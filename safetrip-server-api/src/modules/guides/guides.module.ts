import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuidesController } from './guides.controller';
import { GuidesService } from './guides.service';
import { Country } from '../../entities/country.entity';
import { SafetyGuideCache } from '../../entities/safety-guide-cache.entity';
import { CountryEmergencyContact } from '../../entities/country-emergency-contact.entity';
import { MofaModule } from '../mofa/mofa.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([Country, SafetyGuideCache, CountryEmergencyContact]),
        MofaModule,
    ],
    controllers: [GuidesController],
    providers: [GuidesService],
    exports: [GuidesService],
})
export class GuidesModule { }
