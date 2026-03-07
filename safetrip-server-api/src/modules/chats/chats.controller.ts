import { Controller, Get, Post, Patch, Delete, Param, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ChatsService } from './chats.service';
import { PollService } from './poll.service';

@ApiTags('Chats')
@ApiBearerAuth('firebase-auth')
@Controller('chats')
export class ChatsController {
    constructor(
        private readonly chatsService: ChatsService,
        private readonly pollService: PollService,
    ) { }

    @Get('trip/:tripId/rooms')
    @ApiOperation({ summary: '채팅방 목록 조회' })
    getRooms(@Param('tripId') tripId: string) {
        return this.chatsService.getRooms(tripId);
    }

    @Get('rooms/:roomId/messages/search')
    @ApiOperation({ summary: '메시지 검색 (P3)' })
    searchMessages(
        @Param('roomId') roomId: string,
        @Query('q') query: string,
        @Query('cursor') cursor?: string,
        @Query('limit') limit?: number,
    ) {
        return this.chatsService.searchMessages(roomId, query, cursor, limit);
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

    // ------------------------------------------------------------------
    // Media Gallery (Phase 3)
    // ------------------------------------------------------------------

    @Get('rooms/:roomId/media')
    @ApiOperation({ summary: '미디어 모아보기 (P3)' })
    getMedia(
        @Param('roomId') roomId: string,
        @Query('cursor') cursor?: string,
        @Query('limit') limit?: number,
    ) {
        return this.chatsService.getMedia(roomId, cursor, limit);
    }

    // ------------------------------------------------------------------
    // Reactions (Phase 3)
    // ------------------------------------------------------------------

    @Post('messages/:messageId/reactions')
    @ApiOperation({ summary: '리액션 추가' })
    addReaction(
        @CurrentUser() userId: string,
        @Param('messageId') messageId: string,
        @Body() body: { emoji: string },
    ) {
        return this.chatsService.addReaction(messageId, userId, body.emoji);
    }

    @Delete('messages/:messageId/reactions/:emoji')
    @ApiOperation({ summary: '리액션 제거' })
    removeReaction(
        @CurrentUser() userId: string,
        @Param('messageId') messageId: string,
        @Param('emoji') emoji: string,
    ) {
        return this.chatsService.removeReaction(messageId, userId, emoji);
    }

    @Get('messages/:messageId/reactions')
    @ApiOperation({ summary: '리액션 목록' })
    getReactions(@Param('messageId') messageId: string) {
        return this.chatsService.getReactions(messageId);
    }

    // ------------------------------------------------------------------
    // Poll CRUD (DOC-T3-CHT-020 §8)
    // ------------------------------------------------------------------

    @Post('rooms/:roomId/polls')
    @ApiOperation({ summary: '투표 생성 (captain/crew_chief 전용)' })
    createPoll(
        @CurrentUser() userId: string,
        @Param('roomId') roomId: string,
        @Body() body: { title: string; options: string[]; closesAt?: string },
    ) {
        return this.pollService.createPoll(roomId, userId, body);
    }

    @Get('polls/:pollId')
    @ApiOperation({ summary: '투표 조회 + 결과 집계' })
    getPoll(@Param('pollId') pollId: string) {
        return this.pollService.getPoll(pollId);
    }

    @Post('polls/:pollId/vote')
    @ApiOperation({ summary: '투표 참여 (단일 선택, 마감 전 변경 가능)' })
    castVote(
        @CurrentUser() userId: string,
        @Param('pollId') pollId: string,
        @Body() body: { optionId: number },
    ) {
        return this.pollService.castVote(pollId, userId, body.optionId);
    }

    @Post('polls/:pollId/close')
    @ApiOperation({ summary: '투표 수동 마감 (captain/crew_chief 전용)' })
    closePoll(
        @CurrentUser() userId: string,
        @Param('pollId') pollId: string,
    ) {
        return this.pollService.closePoll(pollId, userId);
    }
}
