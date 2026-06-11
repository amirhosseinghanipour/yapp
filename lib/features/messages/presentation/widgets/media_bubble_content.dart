import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/message_type.dart';
import '../../domain/repositories/messenger_repository.dart';
import '../screens/media_viewer_screen.dart';
import '../yapp_design.dart';

final Map<String, Uint8List> _mediaBytesCache = <String, Uint8List>{};

final ValueNotifier<String?> _activeAudioId = ValueNotifier<String?>(null);

Future<Uint8List> _loadBytes(
  MessengerRepository messenger,
  Message message,
) async {
  final cached = _mediaBytesCache[message.id];
  if (cached != null) return cached;
  final bytes = await messenger.downloadMedia(message.attachment!);
  _mediaBytesCache[message.id] = bytes;
  return bytes;
}

class MediaBubbleContent extends StatelessWidget {
  const MediaBubbleContent({
    super.key,
    required this.message,
    required this.isMine,
    required this.onDark,
    this.messenger,
    this.autoDownload = true,
  });

  final Message message;
  final bool isMine;
  final bool onDark;
  final MessengerRepository? messenger;

  final bool autoDownload;

  @override
  Widget build(BuildContext context) {
    final att = message.attachment;

    if (message.type == MessageType.location) {
      return _LocationTile(attachment: att, onDark: onDark);
    }

    final messenger = this.messenger;
    if (messenger == null || att == null || !att.hasBlob) {
      return _MediaPlaceholder(type: message.type, onDark: onDark);
    }

    if (!autoDownload && !_mediaBytesCache.containsKey(message.id)) {
      return _DownloadGate(
        message: message,
        isMine: isMine,
        onDark: onDark,
        messenger: messenger,
      );
    }

    switch (message.type) {
      case MessageType.image:
      case MessageType.gif:
      case MessageType.sticker:
        return _ImageTile(
          message: message,
          messenger: messenger,
          onDark: onDark,
        );
      case MessageType.voice:
      case MessageType.audio:
        return _AudioTile(
          message: message,
          messenger: messenger,
          onDark: onDark,
        );
      case MessageType.video:
        return _VideoTile(
          message: message,
          messenger: messenger,
          onDark: onDark,
        );
      case MessageType.file:
        return _FileTile(
          message: message,
          messenger: messenger,
          onDark: onDark,
        );
      case MessageType.text:
      case MessageType.location:
        return _MediaPlaceholder(type: message.type, onDark: onDark);
    }
  }
}

String _humanSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = ['b', 'kb', 'mb', 'gb'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final v = size >= 100 || unit == 0
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(1);
  return '$v ${units[unit]}';
}

