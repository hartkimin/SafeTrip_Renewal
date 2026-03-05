# Master_docs 정합성 감사 및 코드 수정 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Align the safetrip-server-api backend code with all Master_docs (01~38) principle documents, fixing entity definitions, SQL schemas, API endpoints, and business logic.

**Architecture:** Read each Master_doc → compare against current code → fix mismatches in entities, SQL, controllers, services, DTOs. DB design doc (07_v3.5) is SSOT for schema. Build-verify after each phase.

**Tech Stack:** NestJS, TypeORM, PostgreSQL, TypeScript

---

## Phase 1: DB Schema & Entity Alignment (Docs 01, 07, 08, 09)

### Task 1: Audit & Fix ENUM Types in SQL Schema

**Files:**
- Modify: `safetrip-server-api/sql/00-extensions-and-types.sql`

**Step 1: Read current ENUM definitions**

Read `sql/00-extensions-and-types.sql` and compare against Doc 07 §1.2 type definitions.

**Step 2: Add/fix ENUM types per doc 07**

Required ENUMs (doc 07 SSOT):
```sql
-- Role & Status
CREATE TYPE member_role_enum AS ENUM ('captain', 'crew_chief', 'crew', 'guardian');
CREATE TYPE trip_status_enum AS ENUM ('planning', 'active', 'completed');
CREATE TYPE privacy_level_enum AS ENUM ('safety_first', 'standard', 'privacy_first');
CREATE TYPE sharing_mode_enum AS ENUM ('forced', 'voluntary');
CREATE TYPE schedule_type_enum AS ENUM ('always', 'time_based', 'schedule_linked');
CREATE TYPE visibility_type_enum AS ENUM ('all', 'admin_only', 'specified');
CREATE TYPE guardian_type_enum AS ENUM ('personal', 'group');
CREATE TYPE guardian_link_status_enum AS ENUM ('pending', 'accepted', 'rejected', 'cancelled');
CREATE TYPE payment_type_enum AS ENUM ('trip_base', 'addon_movement', 'addon_ai_plus', 'addon_ai_pro', 'addon_guardian', 'b2b_contract');
CREATE TYPE notification_type_enum AS ENUM ('sos', 'guardian_alert', 'geofence', 'schedule', 'member_join', 'location_request');
```

**Step 3: Build verify**

Run: `cd safetrip-server-api && npx tsc --noEmit`

---

### Task 2: Audit & Fix User/Auth Domain Entities (Domain A)

**Files:**
- Modify: `safetrip-server-api/src/entities/user.entity.ts`
- Modify: `safetrip-server-api/sql/01-schema-user-group-trip.sql`

**Step 1: Compare TB_USER columns**

Doc 07 requires TB_USER columns:
- `user_id` VARCHAR(128) PK (Firebase UID)
- `phone_number`, `display_name`, `email`, `profile_image_url`
- `date_of_birth`, `location_sharing_mode` (always|in_trip|off)
- `user_status` (active|inactive|banned), `minor_status` (adult|minor_over14|minor_under14|minor_child)
- `guardian_pause_blocked` BOOLEAN, `ai_intelligence_blocked` BOOLEAN
- `deletion_requested_at`, `deleted_at`, `is_active`, `is_onboarding_complete`
- `last_verification_at`, `created_at`, `updated_at`

Read current user.entity.ts and add any missing columns.

**Step 2: Create missing TB_EMERGENCY_CONTACT entity if column mismatches exist**

Doc 07: TB_EMERGENCY_CONTACT has `contact_id` UUID PK, `user_id` FK, `contact_name`, `phone_number`, `relationship`, `sort_order`.

Read current emergency.entity.ts to verify EmergencyContact matches.

**Step 3: Fix SQL schema to match doc 07**

Update `01-schema-user-group-trip.sql` to match all doc 07 TB_USER column definitions.

**Step 4: Build verify**

