import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { ChatRoom, ChatMessage, ChatReadStatus } from '../../entities/chat.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { User } from '../../entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class ChatsService {
    constructor(
        @InjectRepository(ChatRoom) private roomRepo: Repository<ChatRoom>,
        @InjectRepository(ChatMessage) private messageRepo: Repository<ChatMessage>,
        @InjectRepository(ChatReadStatus) private readStatusRepo: Repository<ChatReadStatus>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(User) private userRepo: Repository<User>,
        private notifService: NotificationsService,
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
}
