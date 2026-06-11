enum LastSeenVisibility {
  everyone('everyone', 'Everyone'),
  contacts('contacts', 'My contacts'),
  nobody('nobody', 'Nobody');

  const LastSeenVisibility(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static LastSeenVisibility fromStorage(String? value) {
    for (final v in LastSeenVisibility.values) {
      if (v.storageValue == value) return v;
    }
    return LastSeenVisibility.everyone;
  }
}
