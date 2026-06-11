import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:url_launcher/url_launcher.dart';

import '../yapp_design.dart';

class RichTextMessage extends StatelessWidget {
  const RichTextMessage({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.onDark,
    this.onMentionTap,
  });

  final String text;
  final TextStyle baseStyle;
  final bool onDark;
  final void Function(String handle)? onMentionTap;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    if (blocks.isEmpty) {
      return Text('', style: baseStyle);
    }
    if (blocks.length == 1 && blocks.first is _Paragraph) {
      final p = blocks.first as _Paragraph;
      return Text.rich(
        _inlineSpan(
          p.text,
          baseStyle,
          onDark: onDark,
          onMentionTap: onMentionTap,
        ),
        style: baseStyle,
        textDirection: _dirOf(p.text),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _buildBlock(blocks[i]),
        ],
      ],
    );
  }

  Widget _buildBlock(_Block b) {
    switch (b) {
      case _Paragraph p:
        return Text.rich(
          _inlineSpan(
            p.text,
            baseStyle,
            onDark: onDark,
            onMentionTap: onMentionTap,
          ),
          style: baseStyle,
          textDirection: _dirOf(p.text),
        );
      case _Quote q:
        final color = onDark ? Colors.white : Yapp.ink;
        final bodyColor = (baseStyle.color ?? Yapp.ink).withValues(alpha: 0.92);
        final dir = _dirOf(q.text);
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 3)),
            color: color.withValues(alpha: onDark ? 0.08 : 0.05),
          ),
          child: Text.rich(
            _inlineSpan(
              q.text,
              baseStyle.copyWith(color: bodyColor),
              onDark: onDark,
              onMentionTap: onMentionTap,
            ),
            style: baseStyle.copyWith(color: bodyColor),
            textDirection: dir,
          ),
        );
      case _CodeBlock c:
        return _CodeBlockView(
          code: c.code,
          language: c.language,
          onDark: onDark,
        );
    }
  }
}

TextDirection? _dirOf(String text) {
  if (text.trim().isEmpty) return null;
  return Bidi.detectRtlDirectionality(text)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

sealed class _Block {
  const _Block();
}

class _Paragraph extends _Block {
  const _Paragraph(this.text);
  final String text;
}

class _Quote extends _Block {
  const _Quote(this.text);
  final String text;
}

class _CodeBlock extends _Block {
  const _CodeBlock({required this.code, this.language});
  final String code;
  final String? language;
}

List<_Block> _parseBlocks(String input) {
  final lines = input.split('\n');
  final blocks = <_Block>[];

  var i = 0;
  final paragraph = StringBuffer();
  final quote = StringBuffer();

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(_Paragraph(paragraph.toString()));
    paragraph.clear();
  }

  void flushQuote() {
    if (quote.isEmpty) return;
    blocks.add(_Quote(quote.toString()));
    quote.clear();
  }

  while (i < lines.length) {
    final line = lines[i];

    final fence = _codeFence(line);
    if (fence != null) {
      flushParagraph();
      flushQuote();
      final lang = fence.isEmpty ? null : fence;
      final body = StringBuffer();
      i++;
      while (i < lines.length && _codeFence(lines[i]) == null) {
        if (body.isNotEmpty) body.write('\n');
        body.write(lines[i]);
        i++;
      }
      if (i < lines.length) i++;
      blocks.add(_CodeBlock(code: body.toString(), language: lang));
      continue;
    }

    if (line.startsWith('> ')) {
      flushParagraph();
      if (quote.isNotEmpty) quote.write('\n');
      quote.write(line.substring(2));
      i++;
      continue;
    }
    if (line == '>') {
      flushParagraph();
      if (quote.isNotEmpty) quote.write('\n');
      i++;
      continue;
    }
    if (quote.isNotEmpty) flushQuote();

    if (paragraph.isNotEmpty) paragraph.write('\n');
    paragraph.write(line);
    i++;
  }

  flushParagraph();
  flushQuote();
  return blocks;
}

String? _codeFence(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('```')) return null;
  return trimmed.substring(3).trim();
}

