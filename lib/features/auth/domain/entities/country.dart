class Country {
  const Country({
    required this.iso2,
    required this.dialCode,
    required this.name,
    required this.flag,
  });

  final String iso2;
  final String dialCode;
  final String name;
  final String flag;

  String get displayDialCode => '+$dialCode';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Country && other.iso2 == iso2 && other.dialCode == dialCode);

  @override
  int get hashCode => Object.hash(iso2, dialCode);
}
