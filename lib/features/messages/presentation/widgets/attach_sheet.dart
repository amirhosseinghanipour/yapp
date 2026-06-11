import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../yapp_design.dart';

enum AttachChoice { photo, camera, file, voice, location }

Future<AttachChoice?> showAttachSheet(BuildContext context) {
  return showModalBottomSheet<AttachChoice>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (_) => const _AttachSheetBody(),
  );
}

class _AttachSheetBody extends StatelessWidget {
  const _AttachSheetBody();

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
            child: Text('attach', style: Yapp.display().copyWith(fontSize: 28)),
          ),
          _AttachRow(
            label: 'photo',
            icon: Icons.photo_outlined,
            onTap: () => Navigator.of(context).pop(AttachChoice.photo),
          ),
          _AttachRow(
            label: 'camera',
            icon: Icons.photo_camera_outlined,
            onTap: () => Navigator.of(context).pop(AttachChoice.camera),
          ),
          _AttachRow(
            label: 'file',
            icon: Icons.insert_drive_file_outlined,
            onTap: () => Navigator.of(context).pop(AttachChoice.file),
          ),
          _AttachRow(
            label: 'voice',
            icon: Icons.mic_none_rounded,
            onTap: () => Navigator.of(context).pop(AttachChoice.voice),
          ),
          _AttachRow(
            label: 'location',
            icon: Icons.location_on_outlined,
            onTap: () => Navigator.of(context).pop(AttachChoice.location),
          ),
        ],
      ),
    );
  }
}

class _AttachRow extends StatefulWidget {
  const _AttachRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_AttachRow> createState() => _AttachRowState();
}

class _AttachRowState extends State<_AttachRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final bg = _pressed ? pal.ink : pal.paper;
    final fg = _pressed ? pal.paper : pal.ink;
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
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            SizedBox(width: 28, child: Icon(widget.icon, color: fg, size: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                style: Yapp.name(color: fg).copyWith(fontSize: 16),
              ),
            ),
            YappGlyph.forward(color: fg),
          ],
        ),
      ),
    );
  }
}
