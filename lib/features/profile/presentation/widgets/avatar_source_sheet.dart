import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../../messages/presentation/yapp_design.dart';

enum AvatarSourceResult { picked, removed }

class AvatarSourcePayload {
  const AvatarSourcePayload(this.result, {this.path});
  final AvatarSourceResult result;
  final String? path;
}

Future<AvatarSourcePayload?> showAvatarSourceSheet(
  BuildContext context, {
  required bool canRemove,
}) {
  return showModalBottomSheet<AvatarSourcePayload>(
    context: context,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => _AvatarSourceBody(canRemove: canRemove),
  );
}

class _AvatarSourceBody extends StatelessWidget {
  const _AvatarSourceBody({required this.canRemove});
  final bool canRemove;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1440,
        maxHeight: 1440,
        imageQuality: 86,
      );
      if (!context.mounted) return;
      if (file == null) {
        Navigator.of(context).pop();
        return;
      }
      Navigator.of(
        context,
      ).pop(AvatarSourcePayload(AvatarSourceResult.picked, path: file.path));
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('could not open photo source')),
        );
    }
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
            child: Text(
              'profile photo',
              style: Yapp.display().copyWith(fontSize: 28),
            ),
          ),
          _Row(
            label: 'take photo',
            icon: Icons.photo_camera_outlined,
            onTap: () => _pick(context, ImageSource.camera),
          ),
          _Row(
            label: 'choose from library',
            icon: Icons.photo_library_outlined,
            onTap: () => _pick(context, ImageSource.gallery),
          ),
          if (canRemove)
            _Row(
              label: 'remove photo',
              icon: Icons.delete_outline_rounded,
              onTap: () => Navigator.of(
                context,
              ).pop(const AvatarSourcePayload(AvatarSourceResult.removed)),
              destructive: true,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final base = widget.destructive ? pal.alert : pal.ink;
    final bg = _pressed ? base : pal.paper;
    final fg = _pressed ? pal.paper : base;
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
