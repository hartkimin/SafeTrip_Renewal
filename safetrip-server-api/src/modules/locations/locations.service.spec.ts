import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { LocationsService } from './locations.service';
import { Location, LocationSharing, LocationSchedule, StayPoint, MovementSession } from '../../entities/location.entity';
import { PlannedRoute } from '../../entities/planned-route.entity';
import { RouteDeviation } from '../../entities/route-deviation.entity';
import { DataSource } from 'typeorm';

describe('LocationsService', () => {
    let service: LocationsService;

    const mockRepo = () => ({
        find: jest.fn(),
        findOne: jest.fn(),
        save: jest.fn(),
        create: jest.fn((data) => data),
        count: jest.fn(),
        update: jest.fn(),
        createQueryBuilder: jest.fn(() => ({
            where: jest.fn().mockReturnThis(),
            andWhere: jest.fn().mockReturnThis(),
            orderBy: jest.fn().mockReturnThis(),
            addOrderBy: jest.fn().mockReturnThis(),
            skip: jest.fn().mockReturnThis(),
            take: jest.fn().mockReturnThis(),
            select: jest.fn().mockReturnThis(),
            distinctOn: jest.fn().mockReturnThis(),
            getManyAndCount: jest.fn().mockResolvedValue([[], 0]),
            getMany: jest.fn().mockResolvedValue([]),
            getRawOne: jest.fn().mockResolvedValue({}),
            getRawMany: jest.fn().mockResolvedValue([]),
        })),
    });

    const mockDataSource = {
        getRepository: jest.fn(() => ({ findOne: jest.fn() })),
        query: jest.fn(),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                LocationsService,
                { provide: getRepositoryToken(Location), useFactory: mockRepo },
                { provide: getRepositoryToken(LocationSharing), useFactory: mockRepo },
                { provide: getRepositoryToken(LocationSchedule), useFactory: mockRepo },
                { provide: getRepositoryToken(StayPoint), useFactory: mockRepo },
                { provide: getRepositoryToken(PlannedRoute), useFactory: mockRepo },
                { provide: getRepositoryToken(RouteDeviation), useFactory: mockRepo },
                { provide: getRepositoryToken(MovementSession), useFactory: mockRepo },
                { provide: DataSource, useValue: mockDataSource },
            ],
        }).compile();

        service = module.get<LocationsService>(LocationsService);
    });

    describe('getMemberMovementHistory', () => {
        it('§18.4 무료 가디언 24h 초과 시 upgrade_required 반환', async () => {
            const yesterday = new Date();
            yesterday.setDate(yesterday.getDate() - 2);
            const dateStr = yesterday.toISOString().split('T')[0];

            const result = await service.getMemberMovementHistory(
                'trip-1', 'user-1', dateStr,
                { role: 'guardian', isGuardian: true, isPaid: false },
            );

            expect(result.upgrade_required).toBe(true);
            expect(result.sessions).toEqual([]);
        });

        it('§18.5 유료 가디언 전체 기간 조회 성공', async () => {
            const result = await service.getMemberMovementHistory(
                'trip-1', 'user-1', '2026-03-01',
                { role: 'guardian', isGuardian: true, isPaid: true },
            );

            expect(result.upgrade_required).toBeUndefined();
        });
    });

    describe('detectStayPoints', () => {
        it('§18.10 반경 100m + 5분 기준 체류 지점 감지', async () => {
            // Build a cluster of 4 nearby points spanning 6 minutes, then a far-away 5th point
            // to trigger the dist > 100m branch and evaluate the cluster.
            const mockLocations = [
                { latitude: 37.5, longitude: 127.0, recordedAt: new Date('2026-03-07T10:00:00Z') },
                { latitude: 37.5001, longitude: 127.0001, recordedAt: new Date('2026-03-07T10:02:00Z') },
                { latitude: 37.5002, longitude: 127.0, recordedAt: new Date('2026-03-07T10:04:00Z') },
                { latitude: 37.50005, longitude: 127.00005, recordedAt: new Date('2026-03-07T10:06:00Z') },
                { latitude: 37.51, longitude: 127.01, recordedAt: new Date('2026-03-07T10:20:00Z') },
            ];

            const locationRepo = service['locationRepo'];
            (locationRepo.find as jest.Mock).mockResolvedValue(mockLocations);
            (service['stayPointRepo'].save as jest.Mock).mockResolvedValue([]);

            const result = await service.detectStayPoints('user-1', 'trip-1', 'session-1');

            expect(result.length).toBeGreaterThanOrEqual(1);
            expect(result[0].durationMinutes).toBeGreaterThanOrEqual(5);
        });
    });

    describe('haversineDistance', () => {
        it('서울-부산 거리 약 325km', () => {
            const dist = service['haversineDistance'](37.5665, 126.978, 35.1796, 129.0756);
            expect(dist).toBeGreaterThan(300);
            expect(dist).toBeLessThan(400);
        });
    });

    describe('getMovementSessionStats', () => {
        it('세션 통계 정상 계산', async () => {
            const mockSession = {
                sessionId: 's1',
                userId: 'u1',
                startTime: new Date('2026-03-07T09:00:00Z'),
                endTime: new Date('2026-03-07T10:00:00Z'),
                isCompleted: true,
            };
            const mockLocations = [
                { latitude: 37.5, longitude: 127.0, speed: 5, recordedAt: new Date('2026-03-07T09:00:00Z') },
                { latitude: 37.501, longitude: 127.001, speed: 10, recordedAt: new Date('2026-03-07T09:30:00Z') },
                { latitude: 37.502, longitude: 127.002, speed: 3, recordedAt: new Date('2026-03-07T10:00:00Z') },
            ];

            (service['sessionRepo'].findOne as jest.Mock).mockResolvedValue(mockSession);
            (service['locationRepo'].find as jest.Mock).mockResolvedValue(mockLocations);

            const stats = await service.getMovementSessionStats('u1', 's1');

            expect(stats).toBeDefined();
            expect(stats!.session_id).toBe('s1');
            expect(stats!.total_distance_km).toBeGreaterThan(0);
            expect(stats!.max_speed).toBe(10);
            expect(stats!.duration_minutes).toBe(60);
            expect(stats!.location_count).toBe(3);
        });
    });
});
