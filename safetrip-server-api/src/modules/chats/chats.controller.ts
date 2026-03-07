import { Controller, Get, Post, Patch, Delete, Param, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ChatsService } from './chats.service';

@ApiTags('Chats')
@ApiBearerAuth('firebase-auth')
@Controller('chats')
export class ChatsController {
    constructor(private readonly chatsService: ChatsService) { }

    @Get('trip/:tripId/rooms')
    @ApiOperation({ summary: '채팅방 목록 조회' })
    getRooms(@Param('tripId') tripId: string) {
        return this.chatsService.getRooms(tripId);
    }

    @Get('rooms/:roomId/messages')
    @ApiOperation({ summary: '채팅 메시지 조회 (커서 기반)' })
    getMessages(
        @Param('roomId') roomId: string,
        @Query('cursor') cursor?: string,
        @Query('limit') limit?: number,
    ) {
        return this.chatsService.getMessages(roomId, cursor, limit);
    }

    @Post('rooms/:roomId/messages')
    @ApiOperation({ summary: '채팅 메시지 전송' })
    sendMessage(
        @CurrentUser() userId: string,
        @Param('roomId') roomId: string,
        @Body() body: any,
    ) {
        return this.chatsService.sendMessage(roomId, userId, body);
    }

    @Post('rooms/:roomId/read')
    @ApiOperation({ summary: '읽음 상태 갱신' })
    markRead(
        @CurrentUser() userId: string,
        @Param('roomId') roomId: string,
        @Body() body: { lastReadMessageId: string },
    ) {
        return this.chatsService.markRead(roomId, userId, body.lastReadMessageId);
    }

    // ------------------------------------------------------------------
    // Pin / Unpin / Pinned List / Delete
    // ------------------------------------------------------------------

    @Patch('messages/:messageId/pin')
    @ApiOperation({ summary: '메시지 공지 고정 (captain/crew_chief, 최대 3개)' })
    pinMessage(
        @CurrentUser() userId: string,
        @Param('messageId') messageId: string,
    ) {
        return this.chatsService.pinMessage(messageId, userId);
    }

    @Delete('messages/:messageId/pin')
    @ApiOperation({ summary: '공지 해제 (captain/crew_chief)' })
    unpinMessage(
        @CurrentUser() userId: string,
        @Param('messageId') messageId: string,
    ) {
        return this.chatsService.unpinMessage(messageId, userId);
    }

    @Get('rooms/:roomId/pinned')
    @ApiOperation({ summary: '고정된 메시지 목록 조회 (최대 3개)' })
    getPinnedMessages(@Param('roomId') roomId: string) {
        return this.chatsService.getPinnedMessages(roomId);
    }

    @Delete('messages/:messageId')
    @ApiOperation({ summary: '메시지 소프트 삭제' })
    deleteMessage(
        @CurrentUser() userId: string,
        @Param('messageId') messageId: string,
    ) {
        return this.chatsService.deleteMessage(messageId, userId);
    }
}
