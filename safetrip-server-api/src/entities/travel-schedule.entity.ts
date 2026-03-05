import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
    DeleteDateColumn,
} from 'typeorm';

/**
 * TB_TRAVEL_SCHEDULE -- 고급 일정 (도메인 D)
 * DB 설계 v3.5.1 $4.13
 */
@Entity('tb_travel_schedule')
export class TravelSchedule {
    @PrimaryGeneratedColumn('uuid', { name: 'travel_schedule_id' })
    travelScheduleId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'schedule_date', type: 'date', nullable: true })
    scheduleDate: Date | null;

    @Column({ name: 'title', type: 'varchar', length: 200, nullable: true })
    title: string | null;

    @Column({ name: 'description', type: 'text', nullable: true })
    description: string | null;

    @Column({ name: 'location', type: 'varchar', length: 200, nullable: true })
    location: string | null;

    @Column({ name: 'estimated_cost', type: 'decimal', precision: 10, scale: 2, nullable: true })
    estimatedCost: number | null;

    @Column({ name: 'booking_reference', type: 'varchar', length: 100, nullable: true })
    bookingReference: string | null;

    @Column({ name: 'geofence_id', type: 'uuid', nullable: true })
    geofenceId: string | null;

    @Column({ name: 'created_by', type: 'varchar', length: 128, nullable: true })
    createdBy: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    // -- Backward-compat columns (not in SSOT but used by existing code) --

    @Column({ name: 'schedule_type', type: 'varchar', length: 50, nullable: true })
    scheduleType: string;

    @Column({ name: 'start_time', type: 'timestamptz', nullable: true })
    startTime: Date | null;

    @Column({ name: 'end_time', type: 'timestamptz', nullable: true })
    endTime: Date | null;

    @Column({ name: 'all_day', type: 'boolean', default: false, select: false })
    allDay: boolean;

    @Column({ name: 'location_name', type: 'varchar', length: 300, nullable: true, select: false })
    locationName: string | null;

    @Column({ name: 'location_address', type: 'text', nullable: true, select: false })
    locationAddress: string | null;

    @Column({ name: 'location_lat', type: 'double precision', nullable: true, select: false })
    locationLat: number | null;

    @Column({ name: 'location_lng', type: 'double precision', nullable: true, select: false })
    locationLng: number | null;

    @Column({ name: 'participants', type: 'jsonb', nullable: true, select: false })
    participants: any;

    @Column({ name: 'currency_code', type: 'varchar', length: 3, nullable: true, select: false })
    currencyCode: string | null;

    @Column({ name: 'booking_status', type: 'varchar', length: 30, nullable: true, select: false })
    bookingStatus: string | null;

    @Column({ name: 'booking_url', type: 'text', nullable: true, select: false })
    bookingUrl: string | null;

    @Column({ name: 'reminder_enabled', type: 'boolean', default: false, select: false })
    reminderEnabled: boolean;

    @Column({ name: 'reminder_time', type: 'interval', nullable: true, select: false })
    reminderTime: any;

    @Column({ name: 'attachments', type: 'jsonb', nullable: true, select: false })
    attachments: any;

    @Column({ name: 'is_completed', type: 'boolean', default: false, select: false })
    isCompleted: boolean;

    @Column({ name: 'completed_at', type: 'timestamptz', nullable: true, select: false })
    completedAt: Date | null;

    @Column({ name: 'timezone', type: 'varchar', length: 50, nullable: true, select: false })
    timezone: string | null;

    @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
    deletedAt: Date | null;
}
