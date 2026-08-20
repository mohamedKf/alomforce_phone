// push.dart — notifications on the phone.
//
// Firebase is used for one thing only: waking this app when the server has
// something to say. No analytics, no crash reporting, no other Firebase
// product is initialised.
//
// The token is registered against the signed-in user and removed on sign-out,
// because a phone handed to the next shift must stop notifying whoever had it
// before. That is the same reason the server keys tokens by device rather
// than by person.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';

/// Handles a message that arrives while the app is not running.
///
/// Must be a top-level function: Android spins up a separate isolate for it,
/// which has none of the app's state. Firebase draws the notification itself
/// in this case, so there is nothing to do here but exist.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class Push {
  Push._();
  static final Push instance = Push._();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _token;

  /// Android needs a channel before anything can be shown. Importance.high is
  /// what makes a notification appear as a heads-up banner rather than sliding
  /// silently into the drawer -- these are "your order is ready", not news.
  static const _channel = AndroidNotificationChannel(
    'alomforce_default',
    'AlomForce',
    description: 'Orders, deliveries and the clock.',
    importance: Importance.high,
  );

  /// Called once at startup. Safe to call when Firebase is not configured --
  /// it gives up quietly rather than taking the app down with it.
  Future<void> start() async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      await _local.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested explicitly below, once the user is signed
          // in, rather than on the very first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // A message arriving while someone is looking at the app draws nothing
      // by itself -- Firebase only renders a notification in the background.
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _token = token;
        _register(token);
      });
      _ready = true;
    } catch (e) {
      // A missing google-services.json, an emulator with no Play Services, a
      // build that was never configured: none of these should stop the app
      // from working, they only mean no notifications.
      debugPrint('Push unavailable: $e');
    }
  }

  /// Ask for permission and register this device. Call after signing in.
  ///
  /// Asking here rather than at first launch is deliberate: a permission
  /// prompt makes sense once somebody has an account and something to be
  /// notified about, and Android only lists the app in Settings after it has
  /// been asked at least once.
  Future<void> registerForUser() async {
    if (!_ready) await start();
    if (!_ready) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await _register(token);
    } catch (e) {
      debugPrint('Could not register for push: $e');
    }
  }

  Future<void> _register(String token) async {
    try {
      await api.post('/devices/', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (e) {
      // Not fatal: the app works, this phone just will not be notified.
      debugPrint('Device registration failed: $e');
    }
  }

  /// Stop notifying this device. Called on sign-out, before the token is lost.
  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;
    try {
      await api.delete('/devices/', {'token': token});
    } catch (_) {
      // The server also drops tokens Firebase rejects, so a failure here is
      // recoverable rather than permanent.
    }
    _token = null;
  }

  void _showForeground(RemoteMessage message) {
    final note = message.notification;
    if (note == null) return;
    _local.show(
      note.hashCode,
      note.title,
      note.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}

final push = Push.instance;
