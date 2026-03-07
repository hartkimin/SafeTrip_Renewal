import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

/**
 * TB_AI_USAGE — AI 기능 사용 기록 및 제한 관리
 */
@Entity('tb_ai_usage')
@Index('idx_ai_usage_user_date', ['userId', 'usageDate'])
export class AiUsage {
    @PrimaryGeneratedColumn('uuid', { name: 'usage_id' })
    usageId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    /** 사용 날짜 (YYYY-MM-DD) — 일일 제한 체크용 */
    @Column({ name: 'usage_date', type: 'date' })
    usageDate: Date;

    /** 기능 유형: 'recommendation' | 'optimization' | 'chat' | 'briefing' | 'intelligence' */
    @Column({ name: 'feature_type', type: 'varchar', length: 30 })
    featureType: string;

    /** 사용 횟수 */
    @Column({ name: 'use_count', type: 'int', default: 0 })
    useCount: number;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt: Date;
}

/**
 * TB_AI_USAGE_LOG — AI 사용 이력 건별 로그
 * DOC-T3-AIF-026 §12.1
 */
@Entity('tb_ai_usage_log')
@Index('idx_ai_usage_log_user', ['userId'])
@Index('idx_ai_usage_log_trip', ['tripId'])
@Index('idx_ai_usage_log_type', ['aiType', 'featureName'])
@Index('idx_ai_usage_log_expires', ['expiresAt'])
export class AiUsageLog {
    @PrimaryGeneratedColumn('uuid', { name: 'log_id' })
    logId: string;

    @Column({ name: 'user_id', type: 'uuid', nullable: true })
    userId: string | null;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'ai_type', type: 'varchar', length: 20 })
    aiType: string;

    @Column({ name: 'feature_name', type: 'varchar', length: 50 })
    featureName: string;

    @Column({ name: 'model_used', type: 'varchar', length: 50, nullable: true })
    modelUsed: string | null;

    @Column({ name: 'is_cached', type: 'boolean', default: false })
    isCached: boolean = false;

    @Column({ name: 'is_fallback', type: 'boolean', default: false })
    isFallback: boolean = false;

    @Column({ name: 'fallback_reason', type: 'varchar', length: 100, nullable: true })
    fallbackReason: string | null;

    @Column({ name: 'latency_ms', type: 'int', nullable: true })
    latencyMs: number | null;

    @Column({ name: 'is_minor_user', type: 'boolean', default: false })
    isMinorUser: boolean = false;

    @Column({ name: 'privacy_level', type: 'varchar', length: 20, nullable: true })
    privacyLevel: string | null;

    @Column({ name: 'feedback', type: 'smallint', nullable: true })
    feedback: number | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;
}

/**
 * TB_AI_SUBSCRIPTION — AI 구독 정보
 * DOC-T3-AIF-026 §12.2
 */
@Entity('tb_ai_subscription')
@Index('idx_ai_subscription_user', ['userId'])
@Index('idx_ai_subscription_status', ['status', 'expiresAt'])
export class AiSubscription {
    @PrimaryGeneratedColumn('uuid', { name: 'subscription_id' })
    subscriptionId: string;

    @Column({ name: 'user_id', type: 'uuid' })
    userId: string;

    @Column({ name: 'plan_type', type: 'varchar', length: 20 })
    planType: string;

    @Column({ name: 'billing_cycle', type: 'varchar', length: 10 })
    billingCycle: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string;

    @Column({ name: 'started_at', type: 'timestamptz' })
    startedAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz' })
    expiresAt: Date;

    @Column({ name: 'grace_until', type: 'timestamptz', nullable: true })
    graceUntil: Date | null;

    @Column({ name: 'payment_id', type: 'uuid', nullable: true })
    paymentId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt: Date;
}
