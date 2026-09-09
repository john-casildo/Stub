import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'config/supabase_config.dart';
import 'data/account_link_service.dart';
import 'data/budget_repository.dart';
import 'data/category_repository.dart';
import 'data/device_auth_service.dart';
import 'data/local_auth_device_auth_service.dart';
import 'data/local_notifications_service.dart';
import 'data/local_prefs.dart';
import 'data/mlkit_text_recognition_service.dart';
import 'data/notification_service.dart';
import 'data/supabase_account_link_service.dart';
import 'data/supabase_budget_repository.dart';
import 'data/supabase_category_repository.dart';
import 'data/supabase_transaction_repository.dart';
import 'data/text_recognition_service.dart';
import 'data/transaction_repository.dart';
import 'data/weekly_summary_scheduler.dart';
import 'screens/backup_prompt_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/root_shell.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'theme/text.dart';
import 'util/currency.dart';
import 'widgets/stub_button.dart';
import 'widgets/stub_loading_indicator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StartupGate());
}

class _StartupResult {
  _StartupResult({
    required this.localPrefs,
    required this.themeModeNotifier,
    required this.currencyNotifier,
    required this.lockEnabledNotifier,
  });
  final LocalPrefs localPrefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<String> currencyNotifier;
  final ValueNotifier<bool> lockEnabledNotifier;
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
  final currencyCode = await localPrefs.currencyCode();
  CurrencyConfig.code = currencyCode;
  final currencyNotifier = ValueNotifier<String>(currencyCode);
  final lockEnabledNotifier = ValueNotifier<bool>(await localPrefs.lockEnabled());
  await _initWeeklySummary(localPrefs);
  return _StartupResult(
    localPrefs: localPrefs,
    themeModeNotifier: themeModeNotifier,
    currencyNotifier: currencyNotifier,
    lockEnabledNotifier: lockEnabledNotifier,
  );
}

Future<void> _ensureSession() async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    await client.auth.signInAnonymously();
  }
}