String _durationLabel(int? ms) {
  if (ms == null || ms <= 0) return '0:00';
  final d = Duration(milliseconds: ms);
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _extLabel(Attachment att) {
  final name = att.fileName ?? '';
  final dot = name.lastIndexOf('.');
  if (dot != -1 && dot < name.length - 1) {
    final ext = name.substring(dot + 1).toLowerCase();
    if (ext.isNotEmpty && ext.length <= 4) return ext;
  }
  final mime = att.mime ?? '';
  if (mime.contains('/')) {
    final sub = mime.split('/').last.toLowerCase();
    if (sub.isNotEmpty && sub.length <= 4) return sub;
  }
  return 'file';
}

Color _fgFor(bool onDark) => onDark ? Yapp.paper : Yapp.ink;

Color _washFor(bool onDark) => onDark
    ? Yapp.paper.withValues(alpha: 0.12)
    : Yapp.ink.withValues(alpha: 0.06);

Future<File> _writeTemp(String id, String suffix, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final safe = suffix.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${dir.path}/yapp_media_${id}_$safe');
  if (!file.existsSync()) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return file;
}

List<double> _waveBars(String seed, int count) {
  var h = (seed.hashCode & 0x7fffffff) | 1;
  final out = <double>[];
  for (var i = 0; i < count; i++) {
    h = (h * 1103515245 + 12345) & 0x7fffffff;
    out.add(0.18 + (h % 1000) / 1000.0 * 0.82);
  }
  return out;
}

class _DownloadGate extends StatefulWidget {
  const _DownloadGate({
    required this.message,
    required this.isMine,
    required this.onDark,
    required this.messenger,
  });

  final Message message;
  final bool isMine;
  final bool onDark;
  final MessengerRepository messenger;

  @override
  State<_DownloadGate> createState() => _DownloadGateState();
}

class _DownloadGateState extends State<_DownloadGate> {
  bool _loading = false;
  bool _failed = false;

  bool get _visual => switch (widget.message.type) {
    MessageType.image ||
    MessageType.gif ||
    MessageType.sticker ||
    MessageType.video => true,
    _ => false,
  };

  Future<void> _download() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await _loadBytes(widget.messenger, widget.message);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaBytesCache.containsKey(widget.message.id)) {
      return MediaBubbleContent(
        message: widget.message,
        isMine: widget.isMine,
        onDark: widget.onDark,
        messenger: widget.messenger,
      );
    }

    final fg = _fgFor(widget.onDark);
    final att = widget.message.attachment!;
    final size = _humanSize(att.size);
    final label = _failed
        ? 'failed — tap to retry'
        : _loading
        ? 'downloading…'
        : size.isEmpty
        ? 'tap to download'
        : 'tap to download · $size';

    final body = ColoredBox(
      color: _washFor(widget.onDark),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            else
              Icon(Icons.arrow_downward_rounded, size: 22, color: fg),
            const SizedBox(height: 8),
            Text(
              label,
              style: Yapp.label(color: fg).copyWith(letterSpacing: 1),
            ),
          ],
        ),
      ),
    );

    final w = att.width, h = att.height;
    final aspect = (w != null && h != null && w > 0 && h > 0) ? w / h : 1.0;

    return GestureDetector(
      onTap: _download,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: fg, width: 1)),
        child: _visual
            ? AspectRatio(aspectRatio: aspect.clamp(0.8, 1.5), child: body)
            : SizedBox(height: 72, width: double.infinity, child: body),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.message,
    required this.messenger,
    required this.onDark,
  });

  final Message message;
  final MessengerRepository messenger;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(onDark);
    final att = message.attachment!;
    final w = att.width, h = att.height;
    final aspect = (w != null && h != null && w > 0 && h > 0) ? w / h : 1.0;
    final isGif = message.type == MessageType.gif;

    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: fg, width: 1)),
      child: AspectRatio(
        aspectRatio: aspect.clamp(0.8, 1.5),
        child: FutureBuilder<Uint8List>(
          future: _loadBytes(messenger, message),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _MediaLoading(onDark: onDark, label: 'loading');
            }
            if (snap.hasError || snap.data == null) {
              return _MediaError(onDark: onDark);
            }
            final bytes = snap.data!;
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MediaViewerScreen.image(
                    bytes: bytes,
                    caption: message.text,
                    mime: att.mime,
                    fileName: att.fileName,
                  ),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _MediaError(onDark: onDark),
                  ),
                  if (isGif)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: _CornerTag(label: 'gif'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CornerTag extends StatelessWidget {
  const _CornerTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      color: pal.ink,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        label,
        style: Yapp.label(
          color: pal.paper,
        ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 10),
      ),
    );
  }
}

class _VideoTile extends StatefulWidget {
  const _VideoTile({
    required this.message,
    required this.messenger,
    required this.onDark,
  });

  final Message message;
  final MessengerRepository messenger;
  final bool onDark;