Run: `cd safetrip-server-api && npx tsc --noEmit`

---

### Task 3: Audit & Fix Group/Trip Domain Entities (Domain B)

**Files:**
- Modify: `safetrip-server-api/src/entities/trip.entity.ts`
- Modify: `safetrip-server-api/src/entities/group-member.entity.ts`
- Modify: `safetrip-server-api/src/entities/invite-code.entity.ts`
- Create: `safetrip-server-api/src/entities/trip-settings.entity.ts`
- Create: `safetrip-server-api/src/entities/attendance.entity.ts`
- Create: `safetrip-server-api/src/entities/country-detail.entity.ts` (if TB_COUNTRY differs)
- Modify: `safetrip-server-api/sql/01-schema-user-group-trip.sql`

**Step 1: Compare TB_TRIP columns**

Doc 07 requires TB_TRIP:
- `trip_id` UUID PK
- `group_id` FK, `trip_name`, `destination`, `destination_city`
- `destination_country_code`, `country_code`, `country_name`
- `trip_type` (group|solo), `start_date`, `end_date`
- `status` (planning|active|completed)
- `privacy_level` (safety_first|standard|privacy_first)
- `sharing_mode` (forced|voluntary), `schedule_type` (always|time_based|schedule_linked)
- `schedule_buffer_minutes` (0/15/30)
- `b2b_contract_id` FK, `has_minor_members` BOOLEAN
- `reactivated_at`, `reactivation_count` (CHECK ≤ 1)
- `created_by` FK, `deleted_at`
- CHECK (end_date - start_date ≤ 15)

Read trip.entity.ts — add missing columns: `schedule_type`, `schedule_buffer_minutes`, `reactivation_count`, `created_by` etc.

**Step 2: Compare TB_GROUP_MEMBER columns**

Doc 07 requires:
- `can_edit_geofence`, `can_view_all_locations`, `can_attendance_check`
- `traveler_user_id` FK (for guardian-type members linking to their traveler)

Read group-member.entity.ts — add missing columns.

**Step 3: Create TB_TRIP_SETTINGS entity**

Doc 07 defines TB_TRIP_SETTINGS:
```
setting_id UUID PK
trip_id UUID UNIQUE FK
captain_receive_guardian_msg BOOLEAN DEFAULT TRUE
guardian_msg_enabled BOOLEAN DEFAULT TRUE
sos_auto_trigger_enabled BOOLEAN DEFAULT TRUE
sos_heartbeat_timeout_min INTEGER DEFAULT 30
attendance_check_enabled BOOLEAN DEFAULT TRUE
geofence_guardian_notify BOOLEAN DEFAULT TRUE
```

Create new entity file.

**Step 4: Create TB_ATTENDANCE_CHECK and TB_ATTENDANCE_RESPONSE entities**

Doc 07 defines:
```
TB_ATTENDANCE_CHECK: check_id, trip_id, group_id, initiated_by, deadline_at, created_at
TB_ATTENDANCE_RESPONSE: response_id, check_id, user_id, response_type (present|absent|unknown), responded_at
  UNIQUE(check_id, user_id)
```

Create new entity file.

**Step 5: Fix TB_COUNTRY entity**

Doc 07 defines TB_COUNTRY with: `country_id` UUID PK, `country_code` UNIQUE, `country_name_ko`, `country_name_en`, `country_flag_emoji`, `phone_code`, `region`, `mofa_travel_alert`, `mofa_alert_updated_at`, `is_popular`, `sort_order`.

Compare with current country.entity.ts. Fix mismatches.

**Step 6: Update SQL schema and entity index**

Update SQL and `src/entities/index.ts` to include new entities.

**Step 7: Build verify**

Run: `cd safetrip-server-api && npx tsc --noEmit`

---

### Task 4: Audit & Fix Guardian Domain Entities (Domain C)

