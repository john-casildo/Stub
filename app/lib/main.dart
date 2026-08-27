import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/lock_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await _ensureSession();
  runApp(const StubApp());
}

Future<void> _ensureSession() async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    await client.auth.signInAnonymously();
  }
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
      home: const _LockGate(),
    );
  }
}

/// Shows the lock screen until unlocked, then the real app. Real Face
/// ID/biometric wiring (the `local_auth` package is already a dependency)
/// is separate follow-up work — this just gates on a boolean for now, so
/// the screen and the navigation shell are both real and testable before
/// that wiring exists.
class _LockGate extends StatefulWidget {
  const _LockGate();

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return const RootShell();
    return LockScreen(
      onUnlock: () => setState(() => _unlocked = true),
      onUsePasscode: () => setState(() => _unlocked = true),
    );
  }
}
