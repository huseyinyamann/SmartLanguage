import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/sign_in_screen.dart';
import 'features/onboarding/language_select_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/shell/splash_screen.dart';
import 'providers.dart';
import 'theme/app_theme.dart';

class PrektaApp extends StatelessWidget {
  const PrektaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prekta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AppRoot(),
    );
  }
}

/// Oturum ve dil seçimi durumuna göre kök ekranı belirler.
class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      loading: () => const SplashScreen(),
      error: (e, _) => SplashScreen(error: '$e'),
      data: (user) {
        if (user == null) return const SignInScreen();

        final appUser = ref.watch(appUserProvider);
        return appUser.when(
          loading: () => const SplashScreen(),
          error: (e, _) => SplashScreen(error: '$e'),
          data: (profile) => profile?.hasChosenLanguage ?? false
              ? const MainShell()
              : const LanguageSelectScreen(),
        );
      },
    );
  }
}
