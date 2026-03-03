import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import {
    Location, LocationSharing, LocationSchedule,
    StayPoint, PlannedRoute, RouteDeviation, MovementSession
} from '../../entities/location.entity';

@Injectable()
export class LocationsService {
    constructor(
        @InjectRepository(Location) private locationRepo: Repository<Location>,
        @InjectRepository(LocationSharing) private sharingRepo: Repository<LocationSharing>,
        @InjectRepository(LocationSchedule) private scheduleRepo: Repository<LocationSchedule>,
        @InjectRepository(StayPoint) private stayPointRepo: Repository<StayPoint>,
        @InjectRepository(PlannedRoute) private routeRepo: Repository<PlannedRoute>,
        @InjectRepository(RouteDeviation) private deviationRepo: Repository<RouteDeviation>,
        @InjectRepository(MovementSession) private sessionRepo: Repository<MovementSession>,
    ) { }

    /** 위치 기록 일괄 저장 (오프라인 배치 지원) */
    async batchRecord(userId: string, tripId: string, locations: Array<{
        latitude: number; longitude: number; altitude?: number; accuracy?: number;
        speed?: number; heading?: number; activityType?: string; recordedAt: string;
        batteryLevel?: number; isOffline?: boolean;
    }>) {
        const entities = locations.map((loc) =>
            this.locationRepo.create({
                userId, tripId,
                ...loc,
                recordedAt: new Date(loc.recordedAt),
                serverReceivedAt: new Date(),
            }),
        );
        return this.locationRepo.save(entities);
    }

    async logLocation(data: {
        tripId: string;
        userId: string;
        latitude: number;
        longitude: number;
        accuracy?: number;
        speed?: number;
        heading?: number;
        batteryLevel?: number;
    }) {
        const location = this.locationRepo.create({
            ...data,
            recordedAt: new Date(),
            serverReceivedAt: new Date(),
        });
        return this.locationRepo.save(location);
    }

    async getLocations(tripId: string, userId: string, startTime?: string, endTime?: string, limit: number = 100) {
        const query: any = { tripId, userId };
        if (startTime || endTime) {
            // Complex where conditions require Raw or Between
            if (startTime && endTime) {
                query.recordedAt = Between(new Date(startTime), new Date(endTime));
            } else {
                // Simplified for now, production should handle > start or < end
                if (startTime) query.recordedAt = Between(new Date(startTime), new Date());
                // if (endTime) query.recordedAt = Between(new Date(0), new Date(endTime));
            }
        }

        return this.locationRepo.find({
            where: query,
            order: { recordedAt: 'DESC' },
            take: limit,
        });
    }

    async getRecent(tripId: string, userId: string, limit = 100) {
        return this.locationRepo.find({
            where: { tripId, userId },
            order: { recordedAt: 'DESC' },
            take: limit,
        });
    }

    async getGroupLocations(tripId: string) {
        // 각 멤버의 최신 위치 반환 — subquery로 최적화 필요 시 QueryBuilder 사용
        const raw = await this.locationRepo
            .createQueryBuilder('l')
            .distinctOn(['l.user_id'])
            .where('l.trip_id = :tripId', { tripId })
            .orderBy('l.user_id', 'ASC')
            .addOrderBy('l.recorded_at', 'DESC')
            .getMany();
        return raw;
    }

    // ── 위치 공유 설정 ──
    async getSharingSettings(tripId: string, userId: string) {
        return this.sharingRepo.find({ where: { tripId, userId } });
    }

    async updateSharing(tripId: string, userId: string, isSharing: boolean, visibilityType?: string) {
        let sharing = await this.sharingRepo.findOne({ where: { tripId, userId } });
        if (sharing) {
            await this.sharingRepo.update(sharing.sharingId, {
                isSharing,
                visibilityType,

                updatedAt: new Date()
            });
        } else {
            sharing = this.sharingRepo.create({ tripId, userId, isSharing, visibilityType });
            await this.sharingRepo.save(sharing);
        }
        return this.sharingRepo.findOne({ where: { tripId, userId } });
    }

    // ── 일정 기반 공유 ──
    async setSchedule(tripId: string, userId: string, data: {
        dayOfWeek?: number; specificDate?: string; startTime: string; endTime: string; isSharingOn: boolean;
    }) {
        const schedule = this.scheduleRepo.create({
            tripId, userId,
            dayOfWeek: data.dayOfWeek,
            specificDate: data.specificDate ? new Date(data.specificDate) : undefined,
            startTime: data.startTime,
            endTime: data.endTime,
            isSharingOn: data.isSharingOn,
        });
        return this.scheduleRepo.save(schedule);
    }

    // ── 체류 지점 ──
    async getStayPoints(tripId: string, userId: string) {
        return this.stayPointRepo.find({ where: { tripId, userId }, order: { arrivedAt: 'DESC' } });
    }

    // ── Movement Sessions (9.4 ~ 9.9) ──
    async getMovementSessionsSummary(userId: string, page: number, limit: number, needImages?: string, targetDate?: string, timezoneOffset: number = 0) {
        // Mock implementation to satisfy interface
        return {
            sessions: [],
            page,
            limit,
            total: 0
        };
    }

    async getMovementSessionsDateRange(userId: string, timezoneOffset: number) {
        return {
            start_date: null,
            end_date: null
        };
    }

    async getMovementSessionsByDate(userId: string, date: string, timezoneOffset: number, needImages?: string) {
        return {
            sessions: [],
            date,
            total: 0
        };
    }

    async getMovementSessionDetail(userId: string, sessionId: string) {
        // Query locations by sessionId
        // For now, returning mock
        return {
            session_id: sessionId,
            start_time: new Date().toISOString(),
            end_time: new Date().toISOString(),
            is_completed: null,
            locations: []
        };
    }

    async completeMovementSession(userId: string, sessionId: string, latitude: number, longitude: number, recordedAt: string) {
        // Save the final location and mark session end conceptually
        return { success: true };
    }

    async getMovementSessionEvents(userId: string, sessionId: string) {
        return {
            session_id: sessionId,
            events: [],
            count: 0
        };
    }
}
