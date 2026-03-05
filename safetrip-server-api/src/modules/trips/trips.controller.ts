import { Controller, Get, Post, Patch, Param, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { TripsService } from './trips.service';

@ApiTags('Trips')
@ApiBearerAuth('firebase-auth')
@Controller('trips')
export class TripsController {
    constructor(private readonly tripsService: TripsService) { }

    @Post()
    @ApiOperation({ summary: '여행 생성 (그룹+captain+채팅방 자동 생성)' })
    create(
        @CurrentUser() userId: string,
        @Body() body: {
            title: string;
            country_code: string;
            country_name?: string;
            trip_type: string;
            start_date: string;
            end_date: string;
            sharing_mode?: string;
            privacy_level?: string;
        },
    ) {
        return this.tripsService.create(userId, body);
    }

    @Get()
    @ApiOperation({ summary: '내 여행 목록 조회' })
    findMyTrips(@CurrentUser() userId: string) {
        return this.tripsService.findByUser(userId);
    }

    @Public()
    @Get('preview/:code')
    @ApiOperation({ summary: '초대 코드로 여행 미리보기' })
    previewByInviteCode(@Param('code') code: string) {
        return this.tripsService.previewByInviteCode(code);
    }

    @Public()
    @Get('invite/:inviteCode')
    @ApiOperation({ summary: '여행자용 초대 코드로 여행 정보 조회' })
    findByInviteCode(@Param('inviteCode') inviteCode: string) {
        return this.tripsService.findByInviteCode(inviteCode);
    }

    @Public()
    @Get('verify-invite-code/:code')
    @ApiOperation({ summary: '초대 코드 유효성 검증' })
    verifyInviteCode(@Param('code') code: string) {
        return this.tripsService.verifyInviteCode(code);
    }

    @Post('join')
    @ApiOperation({ summary: '초대 코드로 그룹에 참여' })
    joinTrip(
        @CurrentUser() userId: string,
        @Body() body: { invite_code: string },
    ) {
        return this.tripsService.joinTrip(body.invite_code, userId);
    }

    @Post('invite/accept')
    @ApiOperation({ summary: '초대 수락' })
    acceptInvite(
        @CurrentUser() userId: string,
        @Body() body: { inviteCode: string },
    ) {
        return this.tripsService.acceptInvite(body.inviteCode, userId);
    }

    // ── §5.A 보호자 초대코드 조회 ──
    @Public()
    @Get('guardian-invite/:inviteCode')
    @ApiOperation({ summary: '보호자용 초대 코드로 여행 정보 조회' })
    findByGuardianInviteCode(@Param('inviteCode') inviteCode: string) {
        return this.tripsService.findByGuardianInviteCode(inviteCode);
    }

    // ── §5.A group_id 기반 여행 조회 ──
    @Public()
    @Get('groups/:groupId')
    @ApiOperation({ summary: 'group_id로 여행 조회' })
    findByGroupId(@Param('groupId') groupId: string) {
        return this.tripsService.findByGroupId(groupId);
    }

    // ── §5.A user_id 기반 내 여행 목록 ──
    @Get('users/:userId/trips')
    @ApiOperation({ summary: '사용자의 여행 목록 조회 (enriched)' })
    getUserTrips(@Param('userId') userId: string) {
        return this.tripsService.getUserTrips(userId);
    }

    // ── §5.B 국가/타임존 ──
    @Public()
    @Get('groups/:groupId/countries')
    @ApiOperation({ summary: 'group_id 기반 국가 목록 조회' })
    getCountriesByGroup(@Param('groupId') groupId: string) {
        return this.tripsService.getCountriesByGroup(groupId);
    }

    @Public()
    @Get('users/:userId/countries')
    @ApiOperation({ summary: 'user_id 기반 여행 국가 목록 조회' })
    getCountriesByUser(@Param('userId') userId: string) {
        return this.tripsService.getCountriesByUser(userId);
    }

    @Public()
    @Get('groups/:groupId/timezones')
    @ApiOperation({ summary: 'group_id 기반 타임존 조회' })
    getTimezonesByGroup(@Param('groupId') groupId: string) {
        return this.tripsService.getTimezonesByGroup(groupId);
    }

    // ── 가디언 ──
    @Post('guardian-approval/request')
    @ApiOperation({ summary: '가디언 승인 요청' })
    createGuardianApprovalRequest(
        @CurrentUser() userId: string,
        @Body() body: { inviteCode: string; guardianPhone: string },
    ) {
        return this.tripsService.createGuardianApprovalRequest(userId, body);
    }

    @Get('guardian-approval/status')
    @ApiOperation({ summary: '내 가디언 승인 상태 조회' })
    getGuardianApprovalStatus(@CurrentUser() userId: string) {
        return this.tripsService.getGuardianApprovalStatus(userId);
    }

    // ── 파라미터 라우트 (반드시 정적 라우트 뒤에 위치) ──
    @Public()
    @Get(':tripId')
    @ApiOperation({ summary: '여행 상세 조회' })
    findOne(@Param('tripId') tripId: string) {
        return this.tripsService.findById(tripId);
    }

    @Patch(':tripId')
    @ApiOperation({ summary: '여행 수정' })
    update(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Body() body: any,
    ) {
        return this.tripsService.updateTrip(tripId, userId, body);
    }

    @Patch(':tripId/members/:memberId')
    @ApiOperation({ summary: '여행 멤버 권한 및 역할 수정' })
    updateMember(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Param('memberId') memberId: string,
        @Body() body: any,
    ) {
        return this.tripsService.updateMember(tripId, memberId, userId, body);
    }

    // ── 일정 ──
    @Get(':tripId/schedules')
    @ApiOperation({ summary: '여행 일정 목록 조회' })
    getSchedules(@Param('tripId') tripId: string) {
        return this.tripsService.getSchedules(tripId);
    }

    @Post(':tripId/schedules')
    @ApiOperation({ summary: '일정 추가' })
    addSchedule(
        @Param('tripId') tripId: string,
        @Body() body: { dayNumber: number; scheduleDate: string; title?: string },
    ) {
        return this.tripsService.addSchedule(tripId, body);
    }

    @Post(':tripId/schedules/items')
    @ApiOperation({ summary: '일정 아이템 추가' })
    async addScheduleItem(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Body() body: any,
    ) {
        // Need to grab groupId from trip first
        const trip = await this.tripsService.findById(tripId);
        return this.tripsService.addScheduleItem(tripId, trip.groupId, userId, body);
    }

    // ── 초대 ──
    @Post(':tripId/invite')
    @ApiOperation({ summary: '여행 초대 생성' })
    createInvite(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Body() body: { inviteType: string; invitePhone?: string },
    ) {
        return this.tripsService.createInvite(tripId, userId, body);
    }

    @Post(':tripId/bulk-invite')
    @ApiOperation({ summary: 'B2B/단체 멤버 일괄 초대 (명단 기반)' })
    bulkInvite(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
        @Body() body: { invitees: { phone: string; name?: string; role: string }[] },
    ) {
        return this.tripsService.bulkInvite(tripId, userId, body.invitees);
    }
}
