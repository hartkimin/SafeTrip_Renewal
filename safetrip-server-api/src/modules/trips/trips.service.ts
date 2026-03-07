import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, DataSource, Not } from 'typeorm';
import { Trip } from '../../entities/trip.entity';
import { User } from '../../entities/user.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { ChatRoom } from '../../entities/chat.entity';
import { Schedule } from '../../entities/schedule.entity';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { InviteCode } from '../../entities/invite-code.entity';
import { Country } from '../../entities/country.entity';
import { PaymentsService } from '../payments/payments.service';
import { B2bService } from '../b2b/b2b.service';

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
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(Guardian) private guardianRepo: Repository<Guardian>,
        @InjectRepository(Country) private countryRepo: Repository<Country>,
        private paymentsService: PaymentsService,
        private b2bService: B2bService,
        private dataSource: DataSource,
    ) { }

    /**
     * POST /trips — 여행 생성 (그룹 자동 생성 + captain 등록 + 채팅방 자동 생성)
     */
    async create(userId: string, data: {
        title: string;
        country_code: string;
        country_name?: string;
        trip_type: string;
        start_date: string;
        end_date: string;
        sharing_mode?: string;
        privacy_level?: string;
        b2b_contract_id?: string;
    }) {
        // 1) 15일 제한 체크
        const start = new Date(data.start_date);
        const end = new Date(data.end_date);
        const diffDays = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
        if (diffDays > 15 || diffDays < 0) {
            throw new BadRequestException('Trip duration must be between 1 and 15 days');
        }

        // 2) B2B 쿼터 및 제약 사항 확인
        let finalPrivacyLevel = data.privacy_level || 'standard';
        let finalSharingMode = data.sharing_mode || 'voluntary';

        if (data.b2b_contract_id) {
            const hasQuota = await this.b2bService.checkTripQuota(data.b2b_contract_id);
            if (!hasQuota) {
                throw new BadRequestException('B2B Trip quota exceeded for this contract');
            }

            // 계약 강제 설정 확인
            const contract = await this.dataSource.query('SELECT forced_privacy_level, forced_sharing_mode FROM tb_b2b_contract WHERE contract_id = $1', [data.b2b_contract_id]);
            if (contract && contract.length > 0) {
                if (contract[0].forced_privacy_level) finalPrivacyLevel = contract[0].forced_privacy_level;
                if (contract[0].forced_sharing_mode) finalSharingMode = contract[0].forced_sharing_mode;
            }
        }

        const inviteCode = Math.random().toString(36).substring(2, 8).toUpperCase();

        // 3) 그룹 생성
        const group = this.groupRepo.create({
            groupName: data.title,
            groupType: data.trip_type,
            createdBy: userId,
            inviteCode
        });
        const savedGroup = await this.groupRepo.save(group);

        // 4) 여행 생성
        const trip = this.tripRepo.create({
            groupId: savedGroup.groupId,
            tripName: data.title,
            destination: data.country_name || data.country_code,
            destinationCountryCode: data.country_code,
            startDate: start,
            endDate: end,
            sharingMode: finalSharingMode,
            privacyLevel: finalPrivacyLevel,
            b2bContractId: data.b2b_contract_id || null,
        });
        const savedTrip = await this.tripRepo.save(trip);

        // B2B인 경우 카운트 증가
        if (data.b2b_contract_id) {
            await this.b2bService.incrementTripCount(data.b2b_contract_id);
        }

        // 5) captain 등록
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

        // 6) §10.2: 미성년자 보호 로직 적용 (캡틴이 미성년자인 경우)
        await this.checkAndEnforceMinorProtection(savedTrip.tripId, userId);

        // 7) 채팅방 자동 생성
        const chatRoom = this.chatRoomRepo.create({
            tripId: savedTrip.tripId,
            roomType: 'group',
            roomName: data.title,
        });
        await this.chatRoomRepo.save(chatRoom);

        // Refresh trip data to include updated privacy_level if changed
        const finalTrip = await this.tripRepo.findOne({ where: { tripId: savedTrip.tripId } });
        return { ...finalTrip, inviteCode };
    }

    /**
     * §10.2 미성년자 보호 로직
     * 미성년자(만 18세 미만) 멤버 포함 시 safety_first 등급 강제
     */
    private async checkAndEnforceMinorProtection(tripId: string, userId: string) {
        const user = await this.userRepo.findOne({ where: { userId }, select: ['minorStatus'] });
        if (!user) return;

        if (user.minorStatus === 'minor') {
            await this.tripRepo.update(tripId, {
                privacyLevel: 'safety_first',
                hasMinorMembers: true,
                updatedAt: new Date(),
            });
        }
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

        const trip = await this.findById(tripId);

        // §08.2: 기간 변경 시 15일 검증
        if (data.endDate || data.startDate) {
            const newStart = data.startDate ? new Date(data.startDate as string) : trip.startDate;
            const newEnd = data.endDate ? new Date(data.endDate as string) : trip.endDate;
            const diffDays = Math.ceil((newEnd.getTime() - newStart.getTime()) / (1000 * 60 * 60 * 24));
            if (diffDays > 15) {
                throw new BadRequestException({
                    statusCode: 400,
                    errorCode: 'TRIP_DURATION_EXCEEDED',
                    message: '여행 기간은 최대 15일까지 설정할 수 있습니다.',
                });
            }
            if (diffDays < 0) {
                throw new BadRequestException({
                    statusCode: 400,
                    errorCode: 'TRIP_DATE_CONFLICT',
                    message: '종료일이 시작일보다 앞설 수 없습니다.',
                });
            }
        }

        // §10.2: 미성년자가 포함된 여행은 safety_first 외 등급 변경 불가
        if (trip.hasMinorMembers && data.privacyLevel && data.privacyLevel !== 'safety_first') {
            throw new BadRequestException('미성년자가 포함된 여행은 "안전 최우선" 등급만 사용할 수 있습니다. (비즈니스 원칙 §10.2)');
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
            const items = await this.travelScheduleRepo.find({
                where: { tripId, ...(sched.scheduleName ? { scheduleType: sched.scheduleName } : {}) },
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

    async bulkInvite(tripId: string, userId: string, invitees: { phone: string; name?: string; role: string }[]) {
        const trip = await this.findById(tripId);

        // 권한 확인
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });
        if (!member || (!member.isAdmin && !member.canManageMembers && member.memberRole !== 'captain')) {
            throw new ForbiddenException('Permission denied: Cannot manage invites');
        }

        const results: any[] = [];
        for (const inv of invitees) {
            const code = Math.random().toString(36).substring(2, 8).toUpperCase();
            const invite = this.inviteCodeRepo.create({
                groupId: trip.groupId,
                createdBy: userId,
                targetRole: inv.role,
                code: code,
                expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7일 만료
            });
            const saved = await this.inviteCodeRepo.save(invite);
            results.push({
                phone: inv.phone,
                name: inv.name,
                code: saved.code,
            });
        }
        return { success: true, count: results.length, invitees: results };
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

        // §10.2: 미성년자 합류 시 보호 로직 실행
        await this.checkAndEnforceMinorProtection(trip.tripId, userId);

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

        // §10.2: 미성년자 합류 시 보호 로직 실행
        await this.checkAndEnforceMinorProtection(trip.tripId, userId);

        return { groupId: group.groupId, memberId: savedMember.memberId };
    }

    // ── 가디언 승인 흐름 ──────────────────────────────────────────────────────
    /**
     * §05.4 가디언 슬롯 쿼터 제한 로직 포함
     */
    async createGuardianApprovalRequest(userId: string, data: { inviteCode: string; guardianPhone: string }) {
        const group = await this.groupRepo.findOne({ where: { inviteCode: data.inviteCode } });
        if (!group) throw new NotFoundException('Invalid invite code');

        const trip = await this.tripRepo.findOne({ where: { groupId: group.groupId } });
        if (!trip) throw new NotFoundException('Trip not found');

        const member = await this.memberRepo.findOne({ where: { tripId: trip.tripId, userId } });
        if (!member) throw new ForbiddenException('You must join the trip first');

        // 쿼터 확인
        const { maxGuardians } = await this.paymentsService.checkGuardianQuota(userId, trip.tripId);
        const currentGuardians = await this.guardianLinkRepo.count({
            where: { memberId: member.memberId, status: Not('rejected') }
        });

        if (currentGuardians >= maxGuardians) {
            throw new BadRequestException(`Guardian limit exceeded. (Current plan limit: ${maxGuardians})`);
        }

        const guardianLink = this.guardianLinkRepo.create({
            tripId: trip.tripId,
            memberId: member.memberId,
            guardianPhone: data.guardianPhone,
            status: 'pending'
        });

        await this.guardianLinkRepo.save(guardianLink);

        return {
            guardian_id: guardianLink.linkId,
            guardian_invite_code: guardianLink.linkId.substring(0, 8).toUpperCase(),
            message: 'Guardian approval request sent'
        };
    }

    async getGuardianApprovalStatus(userId: string) {
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

    // ── 여행정보카드 (DOC-T3-TIC-024 §11.3) ──────────────────────────

    /**
     * GET /trips/card-view — 여행정보카드 전용 데이터 조회
     * TB_TRIP_CARD_VIEW + 가디언 여행 + 오늘 일정 요약
     * (DOC-T3-TIC-024 §11.3)
     */
    async getCardView(userId: string) {
        if (!userId) throw new BadRequestException('user_id is required');

        // 1) 자동 상태 전환: end_date 지난 active 여행 → completed (§04.5, P1-5)
        await this.dataSource.query(`
            UPDATE tb_trip
            SET status = 'completed', updated_at = NOW()
            WHERE status = 'active'
              AND end_date < CURRENT_DATE
              AND deleted_at IS NULL
        `);

        // 2) 멤버 여행 카드 데이터
        const memberTrips = await this.dataSource.query(`
            SELECT
                v.trip_id, v.trip_name, v.status, v.start_date, v.end_date,
                v.trip_days, v.privacy_level, v.sharing_mode, v.schedule_type,
                v.country_code, v.country_name, v.destination_city,
                v.has_minor_members, v.reactivation_count,
                v.d_day, v.current_day, v.member_count, v.can_reactivate,
                v.group_id, v.reactivated_at, v.updated_at,
                gm.member_role AS user_role,
                gm.is_admin
            FROM tb_trip_card_view v
            JOIN tb_group_member gm ON gm.trip_id = v.trip_id
            WHERE gm.user_id = $1
              AND gm.status = 'active'
              AND gm.member_role IN ('captain', 'crew_chief', 'crew')
            ORDER BY
                CASE v.status
                    WHEN 'active' THEN 1
                    WHEN 'planning' THEN 2
                    WHEN 'completed' THEN 3
                END,
                v.start_date DESC
        `, [userId]);

        // 3) 가디언 여행 카드 데이터 (§05)
        //    tb_guardian_link.guardian_id = guardian's user_id
        //    tb_guardian_link.member_id = member's user_id
        let guardianTrips: any[] = [];
        try {
            guardianTrips = await this.dataSource.query(`
                SELECT
                    v.trip_id, v.trip_name, v.status, v.start_date, v.end_date,
                    v.privacy_level, v.group_id,
                    gl.guardian_type,
                    gl.is_paid,
                    u.display_name AS member_name,
                    gm.location_sharing_enabled AS location_sharing_status
                FROM tb_guardian_link gl
                JOIN tb_user u ON u.user_id = gl.member_id
                JOIN tb_group_member gm ON gm.user_id = gl.member_id AND gm.status = 'active'
                JOIN tb_trip_card_view v ON v.trip_id = gm.trip_id
                WHERE gl.guardian_id = $1
                  AND gl.status = 'accepted'
                  AND v.status IN ('active', 'planning')
                ORDER BY v.start_date DESC
            `, [userId]);
        } catch (err) {
            // Fallback: if is_paid or location_sharing_enabled column doesn't exist
            console.warn('getCardView guardianTrips query fallback:', err.message);
            try {
                guardianTrips = await this.dataSource.query(`
                    SELECT
                        v.trip_id, v.trip_name, v.status, v.start_date, v.end_date,
                        v.privacy_level, v.group_id,
                        gl.guardian_type,
                        FALSE AS is_paid,
                        u.display_name AS member_name,
                        TRUE AS location_sharing_status
                    FROM tb_guardian_link gl
                    JOIN tb_user u ON u.user_id = gl.member_id
                    JOIN tb_group_member gm ON gm.user_id = gl.member_id AND gm.status = 'active'
                    JOIN tb_trip_card_view v ON v.trip_id = gm.trip_id
                    WHERE gl.guardian_id = $1
                      AND gl.status = 'accepted'
                      AND v.status IN ('active', 'planning')
                    ORDER BY v.start_date DESC
                `, [userId]);
            } catch (err2) {
                console.warn('getCardView guardianTrips fallback also failed:', err2.message);
                guardianTrips = [];
            }
        }

        // 4) 오늘 일정 요약 (active 여행만, P2-2)
        //    tb_travel_schedule: schedule_date, title, trip_id
        let scheduleMap = new Map<string, string>();
        try {
            const activeTripIds = memberTrips
                .filter((t: any) => t.status === 'active')
                .map((t: any) => t.trip_id);
            if (activeTripIds.length > 0) {
                const todaySchedules = await this.dataSource.query(`
                    SELECT
                        ts.trip_id,
                        STRING_AGG(ts.title, ' → ' ORDER BY ts.start_time) AS today_summary
                    FROM tb_travel_schedule ts
                    WHERE ts.schedule_date = CURRENT_DATE
                      AND ts.trip_id = ANY($1::uuid[])
                    GROUP BY ts.trip_id
                `, [activeTripIds]);
                scheduleMap = new Map(todaySchedules.map((s: any) => [s.trip_id, s.today_summary]));
            }
        } catch (err) {
            console.warn('getCardView todaySchedules query failed (tables may not exist):', err.message);
        }

        // 5) completed 통계 (P3-1)
        //    tb_movement_history may not exist yet
        let statsMap = new Map<string, any>();
        try {
            const completedTripIds = memberTrips
                .filter((t: any) => t.status === 'completed')
                .map((t: any) => t.trip_id);
            if (completedTripIds.length > 0) {
                const stats = await this.dataSource.query(`
                    SELECT
                        trip_id,
                        COALESCE(SUM(distance_meters), 0) / 1000.0 AS total_distance_km,
                        COUNT(DISTINCT place_name) AS visited_places
                    FROM tb_movement_history
                    WHERE trip_id = ANY($1::uuid[])
                    GROUP BY trip_id
                `, [completedTripIds]);
                statsMap = new Map(stats.map((s: any) => [s.trip_id, s]));
            }
        } catch (err) {
            console.warn('getCardView completedStats query failed (tb_movement_history may not exist):', err.message);
        }

        return {
            memberTrips: memberTrips.map((t: any) => ({
                ...t,
                today_schedule_summary: scheduleMap.get(t.trip_id) || null,
                total_distance_km: statsMap.get(t.trip_id)?.total_distance_km || null,
                visited_places: statsMap.get(t.trip_id)?.visited_places || null,
            })),
            guardianTrips,
        };
    }

    /**
     * PATCH /trips/:tripId/reactivate — 여행 재활성화 (§04.5, P2-1)
     * 조건: completed + 24시간 이내 + reactivation_count == 0
     */
    async reactivateTrip(tripId: string, userId: string) {
        const trip = await this.findById(tripId);

        // 캡틴만 가능
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active', memberRole: 'captain' },
        });
        if (!member) throw new ForbiddenException('캡틴만 재활성화할 수 있습니다.');

        if (trip.status !== 'completed') {
            throw new BadRequestException('완료된 여행만 재활성화할 수 있습니다.');
        }

        if (trip.reactivationCount >= 1) {
            throw new BadRequestException('재활성화는 1회만 가능합니다. (비즈니스 원칙 §02.6)');
        }

        const referenceTime = trip.updatedAt ? new Date(trip.updatedAt).getTime() : 0;
        const hoursSinceUpdate = (Date.now() - referenceTime) / (1000 * 60 * 60);
        if (hoursSinceUpdate > 24) {
            throw new BadRequestException('재활성화 가능 시간(24시간)이 지났습니다.');
        }

        await this.tripRepo.update(tripId, {
            status: 'active',
            reactivationCount: trip.reactivationCount + 1,
            reactivatedAt: new Date(),
        });

        return { success: true, message: '여행이 재활성화되었습니다.' };
    }

    // ── §5.A 추가 조회 엔드포인트 ──────────────────────────────────

    /** GET /trips/groups/:groupId — group_id로 첫 번째 여행 조회 */
    async findByGroupId(groupId: string) {
        if (!groupId) throw new BadRequestException('group_id is required');
        const trip = await this.tripRepo.findOne({
            where: { groupId },
            order: { startDate: 'ASC' },
        });
        if (!trip) throw new NotFoundException('No trip found for this group');
        return trip;
    }

    /** GET /trips/users/:userId/trips — enriched 내 여행 목록 */
    async getUserTrips(userId: string) {
        if (!userId) throw new BadRequestException('user_id is required');

        const rows = await this.dataSource.query(`
            SELECT
                t.trip_id, t.group_id, g.group_name,
                gm.member_role, gm.is_admin,
                t.destination_country_code AS country_code,
                t.destination AS country_name,
                t.destination_city,
                TO_CHAR(t.start_date, 'YYYY-MM-DD') AS start_date,
                TO_CHAR(t.end_date, 'YYYY-MM-DD') AS end_date,
                t.status AS trip_status,
                (SELECT COUNT(*) FROM tb_group_member m2
                 WHERE m2.group_id = gm.group_id AND m2.status = 'active')::int AS member_count,
                gm.joined_at
            FROM tb_group_member gm
            JOIN tb_trip t ON t.trip_id = gm.trip_id
            JOIN tb_group g ON g.group_id = gm.group_id
            WHERE gm.user_id = $1 AND gm.status = 'active'
            ORDER BY gm.joined_at DESC
        `, [userId]);

        return rows;
    }

    /** GET /trips/guardian-invite/:inviteCode — 보호자용 초대코드 조회 */
    async findByGuardianInviteCode(inviteCode: string) {
        if (!inviteCode) throw new BadRequestException('inviteCode is required');

        const guardian = await this.guardianRepo.findOne({
            where: { guardianInviteCode: inviteCode },
        });
        if (!guardian) throw new NotFoundException('Invalid guardian invite code');

        const trip = guardian.tripId
            ? await this.tripRepo.findOne({ where: { tripId: guardian.tripId } })
            : null;

        const traveler = guardian.travelerUserId
            ? await this.userRepo.findOne({ where: { userId: guardian.travelerUserId } })
            : null;

        return {
            trip: trip ? {
                trip_id: trip.tripId,
                country_name: trip.destination,
                start_date: trip.startDate,
                end_date: trip.endDate,
            } : null,
            traveler: traveler ? {
                user_id: traveler.userId,
                display_name: traveler.displayName,
                phone_number: traveler.phoneNumber,
            } : null,
        };
    }

    // ── §5.B 국가 · 타임존 ──────────────────────────────────

    /** GET /trips/groups/:groupId/countries */
    async getCountriesByGroup(groupId: string) {
        if (!groupId) throw new BadRequestException('group_id is required');

        const rows = await this.dataSource.query(`
            SELECT
                destination_country_code AS country_code,
                MIN(start_date)::date::text AS start_date,
                MAX(end_date)::date::text AS end_date
            FROM tb_trip
            WHERE group_id = $1 AND destination_country_code IS NOT NULL
            GROUP BY destination_country_code
            ORDER BY MIN(start_date) ASC
        `, [groupId]);

        return {
            group_id: groupId,
            countries: rows,
            country_codes: rows.map((r: any) => r.country_code),
            count: rows.length,
        };
    }

    /** GET /trips/users/:userId/countries */
    async getCountriesByUser(userId: string) {
        if (!userId) throw new BadRequestException('user_id is required');

        const rows = await this.dataSource.query(`
            SELECT DISTINCT t.destination_country_code AS country_code
            FROM tb_group_member gm
            JOIN tb_trip t ON t.trip_id = gm.trip_id
            WHERE gm.user_id = $1 AND gm.status = 'active'
              AND t.destination_country_code IS NOT NULL
            ORDER BY country_code
        `, [userId]);

        return {
            user_id: userId,
            country_codes: rows.map((r: any) => r.country_code),
            count: rows.length,
        };
    }

    /** GET /trips/groups/:groupId/timezones */
    async getTimezonesByGroup(groupId: string) {
        if (!groupId) throw new BadRequestException('group_id is required');

        const rows = await this.dataSource.query(`
            SELECT DISTINCT c.timezone, c.country_code, c.country_name_ko
            FROM tb_trip t
            JOIN tb_country c ON c.country_code = t.destination_country_code
            WHERE t.group_id = $1 AND c.is_active = TRUE AND c.timezone IS NOT NULL
            ORDER BY c.timezone
        `, [groupId]);

        // Always include Korea first
        const koreaEntry = { country_code: 'KOR', timezone: 'Asia/Seoul', country_name_ko: '대한민국' };
        const filtered = rows.filter((r: any) => r.timezone !== 'Asia/Seoul');

        return {
            group_id: groupId,
            timezones: [koreaEntry, ...filtered],
        };
    }
    // ── Admin Methods ──────────────────────────────────────────────

    /** [Admin] GET /trips/admin/list — 전체 여행 목록 (페이지네이션) */
    async listAllTrips(query: { page?: string; limit?: string }) {
        const page = parseInt(query.page || '1', 10);
        const limit = parseInt(query.limit || '20', 10);
        const skip = (page - 1) * limit;

        try {
            const [trips, total] = await this.tripRepo.createQueryBuilder('t')
                .orderBy('t.createdAt', 'DESC')
                .skip(skip)
                .take(limit)
                .getManyAndCount();

            return {
                success: true,
                data: trips,
                total,
                page,
                limit,
                totalPages: Math.ceil(total / limit),
            };
        } catch (error) {
            console.error('listAllTrips error:', error.message);
            return { success: true, data: [], total: 0, page, limit, totalPages: 0 };
        }
    }

    /** [Admin] GET /trips/admin/stats — 여행 통계 */
    async getTripStats() {
        try {
            const total = await this.tripRepo.count();
            let active = 0;
            let createdToday = 0;
            try {
                active = await this.tripRepo.createQueryBuilder('t')
                    .where('t.status = :status', { status: 'active' })
                    .getCount();
            } catch { /* status column might not exist */ }
            try {
                const today = new Date();
                today.setHours(0, 0, 0, 0);
                createdToday = await this.tripRepo.createQueryBuilder('t')
                    .where('t.createdAt >= :today', { today })
                    .getCount();
            } catch { /* createdAt query issue */ }
            return {
                success: true,
                data: { total, active, createdToday },
            };
        } catch (error) {
            console.error('getTripStats error:', error.message);
            return { success: true, data: { total: 0, active: 0, createdToday: 0 } };
        }
    }
}
