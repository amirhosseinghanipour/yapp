import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/app_scope.dart';
import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/yapp_design.dart';
import '../../settings/presentation/widgets/yapp_confirm_sheet.dart';
import '../domain/entities/my_profile.dart';
import '../domain/repositories/profile_repository.dart';
import 'widgets/avatar_source_sheet.dart';
import 'widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _bio;

  ProfileRepository? _repo;
  MyProfile? _original;
  MyProfile? _live;
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _username = TextEditingController();
    _bio = TextEditingController();
    for (final c in [_name, _username, _bio]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _repo = AppScope.profileOf(context);
    _repo!.getMyProfile().then((p) {
      if (!mounted) return;
      setState(() {
        _original = p;
        _live = p;
        _name.text = p.displayName;
        _username.text = p.username ?? '';
        _bio.text = p.bio ?? '';
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final p = _original;
    if (p == null || _live == null) return false;
    return _name.text.trim() != p.displayName ||
        _username.text.trim() != (p.username ?? '') ||
        _bio.text.trim() != (p.bio ?? '') ||
        _live!.avatarUrl != p.avatarUrl ||
        _live!.avatarBlob?.objectKey != p.avatarBlob?.objectKey;
  }

  Future<void> _pickAvatar() async {
    final repo = _repo;
    final live = _live;
    if (repo == null || live == null) return;
    final result = await showAvatarSourceSheet(context, canRemove: true);
    if (result == null) return;
    MyProfile next;
    if (result.result == AvatarSourceResult.picked && result.path != null) {
      next = await repo.updateAvatar(result.path!);
    } else {
      next = await repo.removeAvatar();
    }
    if (!mounted) return;
    setState(() => _live = next);
  }

  Future<void> _save() async {
    final repo = _repo;
    if (repo == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final trimmedName = _name.text.trim();
    final trimmedUsername = _username.text.trim();
    final trimmedBio = _bio.text.trim();

    await repo.updateProfile(
      displayName: trimmedName,
      username: trimmedUsername.isEmpty ? null : trimmedUsername,
      unsetUsername: trimmedUsername.isEmpty,
      bio: trimmedBio.isEmpty ? null : trimmedBio,
      unsetBio: trimmedBio.isEmpty,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('profile saved')));
    Navigator.of(context).maybePop();
  }

  Future<bool> _confirmDiscard() async {
    if (!_hasChanges) return true;
    final ok = await showYappConfirmSheet(
      context,
      headline: 'discard changes?',
      body: 'you haven\'t saved your profile yet.',
      primaryLabel: 'discard',
      cancelLabel: 'keep editing',
      destructive: true,
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final canSave = _hasChanges && !_saving;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (!ok || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: pal.paper,
        body: _original == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _Header(
                        onBack: () async {
                          final ok = await _confirmDiscard();
                          if (!ok || !context.mounted) return;
                          Navigator.of(context).maybePop();
                        },
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _AvatarEditor(
                              profile: _live!,
                              repository: _repo!,
                              onTap: _pickAvatar,
                            ),
                            const YappSectionLabel('about you', topSpace: 24),
                            _Field(
                              label: 'name',
                              controller: _name,
                              hint: 'your full name',
                              maxLength: 60,
                              validator: (v) {
                                if (v.trim().isEmpty) return 'name is required';
                                return null;
                              },
                            ),
                            _Field(
                              label: 'handle',
                              controller: _username,
                              hint: 'handle',
                              prefix: '@',
                              maxLength: 24,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-zA-Z0-9_\.]'),
                                ),
                              ],
                              helper:
                                  'letters, numbers, underscores, dots. empty to remove.',
                              validator: (v) {
                                final value = v.trim();
                                if (value.isEmpty) return null;
                                if (value.length < 3) {
                                  return 'at least 3 characters';
                                }
                                return null;
                              },
                            ),
                            _Field(
                              label: 'bio',
                              controller: _bio,
                              hint: 'tell people about yourself',
                              maxLength: 140,
                              minLines: 1,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                      _SaveBar(enabled: canSave, onSave: _save),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      height: 72,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: YappGlyph.back(),
            ),
          ),
          const SizedBox(width: 10),
          Text('edit', style: Yapp.display().copyWith(fontSize: 24)),
        ],
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.profile,
    required this.repository,
    required this.onTap,
  });

  final MyProfile profile;
  final ProfileRepository repository;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ProfileAvatar(
              profile: profile,
              repository: repository,
              size: 88,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('photo', style: Yapp.display().copyWith(fontSize: 22)),
                const SizedBox(height: 6),
                Text(
                  'tap the square to replace or remove.',
                  style: Yapp.body(color: pal.gray2).copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          YappGlyph.forward(color: pal.gray3, size: 22),
        ],
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.prefix,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.inputFormatters,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? prefix;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String)? validator;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final FocusNode _focus;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()
      ..addListener(() => setState(() => _hasFocus = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: Yapp.label(color: pal.gray2).copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Yapp.bidi(
                  controller: widget.controller,
                  builder: (dir) => TextFormField(
                    controller: widget.controller,
                    focusNode: _focus,
                    maxLength: widget.maxLength,
                    minLines: widget.minLines,
                    maxLines: widget.maxLines,
                    inputFormatters: widget.inputFormatters,
                    cursorColor: pal.ink,
                    validator: widget.validator == null
                        ? null
                        : (v) => widget.validator!(v ?? ''),
                    style: Yapp.name(color: pal.ink).copyWith(fontSize: 16),
                    textAlign: TextAlign.start,
                    textDirection: dir,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: widget.hint?.toLowerCase(),
                      hintStyle: Yapp.name(
                        color: pal.gray3,
                      ).copyWith(fontSize: 16),
                      prefixText: widget.prefix,
                      prefixStyle: Yapp.name(
                        color: pal.gray2,
                      ).copyWith(fontSize: 16),
                      isDense: true,
                      contentPadding: const EdgeInsets.only(bottom: 6),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorStyle: Yapp.body(
                        color: pal.alert,
                      ).copyWith(fontSize: 11),
                    ),
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
          if (widget.helper != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.helper!,
              style: Yapp.body(color: pal.gray2).copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.enabled, required this.onSave});
  final bool enabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    if (!enabled) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pal.gray4,
          border: Border(
            top: BorderSide(color: pal.gray4, width: Yapp.hairline),
          ),
        ),
        child: Text(
          'no changes',
          style: Yapp.name(color: pal.gray3).copyWith(fontSize: 14),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: pal.gray4, width: Yapp.hairline),
        ),
      ),
      child: YappQuietRow(
        showDivider: false,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        onTap: onSave,
        child: SizedBox(
          height: 64,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'save',
                  style: Yapp.name(
                    color: pal.ink,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                YappGlyph.forward(color: pal.ink, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
