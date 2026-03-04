import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AiService } from './ai.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@ApiTags('AI')
@ApiBearerAuth('firebase-auth')
@Controller('ai')
export class AiController {
    constructor(private readonly aiService: AiService) { }

    @Post('recommendation')
    @ApiOperation({ summary: 'AI 장소/일정 추천' })
    async getRecommendation(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; query: string }
    ) {
        return this.aiService.getRecommendation(userId, body.trip_id, body.query);
    }

    @Get('usage')
    @ApiOperation({ summary: '내 AI 사용량 및 제한 확인' })
    async getUsage(
        @CurrentUser() userId: string,
        @Query('feature') feature: 'recommendation' | 'optimization' | 'chat' | 'briefing' | 'intelligence',
        @Query('trip_id') tripId?: string
    ) {
        return this.aiService.checkAccess(userId, feature, tripId);
    }
}