**Files:**
- Modify: `safetrip-server-api/src/entities/guardian.entity.ts`
- Modify: `safetrip-server-api/sql/02-schema-guardian.sql`

**Step 1: Compare TB_GUARDIAN columns**

Doc 07 v3.5 defines TB_GUARDIAN with:
- `guardian_id` UUID PK
- `traveler_user_id` FK, `guardian_user_id` FK, `trip_id` FK
- `guardian_type` (primary|secondary|group)
- `can_view_location`, `can_request_checkin`, `can_receive_sos`
- `invite_status` (pending|accepted|rejected)
- `is_minor_guardian`, `consent_id` FK
- `auto_notify_sos`, `auto_notify_geofence`
- `is_paid`, `paid_at`, `payment_id` FK

Read guardian.entity.ts and fix all mismatches.

**Step 2: Compare TB_GUARDIAN_LINK columns**

Verify: `guardian_type` (personal|group), `can_view_location`, `can_receive_sos`, `can_request_checkin`, `can_send_message` columns exist.

**Step 3: Verify TB_GUARDIAN_PAUSE, TB_GUARDIAN_LOCATION_REQUEST, TB_GUARDIAN_SNAPSHOT**

Read guardian.entity.ts for these sub-entities. Check columns match doc 07 (e.g., `auto_responded`, `auto_response_reason` in location request).

**Step 4: Fix SQL schema and build verify**

---

### Task 5: Audit & Fix Schedule/Geofence Domain (Domain D)

**Files:**
- Modify: `safetrip-server-api/src/entities/schedule.entity.ts`
- Modify: `safetrip-server-api/src/entities/travel-schedule.entity.ts`
- Modify: `safetrip-server-api/src/entities/geofence.entity.ts`
- Modify: `safetrip-server-api/sql/03-schema-schedule-geofence.sql`

**Step 1: Compare TB_SCHEDULE**

Doc 07: `schedule_id`, `trip_id`, `title`, `description`, `start_time`, `end_time`, `location`, `all_day`, `created_by`, timestamps.

Read schedule.entity.ts, fix mismatches.

**Step 2: Compare TB_GEOFENCE**

Doc 07: `geofence_id`, `group_id`, `trip_id`, `name`, `latitude`, `longitude`, `radius_meters`, `geofence_type` (safe|watch|danger), `is_active`, timestamps.

Read geofence.entity.ts, fix mismatches.

**Step 3: Fix SQL and build verify**

---

### Task 6: Audit & Fix Location/Movement Domain (Domain E)

**Files:**
- Modify: `safetrip-server-api/src/entities/location.entity.ts`
- Modify: `safetrip-server-api/src/entities/planned-route.entity.ts`
- Modify: `safetrip-server-api/src/entities/route-deviation.entity.ts`
- Modify: `safetrip-server-api/sql/04-schema-location-movement.sql`

**Step 1: Compare TB_LOCATION columns**

Doc 07 requires: `group_id` FK, `bearing`, `battery_level`, `network_type`, `is_sharing`, `motion_state`, `provider`, `movement_session_id`, `server_received_at`.

Read location.entity.ts and fix.

**Step 2: Compare TB_LOCATION_SHARING**

Doc 07: `visibility_type` (all|admin_only|specified), `visibility_member_ids` JSONB.

**Step 3: Compare TB_PLANNED_ROUTE and TB_ROUTE_DEVIATION**

Doc 07: `route_data` JSONB (GeoJSON) for planned route; `deviation_data` JSONB for deviations.

**Step 4: Fix SQL and build verify**

---

### Task 7: Audit & Fix Safety/SOS Domain (Domain F)

**Files:**
- Modify: `safetrip-server-api/src/entities/emergency.entity.ts`
- Create: `safetrip-server-api/src/entities/heartbeat.entity.ts`
- Create: `safetrip-server-api/src/entities/power-event.entity.ts`
- Create: `safetrip-server-api/src/entities/sos-rescue-log.entity.ts`
- Create: `safetrip-server-api/src/entities/sos-cancel-log.entity.ts`
- Modify: `safetrip-server-api/sql/05-schema-safety-sos.sql`