TextSpan _inlineSpan(
  String source,
  TextStyle base, {
  required bool onDark,
  void Function(String handle)? onMentionTap,
}) {
  return TextSpan(
    style: base,
    children: _parseInline(
      source,
      base,
      onDark: onDark,
      onMentionTap: onMentionTap,
    ),
  );
}

List<InlineSpan> _parseInline(
  String source,
  TextStyle base, {
  required bool onDark,
  void Function(String handle)? onMentionTap,
}) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  while (cursor < source.length) {
    final next = _nextMarker(source, cursor);
    if (next == null) {
      spans.add(TextSpan(text: source.substring(cursor), style: base));
      break;
    }
    if (next.start > cursor) {
      _appendPlainWithLinks(
        spans,
        source.substring(cursor, next.start),
        base,
        onDark: onDark,
        onMentionTap: onMentionTap,
      );
    }
    final styled = _styledSpan(next, base, onDark: onDark);
    spans.add(styled);
    cursor = next.end;
  }
  return spans;
}

class _Marker {
  const _Marker({
    required this.start,
    required this.end,
    required this.inner,
    required this.kind,
  });

  final int start;
  final int end;
  final String inner;
  final _MarkerKind kind;
}

enum _MarkerKind { bold, italic, strike, code }

_Marker? _nextMarker(String source, int from) {
  for (var i = from; i < source.length; i++) {
    final c = source[i];

    if (c == '`') {
      final close = source.indexOf('`', i + 1);
      if (close == -1) continue;
      return _Marker(
        start: i,
        end: close + 1,
        inner: source.substring(i + 1, close),
        kind: _MarkerKind.code,
      );
    }

    if (c == '*' && i + 1 < source.length && source[i + 1] == '*') {
      final close = source.indexOf('**', i + 2);
      if (close == -1 || close == i + 2) continue;
      return _Marker(
        start: i,
        end: close + 2,
        inner: source.substring(i + 2, close),
        kind: _MarkerKind.bold,
      );
    }

    if (c == '~' && i + 1 < source.length && source[i + 1] == '~') {
      final close = source.indexOf('~~', i + 2);
      if (close == -1 || close == i + 2) continue;
      return _Marker(
        start: i,
        end: close + 2,
        inner: source.substring(i + 2, close),
        kind: _MarkerKind.strike,
      );
    }

    if ((c == '*' || c == '_') && _validItalicStart(source, i)) {
      final close = _findItalicClose(source, i + 1, c);
      if (close == -1) continue;
      return _Marker(
        start: i,
        end: close + 1,
        inner: source.substring(i + 1, close),
        kind: _MarkerKind.italic,
      );
    }
  }
  return null;
}

bool _validItalicStart(String source, int i) {
  if (i > 0) {
    final prev = source[i - 1];
    if (RegExp(r'[A-Za-z0-9_]').hasMatch(prev)) return false;
  }
  if (i + 1 >= source.length) return false;
  final next = source[i + 1];
  if (next == ' ' || next == '\n') return false;
  return true;
}

int _findItalicClose(String source, int from, String marker) {
  var i = from;
  while (i < source.length) {
    final idx = source.indexOf(marker, i);
    if (idx == -1) return -1;
    if (idx + 1 < source.length &&
        RegExp(r'[A-Za-z0-9_]').hasMatch(source[idx + 1])) {
      i = idx + 1;
      continue;
    }
    if (idx > 0 && source[idx - 1] == ' ') {
      i = idx + 1;
      continue;
    }
    return idx;
  }
  return -1;
}

InlineSpan _styledSpan(_Marker m, TextStyle base, {required bool onDark}) {
  final inner = m.inner;
  switch (m.kind) {
    case _MarkerKind.bold:
      return TextSpan(
        text: inner,
        style: base.copyWith(fontWeight: FontWeight.w800),
      );
    case _MarkerKind.italic:
      return TextSpan(
        text: inner,
        style: base.copyWith(fontStyle: FontStyle.italic),
      );
    case _MarkerKind.strike:
      return TextSpan(
        text: inner,
        style: base.copyWith(decoration: TextDecoration.lineThrough),
      );
    case _MarkerKind.code:
      final bg = onDark
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.black.withValues(alpha: 0.06);
      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: bg),
          child: Text(
            inner,
            style: GoogleFonts.firaCode(
              textStyle: base.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ),
      );
  }
}

