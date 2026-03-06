import {
    Injectable,
    NotFoundException,
    ForbiddenException,
    BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { ScheduleVote } from '../../entities/schedule-vote.entity';
import { ScheduleVoteOption } from '../../entities/schedule-vote-option.entity';
import { ScheduleVoteResponse } from '../../entities/schedule-vote-response.entity';
import { GroupMember } from '../../entities/group-member.entity';

@Injectable()
export class ScheduleVoteService {
    constructor(
        @InjectRepository(ScheduleVote)
        private voteRepo: Repository<ScheduleVote>,
        @InjectRepository(ScheduleVoteOption)
        private optionRepo: Repository<ScheduleVoteOption>,
        @InjectRepository(ScheduleVoteResponse)
        private responseRepo: Repository<ScheduleVoteResponse>,
        @InjectRepository(GroupMember)
        private memberRepo: Repository<GroupMember>,
        private dataSource: DataSource,
    ) {}

    /**
     * Check if user is captain or crew_chief for the given trip.
     */
    private async checkLeaderPermission(tripId: string, userId: string): Promise<void> {
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });

        if (!member) {
            throw new ForbiddenException('Not a member of this trip');
        }

        if (member.memberRole !== 'captain' && member.memberRole !== 'crew_chief') {
            throw new ForbiddenException('Only captain or crew_chief can create votes');
        }
    }

    /**
     * Check if user is captain for the given trip.
     */
    private async checkCaptainPermission(tripId: string, userId: string): Promise<void> {
        const member = await this.memberRepo.findOne({
            where: { tripId, userId, status: 'active' },
        });

        if (!member) {
            throw new ForbiddenException('Not a member of this trip');
        }

        if (member.memberRole !== 'captain') {
            throw new ForbiddenException('Only captain can close votes');
        }
    }

    /**
     * POST create a new vote.
     * Only captain/crew_chief can create.
     */
    async createVote(
        tripId: string,
        userId: string,
        title: string,
        options: { label: string; scheduleData?: any }[],
        deadline?: string,
    ): Promise<{ vote: ScheduleVote; options: ScheduleVoteOption[] }> {
        await this.checkLeaderPermission(tripId, userId);

        if (!title || title.trim().length === 0) {
            throw new BadRequestException('Vote title is required');
        }
        if (!options || options.length < 2) {
            throw new BadRequestException('At least 2 options are required');
        }

        const queryRunner = this.dataSource.createQueryRunner();
        await queryRunner.connect();
        await queryRunner.startTransaction();

        try {
            const vote = this.voteRepo.create({
                tripId,
                title: title.trim(),
                createdBy: userId,
                deadline: deadline ? new Date(deadline) : null,
            });
            const savedVote = await queryRunner.manager.save(ScheduleVote, vote);

            const voteOptions: ScheduleVoteOption[] = [];
            for (const opt of options) {
                const option = this.optionRepo.create({
                    voteId: savedVote.id,
                    label: opt.label,
                    scheduleData: opt.scheduleData || null,
                });
                voteOptions.push(await queryRunner.manager.save(ScheduleVoteOption, option));
            }

            await queryRunner.commitTransaction();
            return { vote: savedVote, options: voteOptions };
        } catch (err) {
            await queryRunner.rollbackTransaction();
            throw err;
        } finally {
            await queryRunner.release();
        }
    }

    /**
     * GET all votes for a trip with option counts.
     */
    async getVotes(tripId: string): Promise<any[]> {
        const votes = await this.voteRepo.find({
            where: { tripId },
            order: { createdAt: 'DESC' },
        });

        const result: any[] = [];
        for (const vote of votes) {
            const options = await this.optionRepo.find({
                where: { voteId: vote.id },
            });

            const optionsWithCount = await Promise.all(
                options.map(async (opt) => {
                    const count = await this.responseRepo.count({
                        where: { voteId: vote.id, optionId: opt.id },
                    });
                    return {
                        ...opt,
                        responseCount: count,
                    };
                }),
            );

            const totalResponses = await this.responseRepo.count({
                where: { voteId: vote.id },
            });

            result.push({
                ...vote,
                options: optionsWithCount,
                totalResponses,
            });
        }

        return result;
    }

    /**
     * POST cast a vote. Validates:
     * - Vote is open
     * - Deadline not passed
     * - User hasn't already voted
     * - Option belongs to the vote
     */
    async castVote(
        voteId: string,
        userId: string,
        optionId: string,
    ): Promise<ScheduleVoteResponse> {
        const vote = await this.voteRepo.findOne({ where: { id: voteId } });
        if (!vote) {
            throw new NotFoundException('Vote not found');
        }
        if (vote.status !== 'open') {
            throw new BadRequestException('Vote is closed');
        }
        if (vote.deadline && new Date(vote.deadline) < new Date()) {
            throw new BadRequestException('Vote deadline has passed');
        }

        // Verify option belongs to this vote
        const option = await this.optionRepo.findOne({
            where: { id: optionId, voteId },
        });
        if (!option) {
            throw new NotFoundException('Option not found for this vote');
        }

        // Check if user already voted
        const existing = await this.responseRepo.findOne({
            where: { voteId, userId },
        });
        if (existing) {
            throw new BadRequestException('User has already voted');
        }

        const response = this.responseRepo.create({
            voteId,
            optionId,
            userId,
        });

        return this.responseRepo.save(response);
    }

    /**
     * PATCH close a vote. Only captain can close.
     */
    async closeVote(voteId: string, userId: string): Promise<ScheduleVote> {
        const vote = await this.voteRepo.findOne({ where: { id: voteId } });
        if (!vote) {
            throw new NotFoundException('Vote not found');
        }

        await this.checkCaptainPermission(vote.tripId, userId);

        if (vote.status === 'closed') {
            throw new BadRequestException('Vote is already closed');
        }

        vote.status = 'closed';
        return this.voteRepo.save(vote);
    }
}
