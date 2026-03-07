import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { InviteCode } from '../../entities/invite-code.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';
import { CreateInviteCodeDto } from './dto/create-invite-code.dto';

/** §05 Step 8: 역할별 최대 인원 (tb_trip_settings에 컬럼이 없으므로 상수로 관리) */
const MAX_CREW_CHIEFS_PER_GROUP = 5;

@Injectable()
export class InviteCodesService {
    constructor(
        @InjectRepository(InviteCode) private inviteCodeRepo: Repository<InviteCode>,
        @InjectRepository(Group) private groupRepo: Repository<Group>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        private dataSource: DataSource,
    ) {}

    /** §03.1: 7-char alphanumeric code excluding O/0/I/l */
    private generateCode(): string {
        const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ123456789';
        let code = '';
        for (let i = 0; i < 7; i++) {
            code += chars[Math.floor(Math.random() * chars.length)];
        }
        return code;
    }

    /** §03 + §04: Create invite code */
    async createCode(tripId: string, userId: string, dto: CreateInviteCodeDto) {
        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) throw new NotFoundException('Trip not found');

        const groupId = trip.groupId;

        // §04.1: Permission matrix
        const member = await this.memberRepo.findOne({
            where: { groupId, userId, status: 'active' },
        });
        if (!member) throw new ForbiddenException('Not a member of this trip');

        const role = member.memberRole;
        const targetRole = dto.target_role;

        if (!['crew_chief', 'crew', 'guardian'].includes(targetRole)) {
            throw new BadRequestException('target_role must be one of: crew_chief, crew, guardian');
        }

        // §04.1: Captain = all roles, crew_chief = crew only
        if (role === 'crew_chief' && targetRole !== 'crew') {
            throw new ForbiddenException('Crew chief can only create crew invite codes');
        }
        if (role !== 'captain' && role !== 'crew_chief') {
            throw new ForbiddenException('Only captain or crew_chief can create invite codes');
        }

        // §04.2: Active code limit
        const whereClause: any = { createdBy: userId, isActive: true };
        if (role === 'captain') {
            whereClause.targetRole = targetRole;
            whereClause.groupId = groupId;
        } else {
            whereClause.groupId = groupId;
        }
        const activeCodeCount = await this.inviteCodeRepo.count({ where: whereClause });

        const limit = role === 'captain' ? 10 : 5;
        if (activeCodeCount >= limit) {
            throw new BadRequestException(
                `Active code limit reached (max ${limit}). Deactivate existing codes first.`,
            );
        }

        // §03.2 + §03.3: Defaults — direct 타입에서 max_uses=NULL 불허
        if (dto.max_uses === null || dto.max_uses === 0) {
            throw new BadRequestException('max_uses must be a positive number for direct model');
        }

        // §04.1: 크루장은 고급 설정 불가 — max_uses=1, expires_hours=72 강제
        let maxUses: number;
        let expiresHours: number;
        if (role === 'crew_chief') {
            maxUses = 1;
            expiresHours = 72;
        } else {
            maxUses = dto.max_uses ?? 1;
            expiresHours = dto.expires_hours ?? 72;
        }

        const expiresAt = new Date();
        expiresAt.setTime(expiresAt.getTime() + expiresHours * 60 * 60 * 1000);

        // §03.1: Generate code with 5 retry attempts
        let code = '';
        for (let attempt = 0; attempt < 5; attempt++) {
            code = this.generateCode();
            const exists = await this.inviteCodeRepo.findOne({ where: { code } });
            if (!exists) break;
            if (attempt === 4) throw new BadRequestException('Failed to generate unique code after 5 attempts');
        }

        const invite = this.inviteCodeRepo.create({
            groupId,
            tripId,
            code,
            targetRole,
            maxUses,
            expiresAt,
            createdBy: userId,
            modelType: 'direct',
        });

        const saved = await this.inviteCodeRepo.save(invite);

