import 'package:googleapis/calendar/v3.dart';

import '../models/busy_period.dart';
import '../models/calendar_event.dart';

class CalendarService {
  final CalendarApi _api;

  CalendarService(this._api);

  /// Récupère les événements détaillés (titre, créateur, id) pour chaque
  /// calendrier de [calendarIds] entre [start] et [end].
  Future<Map<String, List<CalendarEvent>>> fetchMemberEvents({
    required List<String> calendarIds,
    required DateTime start,
    required DateTime end,
  }) async {
    if (calendarIds.isEmpty) return {};

    final result = <String, List<CalendarEvent>>{};
    for (final calendarId in calendarIds) {
      try {
        result[calendarId] =
            await _fetchEventsForCalendar(calendarId, start, end);
      } catch (_) {
        result[calendarId] = const [];
      }
    }
    return result;
  }

  Future<List<CalendarEvent>> _fetchEventsForCalendar(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _api.events.list(
      calendarId,
      timeMin: start.toUtc(),
      timeMax: end.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );
    return (response.items ?? [])
        .where(_hasValidTime)
        .map((e) => _toCalendarEvent(e, calendarId))
        .toList(growable: false);
  }

  bool _hasValidTime(Event e) =>
      e.start?.dateTime != null || e.start?.date != null;

  CalendarEvent _toCalendarEvent(Event event, String calendarId) {
    final start = event.start!.dateTime ?? _dateOnly(event.start!.date!);
    final end = event.end?.dateTime ??
        (event.end?.date != null
            ? _dateOnly(event.end!.date!)
            : start.add(const Duration(hours: 1)));

    return CalendarEvent(
      id: event.id,
      calendarId: calendarId,
      title: event.summary,
      creatorEmail: event.creator?.email,
      start: start,
      end: end,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Crée un événement dans le calendrier [calendarId].
  ///
  /// Retourne l'id de l'événement créé.
  Future<String> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    final event = Event(
      summary: title,
      start: EventDateTime(dateTime: start.toUtc()),
      end: EventDateTime(dateTime: end.toUtc()),
    );

    try {
      final created = await _api.events.insert(event, calendarId);
      return created.id ?? '';
    } on DetailedApiRequestError catch (e) {
      throw CalendarServiceException(
        'Erreur lors de la création (${e.status}) : ${e.message}',
        cause: e,
      );
    } catch (e) {
      throw CalendarServiceException(
        'Impossible de créer l\'événement : $e',
        cause: e,
      );
    }
  }

  /// Interroge l'API FreeBusy (conservé pour usage futur).
  Future<Map<String, CalendarAvailability>> fetchFamilyAvailability({
    required List<String> emails,
    required DateTime start,
    required DateTime end,
  }) async {
    if (emails.isEmpty) return {};

    final request = FreeBusyRequest(
      timeMin: start.toUtc(),
      timeMax: end.toUtc(),
      items: emails.map((e) => FreeBusyRequestItem(id: e)).toList(),
    );

    final FreeBusyResponse response;
    try {
      response = await _api.freebusy.query(request);
    } on DetailedApiRequestError catch (e) {
      throw CalendarServiceException(
        'Erreur API Google Calendar (${e.status}) : ${e.message}',
        cause: e,
      );
    } catch (e) {
      throw CalendarServiceException(
        'Impossible de joindre l\'API Calendar : $e',
        cause: e,
      );
    }

    return _parseFreeBusyResponse(response, emails);
  }

  Map<String, CalendarAvailability> _parseFreeBusyResponse(
    FreeBusyResponse response,
    List<String> emails,
  ) {
    final calendars = response.calendars ?? {};
    return {
      for (final email in emails)
        email: _parseFreeBusyCalendar(email, calendars[email]),
    };
  }

  CalendarAvailability _parseFreeBusyCalendar(
    String email,
    FreeBusyCalendar? calendar,
  ) {
    if (calendar == null) {
      return CalendarAvailability(email: email, busyPeriods: const []);
    }

    final errors = calendar.errors
            ?.map((e) => '${e.domain ?? 'inconnu'} : ${e.reason ?? '?'}')
            .toList() ??
        const [];

    final busyPeriods = calendar.busy
            ?.where((p) => p.start != null && p.end != null)
            .map((p) => BusyPeriod(start: p.start!, end: p.end!))
            .toList(growable: false) ??
        const [];

    return CalendarAvailability(
      email: email,
      busyPeriods: busyPeriods,
      errors: errors,
    );
  }
}

class CalendarServiceException implements Exception {
  final String message;
  final Object? cause;

  const CalendarServiceException(this.message, {this.cause});

  @override
  String toString() => 'CalendarServiceException : $message';
}
