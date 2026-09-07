import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'data/account_link_service.dart';
import 'data/budget_repository.dart';
import 'data/category_repository.dart';
import 'data/local_prefs.dart';
import 'data/mlkit_text_recognition_service.dart';
import 'data/supabase_account_link_service.dart';
import 'data/supabase_budget_repository.dart';
import 'data/supabase_category_repository.dart';
import 'data/supabase_transaction_repository.dart';
import 'data/text_recognition_service.dart';
import 'data/transaction_repository.dart';
import 'screens/backup_prompt_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'theme/text.dart';
import 'widgets/stub_button.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StartupGate());
}

class _StartupResult {
  _StartupResult({required this.localPrefs, required this.themeModeNotifier});
  final LocalPrefs localPrefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
}

/// `Supabase.initialize` is safe to call more than once (it no-ops if
/// already initialized), so the whole bootstrap sequence can be retried
/// as one unit on failure.
Future<_StartupResult> _startup() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await _ensureSession();
  final localPrefs = LocalPrefs();
  final themeModeNotifier = ValueNotifier<ThemeMode>(await localPrefs.themeMode());
  return _StartupResult(localPrefs: localPrefs, themeModeNotifier: themeModeNotifier);
}

Future<void> _ensureSession() async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    await client.auth.signInAnonymously();
  }
}

/// Runs the real (network-dependent) startup sequence before the real app
/// exists to show anything — must never let a failure here (e.g. no
/// internet reaching Supabase) throw uncaught out of `main()`, which
/// would prevent `runApp` from ever being called and leave the OS
/// showing a blank white screen with no way to recover short of
/// force-quitting. Shows a loading state, then either the real `StubApp`
/// or a retry screen, same loading/error/retry shape as `RootShell`'s
/// own data-loading `FutureBuilder`.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late Future<_StartupResult> _future = _startup();

  void _retry() {
    setState(() {
      _future = _startup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupScaffold(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _StartupScaffold(child: _StartupError(onRetry: _retry));
        }
        final result = snapshot.data!;
        return StubApp(
          categoryRepository: SupabaseCategoryRepository(Supabase.instance.client),
          transactionRepository: SupabaseTransactionRepository(Supabase.instance.client),
          budgetRepository: SupabaseBudgetRepository(Supabase.instance.client),
          accountLinkService: SupabaseAccountLinkService(Supabase.instance.client),
          localPrefs: result.localPrefs,
          themeModeNotifier: result.themeModeNotifier,
          textRecognitionService: MlKitTextRecognitionService(),
        );
      },
    );
  }
}

/// A minimal themed `MaterialApp` for the loading/error states above —
/// the real `StubApp`'s `MaterialApp` (with the user's persisted theme
/// preference) doesn't exist yet at this point, so this uses the system
/// brightness instead.
class _StartupScaffold extends StatelessWidget {
  const _StartupScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: StubTheme.light(),
      darkTheme: StubTheme.dark(),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
            body: Center(child: child),
          );
        },
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Couldn't connect", style: StubText.archivo(fontSize: 16, fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 8),
          Text(
            'Check your internet connection and try again.',
            textAlign: TextAlign.center,
            style: StubText.archivo(fontSize: 14, color: ink.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          StubButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
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
    required this.themeModeNotifier,
    required this.textRecognitionService,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final AccountLinkService accountLinkService;
  final LocalPrefs localPrefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final TextRecognitionService textRecognitionService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'Stub',
        debugShowCheckedModeBanner: false,
        theme: StubTheme.light(),
        darkTheme: StubTheme.dark(),
        themeMode: mode,
        home: _LockGate(
          categoryRepository: categoryRepository,
          transactionRepository: transactionRepository,
          budgetRepository: budgetRepository,
          accountLinkService: accountLinkService,
          localPrefs: localPrefs,
          themeModeNotifier: themeModeNotifier,
          textRecognitionService: textRecognitionService,
        ),
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
    required this.themeModeNotifier,
    required this.textRecognitionService,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final AccountLinkService accountLinkService;
  final LocalPrefs localPrefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final TextRecognitionService textRecognitionService;

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
    bool showPrompt = false;
    try {
      final alreadySeen = await widget.localPrefs.hasSeenBackupPrompt();
      if (!alreadySeen) {
        // Set the flag as soon as the prompt is about to be shown, not
        // only once it's dismissed, so a killed app mid-prompt doesn't
        // re-show it forever.
        await widget.localPrefs.setHasSeenBackupPrompt(true);
        showPrompt = true;
      }
    } catch (_) {
      // A broken local-prefs read/write must never strand the app on a
      // blank screen — fall through to RootShell instead.
    }
    if (!mounted) return;
    setState(() => _showBackupPrompt = showPrompt);
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
      accountLinkService: widget.accountLinkService,
      themeModeNotifier: widget.themeModeNotifier,
      localPrefs: widget.localPrefs,
      textRecognitionService: widget.textRecognitionService,
    );
  }
}
