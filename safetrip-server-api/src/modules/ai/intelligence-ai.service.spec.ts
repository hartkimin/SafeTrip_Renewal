import { IntelligenceAiService } from './intelligence-ai.service';

describe('IntelligenceAiService', () => {
    let service: IntelligenceAiService;
    const mockAccessGuard = { checkAccess: jest.fn().mockResolvedValue({ allowed: true }) };
    const mockLLMGateway = {
        call: jest.fn().mockResolvedValue({
            content: JSON.stringify({ insights: ['High activity area: Shibuya'] }),
            modelUsed: 'gpt-4o', isFallback: false, latencyMs: 3000,
        }),
    };
    const mockCache = {
        get: jest.fn().mockReturnValue(null), set: jest.fn(),
        getTtl: jest.fn().mockReturnValue(14400000), buildKey: jest.fn().mockReturnValue('key'),
    };
    const mockUsageLogger = { log: jest.fn().mockResolvedValue({}) };
    const mockDataMasker = { maskText: jest.fn((t) => t), coarsenLocation: jest.fn((lat, lng) => ({ latitude: lat, longitude: lng })) };

    beforeEach(() => {
        service = new IntelligenceAiService(
            mockAccessGuard as any, mockLLMGateway as any,
            mockDataMasker as any, mockCache as any, mockUsageLogger as any,
        );
        jest.clearAllMocks();
    });

    it('should call access guard with travel_insight', async () => {
        await service.getTravelInsight('u1', 'trip-1');
        expect(mockAccessGuard.checkAccess).toHaveBeenCalledWith('u1', 'travel_insight', 'trip-1');
    });

    it('should include evidence metadata in response', async () => {
        const result = await service.getTravelInsight('u1', 'trip-1');
        expect(result.evidence).toBeDefined();
        expect(result.disclaimer).toContain('분석');
    });

    it('should call access guard with safety_briefing for Pro', async () => {
        await service.getSafetyBriefing('u1', 'trip-1', 'Tokyo');
        expect(mockAccessGuard.checkAccess).toHaveBeenCalledWith('u1', 'safety_briefing', 'trip-1');
    });
});
