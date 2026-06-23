import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/availability_notifier.dart';
import '../services/prefs_service.dart';

/// BottomSheet de création d'un nouvel événement.
///
/// Champs : titre, date (fixée à [initialDate]), heure de début,
/// heure de fin, et option "Notifier la famille".
class AddEventSheet extends StatefulWidget {
  final DateTime initialDate;

  const AddEventSheet({super.key, required this.initialDate});

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _notifyFamily = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = TimeOfDay.now();
    _startTime = TimeOfDay(hour: now.hour, minute: 0);
    _endTime = TimeOfDay(
      hour: (now.hour + 1) % 24,
      minute: 0,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  DateTime _toDateTime(TimeOfDay t) => DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day,
        t.hour,
        t.minute,
      );

  String _formatDate(DateTime d) {
    const weekdays = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche'
    ];
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}h${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
        // Ajuste automatiquement la fin si elle précède le début
        final startMin = picked.hour * 60 + picked.minute;
        final endMin = _endTime.hour * 60 + _endTime.minute;
        if (endMin <= startMin) {
          final newEnd = startMin + 60;
          _endTime = TimeOfDay(hour: (newEnd ~/ 60) % 24, minute: newEnd % 60);
        }
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _toDateTime(_startTime);
    final end = _toDateTime(_endTime);

    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'heure de fin doit être après le début.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final calendarIds = await PrefsService().getCalendarIds();
    final calendarId = calendarIds.isNotEmpty ? calendarIds.first : 'primary';

    if (!mounted) return;

    final success = await context.read<AvailabilityNotifier>().createEvent(
          calendarId: calendarId,
          title: _titleController.text.trim(),
          start: start,
          end: end,
          notifyFamily: _notifyFamily,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _notifyFamily
                ? 'Événement créé et famille notifiée !'
                : 'Événement créé.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de créer l\'événement.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            children: [
              // ── Barre de glissement ─────────────────────────────────────
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

              // ── Titre du volet ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Créer un événement',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),

              Divider(color: cs.outlineVariant),
              const SizedBox(height: 20),

              // ── Champ titre ──────────────────────────────────────────────
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Titre de l\'événement',
                  hintText: 'Ex : Réunion famille, Sport…',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withAlpha(60),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
                onFieldSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: 20),

              // ── Date ─────────────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    Text(
                      _formatDate(widget.initialDate),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Horaires ─────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: 'Début',
                      time: _formatTime(_startTime),
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_forward_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeTile(
                      label: 'Fin',
                      time: _formatTime(_endTime),
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Divider(color: cs.outlineVariant),

              // ── Option "Notifier la famille" ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    // Icône notification.png
                    Image.asset(
                      'icon/notification.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Notifier la famille',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            'Envoie une notification push à tous les membres',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Switch(
                      value: _notifyFamily,
                      onChanged: (v) => setState(() => _notifyFamily = v),
                    ),
                  ],
                ),
              ),

              Divider(color: cs.outlineVariant),
              const SizedBox(height: 24),

              // ── Bouton créer ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    disabledBackgroundColor: cs.onSurface.withAlpha(31),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: cs.onPrimary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(_notifyFamily
                                ? 'Créer et notifier la famille'
                                : 'Créer l\'événement'),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── tuile horaire cliquable ──────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withAlpha(120)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
