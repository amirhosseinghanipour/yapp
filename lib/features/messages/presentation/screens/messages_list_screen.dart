import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/app_scope.dart';
import '../../../../core/theme/yapp_palette.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/chat_list_kind.dart';
import '../../domain/entities/chat_summary.dart';
import '../../domain/entities/current_user.dart';
import '../../domain/entities/message_hit.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/messenger_repository.dart';
import '../widgets/delete_message_sheet.dart';
import '../widgets/message_preview_text.dart';
import '../widgets/peer_avatar.dart';
import '../yapp_design.dart';
import 'chat_detail_screen.dart';
import 'contacts_screen.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  MessengerRepository? _repository;
  SettingsRepository? _settingsRepo;
  StreamSubscription<List<ChatSummary>>? _sub;
  StreamSubscription<AppSettings>? _settingsSub;
  Future<CurrentUser>? _meFuture;

  List<ChatSummary> _summaries = const [];
  bool _loading = true;
  AppSettings _appSettings = AppSettings.defaults;

  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<User> _contactHits = const [];
  List<MessageHit> _messageHits = const [];
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.of(context);
    final settings = AppScope.settingsOf(context);
    if (!identical(_repository, repo)) {
      _repository = repo;
      _meFuture = repo.getCurrentUser();
      _bind(repo);
    }
    if (!identical(_settingsRepo, settings)) {
      _settingsRepo = settings;
      _settingsSub?.cancel();
      _settingsSub = settings.watch().listen((s) {
        if (!mounted) return;
        setState(() => _appSettings = s);
      });
    }
  }

  Future<void> _bind(MessengerRepository repo) async {
    await _sub?.cancel();
    final initial = await repo.getChatSummaries();
    if (!mounted) return;
    setState(() {
      _summaries = initial;
      _loading = false;
    });
    _sub = repo.watchChatSummaries().listen((data) {
      if (!mounted) return;
      setState(() => _summaries = data);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _settingsSub?.cancel();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String get _query => _searchCtrl.text.trim();

  List<ChatSummary> get _chatHits {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _summaries;
    return _summaries
        .where(
          (s) =>
              s.user.name.toLowerCase().contains(q) ||
              s.lastMessage.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), _runSearch);
  }

  Future<void> _runSearch() async {
    final repo = _repository;
    if (repo == null) return;
    final q = _query;
    if (q.isEmpty) {
      setState(() {
        _contactHits = const [];
        _messageHits = const [];
      });
      return;
    }
    final (contacts, messages) = await (
      repo.searchContacts(q),
      repo.searchMessages(q),
    ).wait;
    if (!mounted) return;
    setState(() {
      _contactHits = contacts;
      _messageHits = messages;
    });
  }

  void _enterSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  void _exitSearch() {
    _debounce?.cancel();
    setState(() {
      _searching = false;
      _searchCtrl.clear();
      _contactHits = const [];
      _messageHits = const [];
    });
  }

  void _openChat(ChatSummary s) {
    _repository?.markChatRead(chatId: s.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(chatId: s.id, peer: s.user),
      ),
    );
  }

  Future<void> _openContactChat(User user) async {
    final repo = _repository;
    if (repo == null) return;
    final summary = await repo.openChatWith(user);
    if (!mounted) return;
    _exitSearch();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatDetailScreen(chatId: summary.id, peer: summary.user),
      ),
    );
  }

  void _openMessageHit(MessageHit hit) {
    _exitSearch();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(
          chatId: hit.summary.id,
          peer: hit.summary.user,
          initialHighlightMessageId: hit.message.id,
        ),
      ),
    );
  }

  void _openNewChat() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ContactsScreen()));
  }

  Future<void> _pullToRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final fresh = await _repository?.getChatSummaries();
    if (!mounted || fresh == null) return;
    setState(() => _summaries = fresh);
  }

  Future<void> _showRowActions(ChatSummary s) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<_RowAction>(
      context: context,
      backgroundColor: YappPalette.of(context).paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => _YappActionsSheet(summary: s),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _RowAction.pin:
        final ok = await _repository!.setPinned(
          chatId: s.id,
          pinned: !s.isPinned,
        );
        if (!ok && mounted) {
          _toast(
            'only '
            '${MessengerRepository.pinnedChatLimit} can be pinned. '
            'unpin one first.',
          );
        }
        break;
      case _RowAction.mute:
        _repository!.setMuted(chatId: s.id, muted: !s.isMuted);
        break;
      case _RowAction.markRead:
        _repository!.markChatRead(chatId: s.id);
        break;
      case _RowAction.delete:
        final choice = await showDeleteChatSheet(
          context,
          peerName: s.user.name.split(' ').first,
        );
        if (choice != null && mounted) {
          await _repository!.deleteChat(
            chatId: s.id,
            forEveryone: choice.forEveryone,
          );
        }
        break;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: Yapp.body(color: YappPalette.of(context).paper),
          ),
          backgroundColor: YappPalette.of(context).ink,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = YappPalette.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: _appSettings.wallpaper.chatListDecoration(
              brightness: Theme.of(context).brightness,
              basePaper: palette.paper,
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: Yapp.dur,
                    switchInCurve: Yapp.curve,
                    switchOutCurve: Yapp.curve,
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: _searching
                        ? _YappSearchHeader(
                            key: const ValueKey('search'),
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            onClose: _exitSearch,
                          )
                        : _YappHeader(
                            key: const ValueKey('title'),
                            meFuture: _meFuture,
                            onSearch: _enterSearch,
                          ),
                  ),
                  const _Hairline(),
                  Expanded(
                    child: RefreshIndicator(
                      color: palette.ink,
                      backgroundColor: palette.paper,
                      onRefresh: _pullToRefresh,
                      child: _body(),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _NewYapBar(onTap: _openNewChat),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: YappPalette.of(context).ink,
          ),
        ),
      );
    }

    if (_searching && _query.isNotEmpty) {
      return _YappSearchResults(
        query: _query,
        chats: _chatHits,
        contacts: _contactHits,
        messages: _messageHits,
        onTapChat: _openChat,
        onTapContact: _openContactChat,
        onTapMessage: _openMessageHit,
      );
    }

    final data = _chatHits;
    if (data.isEmpty) return const _EmptyState();

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 72 + 24),
      itemCount: data.length,
      separatorBuilder: (_, _) => const _Hairline(indent: 24),
      itemBuilder: (_, i) {
        final s = data[i];
        return _YappChatRow(
          key: ValueKey(s.id),
          summary: s,
          onTap: () => _openChat(s),
          onLongPress: () => _showRowActions(s),
        );
      },
    );
  }
}

