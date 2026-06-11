library;

const int _matchDigits = 10;

String normalizeToDigits(String input) {
  final sb = StringBuffer();
  for (final c in input.codeUnits) {
    if (c >= 0x30 && c <= 0x39) {
      sb.writeCharCode(c);
    }
  }
  return sb.toString();
}

String phoneKey(String input) {
  final digits = normalizeToDigits(input);
  if (digits.isEmpty) return '';
  if (digits.length <= _matchDigits) return digits;
  return digits.substring(digits.length - _matchDigits);
}
