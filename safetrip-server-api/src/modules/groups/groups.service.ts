import { Injectable, NotFoundException, ForbiddenException, BadRequestException, Inject } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { InviteCode } from '../../entities/invite-code.entity';
import { Trip } from '../../entities/trip.entity';
import { Schedule } from '../../entities/schedule.entity';

@Injectable()
export class GroupsService {
    constructor(
        @InjectRepository(Group) private groupRepo: Repository<Group>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(InviteCode) private inviteCodeRepo: Repository<InviteCode>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        @InjectRepository(Schedule) private scheduleRepo: Repository<Schedule>,
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
        // §02.2: 일정 겹침 체크 (captain/crew_chief/crew 대상)
        if (['captain', 'crew_chief', 'crew'].includes(role)) {
            await this.checkDateOverlap(userId, tripId);
        }

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

    /**
     * §02.2 일정 충돌 검증 로직
     * captain, crew_chief, crew는 겹치는 기간의 여행에 중복 참여 불가
     */
    private async checkDateOverlap(userId: string, targetTripId: string) {
        const targetTrip = await this.tripRepo.findOne({ where: { tripId: targetTripId } });
        if (!targetTrip) throw new NotFoundException('Target trip not found');

        // 참여 중인 active/planning 상태의 여행 멤버 정보 조회
        const allMyActive = await this.dataSource.query(`
            SELECT t.start_date, t.end_date, t.trip_id, t.destination
            FROM tb_group_member gm
            JOIN tb_trip t ON gm.trip_id = t.trip_id
            WHERE gm.user_id = $1 
              AND gm.status = 'active'
              AND gm.member_role IN ('captain', 'crew_chief', 'crew')
              AND t.status IN ('planning', 'active')
              AND t.trip_id != $2
        `, [userId, targetTripId]);

        for (const trip of allMyActive) {
            const existingStart = new Date(trip.start_date);
            const existingEnd = new Date(trip.end_date);
            const targetStart = new Date(targetTrip.startDate);
            const targetEnd = new Date(targetTrip.endDate);

            // 겹침 조건: (StartA <= EndB) and (EndA >= StartB)
            if (existingStart <= targetEnd && existingEnd >= targetStart) {
                throw new BadRequestException(`일정이 겹치는 다른 여행(${trip.destination})에 이미 참여 중입니다. (비즈니스 원칙 §02.2)`);
            }
        }
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

    /** §6.B PATCH /groups/:groupId/members/:userId — spec-aligned route */
    async updateMemberByGroupId(groupId: string, userId: string, body: any, updatedBy: string) {
        const trip = await this.tripRepo.findOne({ where: { groupId }, select: ['tripId'] });
        if (!trip) throw new NotFoundException('No trip found for this group');

        if (body.role || body.member_role) {
            return this.updateMemberRole(trip.tripId, userId, body.role || body.member_role, updatedBy);
        }

        // Partial field updates (permissions only)
        const member = await this.memberRepo.findOne({ where: { tripId: trip.tripId, userId, status: 'active' } });
        if (!member) throw new NotFoundException('Member not found');

        const updates: Partial<GroupMember> = {};
        if (body.can_edit_schedule !== undefined) updates.canEditSchedule = body.can_edit_schedule;
        if (body.can_edit_geofence !== undefined) updates.canManageGeofences = body.can_edit_geofence;
        if (body.can_view_all_locations !== undefined) updates.canViewAllLocations = body.can_view_all_locations;

        if (Object.keys(updates).length > 0) {
            await this.memberRepo.update(member.memberId, updates);
        }
        return this.memberRepo.findOne({ where: { memberId: member.memberId } });
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
        // §23 8-step invite code validation
        // Step 1: Code exists
        const invite = await this.inviteCodeRepo.findOne({ where: { code } });
        if (!invite) throw new BadRequestException('ERR_CODE_NOT_FOUND');

        // Step 2: is_active = TRUE
        if (!invite.isActive) throw new BadRequestException('ERR_CODE_INACTIVE');

        // Step 3: Not expired
        if (invite.expiresAt && new Date() > invite.expiresAt) throw new BadRequestException('ERR_CODE_EXPIRED');

        // Step 4: Uses remaining
        if (invite.maxUses && invite.usedCount >= invite.maxUses) throw new BadRequestException('ERR_CODE_EXHAUSTED');

        const group = await this.groupRepo.findOne({ where: { groupId: invite.groupId } });
        if (!group) throw new NotFoundException('Group not found');

        const trip = await this.tripRepo.findOne({ where: { groupId: group.groupId } });
        if (!trip) throw new NotFoundException('Trip not found for this group');

        // Step 5: Trip status valid
        if (!['scheduled', 'ongoing'].includes(trip.status || '')) {
            throw new BadRequestException('ERR_TRIP_INVALID');
        }

        // Step 6: Not already a member
        const existingMember = await this.memberRepo.findOne({ where: { groupId: group.groupId, userId, status: 'active' } });
        if (existingMember) {
            return {
                group: { group_id: group.groupId, group_name: group.groupName },
                member: { member_role: existingMember.memberRole, is_admin: existingMember.isAdmin },
                target_role: invite.targetRole,
                already_member: true
            };
        }

        // Step 7: Member capacity check
        if (group.maxMembers) {
            const currentCount = await this.memberRepo.count({ where: { groupId: group.groupId, status: 'active' } });
            if (currentCount >= group.maxMembers) {
                throw new BadRequestException('ERR_TRIP_FULL');
            }
        }

        // Step 8: Role capacity (simplified — no per-role hard limits enforced yet)
        const role = invite.targetRole;
        const newMember = await this.addMember(group.groupId, trip.tripId, userId, role);

        invite.usedCount += 1;
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

        // §23 §3.1: 7-char alphanumeric excluding O/0/I/l, retry on collision
        let codeString = '';
        for (let attempt = 0; attempt < 5; attempt++) {
            codeString = this.generateInviteCode();
            const exists = await this.inviteCodeRepo.findOne({ where: { code: codeString } });
            if (!exists) break;
            if (attempt === 4) throw new BadRequestException('Failed to generate unique invite code');
        }

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

    /** §23 §3.1: Generate 7-char alphanumeric code excluding O/0/I/l */
    private generateInviteCode(): string {
        const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ123456789'; // excludes O,0,I,l
        let code = '';
        for (let i = 0; i < 7; i++) {
            code += chars[Math.floor(Math.random() * chars.length)];
        }
        return code;
    }

    // ── §6.D Schedule CRUD (group_id 기반) ──

    private async getTripIdForGroup(groupId: string): Promise<string> {
        const trip = await this.tripRepo.findOne({ where: { groupId }, select: ['tripId'] });
        if (!trip) throw new NotFoundException('No trip found for this group');
        return trip.tripId;
    }

    async getSchedules(groupId: string, query: any) {
        const tripId = await this.getTripIdForGroup(groupId);
        const qb = this.scheduleRepo.createQueryBuilder('s')
            .where('s.tripId = :tripId', { tripId });

        if (query.schedule_type) qb.andWhere('s.title ILIKE :type', { type: `%${query.schedule_type}%` });
        if (query.start_time) qb.andWhere('s.startTime >= :start', { start: query.start_time });
        if (query.end_time) qb.andWhere('s.endTime <= :end', { end: query.end_time });

        qb.orderBy('s.startTime', 'ASC');
        const schedules = await qb.getMany();

        return {
            schedules: schedules.map(s => ({
                schedule_id: s.scheduleId,
                trip_id: s.tripId,
                title: s.title,
                description: s.description,
                schedule_date: s.scheduleDate,
                start_time: s.startTime,
                end_time: s.endTime,
                location: s.location,
                location_lat: s.locationLat,
                location_lng: s.locationLng,
                all_day: s.allDay,
                order_index: s.orderIndex,
                created_by: s.createdBy,
                created_at: s.createdAt,
            })),
            count: schedules.length,
        };
    }

    async createSchedule(groupId: string, userId: string, body: any) {
        const tripId = await this.getTripIdForGroup(groupId);
        if (!body.title || !body.start_time) {
            throw new BadRequestException('title and start_time are required');
        }

        const schedule = this.scheduleRepo.create({
            tripId,
            title: body.title,
            description: body.description,
            scheduleDate: body.schedule_date ? new Date(body.schedule_date) : null,
            startTime: new Date(body.start_time),
            endTime: body.end_time ? new Date(body.end_time) : null,
            location: body.location,
            locationLat: body.location_lat,
            locationLng: body.location_lng,
            allDay: body.all_day ?? false,
            orderIndex: body.order_index ?? 0,
            createdBy: userId,
        });

        const saved = await this.scheduleRepo.save(schedule);
        return { schedule_id: saved.scheduleId, message: 'Schedule created' };
    }

    async updateSchedule(groupId: string, scheduleId: string, userId: string, body: any) {
        await this.getTripIdForGroup(groupId); // verify group exists

        const schedule = await this.scheduleRepo.findOne({ where: { scheduleId } });
        if (!schedule) throw new NotFoundException('Schedule not found');

        if (body.title !== undefined) schedule.title = body.title;
        if (body.description !== undefined) schedule.description = body.description;
        if (body.schedule_date !== undefined) schedule.scheduleDate = body.schedule_date ? new Date(body.schedule_date) : null;
        if (body.start_time !== undefined) schedule.startTime = new Date(body.start_time);
        if (body.end_time !== undefined) schedule.endTime = body.end_time ? new Date(body.end_time) : null;
        if (body.location !== undefined) schedule.location = body.location;
        if (body.location_lat !== undefined) schedule.locationLat = body.location_lat;
        if (body.location_lng !== undefined) schedule.locationLng = body.location_lng;
        if (body.all_day !== undefined) schedule.allDay = body.all_day;
        if (body.order_index !== undefined) schedule.orderIndex = body.order_index;

        await this.scheduleRepo.save(schedule);
        return { schedule_id: scheduleId, message: 'Schedule updated' };
    }

    async deleteSchedule(groupId: string, scheduleId: string) {
        await this.getTripIdForGroup(groupId);

        const schedule = await this.scheduleRepo.findOne({ where: { scheduleId } });
        if (!schedule) throw new NotFoundException('Schedule not found');

        await this.scheduleRepo.remove(schedule);
        return { schedule_id: scheduleId, message: 'Schedule deleted' };
    }

    // ── §6.F 출석체크 ──

    async startAttendance(groupId: string, userId: string, body: any) {
        // Verify admin permission
        const member = await this.memberRepo.findOne({ where: { groupId, userId, status: 'active' } });
        if (!member || (member.memberRole !== 'captain' && member.memberRole !== 'crew_chief')) {
            throw new ForbiddenException('Permission denied: admin role required');
        }

        const tripId = await this.getTripIdForGroup(groupId);

        // Create attendance check record
        const result = await this.dataSource.query(`
            INSERT INTO tb_attendance_check (group_id, trip_id, initiated_by, message, status)
            VALUES ($1, $2, $3, $4, 'pending')
            RETURNING attendance_id, created_at
        `, [groupId, tripId, userId, body.message || '출석체크를 확인해주세요']);

        return {
            attendance_id: result[0].attendance_id,
            group_id: groupId,
            status: 'pending',
            message: 'Attendance check started',
            created_at: result[0].created_at,
        };
    }
}
