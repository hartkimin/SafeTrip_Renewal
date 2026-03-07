import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { LocationsController } from './locations.controller';
import { LocationsService } from './locations.service';
import { LocationsGateway } from './locations.gateway';
import {
    Location, LocationSharing, LocationSchedule,
    StayPoint, SessionMapImage, MovementSession
} from '../../entities/location.entity';
import { PlannedRoute } from '../../entities/planned-route.entity';
import { RouteDeviation } from '../../entities/route-deviation.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { MovementHistoryAccessGuard } from './guards/movement-history-access.guard';

@Module({
    imports: [TypeOrmModule.forFeature([
        Location, LocationSharing, LocationSchedule,
        StayPoint, SessionMapImage, PlannedRoute, RouteDeviation, MovementSession,
        GroupMember, GuardianLink,
    ])],
    controllers: [LocationsController],
    providers: [LocationsService, LocationsGateway, MovementHistoryAccessGuard],
    exports: [LocationsService, LocationsGateway],
})
export class LocationsModule { }
