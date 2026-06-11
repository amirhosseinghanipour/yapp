import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/app_scope.dart';
import '../../../../core/theme/yapp_palette.dart';
import '../../../settings/domain/entities/blocked_user.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../settings/presentation/widgets/yapp_confirm_sheet.dart';
import '../../domain/entities/chat_summary.dart';
import '../../domain/entities/user.dart';
import '../../domain/utils/last_seen_format.dart';
import '../../domain/repositories/messenger_repository.dart';
import '../widgets/delete_message_sheet.dart';
import '../widgets/peer_avatar.dart';
import '../yapp_design.dart';

enum ChatInfoIntent { openSearch }

class ChatInfoScreen extends StatefulWidget {
  const ChatInfoScreen({super.key, required this.chatId, required this.peer});

  final String chatId;
  final User peer;

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  MessengerRepository? _repo;
  SettingsRepository? _settings;
  ChatSummary? _summary;
  bool _blocked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.of(context);
    final settings = AppScope.settingsOf(context);
    final changed = !identical(_repo, repo) || !identical(_settings, settings);
    if (changed) {
      _repo = repo;
      _settings = settings;
      _load();
    }
  }

  Future<void> _load() async {
    final summaries = await _repo!.getChatSummaries();
    final blocked = _settings?.isBlocked(widget.peer.id) ?? false;
    if (!mounted) return;
    setState(() {
      _summary = summaries.firstWhere(
        (s) => s.id == widget.chatId,
        orElse: () => ChatSummary(
          id: widget.chatId,
          user: widget.peer,
          lastMessage: '',
          timestamp: DateTime.now(),
          unreadCount: 0,
        ),
      );
      _blocked = blocked;
    });
  }

  Future<void> _toggleBlocked() async {
    final s = _settings;
    if (s == null) return;
    HapticFeedback.selectionClick();
    final first = widget.peer.name.split(' ').first.toLowerCase();
    if (_blocked) {
      await s.unblockUser(widget.peer.id);
    } else {
      final ok = await showYappConfirmSheet(
        context,
        headline: 'block $first?',
        body: 'they won\'t be able to reach you until you unblock.',
        primaryLabel: 'block',
        destructive: true,
      );
      if (ok != true) return;
      await s.blockUser(
        BlockedUser(id: widget.peer.id, name: widget.peer.name),
      );
    }
    if (!mounted) return;
    setState(() => _blocked = !_blocked);
  }

  Future<void> _toggleMute() async {
    final s = _summary;
    if (s == null) return;
    HapticFeedback.selectionClick();
    await _repo!.setMuted(chatId: s.id, muted: !s.isMuted);
    setState(() => _summary = s.copyWith(isMuted: !s.isMuted));
  }

  Future<void> _togglePin() async {
    final s = _summary;
    if (s == null) return;
    HapticFeedback.selectionClick();
    final ok = await _repo!.setPinned(chatId: s.id, pinned: !s.isPinned);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'pin limit reached · max '
              '${MessengerRepository.pinnedChatLimit}',
            ),
          ),
        );
      return;
    }
    setState(() => _summary = s.copyWith(isPinned: !s.isPinned));
  }

  Future<void> _deleteChat() async {
    final first = widget.peer.name.split(' ').first;
    final choice = await showDeleteChatSheet(context, peerName: first);
    if (choice == null || !mounted) return;
    await _repo!.deleteChat(
      chatId: widget.chatId,
      forEveryone: choice.forEveryone,
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final peer = widget.peer;
    final summary = _summary;
    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(onBack: () => Navigator.of(context).maybePop()),
            ),
            SliverToBoxAdapter(child: _Hero(peer: peer)),
            SliverToBoxAdapter(
              child: _ActionStrip(
                onMessage: () => Navigator.of(context).maybePop(),
                onSearch: () => Navigator.of(
                  context,
                ).maybePop<ChatInfoIntent>(ChatInfoIntent.openSearch),
                onMute: _toggleMute,
                muted: summary?.isMuted ?? false,
              ),
            ),
            const SliverToBoxAdapter(
              child: YappSectionLabel('info', topSpace: 24),
            ),
            if (peer.username != null && peer.username!.isNotEmpty)
              SliverToBoxAdapter(
                child: _InfoRow(
                  label: 'handle',
                  value: '@${peer.username}',
                  copyable: true,
                ),
              ),
            if (peer.bio != null && peer.bio!.isNotEmpty)
              SliverToBoxAdapter(
                child: _InfoRow(label: 'bio', value: peer.bio!),
              ),
            const SliverToBoxAdapter(
              child: YappSectionLabel('settings', topSpace: 28),
            ),
            SliverToBoxAdapter(
              child: _SwitchRow(
                label: 'mute notifications',
                value: summary?.isMuted ?? false,
                onTap: _toggleMute,
              ),
            ),
            SliverToBoxAdapter(
              child: _SwitchRow(
                label: 'pin conversation',
                value: summary?.isPinned ?? false,
                onTap: _togglePin,
              ),
            ),
            const SliverToBoxAdapter(
              child: YappSectionLabel('danger', topSpace: 28),
            ),
            SliverToBoxAdapter(
              child: _DangerRow(
                label: _blocked
                    ? 'unblock ${peer.name.split(' ').first.toLowerCase()}'
                    : 'block ${peer.name.split(' ').first.toLowerCase()}',
                onTap: _toggleBlocked,
              ),
            ),
            SliverToBoxAdapter(
              child: _DangerRow(label: 'delete chat', onTap: _deleteChat),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      height: 72,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: YappGlyph.back(),
            ),
          ),
          const SizedBox(width: 10),
          Text('info', style: Yapp.display().copyWith(fontSize: 24)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.peer});
  final User peer;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final hasHandle = peer.username != null && peer.username!.isNotEmpty;
    final initial = peer.name.trim().isEmpty
        ? '?'
        : peer.name.trim().characters.first.toUpperCase();
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
            ),
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: pal.gray4,
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: Yapp.display(
                      color: pal.gray3,
                    ).copyWith(fontSize: 160),
                  ),
                ),
                Positioned.fill(child: PeerAvatar(user: peer)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: pal.ink,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          peer.name.toLowerCase(),
                          style: Yapp.display(
                            color: pal.paper,
                          ).copyWith(fontSize: 34, height: 1),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: Yapp.dirFor(peer.name),
                        ),
                        if (hasHandle) ...[
                          const SizedBox(height: 8),
                          Text(
                            '@${peer.username}',
                            style: Yapp.body(
                              color: pal.gray3,
                            ).copyWith(fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                color: peer.isOnline ? pal.ink : pal.gray3,
              ),
              const SizedBox(width: 10),
              Text(
                formatLastSeenLabel(
                  isOnline: peer.isOnline,
                  lastSeenAt: peer.lastSeenAt,
                ),
                style: Yapp.body(color: pal.gray2).copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.onMessage,
    required this.onSearch,
    required this.onMute,
    required this.muted,
  });

  final VoidCallback onMessage;
  final VoidCallback onSearch;
  final VoidCallback onMute;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: _QuietActionCell(label: 'message', onTap: onMessage),
          ),
          Container(width: Yapp.hairline, color: pal.gray4),
          Expanded(
            child: _QuietActionCell(label: 'search', onTap: onSearch),
          ),
          Container(width: Yapp.hairline, color: pal.gray4),
          Expanded(
            child: _QuietActionCell(
              label: muted ? 'unmute' : 'mute',
              onTap: onMute,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietActionCell extends StatefulWidget {
  const _QuietActionCell({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_QuietActionCell> createState() => _QuietActionCellState();
}

class _QuietActionCellState extends State<_QuietActionCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        height: 64,
        decoration: BoxDecoration(
          color: _pressed ? pal.pressWash : pal.paper,
          border: Border(
            left: BorderSide(
              color: _pressed ? pal.ink : Colors.transparent,
              width: Yapp.tickWidth,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Yapp.name(
            color: pal.ink,
          ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _InfoRow extends StatefulWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });
  final String label;
  final String value;
  final bool copyable;
  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
  bool _pressed = false;

  Future<void> _copy() async {
    if (!widget.copyable) return;
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${widget.label} copied')));
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    if (!widget.copyable) {
      return Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: Yapp.body(color: pal.gray2).copyWith(fontSize: 14),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.value,
                textAlign: TextAlign.end,
                maxLines: 4,
                style: Yapp.name(color: pal.ink).copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onLongPress: _copy,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
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
        padding: const EdgeInsets.fromLTRB(20 - Yapp.tickWidth, 16, 20, 16),
        child: Row(
          children: [
            Text(
              widget.label,
              style: Yapp.body(color: pal.gray2).copyWith(fontSize: 14),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Yapp.name(color: pal.ink).copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatefulWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final bool value;
  final VoidCallback onTap;
  @override
  State<_SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<_SwitchRow> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final valueFg = widget.value ? pal.ink : pal.gray3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
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
        padding: const EdgeInsets.fromLTRB(20 - Yapp.tickWidth, 18, 20, 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Yapp.body(color: pal.ink).copyWith(fontSize: 14),
              ),
            ),
            AnimatedSwitcher(
              duration: Yapp.dur,
              child: Text(
                widget.value ? 'on' : 'off',
                key: ValueKey(widget.value),
                style: Yapp.name(color: valueFg).copyWith(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerRow extends StatefulWidget {
  const _DangerRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_DangerRow> createState() => _DangerRowState();
}

class _DangerRowState extends State<_DangerRow> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        decoration: BoxDecoration(
          color: _pressed ? pal.alert.withValues(alpha: 0.06) : pal.paper,
          border: Border(
            left: BorderSide(
              color: _pressed ? pal.alert : Colors.transparent,
              width: Yapp.tickWidth,
            ),
            bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20 - Yapp.tickWidth, 18, 20, 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: Yapp.name(
                  color: pal.alert,
                ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            YappGlyph.forward(color: pal.alert, size: 18),
          ],
        ),
      ),
    );
  }
}
