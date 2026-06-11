import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/yapp_palette.dart';
import '../../../messages/presentation/yapp_design.dart';

Future<String?> showFieldEditorSheet(
  BuildContext context, {
  required String title,
  required String? initialValue,
  String? hint,
  String? helper,
  int maxLength = 80,
  int minLines = 1,
  int maxLines = 1,
  bool allowEmpty = true,
  String? prefix,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String value)? validator,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    elevation: 0,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _FieldEditorBody(
        title: title,
        initialValue: initialValue,
        hint: hint,
        helper: helper,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        allowEmpty: allowEmpty,
        prefix: prefix,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
      ),
    ),
  );
}

class _FieldEditorBody extends StatefulWidget {
  const _FieldEditorBody({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.helper,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
    required this.allowEmpty,
    required this.prefix,
    required this.keyboardType,
    required this.inputFormatters,
    required this.validator,
  });

  final String title;
  final String? initialValue;
  final String? hint;
  final String? helper;
  final int maxLength;
  final int minLines;
  final int maxLines;
  final bool allowEmpty;
  final String? prefix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String value)? validator;

  @override
  State<_FieldEditorBody> createState() => _FieldEditorBodyState();
}

class _FieldEditorBodyState extends State<_FieldEditorBody> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  String? _error;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _focus = FocusNode()
      ..addListener(() => setState(() => _hasFocus = _focus.hasFocus));
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty && !widget.allowEmpty) {
      setState(() => _error = 'this field is required');
      return;
    }
    if (widget.validator != null) {
      final err = widget.validator!(value);
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }
    Navigator.of(context).pop(value);
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
              widget.title.toLowerCase(),
              style: Yapp.display().copyWith(fontSize: 28),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.prefix != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.prefix!,
                            style: Yapp.name(
                              color: pal.gray2,
                            ).copyWith(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Yapp.bidi(
                          controller: _controller,
                          builder: (dir) => TextField(
                            controller: _controller,
                            focusNode: _focus,
                            maxLength: widget.maxLength,
                            minLines: widget.minLines,
                            maxLines: widget.maxLines,
                            keyboardType: widget.keyboardType,
                            inputFormatters: widget.inputFormatters,
                            cursorColor: pal.ink,
                            textInputAction: widget.maxLines == 1
                                ? TextInputAction.done
                                : TextInputAction.newline,
                            onSubmitted: (_) => _submit(),
                            style: Yapp.name(
                              color: pal.ink,
                            ).copyWith(fontSize: 18),
                            textAlign: TextAlign.start,
                            textDirection: dir,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              counterText: '',
                              contentPadding: const EdgeInsets.only(bottom: 6),
                              hintText: widget.hint?.toLowerCase(),
                              hintStyle: Yapp.name(
                                color: pal.gray3,
                              ).copyWith(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                    ],
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Text(
                _error!,
                style: Yapp.body(color: pal.alert).copyWith(fontSize: 12),
              ),
            )
          else if (widget.helper != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Text(
                widget.helper!,
                style: Yapp.body(color: pal.gray2).copyWith(fontSize: 12),
              ),
            )
          else
            const SizedBox(height: 18),
          _StampRow(
            label: 'save  →',
            fill: pal.ink,
            textColor: pal.paper,
            onTap: _submit,
          ),
          Container(height: Yapp.hairline, color: pal.ink),
          _StampRow(
            label: 'cancel',
            fill: pal.paper,
            textColor: pal.ink,
            onTap: () => Navigator.of(context).pop(),
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
