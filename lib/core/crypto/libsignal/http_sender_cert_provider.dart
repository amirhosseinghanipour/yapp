import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'libsignal_engine.dart';

class HttpSenderCertProvider implements SenderCertProvider {
  HttpSenderCertProvider({
    required this.issuerUrl,
    required Uint8List trustRoot,
    required this.accessTokenProvider,
    http.Client? httpClient,
  }) : _trustRoot = trustRoot,
       _http = httpClient ?? http.Client();

  final String issuerUrl;
  final Uint8List _trustRoot;
  final Future<String?> Function() accessTokenProvider;
  final http.Client _http;

  Uint8List? _cert;
  DateTime _expiresAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Uint8List get trustRoot => _trustRoot;

  @override
  Future<Uint8List> senderCertificate() async {
    if (_cert != null &&
        DateTime.now().isBefore(
          _expiresAt.subtract(const Duration(hours: 1)),
        )) {
      return _cert!;
    }
    final token = await accessTokenProvider();
    if (token == null) throw StateError('no access token for cert issuer');
    final res = await _http.post(
      Uri.parse('$issuerUrl/sender-certificate'),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (res.statusCode != 200) {
      throw StateError('cert issuer error ${res.statusCode}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    _cert = base64.decode(j['certificate'] as String);
    _expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (j['expiresAt'] as num).toInt(),
    );
    return _cert!;
  }
}
