import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/startup_screen.dart';
import 'services/app_state.dart';
import 'services/notification_service.dart';
import 'services/yape_notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService.instance.initialize();
  } catch (error) {
    debugPrint('NotificationService.initialize(): $error');
  }

  try {
    await YapeNotificationService.instance.initialize();
  } catch (error) {
    debugPrint('YapeNotificationService.initialize(): $error');
  }

  runApp(const MotoCajaApp());
}

class MotoCajaApp extends StatelessWidget {
  const MotoCajaApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AppState()..load(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MotoCaja',
      theme: buildTheme(),
      home: const _Bootstrap(),
    ),
  );
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 950), () {
      if (mounted) {
        setState(() => _minimumSplashElapsed = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    Widget child;

    if (!_minimumSplashElapsed || !appState.loaded) {
      child = const StartupScreen(key: ValueKey('startup'));
    } else if (appState.loadError != null) {
      child = _StartupError(
        key: const ValueKey('startup-error'),
        message: appState.loadError!,
      );
    } else if (!appState.onboardingCompleted) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else {
      child = const MainShell(key: ValueKey('main-shell'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final scale = Tween<double>(begin: 0.985, end: 1).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

class _StartupError extends StatelessWidget {
  final String message;

  const _StartupError({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: AppColors.redSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 38,
                  color: AppColors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No se pudo iniciar MotoCaja',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
