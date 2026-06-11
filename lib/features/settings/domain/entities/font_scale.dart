enum FontScale {
  small(0.9, 'Small'),
  medium(1.0, 'Medium'),
  large(1.15, 'Large'),
  xlarge(1.3, 'Huge');

  const FontScale(this.multiplier, this.label);

  final double multiplier;
  final String label;

  String get storageValue => name;

  static FontScale fromStorage(String? raw) {
    for (final v in FontScale.values) {
      if (v.name == raw) return v;
    }
    return FontScale.medium;
  }
}
