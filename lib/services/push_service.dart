import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'api.dart';

bool _initialized = false;

/// Initialise Firebase Messaging and register the device token.
/// Safe to call multiple times — only the first call does real work.
Future<void> initPush() async {
  if (_initialized) return;
  _initialized = true;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS / web)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Register token
    await _registerToken(messaging);

    // Re-register on token refresh
    messaging.onTokenRefresh.listen((token) => _registerToken(messaging));

    // Foreground messages
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('FCM foreground: ${msg.notification?.title}');
    });
  } catch (_) {
    // Firebase not configured — ignore.
  }
}

Future<void> _registerToken(FirebaseMessaging messaging) async {
  try {
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;
    final platform = kIsWeb ? 'web' : 'android';
    await Api.registerDeviceToken(token, platform);
  } catch (_) {}
}
