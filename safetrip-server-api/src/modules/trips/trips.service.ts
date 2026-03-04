import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Trip } from '../../entities/trip.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { ChatRoom } from '../../entities/chat.entity';
import { Schedule } from '../../entities/schedule.entity';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { InviteCode } from '../../entities/invite-code.entity';

@Injectable()
export class TripsService {
    constructor(
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        @InjectRepository(Group) private groupRepo: Repository<Group>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(ChatRoom) private chatRoomRepo: Repository<ChatRoom>,
        @InjectRepository(GuardianLink) private guardianLinkRepo: Repository<GuardianLink>,
        @InjectRepository(Schedule) private scheduleRepo: Repository<Schedule>,
        @InjectRepository(TravelSchedule) private travelScheduleRepo: Repository<TravelSchedule>,
        @InjectRepository(InviteCode) private inviteCodeRepo: Repository<InviteCode>,
    ) { }

    /**
     * POST /trips — 여행 생성 (그룹 자동 생성 + captain 등록 + 채팅방 자동 생성)
     */
    async create(userId: string, data: {
        tripName: string; destination?: string; destinationCountryCode?: string;
        startDate: string; endDate: string; sharingMode?: string; privacyLevel?: string;
    }) {
        // 15일 제한 체크
        const start = new Date(data.startDate);
        const end = new Date(data.endDate);
        const diffDays = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
        if (diffDays > 15 || diffDays < 0) {
            throw new BadRequestException('Trip duration must be between 1 and 15 days');
        }

        const inviteCode = Math.random().toString(36).substring(2, 8).toUpperCase();

        // 1) 그룹 생성
        const group = this.groupRepo.create({ groupName: data.tripName, createdBy: userId, inviteCode });
        const savedGroup = await this.groupRepo.save(group);

        // 2) 여행 생성
        const trip = this.tripRepo.create({
            groupId: savedGroup.groupId,
            tripName: data.tripName,
            destination: data.destination,
            destinationCountryCode: data.destinationCountryCode,
            startDate: start,
            endDate: end,
            sharingMode: data.sharingMode || 'voluntary',
            privacyLevel: data.privacyLevel || 'standard',
        });
        const savedTrip = await this.tripRepo.save(trip);

        // 3) captain 등록
        const member = this.memberRepo.create({
            groupId: savedGroup.groupId,
            userId,
            tripId: savedTrip.tripId,
            memberRole: 'captain',
            isAdmin: true,
            canEditSchedule: true,
            canManageMembers: true,
            canSendNotifications: true,
            canViewLocation: true,
            canManageGeofences: true,
        });
        await this.memberRepo.save(member);

        // 4) 채팅방 자동 생성
        const chatRoom = this.chatRoomRepo.create({
            tripId: savedTrip.tripId,
            roomType: 'group',
            roomName: data.tripName,
        });
        await this.chatRoomRepo.save(chatRoom);

        return { ...savedTrip, inviteCode };
    }

    async findByUser(userId: string) {
        const memberships = await this.memberRepo.find({
            where: { userId, status: 'active' },
        });
        if (memberships.length === 0) return [];

        const tripIds = memberships.map((m) => m.tripId);
        return this.tripRepo.find({ where: { tripId: In(tripIds) } });
    }

