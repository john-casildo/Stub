import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'data/budget_repository.dart';
import 'data/category_repository.dart';
import 'data/supabase_budget_repository.dart';
import 'data/supabase_category_repository.dart';
import 'data/supabase_transaction_repository.dart';
import 'data/transaction_repository.dart';
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
  runApp(StubApp(
    categoryRepository: SupabaseCategoryRepository(Supabase.instance.client),
    transactionRepository: SupabaseTransactionRepository(Supabase.instance.client),
    budgetRepository: SupabaseBudgetRepository(Supabase.instance.client),
  ));
}

Future<void> _ensureSession() async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    await client.auth.signInAnonymously();
  }
}

class StubApp extends StatelessWidget {
  const StubApp({
    super.key,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.budgetRepository,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stub',
      debugShowCheckedModeBanner: false,
      theme: StubTheme.light(),
      darkTheme: StubTheme.dark(),
      themeMode: ThemeMode.system,
      home: _LockGate(
        categoryRepository: categoryRepository,
        transactionRepository: transactionRepository,
        budgetRepository: budgetRepository,
      ),
    );
  }
}

/// Shows the lock screen until unlocked, then the real app. Real Face
/// ID/biometric wiring (the `local_auth` package is already a dependency)
/// is separate follow-up work — this just gates on a boolean for now, so
/// the screen and the navigation shell are both real and testable before
/// that wiring exists.
class _LockGate extends StatefulWidget {
  const _LockGate({
    required this.categoryRepository,
    required this.transactionRepository,
    required this.budgetRepository,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  bool _unlocked = false;

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return RootShell(
        categoryRepository: widget.categoryRepository,
        transactionRepository: widget.transactionRepository,
        budgetRepository: widget.budgetRepository,
      );
    }
    return LockScreen(
      onUnlock: () => setState(() => _unlocked = true),
      onUsePasscode: () => setState(() => _unlocked = true),
    );
  }
}
