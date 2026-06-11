import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeRelay {
  RealtimeRelay({required SupabaseClient client, required String accountId})
    : _client = client,
      _accountId = accountId;

  final SupabaseClient _client;
  final String _accountId;

  RealtimeChannel? _channel;

  final _envelopeCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _typingCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _profileCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _sessionRevokedCtrl =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get envelopes => _envelopeCtrl.stream;

  Stream<Map<String, dynamic>> get typing => _typingCtrl.stream;

  Stream<Map<String, dynamic>> get presence => _presenceCtrl.stream;

  Stream<Map<String, dynamic>> get profile => _profileCtrl.stream;

  Stream<Map<String, dynamic>> get sessionRevoked => _sessionRevokedCtrl.stream;

  bool get isConnected => _channel != null;

  void connect() {
    if (_channel != null) return;
    final channel = _client.channel(
      'account:$_accountId',
      opts: const RealtimeChannelConfig(private: true),
    );
    channel
        .onBroadcast(
          event: 'envelope',
          callback: (payload) => _emit(_envelopeCtrl, payload),
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) => _emit(_typingCtrl, payload),
        )
        .onBroadcast(
          event: 'presence',
          callback: (payload) => _emit(_presenceCtrl, payload),
        )
        .onBroadcast(
          event: 'profile',
          callback: (payload) => _emit(_profileCtrl, payload),
        )
        .onBroadcast(
          event: 'sessionRevoked',
          callback: (payload) => _emit(_sessionRevokedCtrl, payload),
        )
        .subscribe();
    _channel = channel;
  }

  void _emit(
    StreamController<Map<String, dynamic>> ctrl,
    Map<String, dynamic> payload,
  ) {
    if (ctrl.isClosed) return;
    final inner = payload['payload'];
    ctrl.add(
      inner is Map<String, dynamic>
          ? inner
          : Map<String, dynamic>.from(payload),
    );
  }

  Future<void> disconnect() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _envelopeCtrl.close();
    await _typingCtrl.close();
    await _presenceCtrl.close();
    await _profileCtrl.close();
    await _sessionRevokedCtrl.close();
  }
}
