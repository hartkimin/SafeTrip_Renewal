import { UsageLoggerService } from './usage-logger.service';

describe('UsageLoggerService', () => {
    let service: UsageLoggerService;
    const mockRepo = {
        create: jest.fn().mockImplementation((data) => ({ ...data })),
        save: jest.fn().mockImplementation(async (entity) => ({ ...entity, logId: 'test-uuid' })),
        update: jest.fn().mockResolvedValue({ affected: 1 }),
    };

    beforeEach(() => {
        service = new UsageLoggerService(mockRepo as any);
        jest.clearAllMocks();
    });

    it('should log with 90-day expires_at for adult', async () => {
        await service.log({ aiType: 'convenience', featureName: 'schedule_autocomplete', isMinorUser: false });
        const saved = mockRepo.create.mock.calls[0][0];
        const diffDays = (saved.expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
        expect(diffDays).toBeGreaterThan(89);
        expect(diffDays).toBeLessThan(91);
    });

    it('should log with 30-day expires_at for minor', async () => {
        await service.log({ aiType: 'safety', featureName: 'sos_auto_detect', isMinorUser: true });
        const saved = mockRepo.create.mock.calls[0][0];
        const diffDays = (saved.expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
        expect(diffDays).toBeGreaterThan(29);
        expect(diffDays).toBeLessThan(31);
    });

    it('should update feedback', async () => {
        await service.updateFeedback('log-1', 1);
        expect(mockRepo.update).toHaveBeenCalledWith('log-1', { feedback: 1 });
    });
});
