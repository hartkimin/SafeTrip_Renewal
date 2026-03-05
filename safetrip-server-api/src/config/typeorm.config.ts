import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import { User, ParentalConsent } from '../entities/user.entity';
import { Trip } from '../entities/trip.entity';
import { TravelSchedule } from '../entities/travel-schedule.entity';
import { Schedule } from '../entities/schedule.entity';
import { RouteDeviation } from '../entities/route-deviation.entity';
import { PlannedRoute } from '../entities/planned-route.entity';
import { Payment, Subscription, RedeemCode } from '../entities/payment.entity';
import { Notification, FcmToken, NotificationPreference } from '../entities/notification.entity';
import { Location, LocationSharing, LocationSchedule, StayPoint, MovementSession, SessionMapImage } from '../entities/location.entity';
import { InviteCode } from '../entities/invite-code.entity';
import { Guardian, GuardianLink, GuardianPause, GuardianLocationRequest, GuardianSnapshot } from '../entities/guardian.entity';
import { Group } from '../entities/group.entity';
import { GroupMember } from '../entities/group-member.entity';
import { Geofence, GeofenceEvent, GeofencePenalty } from '../entities/geofence.entity';
import { EventLog } from '../entities/event-log.entity';
import { Emergency, EmergencyContact, EmergencyRecipient, SosEvent, NoResponseEvent, SafetyCheckin } from '../entities/emergency.entity';
import { Country } from '../entities/country.entity';
import { CountrySafety } from '../entities/country-safety.entity';
import { ChatRoom, ChatMessage, ChatReadStatus } from '../entities/chat.entity';
import { B2bOrganization, B2bContract, B2bAdmin, B2bDashboardConfig } from '../entities/b2b.entity';
import { AiUsage } from '../entities/ai.entity';
import { TripSettings } from '../entities/trip-settings.entity';
import { AttendanceCheck, AttendanceResponse } from '../entities/attendance.entity';

dotenv.config();

export default new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    username: process.env.DB_USER || 'safetrip',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'safetrip_local',
    entities: [
        User, ParentalConsent, Trip, TravelSchedule, Schedule, RouteDeviation, PlannedRoute,
        Payment, Subscription, RedeemCode, Notification, FcmToken, NotificationPreference,
        Location, LocationSharing, LocationSchedule, StayPoint, MovementSession, SessionMapImage,
        InviteCode, Guardian, GuardianLink, GuardianPause, GuardianLocationRequest, GuardianSnapshot,
        Group, GroupMember, Geofence, GeofenceEvent, GeofencePenalty, EventLog,
        Emergency, EmergencyContact, EmergencyRecipient, SosEvent, NoResponseEvent, SafetyCheckin,
        Country, CountrySafety, ChatRoom, ChatMessage, ChatReadStatus,
        B2bOrganization, B2bContract, B2bAdmin, B2bDashboardConfig, AiUsage,
        TripSettings, AttendanceCheck, AttendanceResponse
    ],
    synchronize: false,
    logging: true,
});
