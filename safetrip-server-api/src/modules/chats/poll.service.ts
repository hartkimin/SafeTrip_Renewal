import {
    Injectable,
    NotFoundException,
    BadRequestException,
    ForbiddenException,
    Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ChatPoll, ChatPollVote, ChatMessage, ChatRoom } from '../../entities/chat.entity';
import { GroupMember } from '../../entities/group-member.entity';

@Injectable()
export class PollService {
    private readonly logger = new Logger(PollService.name);

    constructor(
        @InjectRepository(ChatPoll) private pollRepo: Repository<ChatPoll>,
        @InjectRepository(ChatPollVote) private voteRepo: Repository<ChatPollVote>,
        @InjectRepository(ChatMessage) private messageRepo: Repository<ChatMessage>,
        @InjectRepository(ChatRoom) private roomRepo: Repository<ChatRoom>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
    ) {}

    // ------------------------------------------------------------------
    // Create Poll
    // ------------------------------------------------------------------

    /**
     * 투표 생성 (captain/crew_chief 전용)
     * DOC-T3-CHT-020 section 8: captain/crew_chief만 투표 생성 가능
     */
    async createPoll(
        roomId: string,
        userId: string,
        data: { title: string; options: string[]; closesAt?: string },
    ) {
        // 1. Find room -> get tripId
        const room = await this.roomRepo.findOne({ where: { roomId } });
        if (!room) throw new NotFoundException('채팅방을 찾을 수 없습니다.');

        const tripId = room.tripId;

        // 2. Check captain/crew_chief role
        await this.assertLeaderRole(tripId, userId);

        // 3. Validate input
        if (!data.title || data.title.trim().length === 0) {
            throw new BadRequestException('투표 제목을 입력해주세요.');
        }
        if (!data.options || data.options.length < 2) {
            throw new BadRequestException('투표 선택지는 최소 2개 이상이어야 합니다.');
        }
        if (data.options.length > 10) {
            throw new BadRequestException('투표 선택지는 최대 10개까지 가능합니다.');
        }

        // 4. Parse closesAt if provided
        let closesAt: Date | null = null;
        if (data.closesAt) {
            closesAt = new Date(data.closesAt);
            if (isNaN(closesAt.getTime())) {
                throw new BadRequestException('유효하지 않은 마감 시간입니다.');
            }
            if (closesAt <= new Date()) {
                throw new BadRequestException('마감 시간은 현재 시간 이후여야 합니다.');
            }
        }

        // 5. Build options JSONB: [{id: 0, text: "..."}]
        const options = data.options.map((text, idx) => ({
            id: idx,
            text: text.trim(),
        }));

        // 6. Create ChatMessage with messageType='poll'
        const message = this.messageRepo.create({
            roomId,
            tripId,
            senderId: userId,
            messageType: 'poll',
            content: data.title,
            metadata: { pollOptions: options },
        } as Partial<ChatMessage>);
        const savedMessage = await this.messageRepo.save(message);

        // 7. Create ChatPoll linked to message
        const poll = this.pollRepo.create({
            messageId: savedMessage.messageId,
            tripId,
            creatorId: userId,
            title: data.title,
            options,
            allowMultiple: false, // DOC-T3-CHT-020: 복수 선택 지원하지 않음
            isAnonymous: false,
            closesAt,
            isClosed: false,
        } as Partial<ChatPoll>);
        const savedPoll = await this.pollRepo.save(poll);

        return {
            success: true,
            data: {
                ...savedPoll,
                messageId: savedMessage.messageId,
                results: options.map((opt) => ({ optionId: opt.id, text: opt.text, count: 0 })),
                totalVotes: 0,
            },
        };
    }

    // ------------------------------------------------------------------
    // Get Poll with Results
    // ------------------------------------------------------------------

    /**
     * 투표 조회 + 결과 집계
     */
    async getPoll(pollId: string) {
        const poll = await this.pollRepo.findOne({ where: { pollId } });
        if (!poll) throw new NotFoundException('투표를 찾을 수 없습니다.');

        // Get all votes
        const votes = await this.voteRepo.find({ where: { pollId } });

        // Calculate results: count per option
        const optionCounts = new Map<number, number>();
        for (const opt of poll.options) {
            optionCounts.set(opt.id, 0);
        }
        for (const vote of votes) {
            for (const selectedOpt of vote.selectedOptions) {
                optionCounts.set(selectedOpt, (optionCounts.get(selectedOpt) || 0) + 1);
            }
        }

        const results = poll.options.map((opt: { id: number; text: string }) => ({
            optionId: opt.id,
            text: opt.text,
            count: optionCounts.get(opt.id) || 0,
        }));

        return {
            success: true,
            data: {
                ...poll,
                results,
                totalVotes: votes.length,
            },
        };
    }

