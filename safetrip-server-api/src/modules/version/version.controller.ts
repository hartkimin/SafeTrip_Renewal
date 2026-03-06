import { Controller, Get, Query } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { ApiTags, ApiOperation, ApiQuery } from '@nestjs/swagger';
import { VersionService } from './version.service';

@ApiTags('Version')
@Controller('version')
export class VersionController {
    constructor(private readonly versionService: VersionService) {}

    @Public()
    @Get('check')
    @ApiOperation({ summary: '앱 버전 확인 — 최소/권장 버전 비교' })
    @ApiQuery({ name: 'platform', required: true, enum: ['android', 'ios'] })
    @ApiQuery({ name: 'version', required: true, example: '1.1.0' })
    check(@Query('platform') platform: string, @Query('version') version: string) {
        return this.versionService.check(platform || 'android', version || '0.0.0');
    }
}
