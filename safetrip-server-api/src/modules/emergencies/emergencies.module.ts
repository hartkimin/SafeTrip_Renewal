import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EmergenciesController } from './emergencies.controller';
import { EmergenciesService } from './emergencies.service';
import { Emergency, EmergencyContact, SosEvent, NoResponseEvent } from '../../entities/emergency.entity';

@Module({
    imports: [TypeOrmModule.forFeature([Emergency, EmergencyContact, SosEvent, NoResponseEvent])],
    controllers: [EmergenciesController],
    providers: [EmergenciesService],
    exports: [EmergenciesService],
})
export class EmergenciesModule { }
