import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
} from 'typeorm';

/**
 * TB_SCHEDULE -- 기본 일정 (도메인 D)
 * DB 설계 v3.5.1 $4.12
 */
@Entity('tb_schedule')
export class Schedule {
    @PrimaryGeneratedColumn('uuid', { name: 'schedule_id' })
    scheduleId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'title', type: 'varchar', length: 200 })
    title: string;

    @Column({ name: 'description', type: 'text', nullable: true })
    description: string | null;

    @Column({ name: 'schedule_date', type: 'date', nullable: true })
    scheduleDate: Date | null;

    @Column({ name: 'start_time', type: 'timestamptz', nullable: true })
    startTime: Date | null;

    @Column({ name: 'end_time', type: 'timestamptz', nullable: true })
    endTime: Date | null;

    @Column({ name: 'location', type: 'varchar', length: 200, nullable: true })
    location: string | null;

    @Column({ name: 'location_lat', type: 'double precision', nullable: true })
    locationLat: number | null;

    @Column({ name: 'location_lng', type: 'double precision', nullable: true })
    locationLng: number | null;

    @Column({ name: 'all_day', type: 'boolean', default: false })
    allDay: boolean;

    @Column({ name: 'order_index', type: 'int', default: 0 })
    orderIndex: number;

    @Column({ name: 'created_by', type: 'varchar', length: 128, nullable: true })
    createdBy: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    // -- Backward-compat columns (not in SSOT but used by existing code) --

    @Column({ name: 'schedule_name', type: 'varchar', length: 200, nullable: true, select: false })
    scheduleName: string | null;

    @Column({ name: 'location_name', type: 'varchar', length: 200, nullable: true, select: false })
    locationName: string | null;

    @Column({ name: 'location_address', type: 'text', nullable: true, select: false })
    locationAddress: string | null;

    @Column({ name: 'notes', type: 'text', nullable: true, select: false })
    notes: string | null;
}
