import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/app_scope.dart';
import '../../../../core/theme/yapp_palette.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/messenger_repository.dart';
import '../yapp_design.dart';
import 'chat_detail_screen.dart';
import 'scan_contact_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  MessengerRepository? _repo;
  bool _loading = true;
  String? _error;

  List<User> _peers = const [];

  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  bool _queryFocused = false;
  bool _lookupBusy = false;

  @override
  void initState() {
    super.initState();
    _queryFocus.addListener(() {
      if (mounted) setState(() => _queryFocused = _queryFocus.hasFocus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.of(context);
    if (!identical(_repo, repo)) {
      _repo = repo;
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final peers = await _repo!.getContactableUsers();
      if (!mounted) return;
      setState(() {
        _peers = peers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openChat(User u) async {
    HapticFeedback.selectionClick();
    final summary = await _repo!.openChatWith(u);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            ChatDetailScreen(chatId: summary.id, peer: summary.user),
      ),
    );
  }

  Future<void> _lookupUsername() async {
    final raw = _query.text.trim();
    final username = raw.startsWith('@') ? raw.substring(1) : raw;
    if (username.length < 3) {
      setState(() => _error = 'handle must be at least 3 characters');
      return;
    }
    setState(() {
      _lookupBusy = true;
      _error = null;
    });
    try {
      final summary = await _repo!.openChatByUsername(username);
      if (!mounted) return;
      await _openChat(summary.user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lookupBusy = false;
        _error = 'user not found';
      });
    }
  }

  List<User> get _filteredPeers {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return _peers;
    final needle = q.startsWith('@') ? q.substring(1) : q;
    return _peers
        .where(
          (u) =>
              u.name.toLowerCase().contains(needle) ||
              (u.username?.toLowerCase().contains(needle) ?? false),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _NewChatHeader(
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),
            SliverToBoxAdapter(
              child: _SearchField(
                controller: _query,
                focusNode: _queryFocus,
                focused: _queryFocused,
                onChanged: () => setState(() {}),
                onSubmitted: (_) => _lookupUsername(),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(_error!, style: Yapp.body(color: pal.alert)),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _QuietOutlineButton(
                  label: _lookupBusy ? 'looking up…' : 'find by handle →',
                  onTap: _lookupBusy ? null : _lookupUsername,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _QuietOutlineButton(
                  label: 'scan a qr code →',
                  onTap: _scanContactQr,
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._listSlivers(),
          ],
        ),
      ),
    );
  }

  Future<void> _scanContactQr() async {
    HapticFeedback.selectionClick();
    final repo = _repo;
    if (repo == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanContactScreen(repository: repo),
      ),
    );
  }

  List<Widget> _listSlivers() {
    final pal = YappPalette.of(context);
    final rows = _filteredPeers;
    if (rows.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 80),
            child: Center(
              child: Text(
                _query.text.isEmpty
                    ? 'start a chat by handle above'
                    : 'no local matches — try find by handle',
                style: Yapp.body(color: pal.gray2),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: YappSectionLabel(
          'chats',
          topSpace: 22,
          trailing: Text(
            '${rows.length}',
            style: Yapp.label(color: pal.gray3).copyWith(letterSpacing: 1),
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((context, i) {
          final u = rows[i];
          return _ContactRow(
            title: u.username != null ? '@${u.username}' : u.name,
            subtitle: u.name,
            avatarUrl: u.avatarUrl,
            action: 'message →',
            onTap: () => _openChat(u),
          );
        }, childCount: rows.length),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ];
  }
}

class _NewChatHeader extends StatelessWidget {
  const _NewChatHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: YappGlyph.back()),
          Text('new chat', style: Yapp.display().copyWith(fontSize: 28)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final VoidCallback onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: (_) => onChanged(),
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: '@handle',
          hintStyle: Yapp.body(color: pal.gray3),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: focused ? pal.ink : pal.gray4,
              width: focused ? 1.5 : Yapp.hairline,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: pal.ink, width: 1.5),
          ),
        ),
        style: Yapp.name(color: pal.ink),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String avatarUrl;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Yapp.name(color: pal.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Yapp.body()),
                ],
              ),
            ),
            Text(action, style: Yapp.label(color: pal.gray2)),
          ],
        ),
      ),
    );
  }
}

class _QuietOutlineButton extends StatelessWidget {
  const _QuietOutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: pal.gray3, width: Yapp.hairline),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Yapp.label(color: onTap == null ? pal.gray3 : pal.ink),
        ),
      ),
    );
  }
}
