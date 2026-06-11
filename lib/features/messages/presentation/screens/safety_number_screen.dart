import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/crypto/base64url.dart';
import '../../../../core/crypto/libsignal/libsignal_identity.dart';
import '../../../../core/crypto/libsignal/safety_number.dart';
import '../../../../core/storage/identity_vault.dart';

Future<void> openSafetyNumberScreen(
  BuildContext context, {
  required String selfAccountId,
  required String peerAccountId,
  required String peerName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final identity = await LibsignalIdentity.fromSeed(
      (await IdentityVault().loadOrThrow()).identitySeed,
    );
    final rows = await Supabase.instance.client
        .from('accounts')
        .select('libsignal_identity_key')
        .eq('id', peerAccountId)
        .limit(1);
    final peerKeyB64 = rows.isNotEmpty
        ? rows.first['libsignal_identity_key'] as String?
        : null;
    if (peerKeyB64 == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No safety number yet — peer is not on the new protocol.',
          ),
        ),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => SafetyNumberScreen(
          selfAccountId: selfAccountId,
          selfIdentityKey: identity.identityPublicKey(),
          peerAccountId: peerAccountId,
          peerIdentityKey: decodeBase64Url(peerKeyB64),
          peerName: peerName,
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not load safety number: $e')),
    );
  }
}

class SafetyNumberScreen extends StatefulWidget {
  const SafetyNumberScreen({
    super.key,
    required this.selfAccountId,
    required this.selfIdentityKey,
    required this.peerAccountId,
    required this.peerIdentityKey,
    required this.peerName,
  });

  final String selfAccountId;
  final Uint8List selfIdentityKey;
  final String peerAccountId;
  final Uint8List peerIdentityKey;
  final String peerName;

  @override
  State<SafetyNumberScreen> createState() => _SafetyNumberScreenState();
}

class _SafetyNumberScreenState extends State<SafetyNumberScreen> {
  String? _number;
  String? _error;
  bool _verified = false;
  bool _keyChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final number = await SafetyNumber.compute(
        selfAccountId: widget.selfAccountId,
        selfIdentityKey: widget.selfIdentityKey,
        peerAccountId: widget.peerAccountId,
        peerIdentityKey: widget.peerIdentityKey,
      );
      final verified = await SafetyNumber.isVerified(widget.peerAccountId);
      final keyChanged = await SafetyNumber.hasKeyChanged(widget.peerAccountId);
      if (!mounted) return;
      setState(() {
        _number = number;
        _verified = verified;
        _keyChanged = keyChanged;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _toggleVerified(bool value) async {
    await SafetyNumber.setVerified(widget.peerAccountId, value);
    if (value) await SafetyNumber.acknowledgeKeyChange(widget.peerAccountId);
    if (mounted) {
      setState(() {
        _verified = value;
        if (value) _keyChanged = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('safety number')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : _number == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_keyChanged)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      "⚠️  ${widget.peerName}'s safety number changed. This can "
                      "happen if they reinstalled the app — or it could mean someone "
                      "is intercepting your messages. Re-verify before trusting this chat.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Text(
                  'Compare this number with ${widget.peerName} in person or '
                  'over another trusted channel. If it matches, your chat is '
                  'verified end-to-end.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                SelectableText(
                  _number!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    letterSpacing: 1.5,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Mark as verified'),
                  value: _verified,
                  onChanged: _toggleVerified,
                ),
              ],
            ),
    );
  }
}
