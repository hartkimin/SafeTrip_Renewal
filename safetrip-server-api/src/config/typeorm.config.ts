import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import { User } from '../entities/user.entity';
import { Group } from '../entities/group.entity';
import { Trip } from '../entities/trip.entity';
import { GroupMember } from '../entities/group-member.entity';
import { InviteCode } from '../entities/invite-code.entity';
import { Location, LocationSharing, LocationSchedule, StayPoint, PlannedRoute, RouteDeviation, MovementSession } from '../entities/location.entity';
import { Guardian, GuardianLink, GuardianPause, GuardianLocationRequest, GuardianSnapshot } from '../entities/guardian.entity';
import { ChatRoom, ChatMessage, ChatPoll, ChatPollVote, ChatReadStatus } from '../entities/chat.entity';
import { FcmToken, Notification, NotificationSetting, EventNotificationConfig } from '../entities/notification.entity';
import { Heartbeat, SosEvent, PowerEvent, SosRescueLog, SosCancelLog } from '../entities/emergency.entity';
import { UserConsent, MinorConsent, LocationAccessLog, LocationSharingPauseLog, DataDeletionLog, DataProvisionLog } from '../entities/legal-privacy.entity';
import { EventLog, LeaderTransferLog, EmergencyNumber } from '../entities/event-log.entity';
import { Payment, Subscription, BillingItem, RefundLog } from '../entities/payment.entity';
import { B2bContract, B2bSchool, B2bInviteBatch, B2bMemberLog } from '../entities/b2b.entity';
import { Country } from '../entities/country.entity';

dotenv.config();

export default new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    username: process.env.DB_USER || 'safetrip',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'safetrip_local',
    entities: [
        User, Group, Trip, GroupMember, InviteCode,
        Location, LocationSharing, LocationSchedule, StayPoint, PlannedRoute, RouteDeviation, MovementSession,
        Guardian, GuardianLink, GuardianPause, GuardianLocationRequest, GuardianSnapshot,
        ChatRoom, ChatMessage, ChatPoll, ChatPollVote, ChatReadStatus,
        FcmToken, Notification, NotificationSetting, EventNotificationConfig,
        Heartbeat, SosEvent, PowerEvent, SosRescueLog, SosCancelLog,
        UserConsent, MinorConsent, LocationAccessLog, LocationSharingPauseLog, DataDeletionLog, DataProvisionLog,
        EventLog, LeaderTransferLog, EmergencyNumber,
        Payment, Subscription, BillingItem, RefundLog,
        B2bContract, B2bSchool, B2bInviteBatch, B2bMemberLog,
        Country
    ],
    synchronize: false,
    logging: true,
});
