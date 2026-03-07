import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../managers/map_camera_transition_manager.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/main/providers/connectivity_provider.dart';
import '../../features/main/providers/main_screen_provider.dart';
import '../../widgets/components/offline_banner.dart';
import 'bottom_sheets/bottom_sheet_1_trip.dart';
import '../../features/safety_guide/presentation/safety_guide_bottom_sheet.dart';
import 'bottom_sheets/bottom_sheet_guardian_members.dart';
import 'bottom_sheets/snapping_bottom_sheet.dart';
import 'navigation/bottom_navigation_bar.dart';
import 'widgets/top_trip_info_card.dart';

/// 가디언 전용 메인 화면 (화면구성원칙 §6.3)
///
/// 3탭 구조: 내 담당 멤버 / 일정(읽기 전용) / 안전가이드
/// SOS 버튼 없음, 채팅 탭 없음
class MainGuardianScreen extends ConsumerStatefulWidget {
  const MainGuardianScreen({super.key});

  @override
  ConsumerState<MainGuardianScreen> createState() => _MainGuardianScreenState();
}

class _MainGuardianScreenState extends ConsumerState<MainGuardianScreen> {
  final MapController _mapController = MapController();
  BottomTab _currentTab = BottomTab.member;
  late final MapCameraTransitionManager _cameraTransitionManager;

  @override
  void initState() {
    super.initState();
    _cameraTransitionManager = MapCameraTransitionManager(
      getMapController: () => _mapController,
    );
  }

  @override
  void dispose() {
    _cameraTransitionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStateProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Layer 1: Map
            FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(37.5665, 126.9780),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.urock.safe.trip',
                ),
              ],
            ),

            // Layer 2: Top Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: AppSpacing.md,
              right: AppSpacing.md,
              child: const TopTripInfoCard(),
            ),

            // Layer 3: Snapping Bottom Sheet
            SnappingBottomSheet(
              initialLevel: BottomSheetLevel.half,
              onLevelChanged: (level) {
                ref.read(mainScreenProvider.notifier).setSheetLevel(level);
              },
              builder: (context, scrollController) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buildTabContent(scrollController),
                );
              },
            ),

            // Layer 4: Bottom Navigation (guardian mode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNavigationBar(
                currentTab: _currentTab,
                onTabChanged: (tab) {
                  // 가디언은 chat 탭 접근 불가
                  if (tab == BottomTab.chat) return;
                  setState(() => _currentTab = tab);
                },
                isGuardian: true,
              ),
            ),

            // Offline Banner
            if (!networkStatus.isOnline)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: OfflineBanner(status: networkStatus),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(ScrollController scrollController) {
    switch (_currentTab) {
      case BottomTab.member:
        return BottomSheetGuardianMembers(
          key: const ValueKey('guardian_members'),
          scrollController: scrollController,
        );
      case BottomTab.trip:
        return BottomSheetTrip(
          key: const ValueKey('trip_readonly'),
          scrollController: scrollController,
        );
      case BottomTab.guide:
        return SafetyGuideBottomSheet(
          key: const ValueKey('guide'),
          scrollController: scrollController,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('앱 종료'),
        content: const Text('SafeTrip을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    // Note: actual app exit would need SystemNavigator.pop()
    if (shouldExit == true && mounted) {
      // Let the system handle back navigation
    }
  }
}
