import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_PAYMENT — 결제 (도메인 I)
 * DB 설계 v3.4 §4.29
 */
@Entity('tb_payment')
@Index('idx_payment_user', ['userId'])
export class Payment {
    @PrimaryGeneratedColumn('uuid', { name: 'payment_id' })
    paymentId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'payment_type', type: 'varchar', length: 30 })
    paymentType: string; // 'guardian_fee' | 'premium' | 'b2b_contract'

    @Column({ name: 'amount', type: 'decimal', precision: 12, scale: 2 })
    amount: number;

    @Column({ name: 'currency', type: 'varchar', length: 3, default: 'KRW' })
    currency: string;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'pending' })
    status: string; // 'pending' | 'completed' | 'failed' | 'refunded'

    @Column({ name: 'payment_method', type: 'varchar', length: 30, nullable: true })
    paymentMethod: string | null;

    @Column({ name: 'external_payment_id', type: 'varchar', length: 200, nullable: true })
    externalPaymentId: string | null;

    @Column({ name: 'receipt_url', type: 'text', nullable: true })
    receiptUrl: string | null;

    /** v3.4: 구독 연결 */
    @Column({ name: 'subscription_id', type: 'uuid', nullable: true })
    subscriptionId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
    completedAt: Date | null;
}

/**
 * TB_SUBSCRIPTION — 구독 (도메인 I, v3.4 신규)
 * DB 설계 v3.4 §4.29a
 */
@Entity('tb_subscription')
export class Subscription {
    @PrimaryGeneratedColumn('uuid', { name: 'subscription_id' })
    subscriptionId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'plan_type', type: 'varchar', length: 30 })
    planType: string; // 'free' | 'guardian_basic' | 'guardian_premium'

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'cancelled' | 'expired' | 'paused'

    @Column({ name: 'started_at', type: 'timestamptz' })
    startedAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;

    @Column({ name: 'auto_renew', type: 'boolean', default: true })
    autoRenew: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
