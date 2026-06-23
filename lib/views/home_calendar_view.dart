import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../dev_config.dart';
import '../models/calendar_event.dart';
import '../models/family_member.dart';
import '../models/member_availability.dart';
import '../services/availability_notifier.dart';
import '../services/notification_service.dart';
import '../services/prefs_service.dart';
import 'add_event_sheet.dart';

const double _kHourHeight = 64.0;
const double _kTimeColWidth = 44.0;

const _kMemberColors = [
  Color(0xFF4A90D9),
  Color(0xFF27AE60),
  Color(0xFFE67E22),
  Color(0xFF9B59B6),
  Color(0xFFE74C3C),
  Color(0xFF1ABC9C),
];

// ─── écran principal ──────────────────────────────────────────────────────────

class HomeCalendarView extends StatefulWidget {
  const HomeCalendarView({super.key});

  @override
  State<HomeCalendarView> createState() => _HomeCalendarViewState();
}

class _HomeCalendarViewState extends State<HomeCalendarView> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _format = CalendarFormat.month;
  List<String> _calendarIds = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = now;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCalendarIds(now));
  }

  Future<void> _initCalendarIds(DateTime month) async {
    // En mode dev : IDs fictifs, pas de lecture des prefs.
    final ids = kDevMode
        ? kMockCalendarIds
        : await PrefsService().getCalendarIds();
    if (!mounted) return;
    setState(() => _calendarIds = ids);

    // Abonne l'appareil au topic FCM famille (silencieux si Firebase absent).
    if (!kDevMode) NotificationService.init();

    _loadMonth(month);
  }

  void _showFamilyMembers() {
    final currentUserEmail =
        context.read<AvailabilityNotifier>().currentUserEmail;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FamilyMembersSheet(currentUserEmail: currentUserEmail),
    );
  }

  void _onAddEventTapped() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEventSheet(initialDate: _selectedDay),
    );
  }

  void _loadMonth(DateTime month) {
    if (_calendarIds.isEmpty) return;
    context.read<AvailabilityNotifier>().loadAvailability(
      calendarIds: _calendarIds,
      start: DateTime(month.year, month.month, 1),
      end: DateTime(month.year, month.month + 1, 0, 23, 59, 59),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserEmail =
        context.watch<AvailabilityNotifier>().currentUserEmail;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC8E6C9),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Image.asset(
          'icon/logo.png',
          height: 44,
          fit: BoxFit.contain,
          semanticLabel: 'Agenda Family',
        ),
        actions: [
          IconButton(
            icon: Image.asset(
              'icon/personne.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            tooltip: 'Membres de la famille',
            onPressed: _showFamilyMembers,
          ),
          IconButton(
            icon: Icon(_format == CalendarFormat.month
                ? Icons.view_week
                : Icons.calendar_month),
            tooltip: _format == CalendarFormat.month
                ? 'Vue semaine'
                : 'Vue mois',
            onPressed: () => setState(() {
              _format = _format == CalendarFormat.month
                  ? CalendarFormat.week
                  : CalendarFormat.month;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendar(context),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: _DayTimeline(
              selectedDay: _selectedDay,
              currentUserEmail: currentUserEmail,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _AddEventBar(onTap: _onAddEventTapped),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: _focusedDay,
      calendarFormat: _format,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Mois',
        CalendarFormat.week: 'Semaine',
      },
      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
      onDaySelected: (selected, focused) => setState(() {
        _selectedDay = selected;
        _focusedDay = focused;
      }),
      onPageChanged: (focused) {
        setState(() => _focusedDay = focused);
        _loadMonth(focused);
      },
      onFormatChanged: (fmt) => setState(() => _format = fmt),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: cs.primaryContainer,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(color: cs.onPrimaryContainer),
        selectedTextStyle: TextStyle(color: cs.onPrimary),
      ),
    );
  }
}

// ─── timeline du jour ─────────────────────────────────────────────────────────

class _DayTimeline extends StatelessWidget {
  final DateTime selectedDay;
  final String? currentUserEmail;

  const _DayTimeline({
    required this.selectedDay,
    required this.currentUserEmail,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<AvailabilityNotifier>();

    if (notifier.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notifier.hasError) {
      return _ErrorPlaceholder(
        message: notifier.errorMessage ?? 'Erreur inconnue',
        onRetry: notifier.clearError,
      );
    }

    final members = notifier.availabilities;

    if (members.isEmpty) {
      return const _EmptyPlaceholder();
    }

    return Column(
      children: [
        _MemberNamesHeader(members: members),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            child: _TimelineGrid(
              selectedDay: selectedDay,
              members: members,
              currentUserEmail: currentUserEmail,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── placeholders ─────────────────────────────────────────────────────────────

class _ErrorPlaceholder extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPlaceholder({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.red),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text('Aucun membre configuré.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── en-tête des membres ──────────────────────────────────────────────────────

class _MemberNamesHeader extends StatelessWidget {
  final List<MemberAvailability> members;

  const _MemberNamesHeader({required this.members});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          const SizedBox(width: _kTimeColWidth),
          ...members.indexed.map((entry) {
            final (i, member) = entry;
            final color = _kMemberColors[i % _kMemberColors.length];
            return Expanded(
              child: Text(
                _shortName(member.displayName),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _shortName(String name) {
    final at = name.indexOf('@');
    return at > 0 ? name.substring(0, at) : name;
  }
}

// ─── grille timeline ──────────────────────────────────────────────────────────

class _TimelineGrid extends StatelessWidget {
  final DateTime selectedDay;
  final List<MemberAvailability> members;
  final String? currentUserEmail;

  const _TimelineGrid({
    required this.selectedDay,
    required this.members,
    required this.currentUserEmail,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24 * _kHourHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HourLabelsColumn(),
          ...members.indexed.map((entry) {
            final (i, member) = entry;
            return Expanded(
              child: _MemberColumn(
                color: _kMemberColors[i % _kMemberColors.length],
                events: _eventsForDay(member.events),
                selectedDay: selectedDay,
                memberName: member.displayName,
                currentUserEmail: currentUserEmail,
              ),
            );
          }),
        ],
      ),
    );
  }

  List<CalendarEvent> _eventsForDay(List<CalendarEvent> events) {
    final dayStart =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return events.where((e) {
      final s = e.start.toLocal();
      final end = e.end.toLocal();
      return s.isBefore(dayEnd) && end.isAfter(dayStart);
    }).toList();
  }
}

// ─── colonne des heures ───────────────────────────────────────────────────────

class _HourLabelsColumn extends StatelessWidget {
  const _HourLabelsColumn();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kTimeColWidth,
      height: 24 * _kHourHeight,
      child: Stack(
        children: List.generate(24, (h) {
          return Positioned(
            top: h * _kHourHeight - 7,
            left: 0,
            right: 0,
            child: Text(
              '${h.toString().padLeft(2, '0')}h',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          );
        }),
      ),
    );
  }
}

// ─── colonne d'un membre ──────────────────────────────────────────────────────

class _MemberColumn extends StatelessWidget {
  final Color color;
  final List<CalendarEvent> events;
  final DateTime selectedDay;
  final String memberName;
  final String? currentUserEmail;

  const _MemberColumn({
    required this.color,
    required this.events,
    required this.selectedDay,
    required this.memberName,
    required this.currentUserEmail,
  });

  @override
  Widget build(BuildContext context) {
    final dayStart =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    return SizedBox(
      height: 24 * _kHourHeight,
      child: Stack(
        children: [
          // Séparateur vertical gauche
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(width: 1, color: const Color(0xFFDDDDDD)),
          ),
          // Lignes horizontales par heure
          ...List.generate(
            24,
            (h) => Positioned(
              top: h * _kHourHeight,
              left: 0,
              right: 0,
              child: const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ),
          ),
          // Blocs d'événements
          ...events.map((event) => _EventBlock(
                event: event,
                dayStart: dayStart,
                color: color,
                memberName: memberName,
                currentUserEmail: currentUserEmail,
              )),
        ],
      ),
    );
  }
}

// ─── barre d'ajout fixe ───────────────────────────────────────────────────────

class _AddEventBar extends StatelessWidget {
  final VoidCallback onTap;

  const _AddEventBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFC8E6C9),
        border: Border(
          top: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Semantics(
        label: 'Ajouter un événement',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'icon/ajout.png',
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── bloc d'un événement ─────────────────────────────────────────────────────

class _EventBlock extends StatelessWidget {
  final CalendarEvent event;
  final DateTime dayStart;
  final Color color;
  final String memberName;
  final String? currentUserEmail;

  const _EventBlock({
    required this.event,
    required this.dayStart,
    required this.color,
    required this.memberName,
    required this.currentUserEmail,
  });

  @override
  Widget build(BuildContext context) {
    final dayEnd = dayStart.add(const Duration(days: 1));

    final localStart = event.start.toLocal();
    final localEnd = event.end.toLocal();
    final clampedStart = localStart.isBefore(dayStart) ? dayStart : localStart;
    final clampedEnd = localEnd.isAfter(dayEnd) ? dayEnd : localEnd;

    final startMinutes = clampedStart.difference(dayStart).inMinutes;
    final durationMin =
        clampedEnd.difference(clampedStart).inMinutes.clamp(1, 1440);

    final top = startMinutes / 60.0 * _kHourHeight;
    final height =
        (durationMin / 60.0 * _kHourHeight).clamp(4.0, double.infinity);

    // L'icône poubelle s'affiche seulement si l'utilisateur est le créateur
    // ET que l'événement possède un id et un calendarId (supprimable).
    final canDelete =
        event.canDelete && event.isOwnedBy(currentUserEmail);

    return Positioned(
      top: top,
      left: 3,
      right: 3,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha(191),
          borderRadius: BorderRadius.circular(4),
        ),
        clipBehavior: Clip.hardEdge,
        child: height >= 20
            ? Stack(
                children: [
                  // Contenu central : icône + titre
                  Padding(
                    padding: EdgeInsets.only(
                      left: 5,
                      right: canDelete ? 18 : 5,
                    ),
                    child: Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'icon/indisponible.png',
                            width: 13,
                            height: 13,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              event.title ?? _firstName(memberName),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Icône poubelle en haut à droite — visible seulement
                  // si l'utilisateur connecté est le créateur de l'événement.
                  if (canDelete)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _confirmDelete(context),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Image.asset(
                            'icon/poubelle.png',
                            width: 14,
                            height: 14,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'événement'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${event.title ?? 'cet événement'} » ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'icon/poubelle.png',
                  width: 16,
                  height: 16,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 6),
                const Text('Supprimer'),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success =
          await context.read<AvailabilityNotifier>().deleteEvent(event);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de supprimer l\'événement.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  static String _firstName(String displayName) {
    final atIndex = displayName.indexOf('@');
    final name = atIndex > 0 ? displayName.substring(0, atIndex) : displayName;
    final spaceIndex = name.indexOf(' ');
    return spaceIndex > 0 ? name.substring(0, spaceIndex) : name;
  }
}

// ─── volet membres de la famille ─────────────────────────────────────────────

class _FamilyMembersSheet extends StatelessWidget {
  final String? currentUserEmail;

  const _FamilyMembersSheet({required this.currentUserEmail});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre de glissement
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // En-tête
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Image.asset(
                    'icon/personne.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Membres de la famille',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: cs.outlineVariant),

            // Liste
            Expanded(
              child: FutureBuilder<List<FamilyMember>>(
                future: kDevMode
                    ? Future.value(List<FamilyMember>.from(kMockFamilyMembers))
                    : PrefsService().getFamilyMembers(),
                builder: (ctx, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final members = snapshot.data!;

                  if (members.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 48,
                                color: cs.onSurfaceVariant.withAlpha(100)),
                            const SizedBox(height: 12),
                            Text(
                              'Aucun membre enregistré.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: members.length,
                    separatorBuilder: (_, i) => Divider(
                      height: 1,
                      indent: 72,
                      color: cs.outlineVariant.withAlpha(100),
                    ),
                    itemBuilder: (_, i) => _MemberTile(
                      member: members[i],
                      colorIndex: i,
                      isCurrentUser: members[i].email.toLowerCase() ==
                          (currentUserEmail?.toLowerCase() ?? ''),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── tuile d'un membre ────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final FamilyMember member;
  final int colorIndex;
  final bool isCurrentUser;

  const _MemberTile({
    required this.member,
    required this.colorIndex,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final avatarColor = _kMemberColors[colorIndex % _kMemberColors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Avatar avec initiales
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarColor.withAlpha(220),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Nom + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Vous',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
