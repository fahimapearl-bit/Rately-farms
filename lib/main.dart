import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'auth_page.dart';
import 'home_dashboard.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const RatelyFarmsApp());
}

class RatelyFarmsApp extends StatelessWidget {
  const RatelyFarmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rately Farms',
      debugShowCheckedModeBanner: false,
      // Both themes now come from AppTheme, which reads AppColors and
      // registers the palette as a ThemeExtension.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AuthGate(child: HomeDashboardPage()),
    );
  }
}
