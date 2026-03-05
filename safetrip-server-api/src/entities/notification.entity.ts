import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_NOTIFICATION — 알림 (도메인 H)
 * DB 설계 v3.5.1 §4.27
 */
@Entity('tb_notification')
@Index('idx_notification_user', ['userId', 'createdAt'])
@Index('idx_notification_user_read', ['userId', 'isRead', 'isDeleted'])
@Index('idx_notification_trip', ['tripId', 'createdAt'])
@Index('idx_notification_priority', ['priority', 'isRead'])
export class Notification {
    @PrimaryGeneratedColumn('uuid', { name: 'notification_id' })
    notificationId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'event_type', type: 'varchar', length: 50, nullable: true })
    eventType: string | null;

    @Column({ name: 'notification_type', type: 'varchar', length: 40 })
    notificationType: string;

    @Column({ name: 'priority', type: 'varchar', length: 10, default: 'normal' })
    priority: string; // 'P0' | 'P1' | 'P2' | 'P3' | 'P4' | 'low' | 'normal' | 'high' | 'critical'

    @Column({ name: 'channel', type: 'varchar', length: 30, nullable: true })
    channel: string | null;

    @Column({ name: 'title', type: 'varchar', length: 200 })
    title: string;

    @Column({ name: 'body', type: 'text', nullable: true })
    body: string | null;

    @Column({ name: 'icon', type: 'varchar', length: 10, nullable: true })
    icon: string | null;

    @Column({ name: 'color', type: 'varchar', length: 7, nullable: true })
    color: string | null;

    @Column({ name: 'deeplink', type: 'text', nullable: true })
    deeplink: string | null;

    @Column({ name: 'related_user_id', type: 'varchar', length: 128, nullable: true })
    relatedUserId: string | null;

    @Column({ name: 'related_event_id', type: 'varchar', length: 128, nullable: true })
    relatedEventId: string | null;

    @Column({ name: 'location_data', type: 'jsonb', nullable: true })
    locationData: any;

    @Column({ name: 'data', type: 'jsonb', nullable: true })
    data: any;

    @Column({ name: 'is_read', type: 'boolean', default: false })
    isRead: boolean;

    @Column({ name: 'read_at', type: 'timestamptz', nullable: true })
    readAt: Date | null;

    @Column({ name: 'is_deleted', type: 'boolean', default: false })
    isDeleted: boolean;

    @Column({ name: 'fcm_sent', type: 'boolean', default: false })
    fcmSent: boolean;

    @Column({ name: 'fcm_sent_at', type: 'timestamptz', nullable: true })
    fcmSentAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;
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
 * TB_NOTIFICATION_PREFERENCE — 알림 설정 (도메인 H, backward-compat)
 * 기존 코드 호환용. SSOT에서는 TB_NOTIFICATION_SETTING으로 대체.
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

/**
 * TB_NOTIFICATION_SETTING — 알림 설정 (도메인 H)
 * DB 설계 v3.5.1 §4.28
 * Composite PK: (user_id, event_type)
 */
@Entity('tb_notification_setting')
export class NotificationSetting {
    @PrimaryGeneratedColumn('uuid', { name: 'setting_id' })
    settingId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'event_type', type: 'varchar', length: 50 })
    eventType: string;

    @Column({ name: 'is_enabled', type: 'boolean', default: true })
    isEnabled: boolean;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_EVENT_NOTIFICATION_CONFIG — 알림 규칙 (그룹 단위, 도메인 H)
 * DB 설계 v3.5.1 §4.29
 */
@Entity('tb_event_notification_config')
@Index('idx_event_notification_config_unique', ['groupId', 'eventType'], { unique: true })
export class EventNotificationConfig {
    @PrimaryGeneratedColumn('uuid', { name: 'config_id' })
    configId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'event_type', type: 'varchar', length: 50, nullable: true })
    eventType: string | null;

    @Column({ name: 'notify_admins', type: 'boolean', default: true })
    notifyAdmins: boolean;

    @Column({ name: 'notify_guardians', type: 'boolean', default: true })
    notifyGuardians: boolean;

    @Column({ name: 'notify_members', type: 'boolean', default: false })
    notifyMembers: boolean;

    @Column({ name: 'notify_self', type: 'boolean', default: true })
    notifySelf: boolean;

    @Column({ name: 'is_enabled', type: 'boolean', default: true })
    isEnabled: boolean;

    @Column({ name: 'title_template', type: 'text', nullable: true })
    titleTemplate: string | null;

    @Column({ name: 'body_template', type: 'text', nullable: true })
    bodyTemplate: string | null;
}
