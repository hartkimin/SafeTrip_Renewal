# Guardian System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 가디언(Guardian) 역할의 1:1 멤버 연결 구조, 권한 미들웨어, 메시지 시스템, API 엔드포인트, Flutter UI를 완전하게 구현한다.

**Architecture:**
DB 스키마(`tb_guardian_link`, `tb_trip_settings`)와 서비스 레이어(`guardian-link.service.ts`, `guardian-message.service.ts`, `trip-settings.service.ts`, `guardian-permission.middleware.ts`)는 이미 구현 완료. 이번 작업은 컨트롤러/라우트 레이어를 연결하고, 누락된 `guardian-view.service.ts`와 캡틴 전용 미들웨어를 추가하고, `index.ts`에 라우트를 등록하며, Flutter UI를 구현한다.

**Tech Stack:** Node.js/TypeScript (Express), PostgreSQL, Firebase RTDB, Flutter/Dart

---

## 현황 요약 (이미 완료된 것)

| 파일 | 상태 |
|------|------|
| `migration-guardian-system.sql` | ✅ DB 마이그레이션 완료 |
| `guardian-link.service.ts` | ✅ CRUD + 목록 조회 구현 완료 |
| `guardian-message.service.ts` | ✅ RTDB 기반 메시지 구현 완료 |
| `trip-settings.service.ts` | ✅ getSettings/updateCaptainReceiveMsg 완료 |
| `guardian-permission.middleware.ts` | ✅ 5개 미들웨어 완료 |

---

## Task 1: 캡틴 전용 미들웨어 추가

**파일:**
- Modify: `safetrip-server-api/src/middleware/guardian-permission.middleware.ts`

**목적:** PATCH `/trips/:tripId/settings`를 캡틴만 사용할 수 있도록 검증.

**Step 1: 파일 하단에 `requireTripCaptain` 함수 추가**

```typescript
// guardian-permission.middleware.ts 맨 아래에 추가

// 6. 해당 여행의 캡틴인지 검증
export const requireTripCaptain = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const userId = req.userId;
    const { tripId } = req.params;

    const db = getDatabase();
    const result = await db.query(
      `SELECT gm.member_id
       FROM tb_group_member gm
       INNER JOIN tb_trip t ON t.group_id = gm.group_id
       WHERE t.trip_id = $1
         AND gm.user_id = $2
         AND gm.member_role = 'captain'
         AND gm.status = 'active'
       LIMIT 1`,
      [tripId, userId]
    );

    if (result.rows.length === 0) {
      sendError(res, '캡틴만 접근할 수 있습니다', 403);
      return;
    }

    next();
  } catch (error: any) {
    logger.error('requireTripCaptain error', { error: error.message });
    sendError(res, '권한 확인 중 오류가 발생했습니다', 500);
  }
};
```

**Step 2: 서버 재시작 후 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npx tsc --noEmit 2>&1 | head -30
```

Expected: 에러 없음

**Step 3: Commit**

```bash
git add src/middleware/guardian-permission.middleware.ts
git commit -m "feat: add requireTripCaptain middleware"
```

---

## Task 2: 가디언 관리 API — 컨트롤러 + 라우트

**파일:**
- Create: `safetrip-server-api/src/controllers/trip-guardian.controller.ts`
- Create: `safetrip-server-api/src/routes/trip-guardian.routes.ts`

**목적:** POST/PATCH/DELETE/GET 엔드포인트를 `/trips/:tripId/guardians` 경로로 노출.

**Step 1: 컨트롤러 생성**

`src/controllers/trip-guardian.controller.ts`:

```typescript
import { Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware';
import { sendSuccess, sendError } from '../utils/response';
import { guardianLinkService } from '../services/guardian-link.service';

export const tripGuardianController = {
  /**
   * POST /trips/:tripId/guardians
   * 멤버가 가디언 추가 요청 (전화번호로)
   * 미들웨어: authenticate, validateGuardianLimit
   */
  createGuardianLink: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const memberId = req.userId!;
      const { tripId } = req.params;
      const { guardian_phone } = req.body;

      if (!guardian_phone) {
        sendError(res, 'guardian_phone is required', 400);
        return;
      }

      const result = await guardianLinkService.createGuardianLink(tripId, memberId, guardian_phone);
      sendSuccess(res, result, '가디언 요청이 전송되었습니다', 201);
    } catch (error: any) {
      if (error.message === 'USER_NOT_FOUND') {
        sendError(res, '해당 전화번호로 가입된 사용자를 찾을 수 없습니다', 404);
      } else if (error.message === 'SELF_GUARDIAN_NOT_ALLOWED') {
        sendError(res, '본인을 가디언으로 추가할 수 없습니다', 400);
      } else if (error.message === 'GUARDIAN_LINK_ALREADY_EXISTS') {
        sendError(res, '이미 요청한 가디언입니다', 409);
      } else {
        sendError(res, '가디언 요청 중 오류가 발생했습니다', 500);
      }
    }
  },

  /**
   * PATCH /trips/:tripId/guardians/:linkId/respond
   * 가디언이 초대 수락/거절
   * 미들웨어: authenticate
   */
  respondToGuardianLink: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const guardianId = req.userId!;
      const { linkId } = req.params;
      const { action } = req.body;

      if (!action || !['accepted', 'rejected'].includes(action)) {
        sendError(res, "action must be 'accepted' or 'rejected'", 400);
        return;
      }

      const result = await guardianLinkService.respondToGuardianLink(linkId, guardianId, action);
      sendSuccess(res, result, action === 'accepted' ? '가디언 요청을 수락했습니다' : '가디언 요청을 거절했습니다');
    } catch (error: any) {
      if (error.message === 'GUARDIAN_LINK_NOT_FOUND_OR_NOT_PENDING') {
        sendError(res, '처리할 수 없는 요청입니다 (존재하지 않거나 이미 처리됨)', 404);
      } else {
        sendError(res, '응답 처리 중 오류가 발생했습니다', 500);
      }
    }
  },

  /**
   * DELETE /trips/:tripId/guardians/:linkId
   * 가디언 연결 해제 (멤버 또는 가디언 본인)
   * 미들웨어: authenticate
   */
  deleteGuardianLink: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const requestUserId = req.userId!;
      const { linkId } = req.params;

      await guardianLinkService.deleteGuardianLink(linkId, requestUserId);
      sendSuccess(res, null, '가디언 연결이 해제되었습니다');
    } catch (error: any) {
      if (error.message === 'GUARDIAN_LINK_NOT_FOUND_OR_UNAUTHORIZED') {
        sendError(res, '해당 가디언 연결을 찾을 수 없거나 권한이 없습니다', 404);
      } else {
        sendError(res, '가디언 연결 해제 중 오류가 발생했습니다', 500);
      }
    }
  },

  /**
   * GET /trips/:tripId/guardians/me
   * 멤버 본인의 가디언 목록 조회
   * 미들웨어: authenticate
   */
  getMyGuardians: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const memberId = req.userId!;
      const { tripId } = req.params;

      const guardians = await guardianLinkService.getMyGuardians(tripId, memberId);
      sendSuccess(res, guardians);
    } catch (error: any) {
      sendError(res, '가디언 목록 조회 중 오류가 발생했습니다', 500);
    }
  },

  /**
   * GET /trips/:tripId/guardians/pending
   * 가디언 본인에게 온 pending 초대 목록
   * 미들웨어: authenticate
   */
  getPendingInvitations: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const guardianId = req.userId!;

      const invitations = await guardianLinkService.getPendingInvitations(guardianId);
      sendSuccess(res, invitations);
    } catch (error: any) {
      sendError(res, '초대 목록 조회 중 오류가 발생했습니다', 500);
    }
  },

  /**
   * GET /trips/:tripId/guardians/linked-members
   * 가디언 본인의 accepted 멤버 목록
   * 미들웨어: authenticate
   */
  getLinkedMembers: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const guardianId = req.userId!;
      const { tripId } = req.params;

      const members = await guardianLinkService.getLinkedMembers(tripId, guardianId);
      sendSuccess(res, members);
    } catch (error: any) {
      sendError(res, '연결된 멤버 목록 조회 중 오류가 발생했습니다', 500);
    }
  },
};
```

**Step 2: 라우트 생성**

`src/routes/trip-guardian.routes.ts`:

```typescript
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import {
  validateGuardianLimit,
} from '../middleware/guardian-permission.middleware';
import { tripGuardianController } from '../controllers/trip-guardian.controller';

