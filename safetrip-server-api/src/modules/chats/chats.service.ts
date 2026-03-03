import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { ChatRoom, ChatMessage, ChatReadStatus } from '../../entities/chat.entity';

@Injectable()
export class ChatsService {
    constructor(
        @InjectRepository(ChatRoom) private roomRepo: Repository<ChatRoom>,
        @InjectRepository(ChatMessage) private messageRepo: Repository<ChatMessage>,
        @InjectRepository(ChatReadStatus) private readStatusRepo: Repository<ChatReadStatus>,
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
        messageType?: string; content?: string; mediaUrl?: string;
        latitude?: number; longitude?: number;
    }) {
        const message = this.messageRepo.create({
            roomId, senderId,
            messageType: data.messageType || 'text',
            content: data.content,
        } as Partial<ChatMessage>);
        return this.messageRepo.save(message);
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
