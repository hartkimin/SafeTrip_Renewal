import {
    Injectable,
    NotFoundException,
    BadRequestException,
    ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { ScheduleHistory } from '../../entities/schedule-history.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';

@Injectable()
export class SchedulesService {
    constructor(
        @InjectRepository(TravelSchedule)
        private scheduleRepo: Repository<TravelSchedule>,
        @InjectRepository(ScheduleHistory)
        private historyRepo: Repository<ScheduleHistory>,
        @InjectRepository(GroupMember)
        private memberRepo: Repository<GroupMember>,
        @InjectRepository(Trip)
        private tripRepo: Repository<Trip>,
        private dataSource: DataSource,
    ) {}

    /**
     * Check if user has edit permission on schedules for the given trip.
     * §5.1: 캡틴/크루장만 CUD 가능 — crew와 guardian은 불가.
     */
    async checkEditPermission(tripId: string, userId: string): Promise<GroupMember> {
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });

        if (!member) {
            throw new ForbiddenException('여행 멤버가 아닙니다');
        }

        // §5.1: Only captain and crew_chief can create/update/delete schedules
        if (member.memberRole !== 'captain' && member.memberRole !== 'crew_chief') {
            throw new ForbiddenException('일정 수정 권한이 없습니다 (캡틴/크루장만 가능)');
        }

        return member;
    }

    /**
     * GET schedules for a trip, optionally filtered by date.
     * Returns all non-deleted schedules ordered by start_time ASC.
     */
    async getSchedulesByDate(tripId: string, date?: string): Promise<TravelSchedule[]> {
        const qb = this.scheduleRepo
            .createQueryBuilder('s')
            .where('s.trip_id = :tripId', { tripId })
            .andWhere('s.deleted_at IS NULL');

        if (date) {
            qb.andWhere('s.schedule_date = :date', { date });
        }

        qb.orderBy('s.start_time', 'ASC', 'NULLS LAST');
        qb.addOrderBy('s.created_at', 'ASC');

        return qb.getMany();
    }

    /**
     * GET distinct schedule dates for a trip.
     * Returns sorted array of date strings (YYYY-MM-DD).
     */
    async getScheduleDates(tripId: string): Promise<string[]> {
        const rows = await this.scheduleRepo
            .createQueryBuilder('s')
            .select('DISTINCT s.schedule_date::text', 'date')
            .where('s.trip_id = :tripId', { tripId })
            .andWhere('s.deleted_at IS NULL')
            .andWhere('s.schedule_date IS NOT NULL')
            .orderBy('s.schedule_date', 'ASC')
            .getRawMany();

        return rows.map((r) => r.date);
    }

    /**
     * POST create a new schedule.
     * Validates: trip exists, trip not completed, date within trip range, end > start.
     */
    async createSchedule(
        tripId: string,
        userId: string,
        data: {
            title: string;
            schedule_date: string;
            schedule_type?: string;
            start_time?: string;
            end_time?: string;
            all_day?: boolean;
            description?: string;
            location?: string;
            location_name?: string;
            location_address?: string;
            location_lat?: number;
            location_lng?: number;
            estimated_cost?: number;
            currency_code?: string;
            booking_reference?: string;
            booking_status?: string;
            booking_url?: string;
            timezone?: string;
        },
    ): Promise<TravelSchedule> {
        // Validate trip exists and is not completed
        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) {
            throw new NotFoundException('Trip not found');
        }
        if (trip.status === 'completed') {
            throw new BadRequestException('Cannot add schedules to a completed trip');
        }

        // Validate date is within trip range
        const scheduleDate = new Date(data.schedule_date);
        const tripStart = new Date(trip.startDate);
        const tripEnd = new Date(trip.endDate);
        if (scheduleDate < tripStart || scheduleDate > tripEnd) {
            throw new BadRequestException(
                'Schedule date must be within the trip date range',
            );
        }

        // Validate end_time > start_time if both provided
        if (data.start_time && data.end_time) {
            const start = new Date(data.start_time);
            const end = new Date(data.end_time);
            if (end <= start) {
                throw new BadRequestException('end_time must be after start_time');
            }
        }

        // Check edit permission
        await this.checkEditPermission(tripId, userId);

        const schedule = this.scheduleRepo.create({
            tripId,
            groupId: trip.groupId,
            scheduleDate: new Date(data.schedule_date),
            title: data.title,
            description: data.description || null,
            location: data.location || null,
            scheduleType: data.schedule_type || 'other',
            startTime: data.start_time ? new Date(data.start_time) : null,
            endTime: data.end_time ? new Date(data.end_time) : null,
            allDay: data.all_day || false,
            locationName: data.location_name || null,
            locationAddress: data.location_address || null,
            locationLat: data.location_lat ?? null,
            locationLng: data.location_lng ?? null,
            estimatedCost: data.estimated_cost ?? null,
            currencyCode: data.currency_code || null,
            bookingReference: data.booking_reference || null,
            bookingStatus: data.booking_status || null,
            bookingUrl: data.booking_url || null,
            timezone: data.timezone || null,
            createdBy: userId,
        });

        return this.scheduleRepo.save(schedule);
    }

    /**
     * PATCH update a schedule.
     * Tracks field-level changes in tb_schedule_history within a transaction.
     */
    async updateSchedule(
        tripId: string,
        scheduleId: string,
        userId: string,
        data: Record<string, any>,
    ): Promise<TravelSchedule> {
        await this.checkEditPermission(tripId, userId);

        const schedule = await this.scheduleRepo.findOne({
            where: { travelScheduleId: scheduleId, tripId },
        });
        if (!schedule) {
            throw new NotFoundException('Schedule not found');
        }
        if (schedule.deletedAt) {
            throw new NotFoundException('Schedule has been deleted');
        }

        // Validate end_time > start_time if updating times
        const newStart = data.start_time
            ? new Date(data.start_time)
            : schedule.startTime;
        const newEnd = data.end_time ? new Date(data.end_time) : schedule.endTime;
        if (newStart && newEnd && newEnd <= newStart) {
            throw new BadRequestException('end_time must be after start_time');
        }

        // Validate schedule_date within trip range if changing date
        if (data.schedule_date) {
            const trip = await this.tripRepo.findOne({ where: { tripId } });
            if (trip) {
                const scheduleDate = new Date(data.schedule_date);
                const tripStart = new Date(trip.startDate);
                const tripEnd = new Date(trip.endDate);
                if (scheduleDate < tripStart || scheduleDate > tripEnd) {
                    throw new BadRequestException(
                        'Schedule date must be within the trip date range',
                    );
                }
            }
        }

        // Map of API field names to entity property names
        const fieldMap: Record<string, string> = {
            title: 'title',
            description: 'description',
            location: 'location',
            schedule_date: 'scheduleDate',
            schedule_type: 'scheduleType',
            start_time: 'startTime',
            end_time: 'endTime',
            all_day: 'allDay',
            location_name: 'locationName',
            location_address: 'locationAddress',
            location_lat: 'locationLat',
            location_lng: 'locationLng',
            estimated_cost: 'estimatedCost',
            currency_code: 'currencyCode',
            booking_reference: 'bookingReference',
            booking_status: 'bookingStatus',
            booking_url: 'bookingUrl',
            timezone: 'timezone',
            is_completed: 'isCompleted',
        };

        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            // Track changes and build update object
            const historyEntries: Partial<ScheduleHistory>[] = [];

            for (const [apiField, entityProp] of Object.entries(fieldMap)) {
                if (data[apiField] === undefined) continue;

                const oldVal = (schedule as any)[entityProp];
                const newVal = data[apiField];

                // Convert values to comparable strings
                const oldStr = oldVal === null || oldVal === undefined
                    ? null
                    : String(oldVal);
                const newStr = newVal === null || newVal === undefined
                    ? null
                    : String(newVal);

                if (oldStr !== newStr) {
                    historyEntries.push({
                        scheduleId,
                        modifiedBy: userId,
                        fieldName: apiField,
                        oldValue: oldStr,
                        newValue: newStr,
                    });

                    // Update the entity value
                    if (entityProp === 'startTime' || entityProp === 'endTime') {
                        (schedule as any)[entityProp] = newVal ? new Date(newVal) : null;
                    } else if (entityProp === 'scheduleDate') {
                        (schedule as any)[entityProp] = new Date(newVal);
                    } else {
                        (schedule as any)[entityProp] = newVal;
                    }
                }
            }

            // Save history entries
            if (historyEntries.length > 0) {
                await queryRunner.manager.save(ScheduleHistory, historyEntries);
            }

            // Save updated schedule
            const updated = await queryRunner.manager.save(TravelSchedule, schedule);

            await queryRunner.commitTransaction();
            return updated;
        } catch (err) {
            await queryRunner.rollbackTransaction();
            throw err;
        } finally {
            await queryRunner.release();
        }
    }

    /**
     * DELETE (soft) a schedule.
     * Sets deleted_at timestamp instead of removing the row.
     */
    async deleteSchedule(
        tripId: string,
        scheduleId: string,
        userId: string,
    ): Promise<void> {
        await this.checkEditPermission(tripId, userId);

        const schedule = await this.scheduleRepo.findOne({
            where: { travelScheduleId: scheduleId, tripId },
        });
        if (!schedule) {
            throw new NotFoundException('Schedule not found');
        }

        await this.scheduleRepo.softDelete(scheduleId);
    }

    /**
     * GET overlapping schedules for conflict detection.
     * Finds schedules on the same date whose time ranges overlap.
     */
    async checkConflicts(
        tripId: string,
        date: string,
        startTime: string,
        endTime: string,
        excludeId?: string,
    ): Promise<TravelSchedule[]> {
        const qb = this.scheduleRepo
            .createQueryBuilder('s')
            .where('s.trip_id = :tripId', { tripId })
            .andWhere('s.schedule_date = :date', { date })
            .andWhere('s.deleted_at IS NULL')
            .andWhere('s.all_day = false')
            .andWhere('s.start_time IS NOT NULL')
            .andWhere('s.end_time IS NOT NULL')
            .andWhere('s.start_time < :endTime', { endTime })
            .andWhere('s.end_time > :startTime', { startTime });

        if (excludeId) {
            qb.andWhere('s.travel_schedule_id != :excludeId', { excludeId });
        }

        return qb.getMany();
    }
}
