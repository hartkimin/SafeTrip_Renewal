import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_GEOFENCE -- 지오펜스 (도메인 D)
 * DB 설계 v3.5.1 $4.14
 */
@Entity('tb_geofence')
@Index('idx_geofence_trip', ['tripId'])
export class Geofence {
    @PrimaryGeneratedColumn('uuid', { name: 'geofence_id' })
    geofenceId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'name', type: 'varchar', length: 200 })
    name: string;

    @Column({ name: 'latitude', type: 'double precision', nullable: true })
    latitude: number | null;

    @Column({ name: 'longitude', type: 'double precision', nullable: true })
    longitude: number | null;

    @Column({ name: 'radius_meters', type: 'int', default: 200 })
    radiusMeters: number;

    @Column({ name: 'geofence_type', type: 'varchar', length: 20, default: 'safe' })
    geofenceType: string; // 'safe' | 'watch' | 'danger'

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'created_by', type: 'varchar', length: 128, nullable: true })
    createdBy: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    // -- Backward-compat columns (not in SSOT but used by existing code) --

    @Column({ name: 'fence_type', type: 'varchar', length: 20, default: 'circle', select: false })
    fenceType: string;

    @Column({ name: 'center_latitude', type: 'float', nullable: true, select: false })
    centerLatitude: number | null;

    @Column({ name: 'center_longitude', type: 'float', nullable: true, select: false })
    centerLongitude: number | null;

    @Column({ name: 'polygon_coordinates', type: 'jsonb', nullable: true, select: false })
    polygonCoordinates: any;

    @Column({ name: 'alert_on_enter', type: 'boolean', default: true, select: false })
    alertOnEnter: boolean;

    @Column({ name: 'alert_on_exit', type: 'boolean', default: true, select: false })
    alertOnExit: boolean;

    @Column({ name: 'active_start_time', type: 'time', nullable: true, select: false })
    activeStartTime: string | null;

    @Column({ name: 'active_end_time', type: 'time', nullable: true, select: false })
    activeEndTime: string | null;

    @Column({ name: 'active_days', type: 'jsonb', nullable: true, select: false })
    activeDays: number[] | null;

    @Column({ name: 'parent_geofence_id', type: 'uuid', nullable: true, select: false })
    parentGeofenceId: string | null;
}

/**
 * TB_GEOFENCE_EVENT -- 지오펜스 이벤트 (도메인 D)
 * DB 설계 v3.4 $4.13
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
 * TB_GEOFENCE_PENALTY -- 지오펜스 위반 패널티 (도메인 D)
 * DB 설계 v3.4 $4.14
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