    // ------------------------------------------------------------------
    // Cast Vote
    // ------------------------------------------------------------------

    /**
     * 투표 참여 (single choice only)
     * DOC-T3-CHT-020: 마감 전 변경 가능, 단일 선택만 허용
     */
    async castVote(pollId: string, userId: string, optionId: number) {
        // 1. Find poll
        const poll = await this.pollRepo.findOne({ where: { pollId } });
        if (!poll) throw new NotFoundException('투표를 찾을 수 없습니다.');

        // 2. Check not closed
        if (poll.isClosed) {
            throw new BadRequestException('이미 마감된 투표입니다.');
        }

        // 3. Check if closes_at has passed
        if (poll.closesAt && new Date(poll.closesAt) <= new Date()) {
            // Auto-close this poll
            await this.pollRepo.update(pollId, { isClosed: true });
            throw new BadRequestException('투표 마감 시간이 지났습니다.');
        }

        // 4. Validate optionId
        const validOption = poll.options.find((opt: { id: number }) => opt.id === optionId);
        if (!validOption) {
            throw new BadRequestException('유효하지 않은 선택지입니다.');
        }

        // 5. Check membership (guardian cannot vote)
        const member = await this.memberRepo.findOne({
            where: { tripId: poll.tripId, userId, status: 'active' },
        });
        if (!member) {
            throw new ForbiddenException('여행 멤버가 아닙니다.');
        }
        if (member.memberRole === 'guardian') {
            throw new ForbiddenException('가디언은 투표에 참여할 수 없습니다.');
        }

        // 6. Upsert vote (single choice: selectedOptions = [optionId])
        const existingVote = await this.voteRepo.findOne({
            where: { pollId, userId },
        });

        if (existingVote) {
            await this.voteRepo.update(existingVote.voteId, {
                selectedOptions: [optionId],
                votedAt: new Date(),
            } as Partial<ChatPollVote>);
        } else {
            const vote = this.voteRepo.create({
                pollId,
                userId,
                selectedOptions: [optionId],
            } as Partial<ChatPollVote>);
            await this.voteRepo.save(vote);
        }

        // 7. Return updated poll results
        return this.getPoll(pollId);
    }

    // ------------------------------------------------------------------
    // Close Poll
    // ------------------------------------------------------------------

    /**
     * 투표 수동 마감 (captain/crew_chief 전용)
     */
    async closePoll(pollId: string, userId: string) {
        const poll = await this.pollRepo.findOne({ where: { pollId } });
        if (!poll) throw new NotFoundException('투표를 찾을 수 없습니다.');

        if (poll.isClosed) {
            throw new BadRequestException('이미 마감된 투표입니다.');
        }

        // Check captain/crew_chief role
        await this.assertLeaderRole(poll.tripId, userId);

        // Close the poll
        await this.pollRepo.update(pollId, {
            isClosed: true,
            closedBy: userId,
        });

        // Return updated poll
        return this.getPoll(pollId);
    }

    // ------------------------------------------------------------------
    // Auto-Close Scheduler (every minute)
    // ------------------------------------------------------------------

    /**
     * 매 분 실행: closes_at이 지난 미마감 투표를 자동 마감
     */
    @Cron(CronExpression.EVERY_MINUTE)
    async autoCloseExpiredPolls() {
        try {
            const result = await this.pollRepo
                .createQueryBuilder()
                .update(ChatPoll)
                .set({ isClosed: true })
                .where('is_closed = :isClosed', { isClosed: false })
                .andWhere('closes_at IS NOT NULL')
                .andWhere('closes_at <= :now', { now: new Date() })
                .execute();

            if (result.affected && result.affected > 0) {
                this.logger.log(`Auto-closed ${result.affected} expired poll(s)`);
            }
        } catch (error) {
            this.logger.error('Failed to auto-close expired polls', error);
        }
    }

    // ------------------------------------------------------------------
    // Role-check helper
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
}
