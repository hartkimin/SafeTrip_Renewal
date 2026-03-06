# Offline Principles Compliance Design (P0 + P1)

**Principles Document**: `Master_docs/16_T2_오프라인_동작_통합_원칙.md` (DOC-T2-OFL-016)
**Scope**: P0 (Phase 1) + P1 (Phase 2)
**Approach**: Incremental Enhancement — build on existing stack

---

## Gap Analysis

### Already Implemented
- Basic connectivity monitoring (`connectivity_plus`)
- Simple offline banner (no last sync time)
- SQLite queue for locations (`TB_OFFLINE_LOCATION`) and SOS (`TB_OFFLINE_SOS`)
- SOS offline queuing to SQLite
- Location offline queuing
- Auto-sync on reconnect (SOS first, then locations)
- Offline map tile caching

### P0 Gaps (Phase 1)
1. Three-state network detection (Online/Degraded/Offline) — §2
2. HTTP healthcheck (30s API ping, 3-fail threshold) — §2.2
3. Last sync time on offline banner — §8.1
4. SOS SMS fallback (telephony package) — §3.2
5. SOS local alarm (max volume) — §3.2
6. Emergency contacts local caching — §3.1
7. Safety guide pre-caching — §3.1

### P1 Gaps (Phase 2)
8. Chat queue table + service (100 msg, FIFO) — §5.3, §3.4
9. Location queue limits (72h/8,640, eviction) — §3.3
10. Full 6-stage sync priority — §4
11. Battery-based GPS interval adjustment — §7.1, §7.3
12. Privacy-level GPS intervals for offline — §10
13. Schedule draft table + conflict resolution — §5.4, §6
14. Cache meta table — §5.5
15. Feature-specific offline indicators — §8.2
16. Sync completion toast notifications — §8.3, §4.2

---

## Design Decisions

### 1. Enhanced Network Detection (§2)
- Enhance `connectivity_provider.dart`
- New enum: `NetworkState { online, degraded, offline }`
- Add HTTP healthcheck to `/api/v1/health` (30s interval, 5s timeout)
- Consecutive failure counter: 2 fails → degraded, 3 fails → offline
- Recovery: 1 success → online (immediate), 2 success from degraded → online
- New Riverpod provider: `networkStateProvider` (replaces `isOfflineProvider`)
- Store `lastSyncTime` in SharedPreferences

### 2. SQLite Schema Extension (§5)
- Add 3 new tables: `local_chat_queue`, `local_schedule_draft`, `local_cache_meta`
- Location queue: enforce 8,640 record limit with oldest-first eviction
- Chat queue: enforce 100 message limit
- 72-hour expiration cleanup on each sync cycle

### 3. SOS Offline Fallback (§3.2)
- Add `telephony` or `flutter_sms` package for SMS sending
- Offline SOS flow: SMS → alarm → queue → display emergency numbers
- Handle SMS permission denial gracefully
- Add `flutter_ringtone_player` or `audioplayers` for local alarm

### 4. 6-Stage Sync Priority Engine (§4)
- Priority 1: SOS → Priority 2: Guardian → Priority 3: Locations (100-batch)
- Priority 4: Schedule drafts → Priority 5: Chat → Priority 6: Events
- Each stage independent — failure doesn't block next stage
- Sync state tracked in `tb_sync_queue_offline` (or existing tables' is_synced flags)

### 5. Battery-aware GPS Intervals (§7)
- New `battery_gps_manager.dart` service
- Listen to `battery_plus` for level changes
- Privacy level × network state matrix from §7.1
- Battery thresholds: <20% → 2x interval, <10% → 4x, <5% → SOS-only

### 6. UI Enhancements (§8)
- Offline banner: show last sync time, degraded state message, queue full warning
- Sync completion toast: "{N}건 동기화 완료" or "일부 실패. 재시도 중..."
- Chat: "⏳ 전송 대기 중" indicator for queued messages

### 7. Emergency Contacts & Safety Guide Caching (P0)
- New `emergency_cache_service.dart`
- Cache emergency contacts to `local_cache_meta` on trip activation
- Cache safety guide per country_code
- Serve from cache when offline; refresh on online session start

### 8. Chat Queuing (P1)
- Queue outgoing messages to `local_chat_queue` when offline
- 100 message limit; show warning when full
- FIFO delivery on reconnect (Priority 5)

---

## Files to Modify/Create

### Modify
- `lib/features/main/providers/connectivity_provider.dart` — 3-state detection
- `lib/services/offline_sync_service.dart` — new tables, limits, 6-stage sync
- `lib/services/sos_service.dart` — SMS fallback, local alarm
- `lib/services/location_service.dart` — battery/privacy GPS intervals
- `lib/services/device_status_service.dart` — integrate new network state
- `lib/widgets/components/offline_banner.dart` — enhanced UI
- `lib/screens/main/screen_main.dart` — use networkStateProvider

### Create
- `lib/services/battery_gps_manager.dart` — battery-aware GPS intervals
- `lib/services/emergency_cache_service.dart` — contacts & guide caching

### Dependencies (pubspec.yaml)
- Already present: `connectivity_plus`, `sqflite`, `battery_plus`
- May need: SMS sending package (or use url_launcher for tel:)
