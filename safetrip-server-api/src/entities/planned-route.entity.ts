import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

/**
 * TB_PLANNED_ROUTE — 계획된 경로 (도메인 E)
 * DB 설계 v3.4 §4.17 — Route Deviation Detection을 위한 사전 계획 경로
 */
@Entity('tb_planned_route')
@Index('idx_planned_routes_trip', ['tripId'])
@Index('idx_planned_routes_user', ['userId'])
export class PlannedRoute {
    @PrimaryGeneratedColumn('uuid', { name: 'route_id' })
    routeId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'route_name', type: 'varchar', length: 200, nullable: true })
    routeName: string | null;

    @Column({ name: 'start_location', type: 'varchar', length: 200 })
    startLocation: string;

    @Column({ name: 'end_location', type: 'varchar', length: 200 })
    endLocation: string;

    @Column({ name: 'start_latitude', type: 'float' })
    startLatitude: number;

    @Column({ name: 'start_longitude', type: 'float' })
    startLongitude: number;

    @Column({ name: 'end_latitude', type: 'float' })
    endLatitude: number;

    @Column({ name: 'end_longitude', type: 'float' })
    endLongitude: number;

    /** 경로 데이터 (GeoJSON LineString 또는 좌표 배열) */
    @Column({ name: 'route_path', type: 'jsonb' })
    routePath: any;

    /** 경유지 목록 */
    @Column({ name: 'waypoints', type: 'jsonb', nullable: true })
    waypoints: any;

    /** 전체 경로 거리 (km) */
    @Column({ name: 'total_distance', type: 'float', nullable: true })
    totalDistance: number | null;

    /** 예상 소요 시간 (분) */
    @Column({ name: 'estimated_duration', type: 'int', nullable: true })
    estimatedDuration: number | null;

    /** 이탈 감지 임계값 (미터, 기본 100m) */
    @Column({ name: 'deviation_threshold', type: 'int', default: 100 })
    deviationThreshold: number;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    /** 일정 시간 */
    @Column({ name: 'scheduled_start', type: 'timestamptz', nullable: true })
    scheduledStart: Date | null;

    @Column({ name: 'scheduled_end', type: 'timestamptz', nullable: true })
    scheduledEnd: Date | null;

    /** PostGIS: 경로 이탈 감지 최적화용 geometry (LineString) */
    @Column({
        type: 'geometry',
        spatialFeatureType: 'LineString',
        srid: 4326,
        nullable: true,
    })
    @Index('idx_planned_route_geom', { spatial: true })
    geometry: any;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt: Date;

    @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
    deletedAt: Date | null;
}
