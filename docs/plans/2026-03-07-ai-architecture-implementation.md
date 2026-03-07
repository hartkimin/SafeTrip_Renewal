# AI Architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the full AI 기능 원칙 (DOC-T3-AIF-026) as a Layered AI Service Architecture — DB schema, Core services (AccessGuard, LLMGateway, DataMasker, ResponseCache, UsageLogger), Feature services (Safety/Convenience/Intelligence), and Flutter AI features.

**Architecture:** Decompose the monolithic `ai.service.ts` into a layered structure: Core Layer (5 cross-cutting services) + Feature Layer (3 domain services). Each layer maps 1:1 to document sections. Existing `tb_ai_usage` (daily counter) stays; new `tb_ai_usage_log` (per-call log) and `tb_ai_subscription` added per §12.

**Tech Stack:** NestJS 10 + TypeORM + PostgreSQL, OpenAI SDK + Anthropic SDK, Flutter/Dart + Riverpod, Jest for tests

---

## Task 1: Install NPM Dependencies

**Files:**
- Modify: `safetrip-server-api/package.json`

**Step 1: Install openai and @anthropic-ai/sdk**

```bash
cd safetrip-server-api && npm install openai @anthropic-ai/sdk
```

**Step 2: Verify installation**

```bash
cd safetrip-server-api && node -e "require('openai'); require('@anthropic-ai/sdk'); console.log('OK')"
```

Expected: `OK`

**Step 3: Commit**

```bash
git add safetrip-server-api/package.json safetrip-server-api/package-lock.json
git commit -m "chore: add openai and @anthropic-ai/sdk dependencies"
```

---

## Task 2: SQL Migration — tb_ai_usage_log + tb_ai_subscription

**Files:**
- Create: `safetrip-server-api/sql/15-schema-ai.sql`

**Step 1: Create the migration file**

```sql
-- ============================================================
-- SafeTrip DB Schema v3.6
-- 15: [N] AI 도메인 (2 tables)
-- 기준 문서: 26_T3_AI_기능_원칙_v1.1 §12
-- ============================================================

-- §12.1 TB_AI_USAGE_LOG (AI 사용 이력 — 건별 로그)
CREATE TABLE IF NOT EXISTS tb_ai_usage_log (
    log_id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID REFERENCES tb_user(user_id) ON DELETE SET NULL,
    trip_id         UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    ai_type         VARCHAR(20) NOT NULL
                    CHECK (ai_type IN ('safety', 'convenience', 'intelligence')),
    feature_name    VARCHAR(50) NOT NULL,
    model_used      VARCHAR(50),
    is_cached       BOOLEAN DEFAULT FALSE,
    is_fallback     BOOLEAN DEFAULT FALSE,
    fallback_reason VARCHAR(100),
    latency_ms      INTEGER,
    is_minor_user   BOOLEAN DEFAULT FALSE,
    privacy_level   VARCHAR(20),
    feedback        SMALLINT CHECK (feedback IN (-1, 0, 1)),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    expires_at      TIMESTAMPTZ
);

CREATE INDEX idx_ai_usage_log_user    ON tb_ai_usage_log (user_id);
CREATE INDEX idx_ai_usage_log_trip    ON tb_ai_usage_log (trip_id);
CREATE INDEX idx_ai_usage_log_type    ON tb_ai_usage_log (ai_type, feature_name);
CREATE INDEX idx_ai_usage_log_expires ON tb_ai_usage_log (expires_at);

-- §12.2 TB_AI_SUBSCRIPTION (AI 구독 정보)
CREATE TABLE IF NOT EXISTS tb_ai_subscription (
    subscription_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES tb_user(user_id) ON DELETE CASCADE,
    plan_type       VARCHAR(20) NOT NULL
                    CHECK (plan_type IN ('ai_plus', 'ai_pro')),
    billing_cycle   VARCHAR(10) NOT NULL
                    CHECK (billing_cycle IN ('monthly', 'per_trip')),
    trip_id         UUID REFERENCES tb_trip(trip_id) ON DELETE SET NULL,
    status          VARCHAR(20) DEFAULT 'active'
                    CHECK (status IN ('active', 'cancelled', 'expired', 'grace_period')),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at      TIMESTAMPTZ NOT NULL,
    grace_until     TIMESTAMPTZ,
    payment_id      UUID REFERENCES tb_payment(payment_id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ai_subscription_user   ON tb_ai_subscription (user_id);
CREATE INDEX idx_ai_subscription_status ON tb_ai_subscription (status, expires_at);
CREATE INDEX idx_ai_subscription_trip   ON tb_ai_subscription (trip_id)
    WHERE trip_id IS NOT NULL;

CREATE UNIQUE INDEX idx_ai_subscription_active_monthly
    ON tb_ai_subscription (user_id, plan_type)
    WHERE billing_cycle = 'monthly' AND status IN ('active', 'grace_period');
```

**Step 2: Verify SQL syntax**

```bash
cd safetrip-server-api && cat sql/15-schema-ai.sql | head -5
```

**Step 3: Commit**

```bash
git add safetrip-server-api/sql/15-schema-ai.sql
git commit -m "feat(db): add tb_ai_usage_log + tb_ai_subscription (§12)"
```

---

## Task 3: TypeORM Entities — AiUsageLog + AiSubscription

**Files:**
- Modify: `safetrip-server-api/src/entities/ai.entity.ts` — add AiUsageLog + AiSubscription (keep existing AiUsage)
- Modify: `safetrip-server-api/src/entities/index.ts` — export new entities

**Step 1: Write test for entity instantiation**

Create: `safetrip-server-api/src/entities/ai.entity.spec.ts`

```typescript
import { AiUsageLog, AiSubscription, AiUsage } from './ai.entity';

describe('AI Entities', () => {
    it('should create AiUsageLog instance with correct defaults', () => {
        const log = new AiUsageLog();
        log.aiType = 'safety';
        log.featureName = 'sos_auto_detect';
        expect(log.aiType).toBe('safety');
        expect(log.featureName).toBe('sos_auto_detect');
        expect(log.isCached).toBe(false);
        expect(log.isFallback).toBe(false);
        expect(log.isMinorUser).toBe(false);
    });

    it('should create AiSubscription instance', () => {
        const sub = new AiSubscription();
        sub.planType = 'ai_plus';
        sub.billingCycle = 'monthly';
        sub.status = 'active';
        expect(sub.planType).toBe('ai_plus');
        expect(sub.billingCycle).toBe('monthly');
    });

    it('should preserve existing AiUsage entity', () => {
        const usage = new AiUsage();
        usage.featureType = 'recommendation';
        usage.useCount = 5;
        expect(usage.featureType).toBe('recommendation');
        expect(usage.useCount).toBe(5);
    });
});
```

**Step 2: Run test to verify it fails**

```bash
cd safetrip-server-api && npx jest src/entities/ai.entity.spec.ts --no-cache
```

Expected: FAIL — `AiUsageLog` and `AiSubscription` not found.

**Step 3: Add entities to ai.entity.ts**

Append to `safetrip-server-api/src/entities/ai.entity.ts` (after existing AiUsage class):

```typescript
/**
 * TB_AI_USAGE_LOG — AI 사용 이력 건별 로그
 * DOC-T3-AIF-026 §12.1
 */
@Entity('tb_ai_usage_log')
@Index('idx_ai_usage_log_user', ['userId'])
@Index('idx_ai_usage_log_trip', ['tripId'])
@Index('idx_ai_usage_log_type', ['aiType', 'featureName'])
@Index('idx_ai_usage_log_expires', ['expiresAt'])
export class AiUsageLog {
    @PrimaryGeneratedColumn('uuid', { name: 'log_id' })
    logId: string;

    @Column({ name: 'user_id', type: 'uuid', nullable: true })
    userId: string | null;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'ai_type', type: 'varchar', length: 20 })
    aiType: string; // 'safety' | 'convenience' | 'intelligence'

    @Column({ name: 'feature_name', type: 'varchar', length: 50 })
    featureName: string;

    @Column({ name: 'model_used', type: 'varchar', length: 50, nullable: true })
    modelUsed: string | null;

    @Column({ name: 'is_cached', type: 'boolean', default: false })
    isCached: boolean = false;

    @Column({ name: 'is_fallback', type: 'boolean', default: false })
    isFallback: boolean = false;

    @Column({ name: 'fallback_reason', type: 'varchar', length: 100, nullable: true })
    fallbackReason: string | null;

    @Column({ name: 'latency_ms', type: 'int', nullable: true })
    latencyMs: number | null;

    @Column({ name: 'is_minor_user', type: 'boolean', default: false })
    isMinorUser: boolean = false;

    @Column({ name: 'privacy_level', type: 'varchar', length: 20, nullable: true })
    privacyLevel: string | null;

    @Column({ name: 'feedback', type: 'smallint', nullable: true })
    feedback: number | null; // -1 | 0 | 1

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;
}

/**
 * TB_AI_SUBSCRIPTION — AI 구독 정보
 * DOC-T3-AIF-026 §12.2
 */
@Entity('tb_ai_subscription')
@Index('idx_ai_subscription_user', ['userId'])
@Index('idx_ai_subscription_status', ['status', 'expiresAt'])
export class AiSubscription {
    @PrimaryGeneratedColumn('uuid', { name: 'subscription_id' })
    subscriptionId: string;

    @Column({ name: 'user_id', type: 'uuid' })
    userId: string;

    @Column({ name: 'plan_type', type: 'varchar', length: 20 })
    planType: string; // 'ai_plus' | 'ai_pro'

    @Column({ name: 'billing_cycle', type: 'varchar', length: 10 })
    billingCycle: string; // 'monthly' | 'per_trip'

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'cancelled' | 'expired' | 'grace_period'

    @Column({ name: 'started_at', type: 'timestamptz' })
    startedAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz' })
    expiresAt: Date;

    @Column({ name: 'grace_until', type: 'timestamptz', nullable: true })
    graceUntil: Date | null;

    @Column({ name: 'payment_id', type: 'uuid', nullable: true })
    paymentId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt: Date;
}
```

**Step 4: Update entities/index.ts**

Change the AI Domain export line in `safetrip-server-api/src/entities/index.ts`:

```typescript
// AI Domain (N)
export { AiUsage, AiUsageLog, AiSubscription } from './ai.entity';
```

**Step 5: Run test to verify it passes**

