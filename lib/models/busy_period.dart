class BusyPeriod {
  final DateTime start;
  final DateTime end;

  const BusyPeriod({required this.start, required this.end});

  Duration get duration => end.difference(start);

  Map<String, dynamic> toJson() => {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
      };

  factory BusyPeriod.fromJson(Map<String, dynamic> json) => BusyPeriod(
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
      );

  @override
  String toString() => 'BusyPeriod($start → $end)';

  @override
  bool operator ==(Object other) =>
      other is BusyPeriod && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

class CalendarAvailability {
  final String email;
  final List<BusyPeriod> busyPeriods;
  final List<String> errors;

  const CalendarAvailability({
    required this.email,
    required this.busyPeriods,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isFree => busyPeriods.isEmpty;
}
