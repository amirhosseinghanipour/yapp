import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../domain/entities/chat_summary.dart';
import '../../domain/repositories/messenger_repository.dart';
import 'peer_avatar.dart';
import '../yapp_design.dart';

Future<List<ChatSummary>?> showForwardTargetSheet(
  BuildContext context, {
  required MessengerRepository repository,
  required String excludeChatId,
}) {
  return showModalBottomSheet<List<ChatSummary>>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    isScrollControlled: true,
    builder: (ctx) => _ForwardTargetSheet(
      repository: repository,
      excludeChatId: excludeChatId,
    ),
  );
}

class _ForwardTargetSheet extends StatefulWidget {
  const _ForwardTargetSheet({
    required this.repository,
    required this.excludeChatId,
  });

  final MessengerRepository repository;
  final String excludeChatId;

  @override
  State<_ForwardTargetSheet> createState() => _ForwardTargetSheetState();
}

class _ForwardTargetSheetState extends State<_ForwardTargetSheet> {
  late final TextEditingController _search = TextEditingController();
  late final FocusNode _focus = FocusNode()
    ..addListener(() => setState(() => _hasFocus = _focus.hasFocus));
  bool _hasFocus = false;
  List<ChatSummary> _chats = const [];
  bool _loading = true;
  final Set<String> _selected = <String>{};

  void _toggle(String chatId) {
    setState(() {
      if (!_selected.remove(chatId)) _selected.add(chatId);
    });
  }

  void _confirm() {
    final chosen = _chats
        .where((c) => _selected.contains(c.id))
        .toList(growable: false);
    if (chosen.isEmpty) return;
    Navigator.of(context).pop(chosen);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.repository.getChatSummaries();
    if (!mounted) return;
    setState(() {
      _chats = data.where((c) => c.id != widget.excludeChatId).toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<ChatSummary> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _chats;
    return _chats.where((c) => c.user.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, controller) => Column(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'forward to',
                      style: Yapp.display().copyWith(fontSize: 28),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: YappGlyph.close(size: 24),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: TextField(
                      controller: _search,
                      focusNode: _focus,
                      cursorColor: pal.ink,
                      onChanged: (_) => setState(() {}),
                      style: Yapp.name(color: pal.ink).copyWith(fontSize: 15),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        hintText: 'search chats',
                        hintStyle: Yapp.name(
                          color: pal.gray3,
                        ).copyWith(fontSize: 15),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: Yapp.dur,
                      curve: Yapp.curve,
                      height: _hasFocus ? 2 : Yapp.hairline,
                      color: pal.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: controller,
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final c = _filtered[i];
                        return _ChatRow(
                          summary: c,
                          selected: _selected.contains(c.id),
                          onTap: () => _toggle(c.id),
                        );
                      },
                    ),
            ),
            _ForwardButton(count: _selected.length, onTap: _confirm),
          ],
        ),
      ),
    );
  }
}

class _ForwardButton extends StatelessWidget {
  const _ForwardButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final enabled = count > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          color: enabled ? pal.ink : pal.gray4,
          alignment: Alignment.center,
          child: Text(
            enabled ? 'forward to $count  →' : 'select chats to forward',
            style: Yapp.cta(color: enabled ? pal.paper : pal.gray2),
          ),
        ),
      ),
    );
  }
}

class _ChatRow extends StatefulWidget {
  const _ChatRow({
    required this.summary,
    required this.selected,
    required this.onTap,
  });
  final ChatSummary summary;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final invert = _pressed || widget.selected;
    final bg = invert ? pal.ink : pal.paper;
    final fg = invert ? pal.paper : pal.ink;
    final sub = invert ? pal.paper : pal.gray2;
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
          color: bg,
          border: Border(
            bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: pal.gray4,
                border: Border.all(color: pal.ink, width: Yapp.hairline),
              ),
              clipBehavior: Clip.hardEdge,
              child: PeerAvatar(user: widget.summary.user),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.summary.user.name.toLowerCase(),
                    style: Yapp.name(color: fg).copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: Yapp.dirFor(widget.summary.user.name),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.summary.lastMessage.isEmpty
                        ? 'tap to start yapping'
                        : widget.summary.lastMessage.toLowerCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Yapp.body(color: sub).copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: widget.selected ? pal.paper : Colors.transparent,
                border: Border.all(color: fg, width: 1.5),
              ),
              alignment: Alignment.center,
              child: widget.selected
                  ? Icon(Icons.check, size: 16, color: pal.ink)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
