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

    /** PostGIS 기반 근접 지오펜스 체크 (공간 쿼리 최적화) */
    async checkProximity(lat: number, lng: number, tripId: string) {
        // ST_DWithin: 현재 좌표 기준 반경 내에 있는 지오펜스 조회
        // ST_Contains: 폴리곤 형태 지오펜스 내부에 있는지 확인
        const point = `ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)`;
        
        return this.geofenceRepo.createQueryBuilder('geofence')
            .where('geofence.trip_id = :tripId', { tripId })
            .andWhere('geofence.is_active = true')
            .andWhere(`(
                (geofence.fence_type = 'circle' AND ST_DWithin(geofence.geometry, ${point}, geofence.radius_meters)) OR
                (geofence.fence_type = 'polygon' AND ST_Contains(geofence.geometry, ${point}))
            )`)
            .getMany();
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
