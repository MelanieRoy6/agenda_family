import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dev_config.dart';
import 'services/google_auth_service.dart';
import 'services/availability_notifier.dart';
import 'services/prefs_service.dart';
import 'views/home_calendar_view.dart';
import 'views/onboarding_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase est requis pour les notifications push.
  // Sans google-services.json (Android) ou GoogleService-Info.plist (iOS),
  // l'initialisation échoue silencieusement et les notifications sont désactivées.
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  runApp(const AgendaFamilyApp());
}

class AgendaFamilyApp extends StatelessWidget {
  const AgendaFamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<GoogleAuthService>(
          create: (_) => GoogleAuthService(),
        ),
        ChangeNotifierProxyProvider<GoogleAuthService, AvailabilityNotifier>(
          create: (ctx) => AvailabilityNotifier(ctx.read<GoogleAuthService>()),
          update: (_, auth, previous) => previous ?? AvailabilityNotifier(auth),
        ),
      ],
      child: MaterialApp(
        title: 'Agenda Family',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const _AppRouter(),
      ),
    );
  }
}

/// Redirige vers [OnboardingView] si la configuration n'existe pas encore,
/// ou vers [HomeCalendarView] si l'utilisateur a déjà terminé l'onboarding.
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      // En mode dev : court-circuit vers HomeCalendarView sans vérifier les prefs.
      future: kDevMode
          ? Future.value(true)
          : PrefsService().isOnboardingComplete(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFC8E6C9),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data! ? const HomeCalendarView() : const OnboardingView();
      },
    );
  }
}
