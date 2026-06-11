import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/app_scope.dart';
import '../../../core/graphql/token_storage.dart';
import '../../../core/theme/yapp_palette.dart';
import '../../auth/presentation/link_device_qr_screen.dart';
import '../../messages/presentation/yapp_design.dart';
import 'widgets/yapp_confirm_sheet.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  List<Map<String, dynamic>> _devices = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final currentDeviceId = await TokenStorage().readDeviceId();
    try {
      final rows = await Supabase.instance.client
          .from('devices')
          .select('id, name, platform, last_used_at, revoked_at')
          .filter('revoked_at', 'is', null)
          .order('created_at');
      if (!mounted) return;
      final list = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(
            (d) => <String, dynamic>{
              'id': d['id'],
              'name': d['name'],
              'platform': d['platform'],
              'lastUsedAt': d['last_used_at'],
              'isCurrent': d['id'] == currentDeviceId,
            },
          )
          .toList();
      list.sort((a, b) {
        if (a['isCurrent'] == true) return -1;
        if (b['isCurrent'] == true) return 1;
        return 0;
      });
      setState(() {
        _devices = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _revoke(Map<String, dynamic> device) async {
    final name = (device['name'] as String? ?? 'device').toLowerCase();
    final ok = await showYappConfirmSheet(
      context,
      headline: 'remove $name?',
      body:
          'this device will be signed out immediately and will need the '
          'recovery phrase to sign back in.',
      primaryLabel: 'remove',
      destructive: true,
    );
    if (ok != true) return;
    await Supabase.instance.client.rpc<void>(
      'revoke_device',
      params: <String, dynamic>{'p_device': device['id']},
    );
    await _load();
  }

  void _openLinkQr() {
    final auth = AppScope.authOf(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LinkDeviceQrScreen(repository: auth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final count = _devices.length;
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
                    'linked\ndevices',
                    style: Yapp.display().copyWith(fontSize: 48, height: 0.98),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'every phone signed in to this account. remove any you '
                    'don\'t recognise.',
                    style: Yapp.body(color: pal.gray2).copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  _LinkStamp(onTap: _openLinkQr),
                  const SizedBox(height: 32),
                  if (_error != null)
                    Text(_error!, style: Yapp.body(color: pal.alert))
                  else if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: pal.ink,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Text(
                          'active',
                          style: Yapp.label(
                            color: pal.gray2,
                          ).copyWith(letterSpacing: 2, fontSize: 10),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: Yapp.hairline,
                            color: pal.gray4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$count',
                          style: Yapp.label(
                            color: pal.gray2,
                          ).copyWith(letterSpacing: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DeviceList(devices: _devices, onRemove: _revoke),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkStamp extends StatefulWidget {
  const _LinkStamp({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_LinkStamp> createState() => _LinkStampState();
}

class _LinkStampState extends State<_LinkStamp> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    final bg = _pressed ? pal.alert : pal.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: Yapp.dur,
        curve: Yapp.curve,
        height: 60,
        color: bg,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('link a device', style: Yapp.cta(color: pal.paper)),
              Text('qr →', style: Yapp.cta(color: pal.paper)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.devices, required this.onRemove});

  final List<Map<String, dynamic>> devices;
  final void Function(Map<String, dynamic>) onRemove;

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    if (devices.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: pal.gray4, width: Yapp.hairline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
        alignment: Alignment.center,
        child: Text('no other devices.', style: Yapp.body(color: pal.gray2)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: pal.ink, width: Yapp.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < devices.length; i++) ...[
            if (i > 0)
              SizedBox(
                height: Yapp.hairline,
                child: ColoredBox(color: pal.gray4),
              ),
            _DeviceRow(
              device: devices[i],
              onRemove: () => onRemove(devices[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceRow extends StatefulWidget {
  const _DeviceRow({required this.device, required this.onRemove});

  final Map<String, dynamic> device;
  final VoidCallback onRemove;

  @override
  State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _removePressed = false;

  String get _name =>
      (widget.device['name'] as String? ?? 'device').toLowerCase();

  bool get _isCurrent => widget.device['isCurrent'] == true;

  String _meta() {
    final platform = (widget.device['platform'] as String? ?? 'unknown')
        .toLowerCase();
    if (_isCurrent) return '$platform · active now';
    final raw = widget.device['lastUsedAt'];
    if (raw is String) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        final d = dt.toLocal();
        final mm = d.month.toString().padLeft(2, '0');
        final dd = d.day.toString().padLeft(2, '0');
        return '$platform · last seen ${d.year}-$mm-$dd';
      }
    }
    return '$platform · last seen unknown';
  }

  @override
  Widget build(BuildContext context) {
    final pal = YappPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Yapp.name(
                    color: pal.ink,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _meta(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Yapp.label(color: pal.gray2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: pal.ink,
              child: Text(
                'current',
                style: Yapp.label(
                  color: pal.paper,
                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _removePressed = true),
              onTapCancel: () => setState(() => _removePressed = false),
              onTapUp: (_) => setState(() => _removePressed = false),
              onTap: widget.onRemove,
              child: AnimatedContainer(
                duration: Yapp.dur,
                curve: Yapp.curve,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _removePressed ? pal.alert : pal.paper,
                  border: Border.all(color: pal.alert, width: Yapp.hairline),
                ),
                child: Text(
                  'remove',
                  style: Yapp.label(
                    color: _removePressed ? pal.paper : pal.alert,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
