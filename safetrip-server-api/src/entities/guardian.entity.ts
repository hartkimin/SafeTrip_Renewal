import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

/**
 * TB_GUARDIAN -- 가디언 기본 정보 (도메인 C)
 * DB 설계 v3.5.1 $4.9
 */
@Entity('tb_guardian')
export class Guardian {
    @PrimaryGeneratedColumn('uuid', { name: 'guardian_id' })
    guardianId: string;

    @Column({ name: 'traveler_user_id', type: 'varchar', length: 128, nullable: true })
    travelerUserId: string | null;

    @Column({ name: 'guardian_user_id', type: 'varchar', length: 128, nullable: true })
    guardianUserId: string | null;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'guardian_type', type: 'varchar', length: 20, nullable: true })
    guardianType: string | null; // 'primary' | 'secondary' | 'group'

    @Column({ name: 'can_view_location', type: 'boolean', default: true })
    canViewLocation: boolean;

    @Column({ name: 'can_request_checkin', type: 'boolean', default: true })
    canRequestCheckin: boolean;

    @Column({ name: 'can_receive_sos', type: 'boolean', default: true })
    canReceiveSos: boolean;

    @Column({ name: 'invite_status', type: 'varchar', length: 20, nullable: true })
    inviteStatus: string | null; // 'pending' | 'accepted' | 'rejected'

    @Column({ name: 'guardian_invite_code', type: 'varchar', length: 20, nullable: true })
    guardianInviteCode: string | null;

    @Column({ name: 'is_minor_guardian', type: 'boolean', default: false })
    isMinorGuardian: boolean;

    @Column({ name: 'consent_id', type: 'uuid', nullable: true })
    consentId: string | null;

    @Column({ name: 'auto_notify_sos', type: 'boolean', default: true })
    autoNotifySos: boolean;

    @Column({ name: 'auto_notify_geofence', type: 'boolean', default: true })
    autoNotifyGeofence: boolean;

    @Column({ name: 'is_paid', type: 'boolean', default: false })
    isPaid: boolean;

    @Column({ name: 'paid_at', type: 'timestamptz', nullable: true })
    paidAt: Date | null;

    @Column({ name: 'payment_id', type: 'uuid', nullable: true })
    paymentId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'accepted_at', type: 'timestamptz', nullable: true })
    acceptedAt: Date | null;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;

    // -- Backward-compat (legacy field used by existing code) --
    @Column({ name: 'user_id', type: 'varchar', length: 128, nullable: true })
    userId: string;
}

/**
 * TB_GUARDIAN_LINK -- 가디언-멤버 연결 (도메인 C)
 * DB 설계 v3.5.1 $4.10
 * v3.4: UNIQUE 제거 -> 부분 인덱스 2개로 대체
 */
@Entity('tb_guardian_link')
@Index('idx_guardian_link_active', ['tripId', 'guardianId', 'memberId'], {
    unique: true,
    where: `"status" = 'accepted' AND "guardian_id" IS NOT NULL`,
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

    @Column({ name: 'member_id', type: 'varchar', length: 128 })
    memberId: string;

    @Column({ name: 'guardian_id', type: 'varchar', length: 128, nullable: true })
    guardianId: string | null;

    @Column({ name: 'guardian_phone', type: 'varchar', length: 20, nullable: true })
    guardianPhone: string | null;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'pending' })
    status: string; // 'pending' | 'accepted' | 'rejected' | 'cancelled'

    @Column({ name: 'guardian_type', type: 'varchar', length: 20, default: 'personal' })
    guardianType: string; // 'personal' | 'group'

    @Column({ name: 'is_paid', type: 'boolean', default: false })
    isPaid: boolean;

    @Column({ name: 'paid_at', type: 'timestamptz', nullable: true })
    paidAt: Date | null;

    @Column({ name: 'payment_id', type: 'uuid', nullable: true })
    paymentId: string | null;

    @Column({ name: 'can_view_location', type: 'boolean', default: true })
    canViewLocation: boolean;

    @Column({ name: 'can_receive_sos', type: 'boolean', default: true })
    canReceiveSos: boolean;

    @Column({ name: 'can_request_checkin', type: 'boolean', default: true })
    canRequestCheckin: boolean;

    @Column({ name: 'can_send_message', type: 'boolean', default: true })
    canSendMessage: boolean;

    @Column({ name: 'invited_at', type: 'timestamptz', nullable: true })
    invitedAt: Date | null;

    @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
    respondedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    @Column({ name: 'accepted_at', type: 'timestamptz', nullable: true })
    acceptedAt: Date | null;
}