    async findById(tripId: string) {
        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) throw new NotFoundException('Trip not found');
        return trip;
    }

    async updateTrip(tripId: string, userId: string, data: Partial<Trip>) {
        // 권한 확인 (captain/crew_chief만)
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });
        if (!member || (member.memberRole !== 'captain' && !member.canEditSchedule)) {
            throw new ForbiddenException('Permission denied');
        }

        await this.tripRepo.update(tripId, { ...data, updatedAt: new Date() });
        return this.findById(tripId);
    }

    // ── 멤버 관리 ─────────────────────────────────────────────────
    async updateMember(tripId: string, memberId: string, updaterId: string, data: Partial<GroupMember>) {
        const updater = await this.memberRepo.findOne({
            where: { tripId, userId: updaterId, status: 'active' },
        });

        if (!updater || (!updater.isAdmin && !updater.canManageMembers && updater.memberRole !== 'captain')) {
            throw new ForbiddenException('Permission denied: Cannot manage members');
        }

        const targetMember = await this.memberRepo.findOne({
            where: { tripId, memberId }
        });

        if (!targetMember) {
            throw new NotFoundException('Member not found in this trip');
        }

        // Apply allowed updates
        const allowedFields = ['memberRole', 'canEditSchedule', 'canManageMembers', 'canSendNotifications', 'canViewLocation', 'canManageGeofences', 'isAdmin'];
        for (const key of allowedFields) {
            if (data[key] !== undefined) {
                (targetMember as any)[key] = data[key];
            }
        }

        return this.memberRepo.save(targetMember);
    }

    // ── 일정 관리 ─────────────────────────────────────────────────
    async getSchedules(tripId: string) {
        const schedules = await this.scheduleRepo.find({
            where: { tripId },
            order: { scheduleDate: 'ASC', startTime: 'ASC' },
        });

        const result: any[] = [];
        for (const sched of schedules) {
            // Note: Since DB uses both tb_schedule and tb_travel_schedule, 
            // if we need generic items for the parent schedule we would grab travel schedules.
            // Assuming this API just wants "details" tied to simple travel schedules here:
            const items = await this.travelScheduleRepo.find({
                where: { tripId, scheduleType: sched.scheduleName },
                order: { startTime: 'ASC' },
            });
            result.push({ ...sched, items });
        }
        return result;
    }

    async addSchedule(tripId: string, data: { dayNumber: number; scheduleDate: string; title?: string }) {
        const schedule = this.scheduleRepo.create({
            tripId,
            orderIndex: data.dayNumber,
            scheduleDate: new Date(data.scheduleDate),
            scheduleName: data.title,
        });
        return this.scheduleRepo.save(schedule);
    }

    async addScheduleItem(tripId: string, groupId: string, userId: string, data: {
        title: string; placeName?: string; latitude?: number; longitude?: number;
        startTime?: string; endTime?: string; memo?: string; sortOrder?: number;
    }) {
        const item = this.travelScheduleRepo.create({
            tripId,
            groupId,
            createdBy: userId,
            title: data.title,
            locationName: data.placeName,
            locationLat: data.latitude,
            locationLng: data.longitude,
            startTime: data.startTime ? new Date(data.startTime) : new Date(),
            endTime: data.endTime ? new Date(data.endTime) : undefined,
            description: data.memo,
        });
        return this.travelScheduleRepo.save(item);
    }

    // ── 초대 ──────────────────────────────────────────────────────
    async createInvite(tripId: string, userId: string, data: {
        inviteType: string; invitePhone?: string;
    }) {
        const trip = await this.findById(tripId);
        const group = await this.groupRepo.findOne({ where: { groupId: trip.groupId } });
        if (!group) throw new NotFoundException('Group related to trip not found');

        const inviteCodeStr = Math.random().toString(36).substring(2, 8).toUpperCase();
        const invite = this.inviteCodeRepo.create({
            groupId: group.groupId,
            createdBy: userId,
            targetRole: data.inviteType,
            code: inviteCodeStr,
            expiresAt: new Date(Date.now() + 48 * 60 * 60 * 1000), // 48시간 후 만료
        });
        return this.inviteCodeRepo.save(invite);
    }

    async acceptInvite(inviteCode: string, userId: string) {
        const invite = await this.inviteCodeRepo.findOne({ where: { code: inviteCode, isActive: true } });
        if (!invite) throw new NotFoundException('Invalid or expired invite');
        if (invite.expiresAt && invite.expiresAt < new Date()) {
            throw new BadRequestException('Invite has expired');
        }

        const trip = await this.tripRepo.findOne({ where: { groupId: invite.groupId } });
        if (!trip) throw new NotFoundException('Trip related to group not found');

        // 멤버 등록
        const member = this.memberRepo.create({
            groupId: invite.groupId,
            userId,
            tripId: trip.tripId,
            memberRole: invite.targetRole || 'crew',
            canViewLocation: true,
        });
        await this.memberRepo.save(member);

        // 초대 상태 갱신 (usedCount 증가 및 maxUses 도달 시 비활성화)
        invite.usedCount += 1;
        if (invite.maxUses && invite.usedCount >= invite.maxUses) {
            invite.isActive = false;
        }
        await this.inviteCodeRepo.save(invite);

        return { tripId: trip.tripId, message: 'Invite accepted' };
    }

    async previewByInviteCode(inviteCode: string) {
        const group = await this.groupRepo.findOne({ where: { inviteCode } });
        if (!group) throw new NotFoundException('Trip not found or invalid code');
        const trips = await this.tripRepo.find({ where: { groupId: group.groupId } });
        return { group, trips };
    }

    async findByInviteCode(inviteCode: string) {
        const group = await this.groupRepo.findOne({ where: { inviteCode } });
        if (!group) throw new NotFoundException('Group not found');
        const trip = await this.tripRepo.findOne({ where: { groupId: group.groupId } });
        return { ...trip, group };
    }

    async verifyInviteCode(code: string) {
        const group = await this.groupRepo.findOne({ where: { inviteCode: code } });
        return {
            exists: !!group,
            expired: group ? !group.isActive : false,
        };
    }

    async joinTrip(inviteCode: string, userId: string) {
        const group = await this.groupRepo.findOne({ where: { inviteCode } });
        if (!group) throw new NotFoundException('Group not found');

        const trip = await this.tripRepo.findOne({ where: { groupId: group.groupId } });
        if (!trip) throw new NotFoundException('Trip not found');

        const member = this.memberRepo.create({
            groupId: group.groupId,
            userId,
            tripId: trip.tripId,
            memberRole: 'crew',
        });
        const savedMember = await this.memberRepo.save(member);
        return { groupId: group.groupId, memberId: savedMember.memberId };
    }

    // ── 가디언 승인 흐름 ──────────────────────────────────────────────────────
    async createGuardianApprovalRequest(userId: string, data: { inviteCode: string; guardianPhone: string }) {
        const group = await this.groupRepo.findOne({ where: { inviteCode: data.inviteCode } });
        if (!group) throw new NotFoundException('Invalid invite code');

        const trip = await this.tripRepo.findOne({ where: { groupId: group.groupId } });
        if (!trip) throw new NotFoundException('Trip not found');

        const member = await this.memberRepo.findOne({ where: { tripId: trip.tripId, userId } });
        if (!member) throw new ForbiddenException('You must join the trip first');

        const guardianLink = this.guardianLinkRepo.create({
            tripId: trip.tripId,
            memberId: member.memberId,
            guardianPhone: data.guardianPhone,
            status: 'pending'
        });

        await this.guardianLinkRepo.save(guardianLink);
        // The API spec expects `guardian_id` and `guardian_invite_code` which might be mapped to linkId and something else.
        // Returning minimal structure to simulate for now based on actual GuardianLink entity.
        return {
            guardian_id: guardianLink.linkId,
            guardian_invite_code: guardianLink.linkId.substring(0, 8).toUpperCase(), // Fake invite code since it's missing in GuardianLink
            message: 'Guardian approval request sent'
        };
    }

    async getGuardianApprovalStatus(userId: string) {
        // Find latest pending or active link for the user
        const member = await this.memberRepo.findOne({ where: { userId }, order: { createdAt: 'DESC' } });
        if (!member) return { status: 'none' };

        const link = await this.guardianLinkRepo.findOne({
            where: { memberId: member.memberId },
            order: { createdAt: 'DESC' }
        });

        if (!link) return { status: 'none' };

        let mappedStatus = link.status;
        if (mappedStatus === 'active') mappedStatus = 'approved';

        return {
            status: mappedStatus,
            guardian_invite_code: mappedStatus === 'pending' ? link.linkId.substring(0, 8).toUpperCase() : null,
            accepted_at: link.acceptedAt,
            created_at: link.createdAt
        };
    }
}
