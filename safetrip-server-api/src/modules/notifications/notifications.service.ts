import { Injectable, Inject, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { FIREBASE_APP } from '../../config/firebase/firebase.module';
import { Notification, FcmToken, NotificationPreference } from '../../entities/notification.entity';

@Injectable()
export class NotificationsService {
    private readonly logger = new Logger(NotificationsService.name);

    constructor(
        @InjectRepository(Notification) private notifRepo: Repository<Notification>,
        @InjectRepository(FcmToken) private tokenRepo: Repository<FcmToken>,
        @InjectRepository(NotificationPreference) private prefRepo: Repository<NotificationPreference>,
        @Inject(FIREBASE_APP) private firebaseApp: admin.app.App,
    ) { }

    /** FCM 토큰 등록/갱신 */
    async registerToken(userId: string, token: string, deviceType?: string) {
        let fcmToken = await this.tokenRepo.findOne({ where: { token } });
        
        if (fcmToken) {
            // 이미 존재하는 토큰의 소유자나 상태 업데이트
            fcmToken.userId = userId;
            fcmToken.isActive = true;
            if (deviceType) fcmToken.deviceType = deviceType;
            fcmToken.updatedAt = new Date();
            await this.tokenRepo.save(fcmToken);
        } else {
            fcmToken = this.tokenRepo.create({
                userId,
                token,
                deviceType: deviceType || 'unknown',
                isActive: true,
            });
            await this.tokenRepo.save(fcmToken);
        }
        return { success: true };
    }

    /** FCM 토큰 명시적 무효화 (로그아웃/앱 삭제 시) */
    async invalidateToken(userId: string, token: string) {
        await this.tokenRepo.update({ token, userId }, { isActive: false, updatedAt: new Date() });
        this.logger.log(`Invalidated FCM token for user ${userId}`);
        return { success: true };
    }

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
            this.logger.error('FCM sendPush Error:', error);
            if (this.isInvalidTokenError(error)) {
                await this.tokenRepo.update({ token: data.target_token }, { isActive: false });
            }
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

            // 유효하지 않은 토큰 정리
            if (response.failureCount > 0) {
                const invalidTokens: string[] = [];
                response.responses.forEach((resp, idx) => {
                    if (!resp.success && resp.error && this.isInvalidTokenError(resp.error)) {
                        invalidTokens.push(data.target_tokens[idx]);
                    }
                });
                
                if (invalidTokens.length > 0) {
                    await this.cleanupTokens(invalidTokens);
                }
            }

            return {
                successCount: response.successCount,
                failureCount: response.failureCount,
                results: response.responses
            };
        } catch (error) {
            this.logger.error('FCM sendMulticastPush Error:', error);
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
                    const targetTokens = tokens.map((t) => t.token);
                    const response = await this.firebaseApp.messaging().sendEachForMulticast({
                        tokens: targetTokens,
                        notification: { title: data.title, body: data.body },
                        data: {
                            type: data.notificationType,
                            referenceId: data.referenceId || '',
                            referenceType: data.referenceType || '',
                            tripId: data.tripId || '',
                        },
                    });

                    // 실패한 토큰 정리
                    if (response.failureCount > 0) {
                        const invalidTokens: string[] = [];
                        response.responses.forEach((resp, idx) => {
                            if (!resp.success && resp.error && this.isInvalidTokenError(resp.error)) {
                                invalidTokens.push(targetTokens[idx]);
                            }
                        });
                        if (invalidTokens.length > 0) {
                            await this.cleanupTokens(invalidTokens);
                        }
                    }
                }
            } catch (error) {
                this.logger.error('FCM send error:', error);
            }
        }

        return notification;
    }

    private isInvalidTokenError(error: any): boolean {
        const errCode = error.code || error.message;
        return errCode === 'messaging/invalid-registration-token' ||
               errCode === 'messaging/registration-token-not-registered';
    }

    /** §12.4 특정 여행자에게 FCM 푸시 발송 */
    async notifyTraveler(travelerId: string, data: { title: string; body: string; data?: any }) {
        if (!data.title || !data.body) {
            throw new NotFoundException('title and body are required');
        }

        const tokens = await this.tokenRepo.find({ where: { userId: travelerId, isActive: true } });
        if (tokens.length === 0) {
            throw new NotFoundException('No active FCM tokens found for traveler');
        }

        const targetTokens = tokens.map(t => t.token);
        const response = await this.firebaseApp.messaging().sendEachForMulticast({
            tokens: targetTokens,
            notification: { title: data.title, body: data.body },
            data: data.data || {},
            android: { priority: 'high' as const },
            apns: { headers: { 'apns-priority': '10' } },
        });

        if (response.failureCount > 0) {
            const invalidTokens: string[] = [];
            response.responses.forEach((resp, idx) => {
                if (!resp.success && resp.error && this.isInvalidTokenError(resp.error)) {
                    invalidTokens.push(targetTokens[idx]);
                }
            });
            if (invalidTokens.length > 0) {
                await this.cleanupTokens(invalidTokens);
            }
        }

        return {
            success: true,
            tokens_sent: response.successCount,
            tokens_failed: response.failureCount,
        };
    }

    private async cleanupTokens(tokens: string[]) {
        if (tokens.length === 0) return;
        try {
            await this.tokenRepo.createQueryBuilder()
                .update(FcmToken)
                .set({ isActive: false, updatedAt: new Date() })
                .where("token IN (:...tokens)", { tokens })
                .execute();
            this.logger.log(`Cleaned up ${tokens.length} invalid FCM tokens`);
        } catch (e) {
            this.logger.error(`Failed to cleanup tokens: ${e.message}`);
        }
    }
}

