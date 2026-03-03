import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { CountriesService } from './countries.service';

@ApiTags('Countries')
@Controller('countries')
export class CountriesController {
    constructor(private readonly countriesService: CountriesService) { }

    @Get()
    @ApiOperation({ summary: '활성 국가 목록 조회' })
    async findAll() {
        const countries = await this.countriesService.findAll();
        // Return mapped to match spec if needed, but TypeORM columns matching camelCase 
        // can be mapped to snake_case. Let's map it manually.

        return {
            success: true,
            data: countries.map(c => ({
                country_code: c.countryCode,
                country_name_ko: c.countryNameKo,
                country_name_en: c.countryNameEn,
                country_name_local: c.countryNameLocal,
                flag_emoji: c.flagEmoji,
                iso_alpha2: c.isoAlpha2,
            }))
        };
    }
}
