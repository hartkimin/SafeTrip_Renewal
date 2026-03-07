import { Test, TestingModule } from '@nestjs/testing';
import { GroupsService } from './groups.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { InviteCode } from '../../entities/invite-code.entity';
import { Trip } from '../../entities/trip.entity';
import { Schedule } from '../../entities/schedule.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { LocationSharing } from '../../entities/location.entity';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { DataSource } from 'typeorm';

describe('GroupsService', () => {
    let service: GroupsService;

    const mockGroupRepo = {
        create: jest.fn(),
        save: jest.fn(),
        findOne: jest.fn(),
    };
    const mockMemberRepo = {
        create: jest.fn(),
        save: jest.fn(),
        find: jest.fn(),
        findOne: jest.fn(),
        count: jest.fn(),
        update: jest.fn(),
    };
    const mockInviteCodeRepo = {
        create: jest.fn(),
        save: jest.fn(),
        find: jest.fn(),
        findOne: jest.fn(),
    };
    const mockTripRepo = {
        findOne: jest.fn(),
    };
    const mockScheduleRepo = {
        find: jest.fn(),
        findOne: jest.fn(),
        createQueryBuilder: jest.fn(),
    };
    const mockGuardianLinkRepo = {
        findOne: jest.fn(),
    };
    const mockLocationSharingRepo = {
        find: jest.fn(),
        save: jest.fn(),
    };
    const mockDataSource = {
        query: jest.fn(),
        createQueryRunner: jest.fn().mockReturnValue({
            connect: jest.fn(),
            startTransaction: jest.fn(),
            commitTransaction: jest.fn(),
            rollbackTransaction: jest.fn(),
            release: jest.fn(),
            manager: {
                findOne: jest.fn(),
                update: jest.fn(),
                query: jest.fn(),
                save: jest.fn(),
            },
        }),
    };

    beforeEach(async () => {
        jest.clearAllMocks();

        const module: TestingModule = await Test.createTestingModule({
            providers: [
                GroupsService,
                { provide: getRepositoryToken(Group), useValue: mockGroupRepo },
                { provide: getRepositoryToken(GroupMember), useValue: mockMemberRepo },
                { provide: getRepositoryToken(InviteCode), useValue: mockInviteCodeRepo },
                { provide: getRepositoryToken(Trip), useValue: mockTripRepo },
                { provide: getRepositoryToken(Schedule), useValue: mockScheduleRepo },
                { provide: getRepositoryToken(GuardianLink), useValue: mockGuardianLinkRepo },
                { provide: getRepositoryToken(LocationSharing), useValue: mockLocationSharingRepo },
                { provide: DataSource, useValue: mockDataSource },
            ],
        }).compile();

        service = module.get<GroupsService>(GroupsService);
    });

    it('should be defined', () => {
        expect(service).toBeDefined();
    });

    describe('addMember() - 동일 여행 중복 멤버 방지 (§17#3)', () => {
        const groupId = 'group-1';
        const tripId = 'trip-1';
        const userId = 'user-1';

        it('이미 active 멤버인 유저를 같은 여행에 추가하면 BadRequestException', async () => {
            // Given: 유저가 이미 해당 여행에 crew로 active 상태
            const existingMember = {
                memberId: 'member-existing',
                tripId,
                userId,
                memberRole: 'crew',
                status: 'active',
            };
            mockMemberRepo.findOne.mockResolvedValue(existingMember);

            // When & Then: 같은 유저를 같은 여행에 다시 추가하면 에러
            await expect(
                service.addMember(groupId, tripId, userId, 'crew_chief'),
            ).rejects.toThrow(BadRequestException);

            // memberRepo.findOne이 중복 체크에서 호출되었는지 확인
            expect(mockMemberRepo.findOne).toHaveBeenCalledWith({
                where: { tripId, userId, status: 'active' },
            });
        });

        it('active 멤버가 아닌 경우 정상 추가', async () => {
            // Given: 중복 멤버 체크 -> 없음
            mockMemberRepo.findOne.mockResolvedValueOnce(null);
            // F5: 가디언 겸직 체크 -> 없음
            mockGuardianLinkRepo.findOne.mockResolvedValueOnce(null);
            // checkDateOverlap: tripRepo.findOne으로 target trip 조회
            mockTripRepo.findOne.mockResolvedValueOnce({
                tripId,
                startDate: new Date('2026-05-01'),
                endDate: new Date('2026-05-10'),
            });
            // checkDateOverlap: 기존 active 멤버십 없음
            mockDataSource.query.mockResolvedValueOnce([]);

            const newMember = {
                memberId: 'member-new',
                groupId,
                tripId,
                userId,
                memberRole: 'crew',
            };
            mockMemberRepo.create.mockReturnValue(newMember);
            mockMemberRepo.save.mockResolvedValue(newMember);

            const result = await service.addMember(groupId, tripId, userId, 'crew');

            expect(result.memberId).toEqual('member-new');
            expect(mockMemberRepo.create).toHaveBeenCalled();
            expect(mockMemberRepo.save).toHaveBeenCalled();
        });
    });

    describe('F5: addMember — 멤버+가디언 겸직 방지 (§17#4)', () => {
        it('이미 가디언인 유저를 같은 여행의 멤버로 추가하면 BadRequestException', async () => {
            mockMemberRepo.findOne.mockResolvedValueOnce(null); // no existing member
            mockGuardianLinkRepo.findOne.mockResolvedValueOnce({
                linkId: 'link-1', tripId: 'trip-1', guardianId: 'user-1', status: 'accepted',
            });

            await expect(
                service.addMember('group-1', 'trip-1', 'user-1', 'crew'),
            ).rejects.toThrow(BadRequestException);
        });
    });

    describe('F4: removeMember — 캡틴 탈퇴 시 위임 강제 (§07.2)', () => {
        it('캡틴이 active 여행 + 다른 멤버 있을 때 → ForbiddenException', async () => {
            mockMemberRepo.findOne.mockResolvedValueOnce({
                memberId: 'mem-1', userId: 'captain-1', tripId: 'trip-1',
                memberRole: 'captain', status: 'active',
            });
            mockTripRepo.findOne.mockResolvedValueOnce({ tripId: 'trip-1', status: 'active' });
            mockMemberRepo.count.mockResolvedValueOnce(3);

            await expect(
                service.removeMember('trip-1', 'captain-1', 'captain-1'),
            ).rejects.toThrow(ForbiddenException);
        });

        it('캡틴 혼자 active 여행 → ForbiddenException', async () => {
            mockMemberRepo.findOne.mockResolvedValueOnce({
                memberId: 'mem-1', userId: 'captain-1', tripId: 'trip-1',
                memberRole: 'captain', status: 'active',
            });
            mockTripRepo.findOne.mockResolvedValueOnce({ tripId: 'trip-1', status: 'planning' });
            mockMemberRepo.count.mockResolvedValueOnce(0);

            await expect(
                service.removeMember('trip-1', 'captain-1', 'captain-1'),
            ).rejects.toThrow(ForbiddenException);
        });

        it('캡틴 completed 여행 → 성공', async () => {
            mockMemberRepo.findOne.mockResolvedValueOnce({
                memberId: 'mem-1', userId: 'captain-1', tripId: 'trip-1',
                memberRole: 'captain', status: 'active',
            });
            mockTripRepo.findOne.mockResolvedValueOnce({ tripId: 'trip-1', status: 'completed' });
            mockMemberRepo.update.mockResolvedValueOnce({});
            mockLocationSharingRepo.find.mockResolvedValueOnce([]);

            const result = await service.removeMember('trip-1', 'captain-1', 'captain-1');
            expect(result).toEqual({ message: 'Member removed' });
        });
    });

    describe('F9: removeMember — 공개범위 자동 정리 (§08.5)', () => {
        it('멤버 탈퇴 시 다른 멤버의 visibility_member_ids에서 제거됨', async () => {
            mockMemberRepo.findOne.mockResolvedValueOnce({
                memberId: 'mem-1', userId: 'user-departing', tripId: 'trip-1',
                memberRole: 'crew', status: 'active',
            });
            mockMemberRepo.update.mockResolvedValueOnce({});

            const sharingRecord = {
                locationSharingId: 'ls-1', tripId: 'trip-1', userId: 'other-user',
                visibilityType: 'specified',
                visibilityMemberIds: ['user-stay', 'user-departing', 'user-stay2'],
            };
            mockLocationSharingRepo.find.mockResolvedValueOnce([sharingRecord]);
            mockLocationSharingRepo.save.mockResolvedValueOnce({});

            await service.removeMember('trip-1', 'user-departing', 'admin-1');

            expect(mockLocationSharingRepo.save).toHaveBeenCalledWith(
                expect.objectContaining({
                    visibilityMemberIds: ['user-stay', 'user-stay2'],
                }),
            );
        });
    });
});
