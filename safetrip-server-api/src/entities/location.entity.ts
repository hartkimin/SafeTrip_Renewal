import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index, Check } from 'typeorm';

/**
 * TB_LOCATION -- 위치 기록 (도메인 E)
 * DB 설계 v3.5.1 $4.16
 */
@Entity('tb_location')
@Index('idx_location_user_time', ['userId', 'recordedAt'])
@Index('idx_location_trip', ['tripId'])
export class Location {
    @PrimaryGeneratedColumn('uuid', { name: 'location_id' })
    locationId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'latitude', type: 'double precision' })
    latitude: number;

    @Column({ name: 'longitude', type: 'double precision' })
    longitude: number;

    @Column({ name: 'accuracy', type: 'double precision', nullable: true })
    accuracy: number | null;

    @Column({ name: 'speed', type: 'double precision', nullable: true })
    speed: number | null;

    @Column({ name: 'bearing', type: 'double precision', nullable: true })
    bearing: number | null;

    @Column({ name: 'altitude', type: 'double precision', nullable: true })
    altitude: number | null;

    @Column({ name: 'battery_level', type: 'int', nullable: true })
    batteryLevel: number | null;

    @Column({ name: 'network_type', type: 'varchar', length: 20, nullable: true })
    networkType: string | null;

    @Column({ name: 'is_sharing', type: 'boolean', default: true })
    isSharing: boolean;

    @Column({ name: 'motion_state', type: 'varchar', length: 20, nullable: true })
    motionState: string | null;

    @Column({ name: 'provider', type: 'varchar', length: 20, nullable: true })
    provider: string | null;

    @Column({ name: 'movement_session_id', type: 'uuid', nullable: true })
    movementSessionId: string | null;

    @Column({ name: 'recorded_at', type: 'timestamptz' })
    recordedAt: Date;

    @Column({ name: 'server_received_at', type: 'timestamptz', nullable: true })
    serverReceivedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    // -- Backward-compat columns (not in SSOT but used by existing code) --

    @Column({ name: 'heading', type: 'float', nullable: true, select: false })
    heading: number | null;

    @Column({ name: 'activity_type', type: 'varchar', length: 20, nullable: true, select: false })
    activityType: string | null;

    @Column({ name: 'is_offline', type: 'boolean', default: false, select: false })
    isOffline: boolean;
}

/**
 * TB_LOCATION_SHARING -- 위치 공유 설정 (도메인 E)
 * DB 설계 v3.5.1 $4.15
 */
@Entity('tb_location_sharing')
@Index('idx_location_sharing_trip', ['tripId'])
export class LocationSharing {
    @PrimaryGeneratedColumn('uuid', { name: 'location_sharing_id' })
    locationSharingId: string;

    /** Backward-compat alias for locationSharingId */
    get sharingId(): string { return this.locationSharingId; }

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'visibility_type', type: 'varchar', length: 20, default: 'all' })
    visibilityType: string; // 'all' | 'admin_only' | 'specified'

    @Column({ name: 'visibility_member_ids', type: 'jsonb', nullable: true })
    visibilityMemberIds: any;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    // -- Backward-compat columns --

    @Column({ name: 'is_sharing', type: 'boolean', default: true, select: false })
    isSharing: boolean;

    @Column({ name: 'target_user_id', type: 'varchar', length: 128, nullable: true, select: false })
    targetUserId: string | null;
}

/**
 * TB_LOCATION_SCHEDULE -- 위치 공유 일정 (도메인 E)
 * DB 설계 v3.5.1 $4.15a
 */
@Entity('tb_location_schedule')
@Check(`("day_of_week" IS NOT NULL AND "specific_date" IS NULL) OR ("day_of_week" IS NULL AND "specific_date" IS NOT NULL) OR ("day_of_week" IS NULL AND "specific_date" IS NULL)`)
export class LocationSchedule {
    @PrimaryGeneratedColumn('uuid', { name: 'schedule_id' })
    scheduleId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'day_of_week', type: 'int', nullable: true })
    dayOfWeek: number | null; // 0=Sun, 1=Mon, ... 6=Sat (NULL = daily)

    /** v3.5.1: 특정 일자에만 적용 */
    @Column({ name: 'specific_date', type: 'date', nullable: true })
    specificDate: Date | null;

    @Column({ name: 'share_start', type: 'time' })
    startTime: string; // TypeScript name: startTime, DB column: share_start

    @Column({ name: 'share_end', type: 'time' })
    endTime: string; // TypeScript name: endTime, DB column: share_end

    @Column({ name: 'is_sharing_on', type: 'boolean', default: true })
    isSharingOn: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_STAY_POINT -- 체류 지점 (도메인 E)
 */
@Entity('tb_stay_point')
export class StayPoint {
    @PrimaryGeneratedColumn('uuid', { name: 'stay_point_id' })
    stayPointId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'latitude', type: 'float' })
    latitude: number;

    @Column({ name: 'longitude', type: 'float' })
    longitude: number;

    @Column({ name: 'arrived_at', type: 'timestamptz' })
    arrivedAt: Date;

    @Column({ name: 'left_at', type: 'timestamptz', nullable: true })
    leftAt: Date | null;

    @Column({ name: 'duration_minutes', type: 'int', nullable: true })
    durationMinutes: number | null;

    @Column({ name: 'place_name', type: 'varchar', length: 200, nullable: true })
    placeName: string | null;
}

/**
 * TB_MOVEMENT_SESSION -- 이동 세션 (도메인 E)
 */
@Entity('tb_movement_session')
export class MovementSession {
    @PrimaryGeneratedColumn('uuid', { name: 'session_id' })
    sessionId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'start_time', type: 'timestamptz', nullable: true })
    startTime: Date | null;

    @Column({ name: 'end_time', type: 'timestamptz', nullable: true })
    endTime: Date | null;

    @Column({ name: 'is_completed', type: 'boolean', default: false })
    isCompleted: boolean;
}

/**
 * TB_SESSION_MAP_IMAGE -- 이동 세션 지도 이미지 (도메인 E)
 */
@Entity('tb_session_map_image')
export class SessionMapImage {
    @PrimaryGeneratedColumn('uuid', { name: 'image_id' })
    imageId: string;

    @Column({ name: 'movement_session_id', type: 'uuid' })
    movementSessionId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'image_url', type: 'text' })
    imageUrl: string;

    @Column({ name: 'storage_type', type: 'varchar', length: 20, default: 'firebase' })
    storageType: string;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
