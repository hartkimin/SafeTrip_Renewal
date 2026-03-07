import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { ChatRoom, ChatMessage, ChatReadStatus } from '../../entities/chat.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { User } from '../../entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';
import { SystemMessageService } from './system-message.service';

@Injectable()
export class ChatsService {
    constructor(
        @InjectRepository(ChatRoom) private roomRepo: Repository<ChatRoom>,
        @InjectRepository(ChatMessage) private messageRepo: Repository<ChatMessage>,
        @InjectRepository(ChatReadStatus) private readStatusRepo: Repository<ChatReadStatus>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(User) private userRepo: Repository<User>,
        private notifService: NotificationsService,
        private systemMessageService: SystemMessageService,
    ) { }

    async getRooms(tripId: string) {
        return this.roomRepo.find({ where: { tripId } });
    }

    async getMessages(roomId: string, cursor?: string, limit = 50) {
        const where: any = { roomId };
        if (cursor) {
            where.sentAt = LessThan(new Date(cursor));
        }
        return this.messageRepo.find({
            where,
            order: { sentAt: 'DESC' },
            take: limit,
        });
    }

    async sendMessage(roomId: string, senderId: string, data: {
        messageType?: string;
        content?: string;
        mediaUrls?: any;           // JSONB — [{url, type, size, thumbnail}]
        locationData?: any;        // JSONB — {lat, lng, address, place_name}
        cardData?: any;            // rich card data, stored in metadata
        replyToId?: string;
        // legacy single-field support
        mediaUrl?: string;
        latitude?: number;
        longitude?: number;
    }) {
        const room = await this.roomRepo.findOne({ where: { roomId } });
        if (!room) throw new NotFoundException('Chat room not found');

        // Build media URLs — accept new array format or legacy single URL
        let mediaUrls = data.mediaUrls || null;
        if (!mediaUrls && data.mediaUrl) {
            mediaUrls = [{ url: data.mediaUrl, type: 'image' }];
        }

        // Build location data — accept new object or legacy lat/lng fields
        let locationData = data.locationData || null;
        if (!locationData && data.latitude != null && data.longitude != null) {
            locationData = { lat: data.latitude, lng: data.longitude };
        }

        // Build metadata — store cardData if provided
        const metadata = data.cardData ? { cardData: data.cardData } : null;

        const message = this.messageRepo.create({
            roomId,
            tripId: room.tripId,
            senderId,
            messageType: data.messageType || 'text',
            content: data.content || null,
            mediaUrls,
            locationData,
            replyToId: data.replyToId || null,
            metadata,
        } as Partial<ChatMessage>);
        const saved = await this.messageRepo.save(message);

        // FCM 알림 발송 (다른 멤버들에게)
        this.handleChatNotification(room, senderId, saved).catch(err => console.error('Chat FCM error:', err));

        return saved;
    }

    private async handleChatNotification(room: ChatRoom, senderId: string, message: ChatMessage) {
        try {
            const sender = await this.userRepo.findOne({ where: { userId: senderId } });
            const senderName = sender?.displayName || 'Traveler';

            const title = room.roomName || 'Group Chat';
            const body = `${senderName}: ${message.messageType === 'text' ? message.content : '[' + message.messageType + ']'}`;

            const members = await this.memberRepo.find({
                where: { tripId: room.tripId, status: 'active' },
                select: ['userId']
            });

            const recipientIds = members
                .map(m => m.userId)
                .filter(id => id !== senderId);

            for (const recipientId of recipientIds) {
                await this.notifService.send(recipientId, {
                    title,
                    body,
                    notificationType: 'CHAT',
                    referenceId: message.messageId,
                    referenceType: 'CHAT_MESSAGE',
                    tripId: room.tripId,
                });
            }
        } catch (error) {
            console.error('Failed to send chat notification:', error);
        }
    }

    async markRead(roomId: string, userId: string, lastReadMessageId: string) {
        let status = await this.readStatusRepo.findOne({ where: { roomId, userId } });
        if (status) {
            await this.readStatusRepo.update(status.readId, { lastReadMessageId, lastReadAt: new Date() });
        } else {
            status = this.readStatusRepo.create({ roomId, userId, lastReadMessageId } as Partial<ChatReadStatus>);
            await this.readStatusRepo.save(status);
        }
        return { success: true };
    }

    // ------------------------------------------------------------------
    // Pin / Unpin / Delete
    // ------------------------------------------------------------------

    /**
     * 메시지 고정 (captain, crew_chief만 가능, 최대 3개)
     */
    async pinMessage(messageId: string, userId: string) {
        const message = await this.messageRepo.findOne({ where: { messageId } });
        if (!message) throw new NotFoundException('Message not found');
        if (message.isDeleted) throw new BadRequestException('삭제된 메시지는 고정할 수 없습니다.');
        if (message.isPinned) throw new BadRequestException('이미 고정된 메시지입니다.');

        // tripId를 message 또는 room에서 확보
        const tripId = message.tripId || (await this.roomRepo.findOne({ where: { roomId: message.roomId! } }))?.tripId;
        if (!tripId) throw new NotFoundException('Trip not found for this message');

        await this.assertLeaderRole(tripId, userId);

        // 현재 고정된 메시지 수 확인 (같은 roomId 기준)
        const pinnedCount = await this.messageRepo.count({
            where: { roomId: message.roomId!, isPinned: true, isDeleted: false },
        });
        if (pinnedCount >= 3) {
            throw new BadRequestException(
                '현재 공지가 3건 가득 찼습니다. 기존 공지를 해제한 후 새 공지를 추가하세요.',
            );
        }

        await this.messageRepo.update(messageId, {
            isPinned: true,
            pinnedBy: userId,
            updatedAt: new Date(),
        });

        // 시스템 메시지 삽입 (best-effort)
        const user = await this.userRepo.findOne({ where: { userId } });
        const userName = user?.displayName || 'Unknown';
        this.systemMessageService.insertPinAdd(tripId, userName).catch(() => {});

        return { success: true, data: { messageId, isPinned: true } };
    }

