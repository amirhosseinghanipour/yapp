import 'package:flutter/material.dart';

import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/yapp_design.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _InfoScreen(
      headline: 'terms',
      sections: [
        _Section(
          title: 'the deal',
          body:
              'by using yapp you agree to these terms. they\'re short on '
              'purpose. if you don\'t agree, don\'t use yapp.',
        ),
        _Section(
          title: 'what yapp is',
          body:
              'a messaging service that end-to-end encrypts your conversations. '
              'we relay encrypted data between devices; we cannot read it. the '
              'service is provided as-is, without warranties of any kind.',
        ),
        _Section(
          title: 'your account, your keys',
          body:
              'your account is secured by keys and a recovery phrase that exist '
              'only on your device. you are responsible for keeping them safe. '
              'lose them and the account is unrecoverable — by design, we have '
              'no master key and no reset button.',
        ),
        _Section(
          title: 'what we store',
          body:
              'as little as possible: your handle, your encryption keys\' public '
              'parts, encrypted blobs we can\'t open, and undelivered encrypted '
              'messages until they reach you (then they\'re deleted). no phone '
              'number, no email, no contact graph, no message content.',
        ),
        _Section(
          title: 'be decent',
          body:
              'don\'t use yapp for spam, fraud, or to harm people. encryption '
              'protects your privacy — it\'s not a license for abuse. we may '
              'rate-limit or suspend accounts that attack the service itself.',
        ),
        _Section(
          title: 'blocking',
          body:
              'you can block anyone. blocked people can\'t message you, and you '
              'won\'t message them. blocks are enforced by the server without '
              'revealing them to the other side.',
        ),
        _Section(
          title: 'the service can change',
          body:
              'yapp evolves. features may be added, changed or removed, and '
              'these terms may be updated — the current version always lives '
              'right here in the app.',
        ),
        _Section(
          title: 'liability',
          body:
              'to the maximum extent permitted by law, yapp and its makers are '
              'not liable for indirect or consequential damages, lost data, or '
              'losses arising from your use of the service.',
        ),
      ],
    );
  }
}

class _Section {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;
}

class _InfoScreen extends StatelessWidget {
  const _InfoScreen({required this.headline, required this.sections});

  final String headline;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: YappGlyph.back(),
                  ),
                  Text(headline, style: Yapp.display().copyWith(fontSize: 28)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                itemCount: sections.length,
                itemBuilder: (context, i) {
                  final s = sections[i];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: pal.gray4,
                          width: Yapp.hairline,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: Yapp.name(
                            color: pal.ink,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.body,
                          style: Yapp.body(
                            color: pal.gray1,
                          ).copyWith(fontSize: 14, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
