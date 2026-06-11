import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/di/app_scope.dart';
import 'core/di/backend_factory.dart';
import 'core/push/notification_center.dart';
import 'core/push/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/entities/auth_session.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/messages/data/repositories/messenger_repository_supabase.dart'
    show IncomingMessage;
import 'features/messages/domain/entities/chat_summary.dart';
import 'features/messages/presentation/screens/chat_detail_screen.dart';
import 'features/settings/domain/entities/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  final runtime = await SupabaseRuntime.bootstrap();
  final push = PushNotificationService(client: runtime.client);
  await push.init();
  runApp(YappApp(runtime: runtime, push: push));
}

class YappApp extends StatefulWidget {
  const YappApp({super.key, required this.runtime, required this.push});

  final SupabaseRuntime runtime;
  final PushNotificationService push;

  @override
  State<YappApp> createState() => _YappAppState();
}

class _YappAppState extends State<YappApp> {
  late SessionRepos _repos;
  late Stream<AppSettings> _settingsStream;
  StreamSubscription<AuthSession?>? _sessionSub;
  StreamSubscription<IncomingMessage>? _incomingSub;
  AppSettings _settings = AppSettings.defaults;
  String? _boundAccountId;

  @override
  void initState() {
    super.initState();
    final session = widget.runtime.auth.currentSession;
    _repos = widget.runtime.buildSession(session);
    _settingsStream = _repos.settings.watch();
    _boundAccountId = session?.accountId;
    widget.push.onTapChat = _openChatFromNotification;
    currentOpenChatId.addListener(_clearOpenChatNotifications);
    if (widget.push.hadInitialMessage) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openChatFromNotification(null),
      );
    }
    unawaited(_warmUp(session));
    _sessionSub = widget.runtime.auth.watchSession().listen(_onSession);
  }

  void _onIncoming(IncomingMessage m) {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (currentOpenChatId.value == m.chatId) return;
    unawaited(
      widget.push.showMessage(
        chatId: m.chatId,
        title: m.senderName,
        body: m.preview,
      ),
    );
  }

  Future<void> _openChatFromNotification(String? chatId) async {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    final summaries = await _repos.messenger.getChatSummaries();
    ChatSummary? target;
    for (final s in summaries) {
      if (chatId != null ? s.id == chatId : s.unreadCount > 0) {
        target = s;
        break;
      }
    }
    if (target == null) return;
    final chat = target;
    unawaited(widget.push.clearChat(chat.id));
    unawaited(
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => ChatDetailScreen(chatId: chat.id, peer: chat.user),
        ),
      ),
    );
  }

  void _clearOpenChatNotifications() {
    final id = currentOpenChatId.value;
    if (id != null) unawaited(widget.push.clearChat(id));
  }

  Future<void> _onSession(AuthSession? session) async {
    if (session?.accountId == _boundAccountId) return;
    final signedOut = session == null && _boundAccountId != null;
    _boundAccountId = session?.accountId;
    final old = _repos;
    final next = widget.runtime.buildSession(session);
    setState(() {
      _repos = next;
      _settingsStream = next.settings.watch();
    });
    old.messenger.dispose();
    if (signedOut) await widget.push.clearLocalToken();
    await _warmUp(session);
  }

  Future<void> _warmUp(AuthSession? session) async {
    await _incomingSub?.cancel();
    _incomingSub = null;
    try {
      final loaded = await _repos.settings.load();
      if (mounted) setState(() => _settings = loaded);
      if (session != null) {
        await _repos.settings.syncBlockedFromServer();
        await _repos.messenger.ensureRelayStarted();
        await _repos.profile.getMyProfile(forceRefresh: true);
        _incomingSub = _repos.messenger.incomingMessages.listen(_onIncoming);
        unawaited(widget.push.registerToken());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    currentOpenChatId.removeListener(_clearOpenChatNotifications);
    _incomingSub?.cancel();
    _sessionSub?.cancel();
    _repos.messenger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      messengerRepository: _repos.messenger,
      profileRepository: _repos.profile,
      settingsRepository: _repos.settings,
      authRepository: widget.runtime.auth,
      child: StreamBuilder<AppSettings>(
        stream: _settingsStream,
        initialData: _settings,
        builder: (context, snapshot) {
          final snap = snapshot.data ?? _settings;
          return MaterialApp(
            title: 'Yapp',
            navigatorKey: appNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(wallpaper: snap.wallpaper),
            darkTheme: buildAppDarkTheme(wallpaper: snap.wallpaper),
            themeMode: snap.themeMode.toFlutter(),
            home: AuthGate(repository: widget.runtime.auth),
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(snap.fontScale.multiplier),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