class _YappHeader extends StatelessWidget {
  const _YappHeader({
    super.key,
    required this.meFuture,
    required this.onSearch,
  });

  final Future<CurrentUser>? meFuture;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              'yapp',
              style: Yapp.display(color: YappPalette.of(context).ink),
            ),
          ),
          _HeaderIconButton(
            icon: Icons.search,
            tooltip: 'search',
            onTap: onSearch,
          ),
          const SizedBox(width: 4),
          _MenuStackButton(future: meFuture),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: YappPalette.of(context).ink),
        ),
      ),
    );
  }
}

class _MenuStackButton extends StatelessWidget {
  const _MenuStackButton({required this.future});

  final Future<CurrentUser>? future;

  void _open(BuildContext context) {
    Scaffold.maybeOf(context)?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'menu',
      child: InkWell(
        onTap: () => _open(context),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _MiniSquare(),
                SizedBox(height: 3),
                _MiniSquare(),
                SizedBox(height: 3),
                _MiniSquare(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSquare extends StatelessWidget {
  const _MiniSquare();

  @override
  Widget build(BuildContext context) {
    final ink = YappPalette.of(context).ink;
    return SizedBox(width: 16, height: 3, child: ColoredBox(color: ink));
  }
}

class _YappSearchHeader extends StatefulWidget {
  const _YappSearchHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback onClose;

  @override
  State<_YappSearchHeader> createState() => _YappSearchHeaderState();
}

class _YappSearchHeaderState extends State<_YappSearchHeader> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final pal = YappPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onChanged: (_) => widget.onChanged(),
                  style: Yapp.display(color: pal.ink).copyWith(fontSize: 28),
                  cursorColor: pal.ink,
                  cursorWidth: 2,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.only(bottom: 6),
                    border: InputBorder.none,
                    hintText: 'search',
                    hintStyle: Yapp.display().copyWith(
                      fontSize: 28,
                      color: pal.gray3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: widget.onClose,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Text(
                      'close',
                      style: Yapp.label(
                        color: pal.ink,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: Yapp.dur,
            curve: Yapp.curve,
            height: focused ? 2 : 1,
            color: pal.ink,
          ),
        ],
      ),
    );
  }
}

class _YappChatRow extends StatefulWidget {
  const _YappChatRow({
    super.key,
    required this.summary,
    required this.onTap,
    this.onLongPress,
  });

  final ChatSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_YappChatRow> createState() => _YappChatRowState();
}

class _YappChatRowState extends State<_YappChatRow> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final unread = s.unreadCount > 0;
    final isSaved = s.kind == ChatListKind.saved;
    final pal = YappPalette.of(context);