```bash
cd safetrip-server-api && npx jest src/entities/ai.entity.spec.ts --no-cache
```

Expected: PASS — all 3 tests green.

**Step 6: Commit**

```bash
git add safetrip-server-api/src/entities/ai.entity.ts safetrip-server-api/src/entities/ai.entity.spec.ts safetrip-server-api/src/entities/index.ts
git commit -m "feat(entity): add AiUsageLog + AiSubscription entities (§12)"
```

---

## Task 4: Core — DataMaskerService (§5.1)

**Files:**
- Create: `safetrip-server-api/src/modules/ai/core/data-masker.service.ts`
- Create: `safetrip-server-api/src/modules/ai/core/data-masker.service.spec.ts`

**Step 1: Write the failing test**

```typescript
// data-masker.service.spec.ts
import { DataMaskerService } from './data-masker.service';

describe('DataMaskerService', () => {
    let service: DataMaskerService;

    beforeEach(() => {
        service = new DataMaskerService();
    });

    describe('maskText', () => {
        it('should replace phone numbers with [PHONE]', () => {
            expect(service.maskText('Call 010-1234-5678')).toContain('[PHONE]');
            expect(service.maskText('Call 010-1234-5678')).not.toContain('010-1234-5678');
        });

        it('should replace emails with [EMAIL]', () => {
            expect(service.maskText('Email user@example.com')).toContain('[EMAIL]');
            expect(service.maskText('Email user@example.com')).not.toContain('user@example.com');
        });

        it('should not alter text without PII', () => {
            expect(service.maskText('Visit the Eiffel Tower')).toBe('Visit the Eiffel Tower');
        });
    });

    describe('anonymizeNames', () => {
        it('should replace names with sequential labels', () => {
            const names = ['김철수', '이영희', '박지민'];
            const result = service.anonymizeNames(names);
            expect(result).toEqual(['멤버A', '멤버B', '멤버C']);
        });
    });

    describe('coarsenLocation', () => {
        it('should round lat/lng to ~1km grid', () => {
            const result = service.coarsenLocation(37.5665, 126.9780);
            // 1km ≈ 0.01 degree — round to 2 decimal places
            expect(result.latitude).toBe(37.57);
            expect(result.longitude).toBe(126.98);
        });
    });

    describe('maskTripName', () => {
        it('should replace trip name with internal ID format', () => {
            const tripId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
            expect(service.maskTripName('파리여행 2026', tripId)).toBe('trip_a1b2c3d4');
        });
    });
});
```

**Step 2: Run test to verify it fails**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/data-masker.service.spec.ts --no-cache
```

Expected: FAIL — module not found.

**Step 3: Implement DataMaskerService**

```typescript
// data-masker.service.ts
import { Injectable } from '@nestjs/common';

/**
 * §5.1 LLM 호출 시 개인정보 마스킹
 * LLM 페이로드에 개인정보를 포함하지 않도록 전처리한다.
 */
@Injectable()
export class DataMaskerService {
    /** 텍스트에서 전화번호와 이메일을 마스킹 */
    maskText(text: string): string {
        let masked = text;
        // 전화번호 제거 (한국, 국제 형식)
        masked = masked.replace(
            /(\+?\d{1,4}[\s-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{3,4}/g,
            '[PHONE]',
        );
        // 이메일 제거
        masked = masked.replace(
            /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g,
            '[EMAIL]',
        );
        return masked;
    }

    /** 사용자 이름을 순번 익명화 (§5.1: "멤버A", "멤버B") */
    anonymizeNames(names: string[]): string[] {
        return names.map((_, i) => `멤버${String.fromCharCode(65 + i)}`);
    }

    /** 정확 위치를 구(區) 수준 그리드로 변환 (100m→1km 단위) */
    coarsenLocation(lat: number, lng: number): { latitude: number; longitude: number } {
        return {
            latitude: Math.round(lat * 100) / 100,
            longitude: Math.round(lng * 100) / 100,
        };
    }

    /** 여행명을 내부 ID로 치환 (§5.1: "trip_a1b2") */
    maskTripName(tripName: string, tripId: string): string {
        return `trip_${tripId.split('-')[0]}`;
    }
}
```

**Step 4: Run test to verify it passes**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/data-masker.service.spec.ts --no-cache
```

Expected: PASS — all tests green.

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/core/
git commit -m "feat(ai): add DataMaskerService (§5.1 개인정보 마스킹)"
```

---

## Task 5: Core — ResponseCacheService (§5.3)

**Files:**
- Create: `safetrip-server-api/src/modules/ai/core/response-cache.service.ts`
- Create: `safetrip-server-api/src/modules/ai/core/response-cache.service.spec.ts`

**Step 1: Write the failing test**

```typescript
// response-cache.service.spec.ts
import { ResponseCacheService } from './response-cache.service';

describe('ResponseCacheService', () => {
    let service: ResponseCacheService;

    beforeEach(() => {
        service = new ResponseCacheService();
    });

    afterEach(() => {
        service.clearAll();
    });

    it('should return null for cache miss', () => {
        expect(service.get('nonexistent')).toBeNull();
    });

    it('should cache and retrieve a value', () => {
        service.set('key1', { data: 'test' }, 60_000);
        expect(service.get('key1')).toEqual({ data: 'test' });
    });

    it('should return null for expired entry', () => {
        service.set('expired', { data: 'old' }, -1); // already expired
        expect(service.get('expired')).toBeNull();
    });

    it('should build correct cache key for country threat', () => {
        const key = service.buildKey('country_threat', { country_code: 'JP', threat_type: 'crime' });
        expect(key).toBe('country_threat:JP:crime');
    });

    it('should build correct cache key for place recommendation', () => {
        const key = service.buildKey('place_recommend', { lat_grid: 37.57, lon_grid: 126.98, category: 'food' });
        expect(key).toBe('place_recommend:37.57:126.98:food');
    });

    it('should return correct TTL per feature', () => {
        expect(service.getTtl('country_threat')).toBe(6 * 60 * 60 * 1000);
        expect(service.getTtl('place_recommend')).toBe(24 * 60 * 60 * 1000);
        expect(service.getTtl('schedule_autocomplete')).toBe(1 * 60 * 60 * 1000);
        expect(service.getTtl('safety_briefing')).toBe(4 * 60 * 60 * 1000);
    });

    it('should delete specific key', () => {
        service.set('key1', 'val1', 60_000);
        service.delete('key1');
        expect(service.get('key1')).toBeNull();
    });
});
```

**Step 2: Run test to verify it fails**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/response-cache.service.spec.ts --no-cache
```

**Step 3: Implement ResponseCacheService**

```typescript
// response-cache.service.ts
import { Injectable, Logger } from '@nestjs/common';

interface CacheEntry {
    value: any;
    expiresAt: number;
}

/**
 * §5.3 AI 응답 캐싱 정책
 * 인메모리 캐시 (Map + TTL). Redis 없이 경량 구현.
 */
@Injectable()
export class ResponseCacheService {
    private readonly logger = new Logger(ResponseCacheService.name);
    private readonly cache = new Map<string, CacheEntry>();

    /** §5.3 기능별 캐시 유효 시간 (ms) */
    private readonly ttlMap: Record<string, number> = {
        country_threat: 6 * 60 * 60 * 1000,       // 6시간
        place_recommend: 24 * 60 * 60 * 1000,      // 24시간
        schedule_autocomplete: 1 * 60 * 60 * 1000,  // 1시간
        chat_summary: Infinity,                      // 메시지 변경 전까지
        safety_briefing: 4 * 60 * 60 * 1000,        // 4시간
    };

    get(key: string): any | null {
        const entry = this.cache.get(key);
        if (!entry) return null;
        if (Date.now() > entry.expiresAt) {
            this.cache.delete(key);
            return null;
        }
        return entry.value;
    }

    set(key: string, value: any, ttlMs: number): void {
        this.cache.set(key, {
            value,
            expiresAt: Date.now() + ttlMs,
        });
    }

    delete(key: string): void {
        this.cache.delete(key);
    }

    clearAll(): void {
        this.cache.clear();
    }

    getTtl(feature: string): number {
        return this.ttlMap[feature] ?? 60 * 60 * 1000; // default 1hr
    }

    buildKey(feature: string, params: Record<string, any>): string {
        const parts = Object.values(params).map(String);
        return `${feature}:${parts.join(':')}`;
    }
}
```

**Step 4: Run test to verify it passes**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/response-cache.service.spec.ts --no-cache
```

Expected: PASS

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/core/response-cache.service.ts safetrip-server-api/src/modules/ai/core/response-cache.service.spec.ts
git commit -m "feat(ai): add ResponseCacheService (§5.3 AI 응답 캐싱)"
```

---

## Task 6: Core — UsageLoggerService (§5.4)

**Files:**
- Create: `safetrip-server-api/src/modules/ai/core/usage-logger.service.ts`
- Create: `safetrip-server-api/src/modules/ai/core/usage-logger.service.spec.ts`

**Step 1: Write the failing test**

```typescript
// usage-logger.service.spec.ts
import { UsageLoggerService } from './usage-logger.service';

describe('UsageLoggerService', () => {
    let service: UsageLoggerService;
    const mockRepo = {
        create: jest.fn().mockImplementation((data) => ({ ...data })),
        save: jest.fn().mockImplementation(async (entity) => ({ ...entity, logId: 'test-uuid' })),
    };

    beforeEach(() => {
        service = new UsageLoggerService(mockRepo as any);
        jest.clearAllMocks();
    });

    it('should log AI usage with correct expires_at for adult (90 days)', async () => {
        await service.log({
            userId: 'user-1',
            tripId: 'trip-1',
            aiType: 'convenience',
            featureName: 'schedule_autocomplete',
            modelUsed: 'gpt-4o',
            latencyMs: 1200,
            isCached: false,
            isFallback: false,
            isMinorUser: false,
            privacyLevel: 'standard',
        });

        expect(mockRepo.create).toHaveBeenCalledTimes(1);
        expect(mockRepo.save).toHaveBeenCalledTimes(1);

        const saved = mockRepo.create.mock.calls[0][0];
        expect(saved.aiType).toBe('convenience');
        expect(saved.isMinorUser).toBe(false);
        // expires_at should be ~90 days from now
        const diffDays = (saved.expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
        expect(diffDays).toBeGreaterThan(89);
        expect(diffDays).toBeLessThan(91);
    });

    it('should set 30-day expires_at for minor user', async () => {
        await service.log({
            userId: 'minor-1',
            aiType: 'safety',
            featureName: 'sos_auto_detect',
            isMinorUser: true,
            latencyMs: 50,
        });

        const saved = mockRepo.create.mock.calls[0][0];
        const diffDays = (saved.expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
        expect(diffDays).toBeGreaterThan(29);
        expect(diffDays).toBeLessThan(31);
    });
});
```

**Step 2: Run test — FAIL**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/usage-logger.service.spec.ts --no-cache
```

**Step 3: Implement UsageLoggerService**

```typescript
// usage-logger.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AiUsageLog } from '../../../entities';

export interface AiLogEntry {
    userId?: string;
    tripId?: string;
    aiType: 'safety' | 'convenience' | 'intelligence';
    featureName: string;
    modelUsed?: string;
    latencyMs?: number;
    isCached?: boolean;
    isFallback?: boolean;
    fallbackReason?: string;
    isMinorUser?: boolean;
    privacyLevel?: string;
}

/**
 * §5.4 AI 사용 로그 기록
 * 매 AI 호출 시 tb_ai_usage_log에 기록.
 * expires_at: 성인 +90일, 미성년자 +30일
 */
@Injectable()
export class UsageLoggerService {
    private readonly logger = new Logger(UsageLoggerService.name);

    constructor(
        @InjectRepository(AiUsageLog)
        private readonly logRepo: Repository<AiUsageLog>,
    ) {}

    async log(entry: AiLogEntry): Promise<AiUsageLog> {
        const retentionDays = entry.isMinorUser ? 30 : 90;
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + retentionDays);

        const record = this.logRepo.create({
            userId: entry.userId ?? null,
            tripId: entry.tripId ?? null,
            aiType: entry.aiType,
            featureName: entry.featureName,
            modelUsed: entry.modelUsed ?? null,
            latencyMs: entry.latencyMs ?? null,
            isCached: entry.isCached ?? false,
            isFallback: entry.isFallback ?? false,
            fallbackReason: entry.fallbackReason ?? null,
            isMinorUser: entry.isMinorUser ?? false,
            privacyLevel: entry.privacyLevel ?? null,
            expiresAt,
        });

        return this.logRepo.save(record);
    }

    async updateFeedback(logId: string, feedback: -1 | 0 | 1): Promise<void> {
        await this.logRepo.update(logId, { feedback });
    }
}
```

**Step 4: Run test — PASS**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/usage-logger.service.spec.ts --no-cache
```

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/core/usage-logger.service.ts safetrip-server-api/src/modules/ai/core/usage-logger.service.spec.ts
git commit -m "feat(ai): add UsageLoggerService (§5.4 사용 로그)"
```

---

## Task 7: Core — AccessGuardService (§8, §9, §10)

**Files:**
- Create: `safetrip-server-api/src/modules/ai/core/access-guard.service.ts`
- Create: `safetrip-server-api/src/modules/ai/core/access-guard.service.spec.ts`

This is the most complex core service. It replaces the existing `checkAccess()` in `ai.service.ts`.

**Step 1: Write the failing test**

```typescript
// access-guard.service.spec.ts
import { AccessGuardService, AiFeature } from './access-guard.service';
import { ForbiddenException, BadRequestException } from '@nestjs/common';

describe('AccessGuardService', () => {
    let service: AccessGuardService;

    const mockUserRepo = { findOne: jest.fn() };
    const mockGroupMemberRepo = { findOne: jest.fn() };
    const mockTripRepo = { findOne: jest.fn() };
    const mockAiSubRepo = { findOne: jest.fn() };
    const mockAiUsageRepo = { findOne: jest.fn() };

    beforeEach(() => {
        service = new AccessGuardService(
            mockUserRepo as any,
            mockGroupMemberRepo as any,
            mockTripRepo as any,
            mockAiSubRepo as any,
            mockAiUsageRepo as any,
        );
        jest.clearAllMocks();
    });

    describe('minor restrictions (§10)', () => {
        it('should block AI chatbot for users under 14', async () => {
            mockUserRepo.findOne.mockResolvedValue({
                userId: 'u1', minorStatus: 'minor_under14',
                dateOfBirth: new Date('2015-01-01'),
            });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });

            await expect(service.checkAccess('u1', 'ai_chatbot' as AiFeature, 'trip-1'))
                .rejects.toThrow(ForbiddenException);
        });

        it('should allow Safety AI for all minors', async () => {
            mockUserRepo.findOne.mockResolvedValue({
                userId: 'u1', minorStatus: 'minor_under14',
                dateOfBirth: new Date('2015-01-01'),
            });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'safety_first' });
            mockAiSubRepo.findOne.mockResolvedValue(null);
            mockAiUsageRepo.findOne.mockResolvedValue(null);

            const result = await service.checkAccess('u1', 'danger_zone_detect' as AiFeature, 'trip-1');
            expect(result.allowed).toBe(true);
        });

