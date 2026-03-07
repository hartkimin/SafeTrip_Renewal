// Central entity barrel file -- re-exports all entities.
// User Domain (A)
export { User, ParentalConsent } from './user.entity';

// Group & Trip Domain (B)
export { Group } from './group.entity';
export { GroupMember } from './group-member.entity';
export { Trip } from './trip.entity';
export { TripSettings } from './trip-settings.entity';
export { InviteCode } from './invite-code.entity';
export { AttendanceCheck, AttendanceResponse } from './attendance.entity';

// Country Domain (B)
export { Country } from './country.entity';

// Guardian Domain (C)
export {
    Guardian,
    GuardianLink,
    GuardianPause,
    GuardianLocationRequest,
    GuardianSnapshot,
    GuardianReleaseRequest,
} from './guardian.entity';

// Schedule & Geofence Domain (D)
export { Schedule } from './schedule.entity';
export { TravelSchedule } from './travel-schedule.entity';
export { ScheduleHistory } from './schedule-history.entity';
export { ScheduleComment } from './schedule-comment.entity';
export { ScheduleReaction } from './schedule-reaction.entity';
export { ScheduleVote } from './schedule-vote.entity';
export { ScheduleVoteOption } from './schedule-vote-option.entity';
export { ScheduleVoteResponse } from './schedule-vote-response.entity';
export { ScheduleTemplate } from './schedule-template.entity';
export { Geofence, GeofenceEvent, GeofencePenalty } from './geofence.entity';

// Location Domain (E)
export {
    Location,
    LocationSharing,
    LocationSchedule,
    StayPoint,
    SessionMapImage,
    MovementSession,
} from './location.entity';

export { PlannedRoute } from './planned-route.entity';
export { RouteDeviation } from './route-deviation.entity';

// Safety & SOS Domain (F)
export {
    Emergency,
    EmergencyContact,
    EmergencyRecipient,
    SafetyCheckin,
    SosEvent,
    NoResponseEvent,
    Heartbeat,
    PowerEvent,
    SosRescueLog,
    SosCancelLog,
} from './emergency.entity';

// Chat Domain (G)
export {
    ChatRoom,
    ChatMessage,
    ChatReadStatus,
    ChatPoll,
    ChatPollVote,
} from './chat.entity';

// Notification Domain (H)
export {
    Notification,
    FcmToken,
    NotificationPreference,
    NotificationSetting,
    EventNotificationConfig,
} from './notification.entity';

// Legal & Privacy Domain (I)
export {
    UserConsent,
    MinorConsent,
    LocationAccessLog,
    LocationSharingPauseLog,
    DataDeletionLog,
    DataProvisionLog,
} from './legal.entity';

// Payment Domain (K)
export {
    Payment,
    Subscription,
    RedeemCode,
    BillingItem,
    RefundLog,
} from './payment.entity';

// B2B Domain (L)
export {
    B2bOrganization,
    B2bContract,
    B2bAdmin,
    B2bDashboardConfig,
    B2bSchool,
    B2bInviteBatch,
    B2bMemberLog,
} from './b2b.entity';

// Ops & Log Domain (J)
export {
    EventLog,
    LeaderTransferLog,
    EmergencyNumber,
} from './event-log.entity';

// AI Domain (O)
export { AiUsage, AiUsageLog, AiSubscription } from './ai.entity';