    final name = (isSaved ? 'saved' : s.user.name).toLowerCase();
    final preview = _previewText(s);
    final time = _yappRelative(s.timestamp);

    final bg = _pressed ? pal.ink : pal.paper;
    final fg = _pressed ? pal.paper : pal.ink;
    final fgSub = _pressed ? pal.gray3 : pal.gray2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        color: bg,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(summary: s, inverted: _pressed),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (s.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 6, top: 2),
                          child: _PinSquare(inverted: _pressed),
                        ),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Yapp.name(color: fg).copyWith(
                            fontWeight: unread
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                          textDirection: Yapp.dirFor(name),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: Yapp.label(color: fgSub).copyWith(
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Yapp.body(color: fgSub).copyWith(
                            fontWeight: unread
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          textDirection: Yapp.dirFor(preview),
                        ),
                      ),
                      if (s.isMuted)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('muted', style: Yapp.label(color: fgSub)),
                        ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        _UnreadDot(count: s.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _previewText(ChatSummary s) {
    final raw = stripMessageMarkdown(s.lastMessage).trim();
    if (raw.isEmpty) return 'no messages yet';
    return raw.toLowerCase();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.summary, required this.inverted});

  final ChatSummary summary;
  final bool inverted;

  bool get _isSaved => summary.kind == ChatListKind.saved;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    if (_isSaved) {
      return SizedBox(
        width: 44,
        height: 44,
        child: AnimatedContainer(
          duration: Yapp.dur,
          curve: Yapp.curve,
          color: inverted ? pal.paper : pal.ink,
          alignment: Alignment.center,
          child: Text(
            'y',
            style: Yapp.display().copyWith(
              fontSize: 24,
              color: inverted ? pal.ink : pal.paper,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: pal.gray4,
        border: Border.all(color: pal.ink, width: Yapp.hairline),
      ),
      clipBehavior: Clip.hardEdge,
      child: PeerAvatar(
        user: summary.user,
        placeholder: Container(
          color: pal.gray4,
          alignment: Alignment.center,
          child: Text(
            _initials(summary.user.name),
            style: Yapp.name(
              color: pal.ink,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '•';
    if (parts.length == 1) return parts.first.characters.first.toLowerCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toLowerCase();
  }
}

class _PinSquare extends StatelessWidget {
  const _PinSquare({required this.inverted});
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return SizedBox(
      width: 8,
      height: 8,
      child: ColoredBox(color: inverted ? pal.paper : pal.ink),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 8,
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Yapp.alert,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (count > 9) ...[
          const SizedBox(width: 6),
          Text(
            '$count',
            style: Yapp.label(
              color: Yapp.alert,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

class _YappSearchResults extends StatelessWidget {
  const _YappSearchResults({
    required this.query,
    required this.chats,
    required this.contacts,
    required this.messages,
    required this.onTapChat,
    required this.onTapContact,
    required this.onTapMessage,
  });

  final String query;
  final List<ChatSummary> chats;
  final List<User> contacts;
  final List<MessageHit> messages;
  final ValueChanged<ChatSummary> onTapChat;
  final ValueChanged<User> onTapContact;
  final ValueChanged<MessageHit> onTapMessage;

  @override
  Widget build(BuildContext context) {
    final empty = chats.isEmpty && contacts.isEmpty && messages.isEmpty;
    if (empty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
        children: [
          Text('nothing.', style: Yapp.display()),
          const SizedBox(height: 6),
          Text('no matches for "${query.toLowerCase()}".', style: Yapp.body()),
        ],
      );
    }

    final rows = <Widget>[];

    if (chats.isNotEmpty) {
      rows.add(_SectionHead(label: 'chats', count: chats.length));
      for (final c in chats) {
        rows.add(
          _YappChatRow(
            key: ValueKey('c_${c.id}'),
            summary: c,
            onTap: () => onTapChat(c),
          ),
        );
        rows.add(const _Hairline(indent: 24));
      }
    }

    if (contacts.isNotEmpty) {
      rows.add(_SectionHead(label: 'contacts', count: contacts.length));
      for (final u in contacts) {
        rows.add(_ContactRow(user: u, onTap: () => onTapContact(u)));
        rows.add(const _Hairline(indent: 24));
      }
    }

    if (messages.isNotEmpty) {
      rows.add(_SectionHead(label: 'messages', count: messages.length));
      for (final h in messages) {
        rows.add(
          _MessageHitRow(hit: h, query: query, onTap: () => onTapMessage(h)),
        );
        rows.add(const _Hairline(indent: 24));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: rows,
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: Yapp.display().copyWith(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Yapp.label(color: YappPalette.of(context).gray2),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.user, required this.onTap});
  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pal.gray4,
                border: Border.all(color: pal.ink, width: Yapp.hairline),
              ),
              clipBehavior: Clip.hardEdge,
              child: PeerAvatar(
                user: user,
                placeholder: ColoredBox(color: pal.gray4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name.toLowerCase(), style: Yapp.name()),
                  const SizedBox(height: 2),
                  Text(
                    user.isOnline ? 'online now' : 'tap to start',
                    style: Yapp.body(),
                  ),
                ],
              ),
            ),
            YappGlyph.forward(color: pal.ink),
          ],
        ),
      ),
    );
  }
}

class _MessageHitRow extends StatelessWidget {
  const _MessageHitRow({
    required this.hit,
    required this.query,
    required this.onTap,
  });

  final MessageHit hit;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = stripMessageMarkdown(hit.message.text ?? '').toLowerCase();
    final q = query.toLowerCase();
    final idx = q.isEmpty ? -1 : body.indexOf(q);

    final spans = <InlineSpan>[];
    if (idx == -1) {
      spans.add(TextSpan(text: body));
    } else {
      final end = idx + q.length;
      if (idx > 0) spans.add(TextSpan(text: body.substring(0, idx)));
      spans.add(
        TextSpan(
          text: body.substring(idx, end),
          style: const TextStyle(
            color: Yapp.ink,
            fontWeight: FontWeight.w800,
            backgroundColor: Yapp.alert,
          ),
        ),
      );
      if (end < body.length) spans.add(TextSpan(text: body.substring(end)));
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hit.summary.user.name.toLowerCase(), style: Yapp.name()),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: Yapp.body(color: YappPalette.of(context).gray2),
                children: spans,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
      children: [
        Text('nothing to yap', style: Yapp.display(color: pal.ink)),
        Text(
          'about. yet.',
          style: Yapp.display(color: pal.ink).copyWith(color: pal.gray3),
        ),
        const SizedBox(height: 20),
        Text(
          'hit the bar below to start your first conversation.',
          style: Yapp.body(color: pal.ink),
        ),
      ],
    );
  }
}

class _NewYapBar extends StatefulWidget {
  const _NewYapBar({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_NewYapBar> createState() => _NewYapBarState();
}

class _NewYapBarState extends State<_NewYapBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        height: 72,
        color: _pressed ? pal.alert : pal.ink,
        alignment: Alignment.center,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('new yap', style: Yapp.cta(color: pal.paper)),
                YappGlyph.forward(color: pal.paper),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _RowAction { pin, mute, markRead, delete }

class _YappActionsSheet extends StatelessWidget {
  const _YappActionsSheet({required this.summary});

  final ChatSummary summary;

  @override
  Widget build(BuildContext context) {
    final canMarkRead = summary.unreadCount > 0;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Text(
              summary.user.name.toLowerCase(),
              style: Yapp.display().copyWith(fontSize: 28),
            ),
          ),
          const _Hairline(),
          _SheetRow(
            label: summary.isPinned ? 'unpin' : 'pin to top',
            onTap: () => Navigator.of(context).pop(_RowAction.pin),
          ),
          const _Hairline(indent: 24),
          _SheetRow(
            label: summary.isMuted ? 'unmute' : 'mute',
            onTap: () => Navigator.of(context).pop(_RowAction.mute),
          ),
          if (canMarkRead) ...[
            const _Hairline(indent: 24),
            _SheetRow(
              label: 'mark as read',
              onTap: () => Navigator.of(context).pop(_RowAction.markRead),
            ),
          ],
          const _Hairline(indent: 24),
          _SheetRow(
            label: 'delete chat',
            destructive: true,
            onTap: () => Navigator.of(context).pop(_RowAction.delete),
          ),
          const _Hairline(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final color = destructive ? pal.alert : pal.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Yapp.name(
                  color: color,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            YappGlyph.forward(color: color),
          ],
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline({this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: SizedBox(height: 1, child: ColoredBox(color: pal.gray4)),
    );
  }
}

String _yappRelative(DateTime time) {
  final now = DateTime.now();
  final diff = now.difference(time);

  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';

  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(time.year, time.month, time.day);
  final dayDiff = today.difference(that).inDays;
  if (dayDiff == 1) return 'yday';
  if (dayDiff < 7) {
    const names = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return names[time.weekday - 1];
  }
  if (time.year == now.year) {
    return DateFormat('MMM d').format(time).toLowerCase();
  }
  return DateFormat('MMM y').format(time).toLowerCase();
}
