import { Injectable, Logger } from '@nestjs/common';

export interface LLMRequest {
    aiType: 'safety' | 'convenience' | 'intelligence';
    prompt: string;
    systemPrompt?: string;
    preferredModel?: 'openai' | 'anthropic';
    temperature?: number;
    maxTokens?: number;
}

export interface LLMResponse {
    content: string;
    modelUsed: string;
    isFallback: boolean;
    fallbackReason?: string;
    latencyMs: number;
}

/**
 * SS6 AI 모델 선택 및 폴백 전략
 * 3단계: Cloud LLM -> On-device (interface only) -> Rule-based
 */
@Injectable()
export class LLMGatewayService {
    private readonly logger = new Logger(LLMGatewayService.name);

    /** SS7.1 타임아웃 (ms) */
    getTimeout(aiType: string): number {
        switch (aiType) {
            case 'safety': return 2000;
            case 'convenience': return 5000;
            case 'intelligence': return 10000;
            default: return 5000;
        }
    }

    async call(req: LLMRequest): Promise<LLMResponse> {
        const start = Date.now();
        const timeout = this.getTimeout(req.aiType);

        // 1차: Cloud LLM
        try {
            const result = await this.callCloudLLM(req, timeout);
            return { ...result, latencyMs: Date.now() - start };
        } catch (err) {
            this.logger.warn(`Cloud LLM failed: ${(err as Error).message}. Falling back.`);
        }

        // 2차: On-device (interface only -- skip to 3차)
        // Phase 3에서 실제 구현 예정

        // 3차: Rule-based fallback
        const content = this.ruleBasedFallback(req.aiType, req.prompt);
        return {
            content,
            modelUsed: 'rule_based',
            isFallback: true,
            fallbackReason: 'cloud_llm_unavailable',
            latencyMs: Date.now() - start,
        };
    }

    private async callCloudLLM(req: LLMRequest, timeout: number): Promise<LLMResponse> {
        const model = req.preferredModel || (req.aiType === 'safety' ? 'anthropic' : 'openai');

        if (model === 'openai') {
            return this.callOpenAI(req, timeout);
        } else {
            return this.callAnthropic(req, timeout);
        }
    }

    private async callOpenAI(req: LLMRequest, timeout: number): Promise<LLMResponse> {
        const apiKey = process.env.OPENAI_API_KEY;
        if (!apiKey) throw new Error('OPENAI_API_KEY not configured');

        const OpenAI = require('openai');
        const client = new OpenAI({ apiKey, timeout });

        const messages: any[] = [];
        if (req.systemPrompt) messages.push({ role: 'system', content: req.systemPrompt });
        messages.push({ role: 'user', content: req.prompt });

        const response = await client.chat.completions.create({
            model: 'gpt-4o',
            messages,
            temperature: req.temperature ?? 0.7,
            max_tokens: req.maxTokens ?? 2048,
        });

        return {
            content: response.choices[0].message.content || '',
            modelUsed: 'gpt-4o',
            isFallback: false,
            latencyMs: 0, // caller overwrites
        };
    }

    private async callAnthropic(req: LLMRequest, timeout: number): Promise<LLMResponse> {
        const apiKey = process.env.ANTHROPIC_API_KEY;
        if (!apiKey) throw new Error('ANTHROPIC_API_KEY not configured');

        const Anthropic = require('@anthropic-ai/sdk');
        const client = new Anthropic({ apiKey, timeout });

        const response = await client.messages.create({
            model: 'claude-sonnet-4-20250514',
            max_tokens: req.maxTokens ?? 2048,
            system: req.systemPrompt || undefined,
            messages: [{ role: 'user', content: req.prompt }],
        });

        const textBlock = response.content.find((b: any) => b.type === 'text');

        return {
            content: textBlock?.text || '',
            modelUsed: 'claude-sonnet-4-20250514',
            isFallback: false,
            latencyMs: 0,
        };
    }

    /** SS6.1 3차 -- 규칙 기반 대응 */
    ruleBasedFallback(aiType: string, prompt: string): string {
        switch (aiType) {
            case 'safety':
                return JSON.stringify({
                    status: 'rule_based_active',
                    message: '규칙 기반 안전 모니터링이 활성화되어 있습니다.',
                    capabilities: ['departure_detect', 'sos_inactive_timer', 'geofence_breach'],
                });
            case 'convenience':
                return '현재 AI 서비스 점검 중입니다. 잠시 후 다시 시도해주세요.';
            case 'intelligence':
                return '인터넷 연결 시 사용 가능합니다.';
            default:
                return 'AI 서비스를 이용할 수 없습니다.';
        }
    }
}
