import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { B2bController } from './b2b.controller';
import { B2bService } from './b2b.service';
import { B2bOrganization, B2bContract, B2bAdmin, B2bDashboardConfig } from '../../entities/b2b.entity';

@Module({
    imports: [TypeOrmModule.forFeature([B2bOrganization, B2bContract, B2bAdmin, B2bDashboardConfig])],
    controllers: [B2bController],
    providers: [B2bService],
    exports: [B2bService],
})
export class B2bModule { }
