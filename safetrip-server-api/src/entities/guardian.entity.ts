import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_GUARDIAN — 가디언 기본 정보 (도메인 C)
 * DB 설계 v3.4 §4.9
 */
@Entity('tb_guardian')
export class Guardian {
    @PrimaryGeneratedColumn('uuid', { name: 'guardian_id' })
    guardianId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'is_paid', type: 'boolean', default: false })
    isPaid: boolean;

    @Column({ name: 'paid_at', type: 'timestamptz', nullable: true })
    paidAt: Date | null;

    @Column({ name: 'payment_id', type: 'uuid', nullable: true })
    paymentId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_GUARDIAN_LINK — 가디언-멤버 연결 (도메인 C)
 * DB 설계 v3.4 §4.10
 * v3.4: UNIQUE 제거 → 부분 인덱스 2개로 대체
 */
@Entity('tb_guardian_link')
@Index('idx_guardian_link_active', ['tripId', 'guardianId', 'memberId'], {
    unique: true,
    where: `"status" = 'active' AND "guardian_id" IS NOT NULL`,
})
@Index('idx_guardian_link_pending', ['tripId', 'guardianPhone', 'memberId'], {
    unique: true,
    where: `"status" = 'pending' AND "guardian_phone" IS NOT NULL`,
})
export class GuardianLink {
    @PrimaryGeneratedColumn('uuid', { name: 'link_id' })
    linkId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'guardian_id', type: 'uuid', nullable: true })
    guardianId: string | null; // v3.3: nullable (미가입 가디언 초대 지원)

    @Column({ name: 'guardian_phone', type: 'varchar', length: 20, nullable: true })
    guardianPhone: string | null;

    @Column({ name: 'member_id', type: 'varchar', length: 128 })
    memberId: string;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'pending' })
    status: string; // 'pending' | 'active' | 'rejected' | 'expired'

    @Column({ name: 'payment_id', type: 'uuid', nullable: true })
    paymentId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'accepted_at', type: 'timestamptz', nullable: true })
    acceptedAt: Date | null;
}

/**
 * TB_GUARDIAN_PAUSE — 가디언 일시 중지 (도메인 C)
 * DB 설계 v3.4 §4.11
 */
@Entity('tb_guardian_pause')
export class GuardianPause {
    @PrimaryGeneratedColumn('uuid', { name: 'pause_id' })
    pauseId: string;

    @Column({ name: 'link_id', type: 'uuid' })
    linkId: string;

    /** v3.4: Appendix C 비정규화 */
    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'guardian_user_id', type: 'varchar', length: 128, nullable: true })
    guardianUserId: string | null;

    @Column({ name: 'paused_by', type: 'varchar', length: 128 })
    pausedBy: string;

    @Column({ name: 'reason', type: 'text', nullable: true })
    reason: string | null;

    @CreateDateColumn({ name: 'paused_at', type: 'timestamptz' })
    pausedAt: Date;

    @Column({ name: 'resumed_at', type: 'timestamptz', nullable: true })
    resumedAt: Date | null;
}

/**
 * TB_GUARDIAN_LOCATION_REQUEST — 긴급 위치 요청 (도메인 C, v3.2 신규)
 * DB 설계 v3.4 §4.11a
 */
@Entity('tb_guardian_location_request')
@Index('idx_guardian_location_request_hourly', ['guardianUserId', 'requestedAt'])
export class GuardianLocationRequest {
    @PrimaryGeneratedColumn('uuid', { name: 'request_id' })
    requestId: string;

    @Column({ name: 'link_id', type: 'uuid' })
    linkId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'guardian_user_id', type: 'varchar', length: 128 })
    guardianUserId: string;

    @Column({ name: 'member_id', type: 'varchar', length: 128 })
    memberId: string;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'pending' })
    status: string; // 'pending' | 'approved' | 'denied' | 'expired'

    /** v3.4: 자동 응답 추적 */
    @Column({ name: 'auto_responded', type: 'boolean', default: false })
    autoResponded: boolean;

    @Column({ name: 'auto_response_reason', type: 'varchar', length: 50, nullable: true })
    autoResponseReason: string | null;

    @CreateDateColumn({ name: 'requested_at', type: 'timestamptz' })
    requestedAt: Date;

    @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
    respondedAt: Date | null;
}

/**
 * TB_GUARDIAN_SNAPSHOT — 30분 위치 스냅샷 (도메인 C, v3.2 신규)
 * DB 설계 v3.4 §4.11b
 */
@Entity('tb_guardian_snapshot')
export class GuardianSnapshot {
    @PrimaryGeneratedColumn('uuid', { name: 'snapshot_id' })
    snapshotId: string;

    @Column({ name: 'link_id', type: 'uuid' })
    linkId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'member_id', type: 'varchar', length: 128 })
    memberId: string;

    @Column({ name: 'latitude', type: 'float' })
    latitude: number;

    @Column({ name: 'longitude', type: 'float' })
    longitude: number;

    @Column({ name: 'accuracy', type: 'float', nullable: true })
    accuracy: number | null;

    @CreateDateColumn({ name: 'captured_at', type: 'timestamptz' })
    capturedAt: Date;
}
