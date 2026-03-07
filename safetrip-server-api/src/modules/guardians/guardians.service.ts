import { Injectable, NotFoundException, BadRequestException, ForbiddenException, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, Between } from 'typeorm';
import {
    Guardian, GuardianLink, GuardianPause,
    GuardianLocationRequest, GuardianSnapshot, GuardianReleaseRequest,
} from '../../entities/guardian.entity';
import { User } from '../../entities/user.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Schedule } from '../../entities/schedule.entity';
import { PaymentsService } from '../payments/payments.service';

@Injectable()
export class GuardiansService {
    constructor(
        @InjectRepository(Guardian) private guardianRepo: Repository<Guardian>,
        @InjectRepository(GuardianLink) private linkRepo: Repository<GuardianLink>,
        @InjectRepository(GuardianPause) private pauseRepo: Repository<GuardianPause>,
        @InjectRepository(GuardianLocationRequest) private locReqRepo: Repository<GuardianLocationRequest>,
        @InjectRepository(GuardianSnapshot) private snapshotRepo: Repository<GuardianSnapshot>,
        @InjectRepository(GuardianReleaseRequest) private releaseRequestRepo: Repository<GuardianReleaseRequest>,
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(GroupMember) private groupMemberRepo: Repository<GroupMember>,
        @InjectRepository(Schedule) private scheduleRepo: Repository<Schedule>,
        private paymentsService: PaymentsService,
    ) { }

    // [POST] /api/v1/trips/:tripId/guardians
    async createLink(tripId: string, memberId: string, guardianPhone: string) {
        const targetUser = await this.userRepo.findOne({ where: { phoneNumber: guardianPhone } });
        if (!targetUser) {
            throw new NotFoundException('해당 전화번호로 가입된 사용자를 찾을 수 없습니다');
        }

        if (targetUser.userId === memberId) {
            throw new BadRequestException('본인을 가디언으로 추가할 수 없습니다');
        }

        // §05.4 쿼터 확인
        const { maxGuardians } = await this.paymentsService.checkGuardianQuota(memberId, tripId);
        
        const currentLinks = await this.linkRepo.count({
            where: [
                { memberId, tripId, status: 'pending' },
                { memberId, tripId, status: 'accepted' },
            ]
        });

        if (currentLinks >= maxGuardians) {
            throw new BadRequestException(`가디언 등록 제한을 초과했습니다. (현재 플랜 제한: ${maxGuardians}명)`);
        }

        const existingLink = await this.linkRepo.findOne({
            where: { tripId, memberId, guardianId: targetUser.userId }
        });

        if (existingLink) {
            throw new ConflictException('이미 요청한 가디언입니다');
        }

        const link = this.linkRepo.create({
            tripId,
            memberId,
            guardianId: targetUser.userId,
            guardianPhone,
            status: 'pending'
        });

        await this.linkRepo.save(link);

        return {
            link_id: link.linkId,
            guardian_id: link.guardianId,
            status: link.status
        };
    }

    // [PATCH] /api/v1/trips/:tripId/guardians/:linkId/respond
    async respondToLink(tripId: string, linkId: string, guardianId: string, action: 'accepted' | 'rejected') {
        const link = await this.linkRepo.findOne({ where: { linkId, tripId } });
        if (!link || link.status !== 'pending' || link.guardianId !== guardianId) {
            throw new NotFoundException('처리할 수 없는 요청입니다 (존재하지 않거나 이미 처리됨)');
        }

        link.status = action;
        if (action === 'accepted') {
            link.acceptedAt = new Date();
            let guardian = await this.guardianRepo.findOne({ where: { userId: guardianId } });
            if (!guardian) {
                guardian = this.guardianRepo.create({ userId: guardianId });
                await this.guardianRepo.save(guardian);
            }
        }
        await this.linkRepo.save(link);

        return {
            link_id: link.linkId,
            status: link.status
        };
    }