**Step 1: Create missing entities**

Doc 07 defines 5 tables in safety domain:
- TB_HEARTBEAT: `heartbeat_id`, `user_id`, `trip_id`, `status` (online|offline|sos_active), `battery_level`, `last_location`, `recorded_at`
- TB_SOS_EVENT: already exists as SosEvent
- TB_POWER_EVENT: `power_event_id`, `user_id`, `trip_id`, `event_type`, `battery_level`, `recorded_at`
- TB_SOS_RESCUE_LOG: `rescue_log_id`, `sos_event_id`, `rescue_type`, `contacted_at`, `resolved_at`, `notes`
- TB_SOS_CANCEL_LOG: `cancel_log_id`, `sos_event_id`, `cancelled_by`, `cancel_reason`, `cancelled_at`

Create new entity files for missing tables. Verify SosEvent and NoResponseEvent match doc.

**Step 2: Fix SQL and build verify**

---

### Task 8: Audit & Fix Chat Domain (Domain G)

**Files:**
- Modify: `safetrip-server-api/src/entities/chat.entity.ts`
- Create: `safetrip-server-api/src/entities/chat-poll.entity.ts`
- Modify: `safetrip-server-api/sql/06-schema-chat.sql`

**Step 1: Compare TB_CHAT_MESSAGE**

Doc 07: `trip_id`, `group_id`, `sender_id`, `content`, `reply_to_id` (self-reference), `message_type`, `sent_at`, `deleted_at`.

Read chat.entity.ts and fix. Note: doc 07 removes ChatRoom concept and uses trip_id+group_id directly. Or if ChatRoom still exists, align.

**Step 2: Create TB_CHAT_POLL and TB_CHAT_POLL_VOTE entities**

Doc 07 defines in-chat polling:
- TB_CHAT_POLL: `poll_id`, `message_id` FK, `question`, `options` JSONB, `expires_at`
- TB_CHAT_POLL_VOTE: `vote_id`, `poll_id` FK, `user_id` FK, `option_index`, `voted_at`, UNIQUE(poll_id, user_id)

**Step 3: Fix SQL and build verify**

---

### Task 9: Audit & Fix Notification Domain (Domain H)

**Files:**
- Modify: `safetrip-server-api/src/entities/notification.entity.ts`
- Create: `safetrip-server-api/src/entities/notification-setting.entity.ts`
- Create: `safetrip-server-api/src/entities/event-notification-config.entity.ts`
- Modify: `safetrip-server-api/sql/07-schema-notification.sql`

**Step 1: Compare TB_NOTIFICATION**

Doc 07: `notification_id`, `user_id`, `trip_id`, `type` (sos|guardian_alert|geofence|schedule|member_join|location_request), `title`, `body`, `data` JSONB, `is_read`.

**Step 2: Rename/fix NotificationPreference → TB_NOTIFICATION_SETTING**

Doc 07 uses TB_NOTIFICATION_SETTING (per-trip): `setting_id`, `user_id`, `trip_id`, `notification_type`, `is_enabled`.

**Step 3: Create TB_EVENT_NOTIFICATION_CONFIG**

Doc 07: `config_id`, `trip_id`, `event_type`, `recipient_role`, `enabled`.

**Step 4: Fix SQL and build verify**

---

### Task 10: Audit & Fix Legal/Privacy Domain Entities (Domain I)

**Files:**
- Create: `safetrip-server-api/src/entities/consent.entity.ts`
- Create: `safetrip-server-api/src/entities/data-log.entity.ts`
- Modify: `safetrip-server-api/sql/08-schema-legal-privacy.sql`

**Step 1: Create TB_USER_CONSENT entity**