final RegExp _urlRegex = RegExp(
  r'(https?:\/\/[^\s]+)|(www\.[^\s]+)',
  caseSensitive: false,
);
final RegExp _mentionRegex = RegExp(r'@[A-Za-z0-9_]{2,}');

void _appendPlainWithLinks(
  List<InlineSpan> out,
  String source,
  TextStyle base, {
  required bool onDark,
  void Function(String handle)? onMentionTap,
}) {
  final linkColor = onDark ? Colors.white : Yapp.ink;
  final linkStyle = base.copyWith(
    color: linkColor,
    decoration: TextDecoration.underline,
    decorationColor: linkColor,
  );

  final matches = <_Hit>[];
  for (final m in _urlRegex.allMatches(source)) {
    matches.add(_Hit(m.start, m.end, source.substring(m.start, m.end), true));
  }
  for (final m in _mentionRegex.allMatches(source)) {
    matches.add(_Hit(m.start, m.end, source.substring(m.start, m.end), false));
  }
  matches.sort((a, b) => a.start.compareTo(b.start));

  var cur = 0;
  for (final h in matches) {
    if (h.start < cur) continue;
    if (h.start > cur) {
      out.add(TextSpan(text: source.substring(cur, h.start), style: base));
    }
    if (h.isUrl) {
      out.add(
        TextSpan(
          text: h.text,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _openUrl(h.text),
        ),
      );
    } else {
      out.add(
        TextSpan(
          text: h.text,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => onMentionTap?.call(h.text),
        ),
      );
    }
    cur = h.end;
  }
  if (cur < source.length) {
    out.add(TextSpan(text: source.substring(cur), style: base));
  }
}

class _Hit {
  const _Hit(this.start, this.end, this.text, this.isUrl);
  final int start;
  final int end;
  final String text;
  final bool isUrl;
}

