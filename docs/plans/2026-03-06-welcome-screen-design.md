# Welcome Screen Full-Spec Implementation Design

**Date**: 2026-03-06
**Spec**: DOC-T3-WLC-029 v1.2
**Approach**: Incremental Enhancement (Approach A)
**Scope**: P0~P3 Full Spec

---

## Gap Analysis Summary

### Already Working (60~70%)
- 4-slide carousel with correct colors/copy
- Skip button, dot indicators
- Purpose Selection 4 buttons
- Phase 1 routing (new/returning user)
- Deep link service infrastructure

### Gaps to Fill
| Gap | Priority | Effort |
|-----|----------|--------|
| Deep link → Phase 3 direct (not authPhone) | P0 | Small |
| 5-second auto-advance timer | P1 | Small |
| Onboarding image assets (replace emojis) | P1 | Medium |
| Time-of-day color overlay (§3.2.1) | P2 | Medium |
| Parallax scroll effect (§3.4) | P2 | Medium |
| Accessibility: Semantics, reduced-motion | P2 | Medium |
| Guardian direct entry completion | P2 | Small |
| A/B test infrastructure (§3.6) | P3 | Medium |
| i18n: EN/JP strings (§3.7) | P3 | Medium |
| Analytics events (§7.3) | P3 | Medium |

---

## Architecture

### File Changes

**Modified files:**
1. `screen_welcome.dart` — Major: auto-timer, parallax, time-color, a11y, i18n, A/B, analytics
2. `screen_purpose_select.dart` — Medium: a11y, i18n, analytics
3. `app_router.dart` — Small: deep link routing fix
4. `app_colors.dart` — Small: time-of-day color constants

**New files:**
1. `welcome_slide_page.dart` — Extracted slide widget with parallax
2. `welcome_dot_indicator.dart` — 1.5x scale dot indicator per spec
3. `welcome_strings.dart` — 3-language copy map
4. `analytics_service.dart` — Welcome analytics events
5. `ab_test_service.dart` — Device ID hash-based variant assignment

### Key Design Decisions

1. **Timer resets on manual swipe** — prevents confusing jump after user interaction
2. **Parallax via Transform.translate** — lightweight, no external packages needed
3. **Time-of-day as overlay** — preserves slide brand colors, adds tinted overlay only
4. **i18n via locale map** — simple Map<String, Map> structure, no heavy i18n framework needed for 3 screens
5. **A/B via device ID hash** — consistent variant per device, no server call needed
6. **Analytics via abstract service** — can plug Firebase Analytics later, starts with debug logging

---

## Implementation Phases

### Phase 1 (P0): Core Routing Fix
- Fix deep link → Phase 3 direct routing
- Ensure Phase 1 context detection matches spec exactly

### Phase 2 (P1): Slide Enhancement
- Add 5-second auto-advance timer
- Replace emojis with actual image assets (or enhanced illustrations)
- Extract slide widget for better structure

### Phase 3 (P2): Polish & Accessibility
- Time-of-day color overlay system
- Parallax scroll effect
- Full WCAG 2.1 AA compliance (Semantics, reduced-motion, contrast)
- Guardian direct entry path completion

### Phase 4 (P3): Advanced Features
- i18n: English and Japanese strings
- A/B test infrastructure
- Analytics events (welcome_view, slide_viewed, slide_skipped, purpose_selected)

---

## Verification Checklist (from spec §10)

All 12 items from the spec will be verified in 5 iterative rounds.
