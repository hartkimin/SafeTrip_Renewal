import { Test, TestingModule } from '@nestjs/testing';
import { GuardiansService } from './guardians.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
    Guardian, GuardianLink, GuardianPause,
    GuardianLocationRequest, GuardianSnapshot, GuardianReleaseRequest,
} from '../../entities/guardian.entity';
import { User } from '../../entities/user.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Schedule } from '../../entities/schedule.entity';
import { PaymentsService } from '../payments/payments.service';
import { BadRequestException } from '@nestjs/common';

describe('GuardiansService — P0 비즈니스 원칙 정합성', () => {
    let service: GuardiansService;

    const mockGuardianRepo = { create: jest.fn(), save: jest.fn(), findOne: jest.fn() };
    const mockLinkRepo = {
        create: jest.fn().mockReturnValue({ linkId: 'new-link', status: 'pending' }),
        save: jest.fn().mockImplementation(link => Promise.resolve({ ...link, linkId: link.linkId || 'new-link' })),
        findOne: jest.fn(),
        count: jest.fn(),
    };
    const mockPauseRepo = {};
    const mockLocReqRepo = { count: jest.fn() };
    const mockSnapshotRepo = {};
    const mockReleaseRequestRepo = {};
    const mockUserRepo = { findOne: jest.fn() };
    const mockGroupMemberRepo = { findOne: jest.fn() };
    const mockScheduleRepo = {};
    const mockPaymentsService = {
        checkGuardianQuota: jest.fn().mockResolvedValue({ maxGuardians: 2 }),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                GuardiansService,
                { provide: getRepositoryToken(Guardian), useValue: mockGuardianRepo },
                { provide: getRepositoryToken(GuardianLink), useValue: mockLinkRepo },
                { provide: getRepositoryToken(GuardianPause), useValue: mockPauseRepo },
                { provide: getRepositoryToken(GuardianLocationRequest), useValue: mockLocReqRepo },
                { provide: getRepositoryToken(GuardianSnapshot), useValue: mockSnapshotRepo },
                { provide: getRepositoryToken(GuardianReleaseRequest), useValue: mockReleaseRequestRepo },
                { provide: getRepositoryToken(User), useValue: mockUserRepo },
                { provide: getRepositoryToken(GroupMember), useValue: mockGroupMemberRepo },
                { provide: getRepositoryToken(Schedule), useValue: mockScheduleRepo },
                { provide: PaymentsService, useValue: mockPaymentsService },
            ],
        }).compile();

        service = module.get<GuardiansService>(GuardiansService);
        jest.clearAllMocks();
    });

    describe('F5: createLink — 멤버+가디언 겸직 방지 (§17#4)', () => {
        it('같은 여행의 멤버가 가디언으로 등록 시도 → BadRequestException', async () => {
            mockUserRepo.findOne.mockResolvedValueOnce({ userId: 'guardian-user', phoneNumber: '010-1111-1111' });
            mockGroupMemberRepo.findOne.mockResolvedValueOnce({
                memberId: 'mem-1', userId: 'guardian-user', tripId: 'trip-1',
                memberRole: 'crew', status: 'active',
            });

            await expect(
                service.createLink('trip-1', 'member-1', '010-1111-1111'),
            ).rejects.toThrow(BadRequestException);
        });
    });

    describe('F8: createLink — 개인 가디언 카운트 guardian_type 분리 (§17#6)', () => {
        it('개인 가디언 2명일 때 3번째 추가 → BadRequestException', async () => {
            mockUserRepo.findOne.mockResolvedValueOnce({ userId: 'guardian-3', phoneNumber: '010-3333-3333' });
            mockGroupMemberRepo.findOne.mockResolvedValueOnce(null); // no member conflict
            mockPaymentsService.checkGuardianQuota.mockResolvedValueOnce({ maxGuardians: 2 });
            mockLinkRepo.count.mockResolvedValueOnce(2); // 2 personal guardians already
            mockLinkRepo.findOne.mockResolvedValueOnce(null); // no duplicate

            await expect(
                service.createLink('trip-1', 'member-1', '010-3333-3333', 'personal'),
            ).rejects.toThrow(BadRequestException);
        });

        it('개인 가디언 1명 → 2번째 추가 성공', async () => {
            mockUserRepo.findOne.mockResolvedValueOnce({ userId: 'guardian-2', phoneNumber: '010-2222-2222' });
            mockGroupMemberRepo.findOne.mockResolvedValueOnce(null);
            mockPaymentsService.checkGuardianQuota.mockResolvedValueOnce({ maxGuardians: 2 });
            mockLinkRepo.count.mockResolvedValueOnce(1); // 1 personal guardian
            mockLinkRepo.findOne.mockResolvedValueOnce(null);

            const result = await service.createLink('trip-1', 'member-1', '010-2222-2222', 'personal');
            expect(result).toHaveProperty('link_id');
        });
    });

    describe('F7: createLink — 전체 가디언 여행당 2명 상한 (§17#7)', () => {
        it('전체 가디언 3번째 추가 → BadRequestException', async () => {
            mockUserRepo.findOne.mockResolvedValueOnce({ userId: 'guardian-3', phoneNumber: '010-3333-3333' });
            mockGroupMemberRepo.findOne.mockResolvedValueOnce(null);
            mockLinkRepo.count.mockResolvedValueOnce(2); // 2 group guardians
            mockLinkRepo.findOne.mockResolvedValueOnce(null);

            await expect(
                service.createLink('trip-1', 'member-1', '010-3333-3333', 'group'),
            ).rejects.toThrow(BadRequestException);
        });
    });
});
