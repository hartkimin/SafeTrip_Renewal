import { ConvenienceAiService } from './convenience-ai.service';

describe('ConvenienceAiService', () => {
    let service: ConvenienceAiService;
    const mockAccessGuard = { checkAccess: jest.fn().mockResolvedValue({ allowed: true }) };
    const mockLLMGateway = {
        call: jest.fn().mockResolvedValue({
            content: JSON.stringify({ suggestions: [{ title: 'Visit museum', time: '10:00' }] }),
            modelUsed: 'gpt-4o',
            isFallback: false,
            latencyMs: 800,
        }),
    };
    const mockDataMasker = {
        maskText: jest.fn((t: string) => t),
        coarsenLocation: jest.fn((lat: number, lng: number) => ({ latitude: 37.57, longitude: 126.98 })),
        maskTripName: jest.fn((name: string, id: string) => `trip_${id.split('-')[0]}`),
    };
    const mockCache = {
        get: jest.fn().mockReturnValue(null),
        set: jest.fn(),
        getTtl: jest.fn().mockReturnValue(3600000),
        buildKey: jest.fn().mockReturnValue('test_key'),
    };
    const mockUsageLogger = { log: jest.fn().mockResolvedValue({}) };

    beforeEach(() => {
        service = new ConvenienceAiService(
            mockAccessGuard as any,
            mockLLMGateway as any,
            mockDataMasker as any,
            mockCache as any,
            mockUsageLogger as any,
        );
        jest.clearAllMocks();
    });

    it('should call access guard before generating suggestions', async () => {
        await service.generateScheduleSuggestions('u1', 'trip-1', 'Japan trip');
        expect(mockAccessGuard.checkAccess).toHaveBeenCalledWith('u1', 'schedule_autocomplete', 'trip-1');
    });

    it('should mask data before LLM call', async () => {
        await service.generateScheduleSuggestions('u1', 'trip-1', 'Japan trip');
        expect(mockDataMasker.maskText).toHaveBeenCalled();
    });

    it('should return cached response on cache hit', async () => {
        mockCache.get.mockReturnValueOnce({ cached: true });
        const result = await service.generateScheduleSuggestions('u1', 'trip-1', 'Japan trip');
        expect(result).toEqual({ cached: true });
        expect(mockLLMGateway.call).not.toHaveBeenCalled();
    });

    it('should log usage after call', async () => {
        await service.generateScheduleSuggestions('u1', 'trip-1', 'Japan trip');
        expect(mockUsageLogger.log).toHaveBeenCalledWith(
            expect.objectContaining({
                aiType: 'convenience',
                featureName: 'schedule_autocomplete',
            }),
        );
    });
});