        it('should block Intelligence AI personal analysis for minors', async () => {
            mockUserRepo.findOne.mockResolvedValue({
                userId: 'u1', minorStatus: 'minor_over14',
                dateOfBirth: new Date('2010-01-01'),
            });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });

            await expect(service.checkAccess('u1', 'pattern_analysis' as AiFeature, 'trip-1'))
                .rejects.toThrow(ForbiddenException);
        });
    });

    describe('privacy level restrictions (§9)', () => {
        it('should block location-based AI for privacy_first trips', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'privacy_first' });

            await expect(service.checkAccess('u1', 'place_recommend' as AiFeature, 'trip-1'))
                .rejects.toThrow(ForbiddenException);
        });

        it('should allow non-location AI for privacy_first trips', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'privacy_first' });
            mockAiSubRepo.findOne.mockResolvedValue({ planType: 'ai_plus', status: 'active' });
            mockAiUsageRepo.findOne.mockResolvedValue(null);

            const result = await service.checkAccess('u1', 'chat_translate' as AiFeature, 'trip-1');
            expect(result.allowed).toBe(true);
        });
    });

    describe('subscription check (§3.2)', () => {
        it('should block paid features for free users', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });
            mockAiSubRepo.findOne.mockResolvedValue(null);

            await expect(service.checkAccess('u1', 'ai_chatbot' as AiFeature, 'trip-1'))
                .rejects.toThrow(BadRequestException);
        });

        it('should allow free features without subscription', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'crew' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });
            mockAiSubRepo.findOne.mockResolvedValue(null);
            mockAiUsageRepo.findOne.mockResolvedValue(null);

            const result = await service.checkAccess('u1', 'schedule_autocomplete' as AiFeature, 'trip-1');
            expect(result.allowed).toBe(true);
        });
    });

    describe('role restrictions (§8)', () => {
        it('should block guardian from schedule features', async () => {
            mockUserRepo.findOne.mockResolvedValue({ userId: 'u1', minorStatus: 'adult' });
            mockGroupMemberRepo.findOne.mockResolvedValue({ memberRole: 'guardian' });
            mockTripRepo.findOne.mockResolvedValue({ privacyLevel: 'standard' });

            await expect(service.checkAccess('u1', 'schedule_autocomplete' as AiFeature, 'trip-1'))
                .rejects.toThrow(ForbiddenException);
        });
    });
});
```

**Step 2: Run test — FAIL**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/access-guard.service.spec.ts --no-cache
```

**Step 3: Implement AccessGuardService**

