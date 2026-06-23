import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Gère les notifications push FCM pour tous les membres de la famille.
///
/// Prérequis :
///   • Android : ajouter google-services.json dans android/app/
///   • iOS     : ajouter GoogleService-Info.plist dans ios/Runner/
///   • Déployer la Cloud Function notifyFamilyEvent (voir functions/index.js)
class NotificationService {
  static const _familyTopic = 'family_agenda';

  static bool _initialized = false;

  /// Initialise les permissions et abonne l'appareil au topic famille.
  ///
  /// À appeler une fois après la connexion de l'utilisateur.
  /// Échoue silencieusement si Firebase n'est pas configuré.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Tous les appareils de la famille s'abonnent au même topic.
      await messaging.subscribeToTopic(_familyTopic);

      _initialized = true;
    } catch (_) {
      // Firebase non configuré — notifications désactivées.
    }
  }

  /// Envoie une notification à tous les membres via la Cloud Function.
  ///
  /// [eventTitle]   : titre de l'événement créé.
  /// [creatorName]  : nom ou email du créateur.
  /// [start]        : heure de début de l'événement.
  ///
  /// Retourne `true` si l'envoi a réussi.
  static Future<bool> notifyFamilyNewEvent({
    required String eventTitle,
    required String creatorName,
    required DateTime start,
  }) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('notifyFamilyEvent');

      await callable.call<void>({
        'title': 'Nouvel événement : $eventTitle',
        'body': '$creatorName a ajouté un créneau le ${_formatDate(start)}',
        'startTime': start.toIso8601String(),
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  static String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')} '
        'à ${d.hour.toString().padLeft(2, '0')}h'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
