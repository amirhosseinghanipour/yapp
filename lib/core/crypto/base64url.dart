import 'dart:convert';
import 'dart:typed_data';

String encodeBase64Url(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

Uint8List decodeBase64Url(String input, {int? expectedLen}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed)) {
    throw FormatException('Invalid base64url');
  }
  final pad = (4 - trimmed.length % 4) % 4;
  final padded = '$trimmed${'=' * pad}';
  final out = base64Url.decode(padded);
  if (expectedLen != null && out.length != expectedLen) {
    throw FormatException('Expected $expectedLen bytes, got ${out.length}');
  }
  return Uint8List.fromList(out);
}