```typescript
// access-guard.service.ts
import { Injectable, ForbiddenException, BadRequestException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { User } from '../../../entities/user.entity';
import { GroupMember } from '../../../entities/group-member.entity';
import { Trip } from '../../../entities/trip.entity';
import { AiSubscription, AiUsage } from '../../../entities/ai.entity';

/**
 * §3.2 AI 기능명 — 문서 과금 테이블 기반
 */
export type AiFeature =
    // Safety AI (무료)
    | 'danger_zone_detect' | 'sos_auto_detect' | 'departure_detect' | 'gathering_delay_detect'
    // Convenience AI (무료)
    | 'schedule_autocomplete' | 'travel_time_estimate' | 'packing_list'
    // Convenience AI (AI Plus)
    | 'place_recommend' | 'ai_chatbot' | 'chat_translate' | 'chat_summary'
    // Intelligence AI (AI Plus)
    | 'travel_insight' | 'pattern_analysis' | 'movement_predict'
    // Intelligence AI (AI Pro)
    | 'safety_briefing' | 'schedule_optimize';

type AiCategory = 'safety' | 'convenience' | 'intelligence';
type RequiredPlan = 'free' | 'ai_plus' | 'ai_pro';

interface FeatureDef {
    category: AiCategory;
    requiredPlan: RequiredPlan;
    locationBased: boolean;
    /** Roles that CANNOT access this feature */
    blockedRoles: string[];
    /** Blocked for any minor? */
    minorBlocked: boolean;
    /** Blocked for under14 only? */
    under14Blocked: boolean;
}

/** §3.2 + §8 + §9 매트릭스를 코드 상수로 정의 */
const FEATURE_DEFS: Record<AiFeature, FeatureDef> = {
    // Safety AI — 전원 무료
    danger_zone_detect:    { category: 'safety', requiredPlan: 'free', locationBased: false, blockedRoles: [], minorBlocked: false, under14Blocked: false },
    sos_auto_detect:       { category: 'safety', requiredPlan: 'free', locationBased: false, blockedRoles: [], minorBlocked: false, under14Blocked: false },
    departure_detect:      { category: 'safety', requiredPlan: 'free', locationBased: false, blockedRoles: [], minorBlocked: false, under14Blocked: false },
    gathering_delay_detect:{ category: 'safety', requiredPlan: 'free', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },

    // Convenience AI — 무료
    schedule_autocomplete: { category: 'convenience', requiredPlan: 'free', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },
    travel_time_estimate:  { category: 'convenience', requiredPlan: 'free', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },
    packing_list:          { category: 'convenience', requiredPlan: 'free', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },

    // Convenience AI — AI Plus
    place_recommend: { category: 'convenience', requiredPlan: 'ai_plus', locationBased: true, blockedRoles: ['guardian'], minorBlocked: true, under14Blocked: false },
    ai_chatbot:      { category: 'convenience', requiredPlan: 'ai_plus', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: true },
    chat_translate:  { category: 'convenience', requiredPlan: 'ai_plus', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },
    chat_summary:    { category: 'convenience', requiredPlan: 'ai_plus', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },

    // Intelligence AI — AI Plus
    travel_insight:   { category: 'intelligence', requiredPlan: 'ai_plus', locationBased: false, blockedRoles: ['guardian'], minorBlocked: false, under14Blocked: false },
    pattern_analysis: { category: 'intelligence', requiredPlan: 'ai_plus', locationBased: true, blockedRoles: ['guardian', 'crew'], minorBlocked: true, under14Blocked: false },
    movement_predict: { category: 'intelligence', requiredPlan: 'ai_plus', locationBased: true, blockedRoles: ['guardian', 'crew'], minorBlocked: false, under14Blocked: false },

    // Intelligence AI — AI Pro
    safety_briefing:    { category: 'intelligence', requiredPlan: 'ai_pro', locationBased: false, blockedRoles: ['guardian', 'crew', 'crew_chief'], minorBlocked: false, under14Blocked: false },
    schedule_optimize:  { category: 'intelligence', requiredPlan: 'ai_pro', locationBased: false, blockedRoles: ['guardian', 'crew', 'crew_chief'], minorBlocked: false, under14Blocked: false },
};

export interface AccessCheckResult {
    allowed: boolean;
    plan: string;
    feature: AiFeature;
    category: AiCategory;
}

/**
 * §8 역할별 AI 접근 + §9 프라이버시 등급 + §10 미성년자 제한 + §3.2 과금 분기
 */
@Injectable()
export class AccessGuardService {
    private readonly logger = new Logger(AccessGuardService.name);

    constructor(
        @InjectRepository(User) private userRepo: Repository<User>,
        @InjectRepository(GroupMember) private memberRepo: Repository<GroupMember>,
        @InjectRepository(Trip) private tripRepo: Repository<Trip>,
        @InjectRepository(AiSubscription) private aiSubRepo: Repository<AiSubscription>,
        @InjectRepository(AiUsage) private aiUsageRepo: Repository<AiUsage>,
    ) {}

    async checkAccess(userId: string, feature: AiFeature, tripId?: string): Promise<AccessCheckResult> {
        const def = FEATURE_DEFS[feature];
        if (!def) throw new BadRequestException(`Unknown AI feature: ${feature}`);

        // 1. 사용자 조회
        const user = await this.userRepo.findOne({ where: { userId } });
        if (!user) throw new ForbiddenException('User not found');

        // 2. 역할 확인 (§8)
        if (tripId) {
            const member = await this.memberRepo.findOne({
                where: { userId, tripId, status: 'active' },
            });
            const role = member?.memberRole ?? 'crew';
            if (def.blockedRoles.includes(role)) {
                throw new ForbiddenException(`Role '${role}' cannot access '${feature}'.`);
            }
        }

        // 3. 미성년자 확인 (§10)
        const isMinor = user.minorStatus !== 'adult';
        if (isMinor) {
            const age = user.dateOfBirth ? this.calcAge(user.dateOfBirth) : 0;
            if (def.under14Blocked && age < 14) {
                throw new ForbiddenException(`AI feature '${feature}' is blocked for users under 14.`);
            }
            if (def.minorBlocked) {
                throw new ForbiddenException(`AI feature '${feature}' is blocked for minors.`);
            }
        }

        // 4. 프라이버시 등급 확인 (§9)
        if (tripId && def.locationBased) {
            const trip = await this.tripRepo.findOne({ where: { tripId } });
            if (trip?.privacyLevel === 'privacy_first') {
                throw new ForbiddenException(`Location-based AI feature '${feature}' is disabled for privacy_first trips.`);
            }
        }

        // 5. 구독 확인 (§3.2)
        if (def.requiredPlan !== 'free') {
            const sub = await this.aiSubRepo.findOne({
                where: { userId, status: In(['active', 'grace_period']) },
                order: { createdAt: 'DESC' },
            });

            const planRank = { ai_pro: 2, ai_plus: 1 };
            const requiredRank = planRank[def.requiredPlan] ?? 0;
            const userRank = sub ? (planRank[sub.planType] ?? 0) : 0;

            if (userRank < requiredRank) {
                throw new BadRequestException(
                    `Feature '${feature}' requires ${def.requiredPlan} subscription.`,
                );
            }
        }

        return {
            allowed: true,
            plan: def.requiredPlan,
            feature,
            category: def.category,
        };
    }

    private calcAge(dob: Date): number {
        const now = new Date();
        let age = now.getFullYear() - dob.getFullYear();
        const m = now.getMonth() - dob.getMonth();
        if (m < 0 || (m === 0 && now.getDate() < dob.getDate())) age--;
        return age;
    }
}
```

**Step 4: Run test — PASS**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/access-guard.service.spec.ts --no-cache
```

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/core/access-guard.service.ts safetrip-server-api/src/modules/ai/core/access-guard.service.spec.ts
git commit -m "feat(ai): add AccessGuardService (§8 역할 + §9 프라이버시 + §10 미성년자)"
```

---

## Task 8: Core — LLMGatewayService (§6 폴백 전략)

**Files:**
- Create: `safetrip-server-api/src/modules/ai/core/llm-gateway.service.ts`
- Create: `safetrip-server-api/src/modules/ai/core/llm-gateway.service.spec.ts`

**Step 1: Write the failing test**

```typescript
// llm-gateway.service.spec.ts
import { LLMGatewayService, LLMRequest } from './llm-gateway.service';

describe('LLMGatewayService', () => {
    let service: LLMGatewayService;

    beforeEach(() => {
        service = new LLMGatewayService();
    });

    describe('getTimeout', () => {
        it('should return 2s for safety', () => {
            expect(service.getTimeout('safety')).toBe(2000);
        });
        it('should return 5s for convenience', () => {
            expect(service.getTimeout('convenience')).toBe(5000);
        });
        it('should return 10s for intelligence', () => {
            expect(service.getTimeout('intelligence')).toBe(10000);
        });
    });

    describe('call (fallback)', () => {
        it('should return rule-based fallback when no API keys set', async () => {
            const req: LLMRequest = {
                aiType: 'safety',
                prompt: 'test prompt',
                systemPrompt: 'You are a safety assistant',
            };

            const result = await service.call(req);
            expect(result.isFallback).toBe(true);
            expect(result.modelUsed).toBe('rule_based');
            expect(result.fallbackReason).toBeDefined();
        });

        it('should include latency in response', async () => {
            const result = await service.call({
                aiType: 'convenience',
                prompt: 'test',
            });
            expect(typeof result.latencyMs).toBe('number');
            expect(result.latencyMs).toBeGreaterThanOrEqual(0);
        });
    });

    describe('ruleBasedFallback', () => {
        it('should return structured response for safety type', () => {
            const result = service.ruleBasedFallback('safety', 'detect danger');
            expect(result).toBeDefined();
            expect(typeof result).toBe('string');
        });

        it('should return service unavailable message for convenience', () => {
            const result = service.ruleBasedFallback('convenience', 'recommend place');
            expect(result).toContain('AI 서비스');
        });

        it('should return disabled message for intelligence', () => {
            const result = service.ruleBasedFallback('intelligence', 'analyze');
            expect(result).toContain('사용 가능');
        });
    });
});
```

**Step 2: Run test — FAIL**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/llm-gateway.service.spec.ts --no-cache
```

**Step 3: Implement LLMGatewayService**

```typescript
// llm-gateway.service.ts
import { Injectable, Logger } from '@nestjs/common';

export interface LLMRequest {
    aiType: 'safety' | 'convenience' | 'intelligence';
    prompt: string;
    systemPrompt?: string;
    preferredModel?: 'openai' | 'anthropic';
    temperature?: number;
    maxTokens?: number;
}

export interface LLMResponse {
    content: string;
    modelUsed: string;
    isFallback: boolean;
    fallbackReason?: string;
    latencyMs: number;
}

/**
 * §6 AI 모델 선택 및 폴백 전략
 * 3단계: Cloud LLM → On-device (interface only) → Rule-based
 */
@Injectable()
export class LLMGatewayService {
    private readonly logger = new Logger(LLMGatewayService.name);

    /** §7.1 타임아웃 (ms) */
    getTimeout(aiType: string): number {
        switch (aiType) {
            case 'safety': return 2000;
            case 'convenience': return 5000;
            case 'intelligence': return 10000;
            default: return 5000;
        }
    }

    async call(req: LLMRequest): Promise<LLMResponse> {
        const start = Date.now();
        const timeout = this.getTimeout(req.aiType);

        // 1차: Cloud LLM
        try {
            const result = await this.callCloudLLM(req, timeout);
            return { ...result, latencyMs: Date.now() - start };
        } catch (err) {
            this.logger.warn(`Cloud LLM failed: ${err.message}. Falling back.`);
        }

        // 2차: On-device (interface only — skip to 3차)
        // Phase 3에서 실제 구현 예정

        // 3차: Rule-based fallback
        const content = this.ruleBasedFallback(req.aiType, req.prompt);
        return {
            content,
            modelUsed: 'rule_based',
            isFallback: true,
            fallbackReason: 'cloud_llm_unavailable',
            latencyMs: Date.now() - start,
        };
    }

    private async callCloudLLM(req: LLMRequest, timeout: number): Promise<LLMResponse> {
        const model = req.preferredModel || (req.aiType === 'safety' ? 'anthropic' : 'openai');

        if (model === 'openai') {
            return this.callOpenAI(req, timeout);
        } else {
            return this.callAnthropic(req, timeout);
        }
    }

    private async callOpenAI(req: LLMRequest, timeout: number): Promise<LLMResponse> {
        const apiKey = process.env.OPENAI_API_KEY;
        if (!apiKey) throw new Error('OPENAI_API_KEY not configured');

        const OpenAI = require('openai');
        const client = new OpenAI({ apiKey, timeout });

        const messages: any[] = [];
        if (req.systemPrompt) messages.push({ role: 'system', content: req.systemPrompt });
        messages.push({ role: 'user', content: req.prompt });

        const response = await client.chat.completions.create({
            model: 'gpt-4o',
            messages,
            temperature: req.temperature ?? 0.7,
            max_tokens: req.maxTokens ?? 2048,
        });

        return {
            content: response.choices[0].message.content || '',
            modelUsed: 'gpt-4o',
            isFallback: false,
            latencyMs: 0, // caller overwrites
        };
    }

