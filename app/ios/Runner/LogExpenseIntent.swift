import AppIntents
import UIKit

/// A Shortcuts-discoverable action that quick-logs an expense into Stub.
///
/// It doesn't write anything itself — it opens the app's own deep link
/// (`com.stubapp.stub://log-expense?amount=...&merchant=...`, the scheme
/// registered under `CFBundleURLSchemes` in `Info.plist`), which the Dart
/// side (`DeepLinkService` → `RootShell` → `ManualEntryScreen`) already
/// handles by opening a pre-filled manual-entry form for human review.
///
/// Deliberately uses the deprecated-in-iOS-26 `openAppWhenRun` rather than
/// its replacement `supportedModes` (`IntentModes`), because `IntentModes`
/// is iOS 26.0+ only and this target deploys to iOS 16.0.
///
/// No `@available` annotation is needed: the App Intents framework is
/// iOS 16.0+ and this target's `IPHONEOS_DEPLOYMENT_TARGET` is already 16.0.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense to Stub"

    static var description = IntentDescription(
        "Opens Stub with a new expense pre-filled, ready to review and save."
    )

    /// Bring Stub to the foreground when this intent runs, so the deep link
    /// below lands in a running app rather than being opened from behind
    /// the Shortcuts UI.
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Merchant")
    var merchant: String?

    func perform() async throws -> some IntentResult {
        var components = URLComponents()
        components.scheme = "com.stubapp.stub"
        components.host = "log-expense"

        var items = [URLQueryItem(name: "amount", value: String(amount))]
        if let merchant = merchant, !merchant.isEmpty {
            // URLComponents percent-encodes query item values for us.
            items.append(URLQueryItem(name: "merchant", value: merchant))
        }
        components.queryItems = items

        if let url = components.url {
            _ = await UIApplication.shared.open(url)
        }

        return .result()
    }
}

/// Exposes `LogExpenseIntent` to Siri and the Shortcuts app without the user
/// having to build a shortcut around it first.
struct StubAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Log an expense with \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "dollarsign.circle"
        )
    }
}
