import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/db/app_database.dart';
import 'providers/app_providers.dart';
import 'screens/home_shell.dart';
import 'screens/lock_overlay_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase.ensureFfiInitialized();
  runApp(const ProviderScope(child: JimiBookkeepingApp()));
}

class JimiBookkeepingApp extends ConsumerWidget {
  const JimiBookkeepingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final g = state.activeTheme.config.globalStyle;

    return MaterialApp(
      title: '基米记账',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: g.primary,
          brightness: g.isDarkText ? Brightness.light : Brightness.dark,
        ),
      ),
      home: !state.isInitialized
          ? const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('正在初始化基米记账本地数据库...'),
                  ],
                ),
              ),
            )
          : state.needsOnboarding
              ? const OnboardingScreen()
              : state.isLockedForViewing
                  ? const LockOverlayScreen()
                  : const HomeShell(),
    );
  }
}
