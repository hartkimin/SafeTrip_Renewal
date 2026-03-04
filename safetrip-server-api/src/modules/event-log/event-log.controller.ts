import { Controller, Post, Get, Body, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { EventLogService } from './event-log.service';

@ApiTags('Event Log')
@Controller('events')
export class EventLogController {
    constructor(private readonly eventLogService: EventLogService) { }

    @Public()
    @Post()
    @ApiOperation({ summary: '이벤트 로그 기록' })
    async create(@Body() body: any) {
        const data = await this.eventLogService.create(body);
        return data;
    }

    @Public()
    @Get()
    @ApiOperation({ summary: '이벤트 로그 조회' })
    async find(@Query() query: any) {
        const data = await this.eventLogService.find(query);
        return { success: true, data };
    }
}