Doc 07: `consent_id`, `user_id`, `location_service`, `privacy_policy`, `location_share`, `location_log`, `sos_location`, `heartbeat`, `minor_guardian_consent`, `consent_guardian_id`, timestamps.

**Step 2: Create TB_MINOR_CONSENT entity**

Doc 07: `minor_consent_id`, `user_id`, `guardian_user_id`, `consented_at`.

**Step 3: Create audit log entities**

- TB_LOCATION_ACCESS_LOG
- TB_LOCATION_SHARING_PAUSE_LOG
- TB_DATA_DELETION_LOG
- TB_DATA_PROVISION_LOG

**Step 4: Fix SQL and build verify**

---

### Task 11: Audit & Fix Operations/Log Domain (Domain J)

**Files:**
- Modify: `safetrip-server-api/src/entities/event-log.entity.ts`
- Create: `safetrip-server-api/src/entities/leader-transfer-log.entity.ts`
- Create: `safetrip-server-api/src/entities/emergency-number.entity.ts`
- Modify: `safetrip-server-api/sql/09-schema-ops-log.sql`

**Step 1: Create TB_LEADER_TRANSFER_LOG entity**

Doc 07: `transfer_log_id`, `trip_id`, `from_user_id`, `to_user_id`, `transferred_at`.

**Step 2: Create TB_EMERGENCY_NUMBER entity**

Doc 07: `number_id`, `country_code`, `emergency_type`, `number`, `name_en`, `name_ko`.

**Step 3: Fix SQL and build verify**

---

### Task 12: Audit & Fix Payment/B2B Domain (Domains K, L)

**Files:**
- Modify: `safetrip-server-api/src/entities/payment.entity.ts`
- Modify: `safetrip-server-api/src/entities/b2b.entity.ts`
- Create: `safetrip-server-api/src/entities/billing-item.entity.ts`
- Create: `safetrip-server-api/src/entities/refund-log.entity.ts`
- Create: `safetrip-server-api/src/entities/b2b-batch.entity.ts`
- Modify: `safetrip-server-api/sql/10-schema-payment-b2b.sql`

**Step 1: Compare TB_PAYMENT columns**

Doc 07: `payment_type` CHECK (trip_base|addon_movement|addon_ai_plus|addon_ai_pro|addon_guardian|b2b_contract), `payment_method` (credit_card|app_store|google_play).

**Step 2: Create TB_BILLING_ITEM entity**

Doc 07: `item_id`, `payment_id` FK, `item_type`, `quantity`, `unit_price`, `subtotal`.

**Step 3: Create TB_REFUND_LOG entity**

Doc 07: `refund_id`, `payment_id` FK, `refund_amount`, `refund_policy` (planning_full|active_24h_50pct|active_post_24h_0|completed_0), `refund_reason`, `status`.

**Step 4: Fix B2B entities**

Doc 07 uses TB_B2B_SCHOOL (not B2bOrganization) + TB_B2B_CONTRACT + TB_B2B_INVITE_BATCH + TB_B2B_MEMBER_LOG. Compare and align.

**Step 5: Fix SQL and build verify**

---

### Task 13: Update Entity Index & App Module

**Files:**
- Modify: `safetrip-server-api/src/entities/index.ts`
- Modify: `safetrip-server-api/src/app.module.ts`

**Step 1: Export all new entities from index.ts**

Register every new entity created in Tasks 2-12.

**Step 2: Add new entities to TypeORM config in app.module.ts**

Ensure `entities: [...]` array includes all new entities.

**Step 3: Full build verify**

Run: `cd safetrip-server-api && npx tsc --noEmit`
Expected: 0 errors

**Step 4: Commit Phase 1**

```bash
git add safetrip-server-api/src/entities/ safetrip-server-api/sql/
git commit -m "refactor: align DB entities and SQL schemas with Master_docs 07 v3.5 (54 tables)"
```

