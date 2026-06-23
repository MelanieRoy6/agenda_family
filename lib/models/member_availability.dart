import 'calendar_event.dart';

class MemberAvailability {
  final String email;
  final String displayName;
  final List<CalendarEvent> events;

  MemberAvailability({
    required this.email,
    String? displayName,
    required this.events,
  }) : displayName = displayName ?? email;

  bool get isFree => events.isEmpty;

  MemberAvailability copyWith({
    String? displayName,
    List<CalendarEvent>? events,
  }) {
    return MemberAvailability(
      email: email,
      displayName: displayName ?? this.displayName,
      events: events ?? this.events,
    );
  }

  @override
  String toString() =>
      'MemberAvailability($email, ${events.length} événement(s))';
}
