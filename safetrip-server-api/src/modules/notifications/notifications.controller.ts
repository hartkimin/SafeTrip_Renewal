import { Controller, Post, Get, Delete, Body, Param, Query } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiQuery } from '@nestjs/swagger';
import { NotificationsService } from './notifications.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';

@ApiTags('Notifications')
@ApiBearerAuth('firebase-auth')
@Controller('fcm') // Endpoint defined as /api/v1/fcm in API docs
export class NotificationsController {
    constructor(private readonly notificationsService: NotificationsService) { }

    @Post('token')
    @ApiOperation({ summary: 'FCM 기기 토큰 등록' })
    registerToken(
        @CurrentUser() userId: string,
        @Body() body: { token: string; deviceId?: string }
    ) {
        return this.notificationsService.registerToken(userId, body.token, body.deviceId);
    }

    @Delete('token')
    @ApiOperation({ summary: 'FCM 기기 토큰 삭제 (로그아웃 등)' })
    invalidateToken(
        @CurrentUser() userId: string,
        @Body() body: { token: string }
    ) {
        return this.notificationsService.invalidateToken(userId, body.token);
    }

    @Public()
    @Post('send')
    @ApiOperation({ summary: '단일 기기 푸시 발송 (테스트)' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                target_token: { type: 'string' },
                title: { type: 'string' },
                body: { type: 'string' },
                data: { type: 'object' },
            },
            required: ['target_token', 'title', 'body']
        }
    })
    sendPush(
        @Body() body: { target_token: string; title: string; body: string; data?: any }
    ) {
        return this.notificationsService.sendPush(body);
    }

    @Public()
    @Post('send-multicast')
    @ApiOperation({ summary: '다중 기기 푸시 발송 (테스트)' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                target_tokens: { type: 'array', items: { type: 'string' } },
                title: { type: 'string' },
                body: { type: 'string' },
                data: { type: 'object' },
            },
            required: ['target_tokens', 'title', 'body']
        }
    })
    sendMulticastPush(
        @Body() body: { target_tokens: string[]; title: string; body: string; data?: any }
    ) {
        return this.notificationsService.sendMulticastPush(body);
    }

    @Get('history')
    @ApiOperation({ summary: '내 알림 이력 조회' })
    @ApiQuery({ name: 'page', required: false })
    @ApiQuery({ name: 'limit', required: false })
    getNotificationHistory(
        @CurrentUser() userId: string,
        @Query('page') page: string = '1',
        @Query('limit') limit: string = '20'
    ) {
        return this.notificationsService.getNotificationHistory(userId, parseInt(page, 10), parseInt(limit, 10));
    }

    @Get('history/unread-count')
    @ApiOperation({ summary: '안 읽은 알림 개수 조회' })
    getUnreadCount(@CurrentUser() userId: string) {
        return this.notificationsService.getUnreadCount(userId);
    }

    @Post('history/:notificationId/read')
    @ApiOperation({ summary: '알림 읽음 처리' })
    markAsRead(
        @CurrentUser() userId: string,
        @Param('notificationId') notificationId: string
    ) {
        return this.notificationsService.markAsRead(userId, notificationId);
    }

    // ── §12.4 특정 여행자에게 FCM 푸시 발송 ──
    @Public()
    @Post('travelers/:travelerId/notify')
    @ApiOperation({ summary: '특정 여행자에게 FCM 푸시 발송' })
    notifyTraveler(
        @Param('travelerId') travelerId: string,
        @Body() body: { title: string; body: string; data?: any },
    ) {
        return this.notificationsService.notifyTraveler(travelerId, body);
    }
}
