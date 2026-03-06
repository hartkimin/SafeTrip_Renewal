import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/auth_notifier.dart';
import '../../router/route_paths.dart';

/// Legacy demo screen — redirects to new scenario selection screen
class ScreenTripDemo extends StatefulWidget {
  const ScreenTripDemo({super.key, required this.authNotifier});
  final AuthNotifier authNotifier;

  @override
  State<ScreenTripDemo> createState() => _ScreenTripDemoState();
}

class _ScreenTripDemoState extends State<ScreenTripDemo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(RoutePaths.demoScenarioSelect);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
