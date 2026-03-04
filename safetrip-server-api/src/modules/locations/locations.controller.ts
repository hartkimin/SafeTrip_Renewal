import { Controller, Get, Post, Patch, Param, Body, Query, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { LocationsService } from './locations.service';

@ApiTags('Locations')
@ApiBearerAuth('firebase-auth')
@Controller()
export class LocationsController {
    constructor(private readonly locationsService: LocationsService) { }

    @Post('trips/:tripId/locations/batch')
    @ApiOperation({ summary: '9.A.1 위치 데이터 저장 (단건/다건 배치)' })
    @HttpCode(HttpStatus.CREATED)
    async batchRecord(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Body('locations') locations: any[],
    ) {
        // Validation for body or letting validation pipe handle it later
        await this.locationsService.batchRecord(userId, tripId, locations || []);
        return {
            success: true,
            data: null,
            message: `${locations?.length || 0}개의 위치 데이터 저장 완료`
        };
    }

    @Get('trips/:tripId/locations')
    @ApiOperation({ summary: '9.A.2 특정 멤버의 위치 이력 조회' })
    async getMemberLocations(
        @CurrentUser() requestUserId: string,
        @Param('tripId') tripId: string,
        @Query('user_id') targetUserId?: string,
        @Query('start_time') startTime?: string,
        @Query('end_time') endTime?: string,
        @Query('limit') limit = 100,
    ) {
        // If not specified, default to self
        const queryUserId = targetUserId || requestUserId;
        const result = await this.locationsService.getLocations(tripId, queryUserId, startTime, endTime, limit);
        return {
            success: true,
            data: result
        };
    }

    @Get('trips/:tripId/locations/latest')
    @ApiOperation({ summary: '9.A.3 그룹 멤버 최신 위치 조회' })
    async getGroupLatestLocations(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
    ) {
        const result = await this.locationsService.getGroupLocations(tripId);
        return {
            success: true,
            data: result
        };
    }

    @Get('trips/:tripId/locations/guardian-view')
    @ApiOperation({ summary: '가디언용 멤버 최신 위치 조회 (프라이버시 등급 반영)' })
    async getGuardianView(
        @CurrentUser() guardianUserId: string,
        @Param('tripId') tripId: string,
        @Query('member_user_id') memberUserId: string,
    ) {
        const result = await this.locationsService.getGuardianView(tripId, memberUserId, guardianUserId);
        return {
            success: true,
            data: result
        };
    }

    @Get('trips/:tripId/locations/sharing-settings')
    @ApiOperation({ summary: '9.A.4 내 위치 공유 설정 조회' })
    async getSharingSettings(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
    ) {
        const result = await this.locationsService.getSharingSettings(tripId, userId);
        return {
            success: true,
            data: result
        };
    }

    @Patch('trips/:tripId/locations/sharing-settings')
    @ApiOperation({ summary: '9.A.5 내 위치 공유 설정 변경' })
    async updateSharingSettings(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Body() body: { is_sharing: boolean; visibility_type?: string, sharing_duration_hours?: number },
    ) {
        const result = await this.locationsService.updateSharing(tripId, userId, body.is_sharing, body.visibility_type);
        return {
            success: true,
            data: result,
            message: '위치 공유 설정 변경 완료'
        };
    }

    // -- 9.B Stay Points / Schedules -- 
    @Post('trips/:tripId/locations/schedules')
    @ApiOperation({ summary: '일정 기반 공유 스케줄 설정' })
    async setSchedule(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Body() body: any,
    ) {
        const result = await this.locationsService.setSchedule(tripId, userId, body);
        return {
            success: true,
            data: result
        };
    }

    @Get('trips/:tripId/locations/stay-points')
    @ApiOperation({ summary: '체류 지점 조회' })
    async getStayPoints(@CurrentUser() userId: string, @Param('tripId') tripId: string) {
        const result = await this.locationsService.getStayPoints(tripId, userId);
        return {
            success: true,
            data: result
        };
    }
    @Get('locations/users/:userId/movement-sessions/summary')
    @ApiOperation({ summary: '9.4 이동 세션 요약 목록 조회' })
    async getMovementSessionsSummary(
        @Param('userId') userId: string,
        @Query('page') page = 1,
        @Query('limit') limit = 20,
        @Query('need_images') need_images?: string,
        @Query('target_date') target_date?: string,
        @Query('timezone_offset') timezone_offset = 0
    ) {
        const result = await this.locationsService.getMovementSessionsSummary(userId, +page, +limit, need_images, target_date, +timezone_offset);
        return { success: true, data: result };
    }

    @Get('locations/users/:userId/movement-sessions/date-range')
    @ApiOperation({ summary: '9.5 이동 세션 날짜 범위 조회' })
    async getMovementSessionsDateRange(
        @Param('userId') userId: string,
        @Query('timezone_offset') timezone_offset = 0
    ) {
        const result = await this.locationsService.getMovementSessionsDateRange(userId, +timezone_offset);
        return { success: true, data: result };
    }

    @Get('locations/users/:userId/movement-sessions/by-date')
    @ApiOperation({ summary: '9.6 날짜별 이동 세션 목록 조회' })
    async getMovementSessionsByDate(
        @Param('userId') userId: string,
        @Query('date') date: string,
        @Query('timezone_offset') timezone_offset = 0,
        @Query('need_images') need_images?: string
    ) {
        if (!date) {
            return { success: false, data: null, message: "date is required (YYYY-MM-DD format)" };
        }
        const result = await this.locationsService.getMovementSessionsByDate(userId, date, +timezone_offset, need_images);
        return { success: true, data: result };
    }

    @Get('locations/users/:userId/movement-sessions/:sessionId')
    @ApiOperation({ summary: '9.7 이동 세션 상세 조회' })
    async getMovementSessionDetail(
        @Param('userId') userId: string,
        @Param('sessionId') sessionId: string
    ) {
        const result = await this.locationsService.getMovementSessionDetail(userId, sessionId);
        if (!result) return { success: false, data: null, message: "Movement session not found" };
        return { success: true, data: result };
    }

    @Patch('locations/users/:userId/movement-sessions/:sessionId/complete')
    @ApiOperation({ summary: '9.8 이동 세션 완료 처리' })
    async completeMovementSession(
        @Param('userId') userId: string,
        @Param('sessionId') sessionId: string,
        @Body('latitude') latitude: number,
        @Body('longitude') longitude: number,
        @Body('recorded_at') recorded_at: string
    ) {
        if (latitude === undefined || longitude === undefined || !recorded_at) {
            return { success: false, data: null, message: "latitude, longitude, recorded_at required" };
        }
        const result = await this.locationsService.completeMovementSession(userId, sessionId, latitude, longitude, recorded_at);
        return { success: true, data: { success: true } };
    }

    @Get('locations/users/:userId/movement-sessions/:sessionId/events')
    @ApiOperation({ summary: '9.9 이동 세션 이벤트 목록 조회' })
    async getMovementSessionEvents(
        @Param('userId') userId: string,
        @Param('sessionId') sessionId: string
    ) {
        const result = await this.locationsService.getMovementSessionEvents(userId, sessionId);
        return { success: true, data: result };
    }
}