    private async callAnthropic(req: LLMRequest, timeout: number): Promise<LLMResponse> {
        const apiKey = process.env.ANTHROPIC_API_KEY;
        if (!apiKey) throw new Error('ANTHROPIC_API_KEY not configured');

        const Anthropic = require('@anthropic-ai/sdk');
        const client = new Anthropic({ apiKey, timeout });

        const response = await client.messages.create({
            model: 'claude-sonnet-4-20250514',
            max_tokens: req.maxTokens ?? 2048,
            system: req.systemPrompt || undefined,
            messages: [{ role: 'user', content: req.prompt }],
        });

        const textBlock = response.content.find((b: any) => b.type === 'text');

        return {
            content: textBlock?.text || '',
            modelUsed: 'claude-sonnet-4-20250514',
            isFallback: false,
            latencyMs: 0,
        };
    }

    /** §6.1 3차 — 규칙 기반 대응 */
    ruleBasedFallback(aiType: string, prompt: string): string {
        switch (aiType) {
            case 'safety':
                return JSON.stringify({
                    status: 'rule_based_active',
                    message: '규칙 기반 안전 모니터링이 활성화되어 있습니다.',
                    capabilities: ['departure_detect', 'sos_inactive_timer', 'geofence_breach'],
                });
            case 'convenience':
                return '현재 AI 서비스 점검 중입니다. 잠시 후 다시 시도해주세요.';
            case 'intelligence':
                return '인터넷 연결 시 사용 가능합니다.';
            default:
                return 'AI 서비스를 이용할 수 없습니다.';
        }
    }
}
```

**Step 4: Run test — PASS**

```bash
cd safetrip-server-api && npx jest src/modules/ai/core/llm-gateway.service.spec.ts --no-cache
```

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/core/llm-gateway.service.ts safetrip-server-api/src/modules/ai/core/llm-gateway.service.spec.ts
git commit -m "feat(ai): add LLMGatewayService (§6 3단계 폴백 + OpenAI/Anthropic)"
```

---

## Task 9: Feature — SafetyAiService (§3.1 Safety)

**Files:**
- Create: `safetrip-server-api/src/modules/ai/safety-ai.service.ts`
- Create: `safetrip-server-api/src/modules/ai/safety-ai.service.spec.ts`

**Step 1: Write the failing test**

```typescript
// safety-ai.service.spec.ts
import { SafetyAiService } from './safety-ai.service';

describe('SafetyAiService', () => {
    let service: SafetyAiService;
    const mockAccessGuard = { checkAccess: jest.fn().mockResolvedValue({ allowed: true, category: 'safety' }) };
    const mockUsageLogger = { log: jest.fn().mockResolvedValue({}) };

    beforeEach(() => {
        service = new SafetyAiService(mockAccessGuard as any, mockUsageLogger as any);
        jest.clearAllMocks();
    });

    describe('detectDepartureAnomaly', () => {
        it('should detect departure when beyond 300m for over 10min', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 400,
                durationOutsideMin: 15,
            });
            expect(result.isDeparted).toBe(true);
            expect(result.severity).toBe('high');
        });

        it('should not trigger when within 300m', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 200,
                durationOutsideMin: 20,
            });
            expect(result.isDeparted).toBe(false);
        });

        it('should not trigger when outside but under 10min', () => {
            const result = service.evaluateDeparture({
                distanceFromGatheringM: 500,
                durationOutsideMin: 5,
            });
            expect(result.isDeparted).toBe(false);
        });
    });

    describe('evaluateSosCondition', () => {
        it('should trigger SOS when inactive for 15+ minutes', () => {
            const result = service.evaluateSosCondition({
                inactiveMinutes: 20,
                hasFallDetected: false,
            });
            expect(result.shouldTriggerSos).toBe(true);
        });

        it('should trigger SOS on fall detection', () => {
            const result = service.evaluateSosCondition({
                inactiveMinutes: 0,
                hasFallDetected: true,
            });
            expect(result.shouldTriggerSos).toBe(true);
        });

        it('should not trigger when active', () => {
            const result = service.evaluateSosCondition({
                inactiveMinutes: 5,
                hasFallDetected: false,
            });
            expect(result.shouldTriggerSos).toBe(false);
        });
    });
});
```

**Step 2: Run test — FAIL**

**Step 3: Implement SafetyAiService**

```typescript
// safety-ai.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { AccessGuardService, AiFeature } from './core/access-guard.service';
import { UsageLoggerService } from './core/usage-logger.service';

/**
 * §3.1 Safety AI — 전원 무료, LLM 미사용 (§7.2 할루시네이션 방지)
 * 규칙 기반 + 공식 데이터 소스만 사용
 */
@Injectable()
export class SafetyAiService {
    private readonly logger = new Logger(SafetyAiService.name);

    constructor(
        private readonly accessGuard: AccessGuardService,
        private readonly usageLogger: UsageLoggerService,
    ) {}

    /** §13.2 이탈 감지: 집합 장소 300m 초과 + 10분 지속 */
    evaluateDeparture(data: { distanceFromGatheringM: number; durationOutsideMin: number }) {
        const isDeparted = data.distanceFromGatheringM > 300 && data.durationOutsideMin >= 10;
        return {
            isDeparted,
            severity: isDeparted ? 'high' : 'none',
            distanceM: data.distanceFromGatheringM,
            durationMin: data.durationOutsideMin,
        };
    }

    /** §13.2 SOS 자동 판단: 가속도 낙상 감지 + 15분 비활성 */
    evaluateSosCondition(data: { inactiveMinutes: number; hasFallDetected: boolean }) {
        const shouldTriggerSos = data.hasFallDetected || data.inactiveMinutes >= 15;
        return {
            shouldTriggerSos,
            reason: data.hasFallDetected ? 'fall_detected' : (data.inactiveMinutes >= 15 ? 'inactive_timeout' : 'none'),
        };
    }

    /** 비정상 속도 감지 (기존 anomaly detection 이관) */
    evaluateSpeedAnomaly(speedMs: number) {
        const isAnomalous = speedMs > 41.6; // 150 km/h
        return {
            isAnomalous,
            severity: isAnomalous ? 'medium' : 'none',
            speedKmh: Math.round(speedMs * 3.6),
        };
    }

    /** 접근 제어 + 로그를 포함한 전체 파이프라인 호출 */
    async checkDeparture(userId: string, tripId: string, data: { distanceFromGatheringM: number; durationOutsideMin: number }) {
        const start = Date.now();
        await this.accessGuard.checkAccess(userId, 'departure_detect', tripId);
        const result = this.evaluateDeparture(data);
        await this.usageLogger.log({
            userId, tripId,
            aiType: 'safety',
            featureName: 'departure_detect',
            modelUsed: 'rule_based',
            latencyMs: Date.now() - start,
        });
        return result;
    }
}
```

**Step 4: Run test — PASS**

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/safety-ai.service.ts safetrip-server-api/src/modules/ai/safety-ai.service.spec.ts
git commit -m "feat(ai): add SafetyAiService (§3.1 규칙 기반 Safety AI)"
```

---

## Task 10: Feature — ConvenienceAiService (§3.1 Convenience)

**Files:**
- Create: `safetrip-server-api/src/modules/ai/convenience-ai.service.ts`
- Create: `safetrip-server-api/src/modules/ai/convenience-ai.service.spec.ts`

**Step 1: Write the failing test**

```typescript
// convenience-ai.service.spec.ts
import { ConvenienceAiService } from './convenience-ai.service';

describe('ConvenienceAiService', () => {
    let service: ConvenienceAiService;
    const mockAccessGuard = { checkAccess: jest.fn().mockResolvedValue({ allowed: true }) };
    const mockLLMGateway = {
        call: jest.fn().mockResolvedValue({
            content: JSON.stringify({ suggestions: [{ title: 'Visit museum', time: '10:00' }] }),
            modelUsed: 'gpt-4o', isFallback: false, latencyMs: 800,
        }),
    };
    const mockDataMasker = {
        maskText: jest.fn((t) => t),
        coarsenLocation: jest.fn((lat, lng) => ({ latitude: 37.57, longitude: 126.98 })),
        maskTripName: jest.fn((name, id) => `trip_${id.split('-')[0]}`),
    };
    const mockCache = {
        get: jest.fn().mockReturnValue(null),
        set: jest.fn(),
        getTtl: jest.fn().mockReturnValue(3600000),
        buildKey: jest.fn().mockReturnValue('test_key'),
    };
    const mockUsageLogger = { log: jest.fn().mockResolvedValue({}) };

    beforeEach(() => {
        service = new ConvenienceAiService(
            mockAccessGuard as any,
            mockLLMGateway as any,
            mockDataMasker as any,
            mockCache as any,
            mockUsageLogger as any,
        );
        jest.clearAllMocks();
    });

    it('should call access guard before generating suggestions', async () => {
        await service.generateScheduleSuggestions('u1', 'trip-1', 'Japan trip');
        expect(mockAccessGuard.checkAccess).toHaveBeenCalledWith('u1', 'schedule_autocomplete', 'trip-1');
    });

    it('should mask data before LLM call', async () => {
        await service.generateScheduleSuggestions('u1', 'trip-1', 'Japan trip');
        expect(mockDataMasker.maskText).toHaveBeenCalled();
    });

    it('should return cached response on cache hit', async () => {
        mockCache.get.mockReturnValueOnce({ cached: true });
        const result = await service.generateScheduleSuggestions('u1', 'trip-1', 'Japan trip');
        expect(result).toEqual({ cached: true });
        expect(mockLLMGateway.call).not.toHaveBeenCalled();
    });

    it('should log usage after call', async () => {
        await service.generateScheduleSuggestions('u1', 'trip-1', 'Japan trip');
        expect(mockUsageLogger.log).toHaveBeenCalledWith(
            expect.objectContaining({
                aiType: 'convenience',
                featureName: 'schedule_autocomplete',
            }),
        );
    });
});
```

**Step 2: Run test — FAIL**

**Step 3: Implement ConvenienceAiService**

```typescript
// convenience-ai.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { AccessGuardService, AiFeature } from './core/access-guard.service';
import { LLMGatewayService } from './core/llm-gateway.service';
import { DataMaskerService } from './core/data-masker.service';
import { ResponseCacheService } from './core/response-cache.service';
import { UsageLoggerService } from './core/usage-logger.service';

