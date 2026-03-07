import { Controller, Get, Post, Patch, Delete, Param, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { GuardiansService } from './guardians.service';

@ApiTags('Guardians')
@ApiBearerAuth('firebase-auth')
@Controller('trips/:tripId/guardians')
export class GuardiansController {
    constructor(private readonly guardiansService: GuardiansService) { }

    // ── Static routes first (before :linkId parameterized routes) ──

    @Get('me')
    @ApiOperation({ summary: '나의 가디언 목록 조회 (여행자 시점)' })
    async getMyGuardians(
        @Param('tripId') tripId: string,
        @CurrentUser() memberId: string,
    ) {
        return this.guardiansService.getMyGuardians(tripId, memberId);
    }

    @Get('pending')
    @ApiOperation({ summary: '대기 중인 가디언 초대 목록 조회 (가디언 시점)' })
    async getPendingInvites(
        @Param('tripId') tripId: string,
        @CurrentUser() guardianId: string,
    ) {
        return this.guardiansService.getPendingInvites(guardianId);
    }

    @Get('linked-members')
    @ApiOperation({ summary: '연결된 멤버 목록 조회 (가디언 시점)' })
    async getLinkedMembers(
        @Param('tripId') tripId: string,
        @CurrentUser() guardianId: string,
    ) {
        return this.guardiansService.getLinkedMembers(tripId, guardianId);
    }

    @Post('release-requests')
    @ApiOperation({ summary: '미성년자 가디언 해제 요청 생성 (§10.2)' })
    @HttpCode(HttpStatus.CREATED)
    async createReleaseRequest(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
        @Body('link_id') linkId: string,
    ) {
        return this.guardiansService.createReleaseRequest(tripId, linkId, userId);
    }

    @Post()
    @ApiOperation({ summary: '가디언 추가 (초대)' })
    @HttpCode(HttpStatus.CREATED)
    async addGuardian(
        @Param('tripId') tripId: string,
        @CurrentUser() memberId: string,
        @Body('guardian_phone') guardianPhone: string,
    ) {
        return this.guardiansService.createLink(tripId, memberId, guardianPhone);
    }

    // ── Parameterized routes ──

    @Patch('release-requests/:requestId')
    @ApiOperation({ summary: '미성년자 가디언 해제 요청 승인/거절 (캡틴 전용, §10.2)' })
    async respondToReleaseRequest(
        @Param('tripId') tripId: string,
        @Param('requestId') requestId: string,
        @CurrentUser() captainId: string,
        @Body('action') action: 'approved' | 'rejected',
    ) {
        return this.guardiansService.respondToReleaseRequest(requestId, captainId, action);
    }

    @Patch(':linkId/respond')
    @ApiOperation({ summary: '가디언 연결 수락/거절' })
    async respondToGuardianLink(
        @Param('tripId') tripId: string,
        @Param('linkId') linkId: string,
        @CurrentUser() guardianId: string,
        @Body('action') action: 'accepted' | 'rejected',
    ) {
        return this.guardiansService.respondToLink(tripId, linkId, guardianId, action);
    }

    @Delete(':linkId')
    @ApiOperation({ summary: '가디언 연결 취소/끊기' })
    async deleteGuardianLink(
        @Param('tripId') tripId: string,
        @Param('linkId') linkId: string,
        @CurrentUser() userId: string,
    ) {
        await this.guardiansService.deleteLink(tripId, linkId, userId);
        return null;
    }

    @Post(':linkId/location-request')
    @ApiOperation({ summary: '긴급 위치 요청 (시간당 3회 제한)' })
    requestLocation(
        @CurrentUser() userId: string,
        @Param('linkId') linkId: string,
        @Param('tripId') tripId: string,
        @Body() body: { memberId: string },
    ) {
        return this.guardiansService.requestLocation(linkId, tripId, userId, body.memberId);
    }

    @Patch('location-request/:requestId')
    @ApiOperation({ summary: '위치 요청 응답' })
    respondToRequest(
        @Param('requestId') requestId: string,
        @Body() body: { status: 'approved' | 'denied' },
    ) {
        return this.guardiansService.respondToLocationRequest(requestId, body.status);
    }

    @Get(':linkId/snapshots')
    @ApiOperation({ summary: '30분 스냅샷 목록' })
    getSnapshots(@Param('linkId') linkId: string) {
        return this.guardiansService.getSnapshots(linkId);
    }

    @Get(':linkId/schedule-summary')
    @ApiOperation({ summary: '가디언 일정 요약 조회 (유료 가디언 전용, §9.3)' })
    async getScheduleSummary(
        @Param('tripId') tripId: string,
        @Param('linkId') linkId: string,
        @CurrentUser() guardianId: string,
    ) {
        return this.guardiansService.getScheduleSummary(tripId, linkId, guardianId);
    }
}
