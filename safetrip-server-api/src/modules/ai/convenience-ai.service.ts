import { Injectable, Logger } from '@nestjs/common';
import { AccessGuardService, AiFeature } from './core/access-guard.service';
import { LLMGatewayService } from './core/llm-gateway.service';
import { DataMaskerService } from './core/data-masker.service';
import { ResponseCacheService } from './core/response-cache.service';
import { UsageLoggerService } from './core/usage-logger.service';

/**
 * SS3.1 Convenience AI -- free basic features + AI Plus premium features
 *
 * Free:
 *   - schedule_autocomplete: schedule auto-complete suggestions
 *   - packing_list: basic packing list generation
 *
 * AI Plus:
 *   - ai_chatbot: AI travel assistant chatbot
 *   - chat_translate: real-time translation
 *   - chat_summary: chat message summarization
 */
@Injectable()
export class ConvenienceAiService {
    private readonly logger = new Logger(ConvenienceAiService.name);

    constructor(
        private readonly accessGuard: AccessGuardService,
        private readonly llm: LLMGatewayService,
        private readonly masker: DataMaskerService,
        private readonly cache: ResponseCacheService,
        private readonly usageLogger: UsageLoggerService,
    ) {}

    /**
     * [Free] Schedule auto-complete suggestions
     * Generates AI-powered schedule item suggestions based on prompt.
     */
    async generateScheduleSuggestions(userId: string, tripId: string, prompt: string) {
        await this.accessGuard.checkAccess(userId, 'schedule_autocomplete', tripId);

        const cacheKey = this.cache.buildKey('schedule_autocomplete', {
            trip_id: tripId,
            prompt_hash: prompt.slice(0, 20),
        });
        const cached = this.cache.get(cacheKey);
        if (cached) {
            await this.usageLogger.log({
                userId,
                tripId,
                aiType: 'convenience',
                featureName: 'schedule_autocomplete',
                isCached: true,
                modelUsed: 'cache',
            });
            return cached;
        }

        const maskedPrompt = this.masker.maskText(prompt);
        const resp = await this.llm.call({
            aiType: 'convenience',
            prompt: maskedPrompt,
            systemPrompt:
                'You are a travel schedule assistant. Return JSON with suggestions array. ' +
                'Each suggestion has title (string) and time (HH:MM string).',
        });

        let result: any;
        try {
            result = JSON.parse(resp.content);
        } catch {
            result = { raw: resp.content };
        }

        this.cache.set(cacheKey, result, this.cache.getTtl('schedule_autocomplete'));

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'convenience',
            featureName: 'schedule_autocomplete',
            modelUsed: resp.modelUsed,
            latencyMs: resp.latencyMs,
            isFallback: resp.isFallback,
            fallbackReason: resp.fallbackReason,
        });

        return result;
    }

    /**
     * [Free] Basic packing list generation
     * Generates a packing list tailored to destination, trip duration, and group size.
     */
    async generatePackingList(
        userId: string,
        tripId: string,
        params: { country: string; days: number; memberCount: number },
    ) {
        await this.accessGuard.checkAccess(userId, 'packing_list', tripId);

        const resp = await this.llm.call({
            aiType: 'convenience',
            prompt:
                `Generate a packing list for a ${params.days}-day trip to ${params.country} ` +
                `for ${params.memberCount} people. Return JSON with categories and items.`,
        });

        let result: any;
        try {
            result = JSON.parse(resp.content);
        } catch {
            result = { raw: resp.content };
        }

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'convenience',
            featureName: 'packing_list',
            modelUsed: resp.modelUsed,
            latencyMs: resp.latencyMs,
            isFallback: resp.isFallback,
        });

        return result;
    }

    /**
     * [AI Plus] AI chatbot travel assistant
     * Minor users (14-17) get travel-only filtering; under-14 blocked by AccessGuard.
     */
    async chatWithAssistant(
        userId: string,
        tripId: string,
        message: string,
        isMinor: boolean,
        age?: number,
    ) {
        await this.accessGuard.checkAccess(userId, 'ai_chatbot', tripId);

        const maskedMessage = this.masker.maskText(message);

        let systemPrompt =
            'You are SafeTrip AI travel assistant. Answer travel-related questions helpfully.';
        if (isMinor && age && age >= 14) {
            systemPrompt +=
                ' The user is a minor (14-17). Only answer travel-related questions. ' +
                'If asked non-travel questions, reply: "여행과 관련된 질문을 해주세요."';
        }

        const resp = await this.llm.call({
            aiType: 'convenience',
            prompt: maskedMessage,
            systemPrompt,
        });

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'convenience',
            featureName: 'ai_chatbot',
            modelUsed: resp.modelUsed,
            latencyMs: resp.latencyMs,
            isMinorUser: isMinor,
        });

        return {
            reply: resp.content,
            modelUsed: resp.modelUsed,
            disclaimer: 'AI가 생성한 정보로, 실제와 다를 수 있습니다.',
        };
    }

    /**
     * [AI Plus] Real-time translation
     */
    async translate(userId: string, tripId: string, text: string, targetLang: string) {
        await this.accessGuard.checkAccess(userId, 'chat_translate', tripId);

        const maskedText = this.masker.maskText(text);
        const resp = await this.llm.call({
            aiType: 'convenience',
            prompt: `Translate to ${targetLang}: "${maskedText}"`,
        });

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'convenience',
            featureName: 'chat_translate',
            modelUsed: resp.modelUsed,
            latencyMs: resp.latencyMs,
        });

        return { translated: resp.content, modelUsed: resp.modelUsed };
    }

    /**
     * [AI Plus] Chat message summarization
     * Cached indefinitely per chat room + message count (TTL = Infinity).
     */
    async summarizeChat(userId: string, tripId: string, messages: string[]) {
        await this.accessGuard.checkAccess(userId, 'chat_summary', tripId);

        const cacheKey = this.cache.buildKey('chat_summary', {
            chat_room: tripId,
            msg_count: messages.length,
        });
        const cached = this.cache.get(cacheKey);
        if (cached) return cached;

        const masked = messages.map((m) => this.masker.maskText(m));
        const resp = await this.llm.call({
            aiType: 'convenience',
            prompt: `Summarize these chat messages concisely in Korean:\n${masked.join('\n')}`,
        });

        const result = { summary: resp.content, modelUsed: resp.modelUsed };
        this.cache.set(cacheKey, result, this.cache.getTtl('chat_summary'));

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'convenience',
            featureName: 'chat_summary',
            modelUsed: resp.modelUsed,
            latencyMs: resp.latencyMs,
        });

        return result;
    }
}