  @override
  State<_VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<_VideoTile> {
  bool _busy = false;

  Future<void> _openViewer() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _loadBytes(widget.messenger, widget.message);
      if (!mounted) return;
      final att = widget.message.attachment!;
      final meta = [
        'video',
        if ((att.durationMs ?? 0) > 0) _durationLabel(att.durationMs),
        _humanSize(att.size),
      ].where((s) => s.isNotEmpty).join('  ·  ');
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MediaViewerScreen.video(
            bytes: bytes,
            caption: widget.message.text,
            mime: att.mime,
            fileName: att.fileName,
            metaLabel: meta,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('could not open video')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(widget.onDark);
    final att = widget.message.attachment!;
    final meta = [
      'video',
      if ((att.durationMs ?? 0) > 0) _durationLabel(att.durationMs),
      _humanSize(att.size),
    ].where((s) => s.isNotEmpty).join('  ·  ');

    return GestureDetector(
      onTap: _openViewer,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _washFor(widget.onDark),
                border: Border.all(color: fg, width: 1),
              ),
              child: Center(
                child: _busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(fg),
                        ),
                      )
                    : _TransportSquare(
                        playing: false,
                        fg: fg,
                        bg: fg,
                        glyphColor: _fgFor(!widget.onDark),
                        size: 52,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            meta,
            style: Yapp.meta(color: fg).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AudioTile extends StatefulWidget {
  const _AudioTile({
    required this.message,
    required this.messenger,
    required this.onDark,
  });

  final Message message;
  final MessengerRepository messenger;
  final bool onDark;

  @override
  State<_AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<_AudioTile> {
  AudioPlayer? _player;
  bool _loading = false;
  bool _failed = false;
  Duration _position = Duration.zero;
  Duration? _total;

  @override
  void initState() {
    super.initState();
    _activeAudioId.addListener(_onActiveAudioChanged);
  }

  void _onActiveAudioChanged() {
    if (_activeAudioId.value != widget.message.id &&
        (_player?.playing ?? false)) {
      _player?.pause();
    }
  }

  @override
  void dispose() {
    _activeAudioId.removeListener(_onActiveAudioChanged);
    if (_activeAudioId.value == widget.message.id) {
      _activeAudioId.value = null;
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    if (_player != null || _loading) return;
    setState(() => _loading = true);
    try {
      final bytes = await _loadBytes(widget.messenger, widget.message);
      final mime = widget.message.attachment?.mime ?? '';
      final ext = mime.contains('mpeg')
          ? 'mp3'
          : mime.contains('wav')
          ? 'wav'
          : 'm4a';
      final file = await _writeTemp(widget.message.id, 'audio.$ext', bytes);
      final player = AudioPlayer();
      final dur = await player.setFilePath(file.path);
      if (!mounted) {
        await player.dispose();
        return;
      }
      player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      player.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          player.seek(Duration.zero);
          player.pause();
        }
        setState(() {});
      });
      setState(() {
        _player = player;
        _total = dur;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _toggle() async {
    if (_failed) return;
    if (_player == null) {
      await _ensureLoaded();
      if (_player == null) return;
    }
    final player = _player!;
    if (player.playing) {
      await player.pause();
    } else {
      _activeAudioId.value = widget.message.id;
      await player.play();
    }
  }

  Future<void> _seekFraction(double f) async {
    if (_player == null) await _ensureLoaded();
    final player = _player;
    if (player == null) return;
    final total =
        _total ??
        Duration(milliseconds: widget.message.attachment?.durationMs ?? 0);
    await player.seek(total * f);
    if (!player.playing) {
      _activeAudioId.value = widget.message.id;
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(widget.onDark);
    final bgInverse = _fgFor(!widget.onDark);
    final playing = _player?.playing ?? false;
    final total =
        _total ??
        Duration(milliseconds: widget.message.attachment?.durationMs ?? 0);
    final progress = (total.inMilliseconds > 0)
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final isVoice = widget.message.type == MessageType.voice;
    final att = widget.message.attachment;
    final label = isVoice
        ? 'voice note'
        : (att?.fileName != null && att!.fileName!.trim().isNotEmpty
              ? att.fileName!.trim()
              : 'audio');
    final remaining = _player == null
        ? _durationLabel(total.inMilliseconds)
        : _durationLabel(_position.inMilliseconds);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: _loading
              ? Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: fg)),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  ),
                )
              : _failed
              ? Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border.all(color: fg)),
                  child: Icon(Icons.error_outline_rounded, color: fg, size: 20),
                )
              : _TransportSquare(
                  playing: playing,
                  fg: fg,
                  bg: fg,
                  glyphColor: bgInverse,
                  size: 40,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Yapp.label(color: fg).copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: isVoice ? 1 : 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(remaining, style: Yapp.meta(color: fg)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 26,
                child: _Waveform(
                  seed: widget.message.id,
                  progress: progress,
                  fg: fg,
                  faded: fg.withValues(alpha: 0.42),
                  onSeek: _failed ? null : _seekFraction,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportSquare extends StatelessWidget {
  const _TransportSquare({
    required this.playing,
    required this.fg,
    required this.bg,
    required this.glyphColor,
    this.size = 40,
  });

  final bool playing;
  final Color fg;
  final Color bg;
  final Color glyphColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: bg,
      child: CustomPaint(
        painter: _TransportPainter(playing: playing, color: glyphColor),
      ),
    );
  }
}

class _TransportPainter extends CustomPainter {
  _TransportPainter({required this.playing, required this.color});
  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    if (playing) {
      final barW = w * 0.16;
      final barH = h * 0.42;
      final top = (h - barH) / 2;
      final gap = w * 0.12;
      final cx = w / 2;
      canvas.drawRect(
        Rect.fromLTWH(cx - gap / 2 - barW, top, barW, barH),
        paint,
      );
      canvas.drawRect(Rect.fromLTWH(cx + gap / 2, top, barW, barH), paint);
    } else {
      final path = Path()
        ..moveTo(w * 0.36, h * 0.30)
        ..lineTo(w * 0.36, h * 0.70)
        ..lineTo(w * 0.70, h * 0.50)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TransportPainter old) =>
      old.playing != playing || old.color != color;
}

class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.seed,
    required this.progress,
    required this.fg,
    required this.faded,
    this.onSeek,
  });

  final String seed;
  final double progress;
  final Color fg;
  final Color faded;

  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const barW = 3.0;
        const gap = 2.0;
        final count = ((c.maxWidth + gap) / (barW + gap)).floor().clamp(8, 64);
        final bars = _waveBars(seed, count);
        final playedTo = (count * progress).round();
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: bars[i],
                    child: ColoredBox(color: i < playedTo ? fg : faded),
                  ),
                ),
              ),
            ],
          ],
        );
        final onSeek = this.onSeek;
        if (onSeek == null) return row;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) =>
              onSeek((d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
          child: row,
        );
      },
    );
  }
}

