import 'package:flutter/material.dart';
import '../data/account_link_service.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_account_link_panel.dart';

class BackupPromptScreen extends StatelessWidget {
  const BackupPromptScreen({super.key, required this.accountLinkService, required this.onDone});

  final AccountLinkService accountLinkService;
  final VoidCallback onDone;

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
              StubAccountLinkPanel(accountLinkService: accountLinkService, onLinked: onDone),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: onDone,
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
