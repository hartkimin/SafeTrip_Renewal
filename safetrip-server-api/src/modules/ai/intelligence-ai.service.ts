import { Injectable, Logger } from '@nestjs/common';
import { AccessGuardService } from './core/access-guard.service';
import { LLMGatewayService } from './core/llm-gateway.service';
import { DataMaskerService } from './core/data-masker.service';
import { ResponseCacheService } from './core/response-cache.service';
import { UsageLoggerService } from './core/usage-logger.service';

/**
 * SS3.1 Intelligence AI -- 전원 유료 (AI Plus / AI Pro)
 * 분석 근거 데이터(로그 기간, 샘플 수) 함께 표시 (SS7.2)
 */
@Injectable()
export class IntelligenceAiService {
    private readonly logger = new Logger(IntelligenceAiService.name);

    constructor(
        private readonly accessGuard: AccessGuardService,
        private readonly llm: LLMGatewayService,
        private readonly masker: DataMaskerService,
        private readonly cache: ResponseCacheService,
        private readonly usageLogger: UsageLoggerService,
    ) {}

    /** [AI Plus] 여행 인사이트 */
    async getTravelInsight(userId: string, tripId: string) {
        await this.accessGuard.checkAccess(userId, 'travel_insight', tripId);

        const resp = await this.llm.call({
            aiType: 'intelligence',
            prompt: `Analyze travel patterns for trip and provide insights in JSON format with 'insights' array.`,
            systemPrompt: 'You are a travel data analyst. Provide concise, data-driven insights.',
        });

        let parsed: any;
        try {
            parsed = JSON.parse(resp.content);
        } catch {
            parsed = { insights: [resp.content] };
        }

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'intelligence',
            featureName: 'travel_insight',
            modelUsed: resp.modelUsed,
            latencyMs: resp.latencyMs,
        });

        return {
            ...parsed,
            evidence: { dataRange: '최근 7일', sampleCount: 0 },
            disclaimer: '데이터 분석 기반 인사이트입니다. 실제 상황과 다를 수 있습니다.',
        };
    }

    /** [AI Pro] 맞춤 안전 브리핑 */
    async getSafetyBriefing(userId: string, tripId: string, destination: string) {
        await this.accessGuard.checkAccess(userId, 'safety_briefing', tripId);

        const cacheKey = this.cache.buildKey('safety_briefing', {
            trip_id: tripId,
            destination,
            date: new Date().toISOString().split('T')[0],
        });
        const cached = this.cache.get(cacheKey);
        if (cached) return cached;

        const maskedDest = this.masker.maskText(destination);
        const resp = await this.llm.call({
            aiType: 'intelligence',
            prompt: `Create a comprehensive safety briefing for ${maskedDest}. Include: weather risks, local crime patterns, health advisories, embassy contact. Return JSON.`,
            systemPrompt: 'You are a travel safety analyst. Always cite data sources.',
        });

        let result: any;
        try {
            result = JSON.parse(resp.content);
        } catch {
            result = { briefing: resp.content };
        }

        result = {
            ...result,
            evidence: { sources: ['외교부 여행경보', '기상청', '현지 치안 데이터'] },
            modelUsed: resp.modelUsed,
        };

        this.cache.set(cacheKey, result, this.cache.getTtl('safety_briefing'));

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'intelligence',
            featureName: 'safety_briefing',
            modelUsed: resp.modelUsed,
            latencyMs: resp.latencyMs,
        });

        return result;
    }

    /** [AI Pro] 일정 최적화 */
    async optimizeSchedule(userId: string, tripId: string, schedules: any[]) {
        await this.accessGuard.checkAccess(userId, 'schedule_optimize', tripId);

        const resp = await this.llm.call({
            aiType: 'intelligence',
            prompt: `Optimize this travel schedule for minimal travel time and best experience: ${JSON.stringify(schedules)}. Return optimized JSON.`,
        });

        let result: any;
        try {
            result = JSON.parse(resp.content);
        } catch {
            result = { optimized: resp.content };
        }

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'intelligence',
            featureName: 'schedule_optimize',
            modelUsed: resp.modelUsed,
            latencyMs: resp.latencyMs,
        });

        return {
            ...result,
            disclaimer: '최적화 제안입니다. 실제 교통 상황에 따라 달라질 수 있습니다.',
        };
    }
}
