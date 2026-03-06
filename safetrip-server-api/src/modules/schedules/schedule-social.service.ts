import {
    Injectable,
    NotFoundException,
    ForbiddenException,
    BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ScheduleComment } from '../../entities/schedule-comment.entity';
import { ScheduleReaction } from '../../entities/schedule-reaction.entity';
import { TravelSchedule } from '../../entities/travel-schedule.entity';

const ALLOWED_EMOJIS = ['\u{1F44D}', '\u{2764}\u{FE0F}', '\u{1F60A}', '\u{1F389}', '\u{1F44F}'];

@Injectable()
export class ScheduleSocialService {
    constructor(
        @InjectRepository(ScheduleComment)
        private commentRepo: Repository<ScheduleComment>,
        @InjectRepository(ScheduleReaction)
        private reactionRepo: Repository<ScheduleReaction>,
        @InjectRepository(TravelSchedule)
        private scheduleRepo: Repository<TravelSchedule>,
    ) {}

    /**
     * Validate that a schedule exists and is not deleted.
     */
    private async validateScheduleExists(scheduleId: string): Promise<TravelSchedule> {
        const schedule = await this.scheduleRepo.findOne({
            where: { travelScheduleId: scheduleId },
        });
        if (!schedule || schedule.deletedAt) {
            throw new NotFoundException('Schedule not found');
        }
        return schedule;
    }

    /**
     * GET comments for a schedule with user info, ordered by created_at ASC.
     * Excludes soft-deleted comments.
     */
    async getComments(scheduleId: string): Promise<ScheduleComment[]> {
        return this.commentRepo
            .createQueryBuilder('c')
            .where('c.schedule_id = :scheduleId', { scheduleId })
            .andWhere('c.deleted_at IS NULL')
            .orderBy('c.created_at', 'ASC')
            .getMany();
    }

    /**
     * POST create a comment on a schedule.
     * Validates the schedule exists before inserting.
     */
    async addComment(
        scheduleId: string,
        userId: string,
        content: string,
    ): Promise<ScheduleComment> {
        if (!content || content.trim().length === 0) {
            throw new BadRequestException('Comment content is required');
        }

        await this.validateScheduleExists(scheduleId);

        const comment = this.commentRepo.create({
            scheduleId,
            userId,
            content: content.trim(),
        });

        return this.commentRepo.save(comment);
    }

    /**
     * DELETE (soft) a comment. Only the comment author can delete.
     */
    async deleteComment(commentId: string, userId: string): Promise<void> {
        const comment = await this.commentRepo.findOne({
            where: { id: commentId },
        });

        if (!comment || comment.deletedAt) {
            throw new NotFoundException('Comment not found');
        }

        if (comment.userId !== userId) {
            throw new ForbiddenException('Only the comment author can delete this comment');
        }

        comment.deletedAt = new Date();
        await this.commentRepo.save(comment);
    }

    /**
     * GET reactions for a schedule, grouped by emoji.
     * Returns: { emoji: string, count: number, users: string[] }[]
     */
    async getReactions(
        scheduleId: string,
    ): Promise<{ emoji: string; count: number; users: string[] }[]> {
        const reactions = await this.reactionRepo.find({
            where: { scheduleId },
        });

        // Group by emoji
        const emojiMap = new Map<string, string[]>();
        for (const r of reactions) {
            if (!emojiMap.has(r.emoji)) {
                emojiMap.set(r.emoji, []);
            }
            emojiMap.get(r.emoji)!.push(r.userId);
        }

        return Array.from(emojiMap.entries()).map(([emoji, users]) => ({
            emoji,
            count: users.length,
            users,
        }));
    }

    /**
     * POST toggle a reaction on a schedule.
     * Adds the reaction if it does not exist, removes it if it does.
     * Validates emoji is one of the allowed set.
     */
    async toggleReaction(
        scheduleId: string,
        userId: string,
        emoji: string,
    ): Promise<{ action: 'added' | 'removed' }> {
        if (!ALLOWED_EMOJIS.includes(emoji)) {
            throw new BadRequestException(
                `Invalid emoji. Allowed: ${ALLOWED_EMOJIS.join(' ')}`,
            );
        }

        await this.validateScheduleExists(scheduleId);

        // Check if reaction already exists
        const existing = await this.reactionRepo.findOne({
            where: { scheduleId, userId, emoji },
        });

        if (existing) {
            await this.reactionRepo.remove(existing);
            return { action: 'removed' };
        }

        const reaction = this.reactionRepo.create({
            scheduleId,
            userId,
            emoji,
        });
        await this.reactionRepo.save(reaction);
        return { action: 'added' };
    }
}