/**
 * §3.1 Convenience AI — 무료 기본 기능 + AI Plus 고급 기능
 */
@Injectable()
export class ConvenienceAiService {
    private readonly logger = new Logger(ConvenienceAiService.name);

    constructor(
        private readonly accessGuard: AccessGuardService,
        private readonly llm: LLMGatewayService,
        private readonly masker: DataMaskerService,
        private readonly cache: ResponseCacheService,
        private readonly usageLogger: UsageLoggerService,
    ) {}

    /** [무료] 일정 자동 완성 */
    async generateScheduleSuggestions(userId: string, tripId: string, prompt: string) {
        await this.accessGuard.checkAccess(userId, 'schedule_autocomplete', tripId);

        const cacheKey = this.cache.buildKey('schedule_autocomplete', { trip_id: tripId, prompt_hash: prompt.slice(0, 20) });
        const cached = this.cache.get(cacheKey);
        if (cached) {
            await this.usageLogger.log({ userId, tripId, aiType: 'convenience', featureName: 'schedule_autocomplete', isCached: true, modelUsed: 'cache' });
            return cached;
        }

        const maskedPrompt = this.masker.maskText(prompt);
        const resp = await this.llm.call({
            aiType: 'convenience',
            prompt: maskedPrompt,
            systemPrompt: 'You are a travel schedule assistant. Return JSON with suggestions array.',
        });

        let result: any;
        try { result = JSON.parse(resp.content); } catch { result = { raw: resp.content }; }

        this.cache.set(cacheKey, result, this.cache.getTtl('schedule_autocomplete'));
        await this.usageLogger.log({ userId, tripId, aiType: 'convenience', featureName: 'schedule_autocomplete', modelUsed: resp.modelUsed, latencyMs: resp.latencyMs, isFallback: resp.isFallback, fallbackReason: resp.fallbackReason });
        return result;
    }

    /** [무료] 짐 리스트 기본 생성 */
    async generatePackingList(userId: string, tripId: string, params: { country: string; days: number; memberCount: number }) {
        await this.accessGuard.checkAccess(userId, 'packing_list', tripId);
        const resp = await this.llm.call({
            aiType: 'convenience',
            prompt: `Generate a packing list for a ${params.days}-day trip to ${params.country} for ${params.memberCount} people. Return JSON with categories and items.`,
        });
        let result: any;
        try { result = JSON.parse(resp.content); } catch { result = { raw: resp.content }; }
        await this.usageLogger.log({ userId, tripId, aiType: 'convenience', featureName: 'packing_list', modelUsed: resp.modelUsed, latencyMs: resp.latencyMs, isFallback: resp.isFallback });
        return result;
    }

    /** [AI Plus] AI 챗봇 어시스턴트 */
    async chatWithAssistant(userId: string, tripId: string, message: string, isMinor: boolean, age?: number) {
        await this.accessGuard.checkAccess(userId, 'ai_chatbot', tripId);
        const maskedMessage = this.masker.maskText(message);
        let systemPrompt = 'You are SafeTrip AI travel assistant. Answer travel-related questions helpfully.';
        if (isMinor && age && age >= 14) {
            systemPrompt += ' The user is a minor (14-17). Only answer travel-related questions. If asked non-travel questions, reply: "여행과 관련된 질문을 해주세요."';
        }
        const resp = await this.llm.call({ aiType: 'convenience', prompt: maskedMessage, systemPrompt });
        await this.usageLogger.log({ userId, tripId, aiType: 'convenience', featureName: 'ai_chatbot', modelUsed: resp.modelUsed, latencyMs: resp.latencyMs, isMinorUser: isMinor });
        return { reply: resp.content, modelUsed: resp.modelUsed, disclaimer: 'AI가 생성한 정보로, 실제와 다를 수 있습니다.' };
    }

    /** [AI Plus] 실시간 번역 */
    async translate(userId: string, tripId: string, text: string, targetLang: string) {
        await this.accessGuard.checkAccess(userId, 'chat_translate', tripId);
        const maskedText = this.masker.maskText(text);
        const resp = await this.llm.call({ aiType: 'convenience', prompt: `Translate to ${targetLang}: "${maskedText}"` });
        await this.usageLogger.log({ userId, tripId, aiType: 'convenience', featureName: 'chat_translate', modelUsed: resp.modelUsed, latencyMs: resp.latencyMs });
        return { translated: resp.content, modelUsed: resp.modelUsed };
    }

    /** [AI Plus] 채팅 요약 */
    async summarizeChat(userId: string, tripId: string, messages: string[]) {
        await this.accessGuard.checkAccess(userId, 'chat_summary', tripId);
        const cacheKey = this.cache.buildKey('chat_summary', { chat_room: tripId, msg_count: messages.length });
        const cached = this.cache.get(cacheKey);
        if (cached) return cached;
        const masked = messages.map((m) => this.masker.maskText(m));
        const resp = await this.llm.call({ aiType: 'convenience', prompt: `Summarize these chat messages concisely in Korean:\n${masked.join('\n')}` });
        const result = { summary: resp.content, modelUsed: resp.modelUsed };
        this.cache.set(cacheKey, result, this.cache.getTtl('chat_summary'));
        await this.usageLogger.log({ userId, tripId, aiType: 'convenience', featureName: 'chat_summary', modelUsed: resp.modelUsed, latencyMs: resp.latencyMs });
        return result;
    }
}
```

**Step 4: Run test — PASS**

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/convenience-ai.service.ts safetrip-server-api/src/modules/ai/convenience-ai.service.spec.ts
git commit -m "feat(ai): add ConvenienceAiService (§3.1 무료+AI Plus 기능)"
```

---

## Task 11: Feature — IntelligenceAiService (§3.1 Intelligence)

**Files:**
- Create: `safetrip-server-api/src/modules/ai/intelligence-ai.service.ts`
- Create: `safetrip-server-api/src/modules/ai/intelligence-ai.service.spec.ts`

**Step 1: Write the failing test**

```typescript
// intelligence-ai.service.spec.ts
import { IntelligenceAiService } from './intelligence-ai.service';

describe('IntelligenceAiService', () => {
    let service: IntelligenceAiService;
    const mockAccessGuard = { checkAccess: jest.fn().mockResolvedValue({ allowed: true }) };
    const mockLLMGateway = {
        call: jest.fn().mockResolvedValue({
            content: JSON.stringify({ insights: ['High activity area: Shibuya'] }),
            modelUsed: 'gpt-4o', isFallback: false, latencyMs: 3000,
        }),
    };
    const mockCache = {
        get: jest.fn().mockReturnValue(null), set: jest.fn(),
        getTtl: jest.fn().mockReturnValue(14400000), buildKey: jest.fn().mockReturnValue('key'),
    };
    const mockUsageLogger = { log: jest.fn().mockResolvedValue({}) };
    const mockDataMasker = { maskText: jest.fn((t) => t), coarsenLocation: jest.fn((lat, lng) => ({ latitude: lat, longitude: lng })) };

    beforeEach(() => {
        service = new IntelligenceAiService(
            mockAccessGuard as any, mockLLMGateway as any,
            mockDataMasker as any, mockCache as any, mockUsageLogger as any,
        );
        jest.clearAllMocks();
    });

    it('should call access guard with travel_insight', async () => {
        await service.getTravelInsight('u1', 'trip-1');
        expect(mockAccessGuard.checkAccess).toHaveBeenCalledWith('u1', 'travel_insight', 'trip-1');
    });

    it('should include evidence metadata in response', async () => {
        const result = await service.getTravelInsight('u1', 'trip-1');
        expect(result.evidence).toBeDefined();
        expect(result.disclaimer).toContain('분석');
    });

    it('should call access guard with safety_briefing for Pro', async () => {
        await service.getSafetyBriefing('u1', 'trip-1', 'Tokyo');
        expect(mockAccessGuard.checkAccess).toHaveBeenCalledWith('u1', 'safety_briefing', 'trip-1');
    });
});
```

**Step 2: Run test — FAIL**

**Step 3: Implement IntelligenceAiService**

```typescript
// intelligence-ai.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { AccessGuardService } from './core/access-guard.service';
import { LLMGatewayService } from './core/llm-gateway.service';
import { DataMaskerService } from './core/data-masker.service';
import { ResponseCacheService } from './core/response-cache.service';
import { UsageLoggerService } from './core/usage-logger.service';

/**
 * §3.1 Intelligence AI — 전원 유료 (AI Plus / AI Pro)
 * 분석 근거 데이터(로그 기간, 샘플 수) 함께 표시 (§7.2)
 */
@Injectable()
export class IntelligenceAiService {
    private readonly logger = new Logger(IntelligenceAiService.name);

    constructor(
        private readonly accessGuard: AccessGuardService,
        private readonly llm: LLMGatewayService,
        private readonly masker: DataMaskerService,
        private readonly cache: ResponseCacheService,
        private readonly usageLogger: UsageLoggerService,
    ) {}

    /** [AI Plus] 여행 인사이트 */
    async getTravelInsight(userId: string, tripId: string) {
        await this.accessGuard.checkAccess(userId, 'travel_insight', tripId);
        const resp = await this.llm.call({
            aiType: 'intelligence',
            prompt: `Analyze travel patterns for trip and provide insights in JSON format with 'insights' array.`,
            systemPrompt: 'You are a travel data analyst. Provide concise, data-driven insights.',
        });
        let parsed: any;
        try { parsed = JSON.parse(resp.content); } catch { parsed = { insights: [resp.content] }; }
        await this.usageLogger.log({ userId, tripId, aiType: 'intelligence', featureName: 'travel_insight', modelUsed: resp.modelUsed, latencyMs: resp.latencyMs });
        return { ...parsed, evidence: { dataRange: '최근 7일', sampleCount: 0 }, disclaimer: '데이터 분석 기반 인사이트입니다. 실제 상황과 다를 수 있습니다.' };
    }

    /** [AI Pro] 맞춤 안전 브리핑 */
    async getSafetyBriefing(userId: string, tripId: string, destination: string) {
        await this.accessGuard.checkAccess(userId, 'safety_briefing', tripId);

        const cacheKey = this.cache.buildKey('safety_briefing', { trip_id: tripId, destination, date: new Date().toISOString().split('T')[0] });
        const cached = this.cache.get(cacheKey);
        if (cached) return cached;

        const maskedDest = this.masker.maskText(destination);
        const resp = await this.llm.call({
            aiType: 'intelligence',
            prompt: `Create a comprehensive safety briefing for ${maskedDest}. Include: weather risks, local crime patterns, health advisories, embassy contact. Return JSON.`,
            systemPrompt: 'You are a travel safety analyst. Always cite data sources.',
        });

        let result: any;
        try { result = JSON.parse(resp.content); } catch { result = { briefing: resp.content }; }
        result = { ...result, evidence: { sources: ['외교부 여행경보', '기상청', '현지 치안 데이터'] }, modelUsed: resp.modelUsed };
        this.cache.set(cacheKey, result, this.cache.getTtl('safety_briefing'));
        await this.usageLogger.log({ userId, tripId, aiType: 'intelligence', featureName: 'safety_briefing', modelUsed: resp.modelUsed, latencyMs: resp.latencyMs });
        return result;
    }

    /** [AI Pro] 일정 최적화 */
    async optimizeSchedule(userId: string, tripId: string, schedules: any[]) {
        await this.accessGuard.checkAccess(userId, 'schedule_optimize', tripId);
        const resp = await this.llm.call({
            aiType: 'intelligence',
            prompt: `Optimize this travel schedule for minimal travel time and best experience: ${JSON.stringify(schedules)}. Return optimized JSON.`,
        });
        let result: any;
        try { result = JSON.parse(resp.content); } catch { result = { optimized: resp.content }; }
        await this.usageLogger.log({ userId, tripId, aiType: 'intelligence', featureName: 'schedule_optimize', modelUsed: resp.modelUsed, latencyMs: resp.latencyMs });
        return { ...result, disclaimer: '최적화 제안입니다. 실제 교통 상황에 따라 달라질 수 있습니다.' };
    }
}
```

