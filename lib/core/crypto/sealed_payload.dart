import 'dart:convert';

class SealedMessagePayload {
  SealedMessagePayload({
    required this.messageId,
    required this.senderAccountId,
    required this.senderDeviceId,
    required this.body,
  });

  final String messageId;
  final String senderAccountId;
  final String senderDeviceId;
  final Map<String, dynamic> body;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': 3,
    'id': messageId,
    'sid': senderAccountId,
    'sdid': senderDeviceId,
    ...body,
  };

  static SealedMessagePayload fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final sid = json['sid'] as String?;
    final sdid = json['sdid'] as String?;
    if (sid == null || sid.isEmpty) {
      throw const FormatException('sealed payload missing sid');
    }
    final body = Map<String, dynamic>.from(json)
      ..remove('v')
      ..remove('id')
      ..remove('sid')
      ..remove('sdid');
    return SealedMessagePayload(
      messageId: id,
      senderAccountId: sid,
      senderDeviceId: sdid ?? '',
      body: body,
    );
  }

  static SealedMessagePayload? tryParseUtf8(List<int> bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if ((json['v'] as int? ?? 0) < 3) return null;
      return SealedMessagePayload.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
