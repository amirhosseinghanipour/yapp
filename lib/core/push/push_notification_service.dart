import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

const String _channelId = 'messages';

class PushNotificationService {
  PushNotificationService({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _fcm = false;
  bool _localReady = false;
  bool _hadInitialMessage = false;
  StreamSubscription<String>? _tokenRefreshSub;

  bool get hadInitialMessage => _hadInitialMessage;

  void Function(String? chatId)? onTapChat;

  bool get available => _fcm;

  Future<void> init() async {
    await _initLocal();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _fcm = true;
    } catch (e) {
      debugPrint('push: Firebase not configured ($e); FCM off');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
    FirebaseMessaging.onMessageOpenedApp.listen((_) => onTapChat?.call(null));
    _hadInitialMessage =
        (await FirebaseMessaging.instance.getInitialMessage()) != null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
      _uploadToken,
    );
  }

  Future<void> _initLocal() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _local.initialize(
        settings,
        onDidReceiveNotificationResponse: (resp) =>
            onTapChat?.call(resp.payload),
      );
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          'Messages',
          description: 'New message notifications',
          importance: Importance.high,
        ),
      );
      await android?.requestNotificationsPermission();
      _localReady = true;
    } catch (e) {
      debugPrint('push: local notifications init failed: $e');
    }
  }

  Future<void> showMessage({
    required String chatId,
    required String title,
    required String body,
  }) async {
    if (!_localReady) return;
    try {
      await _local.show(
        chatId.hashCode & 0x7fffffff,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Messages',
            channelDescription: 'New message notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: chatId,
      );
    } catch (e) {
      debugPrint('push: show failed: $e');
    }
  }

  Future<void> clearChat(String chatId) async {
    if (!_localReady) return;
    try {
      await _local.cancel(chatId.hashCode & 0x7fffffff);
    } catch (_) {}
  }

  Future<void> registerToken() async {
    if (!_fcm) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _uploadToken(token);
    } catch (e) {
      debugPrint('push: getToken failed: $e');
    }
  }

  Future<void> _uploadToken(String token) async {
    try {
      await _client.rpc<void>(
        'register_push_token',
        params: <String, dynamic>{'p_token': token, 'p_platform': _platform()},
      );
    } catch (e) {
      debugPrint('push: register_push_token failed: $e');
    }
  }

  Future<void> clearLocalToken() async {
    if (!_fcm) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  String _platform() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
  }
}
