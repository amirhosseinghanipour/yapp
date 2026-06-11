import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/messages/presentation/screens/messages_list_screen.dart';
import '../../features/profile/domain/entities/my_profile.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../di/app_scope.dart';
import '../theme/yapp_palette.dart';
import 'app_menu_drawer.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  StreamSubscription<MyProfile>? _profileSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final SettingsRepository settings = AppScope.settingsOf(context);
      () async {
        try {
          await settings.load();
        } catch (_) {}
      }();

      final messenger = AppScope.of(context);
      _profileSub = AppScope.profileOf(context)
          .watchProfile()
          .skip(1)
          .listen((_) => unawaited(messenger.announceProfileToActiveChats()));
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: YappPalette.of(context).paper,
      drawer: const AppMenuDrawer(),
      drawerEdgeDragWidth: 48,
      body: const MessagesListScreen(),
    );
  }
}
