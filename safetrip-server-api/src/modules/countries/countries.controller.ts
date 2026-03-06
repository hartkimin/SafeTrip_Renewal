import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { CountriesService } from './countries.service';

@ApiTags('Countries')
@Controller('countries')
export class CountriesController {
    constructor(private readonly countriesService: CountriesService) { }

    @Public()
    @Get()
    @ApiOperation({ summary: '활성 국가 목록 조회' })
    async findAll() {
        const countries = await this.countriesService.findAll();
        return countries.map(c => ({
            country_code: c.countryCode,
            country_name_ko: c.countryNameKo,
            country_name_en: c.countryNameEn,
            flag_emoji: c.countryFlagEmoji,
            phone_code: c.phoneCode,
            region: c.region,
            mofa_travel_alert: c.mofaTravelAlert,
            mofa_alert_updated_at: c.mofaAlertUpdatedAt,
            is_popular: c.isPopular,
            sort_order: c.sortOrder,
            updated_at: c.updatedAt,
        }));
    }
}
