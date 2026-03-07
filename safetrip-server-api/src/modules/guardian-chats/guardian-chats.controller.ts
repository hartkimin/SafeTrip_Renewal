import { Controller, Get, Post, Param, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { GuardianChatsService } from './guardian-chats.service';

@ApiTags('Guardian Chats')
@ApiBearerAuth('firebase-auth')
@Controller('guardian-chats')
export class GuardianChatsController {
    constructor(private readonly guardianChatsService: GuardianChatsService) {}

    @Get('trip/:tripId/channels')
    @ApiOperation({ summary: '가디언 채널 목록 조회' })
    getChannels(
        @CurrentUser() userId: string,
        @Param('tripId') tripId: string,
    ) {
        return this.guardianChatsService.getChannels(tripId, userId);
    }

    @Get('channels/:linkId/messages')
    @ApiOperation({ summary: '가디언 채널 메시지 조회 (커서 기반)' })
    getMessages(
        @CurrentUser() userId: string,
        @Param('linkId') linkId: string,
        @Query('cursor') cursor?: string,
        @Query('limit') limit?: number,
    ) {
        return this.guardianChatsService.getMessages(linkId, userId, cursor, limit);
    }

    @Post('channels/:linkId/messages')
    @ApiOperation({ summary: '가디언 채널 메시지 전송' })
    sendMessage(
        @CurrentUser() userId: string,
        @Param('linkId') linkId: string,
        @Body() body: { content?: string; messageType?: string; cardData?: any },
    ) {
        return this.guardianChatsService.sendMessage(linkId, userId, body);
    }

    @Post('channels/:linkId/read')
    @ApiOperation({ summary: '가디언 채널 읽음 처리' })
    markRead(
        @CurrentUser() userId: string,
        @Param('linkId') linkId: string,
    ) {
        return this.guardianChatsService.markRead(linkId, userId);
    }
}
