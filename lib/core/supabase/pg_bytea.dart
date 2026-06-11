import 'dart:convert';
import 'dart:typed_data';

Uint8List decodePgBase64(String value) =>
    base64.decode(base64.normalize(value.replaceAll(RegExp(r'\s'), '')));

String bytesToPgHex(List<int> bytes) {
  final sb = StringBuffer(r'\x');
  for (final b in bytes) {
    sb.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

Uint8List pgHexToBytes(String value) {
  final hex = value.startsWith(r'\x') ? value.substring(2) : value;
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