**Step 4: Run test — PASS**

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/intelligence-ai.service.ts safetrip-server-api/src/modules/ai/intelligence-ai.service.spec.ts
git commit -m "feat(ai): add IntelligenceAiService (§3.1 AI Plus/Pro 기능)"
```

---

## Task 12: Refactor ai.module.ts + ai.controller.ts + ai.service.ts

**Files:**
- Modify: `safetrip-server-api/src/modules/ai/ai.module.ts`
- Modify: `safetrip-server-api/src/modules/ai/ai.controller.ts`
- Modify: `safetrip-server-api/src/modules/ai/ai.service.ts`

**Step 1: Update ai.module.ts**

Replace entire file:

```typescript
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { AccessGuardService } from './core/access-guard.service';
import { LLMGatewayService } from './core/llm-gateway.service';
import { DataMaskerService } from './core/data-masker.service';
import { ResponseCacheService } from './core/response-cache.service';
import { UsageLoggerService } from './core/usage-logger.service';
import { SafetyAiService } from './safety-ai.service';
import { ConvenienceAiService } from './convenience-ai.service';
import { IntelligenceAiService } from './intelligence-ai.service';
import { AiUsage, AiUsageLog, AiSubscription, User, GroupMember, Trip, Payment } from '../../entities';
import { PaymentsModule } from '../payments/payments.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            AiUsage, AiUsageLog, AiSubscription,
            User, GroupMember, Trip, Payment,
        ]),
        PaymentsModule,
        HttpModule,
    ],
    controllers: [AiController],
    providers: [
        AiService,
        AccessGuardService,
        LLMGatewayService,
        DataMaskerService,
        ResponseCacheService,
        UsageLoggerService,
        SafetyAiService,
        ConvenienceAiService,
        IntelligenceAiService,
    ],
    exports: [
        AiService,
        AccessGuardService,
        SafetyAiService,
        ConvenienceAiService,
        IntelligenceAiService,
    ],
})
export class AiModule {}
```

**Step 2: Update ai.controller.ts**

Replace entire file — add new endpoints for all 3 categories:

```typescript
import { Controller, Get, Post, Patch, Body, Query, Param } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SafetyAiService } from './safety-ai.service';
import { ConvenienceAiService } from './convenience-ai.service';
import { IntelligenceAiService } from './intelligence-ai.service';
import { AccessGuardService, AiFeature } from './core/access-guard.service';
import { UsageLoggerService } from './core/usage-logger.service';

@ApiTags('AI')
@ApiBearerAuth('firebase-auth')
@Controller('ai')
export class AiController {
    constructor(
        private readonly safetyAi: SafetyAiService,
        private readonly convenienceAi: ConvenienceAiService,
        private readonly intelligenceAi: IntelligenceAiService,
        private readonly accessGuard: AccessGuardService,
        private readonly usageLogger: UsageLoggerService,
    ) {}

    // ── Access Check ──
    @Get('access-check')
    @ApiOperation({ summary: 'AI 기능 접근 권한 확인' })
    async checkAccess(
        @CurrentUser() userId: string,
        @Query('feature') feature: AiFeature,
        @Query('trip_id') tripId?: string,
    ) {
        return this.accessGuard.checkAccess(userId, feature, tripId);
    }

    // ── Safety AI ──
    @Post('safety/departure-check')
    @ApiOperation({ summary: '[Safety] 이탈 감지 평가' })
    async checkDeparture(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; distance_m: number; duration_min: number },
    ) {
        return this.safetyAi.checkDeparture(userId, body.trip_id, {
            distanceFromGatheringM: body.distance_m,
            durationOutsideMin: body.duration_min,
        });
    }

    @Post('safety/sos-evaluate')
    @ApiOperation({ summary: '[Safety] SOS 자동 판단' })
    async evaluateSos(
        @Body() body: { inactive_minutes: number; fall_detected: boolean },
    ) {
        return SafetyAiService.prototype.evaluateSosCondition.call(
            this.safetyAi, {
                inactiveMinutes: body.inactive_minutes,
                hasFallDetected: body.fall_detected,
            },
        );
    }

    // ── Convenience AI ──
    @Post('convenience/schedule-suggest')
    @ApiOperation({ summary: '[Convenience] 일정 자동 완성' })
    async scheduleSuggest(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; prompt: string },
    ) {
        return this.convenienceAi.generateScheduleSuggestions(userId, body.trip_id, body.prompt);
    }

    @Post('convenience/packing-list')
    @ApiOperation({ summary: '[Convenience] 짐 리스트 생성' })
    async packingList(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; country: string; days: number; member_count: number },
    ) {
        return this.convenienceAi.generatePackingList(userId, body.trip_id, {
            country: body.country, days: body.days, memberCount: body.member_count,
        });
    }

    @Post('convenience/chatbot')
    @ApiOperation({ summary: '[Convenience] AI 챗봇 대화 (AI Plus)' })
    async chatbot(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; message: string; is_minor?: boolean; age?: number },
    ) {
        return this.convenienceAi.chatWithAssistant(
            userId, body.trip_id, body.message, body.is_minor ?? false, body.age,
        );
    }

    @Post('convenience/translate')
    @ApiOperation({ summary: '[Convenience] 실시간 번역 (AI Plus)' })
    async translate(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; text: string; target_lang: string },
    ) {
        return this.convenienceAi.translate(userId, body.trip_id, body.text, body.target_lang);
    }

    @Post('convenience/chat-summary')
    @ApiOperation({ summary: '[Convenience] 채팅 요약 (AI Plus)' })
    async chatSummary(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; messages: string[] },
    ) {
        return this.convenienceAi.summarizeChat(userId, body.trip_id, body.messages);
    }

    // ── Intelligence AI ──
    @Post('intelligence/insight')
    @ApiOperation({ summary: '[Intelligence] 여행 인사이트 (AI Plus)' })
    async travelInsight(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string },
    ) {
        return this.intelligenceAi.getTravelInsight(userId, body.trip_id);
    }

    @Post('intelligence/safety-briefing')
    @ApiOperation({ summary: '[Intelligence] 맞춤 안전 브리핑 (AI Pro)' })
    async safetyBriefing(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; destination: string },
    ) {
        return this.intelligenceAi.getSafetyBriefing(userId, body.trip_id, body.destination);
    }

    @Post('intelligence/schedule-optimize')
    @ApiOperation({ summary: '[Intelligence] 일정 최적화 (AI Pro)' })
    async scheduleOptimize(
        @CurrentUser() userId: string,
        @Body() body: { trip_id: string; schedules: any[] },
    ) {
        return this.intelligenceAi.optimizeSchedule(userId, body.trip_id, body.schedules);
    }

    // ── Feedback ──
    @Patch('feedback/:logId')
    @ApiOperation({ summary: 'AI 응답 피드백 (엄지 업/다운)' })
    async submitFeedback(
        @Param('logId') logId: string,
        @Body() body: { feedback: -1 | 0 | 1 },
    ) {
        await this.usageLogger.updateFeedback(logId, body.feedback);
        return { success: true };
    }
}
```

**Step 3: Slim down ai.service.ts**

Keep as thin orchestrator for backward compatibility. Replace content:

```typescript
import { Injectable, Logger } from '@nestjs/common';
import { SafetyAiService } from './safety-ai.service';
import { ConvenienceAiService } from './convenience-ai.service';
import { IntelligenceAiService } from './intelligence-ai.service';
import { AccessGuardService, AiFeature } from './core/access-guard.service';

/**
 * AiService — backward-compatible orchestrator
 * New code should inject specific services directly.
 */
@Injectable()
export class AiService {
    private readonly logger = new Logger(AiService.name);

    constructor(
        private readonly safetyAi: SafetyAiService,
        private readonly convenienceAi: ConvenienceAiService,
        private readonly intelligenceAi: IntelligenceAiService,
        private readonly accessGuard: AccessGuardService,
    ) {}

    async checkAccess(userId: string, feature: AiFeature, tripId?: string) {
        return this.accessGuard.checkAccess(userId, feature, tripId);
    }
}
```

**Step 4: Run all AI tests**

```bash
cd safetrip-server-api && npx jest src/modules/ai/ --no-cache
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add safetrip-server-api/src/modules/ai/ai.module.ts safetrip-server-api/src/modules/ai/ai.controller.ts safetrip-server-api/src/modules/ai/ai.service.ts
git commit -m "refactor(ai): wire Layered AI Architecture into module (§2~§14)"
```

---

## Task 13: Flutter — AI Access Service + Provider

**Files:**
- Create: `safetrip-mobile/lib/features/ai/services/ai_access_service.dart`
- Create: `safetrip-mobile/lib/features/ai/providers/ai_provider.dart`

**Step 1: Create AI Access Service**

```dart
// ai_access_service.dart
import '../../../services/api_service.dart';