---

## Phase 2: API Endpoint Alignment (Docs 35-38)

### Task 14: Audit & Fix Auth/Users Endpoints

**Files:**
- Modify: `safetrip-server-api/src/modules/auth/auth.controller.ts`
- Modify: `safetrip-server-api/src/modules/users/users.controller.ts`
- Modify: `safetrip-server-api/src/modules/users/users.service.ts`

**Step 1: Compare auth endpoints**

Doc 36 specifies:
- `POST /api/v1/auth/firebase-verify` — verify + upsert
- `POST /api/v1/auth/logout`

Read auth.controller.ts. Remove excess endpoints or add missing ones.

**Step 2: Compare user endpoints**

Doc 36 specifies:
- `POST /api/v1/users/register` (test)
- `GET /api/v1/users/by-phone?phone_number=`
- `GET /api/v1/users/search?q=`
- `GET /api/v1/users/:userId` (public)
- `PUT /api/v1/users/:userId`
- `GET /api/v1/users/me`
- `PATCH /api/v1/users/me`
- `PUT /api/v1/users/:userId/fcm-token` and `PUT /api/v1/users/me/fcm-token`
- `DELETE /api/v1/users/me/fcm-token/:tokenId`
- `PATCH /api/v1/users/:id/terms`

Check for missing endpoints (especially terms update, FCM token delete).

**Step 3: Add rate limiter middleware**

Doc 36: `authLimiter` (20 req/15min/IP) on `/api/v1/auth/*`.

**Step 4: Build verify**

---

### Task 15: Audit & Fix Trips Endpoints

**Files:**
- Modify: `safetrip-server-api/src/modules/trips/trips.controller.ts` (rename from trips.controller if needed)
- Modify: `safetrip-server-api/src/modules/trips/trips.service.ts`

**Step 1: Compare trip endpoints against doc 36**

Check for missing endpoints:
- `GET /api/v1/trips/guardian-invite/:inviteCode`
- `POST /api/v1/trips/guardian-join`
- `GET /api/v1/trips/:tripId/invite-code`
- `POST /api/v1/trips/:tripId/regenerate-invite-code`
- `GET /api/v1/trips/:tripId/settings`
- `PATCH /api/v1/trips/:tripId/settings`
- `GET /api/v1/trips/groups/:group_id`
- `GET /api/v1/trips/groups/:group_id/countries`
- `GET /api/v1/trips/users/:user_id/countries`
- `GET /api/v1/trips/groups/:group_id/timezones`

**Step 2: Verify trip creation auto-creates group + chat room**

Doc 36: `POST /api/v1/trips` must return `{ trip_id, group_id, captain_id, chat_room_id }`.

**Step 3: Build verify**

---

### Task 16: Audit & Fix Groups/Invite Codes/Leadership Endpoints

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.controller.ts`
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts`

**Step 1: Compare group endpoints against doc 37**

Check for missing:
- `POST /api/v1/groups/:groupId/invite-codes` (CRUD)
- `POST /api/v1/groups/:groupId/transfer-leadership`
- `GET /api/v1/groups/:groupId/transfer-history`

**Step 2: Compare attendance endpoints**

Doc 37: `POST /api/v1/groups/:group_id/attendance/start`

This may need a new controller or adding to groups controller.

**Step 3: Compare schedule endpoints**

Doc 37: `GET/POST/PATCH/DELETE /api/v1/groups/:group_id/schedules`

**Step 4: Build verify**

---

### Task 17: Audit & Fix Guardian Endpoints

**Files:**
- Modify: `safetrip-server-api/src/modules/guardians/guardians.controller.ts`
- Modify: `safetrip-server-api/src/modules/guardians/guardians.service.ts`

**Step 1: Compare guardian endpoints against doc 37**