const router = Router({ mergeParams: true }); // tripId를 상위에서 상속

// POST /trips/:tripId/guardians — 가디언 추가 요청 (3명 제한 검증 포함)
router.post('/', authenticate, validateGuardianLimit, tripGuardianController.createGuardianLink);

// PATCH /trips/:tripId/guardians/:linkId/respond — 가디언 수락/거절
router.patch('/:linkId/respond', authenticate, tripGuardianController.respondToGuardianLink);

// DELETE /trips/:tripId/guardians/:linkId — 가디언 연결 해제
router.delete('/:linkId', authenticate, tripGuardianController.deleteGuardianLink);

// GET /trips/:tripId/guardians/me — 내 가디언 목록
router.get('/me', authenticate, tripGuardianController.getMyGuardians);

// GET /trips/:tripId/guardians/pending — 나에게 온 pending 초대 목록
router.get('/pending', authenticate, tripGuardianController.getPendingInvitations);

// GET /trips/:tripId/guardians/linked-members — 내가 가디언인 멤버 목록
router.get('/linked-members', authenticate, tripGuardianController.getLinkedMembers);

export { router as tripGuardianRoutes };
```

**Step 3: TypeScript 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npx tsc --noEmit 2>&1 | head -30
```

Expected: 에러 없음

**Step 4: Commit**

```bash
git add src/controllers/trip-guardian.controller.ts src/routes/trip-guardian.routes.ts
git commit -m "feat: add trip-guardian controller and routes"
```

---

## Task 3: 가디언 뷰 서비스 + 컨트롤러 + 라우트

**파일:**
- Create: `safetrip-server-api/src/services/guardian-view.service.ts`
- Create: `safetrip-server-api/src/controllers/guardian-view.controller.ts`
- Create: `safetrip-server-api/src/routes/guardian-view.routes.ts`

**목적:** 가디언이 연결된 멤버 정보, 여행 일정, 장소를 조회할 수 있는 읽기 전용 API.

**Step 1: guardian-view.service.ts 생성**

```typescript
import { getDatabase } from '../config/database';
import { logger } from '../utils/logger';

export const guardianViewService = {
  /**
   * 가디언이 연결된 특정 멤버의 기본 프로필 조회
   */
  async getMemberInfo(tripId: string, memberId: string): Promise<{
    user_id: string;
    display_name: string;
    phone_number: string;
    profile_image_url: string | null;
    member_role: string | null;
  } | null> {
    const db = getDatabase();
    const result = await db.query(
      `SELECT
         u.user_id,
         u.display_name,
         u.phone_number,
         u.profile_image_url,
         gm.member_role
       FROM tb_user u
       LEFT JOIN tb_trip t ON t.trip_id = $1
       LEFT JOIN tb_group_member gm
         ON gm.group_id = t.group_id
        AND gm.user_id  = u.user_id
        AND gm.status   = 'active'
       WHERE u.user_id = $2
         AND u.deleted_at IS NULL`,
      [tripId, memberId]
    );

    if (result.rows.length === 0) return null;
    const row = result.rows[0];
    return {
      user_id: row.user_id,
      display_name: row.display_name,
      phone_number: row.phone_number,
      profile_image_url: row.profile_image_url,
      member_role: row.member_role,
    };
  },

  /**
   * 여행 일정 조회 (tb_travel_schedule, 날짜 오름차순)
   */
  async getItinerary(tripId: string): Promise<Array<{
    schedule_id: string;
    title: string;
    description: string | null;
    schedule_type: string;
    start_time: string;
    end_time: string | null;
    location_name: string | null;
    location_address: string | null;
  }>> {
    const db = getDatabase();
    const result = await db.query(
      `SELECT
         schedule_id,
         title,
         description,
         schedule_type,
         start_time,
         end_time,
         location_name,
         location_address
       FROM tb_travel_schedule
       WHERE trip_id = $1
       ORDER BY start_time ASC`,
      [tripId]
    );

    return result.rows.map((row) => ({
      schedule_id: row.schedule_id,
      title: row.title,
      description: row.description,
      schedule_type: row.schedule_type,
      start_time: row.start_time,
      end_time: row.end_time,
      location_name: row.location_name,
      location_address: row.location_address,
    }));
  },

  /**
   * 여행 장소(지오펜스) 조회 — 활성화된 지오펜스만
   */
  async getPlaces(tripId: string): Promise<Array<{
    geofence_id: string;
    name: string;
    center_latitude: number;
    center_longitude: number;
    radius_meters: number | null;
    shape_type: string;
  }>> {
    const db = getDatabase();
    const result = await db.query(
      `SELECT
         geofence_id,
         name,
         center_latitude,
         center_longitude,
         radius_meters,
         shape_type
       FROM tb_geofence
       WHERE trip_id = $1
         AND is_active = TRUE
       ORDER BY name ASC`,
      [tripId]
    );

    return result.rows.map((row) => ({
      geofence_id: row.geofence_id,
      name: row.name,
      center_latitude: parseFloat(row.center_latitude),
      center_longitude: parseFloat(row.center_longitude),
      radius_meters: row.radius_meters ? parseFloat(row.radius_meters) : null,
      shape_type: row.shape_type,
    }));
  },
};
```

