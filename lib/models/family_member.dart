class FamilyMember {
  final String email;
  final String name;

  const FamilyMember({required this.email, required this.name});

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'email': email, 'name': name};

  /// Initiales pour l'avatar : "Jean Dupont" → "JD", "alice@gmail.com" → "A".
  String get initials {
    final atIndex = email.indexOf('@');
    final cleaned =
        name.trim().isNotEmpty ? name.trim() : email.substring(0, atIndex > 0 ? atIndex : email.length);
    final parts = cleaned.split(RegExp(r'[\s._\-]+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return cleaned.isNotEmpty ? cleaned[0].toUpperCase() : '?';
  }

  @override
  bool operator ==(Object other) =>
      other is FamilyMember && email.toLowerCase() == other.email.toLowerCase();

  @override
  int get hashCode => email.toLowerCase().hashCode;
}