    // [DELETE] /api/v1/trips/:tripId/guardians/:linkId
    async deleteLink(tripId: string, linkId: string, userId: string) {
        const link = await this.linkRepo.findOne({ where: { linkId, tripId } });
        if (!link || (link.memberId !== userId && link.guardianId !== userId)) {
            throw new NotFoundException('해당 가디언 연결을 찾을 수 없거나 권한이 없습니다');
        }

        // §10.2: 미성년자 가디언 해제 제한
        if (link.memberId === userId) {
            const user = await this.userRepo.findOne({ where: { userId }, select: ['minorStatus'] });
            if (user?.minorStatus === 'minor') {
                throw new ForbiddenException('미성년자 사용자는 등록된 가디언을 임의로 해제할 수 없습니다. (비즈니스 원칙 §10.2)');
            }
        }

        await this.linkRepo.remove(link);
    }

    // [GET] /api/v1/trips/:tripId/guardians/me
    async getMyGuardians(tripId: string, memberId: string) {
        const links = await this.linkRepo.find({
            where: { tripId, memberId },
            order: { createdAt: 'DESC' }
        });

        const results = await Promise.all(links.map(async (link) => {
            let guardianInfo: User | null = null;
            if (link.guardianId) {
                guardianInfo = await this.userRepo.findOne({ where: { userId: link.guardianId } });
            }
            return {
                link_id: link.linkId,
                guardian_id: link.guardianId,
                status: link.status,
                created_at: link.createdAt,
                accepted_at: link.acceptedAt,
                display_name: guardianInfo?.displayName || '',
                phone_number: link.guardianPhone || guardianInfo?.phoneNumber || '',
                profile_image_url: guardianInfo?.profileImageUrl || null
            };
        }));

        return results;
    }

    // [GET] /api/v1/trips/:tripId/guardians/pending
    async getPendingInvites(guardianId: string) {
        const links = await this.linkRepo.find({
            where: { guardianId, status: 'pending' },
            order: { createdAt: 'DESC' }
        });

        return Promise.all(links.map(async (link) => {
            const memberUser = await this.userRepo.findOne({ where: { userId: link.memberId } });
            return {
                link_id: link.linkId,
                trip_id: link.tripId,
                member_id: link.memberId,
                status: link.status,
                created_at: link.createdAt,
                member_display_name: memberUser?.displayName || '',
                member_phone_number: memberUser?.phoneNumber || '',
                member_profile_image_url: memberUser?.profileImageUrl || null,
            };
        }));
    }

    // [GET] /api/v1/trips/:tripId/guardians/linked-members
    async getLinkedMembers(tripId: string, guardianId: string) {
        const links = await this.linkRepo.find({
            where: { tripId, guardianId, status: 'accepted' },
            order: { acceptedAt: 'DESC' }
        });

        return Promise.all(links.map(async (link) => {
            const memberUser = await this.userRepo.findOne({ where: { userId: link.memberId } });
            return {
                link_id: link.linkId,
                member_id: link.memberId,
                status: link.status,
                accepted_at: link.acceptedAt,
                created_at: link.createdAt,
                display_name: memberUser?.displayName || '',
                phone_number: memberUser?.phoneNumber || '',
                profile_image_url: memberUser?.profileImageUrl || null,
            };
        }));
    }

    // ── 긴급 위치 요청 ──
    async requestLocation(linkId: string, tripId: string, guardianUserId: string, memberId: string) {
        const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
        const recentCount = await this.locReqRepo.count({
            where: {
                guardianUserId,
                requestedAt: MoreThan(oneHourAgo),
            },
        });
        if (recentCount >= 3) {
            throw new BadRequestException('Location request limit exceeded (max 3 per hour)');
        }

        const req = this.locReqRepo.create({ linkId, tripId, guardianUserId, memberId });
        return this.locReqRepo.save(req);
    }

    async respondToLocationRequest(requestId: string, status: 'approved' | 'denied') {
        await this.locReqRepo.update(requestId, { status, respondedAt: new Date() });
        return this.locReqRepo.findOne({ where: { requestId } });
    }

    // ── 스냅샷 ──
    async createSnapshot(linkId: string, tripId: string, memberId: string, lat: number, lng: number, accuracy?: number) {
        const snapshot = this.snapshotRepo.create({
            linkId, tripId, memberId,
            latitude: lat, longitude: lng, accuracy,
        });
        return this.snapshotRepo.save(snapshot);
    }

    async getSnapshots(linkId: string) {
        return this.snapshotRepo.find({ where: { linkId }, order: { capturedAt: 'DESC' }, take: 48 });
    }