**Step 2: guardian-view.controller.ts 생성**

```typescript
import { Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware';
import { sendSuccess, sendError } from '../utils/response';
import { guardianViewService } from '../services/guardian-view.service';

export const guardianViewController = {
  /**
   * GET /trips/:tripId/guardian-view/:memberId
   * 연결된 멤버 기본 프로필 조회
   * 미들웨어: authenticate, requireGuardianLinkForMember
   */
  getMemberInfo: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { tripId, memberId } = req.params;
      const info = await guardianViewService.getMemberInfo(tripId, memberId);

      if (!info) {
        sendError(res, '멤버 정보를 찾을 수 없습니다', 404);
        return;
      }

      sendSuccess(res, info);
    } catch (error: any) {
      sendError(res, '멤버 정보 조회 중 오류가 발생했습니다', 500);
    }
  },

  /**
   * GET /trips/:tripId/guardian-view/itinerary
   * 여행 일정 조회 (읽기 전용)
   * 미들웨어: authenticate, requireGuardianLinkForTrip
   */
  getItinerary: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { tripId } = req.params;
      const schedules = await guardianViewService.getItinerary(tripId);
      sendSuccess(res, schedules);
    } catch (error: any) {
      sendError(res, '일정 조회 중 오류가 발생했습니다', 500);
    }
  },

  /**
   * GET /trips/:tripId/guardian-view/places
   * 여행 장소(지오펜스) 조회 (읽기 전용)
   * 미들웨어: authenticate, requireGuardianLinkForTrip
   */
  getPlaces: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { tripId } = req.params;
      const places = await guardianViewService.getPlaces(tripId);
      sendSuccess(res, places);
    } catch (error: any) {
      sendError(res, '장소 조회 중 오류가 발생했습니다', 500);
    }
  },
};
```

**Step 3: guardian-view.routes.ts 생성**

```typescript
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import {
  requireGuardianLinkForMember,
  requireGuardianLinkForTrip,
} from '../middleware/guardian-permission.middleware';
import { guardianViewController } from '../controllers/guardian-view.controller';

const router = Router({ mergeParams: true });

// GET /trips/:tripId/guardian-view/itinerary — 일정 조회
// 주의: :memberId 라우트보다 먼저 정의해야 'itinerary'가 memberId로 캡처되지 않음
router.get('/itinerary', authenticate, requireGuardianLinkForTrip, guardianViewController.getItinerary);

// GET /trips/:tripId/guardian-view/places — 장소 조회
router.get('/places', authenticate, requireGuardianLinkForTrip, guardianViewController.getPlaces);

// GET /trips/:tripId/guardian-view/:memberId — 연결 멤버 프로필
router.get('/:memberId', authenticate, requireGuardianLinkForMember, guardianViewController.getMemberInfo);

export { router as guardianViewRoutes };
```

**Step 4: TypeScript 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npx tsc --noEmit 2>&1 | head -30
```

**Step 5: Commit**

```bash
git add src/services/guardian-view.service.ts \
        src/controllers/guardian-view.controller.ts \
        src/routes/guardian-view.routes.ts
git commit -m "feat: add guardian-view service/controller/routes"
```

---

## Task 4: 캡틴 설정 API + 가디언 메시지 API

**파일:**
- Create: `safetrip-server-api/src/controllers/guardian-messages.controller.ts`
- Create: `safetrip-server-api/src/routes/guardian-messages.routes.ts`
- Modify: `safetrip-server-api/src/controllers/trips.controller.ts` (updateTripSettings 핸들러 추가)
- Modify: `safetrip-server-api/src/routes/trips.routes.ts` (PATCH /:tripId/settings 라우트 추가)

**Step 1: guardian-messages.controller.ts 생성**

```typescript
import { Response } from 'express';
import { AuthRequest } from '../middleware/auth.middleware';
import { sendSuccess, sendError } from '../utils/response';
import { guardianMessageService } from '../services/guardian-message.service';

