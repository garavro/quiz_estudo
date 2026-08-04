import 'nova_senha_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'autenticacao.dart';
import 'menu_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class AppConfig {
  static const String supabaseUrl = 'https://ojkkstibwifhbplakjfw.supabase.co';

  static const String supabaseAnonKey =
      'sb_publishable_-hhQBjLfzt7GhINAq1CLxA_-kjpJNyq';
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;

    if (event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NovaSenhaScreen()),
      );
    }
  });

  runApp(const QuizApp());
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,

          debugShowCheckedModeBanner: false,
          title: 'Olimpíada de Matemática',

          themeMode: mode,

          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),

          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),

          builder: (context, child) {
            return Stack(
              children: [
                ?child,

                Positioned(
                  bottom: 20,
                  left: 20,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.7,
                      child: Image.asset(
                        'assets/logo.png',
                        width: 50,
                        height: 50,
                        errorBuilder: (_, _, _) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },

          home: session != null ? const MenuScreen() : const LoginScreen(),
        );
      },
    );
  }
}
