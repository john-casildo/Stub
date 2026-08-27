# Account Linking (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the anonymous session created in Phase 1 a path to a real, recoverable identity via email, without ever requiring it and without losing any existing data.

**Architecture:** A one-time full-screen prompt shown after first unlock, plus a reusable 4-provider linking widget (Email active, Apple/Google/Phone visibly disabled) that Profile's Account section will reuse later. Email linking calls Supabase's `updateUser(email:)` on the existing anonymous session — same `auth.uid()`, zero data migration — with a custom-URL-scheme deep link so the app detects confirmation via `onAuthStateChange`.

**Tech Stack:** Flutter/Dart, `supabase_flutter` (already a dependency), new dependencies `shared_preferences` (local flag persistence) and `app_links` (deep-link listening — `supabase_flutter` uses it internally but the app still owns the platform-level URL-scheme registration).

**Spec:** `docs/superpowers/specs/2026-08-27-account-linking-phase2-design.md`

## Out of scope for this plan

Profile's "Account" section (from `docs/superpowers/specs/2026-08-27-profile-and-settings-design.md`) is **not** built here — the Profile screen itself doesn't exist yet. This plan only builds the one-time prompt and the reusable pieces (`AccountLinkService`, `StubProviderRow`) that Profile's Account section will reuse once it's implemented next. "Always reachable via Profile if skipped" (from the design spec) becomes true only after that follow-on work, not from this plan alone.

## Global Constraints