export const guardianMessagesController = {
  /**
   * POST /trips/:tripId/guardian-messages
   * 메시지 전송
   * Body: { receiver_id, message, message_type: 'to_member' | 'to_captain' }
   * 미들웨어: authenticate
   * - to_captain이면 requireCanMessageCaptain 미들웨어로 별도 처리 (라우트에서 분기)
   */
  sendMessage: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const senderId = req.userId!;
      const { tripId } = req.params;
      const { receiver_id, message, message_type } = req.body;

      if (!receiver_id || !message || !message_type) {
        sendError(res, 'receiver_id, message, message_type are required', 400);
        return;
      }

      if (!['to_member', 'to_captain'].includes(message_type)) {
        sendError(res, "message_type must be 'to_member' or 'to_captain'", 400);
        return;
      }

      let messageKey: string;

      if (message_type === 'to_captain') {
        // 캡틴 ID 조회
        const captainId = await guardianMessageService.getTripCaptainId(tripId);
        if (!captainId) {
          sendError(res, '캡틴을 찾을 수 없습니다', 404);
          return;
        }
        messageKey = await guardianMessageService.sendToCaptain(tripId, senderId, captainId, message);
      } else {
        messageKey = await guardianMessageService.sendToMember(tripId, senderId, receiver_id, message);
      }

      sendSuccess(res, { message_key: messageKey }, '메시지가 전송되었습니다', 201);
    } catch (error: any) {
      sendError(res, '메시지 전송 중 오류가 발생했습니다', 500);
    }
  },

  /**
   * GET /trips/:tripId/guardian-messages/:channelId
   * 채널 메시지 이력 조회 (최근 50개)
   * 미들웨어: authenticate
   */
  getChannelMessages: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const userId = req.userId!;
      const { tripId, channelId } = req.params;

      // 채널 접근 권한 검증
      const canAccess = await guardianMessageService.validateChannelAccess(tripId, channelId, userId);
      if (!canAccess) {
        sendError(res, '해당 채널에 접근 권한이 없습니다', 403);
        return;
      }

      const messages = await guardianMessageService.getChannelMessages(tripId, channelId);
      sendSuccess(res, messages);
    } catch (error: any) {
      sendError(res, '메시지 조회 중 오류가 발생했습니다', 500);
    }
  },

  /**
   * PATCH /trips/:tripId/guardian-messages/:channelId/:messageId/read
   * 특정 메시지 읽음 처리
   * 미들웨어: authenticate
   */
  markAsRead: async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { tripId, channelId, messageId } = req.params;
      await guardianMessageService.markAsRead(tripId, channelId, messageId);
      sendSuccess(res, null, '읽음 처리 완료');
    } catch (error: any) {
      sendError(res, '읽음 처리 중 오류가 발생했습니다', 500);
    }
  },
};
```

**Step 2: guardian-messages.routes.ts 생성**

```typescript
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { requireCanMessageCaptain } from '../middleware/guardian-permission.middleware';
import { guardianMessagesController } from '../controllers/guardian-messages.controller';

const router = Router({ mergeParams: true });

// POST /trips/:tripId/guardian-messages — 메시지 전송
// to_captain 메시지는 requireCanMessageCaptain으로 검증
// 메시지 타입에 따라 미들웨어를 분기하기 위해 별도 라우트 정의
router.post(
  '/',
  authenticate,
  // 캡틴 메시지 권한은 컨트롤러 내 message_type 확인 후 처리
  // (to_member는 guardian-permission.middleware의 채널 검증으로 커버)
  guardianMessagesController.sendMessage
);

// 캡틴 전용 메시지 전송 엔드포인트 (권한 미들웨어 명시적 적용)
router.post(
  '/to-captain',
  authenticate,
  requireCanMessageCaptain,
  guardianMessagesController.sendMessage
);

// GET /trips/:tripId/guardian-messages/:channelId — 채널 메시지 조회
router.get('/:channelId', authenticate, guardianMessagesController.getChannelMessages);

// PATCH /trips/:tripId/guardian-messages/:channelId/:messageId/read — 읽음 처리
router.patch('/:channelId/:messageId/read', authenticate, guardianMessagesController.markAsRead);

export { router as guardianMessagesRoutes };
```

**Step 3: trips.controller.ts에 updateTripSettings 핸들러 추가**

`trips.controller.ts` 끝에 추가:

```typescript
// trips.controller.ts 내 tripsController 객체에 추가
updateTripSettings: async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { tripId } = req.params;
    const { captain_receive_guardian_msg } = req.body;

    if (typeof captain_receive_guardian_msg !== 'boolean') {
      sendError(res, 'captain_receive_guardian_msg must be a boolean', 400);
      return;
    }

    const settings = await tripSettingsService.updateCaptainReceiveMsg(tripId, captain_receive_guardian_msg);
    sendSuccess(res, settings, '설정이 업데이트되었습니다');
  } catch (error: any) {
    sendError(res, '설정 업데이트 중 오류가 발생했습니다', 500);
  }
},
```

그리고 trips.controller.ts 상단 import에 추가:
```typescript
import { tripSettingsService } from '../services/trip-settings.service';
```

**Step 4: trips.routes.ts에 settings 라우트 추가**

```typescript
// trips.routes.ts에 추가
import { authenticate } from '../middleware/auth.middleware';
import { requireTripCaptain } from '../middleware/guardian-permission.middleware';

// PATCH /api/v1/trips/:tripId/settings — 캡틴 전용 여행 설정 변경
router.patch('/:tripId/settings', authenticate, requireTripCaptain, tripsController.updateTripSettings);
```

**Step 5: TypeScript 컴파일 확인**

```bash
npx tsc --noEmit 2>&1 | head -30
```

**Step 6: Commit**

```bash
git add src/controllers/guardian-messages.controller.ts \
        src/routes/guardian-messages.routes.ts \
        src/controllers/trips.controller.ts \
        src/routes/trips.routes.ts
git commit -m "feat: add guardian-messages API and trip settings update endpoint"
```

---

## Task 5: index.ts에 새 라우트 등록 + 서버 기동 확인

**파일:**
- Modify: `safetrip-server-api/src/index.ts`

**Step 1: index.ts에 3개 라우트 추가**

`index.ts`의 import 섹션에:

```typescript
import { tripGuardianRoutes } from './routes/trip-guardian.routes';
import { guardianViewRoutes } from './routes/guardian-view.routes';
import { guardianMessagesRoutes } from './routes/guardian-messages.routes';
```

Routes 섹션에 (tripsRoutes 등록 바로 뒤에 추가):

```typescript
// Guardian system — /trips/:tripId 하위 라우트
app.use('/api/v1/trips/:tripId/guardians', tripGuardianRoutes);
app.use('/api/v1/trips/:tripId/guardian-view', guardianViewRoutes);
app.use('/api/v1/trips/:tripId/guardian-messages', guardianMessagesRoutes);
```

**Step 2: TypeScript 컴파일 확인**

```bash
npx tsc --noEmit 2>&1 | head -30
```

Expected: 에러 없음

**Step 3: 서버 실행 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-server-api
npm run dev > /tmp/safetrip-backend.log 2>&1 &
sleep 3
curl -s http://localhost:3001/health | head -5
```