        return {
            invite_code_id: saved.inviteCodeId,
            code: saved.code,
            target_role: saved.targetRole,
            max_uses: saved.maxUses,
            expires_at: saved.expiresAt,
            model_type: saved.modelType,
            qr_url: `https://api.safetrip.app/qr/${saved.code}`,  // §14.2
        };
    }

    /** §05: 8-step read-only validation */
    async validateCode(code: string) {
        // §06.1: Uppercase normalization
        code = code.toUpperCase();

        // §05 Step 1: Code exists
        const invite = await this.inviteCodeRepo.findOne({ where: { code } });
        if (!invite) throw new BadRequestException('ERR_CODE_NOT_FOUND');

        // §05 Step 2: Active
        if (!invite.isActive) throw new BadRequestException('ERR_CODE_INACTIVE');

        // §05 Step 3: Not expired
        if (new Date() >= invite.expiresAt) {
            throw new BadRequestException('ERR_CODE_EXPIRED');
        }

        // §05 Step 4: Uses remaining
        if (invite.maxUses !== null && invite.currentUses >= invite.maxUses) {
            throw new BadRequestException('ERR_CODE_EXHAUSTED');
        }

        // §05 Step 5: Trip valid
        const trip = await this.tripRepo.findOne({ where: { tripId: invite.tripId as string } });
        if (!trip || !['scheduled', 'ongoing'].includes(trip.status || '')) {
            throw new BadRequestException('ERR_TRIP_INVALID');
        }

        const group = await this.groupRepo.findOne({ where: { groupId: invite.groupId } });

        return {
            target_role: invite.targetRole,
            uses_remaining: invite.maxUses !== null ? invite.maxUses - invite.currentUses : null,
            trip: {
                trip_id: trip.tripId,
                group_id: trip.groupId,
                destination: trip.destination,
                start_date: trip.startDate,
                end_date: trip.endDate,
                status: trip.status,
                title: group?.groupName || '',
            },
        };
    }

    /** §05 + §11: Transaction join via invite code */
    async useCode(code: string, userId: string) {
        // §06.1: Uppercase normalization
        code = code.toUpperCase();

        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            // §05 Step 1: Code exists (with pessimistic lock for TOCTOU safety)
            const invite = await queryRunner.manager.findOne(InviteCode, {
                where: { code },
                lock: { mode: 'pessimistic_write' },
            });
            if (!invite) throw new BadRequestException('ERR_CODE_NOT_FOUND');

            // §05 Step 2: Active
            if (!invite.isActive) throw new BadRequestException('ERR_CODE_INACTIVE');

            // §05 Step 3: Not expired
            if (new Date() >= invite.expiresAt) {
                throw new BadRequestException('ERR_CODE_EXPIRED');
            }

            // §05 Step 4: Uses remaining
            if (invite.maxUses !== null && invite.currentUses >= invite.maxUses) {
                throw new BadRequestException('ERR_CODE_EXHAUSTED');
            }

            // §05 Step 5: Trip valid
            const trip = await queryRunner.manager.findOne(Trip, { where: { tripId: invite.tripId as string } });
            if (!trip || !['scheduled', 'ongoing'].includes(trip.status || '')) {
                throw new BadRequestException('ERR_TRIP_INVALID');
            }

            const groupId = invite.groupId;

            // §05 Step 6: Not already a member
            const existingMember = await queryRunner.manager.findOne(GroupMember, {
                where: { groupId, userId, status: 'active' },
            });
            if (existingMember) throw new BadRequestException('ERR_ALREADY_MEMBER');

            // §05 Step 7: Capacity check
            const group = await queryRunner.manager.findOne(Group, { where: { groupId } });
            if (group?.maxMembers) {
                const currentCount = await queryRunner.manager.count(GroupMember, {
                    where: { groupId, status: 'active' },
                });
                if (currentCount >= group.maxMembers) {
                    throw new BadRequestException('ERR_TRIP_FULL');
                }
            }

            // §05 Step 8: Role availability
            if (!['crew_chief', 'crew', 'guardian'].includes(invite.targetRole)) {
                throw new BadRequestException('ERR_ROLE_UNAVAILABLE');
            }

            // §05 Step 8: 크루장 정원 검증
            if (invite.targetRole === 'crew_chief') {
                const crewChiefCount = await queryRunner.manager.count(GroupMember, {
                    where: { groupId, memberRole: 'crew_chief', status: 'active' },
                });
                if (crewChiefCount >= MAX_CREW_CHIEFS_PER_GROUP) {
                    throw new BadRequestException('ERR_ROLE_UNAVAILABLE');
                }
            }

            // Guardian-member overlap check (§12.1 #11)
            if (invite.targetRole === 'guardian') {
                const isMemberAny = await queryRunner.manager.findOne(GroupMember, {
                    where: { tripId: invite.tripId as string, userId, status: 'active' },
                });
                if (isMemberAny) {
                    throw new BadRequestException('ERR_GUARDIAN_MEMBER_OVERLAP');
                }
            }

            // §12.1 #10: Rejoin cooldown (24h)
            const recentLeft = await queryRunner.manager
                .createQueryBuilder(GroupMember, 'gm')
                .where('gm.groupId = :groupId', { groupId })
                .andWhere('gm.userId = :userId', { userId })
                .andWhere('gm.status IN (:...statuses)', { statuses: ['left', 'removed'] })
                .andWhere('gm.leftAt IS NOT NULL')
                .orderBy('gm.leftAt', 'DESC')
                .getOne();

            if (recentLeft?.leftAt) {
                const cooldownMs = 24 * 60 * 60 * 1000;
                if (new Date().getTime() - new Date(recentLeft.leftAt).getTime() < cooldownMs) {
                    throw new BadRequestException('ERR_REJOIN_COOLDOWN');
                }
            }

            // §02.2: Schedule overlap check (for crew roles)
            if (['captain', 'crew_chief', 'crew'].includes(invite.targetRole)) {
                const overlapping = await queryRunner.manager.query(`
                    SELECT t.trip_id, t.destination
                    FROM tb_group_member gm
                    JOIN tb_trip t ON gm.trip_id = t.trip_id
                    WHERE gm.user_id = $1
                      AND gm.status = 'active'
                      AND gm.member_role IN ('captain', 'crew_chief', 'crew')
                      AND t.status IN ('planning', 'active', 'scheduled', 'ongoing')
                      AND t.trip_id != $2
                      AND t.start_date <= $4
                      AND t.end_date >= $3
                `, [userId, trip.tripId, trip.startDate, trip.endDate]);

                if (overlapping.length > 0) {
                    throw new BadRequestException(
                        `일정이 겹치는 다른 여행(${overlapping[0].destination})에 이미 참여 중입니다. (비즈니스 원칙 §02.2)`,
                    );
                }
            }

            // §11.1: Join within transaction
            const targetRole = invite.targetRole;
            const newMember = queryRunner.manager.create(GroupMember, {
                groupId,
                userId,
                tripId: invite.tripId as string,
                memberRole: targetRole,
                isAdmin: targetRole === 'captain',
                canEditSchedule: targetRole === 'captain' || targetRole === 'crew_chief',
                canEditGeofence: targetRole === 'captain' || targetRole === 'crew_chief',
                canViewAllLocations: true,
                canAttendanceCheck: targetRole === 'captain' || targetRole === 'crew_chief',
                isGuardian: targetRole === 'guardian',
            });
            const savedMember = await queryRunner.manager.save(GroupMember, newMember);

            // §11.1: Atomic current_uses increment
            await queryRunner.query(
                `UPDATE tb_invite_code SET current_uses = current_uses + 1 WHERE invite_code_id = $1`,
                [invite.inviteCodeId],
            );

            await queryRunner.commitTransaction();

            return {
                group: { group_id: groupId, group_name: group?.groupName },
                member: {
                    member_id: savedMember.memberId,
                    member_role: savedMember.memberRole,
                    is_admin: savedMember.isAdmin,
                },
                target_role: invite.targetRole,
                trip_id: invite.tripId,
            };
        } catch (error) {
            await queryRunner.rollbackTransaction();
            if (error instanceof BadRequestException || error instanceof ForbiddenException || error instanceof NotFoundException) {
                throw error;
            }
            throw new BadRequestException('ERR_JOIN_FAILED');
        } finally {
            await queryRunner.release();
        }
    }

    /** §04.1: List active invite codes for a trip */
    async listCodes(tripId: string, userId: string) {
        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) throw new NotFoundException('Trip not found');

        const groupId = trip.groupId;

        const member = await this.memberRepo.findOne({
            where: { groupId, userId, status: 'active' },
        });
        if (!member) throw new ForbiddenException('Not a member');

        const role = member.memberRole;
        if (role !== 'captain' && role !== 'crew_chief') {
            throw new ForbiddenException('Only captain or crew_chief can view invite codes');
        }

        // §04.1: Captain sees all, crew_chief sees own. §14.1: 활성 코드만 반환
        const where: any = { groupId, isActive: true };
        if (role === 'crew_chief') {
            where.createdBy = userId;
        }

        const codes = await this.inviteCodeRepo.find({
            where,
            order: { createdAt: 'DESC' },
        });

        return codes.map(c => ({
            invite_code_id: c.inviteCodeId,
            code: c.code,
            target_role: c.targetRole,
            max_uses: c.maxUses,
            current_uses: c.currentUses,
            expires_at: c.expiresAt,
            is_active: c.isActive,
            model_type: c.modelType,
            created_by: c.createdBy,
            created_at: c.createdAt,
            is_expired: new Date() >= c.expiresAt,
        }));
    }

    /** §04.1: Deactivate an invite code */
    async deactivateCode(tripId: string, codeId: string, userId: string) {
        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) throw new NotFoundException('Trip not found');

        const groupId = trip.groupId;

        const member = await this.memberRepo.findOne({
            where: { groupId, userId, status: 'active' },
        });
        if (!member) throw new ForbiddenException('Not a member');

        const role = member.memberRole;
        if (role !== 'captain' && role !== 'crew_chief') {
            throw new ForbiddenException('Only captain or crew_chief can deactivate codes');
        }

        const invite = await this.inviteCodeRepo.findOne({
            where: { inviteCodeId: codeId, groupId },
        });
        if (!invite) throw new NotFoundException('Invite code not found');

        // §04.1: Crew chief can only deactivate own codes
        if (role === 'crew_chief' && invite.createdBy !== userId) {
            throw new ForbiddenException('Crew chief can only deactivate own codes');
        }

        invite.isActive = false;
        await this.inviteCodeRepo.save(invite);

        return { invite_code_id: codeId, is_active: false };
    }
}
