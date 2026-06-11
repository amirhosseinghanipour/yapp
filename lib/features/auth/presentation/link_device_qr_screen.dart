import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/yapp_palette.dart';
import '../../messages/presentation/yapp_design.dart';
import '../domain/repositories/auth_repository.dart';

class LinkDeviceQrScreen extends StatefulWidget {
  const LinkDeviceQrScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<LinkDeviceQrScreen> createState() => _LinkDeviceQrScreenState();
}

class _LinkDeviceQrScreenState extends State<LinkDeviceQrScreen> {
  String? _payload;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final payload = await widget.repository.buildLinkDeviceQr(
        httpUrl: kSupabaseUrl,
        wsUrl: kSupabaseUrl,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Scaffold(
      backgroundColor: pal.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.zero,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: YappGlyph.back()),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Text(
                    'link a\ndevice',
                    style: Yapp.display().copyWith(fontSize: 48, height: 0.98),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'add this account to another phone. the link is end-to-end '
                    'encrypted — nobody in between can read it.',
                    style: Yapp.body(color: pal.gray2).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 28),
                  _QrPanel(payload: _payload, busy: _busy, error: _error),
                  const SizedBox(height: 28),
                  _StepsBlock(),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: pal.ink, width: Yapp.hairline),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 52,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'expires in a few minutes',
                        style: Yapp.label(
                          color: pal.gray2,
                        ).copyWith(letterSpacing: 1),
                      ),
                      Text(
                        'keep private',
                        style: Yapp.label(color: pal.alert).copyWith(
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({
    required this.payload,
    required this.busy,
    required this.error,
  });

  final String? payload;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);

    final Widget inner;
    if (busy) {
      inner = SizedBox(
        width: 240,
        height: 240,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: pal.ink),
          ),
        ),
      );
    } else if (error != null) {
      inner = SizedBox(
        width: 240,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'couldn\'t build the link.',
                style: Yapp.name(color: pal.alert),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                error!,
                style: Yapp.body(color: pal.gray2).copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    } else {
      inner = QrImageView(
        data: payload!,
        version: QrVersions.auto,
        size: 240,
        gapless: true,
        backgroundColor: const Color(0xFFFFFFFF),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF0A0A0A),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF0A0A0A),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'scan me',
              style: Yapp.label(
                color: pal.gray2,
              ).copyWith(letterSpacing: 2, fontSize: 10),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(height: Yapp.hairline, color: pal.gray4),
            ),
            const SizedBox(width: 8),
            YappGlyph.down(color: pal.ink, size: 16),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              border: Border.all(color: pal.ink, width: 2),
            ),
            padding: const EdgeInsets.all(20),
            child: inner,
          ),
        ),
      ],
    );
  }
}

class _StepsBlock extends StatelessWidget {
  static const _steps = [
    'open yapp on your other phone',
    'go to add account, then scan qr',
    'point its camera at this code',
  ];

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: pal.ink, width: Yapp.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            if (i > 0)
              SizedBox(
                height: Yapp.hairline,
                child: ColoredBox(color: pal.gray4),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '0${i + 1}',
                    style: Yapp.display(
                      color: pal.ink,
                    ).copyWith(fontSize: 22, height: 1),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: Yapp.name(
                        color: pal.ink,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