Expected: `{"status":"ok"}` 또는 `{"success":true,...}`

**Step 4: API 동작 테스트 (서버가 실행 중일 때)**

아래 엔드포인트가 인증 없이 401을 반환하는지 확인:
```bash
curl -s -w "\n%{http_code}" http://localhost:3001/api/v1/trips/test-trip-id/guardians/me
# Expected: 401
curl -s -w "\n%{http_code}" http://localhost:3001/api/v1/trips/test-trip-id/guardian-view/itinerary
# Expected: 401
curl -s -w "\n%{http_code}" http://localhost:3001/api/v1/trips/test-trip-id/guardian-messages/test-channel
# Expected: 401
```

**Step 5: 서버 로그 확인**

```bash
tail -20 /tmp/safetrip-backend.log
```

Expected: 에러 없음

**Step 6: Commit**

```bash
git add src/index.ts
git commit -m "feat: register guardian system routes in index.ts"
```

---

## Task 6: Flutter — 가디언 모델 + API 서비스 메서드

**파일:**
- Create: `safetrip-mobile/lib/models/guardian_link.dart`
- Modify: `safetrip-mobile/lib/services/api_service.dart`

**Step 1: guardian_link.dart 모델 생성**

```dart
class GuardianLink {
  final String linkId;
  final String guardianId;
  final String status; // pending | accepted | rejected
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String displayName;
  final String phoneNumber;
  final String? profileImageUrl;

  const GuardianLink({
    required this.linkId,
    required this.guardianId,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    required this.displayName,
    required this.phoneNumber,
    this.profileImageUrl,
  });

  factory GuardianLink.fromJson(Map<String, dynamic> json) {
    return GuardianLink(
      linkId: json['link_id'] as String,
      guardianId: json['guardian_id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      displayName: json['display_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }
}

class LinkedMember {
  final String linkId;
  final String memberId;
  final String displayName;
  final String phoneNumber;
  final String? profileImageUrl;
  final String? memberRole;

  const LinkedMember({
    required this.linkId,
    required this.memberId,
    required this.displayName,
    required this.phoneNumber,
    this.profileImageUrl,
    this.memberRole,
  });

  factory LinkedMember.fromJson(Map<String, dynamic> json) {
    return LinkedMember(
      linkId: json['link_id'] as String,
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
      memberRole: json['member_role'] as String?,
    );
  }
}

class GuardianInvitation {
  final String linkId;
  final String tripId;
  final String memberId;
  final DateTime createdAt;
  final String memberDisplayName;
  final String memberPhoneNumber;
  final String? memberProfileImageUrl;
  final String tripCountryCode;
  final String tripCountryName;
  final String? tripDestinationCity;
  final String tripStartDate;
  final String tripEndDate;

  const GuardianInvitation({
    required this.linkId,
    required this.tripId,
    required this.memberId,
    required this.createdAt,
    required this.memberDisplayName,
    required this.memberPhoneNumber,
    this.memberProfileImageUrl,
    required this.tripCountryCode,
    required this.tripCountryName,
    this.tripDestinationCity,
    required this.tripStartDate,
    required this.tripEndDate,
  });

  factory GuardianInvitation.fromJson(Map<String, dynamic> json) {
    return GuardianInvitation(
      linkId: json['link_id'] as String,
      tripId: json['trip_id'] as String,
      memberId: json['member_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      memberDisplayName: json['member_display_name'] as String? ?? '',
      memberPhoneNumber: json['member_phone_number'] as String? ?? '',
      memberProfileImageUrl: json['member_profile_image_url'] as String?,
      tripCountryCode: json['trip_country_code'] as String? ?? '',
      tripCountryName: json['trip_country_name'] as String? ?? '',
      tripDestinationCity: json['trip_destination_city'] as String?,
      tripStartDate: json['trip_start_date'] as String? ?? '',
      tripEndDate: json['trip_end_date'] as String? ?? '',
    );
  }
}
```

**Step 2: api_service.dart에 가디언 API 메서드 추가**

`ApiService` 클래스 내에 다음 메서드들을 추가:

```dart
// ─── Guardian Management ───────────────────────────────────────────────────

/// POST /trips/:tripId/guardians — 가디언 추가 요청
Future<Map<String, dynamic>?> addGuardian(String tripId, String guardianPhone) async {
  try {
    final response = await _dio.post(
      '/api/v1/trips/$tripId/guardians',
      data: {'guardian_phone': guardianPhone},
    );
    return response.data as Map<String, dynamic>?;
  } catch (e) {
    debugPrint('[ApiService] addGuardian error: $e');
    rethrow;
  }
}

/// PATCH /trips/:tripId/guardians/:linkId/respond — 가디언 수락/거절
Future<Map<String, dynamic>?> respondToGuardianInvitation(
  String tripId,
  String linkId,
  String action, // 'accepted' | 'rejected'
) async {
  try {
    final response = await _dio.patch(
      '/api/v1/trips/$tripId/guardians/$linkId/respond',
      data: {'action': action},
    );
    return response.data as Map<String, dynamic>?;
  } catch (e) {
    debugPrint('[ApiService] respondToGuardianInvitation error: $e');
    rethrow;
  }
}

/// DELETE /trips/:tripId/guardians/:linkId — 가디언 연결 해제
Future<void> removeGuardianLink(String tripId, String linkId) async {
  try {
    await _dio.delete('/api/v1/trips/$tripId/guardians/$linkId');
  } catch (e) {
    debugPrint('[ApiService] removeGuardianLink error: $e');
    rethrow;
  }
}

/// GET /trips/:tripId/guardians/me — 내 가디언 목록 (멤버 측)
Future<List<GuardianLink>> getMyGuardians(String tripId) async {
  try {
    final response = await _dio.get('/api/v1/trips/$tripId/guardians/me');
    final data = (response.data['data'] as List?) ?? [];
    return data.map((e) => GuardianLink.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    debugPrint('[ApiService] getMyGuardians error: $e');
    return [];
  }
}

/// GET /trips/:tripId/guardians/pending — 나에게 온 pending 초대 (가디언 측)
Future<List<GuardianInvitation>> getPendingGuardianInvitations(String tripId) async {
  try {
    final response = await _dio.get('/api/v1/trips/$tripId/guardians/pending');
    final data = (response.data['data'] as List?) ?? [];
    return data.map((e) => GuardianInvitation.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    debugPrint('[ApiService] getPendingGuardianInvitations error: $e');
    return [];
  }
}

/// GET /trips/:tripId/guardians/linked-members — 내가 연결된 멤버 목록 (가디언 측)
Future<List<LinkedMember>> getLinkedMembers(String tripId) async {
  try {
    final response = await _dio.get('/api/v1/trips/$tripId/guardians/linked-members');
    final data = (response.data['data'] as List?) ?? [];
    return data.map((e) => LinkedMember.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    debugPrint('[ApiService] getLinkedMembers error: $e');
    return [];
  }
}

// ─── Guardian View ─────────────────────────────────────────────────────────

/// GET /trips/:tripId/guardian-view/itinerary — 여행 일정 (가디언 전용)
Future<List<Map<String, dynamic>>> getGuardianItinerary(String tripId) async {
  try {
    final response = await _dio.get('/api/v1/trips/$tripId/guardian-view/itinerary');
    return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
  } catch (e) {
    debugPrint('[ApiService] getGuardianItinerary error: $e');
    return [];
  }
}

/// GET /trips/:tripId/guardian-view/places — 여행 장소 (가디언 전용)
Future<List<Map<String, dynamic>>> getGuardianPlaces(String tripId) async {
  try {
    final response = await _dio.get('/api/v1/trips/$tripId/guardian-view/places');
    return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
  } catch (e) {
    debugPrint('[ApiService] getGuardianPlaces error: $e');
    return [];
  }
}

// ─── Guardian Messages ─────────────────────────────────────────────────────

/// POST /trips/:tripId/guardian-messages — 메시지 전송
Future<String?> sendGuardianMessage(
  String tripId,
  String receiverId,
  String message,
  String messageType, // 'to_member' | 'to_captain'
) async {
  try {
    final response = await _dio.post(
      '/api/v1/trips/$tripId/guardian-messages',
      data: {
        'receiver_id': receiverId,
        'message': message,
        'message_type': messageType,
      },
    );
    return response.data['data']?['message_key'] as String?;
  } catch (e) {
    debugPrint('[ApiService] sendGuardianMessage error: $e');
    rethrow;
  }
}

/// GET /trips/:tripId/guardian-messages/:channelId — 채널 메시지 조회
Future<List<Map<String, dynamic>>> getGuardianChannelMessages(
  String tripId,
  String channelId,
) async {
  try {
    final response = await _dio.get(
      '/api/v1/trips/$tripId/guardian-messages/$channelId',
    );
    return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
  } catch (e) {
    debugPrint('[ApiService] getGuardianChannelMessages error: $e');
    return [];
  }
}

// ─── Trip Settings ─────────────────────────────────────────────────────────

/// PATCH /trips/:tripId/settings — 캡틴: 가디언 메시지 수신 ON/OFF
Future<bool> updateCaptainReceiveGuardianMsg(String tripId, bool enabled) async {
  try {
    final response = await _dio.patch(
      '/api/v1/trips/$tripId/settings',
      data: {'captain_receive_guardian_msg': enabled},
    );
    return response.data['data']?['captain_receive_guardian_msg'] as bool? ?? enabled;
  } catch (e) {
    debugPrint('[ApiService] updateCaptainReceiveGuardianMsg error: $e');
    rethrow;
  }
}

/// GET /trips/:tripId/settings (별도 엔드포인트 없음 → guardian 설정 상태는 메시지 전송 실패로 감지)
```

**Step 3: Flutter 컴파일 확인**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/models/guardian_link.dart lib/services/api_service.dart 2>&1 | tail -20
```

Expected: No issues found

**Step 4: Commit**

```bash
git add lib/models/guardian_link.dart lib/services/api_service.dart
git commit -m "feat: add GuardianLink models and guardian API service methods"
```

---

## Task 7: Flutter — 멤버 측 "내 가디언 관리" 화면

**파일:**
- Create: `safetrip-mobile/lib/screens/trip/screen_guardian_manage.dart`

**목적:** 멤버가 자신의 가디언을 추가/삭제하고 상태를 확인하는 화면.

**Step 1: screen_guardian_manage.dart 생성**

```dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/guardian_link.dart';

class ScreenGuardianManage extends StatefulWidget {
  final String tripId;

  const ScreenGuardianManage({super.key, required this.tripId});

  @override
  State<ScreenGuardianManage> createState() => _ScreenGuardianManageState();
}

