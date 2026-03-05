import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_PAYMENT — 결제 (도메인 K)
 * DB 설계 v3.5.1 §4.40
 */
@Entity('tb_payment')
@Index('idx_payment_user', ['userId'])
@Index('idx_payment_status', ['status'])
export class Payment {
    @PrimaryGeneratedColumn('uuid', { name: 'payment_id' })
    paymentId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'subscription_id', type: 'uuid', nullable: true })
    subscriptionId: string | null;

    @Column({ name: 'payment_type', type: 'varchar', length: 30 })
    paymentType: string;
    // 'trip_base' | 'addon_movement' | 'addon_ai_plus' |
    // 'addon_ai_pro' | 'addon_guardian' | 'b2b_contract'

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'amount', type: 'decimal', precision: 10, scale: 2 })
    amount: number;

    @Column({ name: 'currency', type: 'varchar', length: 3, default: 'KRW' })
    currency: string;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'pending' })
    status: string; // 'pending' | 'completed' | 'failed' | 'refunded' | 'cancelled'

    @Column({ name: 'pg_provider', type: 'varchar', length: 30, nullable: true })
    pgProvider: string | null; // 'toss' | 'kakao' | 'inicis' | 'stripe'

    @Column({ name: 'pg_payment_key', type: 'varchar', length: 200, nullable: true })
    pgPaymentKey: string | null;

    @Column({ name: 'pg_order_id', type: 'varchar', length: 100, nullable: true })
    pgOrderId: string | null;

    @Column({ name: 'pg_receipt_url', type: 'text', nullable: true })
    pgReceiptUrl: string | null;

    @Column({ name: 'paid_at', type: 'timestamptz', nullable: true })
    paidAt: Date | null;

    @Column({ name: 'failed_at', type: 'timestamptz', nullable: true })
    failedAt: Date | null;

    @Column({ name: 'failure_reason', type: 'text', nullable: true })
    failureReason: string | null;

    @Column({ name: 'metadata', type: 'jsonb', nullable: true })
    metadata: any;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    // -- Backward-compat columns --
    @Column({ name: 'payment_method', type: 'varchar', length: 30, nullable: true, select: false })
    paymentMethod: string | null;

    @Column({ name: 'external_payment_id', type: 'varchar', length: 200, nullable: true, select: false })
    externalPaymentId: string | null;

    @Column({ name: 'receipt_url', type: 'text', nullable: true, select: false })
    receiptUrl: string | null;

    @Column({ name: 'completed_at', type: 'timestamptz', nullable: true, select: false })
    completedAt: Date | null;
}

/**
 * TB_SUBSCRIPTION — 구독/플랜 (도메인 K)
 * DB 설계 v3.5.1 §4.39
 */
@Entity('tb_subscription')
@Index('idx_subscription_user', ['userId'])
@Index('idx_subscription_status', ['status'])
export class Subscription {
    @PrimaryGeneratedColumn('uuid', { name: 'subscription_id' })
    subscriptionId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'plan_type', type: 'varchar', length: 30 })
    planType: string;
    // 'free' | 'trip_base' | 'addon_movement' | 'addon_ai_plus' |
    // 'addon_ai_pro' | 'addon_guardian' | 'b2b_school' | 'b2b_corporate'

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'cancelled' | 'expired' | 'suspended'

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'started_at', type: 'timestamptz' })
    startedAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;

    @Column({ name: 'auto_renew', type: 'boolean', default: false })
    autoRenew: boolean;

    @Column({ name: 'cancelled_at', type: 'timestamptz', nullable: true })
    cancelledAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_REDEEM_CODE — 리딤 코드 및 프로모션 (도메인 I, v3.5 신규)
 * DB 설계 v3.5 §4.30
 */
@Entity('tb_redeem_code')
@Index('idx_redeem_codes_code', ['code'])
@Index('idx_redeem_codes_valid', ['validFrom', 'validUntil'])
export class RedeemCode {
    @PrimaryGeneratedColumn('uuid', { name: 'code_id' })
    codeId: string;

    @Column({ name: 'code', type: 'varchar', length: 50, unique: true })
    code: string;

