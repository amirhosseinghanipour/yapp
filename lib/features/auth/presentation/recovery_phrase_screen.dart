import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/yapp_design.dart';

class RecoveryPhraseScreen extends StatefulWidget {
  const RecoveryPhraseScreen({
    super.key,
    required this.mnemonic,
    required this.onConfirmed,
  });

  final String mnemonic;

  final VoidCallback onConfirmed;

  @override
  State<RecoveryPhraseScreen> createState() => _RecoveryPhraseScreenState();
}

enum _Phase { reveal, verify }

class _RecoveryPhraseScreenState extends State<RecoveryPhraseScreen> {
  late final List<String> _words = widget.mnemonic
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  _Phase _phase = _Phase.reveal;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Scaffold(
      backgroundColor: pal.paper,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_phase == _Phase.verify) {
            setState(() => _phase = _Phase.reveal);
          }
        },
        child: SafeArea(
          child: _phase == _Phase.reveal
              ? _RevealView(
                  words: _words,
                  onContinue: () => setState(() => _phase = _Phase.verify),
                )
              : _VerifyView(
                  words: _words,
                  onBack: () => setState(() => _phase = _Phase.reveal),
                  onConfirmed: widget.onConfirmed,
                ),
        ),
      ),
    );
  }
}

class _RevealView extends StatelessWidget {
  const _RevealView({required this.words, required this.onContinue});

  final List<String> words;
  final VoidCallback onContinue;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: words.join(' ')));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Yapp.ink,
          content: const Text(
            'copied — clear your clipboard once it is stored safely',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'recovery phrase',
                  style: Yapp.display(color: pal.ink).copyWith(fontSize: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'these ${words.length} words are the only way to restore your '
                  'account. there is no email, no phone, no password to fall '
                  'back on.',
                  style: Yapp.body(color: pal.gray2),
                ),
                const SizedBox(height: 20),
                _SecurityNote(pal: pal),
                const SizedBox(height: 24),
                _WordGrid(words: words, pal: pal),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _copy(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pal.ink,
                    side: BorderSide(color: pal.ink, width: Yapp.hairline),
                    shape: const RoundedRectangleBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('copy'),
                ),
                const SizedBox(height: 8),
                Text(
                  'copying puts the phrase on your clipboard where other apps '
                  'can read it — only do this to move it into a password '
                  'manager, then clear the clipboard.',
                  style: Yapp.meta(color: pal.gray2),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: pal.ink,
              foregroundColor: pal.paper,
              shape: const RoundedRectangleBorder(),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text("i've saved it"),
          ),
        ),
      ],
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.pal});

  final YappPalette pal;

  @override
  Widget build(BuildContext context) {
    const lines = [
      'anyone who has these words controls your account.',
      'never share them and never take a screenshot.',
      'write them down and store them offline.',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.paper,
        border: Border.all(color: pal.alert, width: Yapp.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i != 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('!', style: Yapp.body(color: pal.alert)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(lines[i], style: Yapp.body(color: pal.ink)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WordGrid extends StatelessWidget {
  const _WordGrid({required this.words, required this.pal});

  final List<String> words;
  final YappPalette pal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: pal.ink, width: Yapp.hairline),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: words.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 44,
        ),
        itemBuilder: (context, i) {
          final rightEdge = i.isOdd;
          final lastRow = i >= words.length - (words.length.isEven ? 2 : 1);
          return Container(
            decoration: BoxDecoration(
              border: Border(
                right: rightEdge
                    ? BorderSide.none
                    : BorderSide(color: pal.gray4, width: Yapp.hairline),
                bottom: lastRow
                    ? BorderSide.none
                    : BorderSide(color: pal.gray4, width: Yapp.hairline),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text('${i + 1}', style: Yapp.meta(color: pal.gray2)),
                ),
                Expanded(
                  child: SelectableText(
                    words[i],
                    style: Yapp.body(color: pal.ink).copyWith(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VerifyView extends StatefulWidget {
  const _VerifyView({
    required this.words,
    required this.onBack,
    required this.onConfirmed,
  });

  final List<String> words;
  final VoidCallback onBack;
  final VoidCallback onConfirmed;

  @override
  State<_VerifyView> createState() => _VerifyViewState();
}

class _VerifyViewState extends State<_VerifyView> {
  late List<int> _targets;

  int _step = 0;

  late List<String> _options;

  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _pickTargets();
    _buildOptions();
  }

  void _pickTargets() {
    final rng = Random.secure();
    final n = widget.words.length;
    final count = min(3, n);
    final chosen = <int>{};
    while (chosen.length < count) {
      chosen.add(rng.nextInt(n));
    }
    _targets = chosen.toList()..sort();
  }

  void _buildOptions() {
    final rng = Random.secure();
    final correctIdx = _targets[_step];
    final correct = widget.words[correctIdx];
    final opts = <String>{correct};
    final pool = widget.words.toList()..shuffle(rng);
    for (final w in pool) {
      if (opts.length >= 4) break;
      opts.add(w);
    }
    _options = opts.toList()..shuffle(rng);
    _wrong = false;
  }

  void _choose(String word) {
    final correct = widget.words[_targets[_step]];
    if (word != correct) {
      setState(() => _wrong = true);
      return;
    }
    if (_step >= _targets.length - 1) {
      widget.onConfirmed();
      return;
    }
    setState(() {
      _step++;
      _buildOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final position = _targets[_step] + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onBack,
              style: TextButton.styleFrom(foregroundColor: pal.ink),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, color: pal.gray2, size: 16),
                  const SizedBox(width: 6),
                  Text('back to phrase', style: Yapp.label(color: pal.gray2)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'confirm your phrase',
                  style: Yapp.display(color: pal.ink).copyWith(fontSize: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'step ${_step + 1} of ${_targets.length}. this proves the '
                  'phrase is safely stored before you continue.',
                  style: Yapp.body(color: pal.gray2),
                ),
                const SizedBox(height: 28),
                Text(
                  'which word is #$position?',
                  style: Yapp.name(color: pal.ink).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 16),
                for (final word in _options) ...[
                  _OptionButton(
                    word: word,
                    pal: pal,
                    onTap: () => _choose(word),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_wrong) ...[
                  const SizedBox(height: 6),
                  Text(
                    "that's not word #$position. check the phrase again.",
                    style: Yapp.body(color: pal.alert),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.word,
    required this.pal,
    required this.onTap,
  });

  final String word;
  final YappPalette pal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: pal.ink,
        side: BorderSide(color: pal.ink, width: Yapp.hairline),
        shape: const RoundedRectangleBorder(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.centerLeft,
      ),
      child: Text(
        word,
        style: Yapp.body(color: pal.ink).copyWith(
          fontFamily: 'monospace',
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