    // ── 일정 요약 (§9.3 — 유료 가디언 전용) ──

    async getScheduleSummary(tripId: string, linkId: string, guardianId: string) {
        // 1. 링크 존재 및 소유권 확인
        const link = await this.linkRepo.findOne({ where: { linkId, tripId } });
        if (!link || link.guardianId !== guardianId) {
            throw new NotFoundException('해당 가디언 연결을 찾을 수 없습니다');
        }

        // 2. 유료 가디언 확인
        if (!link.isPaid) {
            throw new ForbiddenException('일정 요약은 유료 가디언에게만 제공됩니다');
        }

        // 3. 오늘 날짜 범위 계산 (서버 로컬 시간 기준)
        const now = new Date();
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

        // 4. 해당 여행의 오늘 일정 조회
        const schedules = await this.scheduleRepo.find({
            where: {
                tripId,
                scheduleDate: Between(todayStart, todayEnd),
            },
            order: { orderIndex: 'ASC', startTime: 'ASC' },
        });

        return schedules.map((s) => ({
            schedule_id: s.scheduleId,
            title: s.title,
            scheduled_date: s.scheduleDate,
            location_name: s.location || null,
        }));
    }

    // ── 미성년자 가디언 해제 요청 (§10.2) ──

    async createReleaseRequest(tripId: string, linkId: string, requestedBy: string) {
        // 1. 링크 존재 확인
        const link = await this.linkRepo.findOne({ where: { linkId, tripId } });
        if (!link) {
            throw new NotFoundException('해당 가디언 연결을 찾을 수 없습니다');
        }

        // 2. 요청자가 해당 링크의 멤버인지 확인
        if (link.memberId !== requestedBy) {
            throw new ForbiddenException('본인의 가디언 연결에 대해서만 해제 요청할 수 있습니다');
        }

        // 3. 미성년자 여부 확인
        const user = await this.userRepo.findOne({ where: { userId: requestedBy } });
        if (!user || !user.minorStatus || user.minorStatus === 'adult') {
            throw new BadRequestException('미성년자만 가디언 해제 요청을 할 수 있습니다. 성인 사용자는 직접 해제하세요.');
        }

        // 4. 중복 pending 요청 확인
        const existingRequest = await this.releaseRequestRepo.findOne({
            where: { linkId, tripId, status: 'pending' },
        });
        if (existingRequest) {
            throw new ConflictException('이미 대기 중인 해제 요청이 있습니다');
        }

        // 5. 요청 생성
        const request = this.releaseRequestRepo.create({
            linkId,
            tripId,
            requestedBy,
            status: 'pending',
        });
        await this.releaseRequestRepo.save(request);

        return {
            request_id: request.requestId,
            link_id: request.linkId,
            trip_id: request.tripId,
            status: request.status,
            created_at: request.createdAt,
        };
    }

    async respondToReleaseRequest(requestId: string, captainId: string, action: 'approved' | 'rejected') {
        // 1. 요청 존재 확인
        const request = await this.releaseRequestRepo.findOne({ where: { requestId } });
        if (!request) {
            throw new NotFoundException('해당 해제 요청을 찾을 수 없습니다');
        }

        if (request.status !== 'pending') {
            throw new BadRequestException('이미 처리된 요청입니다');
        }

        // 2. 캡틴 권한 확인
        const captain = await this.groupMemberRepo.findOne({
            where: { tripId: request.tripId, userId: captainId, memberRole: 'captain', status: 'active' },
        });
        if (!captain) {
            throw new ForbiddenException('캡틴만 가디언 해제 요청을 승인/거절할 수 있습니다');
        }

        // 3. 요청 상태 업데이트
        request.status = action;
        request.captainId = captainId;
        request.respondedAt = new Date();
        await this.releaseRequestRepo.save(request);

        // 4. 승인 시 가디언 링크 삭제
        if (action === 'approved') {
            const link = await this.linkRepo.findOne({ where: { linkId: request.linkId } });
            if (link) {
                await this.linkRepo.remove(link);
            }
        }

        return {
            request_id: request.requestId,
            status: request.status,
            captain_id: request.captainId,
            responded_at: request.respondedAt,
        };
    }
}