Check missing endpoints:
- Guardian message endpoints (member→guardian, captain→guardian)
- `GET /api/v1/trips/:tripId/guardian-view/:memberId`
- `GET /api/v1/trips/:tripId/guardian-view/itinerary`
- `GET /api/v1/trips/:tripId/guardian-view/places`
- `GET /api/v1/guardians/verify-code/:code`
- `POST /api/v1/guardians/verify-phone`
- `GET /api/v1/guardians/my-trips`
- `GET /api/v1/guardians/:guardianId/travelers`

**Step 2: Build verify**

---

### Task 18: Audit & Fix Location/Geofence Endpoints

**Files:**
- Modify: `safetrip-server-api/src/modules/locations/locations.controller.ts`
- Modify: `safetrip-server-api/src/modules/geofences/geofences.controller.ts`

**Step 1: Compare location endpoints against doc 37**

Check missing:
- Location sharing sub-resource endpoints: `GET/PUT /api/v1/groups/:groupId/location-sharing`
- Movement session endpoints

**Step 2: Compare geofence endpoints against doc 37**

Verify geofence event recording endpoint exists.

**Step 3: Build verify**

---

### Task 19: Audit & Fix Remaining Endpoints (Emergency, Chat, Notification, Payment, B2B, Guides, Events)

**Files:**
- Modify: Multiple controllers across modules

**Step 1: Compare emergency/SOS endpoints against docs**

**Step 2: Compare chat endpoints**

**Step 3: Compare notification/FCM endpoints**

Doc 38: FCM endpoints at `/api/v1/fcm/*`

**Step 4: Compare guide/MOFA endpoints**

Doc 38: 8+ guide/MOFA endpoints.

**Step 5: Compare events/logging endpoints**

Doc 38: `POST/GET /api/v1/events`

**Step 6: Build verify and commit Phase 2**

```bash
git add safetrip-server-api/src/modules/
git commit -m "refactor: align API endpoints with Master_docs 35-38 API specs (120+ endpoints)"
```

---

## Phase 3: Feature Business Logic (Docs 13-30)

### Task 20: SOS & Safety Logic (Doc 13)

**Files:**
- Modify: `safetrip-server-api/src/modules/emergencies/emergencies.service.ts`

**Step 1: Read doc 13 SOS requirements**

Key rules:
- SOS forces location capture regardless of privacy settings
- SOS broadcast to all group members + sender's connected guardians
- Only members (captain/crew_chief/crew) can send SOS, not guardians
- 5-minute cooldown between SOS events
- SOS data preserved 3 years

**Step 2: Verify business logic in emergencies.service.ts**

Read the service and check each rule is implemented.

**Step 3: Fix mismatches**

---

### Task 21: Location Sharing & Privacy Logic (Docs 09, 17, 25)

**Files:**
- Modify: `safetrip-server-api/src/modules/locations/locations.service.ts`

**Step 1: Read docs 09, 17, 25 location requirements**

Key rules per doc 01 §04:
- 3-tier hierarchy: privacy_level → sharing_mode → schedule_type + visibility
- Collection frequency varies by privacy level and motion state
- Guardian snapshot rules differ by privacy level
- SOS override forces location sharing

**Step 2: Verify location service implements privacy-aware logic**

**Step 3: Fix mismatches**

---

### Task 22: Chat & Messaging Logic (Doc 20)

**Files:**
- Modify: `safetrip-server-api/src/modules/chats/chats.service.ts`

**Step 1: Read doc 20 chat requirements**

**Step 2: Verify chat poll support if required**

**Step 3: Fix mismatches**

---

### Task 23: Notification & Alert Logic (Doc 22)

**Files:**
- Modify: `safetrip-server-api/src/modules/notifications/notifications.service.ts`

**Step 1: Read doc 22 notification requirements**

**Step 2: Verify per-trip notification settings**

**Step 3: Fix mismatches**

---

### Task 24: AI Feature Logic (Doc 26)

