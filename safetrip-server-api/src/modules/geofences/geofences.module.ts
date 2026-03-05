import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GeofencesController } from './geofences.controller';
import { GeofencesService } from './geofences.service';
import { Geofence, GeofenceEvent, GeofencePenalty } from '../../entities/geofence.entity';

@Module({
    imports: [TypeOrmModule.forFeature([Geofence, GeofenceEvent, GeofencePenalty])],
    controllers: [GeofencesController],
    providers: [GeofencesService],
    exports: [GeofencesService],
})
export class GeofencesModule { }
