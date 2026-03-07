import { LLMGatewayService, LLMRequest } from './llm-gateway.service';

describe('LLMGatewayService', () => {
    let service: LLMGatewayService;

    beforeEach(() => {
        service = new LLMGatewayService();
    });

    describe('getTimeout', () => {
        it('should return 2s for safety', () => {
            expect(service.getTimeout('safety')).toBe(2000);
        });
        it('should return 5s for convenience', () => {
            expect(service.getTimeout('convenience')).toBe(5000);
        });
        it('should return 10s for intelligence', () => {
            expect(service.getTimeout('intelligence')).toBe(10000);
        });
    });

    describe('call (fallback)', () => {
        it('should return rule-based fallback when no API keys set', async () => {
            const req: LLMRequest = {
                aiType: 'safety',
                prompt: 'test prompt',
                systemPrompt: 'You are a safety assistant',
            };

            const result = await service.call(req);
            expect(result.isFallback).toBe(true);
            expect(result.modelUsed).toBe('rule_based');
            expect(result.fallbackReason).toBeDefined();
        });

        it('should include latency in response', async () => {
            const result = await service.call({
                aiType: 'convenience',
                prompt: 'test',
            });
            expect(typeof result.latencyMs).toBe('number');
            expect(result.latencyMs).toBeGreaterThanOrEqual(0);
        });
    });

    describe('ruleBasedFallback', () => {
        it('should return structured response for safety type', () => {
            const result = service.ruleBasedFallback('safety', 'detect danger');
            expect(result).toBeDefined();
            expect(typeof result).toBe('string');
        });

        it('should return service unavailable message for convenience', () => {
            const result = service.ruleBasedFallback('convenience', 'recommend place');
            expect(result).toContain('AI 서비스');
        });

        it('should return disabled message for intelligence', () => {
            const result = service.ruleBasedFallback('intelligence', 'analyze');
            expect(result).toContain('사용 가능');
        });
    });
});
