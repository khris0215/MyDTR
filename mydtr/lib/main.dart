import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'data/dtr_database.dart';
import 'notifiers/dtr_provider.dart';
import 'ui/home_page.dart';

const Color _brandPrimary = Color(0xFF2B82FF);
const Color _surfaceDeep = Color(0xFF050B1A);
const Color _surfaceCard = Color(0xFF101B32);
const Color _accentMint = Color(0xFF2DD4BF);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DtrDatabase.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseDark = ThemeData.dark();
    final textTheme = GoogleFonts.spaceGroteskTextTheme(
      baseDark.textTheme,
    ).apply(bodyColor: Colors.white, displayColor: Colors.white);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandPrimary,
      brightness: Brightness.dark,
      primary: _brandPrimary,
      secondary: _accentMint,
      surface: _surfaceCard,
    );

    return ChangeNotifierProvider(
      create: (_) => DtrProvider(DtrDatabase.instance)..bootstrap(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'My DTR',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _surfaceDeep,
          colorScheme: colorScheme,
          textTheme: textTheme,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: _surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            margin: EdgeInsets.zero,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              textStyle: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(28),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withAlpha(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            labelStyle: textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
        home: const HomePage(),
      ),
    );
  }
}
