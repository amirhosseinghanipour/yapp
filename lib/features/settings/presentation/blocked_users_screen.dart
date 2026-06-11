import 'package:flutter/material.dart';

import '../../../core/di/app_scope.dart';
import '../../messages/domain/entities/user.dart';
import '../../messages/domain/repositories/messenger_repository.dart';
import '../../messages/presentation/yapp_design.dart';
import '../../../core/theme/yapp_palette.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/blocked_user.dart';
import '../domain/repositories/settings_repository.dart';
import 'widgets/yapp_confirm_sheet.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  SettingsRepository? _settings;
  MessengerRepository? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = AppScope.settingsOf(context);
    _messenger = AppScope.of(context);
  }

  Future<void> _addBlock() async {
    final messenger = _messenger;
    final settings = _settings;
    if (messenger == null || settings == null) return;
    final users = await messenger.getContactableUsers();
    final blocked = (await settings.load()).blocked.map((b) => b.id).toSet();
    final candidates = users
        .where((u) => !blocked.contains(u.id))
        .toList(growable: false);
    if (!mounted) return;

    final picked = await showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => _YappPickUserSheet(users: candidates),
    );
    if (picked == null) return;
    await settings.blockUser(BlockedUser(id: picked.id, name: picked.name));
    if (!mounted) return;
    _toast('${picked.name.toLowerCase()} is now blocked.');
  }

  Future<void> _confirmUnblock(BlockedUser user) async {
    final settings = _settings;
    if (settings == null) return;
    final ok = await showYappConfirmSheet(
      context,
      headline: 'unblock ${user.name.toLowerCase()}?',
      body:
          'they will be able to message you again and see your last seen '
          'according to your privacy settings.',
      primaryLabel: 'unblock',
    );
    if (ok != true) return;
    await settings.unblockUser(user.id);
    if (!mounted) return;
    _toast('${user.name.toLowerCase()} unblocked.');
  }

  void _toast(String msg) {
    final pal = YappPalette.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: Yapp.cta(color: pal.paper)),
          backgroundColor: pal.ink,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<AppSettings>(
          stream: _settings?.watch(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final blocked = snap.data!.blocked;
            return Column(
              children: [
                _YappTopBar(
                  title: 'blocked',
                  trailing: _AddBlockButton(onTap: _addBlock),
                ),
                Expanded(
                  child: blocked.isEmpty
                      ? _EmptyState(onAdd: _addBlock)
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: blocked.length + 1,
                          itemBuilder: (_, i) {
                            if (i == blocked.length) {
                              return Container(
                                height: Yapp.hairline,
                                color: pal.ink,
                              );
                            }
                            return _BlockedRow(
                              user: blocked[i],
                              onUnblock: () => _confirmUnblock(blocked[i]),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _YappTopBar extends StatelessWidget {
  const _YappTopBar({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border(
          bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: YappGlyph.back(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Yapp.display().copyWith(fontSize: 28, height: 1.05),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _AddBlockButton extends StatefulWidget {
  const _AddBlockButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AddBlockButton> createState() => _AddBlockButtonState();
}

class _AddBlockButtonState extends State<_AddBlockButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final bg = _pressed ? pal.paper : pal.ink;
    final fg = _pressed ? pal.ink : pal.paper;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: pal.ink, width: 1),
        ),
        child: Text(
          'block  +',
          style: Yapp.cta(color: fg).copyWith(fontSize: 13),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'no one is\nblocked.',
            style: Yapp.display().copyWith(fontSize: 40, height: 1.0),
          ),
          const SizedBox(height: 12),
          Text(
            'blocked people can’t message you or see when you’re online.',
            style: Yapp.body(color: pal.gray2),
          ),
          const SizedBox(height: 28),
          _StampWideButton(label: 'block someone  →', onTap: onAdd),
        ],
      ),
    );
  }
}

class _StampWideButton extends StatefulWidget {
  const _StampWideButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_StampWideButton> createState() => _StampWideButtonState();
}

class _StampWideButtonState extends State<_StampWideButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final bg = _pressed ? pal.paper : pal.ink;
    final fg = _pressed ? pal.ink : pal.paper;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: pal.ink, width: 1),
        ),
        child: Text(widget.label, style: Yapp.cta(color: fg)),
      ),
    );
  }
}

class _BlockedRow extends StatefulWidget {
  const _BlockedRow({required this.user, required this.onUnblock});

  final BlockedUser user;
  final VoidCallback onUnblock;

  @override
  State<_BlockedRow> createState() => _BlockedRowState();
}

class _BlockedRowState extends State<_BlockedRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onUnblock,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.fromLTRB(20 - Yapp.tickWidth, 14, 20, 14),
        decoration: BoxDecoration(
          color: _pressed ? pal.pressWash : pal.paper,
          border: Border(
            left: BorderSide(
              color: _pressed ? pal.ink : Colors.transparent,
              width: Yapp.tickWidth,
            ),
            bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.user.name.toLowerCase(),
                style: Yapp.name(color: pal.ink),
              ),
            ),
            Text(
              'unblock',
              style: Yapp.cta(color: pal.alert).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _YappPickUserSheet extends StatefulWidget {
  const _YappPickUserSheet({required this.users});
  final List<User> users;

  @override
  State<_YappPickUserSheet> createState() => _YappPickUserSheetState();
}

class _YappPickUserSheetState extends State<_YappPickUserSheet> {
  String _query = '';
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final filtered = _query.isEmpty
        ? widget.users
        : widget.users
              .where((u) => u.name.toLowerCase().contains(_query.toLowerCase()))
              .toList(growable: false);

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, controller) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'block someone',
                      style: Yapp.display().copyWith(
                        fontSize: 28,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedContainer(
                      duration: Yapp.dur,
                      curve: Yapp.curve,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _focus.hasFocus ? pal.ink : pal.gray3,
                            width: _focus.hasFocus ? 2 : Yapp.hairline,
                          ),
                        ),
                      ),
                      child: TextField(
                        focusNode: _focus,
                        cursorColor: pal.ink,
                        style: Yapp.name(),
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'search contacts',
                          hintStyle: Yapp.name(color: pal.gray3),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                        child: Text(
                          'no matching contacts.',
                          style: Yapp.body(color: pal.gray2),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: EdgeInsets.zero,
                        itemCount: filtered.length + 1,
                        itemBuilder: (_, i) {
                          if (i == filtered.length) {
                            return Container(
                              height: Yapp.hairline,
                              color: pal.ink,
                            );
                          }
                          final u = filtered[i];
                          return _PickRow(
                            user: u,
                            onTap: () => Navigator.of(ctx).pop(u),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PickRow extends StatefulWidget {
  const _PickRow({required this.user, required this.onTap});
  final User user;
  final VoidCallback onTap;

  @override
  State<_PickRow> createState() => _PickRowState();
}

class _PickRowState extends State<_PickRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final bg = _pressed ? pal.alert : pal.paper;
    final fg = _pressed ? pal.paper : pal.ink;
    final hint = _pressed ? pal.paper : pal.alert;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(color: pal.ink, width: Yapp.hairline),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.user.name.toLowerCase(),
                style: Yapp.name(color: fg),
              ),
            ),
            Text(
              'block  →',
              style: Yapp.cta(color: hint).copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
