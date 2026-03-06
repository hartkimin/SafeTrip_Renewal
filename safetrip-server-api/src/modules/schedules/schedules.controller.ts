import {
    Controller,
    Get,
    Post,
    Patch,
    Delete,
    Param,
    Body,
    Query,
    BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SchedulesService } from './schedules.service';

@ApiTags('Schedules')
@ApiBearerAuth('firebase-auth')
@Controller('trips/:tripId/schedules')
export class SchedulesController {
    constructor(private readonly schedulesService: SchedulesService) {}

    @Get()
    @ApiOperation({ summary: '일정 목록 조회 (날짜별 필터 가능)' })
    @ApiParam({ name: 'tripId', type: 'string' })
    @ApiQuery({ name: 'date', required: false, description: 'YYYY-MM-DD filter' })
    async getSchedules(
        @Param('tripId') tripId: string,
        @Query('date') date?: string,
    ) {
        const schedules = await this.schedulesService.getSchedulesByDate(tripId, date);
        return {
            success: true,
            data: { schedules, total: schedules.length },
        };
    }

    @Get('dates')
    @ApiOperation({ summary: '일정이 존재하는 날짜 목록 조회' })
    @ApiParam({ name: 'tripId', type: 'string' })
    async getScheduleDates(@Param('tripId') tripId: string) {
        const dates = await this.schedulesService.getScheduleDates(tripId);
        return {
            success: true,
            data: { dates },
        };
    }

    @Get('conflicts')
    @ApiOperation({ summary: '일정 충돌 확인' })
    @ApiParam({ name: 'tripId', type: 'string' })
    @ApiQuery({ name: 'date', required: true })
    @ApiQuery({ name: 'startTime', required: true })
    @ApiQuery({ name: 'endTime', required: true })
    @ApiQuery({ name: 'excludeId', required: false })
    async checkConflicts(
        @Param('tripId') tripId: string,
        @Query('date') date: string,
        @Query('startTime') startTime: string,
        @Query('endTime') endTime: string,
        @Query('excludeId') excludeId?: string,
    ) {
        if (!date || !startTime || !endTime) {
            throw new BadRequestException('date, startTime, and endTime are required');
        }

        const conflicts = await this.schedulesService.checkConflicts(
            tripId,
            date,
            startTime,
            endTime,
            excludeId,
        );
        return {
            success: true,
            data: { conflicts, hasConflict: conflicts.length > 0 },
        };
    }

    @Get('share-timeline')
    @ApiOperation({ summary: '공유 타임라인 세그먼트 조회 (privacy_first)' })
    @ApiParam({ name: 'tripId', type: 'string' })
    @ApiQuery({ name: 'date', required: true, description: 'YYYY-MM-DD' })
    async getShareTimeline(
        @Param('tripId') tripId: string,
        @Query('date') date: string,
    ) {
        if (!date) {
            throw new BadRequestException('date is required');
        }
        const timeline = await this.schedulesService.getShareTimeline(tripId, date);
        return { success: true, data: timeline };
    }

    @Post()
    @ApiOperation({ summary: '일정 생성' })
    @ApiParam({ name: 'tripId', type: 'string' })
    async createSchedule(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
        @Body()
        body: {
            title: string;
            schedule_date: string;
            schedule_type?: string;
            start_time?: string;
            end_time?: string;
            all_day?: boolean;
            description?: string;
            location?: string;
            location_name?: string;
            location_address?: string;
            location_lat?: number;
            location_lng?: number;
            estimated_cost?: number;
            currency_code?: string;
            booking_reference?: string;
            booking_status?: string;
            booking_url?: string;
            timezone?: string;
        },
    ) {
        if (!body.title || !body.schedule_date) {
            throw new BadRequestException('title and schedule_date are required');
        }

        const schedule = await this.schedulesService.createSchedule(
            tripId,
            userId,
            body,
        );
        return {
            success: true,
            data: schedule,
            message: 'Schedule created successfully',
        };
    }

    @Patch(':scheduleId')
    @ApiOperation({ summary: '일정 수정' })
    @ApiParam({ name: 'tripId', type: 'string' })
    @ApiParam({ name: 'scheduleId', type: 'string' })
    async updateSchedule(
        @Param('tripId') tripId: string,
        @Param('scheduleId') scheduleId: string,
        @CurrentUser() userId: string,
        @Body() body: Record<string, any>,
    ) {
        const schedule = await this.schedulesService.updateSchedule(
            tripId,
            scheduleId,
            userId,
            body,
        );
        return {
            success: true,
            data: schedule,
            message: 'Schedule updated successfully',
        };
    }

    @Delete(':scheduleId')
    @ApiOperation({ summary: '일정 삭제 (soft delete)' })
    @ApiParam({ name: 'tripId', type: 'string' })
    @ApiParam({ name: 'scheduleId', type: 'string' })
    async deleteSchedule(
        @Param('tripId') tripId: string,
        @Param('scheduleId') scheduleId: string,
        @CurrentUser() userId: string,
    ) {
        await this.schedulesService.deleteSchedule(tripId, scheduleId, userId);
        return {
            success: true,
            data: { schedule_id: scheduleId },
            message: 'Schedule deleted successfully',
        };
    }
}