class _FileTile extends StatefulWidget {
  const _FileTile({
    required this.message,
    required this.messenger,
    required this.onDark,
  });

  final Message message;
  final MessengerRepository messenger;
  final bool onDark;

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _busy = false;

  Future<void> _openOrShare() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _loadBytes(widget.messenger, widget.message);
      final att = widget.message.attachment!;
      final name = att.fileName ?? 'file';
      final file = await _writeTemp(widget.message.id, name, bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: att.mime, name: name)],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('could not open file')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(widget.onDark);
    final bgInverse = _fgFor(!widget.onDark);
    final att = widget.message.attachment!;
    final name = att.fileName ?? 'file';
    final ext = _extLabel(att);
    final size = _humanSize(att.size);

    return GestureDetector(
      onTap: _openOrShare,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            color: fg,
            child: _busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(bgInverse),
                    ),
                  )
                : Text(
                    ext,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: Yapp.label(color: bgInverse).copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toLowerCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Yapp.bubble(
                    color: fg,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (size.isNotEmpty) ...[
                      Text(size, style: Yapp.meta(color: fg)),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'tap to open',
                      style: Yapp.meta(
                        color: fg,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.attachment, required this.onDark});

  final Attachment? attachment;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(onDark);
    final lat = attachment?.lat;
    final lng = attachment?.lng;
    final hasCoords = lat != null && lng != null;
    final coords = hasCoords
        ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'
        : 'location unavailable';

    return GestureDetector(
      onTap: hasCoords
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MediaViewerScreen.location(lat: lat, lng: lng),
              ),
            )
          : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _washFor(onDark),
                border: Border.all(color: fg, width: 1),
              ),
              child: CustomPaint(
                painter: _MapGridPainter(
                  line: fg.withValues(alpha: 0.28),
                  pin: fg,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'location',
            style: Yapp.label(
              color: fg,
            ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(coords, style: Yapp.bubble(color: fg).copyWith(fontSize: 13)),
          if (hasCoords) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'open in maps',
                  style: Yapp.meta(
                    color: fg,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                YappGlyph.forward(color: fg, size: 14),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  _MapGridPainter({required this.line, required this.pin});
  final Color line;
  final Color pin;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    const step = 22.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final cx = size.width / 2;
    final cy = size.height / 2;
    final fill = Paint()
      ..color = pin
      ..style = PaintingStyle.fill;
    const s = 12.0;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy - 4), width: s, height: s),
      fill,
    );
    final stem = Path()
      ..moveTo(cx - 5, cy + 2)
      ..lineTo(cx + 5, cy + 2)
      ..lineTo(cx, cy + 12)
      ..close();
    canvas.drawPath(stem, fill);
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => old.line != line || old.pin != pin;
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading({required this.onDark, this.label});
  final bool onDark;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(onDark);
    return Container(
      color: _washFor(onDark),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(
              label!,
              style: Yapp.label(
                color: fg,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError({required this.onDark});
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(onDark);
    return Container(
      color: _washFor(onDark),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: fg, size: 26),
          const SizedBox(height: 6),
          Text(
            "couldn't load",
            style: Yapp.label(
              color: fg,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.type, required this.onDark});
  final MessageType type;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = _fgFor(onDark);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: fg, width: 1)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, color: fg),
            const SizedBox(width: 8),
            Text(
              type.name,
              style: Yapp.bubble(
                color: fg,
              ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
