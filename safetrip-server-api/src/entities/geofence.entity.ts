import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_GEOFENCE — 지오펜스 (도메인 D)
 * DB 설계 v3.4 §4.12
 */
@Entity('tb_geofence')
@Index('idx_geofence_trip', ['tripId'])
export class Geofence {
    @PrimaryGeneratedColumn('uuid', { name: 'geofence_id' })
    geofenceId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'created_by', type: 'varchar', length: 128 })
    createdBy: string;

    @Column({ name: 'name', type: 'varchar', length: 100 })
    name: string;

    @Column({ name: 'fence_type', type: 'varchar', length: 20, default: 'circle' })
    fenceType: string; // 'circle' | 'polygon'

    @Column({ name: 'center_latitude', type: 'float', nullable: true })
    centerLatitude: number | null;

    @Column({ name: 'center_longitude', type: 'float', nullable: true })
    centerLongitude: number | null;

    @Column({ name: 'radius_meters', type: 'float', nullable: true })
    radiusMeters: number | null;

    @Column({ name: 'polygon_coordinates', type: 'jsonb', nullable: true })
    polygonCoordinates: any;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'alert_on_enter', type: 'boolean', default: true })
    alertOnEnter: boolean;

    @Column({ name: 'alert_on_exit', type: 'boolean', default: true })
    alertOnExit: boolean;

    /** v3.4: 시간 기반 활성화 */
    @Column({ name: 'active_start_time', type: 'time', nullable: true })
    activeStartTime: string | null;

    @Column({ name: 'active_end_time', type: 'time', nullable: true })
    activeEndTime: string | null;

    @Column({ name: 'active_days', type: 'jsonb', nullable: true })
    activeDays: number[] | null; // [0,1,2,3,4,5,6]

    /** v3.4: 중첩 허용 (중첩된 지오펜스의 부모 ID) */
    @Column({ name: 'parent_geofence_id', type: 'uuid', nullable: true })
    parentGeofenceId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_GEOFENCE_EVENT — 지오펜스 이벤트 (도메인 D)
 * DB 설계 v3.4 §4.13
 */
@Entity('tb_geofence_event')
@Index('idx_geofence_event_trip', ['tripId'])
export class GeofenceEvent {
    @PrimaryGeneratedColumn('uuid', { name: 'event_id' })
    eventId: string;

    @Column({ name: 'geofence_id', type: 'uuid' })
    geofenceId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'event_type', type: 'varchar', length: 10 })
    eventType: string; // 'enter' | 'exit'

    @Column({ name: 'latitude', type: 'float' })
    latitude: number;

    @Column({ name: 'longitude', type: 'float' })
    longitude: number;

    @Column({ name: 'dwell_time_seconds', type: 'int', nullable: true })
    dwellTimeSeconds: number | null;

    @CreateDateColumn({ name: 'occurred_at', type: 'timestamptz' })
    occurredAt: Date;
}

/**
 * TB_GEOFENCE_PENALTY — 지오펜스 위반 패널티 (도메인 D, v3.2 신규)
 * DB 설계 v3.4 §4.14
 */
@Entity('tb_geofence_penalty')
export class GeofencePenalty {
    @PrimaryGeneratedColumn('uuid', { name: 'penalty_id' })
    penaltyId: string;

    @Column({ name: 'event_id', type: 'uuid' })
    eventId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'penalty_type', type: 'varchar', length: 30 })
    penaltyType: string; // 'warning' | 'location_forced' | 'privilege_revoked'

    @Column({ name: 'penalty_reason', type: 'text', nullable: true })
    penaltyReason: string | null;

    @Column({ name: 'cumulative_violations', type: 'int', default: 1 })
    cumulativeViolations: number;

    @Column({ name: 'resolved_at', type: 'timestamptz', nullable: true })
    resolvedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
