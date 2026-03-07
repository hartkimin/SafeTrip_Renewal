import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeeplinkService {
  static final DeeplinkService instance = DeeplinkService._();
  DeeplinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  String? pendingInviteCode;
  String? pendingGuardianCode;

  /// §6.1: Tracks whether an invite deeplink URI was received (regardless of parse success)
  bool inviteDeeplinkReceived = false;

  /// Callback for warm-start deep link events
  void Function(String type, String value)? onDeepLink;

  /// Initialize and listen for deep links
  Future<void> init() async {
    // Check initial link (cold start)
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleUri(uri);
    } catch (e) {
      debugPrint('[DeeplinkService] getInitialLink error: $e');
    }

    // Listen for links while app is running (warm start)
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (e) => debugPrint('[DeeplinkService] stream error: $e'),
    );
  }

  void _handleUri(Uri uri) {
    debugPrint('[DeeplinkService] Received URI: $uri');

    // safetrip://invite?code=ABC123
    // https://safetrip.app/invite/ABC123
    if (uri.host == 'invite' || uri.pathSegments.contains('invite')) {
      inviteDeeplinkReceived = true; // §6.1: track URI receipt regardless of parse
      final code = uri.queryParameters['code'] ??
          (uri.pathSegments.length > 1 ? uri.pathSegments.last : null);
      if (code != null) {
        pendingInviteCode = code;
        debugPrint('[DeeplinkService] Invite code captured: $code');
        onDeepLink?.call('invite', code);
      } else {
        debugPrint('[DeeplinkService] Invite URI received but code parse failed: $uri');
      }
    }

    // safetrip://guardian?link_id=456
    // https://safetrip.app/guardian/456
    if (uri.host == 'guardian' || uri.pathSegments.contains('guardian')) {
      final linkId = uri.queryParameters['link_id'] ??
          (uri.pathSegments.length > 1 ? uri.pathSegments.last : null);
      if (linkId != null) {
        pendingGuardianCode = linkId;
        debugPrint('[DeeplinkService] Guardian link captured: $linkId');
        onDeepLink?.call('guardian', linkId);
      }
    }
  }

  void clearInviteCode() => pendingInviteCode = null;
  void clearGuardianCode() => pendingGuardianCode = null;

  void dispose() {
    _sub?.cancel();
  }
}
