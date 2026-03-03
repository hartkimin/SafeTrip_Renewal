import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, Index, ManyToOne, JoinColumn } from 'typeorm';

@Entity('tb_event_log')
export class EventLog {
    @PrimaryGeneratedColumn('uuid', { name: 'event_id' })
    eventId: string;

    @Index()
    @Column({ name: 'user_id' })
    userId: string;

    @Index()
    @Column({ name: 'group_id', nullable: true })
    groupId: string;

    @Index()
    @Column({ name: 'event_type' })
    eventType: string;

    @Column({ name: 'event_subtype', nullable: true })
    eventSubtype: string;

    @Column('decimal', { precision: 10, scale: 7, nullable: true })
    latitude: number;

    @Column('decimal', { precision: 10, scale: 7, nullable: true })
    longitude: number;

    @Column({ nullable: true })
    address: string;

    @Column({ name: 'battery_level', nullable: true })
    batteryLevel: number;

    @Column({ name: 'battery_is_charging', nullable: true })
    batteryIsCharging: boolean;

    @Column({ name: 'network_type', nullable: true })
    networkType: string;

    @Column({ name: 'app_version', nullable: true })
    appVersion: string;

    @Column({ name: 'geofence_id', nullable: true })
    geofenceId: string;

    @Column({ name: 'movement_session_id', nullable: true })
    movementSessionId: string;

    @Column({ name: 'location_id', nullable: true })
    locationId: string;

    @Column({ name: 'sos_id', nullable: true })
    sosId: string;

    @Column('jsonb', { name: 'event_data', nullable: true })
    eventData: any;

    @Column({ name: 'occurred_at', type: 'timestamp with time zone', nullable: true })
    occurredAt: Date;

    @CreateDateColumn({ name: 'created_at', type: 'timestamp with time zone' })
    createdAt: Date;
}
