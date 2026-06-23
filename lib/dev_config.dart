import 'models/calendar_event.dart';
import 'models/family_member.dart';
import 'models/member_availability.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODE DÉVELOPPEMENT
// Mettre kDevMode = false pour réactiver l'authentification Google et
// l'API Calendar réelle avant la mise en production.
// ─────────────────────────────────────────────────────────────────────────────
const bool kDevMode = true;

// ─── Identité fictive ────────────────────────────────────────────────────────

const String kMockUserEmail = 'moi@famille.fr';
const String kMockUserName = 'Marie Dupont';

// ─── Membres fictifs ─────────────────────────────────────────────────────────

const List<FamilyMember> kMockFamilyMembers = [
  FamilyMember(email: kMockUserEmail, name: kMockUserName),
  FamilyMember(email: 'jean@famille.fr', name: 'Jean Dupont'),
  FamilyMember(email: 'lucie@famille.fr', name: 'Lucie Dupont'),
];

// ─── Calendriers fictifs ──────────────────────────────────────────────────────

const List<String> kMockCalendarIds = [
  kMockUserEmail,
  'jean@famille.fr',
  'lucie@famille.fr',
];

// ─── Données fictives de disponibilité ───────────────────────────────────────

/// Génère des événements fictifs centrés sur la plage [start]→[end].
/// Les événements du jour actuel apparaissent toujours si le mois est courant.
List<MemberAvailability> mockAvailabilities(DateTime start, DateTime end) {
  final today = DateTime.now();
  // Ancre : aujourd'hui si dans la plage demandée, sinon premier jour de la plage.
  final anchor = (today.isAfter(start) && today.isBefore(end))
      ? DateTime(today.year, today.month, today.day)
      : DateTime(start.year, start.month, start.day);

  DateTime day(int offset) => anchor.add(Duration(days: offset));

  return [
    MemberAvailability(
      email: kMockUserEmail,
      displayName: kMockUserName,
      events: [
        CalendarEvent(
          id: 'dev-1',
          calendarId: kMockUserEmail,
          title: 'Réunion travail',
          creatorEmail: kMockUserEmail,
          start: day(0).add(const Duration(hours: 9)),
          end: day(0).add(const Duration(hours: 10, minutes: 30)),
        ),
        CalendarEvent(
          id: 'dev-2',
          calendarId: kMockUserEmail,
          title: 'Sport',
          creatorEmail: kMockUserEmail,
          start: day(0).add(const Duration(hours: 18)),
          end: day(0).add(const Duration(hours: 19, minutes: 30)),
        ),
        CalendarEvent(
          id: 'dev-3',
          calendarId: kMockUserEmail,
          title: 'Rendez-vous banque',
          creatorEmail: kMockUserEmail,
          start: day(2).add(const Duration(hours: 11)),
          end: day(2).add(const Duration(hours: 12)),
        ),
      ],
    ),
    MemberAvailability(
      email: 'jean@famille.fr',
      displayName: 'Jean Dupont',
      events: [
        CalendarEvent(
          id: 'dev-4',
          calendarId: 'jean@famille.fr',
          title: 'Médecin',
          creatorEmail: 'jean@famille.fr',
          start: day(0).add(const Duration(hours: 14)),
          end: day(0).add(const Duration(hours: 15)),
        ),
        CalendarEvent(
          id: 'dev-5',
          calendarId: 'jean@famille.fr',
          title: 'Dentiste',
          creatorEmail: 'jean@famille.fr',
          start: day(1).add(const Duration(hours: 9, minutes: 30)),
          end: day(1).add(const Duration(hours: 10, minutes: 30)),
        ),
      ],
    ),
    MemberAvailability(
      email: 'lucie@famille.fr',
      displayName: 'Lucie Dupont',
      events: [
        CalendarEvent(
          id: 'dev-6',
          calendarId: 'lucie@famille.fr',
          title: 'École — sortie',
          creatorEmail: 'lucie@famille.fr',
          start: day(0).add(const Duration(hours: 16, minutes: 30)),
          end: day(0).add(const Duration(hours: 18)),
        ),
      ],
    ),
  ];
}
