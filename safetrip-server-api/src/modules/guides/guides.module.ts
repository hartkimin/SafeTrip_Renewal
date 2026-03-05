import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuidesController } from './guides.controller';
import { GuidesService } from './guides.service';
import { Country } from '../../entities/country.entity';
// import { MofaRisk } from '../../entities/mofa-risk.entity';

@Module({
    imports: [TypeOrmModule.forFeature([Country])],
    controllers: [GuidesController],
    providers: [GuidesService],
    exports: [GuidesService],
})
export class GuidesModule { }
