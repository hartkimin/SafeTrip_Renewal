import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_NOTIFICATION — 알림 (도메인 H)
 * DB 설계 v3.4 §4.26
 */
@Entity('tb_notification')
@Index('idx_notification_user', ['userId', 'createdAt'])
export class Notification {
    @PrimaryGeneratedColumn('uuid', { name: 'notification_id' })
    notificationId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'notification_type', type: 'varchar', length: 40 })
    notificationType: string;
    // 'sos_alert' | 'geofence_enter' | 'geofence_exit' | 'guardian_request' |
    // 'chat_message' | 'trip_invite' | 'system' | 'no_response' | 'emergency_escalation'

    @Column({ name: 'title', type: 'varchar', length: 200 })
    title: string;

    @Column({ name: 'body', type: 'text', nullable: true })
    body: string | null;

    @Column({ name: 'data', type: 'jsonb', nullable: true })
    data: any;

    @Column({ name: 'is_read', type: 'boolean', default: false })
    isRead: boolean;

    @Column({ name: 'read_at', type: 'timestamptz', nullable: true })
    readAt: Date | null;

    @Column({ name: 'priority', type: 'varchar', length: 10, default: 'normal' })
    priority: string; // 'low' | 'normal' | 'high' | 'critical'

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_FCM_TOKEN — FCM 토큰 (도메인 H)
 * DB 설계 v3.4 §4.27
 */
@Entity('tb_fcm_token')
@Index('idx_fcm_token_user', ['userId'])
export class FcmToken {
    @PrimaryGeneratedColumn('uuid', { name: 'token_id' })
    tokenId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'token', type: 'text' })
    token: string;

    @Column({ name: 'device_type', type: 'varchar', length: 20, nullable: true })
    deviceType: string | null; // 'ios' | 'android' | 'web'

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'last_used_at', type: 'timestamptz', nullable: true })
    lastUsedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_NOTIFICATION_PREFERENCE — 알림 설정 (도메인 H)
 * DB 설계 v3.4 §4.28
 */
@Entity('tb_notification_preference')
@Index('idx_notification_pref_user', ['userId'])
export class NotificationPreference {
    @PrimaryGeneratedColumn('uuid', { name: 'preference_id' })
    preferenceId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'notification_type', type: 'varchar', length: 40 })
    notificationType: string;

    @Column({ name: 'is_enabled', type: 'boolean', default: true })
    isEnabled: boolean;

    @Column({ name: 'is_push_enabled', type: 'boolean', default: true })
    isPushEnabled: boolean;

    @Column({ name: 'is_in_app_enabled', type: 'boolean', default: true })
    isInAppEnabled: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