/// Initializes the background-task plugin (a no-op if the toggle has
/// never been turned on) and, if "Weekly summary" is already enabled
/// from a previous session, re-registers the periodic task — cheap and
/// idempotent, and protects against the OS having dropped the
/// registration (e.g. after a reinstall or OS update) while the
/// preference itself stayed on. A failure here must never block startup.
Future<void> _initWeeklySummary(LocalPrefs localPrefs) async {
  try {
    await Workmanager().initialize(weeklySummaryCallbackDispatcher);
    if (await localPrefs.weeklySummaryEnabled()) {
      await scheduleWeeklySummary();
    }
  } catch (_) {
    // Best-effort — the toggle stays available even if registration
    // failed; SettingsScreen re-attempts it the next time it's touched.
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
          return const _StartupScaffold(child: StubLoadingIndicator());
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
          currencyNotifier: result.currencyNotifier,
          lockEnabledNotifier: result.lockEnabledNotifier,
          textRecognitionService: MlKitTextRecognitionService(),
          deviceAuthService: LocalAuthDeviceAuthService(),
          notificationService: LocalNotificationsService(),
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

/// Shows the lock screen until unlocked via [DeviceAuthService] (real
/// biometric/passcode auth), then the real app. Re-locks immediately
/// whenever the app leaves the foreground, so backgrounding always
/// requires re-auth on return — the "kept private" promise on
/// [LockScreen] needs both halves (gate on entry, re-gate on return) to
/// be true. Devices with no biometric/passcode enrolled at all have
/// nothing to gate on, so they skip the lock screen entirely.
///
/// The lock screen is overlaid via `MaterialApp.builder`, which wraps the
/// *entire* Navigator (the home route plus anything `RootShell` has
/// pushed on top of it via that same shared Navigator) — not swapped in
/// as the home route's content. Swapping content in `home` would unmount
/// `RootShell` (and anything it pushed) every time the app re-locks,
/// which both crashed a pushed screen's now-stale `Navigator.of(context)`
/// closures and, worse, left the lock screen invisible behind whatever
/// route happened to be on top. Overlaying instead means `RootShell` and
/// its pushed screens stay mounted for the life of the app, and the lock
/// screen covers them regardless of navigation depth.
class StubApp extends StatefulWidget {
  const StubApp({
    super.key,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.budgetRepository,
    required this.accountLinkService,
    required this.localPrefs,
    required this.themeModeNotifier,
    required this.currencyNotifier,
    required this.lockEnabledNotifier,
    required this.textRecognitionService,
    required this.deviceAuthService,
    required this.notificationService,
  });

  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final BudgetRepository budgetRepository;
  final AccountLinkService accountLinkService;
  final LocalPrefs localPrefs;
  final ValueNotifier<ThemeMode> themeModeNotifier;
  final ValueNotifier<String> currencyNotifier;
  final ValueNotifier<bool> lockEnabledNotifier;
  final TextRecognitionService textRecognitionService;
  final DeviceAuthService deviceAuthService;
  final NotificationService notificationService;

  @override
  State<StubApp> createState() => _StubAppState();
}

class _StubAppState extends State<StubApp> with WidgetsBindingObserver {
  bool _unlocked = false;
  // null: still checking whether this device has any biometric/passcode
  // enrolled at all; true/false once known.
  bool? _supported;
  // null: still checking the flag right after unlock; true: show the
  // one-time prompt; false: skip it (already seen, or just dismissed).
  bool? _showBackupPrompt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.currencyNotifier.addListener(_syncCurrencyConfig);
    widget.lockEnabledNotifier.addListener(_onLockEnabledChanged);
    _checkSupport();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.currencyNotifier.removeListener(_syncCurrencyConfig);
    widget.lockEnabledNotifier.removeListener(_onLockEnabledChanged);
    super.dispose();
  }

  void _syncCurrencyConfig() {
    CurrencyConfig.code = widget.currencyNotifier.value;
  }

  /// Turning the lock off from Settings only hides the `LockScreen`
  /// overlay (via `_showLock`) — it doesn't by itself make `_buildHome()`
  /// render anything, since that's gated on `_handleUnlock()` having run
  /// (which also does the one-time backup-prompt bookkeeping). Without
  /// this, disabling the toggle while still sitting at the lock screen
  /// left the app on a blank screen instead of the ledger.
  void _onLockEnabledChanged() {
    if (!widget.lockEnabledNotifier.value && !_unlocked) {
      _handleUnlock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_unlocked || _supported != true) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      setState(() => _unlocked = false);
    }
  }

  Future<void> _checkSupport() async {
    bool supported = true;
    try {
      supported = await widget.deviceAuthService.isSupported();
    } catch (_) {
      // Can't tell — fail toward requiring auth rather than silently
      // granting access.
    }
    if (!mounted) return;
    setState(() => _supported = supported);
    if (!supported) await _handleUnlock();
  }

  Future<void> _handleUnlock() async {
    setState(() => _unlocked = true);
    // Backup-prompt bookkeeping only needs to run once, the first time
    // the app is ever unlocked — a later re-lock/re-unlock cycle
    // shouldn't re-show it.
    if (_showBackupPrompt != null) return;
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

  bool _showLock(bool lockEnabled) => _supported == true && !_unlocked && lockEnabled;

  Widget _buildHome() {
    // Nothing to show yet — either still checking device support, or
    // (before the very first unlock) _showBackupPrompt hasn't been
    // decided. Either way the lock overlay (or nothing, pre-_supported)
    // is covering this.
    if (_supported == null || _showBackupPrompt == null) {
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
      currencyNotifier: widget.currencyNotifier,
      lockEnabledNotifier: widget.lockEnabledNotifier,
      lockSupported: _supported == true,
      localPrefs: widget.localPrefs,
      textRecognitionService: widget.textRecognitionService,
      notificationService: widget.notificationService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: widget.themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'Stub',
        debugShowCheckedModeBanner: false,
        theme: StubTheme.light(),
        darkTheme: StubTheme.dark(),
        themeMode: mode,
        builder: (context, child) => ValueListenableBuilder<bool>(
          valueListenable: widget.lockEnabledNotifier,
          builder: (context, lockEnabled, _) {
            final showLock = _showLock(lockEnabled);
            return Stack(
              children: [
                if (child != null) IgnorePointer(ignoring: showLock, child: child),
                if (showLock)
                  LockScreen(
                    deviceAuthService: widget.deviceAuthService,
                    onUnlock: _handleUnlock,
                  ),
              ],
            );
          },
        ),
        home: _buildHome(),
      ),
    );
  }
}