    @Column({ name: 'code_type', type: 'varchar', length: 30 })
    codeType: string; // 'PLAN-PERSONAL-7D', 'PLAN-GROUP-30D', etc.

    @Column({ name: 'plan_type', type: 'varchar', length: 20, nullable: true })
    planType: string | null;

    @Column({ name: 'discount_rate', type: 'decimal', precision: 5, scale: 2, nullable: true })
    discountRate: number | null;

    @Column({ name: 'bonus_days', type: 'int', nullable: true })
    bonusDays: number | null;

    @Column({ name: 'max_uses', type: 'int', default: 1 })
    maxUses: number;

    @Column({ name: 'current_uses', type: 'int', default: 0 })
    currentUses: number;

    @Column({ name: 'valid_from', type: 'timestamptz', default: () => 'CURRENT_TIMESTAMP' })
    validFrom: Date;

    @Column({ name: 'valid_until', type: 'timestamptz', nullable: true })
    validUntil: Date | null;

    @Column({ name: 'issued_by', type: 'varchar', length: 100, nullable: true })
    issuedBy: string | null;

    @Column({ name: 'issued_reason', type: 'text', nullable: true })
    issuedReason: string | null;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_BILLING_ITEM — 결제 항목 명세 (도메인 K)
 * DB 설계 v3.5.1 §4.41
 */
@Entity('tb_billing_item')
export class BillingItem {
    @PrimaryGeneratedColumn('uuid', { name: 'item_id' })
    itemId: string;

    @Column({ name: 'payment_id', type: 'uuid' })
    paymentId: string;

    @Column({ name: 'item_type', type: 'varchar', length: 30 })
    itemType: string;
    // 'trip_base' | 'addon_movement' | 'addon_ai_plus' | 'addon_ai_pro' |
    // 'addon_guardian' | 'b2b_seat' | 'movement_session'

    @Column({ name: 'item_name', type: 'varchar', length: 100 })
    itemName: string;

    @Column({ name: 'quantity', type: 'int', default: 1 })
    quantity: number;

    @Column({ name: 'unit_price', type: 'decimal', precision: 10, scale: 2 })
    unitPrice: number;

    @Column({ name: 'total_price', type: 'decimal', precision: 10, scale: 2 })
    totalPrice: number;

    @Column({ name: 'reference_id', type: 'varchar', length: 128, nullable: true })
    referenceId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_REFUND_LOG — 환불 기록 (도메인 K)
 * DB 설계 v3.5.1 §4.42
 */
@Entity('tb_refund_log')
@Index('idx_refund_payment', ['paymentId'])
@Index('idx_refund_user', ['userId'])
export class RefundLog {
    @PrimaryGeneratedColumn('uuid', { name: 'refund_id' })
    refundId: string;

    @Column({ name: 'payment_id', type: 'uuid' })
    paymentId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128, nullable: true })
    userId: string | null;

    @Column({ name: 'refund_amount', type: 'decimal', precision: 10, scale: 2 })
    refundAmount: number;

    @Column({ name: 'refund_reason', type: 'varchar', length: 100, nullable: true })
    refundReason: string | null;
    // 'user_request' | 'service_error' | 'admin_override' | 'duplicate_payment'

    @Column({ name: 'refund_policy', type: 'varchar', length: 30, nullable: true })
    refundPolicy: string | null;
    // 'planning_full' | 'active_24h_half' | 'active_no_refund' |
    // 'completed_no_refund' | 'admin_override'

    @Column({ name: 'refund_status', type: 'varchar', length: 20, default: 'pending' })
    refundStatus: string; // 'pending' | 'completed' | 'rejected'

    @Column({ name: 'pg_refund_key', type: 'varchar', length: 200, nullable: true })
    pgRefundKey: string | null;

    @Column({ name: 'requested_at', type: 'timestamptz' })
    requestedAt: Date;

    @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
    completedAt: Date | null;

    @Column({ name: 'rejected_at', type: 'timestamptz', nullable: true })
    rejectedAt: Date | null;

    @Column({ name: 'rejection_reason', type: 'text', nullable: true })
    rejectionReason: string | null;

    @Column({ name: 'processed_by', type: 'varchar', length: 128, nullable: true })
    processedBy: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
