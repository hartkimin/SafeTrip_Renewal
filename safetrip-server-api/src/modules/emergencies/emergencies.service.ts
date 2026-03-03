import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, MoreThan } from 'typeorm';
import { Emergency, EmergencyContact, SosEvent, NoResponseEvent } from '../../entities/emergency.entity';

@Injectable()
export class EmergenciesService {
    constructor(
        @InjectRepository(Emergency) private emergencyRepo: Repository<Emergency>,
        @InjectRepository(EmergencyContact) private contactRepo: Repository<EmergencyContact>,
        @InjectRepository(SosEvent) private sosRepo: Repository<SosEvent>,
        @InjectRepository(NoResponseEvent) private noResponseRepo: Repository<NoResponseEvent>,
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
        }

        // TODO: FCM 알림 발송 로직
        return saved;
    }

    async getEmergencies(tripId: string) {
        return this.emergencyRepo.find({ where: { tripId }, order: { createdAt: 'DESC' }, take: 50 });
    }

    async resolveEmergency(emergencyId: string, userId: string, note?: string) {
        await this.emergencyRepo.update(emergencyId, {
            status: 'resolved',
            resolvedBy: userId,
            resolvedAt: new Date(),
            resolutionNote: note,
        });
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
