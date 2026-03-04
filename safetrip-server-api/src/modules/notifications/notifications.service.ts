import { Injectable, Inject, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { FIREBASE_APP } from '../../config/firebase/firebase.module';
import { Notification, FcmToken, NotificationPreference } from '../../entities/notification.entity';

@Injectable()
export class NotificationsService {
    constructor(
        @InjectRepository(Notification) private notifRepo: Repository<Notification>,
        @InjectRepository(FcmToken) private tokenRepo: Repository<FcmToken>,
        @InjectRepository(NotificationPreference) private prefRepo: Repository<NotificationPreference>,
        @Inject(FIREBASE_APP) private firebaseApp: admin.app.App,
    ) { }

    async sendPush(data: { target_token: string; title: string; body: string; data?: any }) {
        try {
            const response = await this.firebaseApp.messaging().send({
                token: data.target_token,
                notification: {
                    title: data.title,
                    body: data.body,
                },
                data: data.data || {},
            });
            return { messageId: response };
        } catch (error) {
            console.error('FCM sendPush Error:', error);
            throw new Error(`Failed to send push: ${error.message}`);
        }
    }

    async sendMulticastPush(data: { target_tokens: string[]; title: string; body: string; data?: any }) {
        try {
            const response = await this.firebaseApp.messaging().sendEachForMulticast({
                tokens: data.target_tokens,
                notification: {
                    title: data.title,
                    body: data.body,
                },
                data: data.data || {},
            });
            return {
                successCount: response.successCount,
                failureCount: response.failureCount,
                results: response.responses
            };
        } catch (error) {
            console.error('FCM sendMulticastPush Error:', error);
            throw new Error(`Failed to send multicast push: ${error.message}`);
        }
    }

    async getNotificationHistory(userId: string, page: number, limit: number) {
        const skip = (page - 1) * limit;
        const [items, total] = await this.notifRepo.findAndCount({
            where: { userId },
            order: { createdAt: 'DESC' },
            skip,
            take: limit,
        });

        return {
            notifications: items,
            page,
            limit,
            total,
            total_pages: Math.ceil(total / limit)
        };
    }

    async getUnreadCount(userId: string) {
        const unread_count = await this.notifRepo.count({
            where: { userId, isRead: false },
        });
        return { unread_count };
    }

    async markAsRead(userId: string, notificationId: string) {
        const notification = await this.notifRepo.findOne({
            where: { notificationId, userId }
        });

        if (!notification) {
            throw new NotFoundException('Notification not found');
        }

        notification.isRead = true;
        notification.readAt = new Date();
        await this.notifRepo.save(notification);

        return {
            success: true,
            data: { message: "Notification marked as read", is_read: true }
        };
    }

    /** 내부 알림 전송 (FCM + DB 저장) */
    async send(userId: string, data: {
        title: string; body: string; notificationType: string;
        referenceId?: string; referenceType?: string; tripId?: string;
    }) {
        // SOS는 설정을 무시하고 항상 전송 (Business Principles §05.1)
        let isPushEnabled = true;
        
        if (data.notificationType !== 'SOS') {
            const pref = await this.prefRepo.findOne({ 
                where: { userId, notificationType: data.notificationType } 
            });
            if (pref && !pref.isPushEnabled) {
                isPushEnabled = false;
            }
        }

        // DB 저장 (앱 내 알림함)
        const notification = this.notifRepo.create({
            userId,
            title: data.title,
            body: data.body,
            notificationType: data.notificationType,
            tripId: data.tripId,
            data: {
                referenceId: data.referenceId,
                referenceType: data.referenceType,
            },
        } as Partial<Notification>);
        await this.notifRepo.save(notification);

        // FCM 전송
        if (isPushEnabled) {
            try {
                const tokens = await this.tokenRepo.find({ where: { userId, isActive: true } });
                if (tokens.length > 0) {
                    await this.firebaseApp.messaging().sendEachForMulticast({
                        tokens: tokens.map((t) => t.token),
                        notification: { title: data.title, body: data.body },
                        data: {
                            type: data.notificationType,
                            referenceId: data.referenceId || '',
                            referenceType: data.referenceType || '',
                            tripId: data.tripId || '',
                        },
                    });
                }
            } catch (error) {
                // FCM 실패는 로그만 남기고 진행
                console.error('FCM send error:', error);
            }
        }

        return notification;
    }
}
