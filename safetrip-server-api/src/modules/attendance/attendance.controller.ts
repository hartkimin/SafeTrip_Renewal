import { Controller, Get, Post, Patch, Param, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AttendanceService } from './attendance.service';

@ApiTags('Attendance')
@ApiBearerAuth('firebase-auth')
@Controller('trips/:tripId/attendance')
export class AttendanceController {
    constructor(private readonly attendanceService: AttendanceService) {}

    @Get()
    @ApiOperation({ summary: '출석 체크 목록 조회 (최근 10건)' })
    async listChecks(@Param('tripId') tripId: string) {
        return this.attendanceService.listChecks(tripId);
    }

    @Post()
    @ApiOperation({ summary: '출석 체크 시작' })
    @HttpCode(HttpStatus.CREATED)
    async startCheck(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
        @Body('group_id') groupId: string,
    ) {
        return this.attendanceService.startCheck(tripId, userId, groupId);
    }

    @Patch(':checkId/respond')
    @ApiOperation({ summary: '출석 체크 응답 (present / absent)' })
    async respond(
        @Param('tripId') tripId: string,
        @Param('checkId') checkId: string,
        @CurrentUser() userId: string,
        @Body('response_type') responseType: 'present' | 'absent',
    ) {
        return this.attendanceService.respond(tripId, checkId, userId, responseType);
    }

    @Patch(':checkId/close')
    @ApiOperation({ summary: '출석 체크 종료 (미응답자 자동 absent 처리)' })
    async closeCheck(
        @Param('tripId') tripId: string,
        @Param('checkId') checkId: string,
        @CurrentUser() userId: string,
    ) {
        return this.attendanceService.closeCheck(tripId, checkId, userId);
    }

    @Get(':checkId/responses')
    @ApiOperation({ summary: '출석 체크 응답 목록 조회' })
    async listResponses(
        @Param('tripId') tripId: string,
        @Param('checkId') checkId: string,
    ) {
        return this.attendanceService.listResponses(tripId, checkId);
    }
}
