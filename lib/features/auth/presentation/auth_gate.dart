import 'package:flutter/material.dart';

import '../../../core/presentation/home_shell.dart';
import '../../messages/presentation/yapp_design.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';
import 'onboarding_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.repository});

  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      stream: repository.watchSession(),
      initialData: repository.currentSession,
      builder: (context, snap) {
        final child = snap.data == null
            ? OnboardingScreen(repository: repository)
            : const HomeShell();
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Yapp.curve,
          switchOutCurve: Yapp.curve,
          child: KeyedSubtree(
            key: ValueKey(snap.data == null ? 'signed-out' : 'signed-in'),
            child: child,
          ),
        );
      },
    );
  }
}