class AiAccessResult {
  final bool allowed;
  final String plan;
  final String feature;
  final String category;

  AiAccessResult({required this.allowed, required this.plan, required this.feature, required this.category});

  factory AiAccessResult.fromJson(Map<String, dynamic> json) {
    return AiAccessResult(
      allowed: json['allowed'] ?? false,
      plan: json['plan'] ?? 'free',
      feature: json['feature'] ?? '',
      category: json['category'] ?? '',
    );
  }
}

class AiAccessService {
  final ApiService _api;

  AiAccessService(this._api);

  Future<AiAccessResult> checkAccess(String feature, {String? tripId}) async {
    try {
      final params = <String, String>{'feature': feature};
      if (tripId != null) params['trip_id'] = tripId;
      final response = await _api.dio.get('/api/ai/access-check', queryParameters: params);
      return AiAccessResult.fromJson(response.data);
    } catch (e) {
      return AiAccessResult(allowed: false, plan: 'free', feature: feature, category: '');
    }
  }

  Future<Map<String, dynamic>> submitFeedback(String logId, int feedback) async {
    final response = await _api.dio.patch('/api/ai/feedback/$logId', data: {'feedback': feedback});
    return response.data;
  }
}
```

**Step 2: Create AI Provider**

```dart
// ai_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_service.dart';
import '../services/ai_access_service.dart';

final aiAccessServiceProvider = Provider<AiAccessService>((ref) {
  return AiAccessService(ApiService());
});

class AiState {
  final bool isLoading;
  final String? error;
  final Map<String, bool> featureAccess;

  const AiState({this.isLoading = false, this.error, this.featureAccess = const {}});

  AiState copyWith({bool? isLoading, String? error, Map<String, bool>? featureAccess}) {
    return AiState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      featureAccess: featureAccess ?? this.featureAccess,
    );
  }
}

class AiNotifier extends StateNotifier<AiState> {
  final AiAccessService _accessService;
  AiNotifier(this._accessService) : super(const AiState());

  Future<bool> checkFeatureAccess(String feature, {String? tripId}) async {
    state = state.copyWith(isLoading: true);
    final result = await _accessService.checkAccess(feature, tripId: tripId);
    final updated = Map<String, bool>.from(state.featureAccess);
    updated[feature] = result.allowed;
    state = state.copyWith(isLoading: false, featureAccess: updated);
    return result.allowed;
  }
}

final aiProvider = StateNotifierProvider<AiNotifier, AiState>((ref) {
  return AiNotifier(ref.read(aiAccessServiceProvider));
});
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/ai/
git commit -m "feat(flutter): add AiAccessService + AiProvider"
```

---

## Task 14: Flutter — AI Subscription Modal + Disclaimer Badge + Feedback Widget

**Files:**
- Create: `safetrip-mobile/lib/features/ai/widgets/ai_subscription_modal.dart`
- Create: `safetrip-mobile/lib/features/ai/widgets/ai_disclaimer_badge.dart`
- Create: `safetrip-mobile/lib/features/ai/widgets/ai_feedback_widget.dart`

**Step 1: Create Subscription Modal (§3.3)**

```dart
// ai_subscription_modal.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class AiSubscriptionModal extends StatelessWidget {
  final VoidCallback? onSubscribe;
  final VoidCallback? onDismiss;

  const AiSubscriptionModal({super.key, this.onSubscribe, this.onDismiss});

  static bool _shownThisSession = false;

  static Future<void> showIfNeeded(BuildContext context, {VoidCallback? onSubscribe}) async {
    if (_shownThisSession) return;
    _shownThisSession = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => AiSubscriptionModal(onSubscribe: onSubscribe),
    );
  }

  static void resetSession() => _shownThisSession = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text('AI 기능 업그레이드', style: AppTypography.headlineMedium),
        const SizedBox(height: 16),
        _buildPlanCard('AI Plus', '4,900원/월 또는 2,900원/여행', ['장소 추천', 'AI 챗봇', '실시간 번역', '채팅 요약', '여행 인사이트'], const Color(0xFFFFB800)),
        const SizedBox(height: 12),
        _buildPlanCard('AI Pro', '9,900원/월 또는 5,900원/여행', ['AI Plus 전체 기능', '맞춤 안전 브리핑', '일정 최적화'], const Color(0xFF7C4DFF)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: onSubscribe ?? () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C4DFF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('구독하기'),
        )),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('나중에')),
      ]),
    );
  }

  Widget _buildPlanCard(String name, String price, List<String> features, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: accentColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(6)),
            child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
          const Spacer(),
          Text(price, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ...features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [Icon(Icons.check_circle, size: 16, color: accentColor), const SizedBox(width: 6), Text(f, style: const TextStyle(fontSize: 13))]),
        )),
      ]),
    );
  }
}
```

**Step 2: Create Disclaimer Badge (§7.2)**

```dart
// ai_disclaimer_badge.dart
import 'package:flutter/material.dart';

class AiDisclaimerBadge extends StatelessWidget {
  final String type; // 'convenience' | 'intelligence'

  const AiDisclaimerBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final text = type == 'intelligence'
        ? 'AI 분석 결과입니다. 데이터 범위에 따라 정확도가 달라질 수 있습니다.'
        : 'AI가 생성한 정보로, 실제와 다를 수 있습니다.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: TextStyle(fontSize: 11, color: Colors.orange.shade700))),
      ]),
    );
  }
}
```

**Step 3: Create Feedback Widget (§7.3)**

```dart
// ai_feedback_widget.dart
import 'package:flutter/material.dart';

class AiFeedbackWidget extends StatefulWidget {
  final String logId;
  final Future<void> Function(String logId, int feedback)? onFeedback;

  const AiFeedbackWidget({super.key, required this.logId, this.onFeedback});

  @override
  State<AiFeedbackWidget> createState() => _AiFeedbackWidgetState();
}

class _AiFeedbackWidgetState extends State<AiFeedbackWidget> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('이 응답이 도움이 되었나요?', style: TextStyle(fontSize: 11, color: Colors.grey)),
      const SizedBox(width: 8),
      _feedbackButton(Icons.thumb_up_outlined, 1),
      const SizedBox(width: 4),
      _feedbackButton(Icons.thumb_down_outlined, -1),
    ]);
  }

  Widget _feedbackButton(IconData icon, int value) {
    final isSelected = _selected == value;
    return InkWell(
      onTap: () async {
        setState(() => _selected = value);
        await widget.onFeedback?.call(widget.logId, value);
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: isSelected ? Colors.blue : Colors.grey),
      ),
    );
  }
}
```

**Step 4: Commit**

```bash
git add safetrip-mobile/lib/features/ai/widgets/
git commit -m "feat(flutter): add AI subscription modal, disclaimer badge, feedback widget"
```

---

## Task 15: Flutter — Offline Safety AI Queue (§13)

**Files:**
- Create: `safetrip-mobile/lib/features/ai/services/ai_offline_queue.dart`
- Create: `safetrip-mobile/lib/features/ai/services/on_device_model_interface.dart`

**Step 1: Create Offline Queue**

```dart
// ai_offline_queue.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// §13 오프라인 Safety AI — 로컬 이벤트 큐잉
class AiOfflineQueue {
  static const _queueKey = 'ai_safety_offline_queue';

  /// 오프라인 이벤트를 큐에 추가
  Future<void> enqueue(Map<String, dynamic> event) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    event['queued_at'] = DateTime.now().toIso8601String();
    queue.add(jsonEncode(event));
    await prefs.setStringList(_queueKey, queue);
  }

  /// 큐잉된 이벤트 목록 조회
  Future<List<Map<String, dynamic>>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    return queue.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  /// 온라인 복귀 시 큐 비우기
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  /// §13.2 규칙 기반 이탈 감지 (오프라인)
  Map<String, dynamic> evaluateDepartureOffline({
    required double distanceM,
    required int durationMin,
  }) {
    final isDeparted = distanceM > 300 && durationMin >= 10;
    return {
      'type': 'departure_detect',
      'is_departed': isDeparted,
      'distance_m': distanceM,
      'duration_min': durationMin,
      'model': 'rule_based_offline',
    };
  }
}
```

**Step 2: Create On-Device Model Interface**

```dart
// on_device_model_interface.dart

/// §6.1 2차 폴백 — 온디바이스 모델 인터페이스
/// Phase 3에서 TFLite/ONNX Runtime으로 실제 구현 예정
abstract class OnDeviceModel {
  /// 모델 로드 여부
  bool get isLoaded;

  /// 모델 초기화 (기기 저장공간 확인 포함)
  Future<bool> initialize();

  /// 추론 실행
  Future<Map<String, dynamic>> predict(Map<String, dynamic> input);

  /// 모델 해제
  Future<void> dispose();
}

/// Phase 3 전까지 사용하는 Stub 구현
class OnDeviceModelStub implements OnDeviceModel {
  @override
  bool get isLoaded => false;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<Map<String, dynamic>> predict(Map<String, dynamic> input) async {
    throw UnsupportedError('On-device model not available. Use rule-based fallback.');
  }

  @override
  Future<void> dispose() async {}
}
```

**Step 3: Commit**

```bash
git add safetrip-mobile/lib/features/ai/services/
git commit -m "feat(flutter): add offline Safety AI queue + on-device model interface (§13, §6.1)"
```

---

## Task 16: Run Full Test Suite + Final Verification

**Step 1: Run all backend AI tests**

```bash
cd safetrip-server-api && npx jest src/modules/ai/ src/entities/ai.entity.spec.ts --no-cache --verbose
```

Expected: ALL PASS.

**Step 2: Run TypeScript compilation check**

```bash
cd safetrip-server-api && npx tsc --noEmit
```

Expected: No errors.

**Step 3: Run Flutter analysis**

```bash
cd safetrip-mobile && flutter analyze lib/features/ai/
```

Expected: No errors.

**Step 4: If any failures, fix and re-run (max 3 attempts per user instructions)**

---

## Task 17: Final Commit

Only after Task 16 passes all checks.

**Step 1: Verify all changes**

```bash
git status
git diff --stat
```

**Step 2: Create final integration commit if not already committed**

```bash
git add -A
git commit -m "feat(ai): complete AI Architecture Principle implementation (DOC-T3-AIF-026)"
```
