import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'data/account_link_service.dart';
import 'data/budget_repository.dart';
import 'data/category_repository.dart';
import 'data/local_prefs.dart';
import 'data/supabase_account_link_service.dart';
import 'data/supabase_budget_repository.dart';
import 'data/supabase_category_repository.dart';
import 'data/supabase_transaction_repository.dart';
import 'data/transaction_repository.dart';
import 'screens/backup_prompt_screen.dart';
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
    accountLinkService: SupabaseAccountLinkService(Supabase.instance.client),
    localPrefs: LocalPrefs(),
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
    required this.accountLinkService,
    required this.localPrefs,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final AccountLinkService accountLinkService;
  final LocalPrefs localPrefs;

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
        accountLinkService: accountLinkService,
        localPrefs: localPrefs,
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
    required this.accountLinkService,
    required this.localPrefs,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final AccountLinkService accountLinkService;
  final LocalPrefs localPrefs;

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  bool _unlocked = false;
  // null: still checking the flag right after unlock; true: show the
  // one-time prompt; false: skip it (already seen, or just dismissed).
  bool? _showBackupPrompt;

  Future<void> _handleUnlock() async {
    setState(() => _unlocked = true);
    final alreadySeen = await widget.localPrefs.hasSeenBackupPrompt();
    if (!mounted) return;
    if (alreadySeen) {
      setState(() => _showBackupPrompt = false);
      return;
    }
    // Set the flag as soon as the prompt is about to be shown, not only
    // once it's dismissed, so a killed app mid-prompt doesn't re-show it
    // forever.
    await widget.localPrefs.setHasSeenBackupPrompt(true);
    if (!mounted) return;
    setState(() => _showBackupPrompt = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return LockScreen(
        onUnlock: _handleUnlock,
        onUsePasscode: _handleUnlock,
      );
    }
    if (_showBackupPrompt == null) {
      return const SizedBox.shrink();
    }
    if (_showBackupPrompt == true) {
      return BackupPromptScreen(
        accountLinkService: widget.accountLinkService,
        onDone: () => setState(() => _showBackupPrompt = false),
      );
    }
    return RootShell(
      categoryRepository: widget.categoryRepository,
      transactionRepository: widget.transactionRepository,
      budgetRepository: widget.budgetRepository,
    );
  }
}
