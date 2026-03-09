import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan, In } from 'typeorm';
import { Emergency, EmergencyContact, SosEvent, NoResponseEvent } from '../../entities/emergency.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
import { User } from '../../entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { SystemMessageService } from '../chats/system-message.service';

@Injectable()
export class EmergenciesService {
    constructor(
        @InjectRepository(Emergency) private emergencyRepo: Repository<Emergency>,
        @InjectRepository(EmergencyContact) private contactRepo: Repository<EmergencyContact>,
        @InjectRepository(SosEvent) private sosRepo: Repository<SosEvent>,
        @InjectRepository(NoResponseEvent) private noResponseRepo: Repository<NoResponseEvent>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(Guardian) private guardianRepo: Repository<Guardian>,
        @InjectRepository(GuardianLink) private linkRepo: Repository<GuardianLink>,
        @InjectRepository(User) private userRepo: Repository<User>,
        private notifService: NotificationsService,
        private systemMessageService: SystemMessageService,
    ) { }

    /** 긴급 상황 생성 (SOS 포함, 5분 쿨다운) */
    async createEmergency(userId: string, tripId: string, data: {
        emergencyType: string; severity?: string;
        latitude?: number; longitude?: number; description?: string;
        triggerMethod?: string;
    }) {
        // 5분 쿨다운 체크
        const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
        const recent = await this.emergencyRepo.findOne({
            where: { userId, createdAt: MoreThan(fiveMinAgo) },
            order: { createdAt: 'DESC' },
        });
        if (recent) {
            throw new BadRequestException('Emergency cooldown: please wait 5 minutes');
        }

        const emergency = this.emergencyRepo.create({
            userId, tripId,
            emergencyType: data.emergencyType,
            severity: data.severity || 'medium',
            latitude: data.latitude,
            longitude: data.longitude,
            description: data.description,
        });
        const saved = await this.emergencyRepo.save(emergency);

        // SOS 타입이면 SOS 이벤트도 생성
        if (data.emergencyType === 'sos') {
            const sos = this.sosRepo.create({
                emergencyId: saved.emergencyId,
                userId, tripId,
                latitude: data.latitude || 0,
                longitude: data.longitude || 0,
                triggerMethod: data.triggerMethod || 'button',
            });
            await this.sosRepo.save(sos);

            // Insert SOS system message to group chat
            const sender = await this.userRepo.findOne({ where: { userId } });
            await this.systemMessageService.insertSosAlert(tripId, sender?.displayName || 'Traveler', {
                lat: data.latitude || 0,
                lng: data.longitude || 0,
                address: data.description,
            });

            // SOS 알림 발송 로직
            await this.handleSosNotification(userId, tripId, saved);
        }

        return saved;
    }

    private async handleSosNotification(senderId: string, tripId: string, emergency: Emergency) {
        try {
            // 발송자 이름 가져오기
            const sender = await this.userRepo.findOne({ where: { userId: senderId } });
            const senderName = sender?.displayName || 'Traveler';

            const title = `🚨 SOS EMERGENCY!`;
            const body = `${senderName} is in an emergency! Please check the map immediately.`;

            // 1. 그룹 전체 멤버 (본인 제외)
            const members = await this.memberRepo.find({
                where: { tripId, status: 'active' },
                select: ['userId']
            });
            const memberUserIds = members
                .map(m => m.userId)
                .filter(id => id !== senderId);

            // 2. 발송자의 가디언 (가입된 유저만)
            const links = await this.linkRepo.find({
                where: { tripId, memberId: senderId, status: 'active' },
                select: ['guardianId']
            });
            const guardianIds = links.map(l => l.guardianId).filter(id => id !== null);

            let guardianUserIds: string[] = [];
            if (guardianIds.length > 0) {
                const guardians = await this.guardianRepo.find({
                    where: { guardianId: In(guardianIds) },
                    select: ['userId']
                });
                guardianUserIds = guardians.map(g => g.userId);
            }

            // 중복 제거 및 최종 수신자 명단
            const recipientUserIds = Array.from(new Set([...memberUserIds, ...guardianUserIds]));

            // 순차적 발송 (NotificationsService.send가 DB 저장까지 함)
            // 대량 발송의 경우 성능 이슈가 있을 수 있으나 현재는 P0 구현에 집중
            for (const recipientId of recipientUserIds) {
                await this.notifService.send(recipientId, {
                    title,
                    body,
                    notificationType: 'SOS',
                    referenceId: emergency.emergencyId,
                    referenceType: 'EMERGENCY',
                    tripId,
                });
            }
        } catch (error) {
            console.error('Failed to send SOS notification:', error);
        }
    }