class _ScreenGuardianManageState extends State<ScreenGuardianManage> {
  final _apiService = ApiService();
  List<GuardianLink> _guardians = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    setState(() => _isLoading = true);
    try {
      final guardians = await _apiService.getMyGuardians(widget.tripId);
      setState(() => _guardians = guardians);
    } catch (e) {
      debugPrint('loadGuardians error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addGuardian() async {
    // 3명 제한 체크
    final activeCount = _guardians.where((g) => g.status != 'rejected').length;
    if (activeCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최대 3명까지 가디언을 추가할 수 있습니다')),
      );
      return;
    }

    final phoneController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가디언 추가'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '전화번호 (예: +821012345678)',
            labelText: '가디언 전화번호',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('요청'),
          ),
        ],
      ),
    );

    if (confirmed != true || phoneController.text.isEmpty) return;

    try {
      await _apiService.addGuardian(widget.tripId, phoneController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가디언 요청이 전송되었습니다')),
      );
      _loadGuardians();
    } catch (e) {
      final msg = e.toString().contains('USER_NOT_FOUND') || e.toString().contains('404')
          ? '해당 번호로 가입된 사용자가 없습니다'
          : e.toString().contains('409')
              ? '이미 요청한 가디언입니다'
              : '요청 중 오류가 발생했습니다';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _removeGuardian(GuardianLink g) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가디언 해제'),
        content: Text('${g.displayName}을 가디언에서 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.removeGuardianLink(widget.tripId, g.linkId);
      _loadGuardians();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('해제 중 오류가 발생했습니다')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted': return '수락됨';
      case 'pending': return '대기중';
      case 'rejected': return '거절됨';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _guardians.where((g) => g.status != 'rejected').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 가디언 관리'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$activeCount / 3',
                style: TextStyle(
                  fontSize: 14,
                  color: activeCount >= 3 ? Colors.red : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _guardians.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        '등록된 가디언이 없습니다',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '전화번호로 가디언을 추가해보세요',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _guardians.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final g = _guardians[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: g.profileImageUrl != null
                              ? NetworkImage(g.profileImageUrl!)
                              : null,
                          child: g.profileImageUrl == null
                              ? Text(g.displayName.isNotEmpty
                                  ? g.displayName[0]
                                  : '?')
                              : null,
                        ),
                        title: Text(g.displayName.isNotEmpty ? g.displayName : g.phoneNumber),
                        subtitle: Text(g.phoneNumber),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(g.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _statusColor(g.status).withOpacity(0.5)),
                              ),
                              child: Text(
                                _statusLabel(g.status),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _statusColor(g.status),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: Colors.red,
                              onPressed: () => _removeGuardian(g),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: activeCount < 3
          ? FloatingActionButton.extended(
              onPressed: _addGuardian,
              icon: const Icon(Icons.person_add),
              label: const Text('가디언 추가'),
            )
          : null,
    );
  }
}
```

**Step 2: Flutter 분석**

```bash
cd /mnt/d/Project/15_SafeTrip_New/safetrip-mobile
flutter analyze lib/screens/trip/screen_guardian_manage.dart 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add lib/screens/trip/screen_guardian_manage.dart
git commit -m "feat: add guardian manage screen for members"
```

---

## Task 8: Flutter — 가디언 홈 화면 (초대 수락 + 연결된 멤버 탭)

**파일:**
- Create: `safetrip-mobile/lib/screens/trip/screen_guardian_home.dart`

**목적:** 가디언 사용자가 진입하는 메인 화면. 연결된 멤버 목록, 여행 일정/장소 탭, 메시지 버튼.

**Step 1: screen_guardian_home.dart 생성**

```dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/guardian_link.dart';
import 'screen_guardian_messages.dart';

class ScreenGuardianHome extends StatefulWidget {
  final String tripId;

  const ScreenGuardianHome({super.key, required this.tripId});

  @override
  State<ScreenGuardianHome> createState() => _ScreenGuardianHomeState();
}

