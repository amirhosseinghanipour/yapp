import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../yapp_design.dart';

class VoiceRecording {
  const VoiceRecording({required this.path, required this.durationMs});
  final String path;
  final int durationMs;
}

Future<VoiceRecording?> showVoiceRecorderSheet(BuildContext context) {
  return showModalBottomSheet<VoiceRecording>(
    context: context,
    elevation: 0,
    isDismissible: true,
    enableDrag: false,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => const _VoiceRecorderBody(),
  );
}

class _VoiceRecorderBody extends StatefulWidget {
  const _VoiceRecorderBody();

  @override
  State<_VoiceRecorderBody> createState() => _VoiceRecorderBodyState();
}

class _VoiceRecorderBodyState extends State<_VoiceRecorderBody>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  String? _path;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        if (!mounted) return;
        setState(() => _error = 'microphone permission denied');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/yapp_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _path = path;
        _recording = true;
        _startedAt = DateTime.now();
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || _startedAt == null) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'could not start recording');
    }
  }

  Future<void> _send() async {
    if (!_recording) {
      Navigator.of(context).pop();
      return;
    }
    _ticker?.cancel();
    final ms = _elapsed.inMilliseconds;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = _path;
    }
    if (!mounted) return;
    final out = path ?? _path;
    if (out == null || ms < 300) {
      Navigator.of(context).pop();
      return;
    }
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(VoiceRecording(path: out, durationMs: ms));
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    if (_recording) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: pal.ink, width: Yapp.hairline),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              children: [
                if (_error == null)
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.25, end: 1).animate(_pulse),
                    child: Container(width: 14, height: 14, color: pal.alert),
                  ),
                if (_error == null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error ?? (_recording ? _timeLabel : 'starting…'),
                    style: Yapp.display(
                      color: _error != null ? pal.alert : null,
                    ).copyWith(fontSize: 28),
                  ),
                ),
              ],
            ),
          ),
          if (_error == null)
            _StampRow(
              label: 'send  →',
              fill: pal.ink,
              textColor: pal.paper,
              onTap: _send,
            ),
          if (_error == null) Container(height: Yapp.hairline, color: pal.ink),
          _StampRow(
            label: 'cancel',
            fill: pal.paper,
            textColor: pal.ink,
            onTap: _cancel,
          ),
        ],
      ),
    );
  }
}

class _StampRow extends StatefulWidget {
  const _StampRow({
    required this.label,
    required this.fill,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<_StampRow> createState() => _StampRowState();
}

class _StampRowState extends State<_StampRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = _pressed ? widget.textColor : widget.fill;
    final fg = _pressed ? widget.fill : widget.textColor;
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
        color: bg,
        alignment: Alignment.center,
        child: Text(widget.label, style: Yapp.cta(color: fg)),
      ),
    );
  }
}
