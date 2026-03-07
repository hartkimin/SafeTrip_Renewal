import {
    Entity, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn,
} from 'typeorm';

/**
 * TB_USER -- 사용자 (도메인 A)
 * DB 설계 v3.5.1 $4.1
 */
@Entity('tb_user')
export class User {
    @PrimaryColumn({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string; // Firebase UID

    @Column({ name: 'phone_number', type: 'varchar', length: 20, nullable: true })
    phoneNumber: string | null;

    @Column({ name: 'phone_country_code', type: 'varchar', length: 5, nullable: true })
    phoneCountryCode: string | null;

    @Column({ name: 'display_name', type: 'varchar', length: 100, nullable: true })
    displayName: string | null;

    @Column({ name: 'profile_image_url', type: 'text', nullable: true })
    profileImageUrl: string | null;

    @Column({ name: 'email', type: 'varchar', length: 255, nullable: true })
    email: string | null;

    @Column({ name: 'date_of_birth', type: 'date', nullable: true })
    dateOfBirth: Date | null;

    @Column({ name: 'location_sharing_mode', type: 'varchar', length: 20, nullable: true })
    locationSharingMode: string | null; // 'always' | 'in_trip' | 'off'

    @Column({ name: 'avatar_id', type: 'varchar', length: 30, nullable: true })
    avatarId: string | null;

    @Column({ name: 'privacy_level', type: 'varchar', length: 20, default: 'standard' })
    privacyLevel: string; // 'safety_first' | 'standard' | 'privacy_first'

    @Column({ name: 'image_review_status', type: 'varchar', length: 20, default: 'none' })
    imageReviewStatus: string; // 'none' | 'pending' | 'approved' | 'rejected'

    @Column({ name: 'onboarding_completed', type: 'boolean', default: false })
    onboardingCompleted: boolean;

    @Column({ name: 'deletion_reason', type: 'text', nullable: true })
    deletionReason: string | null;

    @Column({ name: 'fcm_token', type: 'text', nullable: true })
    fcmToken: string | null;

    @Column({ name: 'install_id', type: 'varchar', length: 100, nullable: true })
    installId: string | null;

    @Column({ name: 'device_info', type: 'jsonb', nullable: true })
    deviceInfo: any;

    @Column({ name: 'user_status', type: 'varchar', length: 20, default: 'active' })
    userStatus: string; // 'active' | 'inactive' | 'banned'

    /** v3.4: 미성년자 상태 */
    @Column({ name: 'minor_status', type: 'varchar', length: 20, default: 'adult' })
    minorStatus: string; // 'adult' | 'minor_over14' | 'minor_under14' | 'minor_child'

    @Column({ name: 'minor_status_updated_at', type: 'timestamptz', nullable: true })
    minorStatusUpdatedAt: Date | null;

    @Column({ name: 'guardian_pause_blocked', type: 'boolean', default: false })
    guardianPauseBlocked: boolean;

    @Column({ name: 'ai_intelligence_blocked', type: 'boolean', default: false })
    aiIntelligenceBlocked: boolean;

    @Column({ name: 'last_verification_at', type: 'timestamptz', nullable: true })
    lastVerificationAt: Date | null;

    @Column({ name: 'last_login_at', type: 'timestamptz', nullable: true })
    lastLoginAt: Date | null;

    @Column({ name: 'last_active_at', type: 'timestamptz', nullable: true })
    lastActiveAt: Date | null;

    /** v3.4: 계정 삭제 7일 유예 기산점 */
    @Column({ name: 'deletion_requested_at', type: 'timestamptz', nullable: true })
    deletionRequestedAt: Date | null;

    @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
    deletedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    // -- Backward-compat columns (not in SSOT but used by existing code) --

    currentUserRole: string; // Not a DB column, runtime-only

    @Column({ name: 'is_active', type: 'boolean', default: true, select: false })
    isActive: boolean;

    @Column({ name: 'is_onboarding_complete', type: 'boolean', default: false, select: false })
    isOnboardingComplete: boolean;

    @Column({ name: 'onboarding_step', type: 'varchar', length: 50, nullable: true, select: false })
    onboardingStep: string | null;

    @Column({ name: 'terms_agreed_at', type: 'timestamptz', nullable: true, select: false })
    termsAgreedAt: Date | null;

    @Column({ name: 'terms_version', type: 'varchar', length: 20, nullable: true, select: false })
    termsVersion: string | null;
}

/**
 * TB_PARENTAL_CONSENT -- 법정대리인 동의 기록 (도메인 A)
 * DB 설계 v3.4 $4.1a
 */
@Entity('tb_parental_consent')
export class ParentalConsent {
    @PrimaryColumn({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'parent_name', type: 'varchar', length: 50, nullable: true })
    parentName: string | null;

    @Column({ name: 'parent_phone', type: 'varchar', length: 20, nullable: true })
    parentPhone: string | null;

    @Column({ name: 'relationship', type: 'varchar', length: 20, nullable: true })
    relationship: string | null;

    @Column({ name: 'consent_otp', type: 'varchar', length: 10, nullable: true })
    consentOtp: string | null;

    @Column({ name: 'is_verified', type: 'boolean', default: false })
    isVerified: boolean;

    @Column({ name: 'verified_at', type: 'timestamptz', nullable: true })
    verifiedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
