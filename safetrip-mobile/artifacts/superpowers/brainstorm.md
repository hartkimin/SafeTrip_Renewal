## Goal
Ensure the Flutter app's main screen (MainScreen) complies with the UI principles defined in 10_T2_??????.md.

## Constraints
- Must strictly follow the 3-layer architecture: Layer 1 (Map), Layer 2 (Bottom Sheet), Layer 3 (Top Overlay + SOS).
- Role-based visibility and privacy settings must be respected.
- Bottom sheet must support the 5 height stages (collapsed, peek, half, expanded, full).
- Must use existing Flutter/Firebase services without breaking them.

## Known context
- The current MainScreen (screens/main/screen_main.dart) uses a Stack but doesn't fully align with the layers.
- Top Bar Overlay lacks 'Country', 'D+N' info, and Alarm icon (currently has AI Briefing and Settings).
- SOS Button is embedded in the AppBottomNavigationBar instead of being a floating Layer 3 overlay.
- Only 2 tabs (Trip, Member) are implemented; principles dictate 4 (Schedule, Member, Chat, Safety Guide).

## Risks
- Refactoring the MainScreen might inadvertently break location tracking or Firebase marker updates if _firebaseLocationManager or _markerManager references get mangled.
- Managing 5 specific height states manually for the Bottom Sheet across 4 tabs is complex and error-prone.

## Options (2?4)
1. **Iterative Component Extraction**: Step-by-step refactoring of MainScreen. First, extract and fix TopBarOverlay and SosButtonOverlay. Then, add the missing tabs (Chat, Safety Guide) to the Bottom Navigation.
2. **Dedicated Sliding Panel Package**: Introduce a robust bottom sheet package (like sliding_up_panel) to easily manage the 5 height stages automatically, requiring a moderate rewrite of the layout tree.
3. **Complete V2 Rewrite**: Build a MainScreenV2 side-by-side with the old one, implementing the 3 strict layers and 4 tabs from scratch, then swap them once stable.

## Recommendation
**Option 1 (Iterative Component Extraction) combined with Option 2**. Use the iterative approach to avoid breaking existing state management while utilizing a sliding panel solution (or refining the current custom bottom sheet) to firmly establish the Layer 2 rules.

## Acceptance criteria
- MainScreen clearly defines Layer 1 (FlutterMap), Layer 2 (BottomSheet), Layer 3 (TopOverlay & SOS).
- Top overlay correctly displays Trip Name, Country, D+N, and Member Count.
- SOS button is always visible on top of everything (Layer 3, bottom right) for appropriate roles.
- Bottom sheet has 4 tabs: Schedule(??), Member(??), Chat(??), SafetyGuide(???).
