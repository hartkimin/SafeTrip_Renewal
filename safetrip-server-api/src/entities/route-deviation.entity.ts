import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

/**
 * TB_ROUTE_DEVIATION — 경로 이탈 감지 로그 (도메인 E)
 * DB 설계 v3.4 §4.18 — Route Deviation Detection
 */
@Entity('tb_route_deviation')
@Index('idx_route_deviations_route', ['routeId'])
@Index('idx_route_deviations_trip', ['tripId'])
@Index('idx_route_deviations_user', ['userId'])
export class RouteDeviation {
    @PrimaryGeneratedColumn('uuid', { name: 'deviation_id' })
    deviationId: string;

    @Column({ name: 'route_id', type: 'uuid' })
    routeId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    /** 이탈 위치 */
    @Column({ name: 'latitude', type: 'float' })
    latitude: number;

    @Column({ name: 'longitude', type: 'float' })
    longitude: number;

    /** 계획된 경로로부터의 거리 (미터) */
    @Column({ name: 'distance_meters', type: 'float' })
    distanceMeters: number;

    /** 이탈 상태 */
    @Column({ name: 'deviation_status', type: 'varchar', length: 20, default: 'active' })
    deviationStatus: string; // 'active' | 'resolved' | 'ignored'

    /** 위험도 */
    @Column({ name: 'severity', type: 'varchar', length: 20, default: 'low' })
    severity: string; // 'low' | 'medium' | 'high' | 'critical'

    /** 이탈 시간 */
    @Column({ name: 'started_at', type: 'timestamptz' })
    startedAt: Date;

    @Column({ name: 'ended_at', type: 'timestamptz', nullable: true })
    endedAt: Date | null;

    /** 이탈 지속 시간 (초) */
    @Column({ name: 'duration', type: 'int', nullable: true })
    duration: number | null;

    /** 알림 여부 */
    @Column({ name: 'guardian_notified', type: 'boolean', default: false })
    guardianNotified: boolean;

    @Column({ name: 'notification_sent_at', type: 'timestamptz', nullable: true })
    notificationSentAt: Date | null;

    /** 연속 이탈 횟수 (3회 이상 시 경고 알림) */
    @Column({ name: 'consecutive_count', type: 'int', default: 1 })
    consecutiveCount: number;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt: Date;
}
