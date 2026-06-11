import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../../messages/presentation/yapp_design.dart';
import '../../domain/entities/my_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.size,
    this.profile,
    this.repository,
    this.source,
    this.borderWidth = 0,
    this.borderColor,
  }) : assert(
         profile != null || source != null,
         'ProfileAvatar needs a profile (for encrypted blobs) or a source url/path',
       );

  final MyProfile? profile;

  final ProfileRepository? repository;

  final String? source;

  final double size;
  final double borderWidth;
  final Color? borderColor;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _maybeLoadBlob();
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?.avatarBlob?.objectKey !=
        widget.profile?.avatarBlob?.objectKey) {
      setState(() => _bytes = null);
      _maybeLoadBlob();
    }
  }

  Future<void> _maybeLoadBlob() async {
    final repo = widget.repository;
    final profile = widget.profile;
    if (repo == null || profile?.avatarBlob == null) return;
    final bytes = await repo.loadAvatarBytes(profile!);
    if (!mounted) return;
    setState(() => _bytes = bytes);
  }

  String get _legacySource => widget.source ?? widget.profile?.avatarUrl ?? '';

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final size = widget.size;
    final placeholder = Container(
      width: size,
      height: size,
      color: pal.gray4,
      alignment: Alignment.center,
      child: Text(
        '—',
        style: Yapp.display(
          color: pal.ink,
        ).copyWith(fontSize: size * 0.4, height: 1),
      ),
    );

    Widget child;
    if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      final source = _legacySource;
      final uri = Uri.tryParse(source);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        child = Image.network(
          source,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        );
      } else if (source.isNotEmpty) {
        final file = uri != null && uri.scheme == 'file'
            ? File.fromUri(uri)
            : File(source);
        child = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => placeholder,
        );
      } else {
        child = placeholder;
      }
    }

    Widget avatar = SizedBox(width: size, height: size, child: child);
    if (widget.borderWidth > 0) {
      avatar = Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.borderColor ?? pal.ink,
            width: widget.borderWidth.clamp(1, 4),
          ),
        ),
        child: avatar,
      );
    }
    return avatar;
  }
}
