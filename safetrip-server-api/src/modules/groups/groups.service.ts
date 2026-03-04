import { Injectable, NotFoundException, ForbiddenException, BadRequestException, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { InviteCode } from '../../entities/invite-code.entity';
import { Trip } from '../../entities/trip.entity';

@Injectable()
export class GroupsService {
    constructor(
        @InjectRepository(Group) private groupRepo: Repository<Group>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(InviteCode) private inviteCodeRepo: Repository<InviteCode>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        private dataSource: DataSource
    ) { }

    async create(userId: string, groupName: string, groupType = 'personal') {
        const group = this.groupRepo.create({
            groupName,
            groupType,
            createdBy: userId,
        });
        return this.groupRepo.save(group);
    }

    async findById(groupId: string) {
        const group = await this.groupRepo.findOne({ where: { groupId } });
        if (!group) throw new NotFoundException('Group not found');
        return group;
    }

    async findMyPermission(groupId: string, userId: string) {
        const member = await this.memberRepo.findOne({
            where: { groupId, userId, status: 'active' }
        });
        if (!member) throw new ForbiddenException('You are not a member of this group');

        return {
            user_id: userId,
            member_role: member.memberRole,
            can_view_all_locations: member.canViewLocation,
            is_admin: member.isAdmin,
            can_edit_schedule: member.canEditSchedule,
            can_edit_geofence: member.canManageGeofences,
        };
    }

    async findRecentGroup(userId: string) {
        const member = await this.memberRepo.findOne({
            where: { userId, status: 'active' },
            order: { createdAt: 'DESC' },
            relations: ['group'],
        });

        if (!member) return { group: null };
        const group = await this.groupRepo.findOne({ where: { groupId: member.groupId } });

        return {
            group: {
                group_id: member.groupId,
                group_name: group?.groupName || 'Unknown Group',
                trip_id: member.tripId,
                member_role: member.memberRole,
                is_admin: member.isAdmin,
            }
        };
    }

    async addMember(groupId: string, tripId: string, userId: string, role = 'crew') {
        // captain 유일성 체크
        if (role === 'captain') {
            const existing = await this.memberRepo.findOne({
                where: { tripId, memberRole: 'captain', status: 'active' },
            });
            if (existing) throw new BadRequestException('Trip already has a captain');
        }

        const member = this.memberRepo.create({
            groupId,
            userId,
            tripId,
            memberRole: role,
            isAdmin: role === 'captain',
            canEditSchedule: role === 'captain' || role === 'crew_chief',
            canManageMembers: role === 'captain',
            canSendNotifications: role === 'captain' || role === 'crew_chief',
            canViewLocation: true,
            canManageGeofences: role === 'captain' || role === 'crew_chief',
        });
        return this.memberRepo.save(member);
    }

    async getMembers(tripId: string) {
        return this.memberRepo.find({
            where: { tripId, status: 'active' },
        });
    }

    async removeMember(tripId: string, userId: string, removedBy: string) {
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });
        if (!member) throw new NotFoundException('Member not found');

        // captain은 제거 불가
        if (member.memberRole === 'captain') {
            throw new ForbiddenException('Cannot remove captain');
        }

        await this.memberRepo.update(member.memberId, {
            status: 'removed',
            leftAt: new Date(),
        });
        return { message: 'Member removed' };
    }

    async updateMemberRole(tripId: string, userId: string, newRole: string, updatedBy: string) {
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });
        if (!member) throw new NotFoundException('Member not found');

        const permissions: Partial<GroupMember> = {
            memberRole: newRole,
            isAdmin: newRole === 'captain',
            canEditSchedule: newRole === 'captain' || newRole === 'crew_chief',
            canManageMembers: newRole === 'captain',
            canSendNotifications: newRole === 'captain' || newRole === 'crew_chief',
            canManageGeofences: newRole === 'captain' || newRole === 'crew_chief',
        };

        await this.memberRepo.update(member.memberId, permissions);
        return this.memberRepo.findOne({ where: { memberId: member.memberId } });
    }

    // ── 초대 코드 (Role-based Invite Codes) ──

    async previewByCode(code: string) {
        const invite = await this.inviteCodeRepo.findOne({ where: { code } });
        if (!invite || !invite.isActive) {
            throw new NotFoundException('Invalid, expired, or used-up invite code');
        }

        if (invite.expiresAt && new Date() > invite.expiresAt) {
            throw new NotFoundException('Invalid, expired, or used-up invite code');
        }

        if (invite.maxUses && invite.usedCount >= invite.maxUses) {
            throw new NotFoundException('Invalid, expired, or used-up invite code');
        }

        const group = await this.groupRepo.findOne({ where: { groupId: invite.groupId } });
        let tripInfo: any = null;
        if (group) {
            const trip = await this.tripRepo.findOne({ where: { groupId: group.groupId } });
            if (trip) {
                tripInfo = {
                    trip_id: trip.tripId,
                    group_id: trip.groupId,
                    country_code: trip.destinationCountryCode,
                    country_name: trip.destination,
                    country_name_ko: trip.destination, // fallback
                    destination_city: trip.destination,
                    start_date: trip.startDate,
                    end_date: trip.endDate,
                    trip_type: trip.privacyLevel,
                    status: trip.status,
                    title: group.groupName
                };
            }
        }

        return {
            target_role: invite.targetRole,
            uses_remaining: invite.maxUses ? invite.maxUses - invite.usedCount : null,
            trip: tripInfo
        };
    }

    async joinByCode(code: string, userId: string) {
        const invite = await this.inviteCodeRepo.findOne({ where: { code } });
        if (!invite || !invite.isActive) throw new NotFoundException('Invalid, expired, or used-up invite code');
        if (invite.expiresAt && new Date() > invite.expiresAt) throw new NotFoundException('Invalid, expired, or used-up invite code');
        if (invite.maxUses && invite.usedCount >= invite.maxUses) throw new NotFoundException('Invalid, expired, or used-up invite code');

        const group = await this.groupRepo.findOne({ where: { groupId: invite.groupId } });
        if (!group) throw new NotFoundException('Group not found');

        const trip = await this.tripRepo.findOne({ where: { groupId: group.groupId } });
        if (!trip) throw new NotFoundException('Trip not found for this group');

        const existingMember = await this.memberRepo.findOne({ where: { groupId: group.groupId, userId, status: 'active' } });
        if (existingMember) {
            return {
                group: { group_id: group.groupId, group_name: group.groupName },
                member: { member_role: existingMember.memberRole, is_admin: existingMember.isAdmin },
                target_role: invite.targetRole,
                already_member: true
            };
        }

        // Add member
        const role = invite.targetRole;
        const newMember = await this.addMember(group.groupId, trip.tripId, userId, role);

        invite.usedCount += 1;
        if (invite.maxUses && invite.usedCount >= invite.maxUses) {
            invite.isActive = false;
        }
        await this.inviteCodeRepo.save(invite);

        return {
            group: { group_id: group.groupId, group_name: group.groupName },
            member: { member_id: newMember.memberId, member_role: newMember.memberRole, is_admin: newMember.isAdmin },
            target_role: invite.targetRole
        };
    }

    async joinLegacy(inviteCode: string, userId: string) {
        // Fallback for tb_group.invite_code
        const group = await this.groupRepo.findOne({ where: { inviteCode } });
        if (!group) {
            // Check tb_invite_code as fallback too if needed, but per spec this is legacy.
            throw new NotFoundException('Invalid invite code');
        }

        const trip = await this.tripRepo.findOne({ where: { groupId: group.groupId } });
        if (!trip) throw new NotFoundException('Trip not found for this group');

        return this.addMember(group.groupId, trip.tripId, userId, 'crew');
    }

    async createInviteCode(groupId: string, userId: string, data: { target_role: string; max_uses?: number; expires_in_days?: number }) {
        const member = await this.memberRepo.findOne({ where: { groupId, userId, status: 'active' } });
        if (!member || (member.memberRole !== 'captain' && member.memberRole !== 'crew_chief')) {
            throw new ForbiddenException('Permission denied: admin role required');
        }

        if (!['crew_chief', 'crew', 'guardian'].includes(data.target_role)) {
            throw new BadRequestException('target_role must be one of: crew_chief, crew, guardian');
        }

        let expiresAt: Date | undefined;
        if (data.expires_in_days) {
            expiresAt = new Date();
            expiresAt.setDate(expiresAt.getDate() + data.expires_in_days);
        }

        const codeString = Math.random().toString(36).substring(2, 8).toUpperCase();

        const invite = this.inviteCodeRepo.create({
            groupId,
            code: codeString,
            targetRole: data.target_role,
            maxUses: data.max_uses,
            expiresAt,
            createdBy: userId
        });

        return this.inviteCodeRepo.save(invite);
    }

    async getInviteCodes(groupId: string, userId: string) {
        const member = await this.memberRepo.findOne({ where: { groupId, userId, status: 'active' } });
        if (!member || (member.memberRole !== 'captain' && member.memberRole !== 'crew_chief')) {
            throw new ForbiddenException('Permission denied: admin role required');
        }

        const codes = await this.inviteCodeRepo.find({ where: { groupId } });
        return { invite_codes: codes };
    }

    async deactivateInviteCode(groupId: string, codeId: string, userId: string) {
        const member = await this.memberRepo.findOne({ where: { groupId, userId, status: 'active' } });
        if (!member || (member.memberRole !== 'captain' && member.memberRole !== 'crew_chief')) {
            throw new ForbiddenException('Permission denied: admin role required');
        }

        const invite = await this.inviteCodeRepo.findOne({ where: { inviteCodeId: codeId } });
        if (invite) {
            invite.isActive = false;
            await this.inviteCodeRepo.save(invite);
        }
        return { invite_code_id: codeId, is_active: false };
    }

    // --- Leadership Transfer ---

    async transferLeadership(groupId: string, currentCaptainId: string, targetUserId: string) {
        if (!groupId || !currentCaptainId || !targetUserId) {
            throw new BadRequestException('groupId, currentCaptainId, and targetUserId are required');
        }

        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            // Verify group
            const group = await queryRunner.manager.findOne(Group, { where: { groupId } });
            if (!group) {
                throw new NotFoundException('Group not found');
            }

            // Verify current captain
            const currentCaptain = await queryRunner.manager.findOne(GroupMember, {
                where: { groupId, userId: currentCaptainId, status: 'active' }
            });

            if (!currentCaptain || currentCaptain.memberRole !== 'captain') {
                throw new ForbiddenException('Only the current captain can transfer leadership');
            }

            // Verify target user is active member
            const targetMember = await queryRunner.manager.findOne(GroupMember, {
                where: { groupId, userId: targetUserId, status: 'active' }
            });

            if (!targetMember) {
                throw new NotFoundException('Target user is not an active member of this group');
            }

            // Execute transfers
            await queryRunner.manager.update(GroupMember,
                { memberId: currentCaptain.memberId },
                { memberRole: 'crew_chief', isAdmin: false }
            );

            await queryRunner.manager.update(GroupMember,
                { memberId: targetMember.memberId },
                { memberRole: 'captain', isAdmin: true }
            );

            await queryRunner.manager.update(Group,
                { groupId },
                { ownerUserId: targetUserId }
            );

            // Log transfer
            await queryRunner.manager.query(
                `INSERT INTO tb_leader_transfer_log (group_id, from_user_id, to_user_id, transferred_at) 
                 VALUES ($1, $2, $3, NOW())`,
                [groupId, currentCaptainId, targetUserId]
            );

            await queryRunner.commitTransaction();

            return {
                success: true,
                from_user_id: currentCaptainId,
                to_user_id: targetUserId
            };

        } catch (error) {
            await queryRunner.rollbackTransaction();
            throw error;
        } finally {
            await queryRunner.release();
        }
    }

    async getTransferHistory(groupId: string, userId: string) {
        if (!groupId) {
            throw new BadRequestException('groupId is required');
        }

        // Must be admin (captain or crew_chief)
        const member = await this.memberRepo.findOne({ where: { groupId, userId, status: 'active' } });
        if (!member || (member.memberRole !== 'captain' && member.memberRole !== 'crew_chief')) {
            throw new ForbiddenException('Permission denied: admin role required');
        }

        // Fetch logs with user names
        const history = await this.dataSource.query(`
            SELECT 
                l.transfer_id, 
                l.from_user_id, 
                l.to_user_id, 
                l.transferred_at,
                u1.display_name as from_display_name,
                u2.display_name as to_display_name
            FROM tb_leader_transfer_log l
            LEFT JOIN tb_user u1 ON l.from_user_id = u1.user_id
            LEFT JOIN tb_user u2 ON l.to_user_id = u2.user_id
            WHERE l.group_id = $1
            ORDER BY l.transferred_at DESC
        `, [groupId]);

        return {
            transfer_history: history
        };
    }
}
