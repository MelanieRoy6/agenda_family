import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:http/http.dart' as http;

import '../dev_config.dart';

class GoogleAuthService {
  // calendar.events : lecture + création + suppression d'événements
  static const _calendarEventsScope =
      'https://www.googleapis.com/auth/calendar.events';

  // calendar.readonly : nécessaire pour calendarList.list (onboarding)
  static const _calendarReadonlyScope =
      'https://www.googleapis.com/auth/calendar.readonly';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [_calendarEventsScope, _calendarReadonlyScope],
  );

  /// Email de l'utilisateur actuellement connecté, ou null si déconnecté.
  String? get currentUserEmail =>
      kDevMode ? kMockUserEmail : _googleSignIn.currentUser?.email;

  /// Nom complet Google de l'utilisateur connecté, ou null si déconnecté.
  String? get currentUserDisplayName =>
      kDevMode ? kMockUserName : _googleSignIn.currentUser?.displayName;

  /// Déclenche le flux de connexion Google.
  /// Lance [GoogleAuthCancelledException] si l'utilisateur ferme la fenêtre.
  Future<GoogleSignInAccount> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) throw const GoogleAuthCancelledException();
      return account;
    } on GoogleAuthCancelledException {
      rethrow;
    } catch (e) {
      throw GoogleAuthException('Échec de la connexion : $e');
    }
  }

  /// Déconnecte l'utilisateur et révoque la session locale.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Retourne un [CalendarApi] prêt à l'emploi.
  ///
  /// Tente d'abord une reconnexion silencieuse, puis déclenche le flux
  /// interactif si nécessaire. Lance [GoogleAuthCancelledException] si
  /// l'utilisateur annule.
  Future<CalendarApi> authenticatedClient() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await signIn();

    final headers = await account.authHeaders;
    return CalendarApi(_AuthenticatedHttpClient(headers));
  }
}

/// Client HTTP qui injecte les en-têtes d'autorisation Google sur chaque requête.
class _AuthenticatedHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthenticatedHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class GoogleAuthCancelledException implements Exception {
  const GoogleAuthCancelledException();

  @override
  String toString() => 'Connexion annulée par l\'utilisateur.';
}

class GoogleAuthException implements Exception {
  final String message;

  const GoogleAuthException(this.message);

  @override
  String toString() => 'GoogleAuthException : $message';
}
