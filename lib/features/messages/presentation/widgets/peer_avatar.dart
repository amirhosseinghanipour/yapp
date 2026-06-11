import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/di/app_scope.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/messenger_repository.dart';

class PeerAvatar extends StatefulWidget {
  const PeerAvatar({
    super.key,
    required this.user,
    this.placeholder = const SizedBox.shrink(),
  });

  final User user;
  final Widget placeholder;

  @override
  State<PeerAvatar> createState() => _PeerAvatarState();
}

class _PeerAvatarState extends State<PeerAvatar> {
  Uint8List? _bytes;
  String? _loadedKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(PeerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoad();
  }

  void _maybeLoad() {
    final key = widget.user.avatarBlob?.objectKey;
    if (key == null) {
      if (_bytes != null || _loadedKey != null) {
        setState(() {
          _bytes = null;
          _loadedKey = null;
        });
      }
      return;
    }
    if (key == _loadedKey) return;
    _loadedKey = key;
    unawaited(_load(AppScope.of(context), key));
  }

  Future<void> _load(MessengerRepository repo, String key) async {
    final bytes = await repo.loadPeerAvatar(widget.user);
    if (!mounted) return;
    if (widget.user.avatarBlob?.objectKey != key) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    }
    if (widget.user.avatarBlob != null) {
      return widget.placeholder;
    }
    final url = widget.user.avatarUrl;
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => widget.placeholder,
      );
    }
    return widget.placeholder;
  }
}
