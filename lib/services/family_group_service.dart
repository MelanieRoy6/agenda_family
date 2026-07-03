import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/busy_period.dart';
import '../models/family_member.dart';

/// Gère les groupes famille dans Firestore.
///
/// Structure Firestore :
///   /family_groups/{code}                      → métadonnées du groupe
///   /family_groups/{code}/members/{email}      → membres
///   /family_groups/{code}/availability/{email} → périodes occupées synchronisées
///
/// Prérequis : Firebase initialisé et Firestore activé dans la console Firebase.
class FamilyGroupService {
  static const _kGroupsCol = 'family_groups';
  static const _kMembersCol = 'members';
  static const _kAvailCol = 'availability';

  // Caractères sans ambiguïté visuelle (pas de 0/O, 1/I/L)
  static const _kChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String _generateCode() {
    final rng = Random.secure();
    return List.generate(6, (_) => _kChars[rng.nextInt(_kChars.length)]).join();
  }

  Future<bool> _groupExists(String code) async {
    final doc = await _db.collection(_kGroupsCol).doc(code).get();
    return doc.exists;
  }

  /// Crée un nouveau groupe et retourne le code généré (6 caractères).
  Future<String> createGroup({
    required String email,
    required String displayName,
  }) async {
    String code;
    var attempts = 0;
    do {
      if (attempts++ > 10) {
        throw const FamilyGroupException(
            'Impossible de générer un code unique. Réessayez.');
      }
      code = _generateCode();
    } while (await _groupExists(code));

    final groupRef = _db.collection(_kGroupsCol).doc(code);
    final memberRef =
        groupRef.collection(_kMembersCol).doc(email.toLowerCase());

    final batch = _db.batch();
    batch.set(groupRef, {
      'code': code,
      'createdBy': email.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(memberRef, {
      'email': email.toLowerCase(),
      'displayName': displayName,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    return code;
  }

  /// Rejoint un groupe existant via son [code].
  ///
  /// Lance [FamilyGroupException] si le code est invalide.
  Future<void> joinGroup({
    required String code,
    required String email,
    required String displayName,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (!await _groupExists(normalized)) {
      throw const FamilyGroupException(
          'Code invalide. Vérifiez le code et réessayez.');
    }

    await _db
        .collection(_kGroupsCol)
        .doc(normalized)
        .collection(_kMembersCol)
        .doc(email.toLowerCase())
        .set({
      'email': email.toLowerCase(),
      'displayName': displayName,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Retourne la liste des membres du groupe [code].
  Future<List<FamilyMember>> getGroupMembers(String code) async {
    final snapshot = await _db
        .collection(_kGroupsCol)
        .doc(code)
        .collection(_kMembersCol)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return FamilyMember(
        email: data['email'] as String? ?? doc.id,
        name: data['displayName'] as String? ?? doc.id,
      );
    }).toList();
  }

  /// Publie les périodes occupées de l'utilisateur pour la plage demandée.
  Future<void> syncBusyPeriods({
    required String code,
    required String email,
    required List<BusyPeriod> busyPeriods,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    await _db
        .collection(_kGroupsCol)
        .doc(code)
        .collection(_kAvailCol)
        .doc(email.toLowerCase())
        .set({
      'busyPeriods': busyPeriods.map((p) => p.toJson()).toList(),
      'rangeStart': rangeStart.toUtc().toIso8601String(),
      'rangeEnd': rangeEnd.toUtc().toIso8601String(),
      'lastSynced': FieldValue.serverTimestamp(),
    });
  }

  /// Retourne les périodes occupées de chaque membre dans [emails].
  ///
  /// La clé du Map retourné est l'email en minuscules.
  Future<Map<String, List<BusyPeriod>>> getMembersBusyPeriods({
    required String code,
    required List<String> emails,
  }) async {
    final result = <String, List<BusyPeriod>>{};

    for (final email in emails) {
      final key = email.toLowerCase();
      try {
        final doc = await _db
            .collection(_kGroupsCol)
            .doc(code)
            .collection(_kAvailCol)
            .doc(key)
            .get();

        if (doc.exists) {
          final rawList =
              (doc.data()!['busyPeriods'] as List<dynamic>?) ?? const [];
          result[key] = rawList
              .map((e) => BusyPeriod.fromJson(e as Map<String, dynamic>))
              .toList(growable: false);
        } else {
          result[key] = const [];
        }
      } catch (_) {
        result[key] = const [];
      }
    }

    return result;
  }
}

class FamilyGroupException implements Exception {
  final String message;

  const FamilyGroupException(this.message);

  @override
  String toString() => message;
}
