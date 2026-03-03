import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    UpdateDateColumn,
    ManyToOne,
    JoinColumn
} from 'typeorm';
import { Trip } from './trip.entity';
import { User } from './user.entity';

@Entity('tb_schedule')
export class Schedule {
    @PrimaryGeneratedColumn('uuid', { name: 'schedule_id' })
    scheduleId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @ManyToOne(() => Trip)
    @JoinColumn({ name: 'trip_id' })
    trip: Trip;

    @Column({ name: 'schedule_name', type: 'varchar', length: 200, nullable: true })
    scheduleName: string;

    @Column({ name: 'schedule_date', type: 'date', nullable: true })
    scheduleDate: Date;

    @Column({ name: 'start_time', type: 'time', nullable: true })
    startTime: string;

    @Column({ name: 'end_time', type: 'time', nullable: true })
    endTime: string;

    @Column({ name: 'location_name', type: 'varchar', length: 200, nullable: true })
    locationName: string;

    @Column({ name: 'location_address', type: 'text', nullable: true })
    locationAddress: string;

    @Column({ name: 'location_lat', type: 'double precision', nullable: true })
    locationLat: number;

    @Column({ name: 'location_lng', type: 'double precision', nullable: true })
    locationLng: number;

    @Column({ name: 'notes', type: 'text', nullable: true })
    notes: string;

    @Column({ name: 'order_index', type: 'int', nullable: true })
    orderIndex: number;

    @Column({ name: 'created_by', type: 'uuid', nullable: true })
    createdBy: string;

    @ManyToOne(() => User)
    @JoinColumn({ name: 'created_by' })
    creator: User;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date;
}
