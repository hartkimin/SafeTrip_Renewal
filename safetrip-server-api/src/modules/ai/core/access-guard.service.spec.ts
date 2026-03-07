import { AccessGuardService, AiFeature } from './access-guard.service';
import { ForbiddenException, BadRequestException } from '@nestjs/common';

describe('AccessGuardService', () => {
    let service: AccessGuardService;

    const mockUserRepo = { findOne: jest.fn() };
    const mockGroupMemberRepo = { findOne: jest.fn() };
    const mockTripRepo = { findOne: jest.fn() };
    const mockAiSubRepo = { findOne: jest.fn() };
    const mockAiUsageRepo = { findOne: jest.fn() };

    beforeEach(() => {
        service = new AccessGuardService(
            mockUserRepo as any,
            mockGroupMemberRepo as any,
            mockTripRepo as any,
            mockAiSubRepo as any,
            mockAiUsageRepo as any,
        );
        jest.clearAllMocks();
    });

    describe('minor restrictions (§10)', () => {
        it('should block AI chatbot for users under 14', async () => {
            mockUserRepo.findOne.mockResolvedValue({
                userId: 'u1', minorStatus: 'minor_under14',
                dateOfBirth: new Date('2015-01-01'),
            });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });

            await expect(service.checkAccess('u1', 'ai_chatbot' as AiFeature, 'trip-1'))
                .rejects.toThrow(ForbiddenException);
        });

        it('should allow Safety AI for all minors', async () => {
            mockUserRepo.findOne.mockResolvedValue({
                userId: 'u1', minorStatus: 'minor_under14',
                dateOfBirth: new Date('2015-01-01'),
            });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'safety_first' });
            mockAiSubRepo.findOne.mockResolvedValue(null);
            mockAiUsageRepo.findOne.mockResolvedValue(null);

            const result = await service.checkAccess('u1', 'danger_zone_detect' as AiFeature, 'trip-1');
            expect(result.allowed).toBe(true);
        });

        it('should block Intelligence AI personal analysis for minors', async () => {
            mockUserRepo.findOne.mockResolvedValue({
                userId: 'u1', minorStatus: 'minor_over14',
                dateOfBirth: new Date('2010-01-01'),
            });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'captain' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });

            await expect(service.checkAccess('u1', 'pattern_analysis' as AiFeature, 'trip-1'))
                .rejects.toThrow(ForbiddenException);
        });
    });

    describe('privacy level restrictions (§9)', () => {
        it('should block location-based AI for privacy_first trips', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'privacy_first' });

            await expect(service.checkAccess('u1', 'place_recommend' as AiFeature, 'trip-1'))
                .rejects.toThrow(ForbiddenException);
        });

        it('should allow non-location AI for privacy_first trips', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'privacy_first' });
            mockAiSubRepo.findOne.mockResolvedValue({ planType: 'ai_plus', status: 'active' });
            mockAiUsageRepo.findOne.mockResolvedValue(null);

            const result = await service.checkAccess('u1', 'chat_translate' as AiFeature, 'trip-1');
            expect(result.allowed).toBe(true);
        });
    });

    describe('subscription check (§3.2)', () => {
        it('should block paid features for free users', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });
            mockAiSubRepo.findOne.mockResolvedValue(null);

            await expect(service.checkAccess('u1', 'ai_chatbot' as AiFeature, 'trip-1'))
                .rejects.toThrow(BadRequestException);
        });

        it('should allow free features without subscription', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });
            mockAiSubRepo.findOne.mockResolvedValue(null);
            mockAiUsageRepo.findOne.mockResolvedValue(null);

            const result = await service.checkAccess('u1', 'schedule_autocomplete' as AiFeature, 'trip-1');
            expect(result.allowed).toBe(true);
        });
    });

    describe('role restrictions (§8)', () => {
        it('should block guardian from schedule features', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'guardian' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });

            await expect(service.checkAccess('u1', 'schedule_autocomplete' as AiFeature, 'trip-1'))
                .rejects.toThrow(ForbiddenException);
        });
    });
});