    async getAllEmergencies(query: { status?: string; limit?: string; offset?: string }) {
        try {
            const qb = this.emergencyRepo.createQueryBuilder('e');
            if (query.status) qb.andWhere('e.status = :status', { status: query.status });
            qb.orderBy('e.createdAt', 'DESC');
            qb.skip(parseInt(query.offset || '0', 10)).take(parseInt(query.limit || '50', 10));
            const [data, total] = await qb.getManyAndCount();
            return { success: true, data, total };
        } catch (error) {
            console.error('getAllEmergencies error:', error.message);
            return { success: true, data: [], total: 0 };
        }
    }

    async getStats() {
        try {
            const total = await this.emergencyRepo.count();
            const active = await this.emergencyRepo.count({ where: { status: 'active' } });
            const resolved = await this.emergencyRepo.count({ where: { status: 'resolved' } });
            const falseAlarm = await this.emergencyRepo.count({ where: { status: 'false_alarm' } });
            return { success: true, data: { total, active, resolved, falseAlarm } };
        } catch (error) {
            console.error('getStats error:', error.message);
            return { success: true, data: { total: 0, active: 0, resolved: 0, falseAlarm: 0 } };
        }
    }

    async getEmergencies(tripId: string) {
        return this.emergencyRepo.find({ where: { tripId }, order: { createdAt: 'DESC' }, take: 50 });
    }

    async resolveEmergency(emergencyId: string, userId: string, data?: { note?: string; isFalseAlarm?: boolean }) {
        const emergency = await this.emergencyRepo.findOne({ where: { emergencyId } });
        if (!emergency) throw new NotFoundException('Emergency not found');

        // §13 §7.1: Only the sender or captain can resolve
        const isSender = emergency.userId === userId;
        let isCaptain = false;
        if (!isSender && emergency.tripId) {
            const captain = await this.memberRepo.findOne({
                where: { tripId: emergency.tripId, userId, memberRole: 'captain', status: 'active' },
            });
            isCaptain = !!captain;
        }
        if (!isSender && !isCaptain) {
            throw new ForbiddenException('Only the sender or captain can resolve an emergency');
        }

        const newStatus = data?.isFalseAlarm ? 'false_alarm' : 'resolved';
        await this.emergencyRepo.update(emergencyId, {
            status: newStatus,
            resolvedBy: userId,
            resolvedAt: new Date(),
            resolutionNote: data?.note,
        });

        // Also mark the SOS event as cancelled if false alarm
        if (emergency.emergencyType === 'sos' && data?.isFalseAlarm) {
            await this.sosRepo.update(
                { emergencyId },
                { wasCancelled: true },
            );
        }

        // §13 §7.3: Notify all recipients that SOS is cleared
        if (emergency.tripId) {
            const clearTitle = data?.isFalseAlarm ? 'SOS False Alarm' : 'SOS Resolved';
            const sender = await this.userRepo.findOne({ where: { userId: emergency.userId } });
            const clearBody = `${sender?.displayName || 'Traveler'}'s emergency has been ${newStatus}.`;
            this.handleSosNotification(userId, emergency.tripId, { ...emergency, status: newStatus } as any)
                .catch(err => console.error('SOS clear notification error:', err));

            // Insert SOS cancel system message to group chat
            await this.systemMessageService.insertSosCancel(
                emergency.tripId,
                sender?.displayName || 'Traveler',
            );
        }

        return this.emergencyRepo.findOne({ where: { emergencyId } });
    }

    async acknowledgeEmergency(emergencyId: string, userId: string) {
        await this.emergencyRepo.update(emergencyId, {
            status: 'acknowledged',
            acknowledgedBy: userId,
            acknowledgedAt: new Date(),
        });
        return this.emergencyRepo.findOne({ where: { emergencyId } });
    }

    // ── 비상 연락처 ──
    async getContacts(userId: string) {
        return this.contactRepo.find({ where: { userId }, order: { priority: 'ASC' } });
    }

    async addContact(userId: string, data: {
        contactName: string; phoneNumber: string; relationship?: string; priority?: number;
    }) {
        const contact = this.contactRepo.create({ userId, ...data });
        return this.contactRepo.save(contact);
    }

    async removeContact(contactId: string) {
        await this.contactRepo.delete(contactId);
    }
}