Future<void> _openUrl(String raw) async {
  final url = raw.startsWith('http') ? raw : 'https://$raw';
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _CodeBlockView extends StatelessWidget {
  const _CodeBlockView({
    required this.code,
    required this.onDark,
    this.language,
  });

  final String code;
  final String? language;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final bg = onDark ? Yapp.paper : Yapp.ink;
    final fg = onDark ? Yapp.ink : Yapp.paper;
    final secondary = fg.withValues(alpha: 0.6);
    final codeBase = GoogleFonts.firaCode(
      textStyle: TextStyle(color: fg, fontSize: 13, height: 1.4),
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: onDark
            ? Border.all(color: Yapp.ink, width: Yapp.hairline)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 2),
            child: Row(
              children: [
                Text(
                  (language == null || language!.isEmpty) ? 'code' : language!,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            'code copied',
                            style: Yapp.body(color: Yapp.paper),
                          ),
                          backgroundColor: Yapp.ink,
                          behavior: SnackBarBehavior.floating,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      );
                  },
                  borderRadius: BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 14, color: secondary),
                        const SizedBox(width: 4),
                        Text(
                          'copy',
                          style: TextStyle(
                            color: secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text.rich(
                TextSpan(
                  children: _highlightCode(code, language, codeBase, fg),
                ),
                style: codeBase,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Set<String> _codeKeywords = <String>{
  'abstract',
  'as',
  'async',
  'await',
  'base',
  'bool',
  'break',
  'case',
  'catch',
  'char',
  'class',
  'const',
  'continue',
  'def',
  'default',
  'deferred',
  'do',
  'double',
  'dynamic',
  'elif',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'final',
  'finally',
  'float',
  'fn',
  'for',
  'from',
  'fun',
  'func',
  'function',
  'get',
  'go',
  'if',
  'impl',
  'implements',
  'import',
  'in',
  'int',
  'interface',
  'is',
  'late',
  'let',
  'long',
  'match',
  'mixin',
  'module',
  'mut',
  'namespace',
  'new',
  'operator',
  'override',
  'package',
  'part',
  'private',
  'protected',
  'pub',
  'public',
  'required',
  'return',
  'sealed',
  'set',
  'short',
  'static',
  'struct',
  'super',
  'switch',
  'sync',
  'then',
  'this',
  'throw',
  'trait',
  'try',
  'type',
  'typedef',
  'union',
  'use',
  'val',
  'var',
  'void',
  'when',
  'where',
  'while',
  'with',
  'yield',
};

const Set<String> _codeLiterals = <String>{
  'true',
  'false',
  'null',
  'nil',
  'none',
  'undefined',
  'True',
  'False',
  'None',
};

const Set<String> _hashCommentLangs = <String>{
  'python',
  'py',
  'rb',
  'ruby',
  'sh',
  'bash',
  'zsh',
  'shell',
  'yaml',
  'yml',
  'toml',
  'ini',
  'r',
  'perl',
  'pl',
  'dockerfile',
  'makefile',
  'make',
  'conf',
  'cfg',
  'properties',
  'gitignore',
  'env',
};

final RegExp _digit = RegExp(r'[0-9]');
final RegExp _numCont = RegExp(r'[0-9a-fA-FxXoObB._]');
final RegExp _wordStart = RegExp(r'[A-Za-z_$]');
final RegExp _wordCont = RegExp(r'[A-Za-z0-9_$]');

List<TextSpan> _highlightCode(
  String code,
  String? lang,
  TextStyle base,
  Color fg,
) {
  final language = (lang ?? '').toLowerCase();
  final hash = _hashCommentLangs.contains(language);

  final normal = base.copyWith(color: fg);
  final keyword = base.copyWith(color: fg, fontWeight: FontWeight.w700);
  final comment = base.copyWith(
    color: fg.withValues(alpha: 0.42),
    fontStyle: FontStyle.italic,
  );
  final literal = base.copyWith(color: Yapp.alert, fontWeight: FontWeight.w600);

  final spans = <TextSpan>[];
  final buf = StringBuffer();
  void flushPlain() {
    if (buf.isNotEmpty) {
      spans.add(TextSpan(text: buf.toString(), style: normal));
      buf.clear();
    }
  }

  final n = code.length;
  var i = 0;
  while (i < n) {
    final c = code[i];

    if ((c == '/' && i + 1 < n && code[i + 1] == '/') || (c == '#' && hash)) {
      flushPlain();
      final nl = code.indexOf('\n', i);
      final stop = nl == -1 ? n : nl;
      spans.add(TextSpan(text: code.substring(i, stop), style: comment));
      i = stop;
      continue;
    }

    if (c == '/' && i + 1 < n && code[i + 1] == '*') {
      flushPlain();
      final end = code.indexOf('*/', i + 2);
      final stop = end == -1 ? n : end + 2;
      spans.add(TextSpan(text: code.substring(i, stop), style: comment));
      i = stop;
      continue;
    }

    if (c == '"' || c == "'" || c == '`') {
      flushPlain();
      var j = i + 1;
      while (j < n) {
        final cj = code[j];
        if (cj == '\\') {
          j += 2;
          continue;
        }
        if (cj == c) {
          j++;
          break;
        }
        if (cj == '\n' && c != '`') break;
        j++;
      }
      final stop = j > n ? n : j;
      spans.add(TextSpan(text: code.substring(i, stop), style: literal));
      i = stop;
      continue;
    }

    if (_digit.hasMatch(c)) {
      flushPlain();
      var j = i + 1;
      while (j < n && _numCont.hasMatch(code[j])) {
        j++;
      }
      spans.add(TextSpan(text: code.substring(i, j), style: literal));
      i = j;
      continue;
    }

    if (_wordStart.hasMatch(c)) {
      var j = i + 1;
      while (j < n && _wordCont.hasMatch(code[j])) {
        j++;
      }
      final word = code.substring(i, j);
      if (_codeKeywords.contains(word)) {
        flushPlain();
        spans.add(TextSpan(text: word, style: keyword));
      } else if (_codeLiterals.contains(word)) {
        flushPlain();
        spans.add(TextSpan(text: word, style: literal));
      } else {
        buf.write(word);
      }
      i = j;
      continue;
    }

    buf.write(c);
    i++;
  }
  flushPlain();
  return spans;
}
