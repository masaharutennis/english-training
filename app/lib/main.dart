import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'utils/env_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (EnvConfig.hasSupabase) {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrlResolved,
      anonKey: EnvConfig.supabaseAnonKeyResolved,
    );
  }
  runApp(const EnglishTrainingApp());
}

/// Google Fonts の **Noto Sans JP**（Noto Sans ファミリー）で `textTheme` / `fontFamily` を明示する。
/// 日本語 UI と欧文の両方をカバーする。
ThemeData _appTheme(ColorScheme colorScheme) {
  final base = ThemeData(brightness: colorScheme.brightness, useMaterial3: true);
  final noto = GoogleFonts.notoSansJpTextTheme(base.textTheme).apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: noto,
    fontFamily: GoogleFonts.notoSansJp().fontFamily,
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class EnglishTrainingApp extends StatelessWidget {
  const EnglishTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1B5E6B);
    final lightScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
    final darkScheme = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);

    return MaterialApp(
      title: '瞬間英作文',
      debugShowCheckedModeBanner: false,
      theme: _appTheme(lightScheme),
      darkTheme: _appTheme(darkScheme),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
