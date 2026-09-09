import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import '../config/supabase_config.dart';
import '../models/transaction.dart';
import '../util/weekly_summary.dart';
import 'local_notifications_service.dart';

/// Must match `ios/Runner/Info.plist`'s `BGTaskSchedulerPermittedIdentifiers`
/// entry — iOS refuses to run a background task whose identifier wasn't
/// declared there.
const weeklySummaryTaskName = 'com.stubapp.stub.weeklySummary';
const _weeklySummaryUniqueName = 'weekly_summary';

/// Registers the periodic weekly-summary background task — call once from
/// Settings' "Weekly summary" toggle when turned on, and once at app
/// startup if the toggle is already enabled (idempotent by unique name,
/// so re-registering on every launch is safe — it also protects against
/// the OS having silently dropped the registration, e.g. after a
/// reinstall or OS update).
///
/// `initialDelay` only aims the *first* fire at the next Sunday 6pm local
/// time — after that, neither iOS's `BGTaskScheduler` nor Android's
/// `WorkManager` guarantee exact-clock-time firing on a `frequency`-based
/// periodic task; the OS runs it opportunistically based on device usage,
/// battery, and charging state. See CLAUDE.md's Open Items for what that
/// means in practice.
Future<void> scheduleWeeklySummary() => Workmanager().registerPeriodicTask(
      _weeklySummaryUniqueName,
      weeklySummaryTaskName,
      frequency: const Duration(days: 7),
      initialDelay: _delayUntilNextSunday6pm(),
    );

Future<void> cancelWeeklySummary() => Workmanager().cancelByUniqueName(_weeklySummaryUniqueName);

Duration _delayUntilNextSunday6pm() {
  final now = DateTime.now();
  var target = DateTime(now.year, now.month, now.day, 18);
  final daysUntilSunday = (DateTime.sunday - now.weekday) % 7;
  target = target.add(Duration(days: daysUntilSunday));
  if (!target.isAfter(now)) target = target.add(const Duration(days: 7));
  return target.difference(now);
}

/// Must be a top-level (or static) function — passed to
/// `Workmanager().initialize` once in `main.dart`. Runs in a fresh
/// background isolate with none of the running app's state (no existing
/// `Supabase.instance`, no widget tree), so it re-initializes Supabase
/// from scratch; the previously-signed-in session is restored from the
/// device's local storage automatically, the same way a normal cold app
/// start restores it. No automated test — needs a real background
/// execution environment, which nothing short of a physical device
/// running for real can exercise; verify manually.
@pragma('vm:entry-point')
void weeklySummaryCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != weeklySummaryTaskName) return true;
    try {
      await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return true; // not signed in — nothing to summarize
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final rows = await client
          .from('transactions')
          .select('amount, occurred_at, category_id, categories(name)')
          .gte('occurred_at', weekAgo.toIso8601String());
      final transactions = [
        for (final row in rows)
          Transaction.fromRow(
            row,
            categoryName: (row['categories'] as Map<String, dynamic>?)?['name'] as String? ?? '',
          ),
      ];
      final summary = computeWeeklySummary(transactions);
      if (summary == null) return true; // no spending this week — nothing to say
      await LocalNotificationsService().show(title: 'Weekly summary', body: weeklySummaryMessage(summary));
    } catch (_) {
      // Best-effort — a failure here must not throw out of the background
      // isolate in a way the OS could penalize the app for.
    }
    return true;
  });
}