    /**
     * 공지 해제 (captain, crew_chief만 가능)
     * SOS CRITICAL 메시지는 해제 불가
     */
    async unpinMessage(messageId: string, userId: string) {
        const message = await this.messageRepo.findOne({ where: { messageId } });
        if (!message) throw new NotFoundException('Message not found');
        if (!message.isPinned) throw new BadRequestException('고정되지 않은 메시지입니다.');

        // SOS CRITICAL 메시지 해제 차단
        if (message.systemEventLevel === 'CRITICAL') {
            throw new BadRequestException('SOS CRITICAL 메시지는 공지 해제할 수 없습니다.');
        }

        const tripId = message.tripId || (await this.roomRepo.findOne({ where: { roomId: message.roomId! } }))?.tripId;
        if (!tripId) throw new NotFoundException('Trip not found for this message');

        await this.assertLeaderRole(tripId, userId);

        await this.messageRepo.update(messageId, {
            isPinned: false,
            pinnedBy: null,
            updatedAt: new Date(),
        });

        // 시스템 메시지 삽입 (best-effort)
        const user = await this.userRepo.findOne({ where: { userId } });
        const userName = user?.displayName || 'Unknown';
        this.systemMessageService.insertPinRemove(tripId, userName).catch(() => {});

        return { success: true, data: { messageId, isPinned: false } };
    }

    /**
     * 고정된 메시지 목록 조회 (최대 3개)
     */
    async getPinnedMessages(roomId: string) {
        const messages = await this.messageRepo.find({
            where: { roomId, isPinned: true, isDeleted: false },
            order: { sentAt: 'DESC' },
            take: 3,
        });
        return { success: true, data: messages };
    }

    /**
     * 메시지 소프트 삭제
     * - SOS CRITICAL 시스템 메시지 삭제 불가
     * - 고정된 메시지는 먼저 해제 필요
     * - captain: 모든 메시지 삭제 가능
     * - crew_chief, crew: 본인 메시지만 삭제 가능
     */
    async deleteMessage(messageId: string, userId: string) {
        const message = await this.messageRepo.findOne({ where: { messageId } });
        if (!message) throw new NotFoundException('Message not found');
        if (message.isDeleted) throw new BadRequestException('이미 삭제된 메시지입니다.');

        // SOS CRITICAL 삭제 차단
        if (message.systemEventLevel === 'CRITICAL') {
            throw new BadRequestException('SOS CRITICAL 메시지는 삭제할 수 없습니다.');
        }

        // 고정된 메시지 삭제 차단
        if (message.isPinned) {
            throw new BadRequestException('고정된 메시지는 먼저 공지 해제 후 삭제할 수 있습니다.');
        }

        const tripId = message.tripId || (await this.roomRepo.findOne({ where: { roomId: message.roomId! } }))?.tripId;
        if (!tripId) throw new NotFoundException('Trip not found for this message');

        // 역할 확인: captain은 모든 메시지 삭제 가능, 그 외는 자기 메시지만
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });
        if (!member) throw new ForbiddenException('여행 멤버가 아닙니다.');

        if (member.memberRole === 'captain') {
            // captain은 모든 메시지 삭제 가능
        } else if (message.senderId === userId) {
            // 본인 메시지 삭제 가능
        } else {
            throw new ForbiddenException('본인의 메시지만 삭제할 수 있습니다.');
        }

        await this.messageRepo.update(messageId, {
            isDeleted: true,
            deletedBy: userId,
            content: '삭제된 메시지입니다',
            updatedAt: new Date(),
        });

        return { success: true, data: { messageId, isDeleted: true } };
    }

    // ------------------------------------------------------------------
    // Role-check helpers
    // ------------------------------------------------------------------

    /**
     * captain 또는 crew_chief 역할인지 검증
     */
    private async assertLeaderRole(tripId: string, userId: string): Promise<void> {
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });
        if (!member) {
            throw new ForbiddenException('여행 멤버가 아닙니다.');
        }
        if (member.memberRole !== 'captain' && member.memberRole !== 'crew_chief') {
            throw new ForbiddenException('캡틴 또는 크루장만 이 작업을 수행할 수 있습니다.');
        }
    }

    /**
     * captain 역할인지 검증
     */
    private async assertCaptainRole(tripId: string, userId: string): Promise<void> {
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });
        if (!member) {
            throw new ForbiddenException('여행 멤버가 아닙니다.');
        }
        if (member.memberRole !== 'captain') {
            throw new ForbiddenException('캡틴만 이 작업을 수행할 수 있습니다.');
        }
    }
}
