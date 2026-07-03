import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/family_member.dart';

/// Couche de persistance locale pour la configuration de l'utilisateur.
class PrefsService {
  static const _keyUserEmail = 'user_email';
  static const _keyUserDisplayName = 'user_display_name';
  static const _keyCalendarIds = 'selected_calendar_ids';
  static const _keyFamilyMembers = 'family_members';
  static const _keyGroupCode = 'group_code';

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyUserEmail);
    return email != null && email.isNotEmpty;
  }

  Future<void> saveOnboarding({
    required String userEmail,
    String? userDisplayName,
    required List<String> calendarIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserEmail, userEmail);
    if (userDisplayName != null) {
      await prefs.setString(_keyUserDisplayName, userDisplayName);
    }
    await prefs.setStringList(_keyCalendarIds, calendarIds);

    // Enregistre l'utilisateur courant comme premier membre de la famille.
    final existing = await getFamilyMembers();
    final me = FamilyMember(
      email: userEmail,
      name: userDisplayName ?? userEmail,
    );
    // Insère en tête s'il n'est pas déjà présent.
    if (!existing.contains(me)) {
      await saveFamilyMembers([me, ...existing]);
    }
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<String?> getUserDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserDisplayName);
  }

  Future<String?> getGroupCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGroupCode);
  }

  Future<void> saveGroupCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGroupCode, code);
  }

  Future<bool> isGroupSetupComplete() async {
    final code = await getGroupCode();
    return code != null && code.isNotEmpty;
  }

  Future<List<String>> getCalendarIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCalendarIds) ?? const [];
  }

  // ─── membres de la famille ───────────────────────────────────────────────────

  Future<List<FamilyMember>> getFamilyMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyFamilyMembers) ?? [];
    return raw.map((s) {
      try {
        return FamilyMember.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<FamilyMember>().toList();
  }

  Future<void> saveFamilyMembers(List<FamilyMember> members) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyFamilyMembers,
      members.map((m) => jsonEncode(m.toJson())).toList(),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserDisplayName);
    await prefs.remove(_keyCalendarIds);
    await prefs.remove(_keyFamilyMembers);
    await prefs.remove(_keyGroupCode);
  }
}
