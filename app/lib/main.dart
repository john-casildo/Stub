import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'theme/app_theme.dart';
import 'theme/text.dart';
import 'widgets/stub_button.dart';
import 'widgets/stub_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const StubApp());
}

class StubApp extends StatelessWidget {
  const StubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stub',
      debugShowCheckedModeBanner: false,
      theme: StubTheme.light(),
      darkTheme: StubTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _ThemeCheckScreen(),
    );
  }
}

/// Temporary home screen — just proves the theme, fonts, and StubButton
/// component are wired correctly end to end. Replace with the real ledger
/// screen once the mockup's screens are ported over one by one.
class _ThemeCheckScreen extends StatelessWidget {
  const _ThemeCheckScreen();

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const StubLogo(size: 40),
                  const SizedBox(width: 10),
                  Text('Stub', style: StubText.domine(fontSize: 32, color: ink)),
                ],
              ),
              const SizedBox(height: 8),
              Text('\$1,842.30', style: StubText.unbounded(fontSize: 28, color: ink)),
              const SizedBox(height: 32),
              StubButton(label: 'Add to ledger', onPressed: () {}),
              const SizedBox(height: 12),
              StubButton(label: 'Save changes', variant: StubButtonVariant.save, onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}
