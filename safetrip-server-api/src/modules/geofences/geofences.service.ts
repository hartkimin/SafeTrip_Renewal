import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Geofence, GeofenceEvent, GeofencePenalty } from '../../entities/geofence.entity';

@Injectable()
export class GeofencesService {
    constructor(
        @InjectRepository(Geofence) private geofenceRepo: Repository<Geofence>,
        @InjectRepository(GeofenceEvent) private eventRepo: Repository<GeofenceEvent>,
        @InjectRepository(GeofencePenalty) private penaltyRepo: Repository<GeofencePenalty>,
    ) { }

    async create(userId: string, tripId: string, data: Partial<Geofence>) {
        const geofence = this.geofenceRepo.create({ ...data, tripId, createdBy: userId });
        return this.geofenceRepo.save(geofence);
    }

    async findByTrip(tripId: string) {
        return this.geofenceRepo.find({ where: { tripId, isActive: true } });
    }

    async update(geofenceId: string, data: Partial<Geofence>) {
        await this.geofenceRepo.update(geofenceId, data);
        return this.geofenceRepo.findOne({ where: { geofenceId } });
    }

    async delete(geofenceId: string) {
        await this.geofenceRepo.update(geofenceId, { isActive: false });
    }

    async recordEvent(geofenceId: string, userId: string, tripId: string, eventType: string, lat: number, lng: number) {
        const event = this.eventRepo.create({ geofenceId, userId, tripId, eventType, latitude: lat, longitude: lng });
        return this.eventRepo.save(event);
    }

    async getEvents(tripId: string) {
        return this.eventRepo.find({ where: { tripId }, order: { occurredAt: 'DESC' }, take: 100 });
    }

    async addPenalty(eventId: string, tripId: string, userId: string, penaltyType: string, reason?: string) {
        // 누적 위반 횟수 계산
        const count = await this.penaltyRepo.count({ where: { tripId, userId } });
        const penalty = this.penaltyRepo.create({
            eventId, tripId, userId, penaltyType,
            penaltyReason: reason,
            cumulativeViolations: count + 1,
        });
        return this.penaltyRepo.save(penalty);
    }
}
