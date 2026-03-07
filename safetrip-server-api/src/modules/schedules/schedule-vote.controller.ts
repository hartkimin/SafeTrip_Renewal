import {
    Controller,
    Get,
    Post,
    Patch,
    Param,
    Body,
    BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ScheduleVoteService } from './schedule-vote.service';

@ApiTags('Schedule Votes')
@ApiBearerAuth('firebase-auth')
@Controller('trips/:tripId/votes')
export class ScheduleVoteController {
    constructor(
        private readonly voteService: ScheduleVoteService,
    ) {}

    @Post()
    @ApiOperation({ summary: '투표 생성 (캡틴/크루장만 가능)' })
    @ApiParam({ name: 'tripId', type: 'string' })
    async createVote(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
        @Body() body: {
            title: string;
            options: { label: string; scheduleData?: any }[];
            deadline?: string;
        },
    ) {
        if (!body.title) {
            throw new BadRequestException('title is required');
        }
        if (!body.options || body.options.length < 2) {
            throw new BadRequestException('At least 2 options are required');
        }

        const result = await this.voteService.createVote(
            tripId,
            userId,
            body.title,
            body.options,
            body.deadline,
        );
        return { success: true, data: result, message: 'Vote created successfully' };
    }

    @Get()
    @ApiOperation({ summary: '투표 목록 조회' })
    @ApiParam({ name: 'tripId', type: 'string' })
    async getVotes(@Param('tripId') tripId: string) {
        const votes = await this.voteService.getVotes(tripId);
        return { success: true, data: { votes, total: votes.length } };
    }

    @Post(':voteId/respond')
    @ApiOperation({ summary: '투표하기' })
    @ApiParam({ name: 'tripId', type: 'string' })
    @ApiParam({ name: 'voteId', type: 'string' })
    async castVote(
        @Param('voteId') voteId: string,
        @CurrentUser() userId: string,
        @Body() body: { optionId: string },
    ) {
        if (!body.optionId) {
            throw new BadRequestException('optionId is required');
        }

        const response = await this.voteService.castVote(voteId, userId, body.optionId);
        return { success: true, data: response, message: 'Vote cast successfully' };
    }

    @Patch(':voteId/close')
    @ApiOperation({ summary: '투표 종료 (캡틴만 가능)' })
    @ApiParam({ name: 'tripId', type: 'string' })
    @ApiParam({ name: 'voteId', type: 'string' })
    async closeVote(
        @Param('voteId') voteId: string,
        @CurrentUser() userId: string,
    ) {
        const vote = await this.voteService.closeVote(voteId, userId);
        return { success: true, data: vote, message: 'Vote closed successfully' };
    }
}
