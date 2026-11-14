import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class RestNotifier {
  Future<bool> initialize();

  Future<bool> requestPermission();

  Future<bool> permissionGranted();

  Future<void> schedule({required DateTime firesAt});

  Future<void> showRestComplete();

  Future<void> cancelRest();
}

class RestNotificationService implements RestNotifier {
  RestNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int restNotificationId = 7301;
  static const String channelId = 'dev.klugesbuch.altaria.rest';
  static const String channelName = 'Rest timer';
  static const String channelDescription =
      'Alerts when a strength-training rest timer ends.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _channelReady = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      ticker: 'Rest over',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentSound: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.active,
    ),
  );

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      tz_data.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      final result = await _plugin.initialize(settings);
      _initialized = result ?? false;
      await _ensureChannel();
      return _initialized;
    } catch (error) {
      debugPrint('altaria rest notifications: $error');
      _initialized = false;
      return false;
    }
  }

  Future<void> _ensureChannel() async {
    if (_channelReady || !_initialized) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _channelReady = true;
      return;
    }
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              description: channelDescription,
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
              showBadge: false,
            ),
          );
      _channelReady = true;
    } catch (error) {
      debugPrint('altaria rest channel: $error');
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!await initialize()) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      }
    } catch (error) {
      debugPrint('altaria rest permission: $error');
    }
    return false;
  }

  @override
  Future<bool> permissionGranted() async {
    if (!await initialize()) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ??
            false;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final options = await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions();
        return options?.isEnabled ?? options?.isProvisionalEnabled ?? false;
      }
    } catch (error) {
      debugPrint('altaria rest permission status: $error');
    }
    return false;
  }

  @override
  Future<void> schedule({required DateTime firesAt}) async {
    if (!await initialize()) return;
    await _ensureChannel();
    final now = DateTime.now();
    if (!firesAt.isAfter(now.add(const Duration(milliseconds: 500)))) {
      return;
    }
    try {
      await _plugin.cancel(restNotificationId);
      await _plugin.zonedSchedule(
        restNotificationId,
        'Rest over',
        'Start the next set. Music keeps playing.',
        tz.TZDateTime.from(firesAt, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (error) {
      debugPrint('altaria rest schedule: $error');
    }
  }

  @override
  Future<void> showRestComplete() async {
    if (!await initialize()) return;
    await _ensureChannel();
    try {
      await _plugin.cancel(restNotificationId);
      await _plugin.show(
        restNotificationId,
        'Rest over',
        'Start the next set. Music keeps playing.',
        _details,
      );
    } catch (error) {
      debugPrint('altaria rest alert: $error');
    }
  }

  @override
  Future<void> cancelRest() async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(restNotificationId);
    } catch (error) {
      debugPrint('altaria rest cancel: $error');
    }
  }
}

class NoopRestNotifier implements RestNotifier {
  NoopRestNotifier({this.granted = false});

  bool granted;
  final List<DateTime> scheduled = [];
  int cancellations = 0;
  int completions = 0;

  @override
  Future<void> cancelRest() async {
    cancellations++;
  }

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> schedule({required DateTime firesAt}) async {
    scheduled.add(firesAt);
  }

  @override
  Future<void> showRestComplete() async {
    completions++;
  }
}
