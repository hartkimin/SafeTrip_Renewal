import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
    DeleteDateColumn,
    ManyToOne,
    JoinColumn
} from 'typeorm';
import { Trip } from './trip.entity';
import { Group } from './group.entity';
import { User } from './user.entity';
import { Geofence } from './geofence.entity';

@Entity('tb_travel_schedule')
export class TravelSchedule {
    @PrimaryGeneratedColumn('uuid', { name: 'schedule_id' })
    scheduleId: string;

    @Column({ name: 'group_id', type: 'uuid' })
    groupId: string;

    @ManyToOne(() => Group)
    @JoinColumn({ name: 'group_id' })
    group: Group;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @ManyToOne(() => Trip)
    @JoinColumn({ name: 'trip_id' })
    trip: Trip;

    @Column({ name: 'created_by', type: 'uuid' })
    createdBy: string;

    @ManyToOne(() => User)
    @JoinColumn({ name: 'created_by' })
    creator: User;

    @Column({ name: 'title', type: 'varchar', length: 300 })
    title: string;

    @Column({ name: 'description', type: 'text', nullable: true })
    description: string;

    @Column({ name: 'schedule_type', type: 'varchar', length: 50, nullable: true })
    scheduleType: string;

    @Column({ name: 'start_time', type: 'timestamptz' })
    startTime: Date;

    @Column({ name: 'end_time', type: 'timestamptz', nullable: true })
    endTime: Date;

    @Column({ name: 'all_day', type: 'boolean', default: false })
    allDay: boolean;

    @Column({ name: 'location_name', type: 'varchar', length: 300, nullable: true })
    locationName: string;

    @Column({ name: 'location_address', type: 'text', nullable: true })
    locationAddress: string;

    @Column({ name: 'location_lat', type: 'double precision', nullable: true })
    locationLat: number;

    @Column({ name: 'location_lng', type: 'double precision', nullable: true })
    locationLng: number;

    // TODO: Add spatial integration if required via geometry

    @Column({ name: 'participants', type: 'jsonb', nullable: true })
    participants: any;

    @Column({ name: 'estimated_cost', type: 'decimal', precision: 12, scale: 2, nullable: true })
    estimatedCost: number;

    @Column({ name: 'currency_code', type: 'varchar', length: 3, nullable: true })
    currencyCode: string;

    @Column({ name: 'booking_reference', type: 'varchar', length: 100, nullable: true })
    bookingReference: string;

    @Column({ name: 'booking_status', type: 'varchar', length: 30, nullable: true })
    bookingStatus: string;

    @Column({ name: 'booking_url', type: 'text', nullable: true })
    bookingUrl: string;

    @Column({ name: 'reminder_enabled', type: 'boolean', default: false })
    reminderEnabled: boolean;

    @Column({ name: 'reminder_time', type: 'interval', nullable: true })
    reminderTime: any;

    @Column({ name: 'attachments', type: 'jsonb', nullable: true })
    attachments: any;

    @Column({ name: 'is_completed', type: 'boolean', default: false })
    isCompleted: boolean;

    @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
    completedAt: Date;

    @Column({ name: 'timezone', type: 'varchar', length: 50, nullable: true })
    timezone: string;

    @Column({ name: 'geofence_id', type: 'uuid', nullable: true })
    geofenceId: string;

    @ManyToOne(() => Geofence)
    @JoinColumn({ name: 'geofence_id' })
    geofence: Geofence;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date;

    @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
    deletedAt: Date;
}
