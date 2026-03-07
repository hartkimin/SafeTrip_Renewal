import {
    Controller,
    Get,
    Post,
    Param,
    Body,
    Query,
    BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiParam, ApiQuery } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ScheduleTemplateService } from './schedule-template.service';

@ApiTags('Schedule Templates')
@ApiBearerAuth('firebase-auth')
@Controller()
export class ScheduleTemplateController {
    constructor(
        private readonly templateService: ScheduleTemplateService,
    ) {}

    @Get('schedule-templates')
    @ApiOperation({ summary: '일정 템플릿 목록 조회' })
    @ApiQuery({ name: 'category', required: false, description: 'Filter by category (e.g. japan_tokyo)' })
    async getTemplates(@Query('category') category?: string) {
        const templates = await this.templateService.getTemplates(category);
        return { success: true, data: { templates, total: templates.length } };
    }

    @Post('trips/:tripId/schedules/from-template')
    @ApiOperation({ summary: '템플릿에서 일정 생성' })
    @ApiParam({ name: 'tripId', type: 'string' })
    async applyTemplate(
        @Param('tripId') tripId: string,
        @CurrentUser() userId: string,
        @Body() body: { templateId: string; startDate: string },
    ) {
        if (!body.templateId) {
            throw new BadRequestException('templateId is required');
        }
        if (!body.startDate) {
            throw new BadRequestException('startDate is required');
        }

        const schedules = await this.templateService.applyTemplate(
            tripId,
            body.templateId,
            body.startDate,
            userId,
        );
        return {
            success: true,
            data: { schedules, total: schedules.length },
            message: 'Template applied successfully',
        };
    }
}
