import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index, Check } from 'typeorm';

/**
 * TB_LOCATION — 위치 기록 (도메인 E, 구 TB_LOCATION_LOG)
 * DB 설계 v3.4 §4.16 — PostGIS 확장 활용
 */
@Entity('tb_location')
@Index('idx_location_user_time', ['userId', 'recordedAt'])
@Index('idx_location_trip', ['tripId'])
export class Location {
    @PrimaryGeneratedColumn('uuid', { name: 'location_id' })
    locationId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'latitude', type: 'float' })
    latitude: number;

    @Column({ name: 'longitude', type: 'float' })
    longitude: number;

    @Column({ name: 'altitude', type: 'float', nullable: true })
    altitude: number | null;

    @Column({ name: 'accuracy', type: 'float', nullable: true })
    accuracy: number | null;

    @Column({ name: 'speed', type: 'float', nullable: true })
    speed: number | null;

    @Column({ name: 'heading', type: 'float', nullable: true })
    heading: number | null;

    @Column({ name: 'activity_type', type: 'varchar', length: 20, nullable: true })
    activityType: string | null; // 'still' | 'walking' | 'running' | 'vehicle'

    @Column({ name: 'movement_session_id', type: 'uuid', nullable: true })
    movementSessionId: string | null;

    @Column({ name: 'is_offline', type: 'boolean', default: false })
    isOffline: boolean;

    @Column({ name: 'battery_level', type: 'int', nullable: true })
    batteryLevel: number | null;

    @CreateDateColumn({ name: 'recorded_at', type: 'timestamptz' })
    recordedAt: Date;

    @Column({ name: 'server_received_at', type: 'timestamptz', nullable: true })
    serverReceivedAt: Date | null;
}

/**
 * TB_LOCATION_SHARING — 위치 공유 설정 (도메인 E)
 * DB 설계 v3.4 §4.15
 */
@Entity('tb_location_sharing')
@Index('idx_location_sharing_trip', ['tripId'])
export class LocationSharing {
    @PrimaryGeneratedColumn('uuid', { name: 'sharing_id' })
    sharingId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    /** v3.4: trip_id 추가 */
    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'is_sharing', type: 'boolean', default: true })
    isSharing: boolean;

    /** v3.4: 가시성 타입 */
    @Column({ name: 'visibility_type', type: 'varchar', length: 20, default: 'all' })
    visibilityType: string; // 'all' | 'admin_only' | 'specified'

    /** specified인 경우 대상 멤버 user_id */
    @Column({ name: 'target_user_id', type: 'varchar', length: 128, nullable: true })
    targetUserId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_LOCATION_SCHEDULE — 위치 공유 일정 (도메인 E, v3.4 신규)
 * DB 설계 v3.4 §4.15a
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
    dayOfWeek: number | null; // 0=일, 1=월, ... 6=토

    /** v3.4.1: 특정 일자에만 적용 */
    @Column({ name: 'specific_date', type: 'date', nullable: true })
    specificDate: Date | null;

    @Column({ name: 'start_time', type: 'time' })
    startTime: string;

    @Column({ name: 'end_time', type: 'time' })
    endTime: string;

    @Column({ name: 'is_sharing_on', type: 'boolean', default: true })
    isSharingOn: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_STAY_POINT — 체류 지점 (도메인 E)
 */
@Entity('tb_stay_point')
export class StayPoint {
    @PrimaryGeneratedColumn('uuid', { name: 'stay_point_id' })
    stayPointId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

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
 * TB_MOVEMENT_SESSION — 이동 세션 (도메인 E, v3.2 신규)
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
 * TB_SESSION_MAP_IMAGE — 이동 세션 지도 이미지 (도메인 E, v3.1 신규)
 */
@Entity('tb_session_map_image')
export class SessionMapImage {
    @PrimaryGeneratedColumn('uuid', { name: 'image_id' })
    imageId: string;

    @Column({ name: 'movement_session_id', type: 'uuid' })
    movementSessionId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'image_url', type: 'text' })
    imageUrl: string;

    @Column({ name: 'storage_type', type: 'varchar', length: 20, default: 'firebase' })
    storageType: string;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_PLANNED_ROUTE — 계획 경로 (도메인 E, v3.1 신규)
 */
@Entity('tb_planned_route')
export class PlannedRoute {
    @PrimaryGeneratedColumn('uuid', { name: 'route_id' })
    routeId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'route_name', type: 'varchar', length: 100, nullable: true })
    routeName: string | null;

    @Column({ name: 'waypoints', type: 'jsonb', nullable: true })
    waypoints: any;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_ROUTE_DEVIATION — 경로 이탈 감지 (도메인 E, v3.1 신규)
 */
@Entity('tb_route_deviation')
export class RouteDeviation {
    @PrimaryGeneratedColumn('uuid', { name: 'deviation_id' })
    deviationId: string;

    @Column({ name: 'route_id', type: 'uuid' })
    routeId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'latitude', type: 'float' })
    latitude: number;

    @Column({ name: 'longitude', type: 'float' })
    longitude: number;

    @Column({ name: 'distance_meters', type: 'float' })
    distanceMeters: number;

    @Column({ name: 'severity', type: 'varchar', length: 20, default: 'low' })
    severity: string; // 'low' | 'medium' | 'high' | 'critical'

    @CreateDateColumn({ name: 'detected_at', type: 'timestamptz' })
    detectedAt: Date;
}
