import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' hide Colors;
import 'package:provider/provider.dart';

import '../services/google_auth_service.dart';
import '../services/prefs_service.dart';
import 'home_calendar_view.dart';

enum _Step { welcome, signingIn, loadingCalendars, selectCalendars, saving }

// ─── écran principal ──────────────────────────────────────────────────────────

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  _Step _step = _Step.welcome;
  String? _error;
  String? _userEmail;
  List<CalendarListEntry> _calendars = const [];
  final Set<String> _selectedIds = {};

  Future<void> _startSignIn() async {
    setState(() {
      _step = _Step.signingIn;
      _error = null;
    });

    final authService = context.read<GoogleAuthService>();

    try {
      await authService.signIn();
      _userEmail = authService.currentUserEmail;

      if (!mounted) return;
      setState(() => _step = _Step.loadingCalendars);

      final calApi = await authService.authenticatedClient();
      final result = await calApi.calendarList.list(showHidden: false);
      final items = result.items ?? [];

      // Pré-coche l'agenda principal
      final preSelected = {
        for (final c in items)
          if (c.primary == true && c.id != null) c.id!,
      };

      if (!mounted) return;
      setState(() {
        _calendars = items;
        _selectedIds
          ..clear()
          ..addAll(preSelected);
        _step = _Step.selectCalendars;
      });
    } on GoogleAuthCancelledException {
      if (mounted) setState(() => _step = _Step.welcome);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Impossible de récupérer vos agendas. Veuillez réessayer.';
          _step = _Step.welcome;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_selectedIds.isEmpty || _userEmail == null) return;

    setState(() => _step = _Step.saving);

    try {
      final displayName =
          context.read<GoogleAuthService>().currentUserDisplayName;
      await PrefsService().saveOnboarding(
        userEmail: _userEmail!,
        userDisplayName: displayName,
        calendarIds: _selectedIds.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeCalendarView()),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors de la sauvegarde. Veuillez réessayer.';
          _step = _Step.selectCalendars;
        });
      }
    }
  }

  void _onToggle(String id) => setState(() {
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          child: switch (_step) {
            _Step.welcome => _WelcomeStep(
                key: const ValueKey('welcome'),
                onSignIn: _startSignIn,
                error: _error,
              ),
            _Step.signingIn => const _LoadingStep(
                key: ValueKey('signing-in'),
                message: 'Connexion en cours…',
              ),
            _Step.loadingCalendars => const _LoadingStep(
                key: ValueKey('loading-cals'),
                message: 'Récupération de vos agendas…',
              ),
            _Step.selectCalendars => _SelectCalendarsStep(
                key: const ValueKey('select-cals'),
                userEmail: _userEmail ?? '',
                calendars: _calendars,
                selectedIds: _selectedIds,
                onToggle: _onToggle,
                onContinue: _save,
                error: _error,
              ),
            _Step.saving => const _LoadingStep(
                key: ValueKey('saving'),
                message: 'Enregistrement…',
              ),
          },
        ),
      ),
    );
  }
}

// ─── étape 1 : accueil ────────────────────────────────────────────────────────

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onSignIn;
  final String? error;

  const _WelcomeStep({super.key, required this.onSignIn, this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Illustration
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              size: 52,
              color: cs.primary,
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Agenda Famille',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            "Voyez en un clin d'œil quand chaque\nmembre de la famille est libre ou occupé.",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 3),

          if (error != null) ...[
            _ErrorBanner(message: error!),
            const SizedBox(height: 20),
          ],

          _GoogleSignInButton(onPressed: onSignIn),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Vos données restent sur votre appareil.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),
          const _StepDots(current: 0, total: 2),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── étape chargement ─────────────────────────────────────────────────────────

class _LoadingStep extends StatelessWidget {
  final String message;

  const _LoadingStep({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── étape 2 : sélection des agendas ─────────────────────────────────────────

class _SelectCalendarsStep extends StatelessWidget {
  final String userEmail;
  final List<CalendarListEntry> calendars;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;
  final VoidCallback onContinue;
  final String? error;

  const _SelectCalendarsStep({
    super.key,
    required this.userEmail,
    required this.calendars,
    required this.selectedIds,
    required this.onToggle,
    required this.onContinue,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canContinue = selectedIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge email connecté
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        userEmail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Vos agendas',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Cochez les agendas dont les événements\ncomptent comme "occupé" pour vous.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),

        const Divider(height: 1),

        // Liste des agendas
        Expanded(
          child: calendars.isEmpty
              ? Center(
                  child: Text(
                    'Aucun agenda trouvé.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: calendars.length,
                  separatorBuilder: (_, index) =>
                      const Divider(height: 1, indent: 64),
                  itemBuilder: (_, i) {
                    final cal = calendars[i];
                    final id = cal.id ?? '';
                    return _CalendarTile(
                      name: cal.summary ?? id,
                      isPrimary: cal.primary == true,
                      dotColor:
                          _hexToColor(cal.backgroundColor) ?? cs.primary,
                      isSelected: selectedIds.contains(id),
                      onTap: id.isNotEmpty ? () => onToggle(id) : null,
                    );
                  },
                ),
        ),

        const Divider(height: 1),

        // Pied de page avec bouton
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            children: [
              if (error != null) ...[
                _ErrorBanner(message: error!),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: canContinue ? onContinue : null,
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Continuer'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: !canContinue
                    ? Text(
                        'Sélectionnez au moins un agenda.',
                        key: const ValueKey('hint'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.error),
                      )
                    : const SizedBox(key: ValueKey('empty'), height: 16),
              ),

              const SizedBox(height: 8),
              const _StepDots(current: 1, total: 2),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  static Color? _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return null;
  }
}

// ─── widgets réutilisables ────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Se connecter avec Google',
      button: true,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFDADCE0), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GoogleLogo(),
              const SizedBox(width: 12),
              const Text(
                'Continuer avec Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1F1F1F),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFF4285F4),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

class _CalendarTile extends StatelessWidget {
  final String name;
  final bool isPrimary;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CalendarTile({
    required this.name,
    required this.isPrimary,
    required this.dotColor,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Semantics(
      label: '$name${isPrimary ? ', agenda principal' : ''}',
      checked: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              // Point de couleur Google Calendar
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 16),

              // Nom + badge principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Agenda principal',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Case à cocher
              Checkbox(
                value: isSelected,
                onChanged: onTap != null ? (_) => onTap!() : null,
                activeColor: cs.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final int total;

  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? cs.primary : cs.onSurface.withAlpha(51),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 20, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
