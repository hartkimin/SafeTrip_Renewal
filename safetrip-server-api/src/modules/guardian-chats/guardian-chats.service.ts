import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThan } from 'typeorm';
import { GuardianMessage } from '../../entities/guardian-message.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class GuardianChatsService {
    constructor(
        @InjectRepository(GuardianMessage) private msgRepo: Repository<GuardianMessage>,
        @InjectRepository(GuardianLink) private linkRepo: Repository<GuardianLink>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        private notifService: NotificationsService,
    ) {}

    /** List guardian channels for a user in a trip */
    async getChannels(tripId: string, userId: string) {
        const links = await this.linkRepo.find({
            where: [
                { tripId, memberId: userId, status: 'accepted' },
                { tripId, guardianId: userId, status: 'accepted' },
            ],
        });
        return links;
    }

    /** Fetch messages for a guardian channel (cursor-based pagination) */
    async getMessages(linkId: string, userId: string, cursor?: string, limit = 50) {
        await this.assertChannelAccess(linkId, userId);

        const where: any = { linkId };
        if (cursor) {
            where.sentAt = LessThan(new Date(cursor));
        }
        return this.msgRepo.find({
            where,
            order: { sentAt: 'DESC' },
            take: limit,
        });
    }

    /** Send a message in a guardian channel */
    async sendMessage(linkId: string, userId: string, data: {
        content?: string; messageType?: string; cardData?: any;
    }) {
        const link = await this.assertChannelAccess(linkId, userId);

        // Determine sender type
        const senderType = link.memberId === userId ? 'member' : 'guardian';

        // Free guardian: block location_card sending
        if (senderType === 'guardian' && !link.isPaid && data.messageType === 'location_card') {
            throw new ForbiddenException('무료 가디언은 위치 카드를 전송할 수 없습니다.');
        }

        const message = this.msgRepo.create({
            tripId: link.tripId,
            linkId,
            senderType,
            senderId: userId,
            messageType: data.messageType || 'text',
            content: data.content,
            cardData: data.cardData,
        });
        const saved = await this.msgRepo.save(message);

        // Notify the other party
        const recipientId = senderType === 'member' ? link.guardianId : link.memberId;
        if (recipientId) {
            this.notifService.send(recipientId, {
                title: '보호자 메시지',
                body: data.content || '[카드]',
                notificationType: 'CHAT',
                referenceId: saved.messageId,
                referenceType: 'GUARDIAN_MESSAGE',
                tripId: link.tripId,
            }).catch(err => console.error('Guardian chat FCM error:', err));
        }

        return saved;
    }

    /** Mark all unread messages from the other party as read */
    async markRead(linkId: string, userId: string) {
        await this.assertChannelAccess(linkId, userId);
        await this.msgRepo
            .createQueryBuilder()
            .update()
            .set({ isRead: true })
            .where('link_id = :linkId AND sender_id != :userId AND is_read = false', { linkId, userId })
            .execute();
        return { success: true };
    }

    /** Verify user has access to the guardian channel */
    private async assertChannelAccess(linkId: string, userId: string): Promise<GuardianLink> {
        const link = await this.linkRepo.findOne({ where: { linkId } });
        if (!link) throw new NotFoundException('Guardian channel not found');
        if (link.memberId !== userId && link.guardianId !== userId) {
            throw new ForbiddenException('이 보호자 채널에 접근 권한이 없습니다.');
        }
        return link;
    }
}
