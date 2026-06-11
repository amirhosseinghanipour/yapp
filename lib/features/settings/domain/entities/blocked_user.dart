class BlockedUser {
  const BlockedUser({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, String> toJson() => {'id': id, 'name': name};

  factory BlockedUser.fromJson(Map<String, Object?> json) =>
      BlockedUser(id: json['id']! as String, name: json['name']! as String);
}
