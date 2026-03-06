import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Country } from '../../entities/country.entity';

@Injectable()
export class GuidesService {
    constructor(
        @InjectRepository(Country)
        private countryRepository: Repository<Country>,
    ) { }

    async findByCountryCode(countryCode: string) {
        const country = await this.countryRepository.findOne({
            where: { countryCode }
        });

        if (!country) return null;

        return {
            country_code: country.countryCode,
            country_name_ko: country.countryNameKo,
            country_name_en: country.countryNameEn,
            flag_emoji: country.countryFlagEmoji,
            last_updated: country.updatedAt
        };
    }

    async getEmergencyContacts(countryCode: string) {
        const country = await this.countryRepository.findOne({
            where: { countryCode }
        });

        if (!country) return null;

        return {
            country_code: country.countryCode,
            country_name_ko: country.countryNameKo,
        };
    }

    async search(query: string, countryCode?: string) {
        const where: any = {};

        if (countryCode) {
            where.countryCode = countryCode;
        }

        const countries = await this.countryRepository.find({
            where: [
                { ...where, countryNameKo: ILike(`%${query}%`) },
                { ...where, countryNameEn: ILike(`%${query}%`) },
            ],
            take: 20,
        });

        return countries.map(c => ({
            country_code: c.countryCode,
            country_name_ko: c.countryNameKo,
            country_name_en: c.countryNameEn,
            flag_emoji: c.countryFlagEmoji,
        }));
    }
}
