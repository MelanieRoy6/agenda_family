import 'package:flutter/foundation.dart';

import 'google_auth_service.dart';
import 'calendar_service.dart';
import 'family_group_service.dart';
import 'notification_service.dart';
import 'prefs_service.dart';
import '../dev_config.dart';
import '../models/busy_period.dart';
import '../models/member_availability.dart';
import '../models/calendar_event.dart';

enum AvailabilityStatus { idle, loading, success, error }

class AvailabilityNotifier extends ChangeNotifier {
  final GoogleAuthService _authService;

  AvailabilityNotifier(this._authService);

  AvailabilityStatus _status = AvailabilityStatus.idle;
  List<MemberAvailability> _availabilities = const [];
  String? _errorMessage;

  // Conservés pour le rechargement automatique après une suppression
  List<String> _lastCalendarIds = const [];
  DateTime? _lastStart;
  DateTime? _lastEnd;

  AvailabilityStatus get status => _status;
  List<MemberAvailability> get availabilities => _availabilities;
  String? get errorMessage => _errorMessage;

  /// Email de l'utilisateur actuellement connecté (null si déconnecté).
  String? get currentUserEmail => _authService.currentUserEmail;

  /// Nom complet Google de l'utilisateur connecté (null si déconnecté).
  String? get currentUserDisplayName => _authService.currentUserDisplayName;

  bool get isLoading => _status == AvailabilityStatus.loading;
  bool get hasError => _status == AvailabilityStatus.error;

  /// Charge les événements pour [calendarIds] sur la plage [start]→[end].
  Future<void> loadAvailability({
    required List<String> calendarIds,
    required DateTime start,
    required DateTime end,
  }) async {
    _lastCalendarIds = calendarIds;
    _lastStart = start;
    _lastEnd = end;

    // ── Mode développement : données fictives, pas d'appel réseau ────────────
    if (kDevMode) {
      _availabilities = mockAvailabilities(start, end);
      _status = AvailabilityStatus.success;
      notifyListeners();
      return;
    }

    _status = AvailabilityStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = await _authService.authenticatedClient();
      final service = CalendarService(client);
      final raw = await service.fetchMemberEvents(
        calendarIds: calendarIds,
        start: start,
        end: end,
      );

      final ownEmail = _authService.currentUserEmail ?? '';
      final ownDisplayName = _authService.currentUserDisplayName ?? ownEmail;
      final ownEvents =
          raw.values.expand((e) => e).toList(growable: false);

      final groupCode = await PrefsService().getGroupCode();
      if (groupCode != null) {
        // Synchronise les créneaux occupés de l'utilisateur vers Firestore.
        final ownBusy = ownEvents
            .map((e) => BusyPeriod(start: e.start, end: e.end))
            .toList(growable: false);

        try {
          final groupService = FamilyGroupService();
          await groupService.syncBusyPeriods(
            code: groupCode,
            email: ownEmail,
            busyPeriods: ownBusy,
            rangeStart: start,
            rangeEnd: end,
          );

          final allMembers = await groupService.getGroupMembers(groupCode);
          final others = allMembers
              .where((m) => m.email.toLowerCase() != ownEmail.toLowerCase())
              .toList(growable: false);

          final othersBusy = others.isNotEmpty
              ? await groupService.getMembersBusyPeriods(
                  code: groupCode,
                  emails: others.map((m) => m.email).toList(),
                )
              : <String, List<BusyPeriod>>{};

          _availabilities = [
            MemberAvailability(
              email: ownEmail,
              displayName: ownDisplayName,
              events: ownEvents,
            ),
            ...others.map((m) {
              final busy =
                  othersBusy[m.email.toLowerCase()] ?? const [];
              return MemberAvailability(
                email: m.email,
                displayName: m.name,
                events: busy
                    .map((bp) =>
                        CalendarEvent(start: bp.start, end: bp.end))
                    .toList(growable: false),
              );
            }),
          ];
        } catch (_) {
          // Firestore indisponible — affiche uniquement les propres événements.
          _availabilities = [
            MemberAvailability(
              email: ownEmail,
              displayName: ownDisplayName,
              events: ownEvents,
            ),
          ];
        }
      } else {
        // Pas de groupe configuré : comportement original (une colonne par calendrier).
        _availabilities = raw.entries.map((entry) {
          return MemberAvailability(email: entry.key, events: entry.value);
        }).toList(growable: false);
      }

      _status = AvailabilityStatus.success;
    } on GoogleAuthCancelledException {
      _errorMessage = 'Connexion annulée par l\'utilisateur.';
      _status = AvailabilityStatus.error;
    } on CalendarServiceException catch (e) {
      _errorMessage = e.message;
      _status = AvailabilityStatus.error;
    } catch (e) {
      _errorMessage = 'Erreur inattendue : $e';
      _status = AvailabilityStatus.error;
    } finally {
      notifyListeners();
    }
  }

  /// Crée un événement dans le calendrier [calendarId], recharge la vue,
  /// et envoie une notification FCM à la famille si [notifyFamily] est vrai.
  ///
  /// Retourne `true` si la création a réussi.
  Future<bool> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    bool notifyFamily = false,
  }) async {
    // ── Mode développement : ajout local ─────────────────────────────────────
    if (kDevMode) {
      final newEvent = CalendarEvent(
        id: 'dev-new-${DateTime.now().millisecondsSinceEpoch}',
        calendarId: calendarId,
        title: title,
        creatorEmail: kMockUserEmail,
        start: start,
        end: end,
      );
      _availabilities = _availabilities.map((m) {
        if (m.email == kMockUserEmail) {
          return m.copyWith(events: [...m.events, newEvent]);
        }
        return m;
      }).toList();
      notifyListeners();
      return true;
    }

    try {
      final client = await _authService.authenticatedClient();
      final service = CalendarService(client);
      await service.createEvent(
        calendarId: calendarId,
        title: title,
        start: start,
        end: end,
      );

      if (notifyFamily) {
        final name = _authService.currentUserDisplayName ??
            _authService.currentUserEmail ??
            'Un membre';
        await NotificationService.notifyFamilyNewEvent(
          eventTitle: title,
          creatorName: name,
          start: start,
        );
      }

      if (_lastStart != null && _lastEnd != null) {
        await loadAvailability(
          calendarIds: _lastCalendarIds,
          start: _lastStart!,
          end: _lastEnd!,
        );
      }
      return true;
    } on GoogleAuthCancelledException {
      return false;
    } on CalendarServiceException {
      return false;
    }
  }

  void reset() {
    _status = AvailabilityStatus.idle;
    _availabilities = const [];
    _errorMessage = null;
    _lastCalendarIds = const [];
    _lastStart = null;
    _lastEnd = null;
    notifyListeners();
  }

  void clearError() {
    if (_status == AvailabilityStatus.error) {
      _status = AvailabilityStatus.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }
}
