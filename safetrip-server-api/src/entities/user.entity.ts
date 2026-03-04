import {
    Entity, PrimaryColumn, Column, CreateDateColumn, UpdateDateColumn,
} from 'typeorm';

/**
 * TB_USER — 사용자 (도메인 A)
 * DB 설계 v3.4 §4.1
 */
@Entity('tb_user')
export class User {
    @PrimaryColumn({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string; // Firebase UID

    @Column({ name: 'phone_number', type: 'varchar', length: 20 })
    phoneNumber: string;

    @Column({ name: 'phone_country_code', type: 'varchar', length: 5, default: '+82' })
    phoneCountryCode: string;

    @Column({ name: 'display_name', type: 'varchar', length: 50, default: '' })
    displayName: string;

    @Column({ name: 'profile_image_url', type: 'text', nullable: true })
    profileImageUrl: string | null;

    @Column({ name: 'date_of_birth', type: 'date', nullable: true })
    dateOfBirth: Date | null;

    currentUserRole: string; // Not a DB column, renamed to avoid TypeORM conflict

    @Column({ name: 'install_id', type: 'varchar', length: 128, nullable: true })
    installId: string | null;

    @Column({ name: 'location_sharing_mode', type: 'varchar', length: 20, default: 'always' })
    locationSharingMode: string;

    @Column({ name: 'last_verification_at', type: 'timestamptz', nullable: true })
    lastVerificationAt: Date | null;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'is_onboarding_complete', type: 'boolean', default: false })
    isOnboardingComplete: boolean;

    @Column({ name: 'onboarding_step', type: 'varchar', length: 50, nullable: true })
    onboardingStep: string | null;

    /** v3.4: 미성년자 여부 */
    @Column({ name: 'minor_status', type: 'varchar', length: 20, default: 'adult' })
    minorStatus: string; // 'adult' | 'minor'

    /** v3.4: 계정 삭제 7일 유예 기산점 */
    @Column({ name: 'deletion_requested_at', type: 'timestamptz', nullable: true })
    deletionRequestedAt: Date | null;

    @Column({ name: 'terms_agreed_at', type: 'timestamptz', nullable: true })
    termsAgreedAt: Date | null;

    @Column({ name: 'terms_version', type: 'varchar', length: 20, nullable: true })
    termsVersion: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt: Date;

    @Column({ name: 'last_active_at', type: 'timestamptz', nullable: true })
    lastActiveAt: Date | null;
}

/**
 * TB_PARENTAL_CONSENT — 법정대리인 동의 기록 (도메인 A)
 * DB 설계 v3.4 §4.1a
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