- Only Email is functional this phase. Apple/Google/Phone are visibly disabled ("Coming soon") rows — do not wire real behavior for them.
- The upgrade must preserve `auth.uid()` — never create a second/separate account. This is what `updateUser(email:)` on the existing session does; do not use `signUp`/`signInWithPassword`, which would create a new identity.
- The custom URL scheme is `com.stubapp.stub` (matches the app's real bundle id, `com.stubapp.stub`, confirmed in `ios/Runner.xcodeproj/project.pbxproj`) — used as `com.stubapp.stub://login-callback`.
- The one-time prompt must never show twice automatically — tracked via a local flag, not a per-session check.
- `flutter analyze` clean and the full `flutter test` suite green before every commit, matching this project's existing standard.
- Deep-link completion cannot be exercised by an automated widget test (it requires a real device, a real email, and tapping a real link) — those parts of this plan get a manual-verification step instead of a test, following the same pattern already used in this project's Supabase-backed repository tasks.

---

### Task 1: Local preference flag (shown-backup-prompt)

**Files:**
- Create: `app/lib/data/local_prefs.dart`
- Test: `app/test/data/local_prefs_test.dart`

**Interfaces:**
- Produces: `LocalPrefs` with `Future<bool> hasSeenBackupPrompt()` and `Future<void> setHasSeenBackupPrompt(bool value)`.
- Consumes: `shared_preferences` (new dependency).

- [ ] **Step 1: Add the dependency**

```bash
cd app
flutter pub add shared_preferences
```

(Never hand-edit the version into `pubspec.yaml` — let `pub add` resolve the real current version, per this project's own convention.)

- [ ] **Step 2: Write the failing test**

```dart
// app/test/data/local_prefs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stub/data/local_prefs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hasSeenBackupPrompt defaults to false, then persists true after being set', () async {
    final prefs = LocalPrefs();
    expect(await prefs.hasSeenBackupPrompt(), isFalse);

    await prefs.setHasSeenBackupPrompt(true);
    expect(await prefs.hasSeenBackupPrompt(), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/data/local_prefs_test.dart
```

Expected: FAIL — `LocalPrefs` doesn't exist yet.

- [ ] **Step 3: Implement**

```dart
// app/lib/data/local_prefs.dart
import 'package:shared_preferences/shared_preferences.dart';

/// Local, per-device UI preferences — never financial data, never synced
/// through Supabase. See DESIGN spec: theme + the one-time backup-prompt
/// flag both belong here.
class LocalPrefs {
  static const _hasSeenBackupPromptKey = 'has_seen_backup_prompt';

  Future<bool> hasSeenBackupPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenBackupPromptKey) ?? false;
  }

  Future<void> setHasSeenBackupPrompt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenBackupPromptKey, value);
  }
}
```

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/data/local_prefs_test.dart && flutter analyze
git add pubspec.yaml pubspec.lock lib/data/local_prefs.dart test/data/local_prefs_test.dart
git commit -m "feat: add LocalPrefs for the one-time backup-prompt flag"
```

---

### Task 2: iOS deep-link scheme registration

**Files:**
- Modify: `app/ios/Runner/Info.plist`
- Modify: `app/pubspec.yaml` (add `app_links`)

**Interfaces:** none (native config + a dependency; no Dart API surface yet — Task 6 is where it's actually used).

This task has no automated test — it's platform configuration, verified manually on a real device in Task 6 once there's something to test end-to-end.

- [ ] **Step 1: Add the `app_links` dependency**

```bash
cd app
flutter pub add app_links
```

- [ ] **Step 2: Register the custom URL scheme**

Open `app/ios/Runner/Info.plist` and add (as a sibling of the existing top-level keys, inside the outer `<dict>`):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.stubapp.stub</string>
    </array>
  </dict>
</array>
```

If `CFBundleURLTypes` already exists in the file for some other reason, add this scheme to its existing array instead of creating a duplicate key — read the file first to check.

- [ ] **Step 3: Add the same redirect URL in the Supabase dashboard**

This is a live-project configuration step, not a code change — via the Supabase CLI (matching this project's existing `supabase config push` workflow): add `com.stubapp.stub://login-callback` to `app/supabase/config.toml`'s `auth.additional_redirect_urls` list, then `supabase config push`. **Read the existing list first** — `additional_redirect_urls` was deliberately restored to `[]` during the real-data-foundation work after an earlier accidental broad overwrite; add this one entry to that empty list, don't replace the whole `[auth]` block, and don't touch any other setting in that section. Verify afterward with `supabase config push` again immediately — it should report "up to date" with no further diff.

- [ ] **Step 4: `flutter analyze`, commit**

```
cd app && flutter analyze
git add ios/Runner/Info.plist pubspec.yaml pubspec.lock ../app/supabase/config.toml
git commit -m "feat: register the com.stubapp.stub:// deep-link scheme for email-link auth"
```

(Adjust the `git add` paths to match the actual repo-root-relative locations — `app/supabase/config.toml`, not `../app/...`, when run from the repo root rather than `app/`.)

---

### Task 3: AccountLinkService — interface, Supabase implementation, fake

**Files:**
- Create: `app/lib/data/account_link_service.dart`
- Create: `app/lib/data/supabase_account_link_service.dart`
- Modify: `app/lib/data/fakes.dart` (add `FakeAccountLinkService`)
- Test: `app/test/data/fakes_test.dart` (extend existing file)

**Interfaces:**
- Produces: `abstract class AccountLinkService { bool get isAnonymous; String? get linkedEmail; Future<void> linkEmail(String email); Stream<bool> get linkStatusChanges; }` — `linkStatusChanges` emits the new `isAnonymous` value whenever Supabase's auth state changes, so UI can react without polling.
- Consumes: `supabase_flutter`'s `SupabaseClient`, `User.isAnonymous` (confirm this field's exact name against the installed package version before writing — see Step 1).

**Before writing any code**: verify the exact `User` model field for anonymous status against the installed `supabase_flutter`/`gotrue` package source (find it via `find ~/.pub-cache -path '*gotrue*/lib/src/types/user.dart'` or equivalent, or `flutter pub deps` to locate the resolved version's source) — this project's earlier session already confirmed via a live REST call that Supabase's JWT carries `"is_anonymous":true`, but confirm the Dart-side `User` class actually exposes this as `isAnonymous` (not a differently-cased or differently-named field) before using it. If it's named differently, use the real name and note the deviation in your report.

- [ ] **Step 1: Write the failing test** (for the fake — the Supabase-backed implementation is verified per this project's established pattern: `flutter analyze` + a manual/scripted smoke test against the real project, not an automated network test)

```dart
// Add to app/test/data/fakes_test.dart
import 'package:stub/data/account_link_service.dart';

// ... inside main():

test('FakeAccountLinkService starts anonymous and can link an email', () async {
  final service = FakeAccountLinkService();
  expect(service.isAnonymous, isTrue);
  expect(service.linkedEmail, isNull);

  await service.linkEmail('me@example.com');

  expect(service.isAnonymous, isFalse);
  expect(service.linkedEmail, 'me@example.com');
});

test('FakeAccountLinkService.linkStatusChanges emits after linking', () async {
  final service = FakeAccountLinkService();
  final events = <bool>[];
  final sub = service.linkStatusChanges.listen(events.add);

  await service.linkEmail('me@example.com');
  await Future<void>.delayed(Duration.zero); // let the stream deliver

  expect(events, [false]); // isAnonymous became false
  await sub.cancel();
});
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/data/fakes_test.dart
```

- [ ] **Step 3: Implement the interface**

```dart
// app/lib/data/account_link_service.dart
abstract class AccountLinkService {
  bool get isAnonymous;
  String? get linkedEmail;
  Future<void> linkEmail(String email);

  /// Emits the new `isAnonymous` value whenever the underlying auth
  /// state changes (e.g. after the user completes an email-link
  /// confirmation) — lets UI react without polling.
  Stream<bool> get linkStatusChanges;
}
```

- [ ] **Step 4: Implement the Supabase-backed version**

```dart
// app/lib/data/supabase_account_link_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_link_service.dart';

class SupabaseAccountLinkService implements AccountLinkService {
  SupabaseAccountLinkService(this._client);
  final SupabaseClient _client;

  @override
  bool get isAnonymous => _client.auth.currentUser?.isAnonymous ?? true;

  @override
  String? get linkedEmail {
    final email = _client.auth.currentUser?.email;
    return (email == null || email.isEmpty) ? null : email;
  }

  @override
  Future<void> linkEmail(String email) async {
    await _client.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: 'com.stubapp.stub://login-callback',
    );
  }

  @override
  Stream<bool> get linkStatusChanges =>
      _client.auth.onAuthStateChange.map((_) => isAnonymous);
}
```

- [ ] **Step 5: Implement the fake**

```dart
// Add to app/lib/data/fakes.dart
import 'dart:async';
import 'account_link_service.dart';

class FakeAccountLinkService implements AccountLinkService {
  FakeAccountLinkService({bool isAnonymous = true, this.linkedEmail}) : _isAnonymous = isAnonymous;
  bool _isAnonymous;
  @override
  String? linkedEmail;

  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  Future<void> linkEmail(String email) async {
    linkedEmail = email;
    _isAnonymous = false;
    _controller.add(_isAnonymous);
  }

  @override
  Stream<bool> get linkStatusChanges => _controller.stream;
}
```

(Add the necessary imports at the top of `fakes.dart` alongside the existing ones — don't duplicate an existing `dart:async` import if one is already there for another reason.)

- [ ] **Step 6: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/data/fakes_test.dart && flutter analyze
git add lib/data/account_link_service.dart lib/data/supabase_account_link_service.dart lib/data/fakes.dart test/data/fakes_test.dart
git commit -m "feat: add AccountLinkService (interface, Supabase impl, fake)"
```

---

### Task 4: New icons — mail, Apple, Google, phone

**Files:**
- Modify: `app/lib/widgets/stub_icon.dart`
- Test: `app/test/widgets/stub_icon_test.dart` (extend existing file)

**Interfaces:**
- Produces: 4 new `StubIcons` entries — `mail`, `brandApple`, `brandGoogle`, `phone`.

Per this project's established pattern (see the existing `StubIcons` doc comment and CLAUDE.md), these must be **exact** Tabler Icons SVG path data — fetch the real source, do not approximate or draw from memory. Get the exact `<path>` data for `mail`, `brand-apple`, `brand-google`, and `phone` from Tabler's icon set (e.g. https://tabler.io/icons or the `@tabler/icons-svg` package source) at the same 24x24 viewBox / stroke-based style as every existing entry in this file (`stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"`).

- [ ] **Step 1: Write the failing test**

```dart
// Add to app/test/widgets/stub_icon_test.dart — follow the existing test's
// exact pattern (it renders one icon and checks for an SvgPicture), just
// parameterized differently or as additional standalone tests:

testWidgets('StubIcons has mail, brandApple, brandGoogle, and phone', (tester) async {
  for (final icon in [StubIcons.mail, StubIcons.brandApple, StubIcons.brandGoogle, StubIcons.phone]) {
    await tester.pumpWidget(MaterialApp(home: Center(child: StubIcon(icon, color: Colors.black))));
    expect(find.byType(SvgPicture), findsOneWidget);
  }
});
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/widgets/stub_icon_test.dart
```

- [ ] **Step 3: Add the 4 new entries to `StubIcons`** in `app/lib/widgets/stub_icon.dart`, following the exact style of the existing entries (each a `static const` raw SVG string). Source the real path data as described above rather than inventing it.

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/widgets/stub_icon_test.dart && flutter analyze
git add lib/widgets/stub_icon.dart test/widgets/stub_icon_test.dart
git commit -m "feat: add mail/brandApple/brandGoogle/phone icons to StubIcons"
```

---

### Task 5: StubProviderRow widget

**Files:**
- Create: `app/lib/widgets/stub_provider_row.dart`
- Test: `app/test/widgets/stub_provider_row_test.dart`

**Interfaces:**
- Produces: `StubProviderRow({required String icon, required String label, required bool enabled, VoidCallback? onTap})` — a tappable row (icon + label) when `enabled`, a visibly-disabled row (reduced opacity, a trailing "Coming soon" tag, no tap response) when not. Shared between `BackupPromptScreen` (Task 6) and Profile's Account section (built later, in the Profile & Settings implementation).
- Consumes: `StubIcon`/`StubIcons` (existing), `StubPressable` (existing — reuse it for the enabled case's press feedback, per this project's "one definition per UI pattern" rule).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/widgets/stub_provider_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/widgets/stub_icon.dart';
import 'package:stub/widgets/stub_provider_row.dart';

void main() {
  testWidgets('StubProviderRow reports taps when enabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Center(child: StubProviderRow(
      icon: StubIcons.mail,
      label: 'Email',
      enabled: true,
      onTap: () => tapped = true,
    ))));

    await tester.tap(find.text('Email'));
    expect(tapped, isTrue);
    expect(find.text('Coming soon'), findsNothing);
  });

  testWidgets('StubProviderRow shows a Coming soon tag and ignores taps when disabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(home: Center(child: StubProviderRow(
      icon: StubIcons.brandApple,
      label: 'Apple',
      enabled: false,
      onTap: () => tapped = true,
    ))));

    expect(find.text('Coming soon'), findsOneWidget);
    await tester.tap(find.text('Apple'));
    expect(tapped, isFalse);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/widgets/stub_provider_row_test.dart
```

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_icon.dart';
import 'stub_pressable.dart';

class StubProviderRow extends StatelessWidget {
  const StubProviderRow({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
  });

  final String icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final color = enabled ? ink : ink.withValues(alpha: 0.3);

    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          StubIcon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: color))),
          if (!enabled)
            Text('Coming soon', style: StubText.archivo(fontSize: 12, color: ink.withValues(alpha: 0.4))),
        ],
      ),
    );

    if (!enabled) return row;
    return StubPressable(onTap: onTap, child: row);
  }
}
```

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/widgets/stub_provider_row_test.dart && flutter analyze
git add lib/widgets/stub_provider_row.dart test/widgets/stub_provider_row_test.dart
git commit -m "feat: add StubProviderRow widget"
```

