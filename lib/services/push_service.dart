import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import 'notification_service.dart';

/// Background isolate handler for data/notification messages. Must be a
/// top-level function annotated for release tree-shaking.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised in the background isolate too.
  await Firebase.initializeApp();
  await _showFrom(message);
}

Future<void> _showFrom(RemoteMessage message) async {
  final n = message.notification;
  final title = n?.title ?? message.data['title'] ?? 'Alert';
  final body = n?.body ?? message.data['body'] ?? '';
  if (body.isEmpty) return;
  await NotificationService.instance.showPriceAlert(
    id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
    title: title,
    body: body,
  );
}

/// Wraps Firebase Cloud Messaging: initialisation, permission, the device
/// token, and rendering pushes as local notifications.
///
/// Entirely inert when [AppConfig.pushEnabled] is false, so the app builds and
/// runs without a Firebase project until push is configured.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  String? _token;
  String? get token => _token;

  final List<void Function(String token)> _tokenListeners = [];

  /// Called whenever the FCM token becomes available or refreshes.
  void onToken(void Function(String token) cb) => _tokenListeners.add(cb);

  Future<void> init() async {
    if (!AppConfig.pushEnabled) return;
    try {
      await Firebase.initializeApp();

      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      // Foreground messages don't auto-display on Android; show them ourselves.
      FirebaseMessaging.onMessage.listen(_showFrom);

      _token = await messaging.getToken();
      if (_token != null) _emit(_token!);

      messaging.onTokenRefresh.listen((t) {
        _token = t;
        _emit(t);
      });
    } catch (e) {
      debugPrint('[push] init failed (is google-services.json present?): $e');
    }
  }

  void _emit(String token) {
    for (final cb in _tokenListeners) {
      cb(token);
    }
  }
}
