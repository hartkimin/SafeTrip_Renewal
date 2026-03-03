import { Injectable, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { EventLog } from '../../entities/event-log.entity';

@Injectable()
export class EventLogService {
    constructor(
        @InjectRepository(EventLog)
        private eventLogRepo: Repository<EventLog>,
    ) { }

    async create(body: any) {
        if (!body.user_id || !body.event_type) {
            throw new BadRequestException('user_id and event_type are required');
        }

        const log = this.eventLogRepo.create({
            userId: body.user_id,
            groupId: body.group_id,
            eventType: body.event_type,
            eventSubtype: body.event_subtype,
            latitude: body.latitude,
            longitude: body.longitude,
            address: body.address,
            batteryLevel: body.battery_level,
            batteryIsCharging: body.battery_is_charging,
            networkType: body.network_type,
            appVersion: body.app_version,
            geofenceId: body.geofence_id,
            movementSessionId: body.movement_session_id,
            locationId: body.location_id,
            sosId: body.sos_id,
            eventData: body.event_data,
            occurredAt: body.occurred_at ? new Date(body.occurred_at) : new Date(),
        });

        const saved = await this.eventLogRepo.save(log);

        // TODO: Async FCM triggers or linking logic

        return {
            event_id: saved.eventId,
            message: 'Event log recorded successfully',
        };
    }

    async find(query: any) {
        const { user_id, group_id, event_type, event_subtype, since, limit = 100, offset = 0 } = query;

        const qb = this.eventLogRepo.createQueryBuilder('e');

        if (user_id) qb.andWhere('e.userId = :user_id', { user_id });
        if (group_id) qb.andWhere('e.groupId = :group_id', { group_id });
        if (event_type) qb.andWhere('e.eventType = :event_type', { event_type });
        if (event_subtype) qb.andWhere('e.eventSubtype = :event_subtype', { event_subtype });
        if (since) qb.andWhere('e.occurredAt >= :since', { since });

        qb.orderBy('e.occurredAt', 'DESC');
        qb.skip(offset).take(limit);

        const [events, count] = await qb.getManyAndCount();

        return {
            events: events.map(e => ({
                event_id: e.eventId,
                user_id: e.userId,
                group_id: e.groupId,
                event_type: e.eventType,
                event_subtype: e.eventSubtype,
                latitude: e.latitude,
                longitude: e.longitude,
                address: e.address,
                battery_level: e.batteryLevel,
                battery_is_charging: e.batteryIsCharging,
                network_type: e.networkType,
                app_version: e.appVersion,
                geofence_id: e.geofenceId,
                movement_session_id: e.movementSessionId,
                location_id: e.locationId,
                sos_id: e.sosId,
                event_data: e.eventData,
                occurred_at: e.occurredAt,
                created_at: e.createdAt,
            })),
            count,
        };
    }
}
