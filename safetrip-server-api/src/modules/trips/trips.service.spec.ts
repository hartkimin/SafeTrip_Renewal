import { Test, TestingModule } from '@nestjs/testing';
import { TripsService } from './trips.service';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Trip } from '../../entities/trip.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { ChatRoom } from '../../entities/chat.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { Schedule } from '../../entities/schedule.entity';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { InviteCode } from '../../entities/invite-code.entity';
import { BadRequestException, NotFoundException } from '@nestjs/common';

describe('TripsService', () => {
    let service: TripsService;

    // Create Mock Repositories
    const mockTripRepo = {
        create: jest.fn(),
        save: jest.fn(),
        find: jest.fn(),
        findOne: jest.fn(),
    };
    const mockGroupRepo = {
        create: jest.fn(),
        save: jest.fn(),
    };
    const mockMemberRepo = {
        create: jest.fn(),
        save: jest.fn(),
        find: jest.fn(),
        findOne: jest.fn(),
    };
    const mockChatRoomRepo = {
        create: jest.fn(),
        save: jest.fn(),
    };
    const mockGuardianLinkRepo = {};
    const mockScheduleRepo = {};
    const mockTravelScheduleRepo = {};
    const mockInviteCodeRepo = {
        findOne: jest.fn(),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                TripsService,
                { provide: getRepositoryToken(Trip), useValue: mockTripRepo },
                { provide: getRepositoryToken(Group), useValue: mockGroupRepo },
                { provide: getRepositoryToken(GroupMember), useValue: mockMemberRepo },
                { provide: getRepositoryToken(ChatRoom), useValue: mockChatRoomRepo },
                { provide: getRepositoryToken(GuardianLink), useValue: mockGuardianLinkRepo },
                { provide: getRepositoryToken(Schedule), useValue: mockScheduleRepo },
                { provide: getRepositoryToken(TravelSchedule), useValue: mockTravelScheduleRepo },
                { provide: getRepositoryToken(InviteCode), useValue: mockInviteCodeRepo },
            ],
        }).compile();

        service = module.get<TripsService>(TripsService);

        // Reset all mocks before each test
        jest.clearAllMocks();
    });

    it('should be defined', () => {
        expect(service).toBeDefined();
    });

    describe('create() trip', () => {
        it('should successfully create a new trip and its relations', async () => {
            const userId = 'test-user';
            const tripData = {
                tripName: 'Paris Vacation',
                destination: 'Paris',
                destinationCountryCode: 'FR',
                startDate: '2026-05-01',
                endDate: '2026-05-10',
            };

            const expectedGroupId = 'new-group-1';
            const expectedTripId = 'new-trip-1';

            mockGroupRepo.create.mockReturnValue({ groupName: tripData.tripName, createdBy: userId });
            mockGroupRepo.save.mockResolvedValue({ groupId: expectedGroupId, groupName: tripData.tripName, createdBy: userId });

            mockTripRepo.create.mockReturnValue({ ...tripData, groupId: expectedGroupId });
            mockTripRepo.save.mockResolvedValue({ tripId: expectedTripId, ...tripData, groupId: expectedGroupId });

            mockMemberRepo.create.mockReturnValue({});
            mockMemberRepo.save.mockResolvedValue({});

            mockChatRoomRepo.create.mockReturnValue({});
            mockChatRoomRepo.save.mockResolvedValue({});

            const result = await service.create(userId, tripData);

            expect(mockGroupRepo.create).toHaveBeenCalled();
            expect(mockGroupRepo.save).toHaveBeenCalled();
            expect(mockTripRepo.create).toHaveBeenCalled();
            expect(mockTripRepo.save).toHaveBeenCalled();
            expect(mockMemberRepo.create).toHaveBeenCalled();
            expect(mockChatRoomRepo.create).toHaveBeenCalled();

            expect(result).toHaveProperty('inviteCode');
            expect(result.groupId).toEqual(expectedGroupId);
        });

        it('should throw BadRequestException for durations over 15 days', async () => {
            const userId = 'test-user';
            const invalidTripData = {
                tripName: 'Long Vacation',
                startDate: '2026-05-01',
                endDate: '2026-05-20', // 19 days
            };

            await expect(service.create(userId, invalidTripData)).rejects.toThrow(BadRequestException);
            await expect(service.create(userId, invalidTripData)).rejects.toThrow('Trip duration must be between 1 and 15 days');
        });
    });

    describe('findByUser()', () => {
        it('should return a list of trips the user is active in', async () => {
            const userId = 'test-user';
            mockMemberRepo.find.mockResolvedValue([
                { tripId: 'trip-1' },
                { tripId: 'trip-2' }
            ]);
            mockTripRepo.find.mockResolvedValue([
                { tripId: 'trip-1', tripName: 'Trip 1' },
                { tripId: 'trip-2', tripName: 'Trip 2' }
            ]);

            const trips = await service.findByUser(userId);

            expect(mockMemberRepo.find).toHaveBeenCalledWith({ where: { userId, status: 'active' } });
            expect(mockTripRepo.find).toHaveBeenCalled();
            expect(trips.length).toBe(2);
        });

        it('should return empty list if user has no memberships', async () => {
            mockMemberRepo.find.mockResolvedValue([]);

            const trips = await service.findByUser('test-user');

            expect(trips).toEqual([]);
            expect(mockTripRepo.find).not.toHaveBeenCalled();
        });
    });

    describe('findById()', () => {
        it('should successfully return a trip if it exists', async () => {
            mockTripRepo.findOne.mockResolvedValue({ tripId: 'valid-id', tripName: 'Paris' });

            const trip = await service.findById('valid-id');
            expect(trip.tripId).toEqual('valid-id');
        });

        it('should throw NotFoundException if trip is missing', async () => {
            mockTripRepo.findOne.mockResolvedValue(null);

            await expect(service.findById('invalid')).rejects.toThrow(NotFoundException);
        });
    });

    describe('updateMember()', () => {
        it('should successfully update member permissions if updater is a captain', async () => {
            mockMemberRepo.findOne
                .mockResolvedValueOnce({ tripId: 'trip-1', userId: 'updater-1', status: 'active', memberRole: 'captain' }) // updater
                .mockResolvedValueOnce({ tripId: 'trip-1', memberId: 'member-1', status: 'active', memberRole: 'crew' }); // target
            mockMemberRepo.save.mockImplementation(async (m) => m);

            const result = await service.updateMember('trip-1', 'member-1', 'updater-1', { memberRole: 'crew_chief', canEditSchedule: true });

            expect(result.memberRole).toEqual('crew_chief');
            expect(result.canEditSchedule).toEqual(true);
            expect(mockMemberRepo.save).toHaveBeenCalled();
        });

        it('should throw ForbiddenException if updater lacks permission', async () => {
            mockMemberRepo.findOne.mockResolvedValueOnce({ tripId: 'trip-1', userId: 'updater-1', status: 'active', memberRole: 'crew', canManageMembers: false });

            await expect(service.updateMember('trip-1', 'member-1', 'updater-1', { canEditSchedule: true })).rejects.toThrow('Permission denied: Cannot manage members');
        });

        it('should throw NotFoundException if target member does not exist', async () => {
            mockMemberRepo.findOne
                .mockResolvedValueOnce({ tripId: 'trip-1', userId: 'updater-1', status: 'active', memberRole: 'captain' }) // updater
                .mockResolvedValueOnce(null); // target missing

            await expect(service.updateMember('trip-1', 'invalid-member', 'updater-1', { canEditSchedule: true })).rejects.toThrow(NotFoundException);
        });
    });
});
