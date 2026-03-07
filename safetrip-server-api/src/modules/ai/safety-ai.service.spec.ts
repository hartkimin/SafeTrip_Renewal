import { SafetyAiService } from './safety-ai.service';

describe('SafetyAiService', () => {
    let service: SafetyAiService;
    const mockAccessGuard = { checkAccess: jest.fn().mockResolvedValue({ allowed: true, category: 'safety' }) };
    const mockUsageLogger = { log: jest.fn().mockResolvedValue({}) };

    beforeEach(() => {
        service = new SafetyAiService(mockAccessGuard as any, mockUsageLogger as any);
        jest.clearAllMocks();
    });

    describe('evaluateDeparture', () => {
        it('should detect departure when beyond 300m for over 10min', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 400,
                durationOutsideMin: 15,
            });
            expect(result.isDeparted).toBe(true);
            expect(result.severity).toBe('high');
        });

        it('should not trigger when within 300m', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 200,
                durationOutsideMin: 20,
            });
            expect(result.isDeparted).toBe(false);
        });

        it('should not trigger when outside but under 10min', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 500,
                durationOutsideMin: 5,
            });
            expect(result.isDeparted).toBe(false);
        });

        it('should return severity "none" when not departed', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 100,
                durationOutsideMin: 2,
            });
            expect(result.severity).toBe('none');
            expect(result.distanceM).toBe(100);
            expect(result.durationMin).toBe(2);
        });

        it('should detect departure at exact boundary (301m, 10min)', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 301,
                durationOutsideMin: 10,
            });
            expect(result.isDeparted).toBe(true);
        });

        it('should NOT detect departure at exact threshold (300m, 10min)', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 300,
                durationOutsideMin: 10,
            });
            expect(result.isDeparted).toBe(false);
        });
    });

    describe('evaluateSosCondition', () => {
        it('should trigger SOS when inactive for 15+ minutes', () => {
            const result = service.evaluateSosCondition({
                inactiveMinutes: 20,
                hasFallDetected: false,
            });
            expect(result.shouldTriggerSos).toBe(true);
            expect(result.reason).toBe('inactive_timeout');
        });

        it('should trigger SOS on fall detection', () => {
            const result = service.evaluateSosCondition({
                inactiveMinutes: 0,
                hasFallDetected: true,
            });
            expect(result.shouldTriggerSos).toBe(true);
            expect(result.reason).toBe('fall_detected');
        });

        it('should not trigger when active and no fall', () => {
            const result = service.evaluateSosCondition({
                inactiveMinutes: 5,
                hasFallDetected: false,
            });
            expect(result.shouldTriggerSos).toBe(false);
            expect(result.reason).toBe('none');
        });

        it('should trigger SOS at exact 15min inactivity boundary', () => {
            const result = service.evaluateSosCondition({
                inactiveMinutes: 15,
                hasFallDetected: false,
            });
            expect(result.shouldTriggerSos).toBe(true);
        });

        it('should prioritize fall_detected reason over inactive_timeout', () => {
            const result = service.evaluateSosCondition({
                inactiveMinutes: 30,
                hasFallDetected: true,
            });
            expect(result.shouldTriggerSos).toBe(true);
            expect(result.reason).toBe('fall_detected');
        });
    });

    describe('evaluateSpeedAnomaly', () => {
        it('should detect anomalous speed above 150 km/h (41.6 m/s)', () => {
            const result = service.evaluateSpeedAnomaly(50); // 180 km/h
            expect(result.isAnomalous).toBe(true);
            expect(result.severity).toBe('medium');
            expect(result.speedKmh).toBe(180);
        });

        it('should not flag normal walking speed', () => {
            const result = service.evaluateSpeedAnomaly(1.4); // ~5 km/h
            expect(result.isAnomalous).toBe(false);
            expect(result.severity).toBe('none');
            expect(result.speedKmh).toBe(5);
        });

        it('should not flag normal driving speed', () => {
            const result = service.evaluateSpeedAnomaly(27.8); // 100 km/h
            expect(result.isAnomalous).toBe(false);
            expect(result.speedKmh).toBe(100);
        });

        it('should detect speed at boundary (41.7 m/s > 41.6)', () => {
            const result = service.evaluateSpeedAnomaly(41.7);
            expect(result.isAnomalous).toBe(true);
        });

        it('should not trigger at exactly 41.6 m/s', () => {
            const result = service.evaluateSpeedAnomaly(41.6);
            expect(result.isAnomalous).toBe(false);
        });
    });

    describe('checkDeparture (full pipeline with access + logging)', () => {
        it('should call accessGuard, evaluate, and log usage', async () => {
            const result = await service.checkDeparture('user-1', 'trip-1', {
                distanceFromGatheringM: 500,
                durationOutsideMin: 12,
            });

            expect(mockAccessGuard.checkAccess).toHaveBeenCalledWith('user-1', 'departure_detect', 'trip-1');
            expect(result.isDeparted).toBe(true);
            expect(mockUsageLogger.log).toHaveBeenCalledWith(
                expect.objectContaining({
                    userId: 'user-1',
                    tripId: 'trip-1',
                    aiType: 'safety',
                    featureName: 'departure_detect',
                    modelUsed: 'rule_based',
                }),
            );
        });

        it('should propagate access guard errors', async () => {
            mockAccessGuard.checkAccess.mockRejectedValueOnce(new Error('Access denied'));

            await expect(
                service.checkDeparture('user-1', 'trip-1', {
                    distanceFromGatheringM: 500,
                    durationOutsideMin: 12,
                }),
            ).rejects.toThrow('Access denied');
        });
    });
});
