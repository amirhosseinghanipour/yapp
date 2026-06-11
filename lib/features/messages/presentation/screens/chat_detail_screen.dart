import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/app_scope.dart';
import '../../../../core/theme/yapp_palette.dart';
import '../../../settings/domain/entities/app_settings.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/chat_list_kind.dart';
import '../../domain/entities/chat_summary.dart';
import '../../domain/entities/message.dart' as domain;
import '../../domain/entities/message_type.dart';
import '../../domain/entities/reply_preview.dart';
import '../../domain/entities/user.dart';
import '../../domain/utils/last_seen_format.dart';
import '../../domain/repositories/messenger_repository.dart';
import '../widgets/emoji_sticker_sheet.dart';
import '../widgets/attach_sheet.dart';
import '../widgets/forward_target_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_context_menu.dart';
import '../widgets/message_input_bar.dart';
import '../../../../core/push/notification_center.dart';
import '../widgets/delete_message_sheet.dart';
import '../widgets/message_preview_text.dart';
import '../widgets/peer_avatar.dart';
import '../widgets/reply_preview_bar.dart';
import '../widgets/swipe_to_reply.dart';
import '../widgets/voice_recorder_sheet.dart';
import '../yapp_design.dart';
import 'chat_info_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.peer,
    this.initialHighlightMessageId,
  });

  final String chatId;
  final User peer;
  final String? initialHighlightMessageId;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  MessengerRepository? _repository;
  SettingsRepository? _settings;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocus = FocusNode();

  StreamSubscription<List<domain.Message>>? _messagesSub;
  StreamSubscription<List<ChatSummary>>? _summariesSub;
  StreamSubscription<AppSettings>? _settingsSub;

  List<domain.Message> _messages = const [];
  ChatSummary? _summary;

  String _currentUserId = '';
  late User _displayPeer;
  bool _peerTyping = false;
  StreamSubscription<bool>? _typingSub;
  Timer? _typingIdleTimer;
  StreamSubscription<User>? _presenceSub;
  bool _emojiSheetOpen = false;
  ReplyPreview? _replyTo;
  bool _showScrollToBottom = false;
  bool _draftLoaded = false;

  String? _editingMessageId;
  String? _editingPreview;
  bool _editingIsMedia = false;

  String? _sendingMediaLabel;
  final ImagePicker _imagePicker = ImagePicker();

  bool _searching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String? _highlightId;
  Timer? _highlightTimer;

  AppSettings _appSettings = AppSettings.defaults;

  @override
  void initState() {
    super.initState();
    _displayPeer = widget.peer;
    currentOpenChatId.value = widget.chatId;
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _textController.addListener(_onTextChanged);
    _textFocus.addListener(_onComposerFocusChanged);
  }

  void _onComposerFocusChanged() {
    if (_textFocus.hasFocus && _emojiSheetOpen) {
      setState(() => _emojiSheetOpen = false);
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted || !_emojiSheetOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_emojiSheetOpen) return;
      final bottom = MediaQuery.viewInsetsOf(context).bottom;
      if (bottom > 0) setState(() => _emojiSheetOpen = false);
    });
  }

  void _onTextChanged() {
    if (!_draftLoaded) return;
    if (_editingMessageId != null) return;
    _repository?.setDraft(chatId: widget.chatId, text: _textController.text);
    final repo = _repository;
    if (repo == null) return;
    final hasText = _textController.text.trim().isNotEmpty;
    repo.sendTyping(chatId: widget.chatId, isTyping: hasText);
    _typingIdleTimer?.cancel();
    if (hasText) {
      _typingIdleTimer = Timer(const Duration(seconds: 2), () {
        repo.sendTyping(chatId: widget.chatId, isTyping: false);
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final distanceFromBottom = pos.maxScrollExtent - pos.pixels;
    final shouldShow = distanceFromBottom > 220;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.of(context);
    final settings = AppScope.settingsOf(context);
    if (!identical(_repository, repo) || !identical(_settings, settings)) {
      _repository = repo;
      _settings = settings;
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    final repo = _repository;
    final settings = _settings;
    if (repo == null || settings == null) return;

    final (me, typing, draft) = await (
      repo.getCurrentUser(),
      repo.isPeerTyping(widget.chatId),
      repo.getDraft(widget.chatId),
    ).wait;
    if (!mounted) return;

    _textController.text = draft;
    _textController.selection = TextSelection.collapsed(offset: draft.length);
    _draftLoaded = true;

    final peer = await repo.fetchPeerWithPresence(widget.peer.id);

    setState(() {
      _currentUserId = me.id;
      _peerTyping = typing;
      _displayPeer = peer;
    });

    await _typingSub?.cancel();
    _typingSub = repo.watchPeerTyping(widget.chatId).listen((v) {
      if (!mounted) return;
      setState(() => _peerTyping = v);
    });

    await _presenceSub?.cancel();
    _presenceSub = repo.watchPeerPresence(widget.peer.id).listen((updated) {
      if (!mounted) return;
      setState(() => _displayPeer = updated);
    });

    await _messagesSub?.cancel();
    var firstEmit = true;
    _messagesSub = repo.watchMessages(widget.chatId).listen((msgs) {
      if (!mounted) return;
      setState(() => _messages = msgs);
      if (firstEmit && widget.initialHighlightMessageId != null) {
        firstEmit = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _jumpToMessage(widget.initialHighlightMessageId!);
        });
      } else {
        _scrollToBottomSoon();
        firstEmit = false;
      }
    });

    await _summariesSub?.cancel();
    _summariesSub = repo.watchChatSummaries().listen((summaries) {
      if (!mounted) return;
      final mine = summaries.firstWhere(
        (s) => s.id == widget.chatId,
        orElse: () => summaries.isEmpty
            ? ChatSummary(
                id: widget.chatId,
                user: widget.peer,
                lastMessage: '',
                timestamp: DateTime.now(),
                unreadCount: 0,
                kind: ChatListKind.dm,
              )
            : summaries.first,
      );
      final su = mine.user;
      setState(() {
        _summary = mine;
        if (su.id == _displayPeer.id) {
          _displayPeer = User(
            id: su.id,
            name: su.name,
            username: su.username ?? _displayPeer.username,
            avatarUrl: su.avatarUrl,
            avatarBlob: su.avatarBlob,
            isOnline: _displayPeer.isOnline,
            lastSeenAt: _displayPeer.lastSeenAt,
          );
        }
      });
    });

    await _settingsSub?.cancel();
    final snap = await settings.load();
    if (!mounted) return;
    setState(() => _appSettings = snap);
    _settingsSub = settings.watch().listen((s) {
      if (!mounted) return;
      setState(() => _appSettings = s);
    });
  }

  @override
  void dispose() {
    if (currentOpenChatId.value == widget.chatId) {
      currentOpenChatId.value = null;
    }
    _typingSub?.cancel();
    _typingIdleTimer?.cancel();
    _presenceSub?.cancel();
    _repository?.sendTyping(chatId: widget.chatId, isTyping: false);
    WidgetsBinding.instance.removeObserver(this);
    _messagesSub?.cancel();
    _summariesSub?.cancel();
    _settingsSub?.cancel();
    _highlightTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _textController.removeListener(_onTextChanged);
    _textFocus.removeListener(_onComposerFocusChanged);
    _textController.dispose();
    _scrollController.dispose();
    _textFocus.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool get _isBlocked => _settings?.isBlocked(widget.peer.id) ?? false;

  bool get _isSavedMessages {
    if (_summary?.kind == ChatListKind.saved) return true;
    final parts = widget.chatId.split('|');
    return parts.length == 3 && parts[0] == 'dm' && parts[1] == parts[2];
  }

  ReplyPreview _replyPreviewFromMessage(domain.Message m) {
    final self = m.senderId == _currentUserId;
    final senderName = self ? 'you' : widget.peer.name;
    return ReplyPreview(
      messageId: m.id,
      senderName: senderName,
      type: m.type,
      text: m.text,
    );
  }

  void _openChatInfo() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<ChatInfoIntent>(
      MaterialPageRoute<ChatInfoIntent>(
        builder: (_) =>
            ChatInfoScreen(chatId: widget.chatId, peer: widget.peer),
      ),
    );
    if (!mounted) return;
    if (result == ChatInfoIntent.openSearch) {
      _openSearch();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _sendText() async {
    final repo = _repository;
    if (repo == null) return;

    if (_editingMessageId != null) {
      final newText = _textController.text.trim();
      final id = _editingMessageId!;
      setState(() {
        _editingMessageId = null;
        _editingPreview = null;
      });
      _textController.clear();
      final wasMedia = _editingIsMedia;
      _editingIsMedia = false;
      if (newText.isEmpty && !wasMedia) {
        await repo.deleteMessage(chatId: widget.chatId, messageId: id);
      } else {
        await repo.editText(
          chatId: widget.chatId,
          messageId: id,
          newText: newText,
        );
      }
      _maybeClick();
      return;
    }

    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    _maybeClick();
    try {
      final sent = await repo.sendText(
        chatId: widget.chatId,
        text: text,
        replyTo: reply,
      );
      if (mounted && !_messages.any((m) => m.id == sent.id)) {
        setState(() => _messages = [..._messages, sent]);
        _scrollToBottomSoon();
      }
    } on SendMessageException catch (e) {
      if (!mounted) return;
      _textController.text = text;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      _textController.text = text;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Couldn’t send your message.')),
        );
    }
  }

  void _maybeClick() {
    HapticFeedback.lightImpact();
  }

  Future<void> _openAttach() async {
    FocusScope.of(context).unfocus();
    if (_emojiSheetOpen) setState(() => _emojiSheetOpen = false);
    final choice = await showAttachSheet(context);
    if (choice == null || !mounted) return;
    switch (choice) {
      case AttachChoice.photo:
        await _pickImage(ImageSource.gallery);
        break;
      case AttachChoice.camera:
        await _pickImage(ImageSource.camera);
        break;
      case AttachChoice.file:
        await _pickFile();
        break;
      case AttachChoice.voice:
        await _recordVoice();
        break;
      case AttachChoice.location:
        await _sendCurrentLocation();
        break;
    }
  }

  Future<void> _sendMediaGuarded(
    String label,
    Future<void> Function() send,
  ) async {
    setState(() => _sendingMediaLabel = label);
    try {
      await send();
    } on SendMessageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('couldn’t send media.')));
    } finally {
      if (mounted) setState(() => _sendingMediaLabel = null);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final repo = _repository;
    if (repo == null) return;
    XFile? file;
    try {
      file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );
    } catch (_) {
      if (!mounted) return;
      _toast('could not open photo source');
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();

    int? width, height;
    try {
      final decoded = await decodeImageFromList(bytes);
      width = decoded.width;
      height = decoded.height;
    } catch (_) {}

    final name = file.name;
    await _sendMediaGuarded('photo', () async {
      await repo.sendMedia(
        chatId: widget.chatId,
        type: MessageType.image,
        bytes: bytes,
        fileName: name,
        mime: file!.mimeType,
        width: width,
        height: height,
      );
    });
  }

  Future<void> _pickFile() async {
    final repo = _repository;
    if (repo == null) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (_) {
      if (!mounted) return;
      _toast('could not open files');
      return;
    }
    if (result == null || result.files.isEmpty || !mounted) return;
    final picked = result.files.first;

    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      try {
        bytes = await File(picked.path!).readAsBytes();
      } catch (_) {}
    }
    if (bytes == null) {
      _toast('could not read file');
      return;
    }

    final ext = (picked.extension ?? '').toLowerCase();
    final mime = _mimeForExtension(ext);
    final isAudio = mime?.startsWith('audio/') ?? false;
    final type = isAudio ? MessageType.audio : MessageType.file;

    final data = bytes;
    await _sendMediaGuarded(isAudio ? 'audio' : 'file', () async {
      await repo.sendMedia(
        chatId: widget.chatId,
        type: type,
        bytes: data,
        fileName: picked.name,
        mime: mime,
      );
    });
  }

  Future<void> _recordVoice() async {
    final repo = _repository;
    if (repo == null) return;
    final rec = await showVoiceRecorderSheet(context);
    if (rec == null || !mounted) return;

    Uint8List bytes;
    try {
      bytes = await File(rec.path).readAsBytes();
    } catch (_) {
      _toast('could not read recording');
      return;
    }
    await _sendMediaGuarded('voice', () async {
      await repo.sendMedia(
        chatId: widget.chatId,
        type: MessageType.voice,
        bytes: bytes,
        mime: 'audio/mp4',
        fileName: 'voice.m4a',
        durationMs: rec.durationMs,
      );
    });
  }

  Future<void> _sendCurrentLocation() async {
    final repo = _repository;
    if (repo == null) return;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (!mounted) return;
        _toast('location services are off');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        _toast('location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      await _sendMediaGuarded('location', () async {
        await repo.sendLocation(
          chatId: widget.chatId,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      });
    } catch (_) {
      if (!mounted) return;
      _toast('could not get location');
    }
  }

  static String? _mimeForExtension(String ext) {
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'flac':
        return 'audio/flac';
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      default:
        return null;
    }
  }

  void _startReply(domain.Message m) {
    HapticFeedback.selectionClick();
    setState(() {
      _replyTo = _replyPreviewFromMessage(m);
      _emojiSheetOpen = false;
      _editingMessageId = null;
      _editingPreview = null;
    });
    _textFocus.requestFocus();
  }

  void _startEdit(domain.Message m) {
    final text = m.text ?? '';
    setState(() {
      _editingMessageId = m.id;
      _editingIsMedia = m.attachment != null;
      _editingPreview = stripMessageMarkdown(text);
      _replyTo = null;
      _emojiSheetOpen = false;
    });
    _textController.text = text;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _textFocus.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _editingPreview = null;
    });
    _textController.clear();
  }

  Future<void> _forward(domain.Message m) async {
    final repo = _repository;
    if (repo == null) return;
    final targets = await showForwardTargetSheet(
      context,
      repository: repo,
      excludeChatId: widget.chatId,
    );
    if (targets == null || targets.isEmpty || !mounted) return;
    for (final t in targets) {
      await repo.forwardMessage(
        sourceChatId: widget.chatId,
        messageId: m.id,
        destinationChatId: t.id,
      );
    }
    if (!mounted) return;
    _toast(
      targets.length == 1
          ? 'forwarded to ${targets.first.user.name.toLowerCase()}'
          : 'forwarded to ${targets.length} chats',
    );
  }

  Future<void> _confirmDeleteMessage(domain.Message m) async {
    final repo = _repository;
    if (repo == null) return;
    final choice = await showDeleteMessageSheet(context);
    if (choice == null || !mounted) return;
    if (choice.deleteChat) {
      await repo.deleteChat(chatId: widget.chatId, forEveryone: true);
      if (mounted) Navigator.of(context).maybePop();
    } else {
      await repo.deleteMessage(chatId: widget.chatId, messageId: m.id);
    }
  }

  Future<void> _togglePinMessage(domain.Message m) async {
    final repo = _repository;
    if (repo == null) return;
    final current = _summary?.pinnedMessageId;
    await repo.setPinnedMessage(
      chatId: widget.chatId,
      messageId: current == m.id ? null : m.id,
    );
    if (!mounted) return;
    _toast(current == m.id ? 'unpinned' : 'pinned');
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final repo = _repository;
    if (repo == null) return;
    HapticFeedback.selectionClick();
    await repo.toggleReaction(
      chatId: widget.chatId,
      messageId: messageId,
      emoji: emoji,
    );
  }

  Future<void> _showContextMenu(Offset pos, domain.Message m) async {
    HapticFeedback.mediumImpact();
    final isOwn = m.senderId == _currentUserId;
    final canEdit =
        isOwn && m.type != MessageType.voice && m.type != MessageType.sticker;
    final isPinned = _summary?.pinnedMessageId == m.id;

    setState(() => _highlightId = m.id);

    final items = <MessageContextMenuItem>[
      const MessageContextMenuItem(
        action: MessageAction.reply,
        icon: Icons.reply_rounded,
        label: 'Reply',
      ),
      if (m.type == MessageType.text)
        const MessageContextMenuItem(
          action: MessageAction.copy,
          icon: Icons.copy_rounded,
          label: 'Copy',
        ),
      if (canEdit)
        MessageContextMenuItem(
          action: MessageAction.edit,
          icon: Icons.edit_rounded,
          label: m.type == MessageType.text ? 'Edit' : 'Edit caption',
        ),
      if (!m.noForward)
        const MessageContextMenuItem(
          action: MessageAction.forward,
          icon: Icons.forward_rounded,
          label: 'Forward',
        ),
      if (isPinned)
        const MessageContextMenuItem(
          action: MessageAction.unpin,
          icon: Icons.push_pin_outlined,
          label: 'Unpin',
        )
      else
        const MessageContextMenuItem(
          action: MessageAction.pin,
          icon: Icons.push_pin_rounded,
          label: 'Pin',
        ),
      if (m.senderId == _currentUserId)
        const MessageContextMenuItem(
          action: MessageAction.delete,
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          danger: true,
        ),
    ];

    final result = await showMessageContextMenu(
      context: context,
      globalPosition: pos,
      items: items,
    );

    if (!mounted) return;
    setState(() => _highlightId = null);

    if (result == null) return;
    switch (result.action) {
      case MessageAction.reply:
        _startReply(m);
        break;
      case MessageAction.copy:
        if (m.text != null) {
          await Clipboard.setData(ClipboardData(text: m.text!));
          _toast('copied.');
        }
        break;
      case MessageAction.edit:
        _startEdit(m);
        break;
      case MessageAction.forward:
        await _forward(m);
        break;
      case MessageAction.pin:
      case MessageAction.unpin:
        await _togglePinMessage(m);
        break;
      case MessageAction.delete:
        await _confirmDeleteMessage(m);
        break;
      case MessageAction.react:
        final emoji = result.emoji;
        if (emoji != null) await _toggleReaction(m.id, emoji);
        break;
      case MessageAction.save:
        break;
    }
  }

  void _jumpToMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final items = _buildItems();
    final itemIndex = items.indexWhere(
      (it) => it is _MessageItem && it.message.id == messageId,
    );
    if (itemIndex == -1) return;

    HapticFeedback.selectionClick();
    final approx = itemIndex * 80.0;
    _scrollController.animateTo(
      approx.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );

    setState(() => _highlightId = messageId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _highlightId = null);
    });
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  void _toast(String msg) {
    final pal = YappPalette.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: pal.ink,
      ),
    );
  }

  void _toggleEmojiSheet() {
    if (_emojiSheetOpen) {
      setState(() => _emojiSheetOpen = false);
      _textFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        setState(() => _emojiSheetOpen = true);
      });
    }
  }

  void _insertEmoji(String emoji) {
    final sel = _textController.selection;
    final text = _textController.text;
    if (!sel.isValid) {
      _textController.text = text + emoji;
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
      return;
    }
    final before = text.substring(0, sel.start);
    final after = text.substring(sel.end);
    final next = '$before$emoji$after';
    _textController.text = next;
    _textController.selection = TextSelection.collapsed(
      offset: (before + emoji).length,
    );
  }

  void _emojiBackspace() {
    final text = _textController.text;
    if (text.isEmpty) return;
    final chars = text.characters.toList();
    chars.removeLast();
    _textController.text = chars.join();
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
  }

  void _openSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _searchCtrl.clear();
    });
  }

  Future<void> _toggleMuteChat() async {
    final repo = _repository;
    final s = _summary;
    if (repo == null || s == null) return;
    final next = !s.isMuted;
    setState(() => _summary = s.copyWith(isMuted: next));
    await repo.setMuted(chatId: widget.chatId, muted: next);
    if (!mounted) return;
    _toast(next ? 'muted' : 'unmuted');
  }

  Future<void> _deleteChatWithConfirm() async {
    if (_isSavedMessages) return;
    final first = widget.peer.name.split(' ').first;
    final choice = await showDeleteChatSheet(context, peerName: first);
    if (choice == null || !mounted) return;
    await _repository?.deleteChat(
      chatId: widget.chatId,
      forEveryone: choice.forEveryone,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _onChatOverflow(_ChatOverflowAction action) {
    switch (action) {
      case _ChatOverflowAction.search:
        _openSearch();
        break;
      case _ChatOverflowAction.mute:
        unawaited(_toggleMuteChat());
        break;
      case _ChatOverflowAction.delete:
        unawaited(_deleteChatWithConfirm());
        break;
    }
  }

  List<domain.Message> get _searchMatches {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _messages
        .where((m) => (m.text ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _isBlocked;
    final pinnedId = _summary?.pinnedMessageId;
    domain.Message? pinnedMsg;
    if (pinnedId != null) {
      for (final m in _messages) {
        if (m.id == pinnedId) {
          pinnedMsg = m;
          break;
        }
      }
    }
    final pinned = pinnedMsg;

    final palette = YappPalette.of(context);
    return Scaffold(
      backgroundColor: palette.paper,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _searching
                ? _YappSearchHeader(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onClose: _closeSearch,
                    onChanged: () => setState(() {}),
                    matchCount: _searchMatches.length,
                  )
                : _YappChatHeader(
                    peer: _displayPeer,
                    typing: _peerTyping,
                    isSaved: _isSavedMessages,
                    isMuted: _summary?.isMuted ?? false,
                    showMuteAndDelete: !_isSavedMessages,
                    onTapPeer: _openChatInfo,
                    onOverflowAction: _onChatOverflow,
                  ),
            Container(height: 1, color: palette.ink),
            if (pinned != null && !_searching)
              _YappPinnedBanner(
                message: pinned,
                onTap: () => _jumpToMessage(pinned.id),
                onClose: () => _repository?.setPinnedMessage(
                  chatId: widget.chatId,
                  messageId: null,
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: _appSettings.wallpaper.chatListDecoration(
                        brightness: Theme.of(context).brightness,
                        basePaper: palette.paper,
                      ),
                    ),
                  ),
                  Positioned.fill(child: _messagesList()),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: _YappScrollDown(
                      visible: _showScrollToBottom,
                      onTap: _scrollToBottom,
                    ),
                  ),
                ],
              ),
            ),
            if (blocked)
              _YappBlockedBanner(
                peerName: widget.peer.name,
                onUnblock: () async {
                  await _settings?.unblockUser(widget.peer.id);
                  if (!mounted) return;
                  setState(() {});
                  _toast('unblocked ${widget.peer.name.toLowerCase()}');
                },
              )
            else ...[
              if (_sendingMediaLabel != null)
                _YappSendingBanner(label: _sendingMediaLabel!),
              if (_editingMessageId != null && _editingPreview != null)
                _YappEditingBanner(
                  preview: _editingPreview!,
                  onCancel: _cancelEdit,
                ),
              if (_replyTo != null)
                ReplyPreviewBar(
                  reply: _replyTo!,
                  onClear: () => setState(() => _replyTo = null),
                ),
              MessageInputBar(
                controller: _textController,
                focusNode: _textFocus,
                emojiToggled: _emojiSheetOpen,
                onToggleEmoji: _toggleEmojiSheet,
                onSendText: _sendText,
                onAttach: _openAttach,
                editing: _editingMessageId != null,
                editingPreview: _editingPreview,
                onCancelEdit: _cancelEdit,
              ),
              if (_emojiSheetOpen)
                EmojiStickerSheet(
                  onResult: (r) {
                    switch (r) {
                      case EmojiInsert(:final emoji):
                        _insertEmoji(emoji);
                        break;
                      case EmojiBackspace():
                        _emojiBackspace();
                        break;
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messagesList() {
    if (_messages.isEmpty) {
      final pal = YappPalette.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'say\nsomething.',
                textAlign: TextAlign.center,
                style: Yapp.display(
                  color: pal.ink,
                ).copyWith(fontSize: 44, height: 0.95),
              ),
              const SizedBox(height: 14),
              Text(
                'no messages yet — go first',
                style: Yapp.label(
                  color: pal.gray3,
                ).copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    final items = _buildItems();
    final query = _searching ? _searchCtrl.text.trim().toLowerCase() : '';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_emojiSheetOpen) setState(() => _emojiSheetOpen = false);
      },
      behavior: HitTestBehavior.translucent,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          if (item is _DayItem) {
            return _YappDaySeparator(label: item.label);
          }
          final msg = item as _MessageItem;
          final m = msg.message;
          final isMine = m.senderId == _currentUserId;
          final matchesSearch =
              query.isNotEmpty &&
              m.type == MessageType.text &&
              (m.text ?? '').toLowerCase().contains(query);
          final faded = query.isNotEmpty && !matchesSearch;

          return Padding(
            padding: EdgeInsets.only(
              bottom:
                  msg.groupPosition == BubbleGroupPosition.standalone ||
                      msg.groupPosition == BubbleGroupPosition.last
                  ? 12
                  : 1,
            ),
            child: Opacity(
              opacity: faded ? 0.35 : 1.0,
              child: SwipeToReply(
                alignStart: !isMine,
                onReply: () => _startReply(m),
                child: _LongPressableBubble(
                  onLongPressAt: (pos) => _showContextMenu(pos, m),
                  child: MessageBubble(
                    message: m,
                    isMine: isMine,
                    messenger: _repository,
                    autoDownloadMedia: _appSettings.autoDownloadMedia,
                    groupPosition: msg.groupPosition,
                    onReplyHeaderTap: _jumpToMessage,
                    onReactionTap: (emoji) => _toggleReaction(m.id, emoji),
                    highlight:
                        _highlightId == m.id ||
                        (matchesSearch && query.isNotEmpty),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_ListItem> _buildItems() {
    final out = <_ListItem>[];
    DateTime? lastDay;
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      final day = DateTime(
        m.timestamp.year,
        m.timestamp.month,
        m.timestamp.day,
      );
      if (lastDay == null || day != lastDay) {
        out.add(_DayItem(_formatDay(day)));
        lastDay = day;
        out.add(_MessageItem(m, _positionFor(i, groupStart: true)));
      } else {
        out.add(_MessageItem(m, _positionFor(i)));
      }
    }
    return out;
  }

  BubbleGroupPosition _positionFor(int i, {bool groupStart = false}) {
    final m = _messages[i];
    bool sameAs(int j) {
      if (j < 0 || j >= _messages.length) return false;
      final n = _messages[j];
      if (n.senderId != m.senderId) return false;
      if (n.timestamp.day != m.timestamp.day) return false;
      if ((m.timestamp.difference(n.timestamp)).inMinutes.abs() > 5) {
        return false;
      }
      return true;
    }

    final hasPrev = !groupStart && sameAs(i - 1);
    final hasNext = sameAs(i + 1);
    if (!hasPrev && !hasNext) return BubbleGroupPosition.standalone;
    if (!hasPrev && hasNext) return BubbleGroupPosition.first;
    if (hasPrev && !hasNext) return BubbleGroupPosition.last;
    return BubbleGroupPosition.middle;
  }

  String _formatDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    if (diff < 7) {
      const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      return weekdays[day.weekday - 1];
    }
    if (day.year == now.year) {
      return '${_month(day.month)} ${day.day}';
    }
    return '${_month(day.month)} ${day.day}, ${day.year}';
  }

  static String _month(int m) {
    const names = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    return names[m - 1];
  }
}

sealed class _ListItem {
  const _ListItem();
}

class _DayItem extends _ListItem {
  const _DayItem(this.label);
  final String label;
}

class _MessageItem extends _ListItem {
  const _MessageItem(this.message, this.groupPosition);
  final domain.Message message;
  final BubbleGroupPosition groupPosition;
}

class _YappDaySeparator extends StatelessWidget {
  const _YappDaySeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          color: pal.ink,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            label,
            style: Yapp.label(color: pal.paper).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}

class _LongPressableBubble extends StatefulWidget {
  const _LongPressableBubble({
    required this.child,
    required this.onLongPressAt,
  });

  final Widget child;
  final ValueChanged<Offset> onLongPressAt;

  @override
  State<_LongPressableBubble> createState() => _LongPressableBubbleState();
}

class _LongPressableBubbleState extends State<_LongPressableBubble> {
  Offset _lastPos = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _lastPos = d.globalPosition,
      onLongPressStart: (d) {
        _lastPos = d.globalPosition;
        widget.onLongPressAt(_lastPos);
      },
      child: widget.child,
    );
  }
}

enum _ChatOverflowAction { search, mute, delete }

class _YappChatHeader extends StatefulWidget {
  const _YappChatHeader({
    required this.peer,
    required this.typing,
    required this.onTapPeer,
    required this.onOverflowAction,
    this.isSaved = false,
    this.isMuted = false,
    this.showMuteAndDelete = true,
  });

  final User peer;
  final bool typing;
  final bool isSaved;
  final bool isMuted;
  final bool showMuteAndDelete;
  final VoidCallback onTapPeer;
  final void Function(_ChatOverflowAction) onOverflowAction;

  @override
  State<_YappChatHeader> createState() => _YappChatHeaderState();
}

class _YappChatHeaderState extends State<_YappChatHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final subtitle = widget.isSaved
        ? 'saved messages'
        : widget.typing
        ? 'typing…'
        : formatLastSeenLabel(
            isOnline: widget.peer.isOnline,
            lastSeenAt: widget.peer.lastSeenAt,
          );

    return Container(
      color: YappPalette.of(context).paper,
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: widget.onTapPeer,
              child: Row(
                children: [
                  _PeerAvatar(peer: widget.peer, isSaved: widget.isSaved),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (widget.isSaved ? 'you' : widget.peer.name)
                              .toLowerCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Yapp.name(color: YappPalette.of(context).ink)
                              .copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1,
                              ),
                          textDirection: Yapp.dirFor(widget.peer.name),
                        ),
                        const SizedBox(height: 2),
                        widget.typing
                            ? FadeTransition(
                                opacity: Tween<double>(
                                  begin: 0.45,
                                  end: 1,
                                ).animate(_pulse),
                                child: Text(
                                  subtitle,
                                  style: Yapp.label(
                                    color: pal.alert,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              )
                            : Text(
                                subtitle,
                                style: Yapp.label(
                                  color: YappPalette.of(context).gray2,
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ChatOverflowTrigger(
            isMuted: widget.isMuted,
            showMuteAndDelete: widget.showMuteAndDelete,
            onAction: widget.onOverflowAction,
          ),
        ],
      ),
    );
  }
}

class _ChatOverflowTrigger extends StatefulWidget {
  const _ChatOverflowTrigger({
    required this.isMuted,
    required this.showMuteAndDelete,
    required this.onAction,
  });

  final bool isMuted;
  final bool showMuteAndDelete;
  final void Function(_ChatOverflowAction) onAction;

  @override
  State<_ChatOverflowTrigger> createState() => _ChatOverflowTriggerState();
}

class _ChatOverflowTriggerState extends State<_ChatOverflowTrigger> {
  OverlayEntry? _entry;

  bool get _open => _entry != null;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _show();
    }
  }

  void _show() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final headerBottom = MediaQuery.paddingOf(context).top + 72 + 1;
    final entry = OverlayEntry(
      builder: (_) => _ChatOverflowPanel(
        top: headerBottom,
        isMuted: widget.isMuted,
        showMuteAndDelete: widget.showMuteAndDelete,
        onDismiss: _close,
        onPick: (a) {
          _close();
          widget.onAction(a);
        },
      ),
    );
    overlay.insert(entry);
    setState(() => _entry = entry);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return InkWell(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: AnimatedSwitcher(
          duration: Yapp.dur,
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween<double>(begin: 0.85, end: 1).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            _open ? Icons.close_rounded : Icons.more_vert_rounded,
            key: ValueKey(_open),
            color: pal.ink,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _ChatOverflowPanel extends StatefulWidget {
  const _ChatOverflowPanel({
    required this.top,
    required this.isMuted,
    required this.showMuteAndDelete,
    required this.onDismiss,
    required this.onPick,
  });

  final double top;
  final bool isMuted;
  final bool showMuteAndDelete;
  final VoidCallback onDismiss;
  final void Function(_ChatOverflowAction) onPick;

  @override
  State<_ChatOverflowPanel> createState() => _ChatOverflowPanelState();
}

class _ChatOverflowPanelState extends State<_ChatOverflowPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: Yapp.dur,
  )..forward();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final fade = CurvedAnimation(parent: _ctl, curve: Yapp.curve);
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(fade);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismiss,
            child: FadeTransition(
              opacity: fade,
              child: Container(color: pal.ink.withValues(alpha: 0.12)),
            ),
          ),
        ),
        Positioned(
          top: widget.top,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: _ChatOverflowList(
                isMuted: widget.isMuted,
                showMuteAndDelete: widget.showMuteAndDelete,
                onPick: widget.onPick,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatOverflowList extends StatelessWidget {
  const _ChatOverflowList({
    required this.isMuted,
    required this.showMuteAndDelete,
    required this.onPick,
  });

  final bool isMuted;
  final bool showMuteAndDelete;
  final void Function(_ChatOverflowAction) onPick;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Material(
      color: pal.paper,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChatOverflowRow(
            label: 'search',
            hint: 'find anything in this chat',
            onTap: () => onPick(_ChatOverflowAction.search),
          ),
          if (showMuteAndDelete)
            _ChatOverflowRow(
              label: isMuted ? 'unmute' : 'mute chat',
              hint: isMuted
                  ? 'turn notifications back on'
                  : 'silence notifications, keep messages',
              onTap: () => onPick(_ChatOverflowAction.mute),
            ),
          if (showMuteAndDelete)
            _ChatOverflowRow(
              label: 'delete chat',
              hint: 'messages will be removed for you only',
              destructive: true,
              onTap: () => onPick(_ChatOverflowAction.delete),
            ),
        ],
      ),
    );
  }
}

class _ChatOverflowRow extends StatefulWidget {
  const _ChatOverflowRow({
    required this.label,
    required this.hint,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool destructive;

  @override
  State<_ChatOverflowRow> createState() => _ChatOverflowRowState();
}

class _ChatOverflowRowState extends State<_ChatOverflowRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final labelColor = widget.destructive ? pal.alert : pal.ink;
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
            bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20 - Yapp.tickWidth, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: Yapp.name(color: labelColor).copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(widget.hint, style: Yapp.body(color: pal.gray2)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            YappGlyph.forward(color: labelColor, size: 22),
          ],
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.peer, required this.isSaved});
  final User peer;
  final bool isSaved;

  static const double _size = 42;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);

    if (isSaved) {
      return Container(
        width: _size,
        height: _size,
        color: pal.ink,
        alignment: Alignment.center,
        child: Text(
          'y',
          style: TextStyle(
            color: pal.paper,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1,
            fontFamily: Yapp.display().fontFamily,
          ),
        ),
      );
    }

    final initial = peer.name.trim().isEmpty
        ? '?'
        : peer.name.trim().characters.first.toUpperCase();

    final face = SizedBox(
      width: _size,
      height: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pal.gray4,
          border: Border.all(color: pal.ink, width: Yapp.hairline),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                initial,
                style: Yapp.display(
                  color: pal.gray2,
                ).copyWith(fontSize: 20, height: 1),
              ),
            ),
            Positioned.fill(child: PeerAvatar(user: peer)),
          ],
        ),
      ),
    );

    if (!peer.isOnline) return face;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        face,
        Positioned(
          right: -3,
          bottom: -3,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: pal.ink,
              border: Border.all(color: pal.paper, width: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _YappSearchHeader extends StatelessWidget {
  const _YappSearchHeader({
    required this.controller,
    required this.focusNode,
    required this.onClose,
    required this.onChanged,
    required this.matchCount,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClose;
  final VoidCallback onChanged;
  final int matchCount;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      color: pal.paper,
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: YappGlyph.back(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Yapp.bidi(
              controller: controller,
              builder: (dir) => TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                onChanged: (_) => onChanged(),
                cursorColor: pal.ink,
                cursorWidth: 2,
                style: Yapp.bubble(color: pal.ink).copyWith(fontSize: 18),
                textAlign: TextAlign.start,
                textDirection: dir,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'search in chat',
                  hintStyle: Yapp.bubble(
                    color: pal.gray3,
                  ).copyWith(fontSize: 18),
                ),
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                matchCount == 0 ? '0' : '$matchCount',
                style: Yapp.label(
                  color: matchCount == 0 ? pal.alert : pal.ink,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

class _YappPinnedBanner extends StatelessWidget {
  const _YappPinnedBanner({
    required this.message,
    required this.onTap,
    required this.onClose,
  });

  final domain.Message message;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final body = message.type == MessageType.text
        ? stripMessageMarkdown(message.text ?? '')
        : _typeSummary(message.type);

    return Container(
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border(bottom: BorderSide(color: pal.ink, width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 8, color: pal.ink),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'pinned',
                        style: Yapp.label(color: pal.gray2).copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body.toLowerCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Yapp.bubble(color: pal.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: YappGlyph.close(color: pal.ink, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _typeSummary(MessageType t) => '';
}

class _YappEditingBanner extends StatelessWidget {
  const _YappEditingBanner({required this.preview, required this.onCancel});
  final String preview;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border(top: BorderSide(color: pal.ink, width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: pal.ink),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'editing:',
                      style: Yapp.label(
                        color: pal.gray2,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview.toLowerCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Yapp.bubble(color: pal.ink),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: onCancel,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  'cancel',
                  style: Yapp.label(
                    color: pal.ink,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YappSendingBanner extends StatelessWidget {
  const _YappSendingBanner({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border(top: BorderSide(color: pal.ink, width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: pal.ink),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(pal.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'sending $label…',
                      style: Yapp.bubble(
                        color: pal.ink,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YappBlockedBanner extends StatelessWidget {
  const _YappBlockedBanner({required this.peerName, required this.onUnblock});
  final String peerName;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: pal.ink,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'you blocked ${peerName.toLowerCase()}.',
                style: Yapp.bubble(
                  color: pal.paper,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            InkWell(
              onTap: onUnblock,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'unblock',
                  style: Yapp.label(color: pal.paper).copyWith(
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YappScrollDown extends StatelessWidget {
  const _YappScrollDown({required this.visible, required this.onTap});
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: Yapp.dur,
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: Yapp.dur,
          offset: visible ? Offset.zero : const Offset(0, 0.25),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 36,
              height: 36,
              color: pal.ink,
              alignment: Alignment.center,
              child: YappGlyph.down(color: pal.paper, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