**Files:**
- Modify: `safetrip-server-api/src/modules/ai/ai.service.ts`

**Step 1: Read doc 26 AI requirements**

Key rules per doc 01 §10:
- Minor AI restrictions: Safety AI unlimited, Convenience AI unlimited, Intelligence AI (personal) blocked, Intelligence AI (group) allowed
- `ai_intelligence_blocked` user flag

**Step 2: Verify AI service respects minor restrictions**

**Step 3: Fix mismatches**

---

### Task 25: Invite Code & Onboarding Logic (Docs 14, 23)

**Files:**
- Modify: `safetrip-server-api/src/modules/groups/groups.service.ts`
- Modify: `safetrip-server-api/src/modules/trips/trips.service.ts`

**Step 1: Read docs 14, 23 requirements**

Key rules:
- Invite code 7-char unique
- Target role assignment
- Expiration handling
- B2B batch invite support

**Step 2: Verify invite code logic**

**Step 3: Fix mismatches**

---

### Task 26: Commit Phase 3

```bash
git add safetrip-server-api/src/modules/
git commit -m "refactor: align feature business logic with Master_docs 13-30 principle documents"
```

---

## Phase 4: Infrastructure & Architecture (Docs 08, 31, 33)

### Task 27: Add Missing Middleware & Guards (Doc 08)

**Files:**
- Create: `safetrip-server-api/src/common/guards/role.guard.ts`
- Create: `safetrip-server-api/src/common/decorators/roles.decorator.ts`
- Create: `safetrip-server-api/src/common/middleware/rate-limiter.middleware.ts`
- Modify: `safetrip-server-api/src/app.module.ts`

**Step 1: Create RoleGuard**

Doc 08 requires `@Roles('captain', 'crew')` decorator + RoleGuard checking `tb_group_member.member_role`.

**Step 2: Create Rate Limiter**

Doc 08/36: Three tiers:
- `generalLimiter`: 500 req/15min/IP
- `authLimiter`: 20 req/15min/IP
- `locationLimiter`: 120 req/1min/IP

**Step 3: Register in app.module.ts**

**Step 4: Build verify**

---

### Task 28: Performance & Monitoring (Doc 31)

**Files:**
- Modify: `safetrip-server-api/src/common/logger/logger.service.ts`
- Modify: `safetrip-server-api/src/main.ts`

**Step 1: Read doc 31 monitoring requirements**

**Step 2: Verify logging levels, health check, error tracking**

**Step 3: Fix mismatches**

---

### Task 29: External API Management (Doc 33)

**Files:**
- Modify: `safetrip-server-api/src/modules/mofa/mofa.module.ts`
- Modify: relevant service files

**Step 1: Read doc 33 external API requirements**

**Step 2: Verify MOFA integration, geocoding, Firebase RTDB patterns**

**Step 3: Fix mismatches**

---

### Task 30: Final Build, SQL Schema Consistency Check, Commit Phase 4

**Step 1: Full build**

Run: `cd safetrip-server-api && npx tsc --noEmit`

**Step 2: Verify all 54 tables exist in SQL files**

Count tables across all sql/*.sql files. Should be 54.

**Step 3: Verify all entities are registered**

Count entity files. Should match doc 07 table count.

**Step 4: Commit**

```bash
git add safetrip-server-api/
git commit -m "refactor: complete Master_docs alignment — all 4 phases (DB, API, features, infra)"
```

---

## Execution Notes

- **SSOT**: Doc 07 (DB설계) is the single source of truth for all schema decisions
- **Conflict Resolution**: If code has extra columns not in doc, keep them (backward compat). If doc has columns not in code, add them.
- **No Breaking Changes**: Existing endpoints keep working. New entities/columns are additive.
- **Build Gate**: Every task ends with `npx tsc --noEmit`. No moving forward with build errors.
- **Phase Order**: Must be P1→P2→P3→P4. Entities must exist before endpoints reference them.
