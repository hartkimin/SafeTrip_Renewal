import { Controller, Get, Post, Param, Body, Query } from '@nestjs/common';
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
}
