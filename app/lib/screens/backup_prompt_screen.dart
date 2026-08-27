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