---

### Task 6: BackupPromptScreen

**Files:**
- Create: `app/lib/screens/backup_prompt_screen.dart`
- Test: `app/test/screens/backup_prompt_screen_test.dart`

**Interfaces:**
- Produces: `BackupPromptScreen({required AccountLinkService accountLinkService, required VoidCallback onDone})` — full screen, 4 `StubProviderRow`s (Email enabled, Apple/Google/Phone disabled), an email-entry sub-flow when Email is tapped, and a prominent "Skip" action. Calls `onDone` when the user skips or submits an email (the screen's job is just to collect the email and call the service — it does not need to wait for confirmation to call `onDone`, since confirmation happens later, out-of-band, via the email link).
- Consumes: `AccountLinkService` (Task 3), `StubProviderRow` (Task 5), `StubIcons` (Task 4).

- [ ] **Step 1: Write the failing test**

```dart
// app/test/screens/backup_prompt_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/screens/backup_prompt_screen.dart';

void main() {
  testWidgets('Tapping Skip calls onDone without linking anything', (tester) async {
    var done = false;
    final service = FakeAccountLinkService();

    await tester.pumpWidget(MaterialApp(home: BackupPromptScreen(
      accountLinkService: service,
      onDone: () => done = true,
    )));

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(done, isTrue);
    expect(service.linkedEmail, isNull);
  });

  testWidgets('Tapping Email, entering an address, and submitting links it and calls onDone', (tester) async {
    var done = false;
    final service = FakeAccountLinkService();

    await tester.pumpWidget(MaterialApp(home: BackupPromptScreen(
      accountLinkService: service,
      onDone: () => done = true,
    )));

    await tester.tap(find.text('Email'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'me@example.com');
    await tester.tap(find.text('Send link'));
    await tester.pump();

    expect(service.linkedEmail, 'me@example.com');
    expect(done, isTrue);
  });

  testWidgets('Apple/Google/Phone rows are disabled and do nothing when tapped', (tester) async {
    final service = FakeAccountLinkService();
    await tester.pumpWidget(MaterialApp(home: BackupPromptScreen(
      accountLinkService: service,
      onDone: () {},
    )));

    await tester.tap(find.text('Apple'));
    await tester.pump();
    expect(service.linkedEmail, isNull);
    expect(find.text('Send link'), findsNothing); // no email sub-flow opened
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```
cd app && flutter test test/screens/backup_prompt_screen_test.dart
```

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import '../data/account_link_service.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_provider_row.dart';

class BackupPromptScreen extends StatefulWidget {
  const BackupPromptScreen({super.key, required this.accountLinkService, required this.onDone});

  final AccountLinkService accountLinkService;
  final VoidCallback onDone;

  @override
  State<BackupPromptScreen> createState() => _BackupPromptScreenState();
}

class _BackupPromptScreenState extends State<BackupPromptScreen> {
  bool _showEmailField = false;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    await widget.accountLinkService.linkEmail(email);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Back up your data', style: StubText.domine(fontSize: 22, color: ink)),
              const SizedBox(height: 8),
              Text(
                "Optional — link an identity so your ledger survives a reinstall or a new phone.",
                style: StubText.archivo(fontSize: 14, color: ink.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 24),
              StubProviderRow(icon: StubIcons.mail, label: 'Email', enabled: true, onTap: () => setState(() => _showEmailField = true)),
              StubProviderRow(icon: StubIcons.brandApple, label: 'Apple', enabled: false),
              StubProviderRow(icon: StubIcons.brandGoogle, label: 'Google', enabled: false),
              StubProviderRow(icon: StubIcons.phone, label: 'Phone', enabled: false),
              if (_showEmailField) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address'),
                ),
                const SizedBox(height: 12),
                StubButton(label: 'Send link', onPressed: _submitEmail),
              ],
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: widget.onDone,
                  child: Text('Skip', style: StubText.archivo(fontSize: 14, color: ink.withValues(alpha: 0.5))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests, `flutter analyze`, commit**

```
cd app && flutter test test/screens/backup_prompt_screen_test.dart && flutter analyze
git add lib/screens/backup_prompt_screen.dart test/screens/backup_prompt_screen_test.dart
git commit -m "feat: add BackupPromptScreen"
```

---

### Task 7: Wire the one-time prompt into the lock-gate flow

**Files:**
- Modify: `app/lib/main.dart`
- Test: `app/test/widget_test.dart` (extend existing file)

**Interfaces:**
- Consumes: `LocalPrefs` (Task 1), `AccountLinkService`/`SupabaseAccountLinkService` (Task 3), `BackupPromptScreen` (Task 6).
- `_LockGate` (or wherever this plan's implementer finds the actual unlock transition — read `main.dart` first) gains the logic: after `_unlocked` becomes true, check `LocalPrefs.hasSeenBackupPrompt()`; if false, show `BackupPromptScreen` (setting the flag true immediately when it's shown, not only when dismissed, so a killed app mid-prompt doesn't re-show it forever); once its `onDone` fires (or if the flag was already true), proceed to `RootShell` as before.

- [ ] **Step 1: Read `main.dart`'s current structure**

This step has no prescriptive code — read the file first (it changed shape across the real-data-foundation work: `StubApp`/`_LockGate` now thread 3 repositories through to `RootShell`) rather than guessing its current form.

- [ ] **Step 2: Write the failing test**

Extend `app/test/widget_test.dart`'s existing boot-and-unlock test, or add a new one, covering: after unlocking with `LocalPrefs.hasSeenBackupPrompt()` false (the default with `SharedPreferences.setMockInitialValues({})`), the backup prompt appears (`find.text('Back up your data')`) before Ledger content; tapping Skip reveals Ledger content (`find.text('LEFT TO SPEND')`).

```dart
// In app/test/widget_test.dart, add near the top of main():
setUp(() {
  SharedPreferences.setMockInitialValues({});
});

// New test:
testWidgets('First unlock shows the backup prompt before the ledger; skipping continues past it', (tester) async {
  await tester.pumpWidget(const StubApp(
    categoryRepository: FakeCategoryRepository(),
    transactionRepository: FakeTransactionRepository(),
    budgetRepository: FakeBudgetRepository(),
    // whatever accountLinkService param this task's changes add —
    // match the actual constructor shape after Step 3 below
  ));

  await tester.tap(find.text('Unlock with Face ID'));
  await tester.pump();

  expect(find.text('Back up your data'), findsOneWidget);

  await tester.tap(find.text('Skip'));
  await tester.pump();

  expect(find.text('LEFT TO SPEND'), findsOneWidget);
});
```

(The exact required constructor parameters depend on how `StubApp`/`_LockGate` end up threading `AccountLinkService` through — follow the same pattern already used for the 3 data repositories, and update the plan's own sketch above to match whatever you actually build, noting the difference in your report if the shape differs from this sketch.)

- [ ] **Step 3: Run to verify it fails**

```
cd app && flutter test test/widget_test.dart
```

- [ ] **Step 4: Implement**

Thread `AccountLinkService` (and an injectable `LocalPrefs`) through `StubApp`/`_LockGate` the same way `categoryRepository`/`transactionRepository`/`budgetRepository` already are. In `_LockGateState`, after unlock, check the flag and conditionally show `BackupPromptScreen` before falling through to `RootShell`. At the real `main()` call site, construct `SupabaseAccountLinkService(Supabase.instance.client)` and a real `LocalPrefs()`, matching how the 3 repositories are already constructed there.

- [ ] **Step 5: Run tests, `flutter analyze`**

```
cd app && flutter test && flutter analyze
```

Fix any other call site this change's constructor signature affects (e.g. anywhere else `StubApp`/`_LockGate` might be constructed) — expected, mechanical work.

- [ ] **Step 6: Manual verification (cannot be automated)**

On a physical device (per this project's established pattern for anything needing real Supabase auth/network): fresh install (or manually clear the app's local storage) → unlock → confirm the backup prompt appears → tap Email → enter a real email you control → confirm a Supabase confirmation email arrives → tap its link → confirm it opens the app (not just a browser) via the `com.stubapp.stub://` scheme → confirm `SupabaseAccountLinkService.isAnonymous` becomes `false` (e.g. via a temporary debug print, removed before committing) once the app resumes. Record the result in your report — this is real infrastructure that only a live run can verify, following the same "manual smoke test" pattern used for this project's Supabase-backed repositories.

- [ ] **Step 7: Commit**

```
cd app && git add lib/main.dart test/widget_test.dart
git commit -m "feat: show the one-time backup prompt after first unlock"
```
