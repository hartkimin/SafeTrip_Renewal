import { Controller, Get, Post, Patch, Delete, Param, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { GroupsService } from './groups.service';

@ApiTags('Groups')
@ApiBearerAuth('firebase-auth')
@Controller('groups')
export class GroupsController {
    constructor(private readonly groupsService: GroupsService) { }

    @Post()
    @ApiOperation({ summary: '그룹 생성' })
    create(@CurrentUser() userId: string, @Body() body: { groupName: string; groupType?: string }) {
        return this.groupsService.create(userId, body.groupName, body.groupType);
    }

    @Get(':groupId')
    @ApiOperation({ summary: '그룹 상세 조회' })
    findOne(@Param('groupId') groupId: string) {
        return this.groupsService.findById(groupId);
    }

    @Get(':groupId/my-permission')
    @ApiOperation({ summary: '내 권한 조회' })
    findMyPermission(
        @Param('groupId') groupId: string,
        @CurrentUser() userId: string,
        @Query('user_id') queryUserId?: string,
    ) {
        return this.groupsService.findMyPermission(groupId, userId || queryUserId || '');
    }

    @Get('users/:userId/recent-groups')
    @ApiOperation({ summary: '최근 그룹 조회' })
    findRecentGroup(@Param('userId') userId: string) {
        return this.groupsService.findRecentGroup(userId);
    }

    @Get(':tripId/members')
    @ApiOperation({ summary: '그룹 멤버 목록 조회 (tripId 기준)' })
    getMembers(@Param('tripId') tripId: string) {
        return this.groupsService.getMembers(tripId);
    }

    @Post(':groupId/members')
    @ApiOperation({ summary: '그룹 멤버 추가' })
    addMember(
        @Param('groupId') groupId: string,
        @Body() body: { tripId: string; userId: string; role?: string },
    ) {
        return this.groupsService.addMember(groupId, body.tripId, body.userId, body.role);
    }

    @Patch(':tripId/members/:userId/role')
    @ApiOperation({ summary: '멤버 역할 변경' })
    updateRole(
        @CurrentUser() currentUserId: string,
        @Param('tripId') tripId: string,
        @Param('userId') userId: string,
        @Body() body: { role: string },
    ) {
        return this.groupsService.updateMemberRole(tripId, userId, body.role, currentUserId);
    }

    @Delete(':tripId/members/:userId')
    @ApiOperation({ summary: '멤버 제거' })
    removeMember(
        @CurrentUser() currentUserId: string,
        @Param('tripId') tripId: string,
        @Param('userId') userId: string,
    ) {
        return this.groupsService.removeMember(tripId, userId, currentUserId);
    }

    // ── 초대 코드 (Role-based Invite Codes) ──
    @Get('preview-by-code/:code')
    @ApiOperation({ summary: '초대 코드 미리보기' })
    previewByCode(@Param('code') code: string) {
        return this.groupsService.previewByCode(code);
    }

    @Post('join-by-code/:code')
    @ApiOperation({ summary: '신규 가입용 초대 코드로 가입' })
    joinByCode(
        @Param('code') code: string,
        @CurrentUser() userId: string,
    ) {
        return this.groupsService.joinByCode(code, userId);
    }

    // legacy
    @Post('join/:invite_code')
    @ApiOperation({ summary: '레거시 초대 코드로 가입' })
    joinLegacy(
        @Param('invite_code') inviteCode: string,
        @CurrentUser() userId: string,
    ) {
        return this.groupsService.joinLegacy(inviteCode, userId);
    }

    @Post(':groupId/invite-codes')
    @ApiOperation({ summary: '역할별 초대코드 생성' })
    createInviteCode(
        @Param('groupId') groupId: string,
        @CurrentUser() userId: string,
        @Body() body: { target_role: string; max_uses?: number; expires_in_days?: number },
    ) {
        return this.groupsService.createInviteCode(groupId, userId, body);
    }

    @Get(':groupId/invite-codes')
    @ApiOperation({ summary: '그룹 내 초대코드 목록 조회' })
    getInviteCodes(
        @Param('groupId') groupId: string,
        @CurrentUser() userId: string,
    ) {
        return this.groupsService.getInviteCodes(groupId, userId);
    }

    @Delete(':groupId/invite-codes/:codeId')
    @ApiOperation({ summary: '초대코드 비활성화' })
    deactivateInviteCode(
        @Param('groupId') groupId: string,
        @Param('codeId') codeId: string,
        @CurrentUser() userId: string,
    ) {
        return this.groupsService.deactivateInviteCode(groupId, codeId, userId);
    }

    // ── 리더십 양도 (Leadership Transfer) ──
    @Post(':groupId/transfer-leadership')
    @ApiOperation({ summary: '리더십 양도' })
    async transferLeadership(
        @Param('groupId') groupId: string,
        @CurrentUser() currentUser: string,
        @Body() body: { user_id?: string; to_user_id: string }
    ) {
        // Fallback to body.user_id if CurrentUser is not provided
        const fromUserId = currentUser || body.user_id;
        return this.groupsService.transferLeadership(groupId, fromUserId || '', body.to_user_id);
    }

    @Get(':groupId/transfer-history')
    @ApiOperation({ summary: '리더 양도 이력 조회' })
    async getTransferHistory(
        @Param('groupId') groupId: string,
        @CurrentUser() currentUser: string,
        @Query('user_id') queryUserId?: string
    ) {
        const userId = currentUser || queryUserId;
        return this.groupsService.getTransferHistory(groupId, userId || '');
    }
}