class _ScreenGuardianHomeState extends State<ScreenGuardianHome>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;

  List<LinkedMember> _linkedMembers = [];
  List<GuardianInvitation> _pendingInvitations = [];
  List<Map<String, dynamic>> _itinerary = [];
  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _apiService.getLinkedMembers(widget.tripId),
        _apiService.getPendingGuardianInvitations(widget.tripId),
        _apiService.getGuardianItinerary(widget.tripId),
        _apiService.getGuardianPlaces(widget.tripId),
      ]);
      setState(() {
        _linkedMembers = results[0] as List<LinkedMember>;
        _pendingInvitations = results[1] as List<GuardianInvitation>;
        _itinerary = results[2] as List<Map<String, dynamic>>;
        _places = results[3] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      debugPrint('ScreenGuardianHome loadAll error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToInvitation(GuardianInvitation inv, String action) async {
    try {
      await _apiService.respondToGuardianInvitation(inv.tripId, inv.linkId, action);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'accepted' ? '초대를 수락했습니다' : '초대를 거절했습니다')),
      );
      _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리 중 오류가 발생했습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('가디언 뷰'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: '멤버'),
            Tab(icon: Icon(Icons.calendar_today), text: '일정'),
            Tab(icon: Icon(Icons.place), text: '장소'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 대기 중인 초대가 있으면 배너 표시
                if (_pendingInvitations.isNotEmpty)
                  _buildInvitationBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMembersTab(),
                      _buildItineraryTab(),
                      _buildPlacesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInvitationBanner() {
    final inv = _pendingInvitations.first;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${inv.memberDisplayName}님의 가디언 요청',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${inv.tripCountryName} · ${inv.tripStartDate} ~ ${inv.tripEndDate}',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respondToInvitation(inv, 'rejected'),
                  child: const Text('거절'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _respondToInvitation(inv, 'accepted'),
                  child: const Text('수락'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_linkedMembers.isEmpty) {
      return const Center(child: Text('연결된 멤버가 없습니다'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _linkedMembers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = _linkedMembers[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: member.profileImageUrl != null
                  ? NetworkImage(member.profileImageUrl!)
                  : null,
              child: member.profileImageUrl == null
                  ? Text(member.displayName.isNotEmpty ? member.displayName[0] : '?')
                  : null,
            ),
            title: Text(member.displayName.isNotEmpty ? member.displayName : member.phoneNumber),
            subtitle: Text(member.phoneNumber),
            trailing: IconButton(
              icon: const Icon(Icons.message_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ScreenGuardianMessages(
                      tripId: widget.tripId,
                      memberId: member.memberId,
                      memberName: member.displayName,
                      channelType: 'member',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildItineraryTab() {
    if (_itinerary.isEmpty) {
      return const Center(child: Text('등록된 일정이 없습니다'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _itinerary.length,
      itemBuilder: (context, index) {
        final item = _itinerary[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.event),
            title: Text(item['title'] as String? ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item['start_time'] != null)
                  Text(item['start_time'] as String, style: const TextStyle(fontSize: 12)),
                if (item['location_name'] != null)
                  Text(item['location_name'] as String,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlacesTab() {
    if (_places.isEmpty) {
      return const Center(child: Text('등록된 장소가 없습니다'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _places.length,
      itemBuilder: (context, index) {
        final place = _places[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.place, color: Colors.teal),
            title: Text(place['name'] as String? ?? ''),
            subtitle: Text(
              '${place['center_latitude']?.toStringAsFixed(4)}, ${place['center_longitude']?.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}
```

**Step 2: Flutter 분석**

```bash
flutter analyze lib/screens/trip/screen_guardian_home.dart 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add lib/screens/trip/screen_guardian_home.dart
git commit -m "feat: add guardian home screen with members/itinerary/places tabs"
```

---

## Task 9: Flutter — 가디언 메시지 화면

**파일:**
- Create: `safetrip-mobile/lib/screens/trip/screen_guardian_messages.dart`

**Step 1: screen_guardian_messages.dart 생성**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class ScreenGuardianMessages extends StatefulWidget {
  final String tripId;
  final String memberId; // 메시지 상대방 ID (to_member) 또는 캡틴 ID (to_captain)
  final String memberName;
  final String channelType; // 'member' | 'captain'

  const ScreenGuardianMessages({
    super.key,
    required this.tripId,
    required this.memberId,
    required this.memberName,
    required this.channelType,
  });

  @override
  State<ScreenGuardianMessages> createState() => _ScreenGuardianMessagesState();
}

class _ScreenGuardianMessagesState extends State<ScreenGuardianMessages> {
  final _apiService = ApiService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  late String _channelId;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _channelId = _buildChannelId();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _buildChannelId() {
    if (widget.channelType == 'captain') {
      return 'captain_$_currentUserId';
    }
    // member channel: 두 ID 정렬 후 합침
    final ids = [_currentUserId, widget.memberId]..sort();
    return 'member_${ids[0]}_${ids[1]}';
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _apiService.getGuardianChannelMessages(
        widget.tripId,
        _channelId,
      );
      setState(() => _messages = messages);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      debugPrint('loadMessages error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _apiService.sendGuardianMessage(
        widget.tripId,
        widget.memberId,
        text,
        widget.channelType == 'captain' ? 'to_captain' : 'to_member',
      );
      _messageController.clear();
      _loadMessages();
    } catch (e) {
      final msg = e.toString().contains('403')
          ? '캡틴이 메시지 수신을 비활성화했습니다'
          : '메시지 전송 실패';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channelType == 'captain'
            ? '캡틴에게 메시지'
            : widget.memberName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('메시지가 없습니다'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['sender_id'] == _currentUserId;
                          return _buildMessageBubble(msg, isMe);
                        },
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.teal : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg['message'] as String? ?? '',
          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Flutter 분석**

```bash
flutter analyze lib/screens/trip/screen_guardian_messages.dart 2>&1 | tail -20
```

**Step 3: Commit**

```bash
git add lib/screens/trip/screen_guardian_messages.dart
git commit -m "feat: add guardian messages chat screen"
```

---

## Task 10: Flutter — 캡틴 설정 화면에 가디언 메시지 수신 토글 추가

**파일:**
- Modify: `safetrip-mobile/lib/screens/settings/screen_settings.dart`

**Step 1: 현재 파일 읽기**

`screen_settings.dart`를 읽고, 캡틴 전용 설정 섹션을 파악한다.

**Step 2: captain_receive_guardian_msg 토글 추가**

`screen_settings.dart`의 State 클래스에 아래를 추가:

```dart
// State 클래스에 추가할 변수
bool _captainReceiveGuardianMsg = true;

// initState 또는 _loadSettings에 추가:
// 현재 여행 ID를 알고 있다고 가정 (AppCache.tripId 사용)
// tripId가 있고, 현재 유저가 캡틴인 경우 설정 로드
```

> **주의:** `screen_settings.dart`의 실제 구조를 먼저 읽은 후 적절한 위치에 삽입할 것.
> 캡틴인지 확인 후 섹션을 조건부로 표시해야 한다.

**삽입할 UI 코드 (캡틴 전용 섹션):**

```dart
// 기존 ListTile들 사이에 삽입 (캡틴인 경우에만 표시)
if (_isCaptain) ...[
  const Divider(),
  Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Text(
      '가디언 설정',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
      ),
    ),
  ),
  SwitchListTile(
    title: const Text('가디언 메시지 수신'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('OFF 시 모든 가디언의 메시지가 차단됩니다'),
        if (!_captainReceiveGuardianMsg)
          const Text(
            '현재 가디언 메시지가 차단 중입니다',
            style: TextStyle(color: Colors.red, fontSize: 11),
          ),
      ],
    ),
    value: _captainReceiveGuardianMsg,
    onChanged: _tripId != null
        ? (value) async {
            try {
              await ApiService().updateCaptainReceiveGuardianMsg(_tripId!, value);
              setState(() => _captainReceiveGuardianMsg = value);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('설정 변경 중 오류가 발생했습니다')),
              );
            }
          }
        : null,
  ),
],
```

**Step 3: Flutter 분석**

```bash
flutter analyze lib/screens/settings/screen_settings.dart 2>&1 | tail -20
```

**Step 4: Commit**

```bash
git add lib/screens/settings/screen_settings.dart
git commit -m "feat: add captain guardian message receive toggle in settings"
```

---

## 완료 검증 체크리스트

### 백엔드
- [ ] TypeScript 컴파일 에러 없음: `npx tsc --noEmit`
- [ ] 서버 정상 기동: `curl http://localhost:3001/health`
- [ ] 인증 없이 guardian 엔드포인트 → 401 반환
- [ ] 7개 새 엔드포인트 모두 라우트 등록 확인

### Flutter
- [ ] `flutter analyze` 에러 없음
- [ ] `GuardianLink.fromJson` 정상 파싱
- [ ] `ApiService` 가디언 메서드 정상 호출 (빌드 확인)
- [ ] 3개 새 화면 컴파일 성공

---

## Obsidian 기록

작업 완료 후 `SafeTrip/개발일지/2026-02-27_개발사항.md` 노트 생성하여 작업 내역 기록.
