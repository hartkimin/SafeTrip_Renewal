import { Controller, Get, Post, Patch, Body, Query, Param } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SafetyAiService } from './safety-ai.service';
import { ConvenienceAiService } from './convenience-ai.service';
import { IntelligenceAiService } from './intelligence-ai.service';
import { AccessGuardService, AiFeature } from './core/access-guard.service';
import { UsageLoggerService } from './core/usage-logger.service';

@ApiTags('AI')
@ApiBearerAuth('firebase-auth')
@Controller('ai')
export class AiController {
    constructor(
        private readonly safetyAi: SafetyAiService,
        private readonly convenienceAi: ConvenienceAiService,
        private readonly intelligenceAi: IntelligenceAiService,
        private readonly accessGuard: AccessGuardService,
        private readonly usageLogger: UsageLoggerService,
    ) {}

    // ── Access Check ──
    @Get('access-check')
    @ApiOperation({ summary: 'AI 기능 접근 권한 확인' })
    async checkAccess(
        @CurrentUser() userId: string,
        @Query('feature') feature: AiFeature,
        @Query('trip_id') tripId?: string,
    ) {
        return this.accessGuard.checkAccess(userId, feature, tripId);
    }

    // ── Safety AI ──
    @Post('safety/departure-check')
    @ApiOperation({ summary: '[Safety] 이탈 감지 평가' })
    async checkDeparture(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; distance_m: number; duration_min: number },
    ) {
        return this.safetyAi.checkDeparture(userId, body.trip_id, {
            distanceFromGatheringM: body.distance_m,
            durationOutsideMin: body.duration_min,
        });
    }

    @Post('safety/sos-evaluate')
    @ApiOperation({ summary: '[Safety] SOS 자동 판단' })
    async evaluateSos(
        @Body() body: { inactive_minutes: number; fall_detected: boolean },
    ) {
        return this.safetyAi.evaluateSosCondition({
            inactiveMinutes: body.inactive_minutes,
            hasFallDetected: body.fall_detected,
        });
    }

    // ── Convenience AI ──
    @Post('convenience/schedule-suggest')
    @ApiOperation({ summary: '[Convenience] 일정 자동 완성' })
    async scheduleSuggest(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; prompt: string },
    ) {
        return this.convenienceAi.generateScheduleSuggestions(userId, body.trip_id, body.prompt);
    }

    @Post('convenience/packing-list')
    @ApiOperation({ summary: '[Convenience] 짐 리스트 생성' })
    async packingList(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; country: string; days: number; member_count: number },
    ) {
        return this.convenienceAi.generatePackingList(userId, body.trip_id, {
            country: body.country, days: body.days, memberCount: body.member_count,
        });
    }

    @Post('convenience/chatbot')
    @ApiOperation({ summary: '[Convenience] AI 챗봇 대화 (AI Plus)' })
    async chatbot(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; message: string; is_minor?: boolean; age?: number },
    ) {
        return this.convenienceAi.chatWithAssistant(
            userId, body.trip_id, body.message, body.is_minor ?? false, body.age,
        );
    }

    @Post('convenience/translate')
    @ApiOperation({ summary: '[Convenience] 실시간 번역 (AI Plus)' })
    async translate(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; text: string; target_lang: string },
    ) {
        return this.convenienceAi.translate(userId, body.trip_id, body.text, body.target_lang);
    }

    @Post('convenience/chat-summary')
    @ApiOperation({ summary: '[Convenience] 채팅 요약 (AI Plus)' })
    async chatSummary(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; messages: string[] },
    ) {
        return this.convenienceAi.summarizeChat(userId, body.trip_id, body.messages);
    }

    // ── Intelligence AI ──
    @Post('intelligence/insight')
    @ApiOperation({ summary: '[Intelligence] 여행 인사이트 (AI Plus)' })
    async travelInsight(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string },
    ) {
        return this.intelligenceAi.getTravelInsight(userId, body.trip_id);
    }

    @Post('intelligence/safety-briefing')
    @ApiOperation({ summary: '[Intelligence] 맞춤 안전 브리핑 (AI Pro)' })
    async safetyBriefing(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; destination: string },
    ) {
        return this.intelligenceAi.getSafetyBriefing(userId, body.trip_id, body.destination);
    }

    @Post('intelligence/schedule-optimize')
    @ApiOperation({ summary: '[Intelligence] 일정 최적화 (AI Pro)' })
    async scheduleOptimize(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; schedules: any[] },
    ) {
        return this.intelligenceAi.optimizeSchedule(userId, body.trip_id, body.schedules);
    }

    // ── Feedback ──
    @Patch('feedback/:logId')
    @ApiOperation({ summary: 'AI 응답 피드백 (엄지 업/다운)' })
    async submitFeedback(
        @Param('logId') logId: string,
        @Body() body: { feedback: -1 | 0 | 1 },
    ) {
        await this.usageLogger.updateFeedback(logId, body.feedback);
        return { success: true };
    }
}