/**
 * TB_GUARDIAN_PAUSE -- 가디언 일시중지 (도메인 C)
 * DB 설계 v3.5.1 $4.11
 */
@Entity('tb_guardian_pause')
export class GuardianPause {
    @PrimaryGeneratedColumn('uuid', { name: 'pause_id' })
    pauseId: string;

    @Column({ name: 'link_id', type: 'uuid' })
    linkId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'guardian_user_id', type: 'varchar', length: 128, nullable: true })
    guardianUserId: string | null;

    @Column({ name: 'paused_at', type: 'timestamptz' })
    pausedAt: Date;

    @Column({ name: 'resume_at', type: 'timestamptz' })
    resumeAt: Date;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'pause_reason', type: 'varchar', length: 50, nullable: true })
    pauseReason: string | null; // 'user_request' | 'minor_blocked'

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    // -- Backward-compat columns --
    @Column({ name: 'paused_by', type: 'varchar', length: 128, nullable: true, select: false })
    pausedBy: string | null;

    @Column({ name: 'reason', type: 'text', nullable: true, select: false })
    reason: string | null;

    @Column({ name: 'resumed_at', type: 'timestamptz', nullable: true, select: false })
    resumedAt: Date | null;
}

/**
 * TB_GUARDIAN_LOCATION_REQUEST -- 긴급 위치 요청 (도메인 C)
 * DB 설계 v3.5.1 $4.11a
 */
@Entity('tb_guardian_location_request')
@Index('idx_guardian_location_request_hourly', ['guardianUserId', 'requestedAt'])
export class GuardianLocationRequest {
    @PrimaryGeneratedColumn('uuid', { name: 'request_id' })
    requestId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'guardian_user_id', type: 'varchar', length: 128 })
    guardianUserId: string;

    @Column({ name: 'target_user_id', type: 'varchar', length: 128, nullable: true })
    targetUserId: string | null;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'pending' })
    status: string; // 'pending' | 'approved' | 'ignored' | 'expired'

    @Column({ name: 'requested_at', type: 'timestamptz', nullable: true })
    requestedAt: Date | null;

    @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
    respondedAt: Date | null;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;

    /** v3.4: 자동 응답 추적 */
    @Column({ name: 'auto_responded', type: 'boolean', default: false })
    autoResponded: boolean;

    @Column({ name: 'auto_response_reason', type: 'varchar', length: 50, nullable: true })
    autoResponseReason: string | null; // 'standard_grade_auto' | 'sos_override'

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    // -- Backward-compat columns --
    @Column({ name: 'link_id', type: 'uuid', nullable: true, select: false })
    linkId: string | null;

    @Column({ name: 'member_id', type: 'varchar', length: 128, nullable: true, select: false })
    memberId: string | null;
}

/**
 * TB_GUARDIAN_SNAPSHOT -- 30분 위치 스냅샷 (도메인 C)
 * DB 설계 v3.5.1 $4.11b
 */
@Entity('tb_guardian_snapshot')
export class GuardianSnapshot {
    @PrimaryGeneratedColumn('uuid', { name: 'snapshot_id' })
    snapshotId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128, nullable: true })
    userId: string | null;

    @Column({ name: 'latitude', type: 'double precision' })
    latitude: number;

    @Column({ name: 'longitude', type: 'double precision' })
    longitude: number;

    @CreateDateColumn({ name: 'captured_at', type: 'timestamptz' })
    capturedAt: Date;

    // -- Backward-compat columns --
    @Column({ name: 'link_id', type: 'uuid', nullable: true, select: false })
    linkId: string | null;

    @Column({ name: 'member_id', type: 'varchar', length: 128, nullable: true, select: false })
    memberId: string | null;

    @Column({ name: 'accuracy', type: 'float', nullable: true, select: false })
    accuracy: number | null;
}

/**
 * TB_GUARDIAN_RELEASE_REQUEST -- 미성년자 가디언 해제 요청 (도메인 C)
 * DOC-T3-MBR-019 §10.2
 */
@Entity('tb_guardian_release_request')
@Index('idx_guardian_release_request_trip', ['tripId', 'status'])
export class GuardianReleaseRequest {
    @PrimaryGeneratedColumn('uuid', { name: 'request_id' })
    requestId: string;

    @Column({ name: 'link_id', type: 'uuid' })
    linkId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'requested_by', type: 'varchar', length: 128 })
    requestedBy: string;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'pending' })
    status: string; // 'pending' | 'approved' | 'rejected'

    @Column({ name: 'captain_id', type: 'varchar', length: 128, nullable: true })
    captainId: string | null;

    @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
    respondedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt: Date;
}
