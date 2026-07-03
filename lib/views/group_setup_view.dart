import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../dev_config.dart';
import '../services/family_group_service.dart';
import '../services/google_auth_service.dart';
import '../services/prefs_service.dart';
import 'home_calendar_view.dart';

enum _Step { choice, creating, showCode, joining, saving }

class GroupSetupView extends StatefulWidget {
  const GroupSetupView({super.key});

  @override
  State<GroupSetupView> createState() => _GroupSetupViewState();
}

class _GroupSetupViewState extends State<GroupSetupView> {
  _Step _step = _Step.choice;
  String? _error;
  String _generatedCode = '';
  final _codeController = TextEditingController();

  String _email = '';
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    if (kDevMode) {
      setState(() {
        _email = kMockUserEmail;
        _displayName = kMockUserName;
      });
      return;
    }

    // Priorité au compte Google en mémoire (juste après l'onboarding).
    final authService = context.read<GoogleAuthService>();
    final authEmail = authService.currentUserEmail;
    final authName = authService.currentUserDisplayName;

    if (authEmail != null) {
      setState(() {
        _email = authEmail;
        _displayName = authName ?? authEmail;
      });
      return;
    }

    // Fallback : lire depuis les préférences.
    final prefs = PrefsService();
    final email = await prefs.getUserEmail() ?? '';
    final displayName = await prefs.getUserDisplayName() ?? email;
    if (mounted) {
      setState(() {
        _email = email;
        _displayName = displayName;
      });
    }
  }

  Future<void> _createGroup() async {
    if (_email.isEmpty) return;
    setState(() {
      _step = _Step.creating;
      _error = null;
    });
    try {
      final code = await FamilyGroupService().createGroup(
        email: _email,
        displayName: _displayName,
      );
      await PrefsService().saveGroupCode(code);
      if (!mounted) return;
      setState(() {
        _generatedCode = code;
        _step = _Step.showCode;
      });
    } on FamilyGroupException catch (e) {
      if (mounted) setState(() => (_error = e.message, _step = _Step.choice));
    } catch (e) {
      if (mounted) {
        setState(() => (_error = e.toString(), _step = _Step.choice));
      }
    }
  }

  Future<void> _joinGroup() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _email.isEmpty) return;
    setState(() {
      _step = _Step.saving;
      _error = null;
    });
    try {
      await FamilyGroupService().joinGroup(
        code: code,
        email: _email,
        displayName: _displayName,
      );
      await PrefsService().saveGroupCode(code.trim().toUpperCase());
      if (!mounted) return;
      _goHome();
    } on FamilyGroupException catch (e) {
      if (mounted) setState(() => (_error = e.message, _step = _Step.joining));
    } catch (_) {
      if (mounted) {
        setState(() => (
              _error =
                  'Impossible de rejoindre le groupe. Vérifiez votre connexion.',
              _step = _Step.joining
            ));
      }
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeCalendarView()),
    );
  }

  bool get _isLoading =>
      _step == _Step.creating || _step == _Step.saving;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          child: switch (_step) {
            _Step.choice || _Step.creating => _ChoiceStep(
                key: const ValueKey('choice'),
                isLoading: _isLoading,
                error: _error,
                onCreateGroup: _isLoading ? null : _createGroup,
                onJoinGroup: _isLoading
                    ? null
                    : () => setState(() {
                          _step = _Step.joining;
                          _error = null;
                        }),
              ),
            _Step.showCode => _ShowCodeStep(
                key: const ValueKey('show-code'),
                code: _generatedCode,
                onContinue: _goHome,
              ),
            _Step.joining || _Step.saving => _JoinStep(
                key: const ValueKey('join'),
                controller: _codeController,
                isLoading: _isLoading,
                error: _error,
                onJoin: _isLoading ? null : _joinGroup,
                onBack: _isLoading
                    ? null
                    : () => setState(() {
                          _step = _Step.choice;
                          _error = null;
                          _codeController.clear();
                        }),
              ),
          },
        ),
      ),
    );
  }
}

// ─── étape 1 : choix créer / rejoindre ───────────────────────────────────────

class _ChoiceStep extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback? onCreateGroup;
  final VoidCallback? onJoinGroup;

  const _ChoiceStep({
    super.key,
    required this.isLoading,
    required this.onCreateGroup,
    required this.onJoinGroup,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.group_rounded, size: 52, color: cs.primary),
          ),

          const SizedBox(height: 32),

          Text(
            'Groupe famille',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            'Créez un groupe et partagez le code\navec vos proches, ou rejoignez\nle groupe de quelqu\'un.',
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

          if (isLoading)
            const SizedBox(
              height: 56,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: onCreateGroup,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer un groupe'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: onJoinGroup,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Rejoindre un groupe'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ─── étape 2a : affichage du code créé ───────────────────────────────────────

class _ShowCodeStep extends StatefulWidget {
  final String code;
  final VoidCallback onContinue;

  const _ShowCodeStep({super.key, required this.code, required this.onContinue});

  @override
  State<_ShowCodeStep> createState() => _ShowCodeStepState();
}

class _ShowCodeStepState extends State<_ShowCodeStep> {
  bool _copied = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Affiche le code avec un tiret au milieu : "ABC-XYZ"
    final displayCode = widget.code.length == 6
        ? '${widget.code.substring(0, 3)}-${widget.code.substring(3)}'
        : widget.code;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),

          Icon(Icons.check_circle_rounded, size: 72, color: cs.primary),

          const SizedBox(height: 24),

          Text(
            'Groupe créé !',
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          Text(
            'Partagez ce code avec les membres\nde votre famille.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Code affiché en grand avec bouton copier
          GestureDetector(
            onTap: _copyCode,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayCode,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    color: cs.primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _copied
                ? Text(
                    'Copié !',
                    key: const ValueKey('copied'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.primary),
                  )
                : Text(
                    'Appuyez pour copier',
                    key: const ValueKey('hint'),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
          ),

          const Spacer(flex: 3),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
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

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ─── étape 2b : rejoindre via un code ────────────────────────────────────────

class _JoinStep extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final String? error;
  final VoidCallback? onJoin;
  final VoidCallback? onBack;

  const _JoinStep({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onJoin,
    required this.onBack,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),

          Center(
            child: Text(
              'Rejoindre un groupe',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Text(
              'Saisissez le code partagé par\nun membre de votre famille.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 40),

          TextField(
            controller: controller,
            enabled: !isLoading,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: theme.textTheme.headlineSmall?.copyWith(
                color: cs.onSurfaceVariant.withAlpha(100),
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withAlpha(60),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            onSubmitted: (_) => onJoin?.call(),
          ),

          if (error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: error!),
          ],

          const Spacer(flex: 3),

          if (isLoading)
            const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Rejoindre le groupe'),
              ),
            ),

          const SizedBox(height: 14),

          Center(
            child: TextButton.icon(
              onPressed: isLoading ? null : onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Retour'),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── formatteur texte en majuscules ──────────────────────────────────────────

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

// ─── bannière d'erreur ────────────────────────────────────────────────────────

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
          Icon(Icons.info_outline_rounded, size: 20, color: cs.onErrorContainer),
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
