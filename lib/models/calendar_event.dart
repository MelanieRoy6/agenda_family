class CalendarEvent {
  final String? id;
  final String? calendarId;
  final String? title;
  final String? creatorEmail;
  final DateTime start;
  final DateTime end;

  const CalendarEvent({
    this.id,
    this.calendarId,
    this.title,
    this.creatorEmail,
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);

  @override
  String toString() =>
      'CalendarEvent(${title ?? 'sans titre'}, $start → $end, créateur: $creatorEmail)';

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      id == other.id &&
      start == other.start &&
      end == other.end;

  @override
  int get hashCode => Object.hash(id, start, end);
}
