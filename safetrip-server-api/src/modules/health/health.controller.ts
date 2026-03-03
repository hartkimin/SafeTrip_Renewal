import { Controller, Get } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { ApiTags, ApiOperation } from '@nestjs/swagger';

@ApiTags('Health')
@Controller('health')
export class HealthController {
    @Public()
    @Get()
    @ApiOperation({ summary: '서버 상태 확인' })
    check() {
        return { status: 'ok', timestamp: new Date().toISOString() };
    }
}
