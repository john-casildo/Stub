import 'package:flutter/material.dart';
import '../data/account_link_service.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'stub_button.dart';
import 'stub_icon.dart';
import 'stub_provider_row.dart';

/// The 4-provider linking UI (Email functional, Apple/Google/Phone
/// visibly disabled) — shared between BackupPromptScreen and Profile's
/// future Account section. Owns its own email sub-flow, submit-guard,
/// validation, and error handling so every consumer gets those for
/// free instead of re-implementing them.
class StubAccountLinkPanel extends StatefulWidget {
  const StubAccountLinkPanel({super.key, required this.accountLinkService, required this.onLinked});

  final AccountLinkService accountLinkService;
  final VoidCallback onLinked;

  @override
  State<StubAccountLinkPanel> createState() => _StubAccountLinkPanelState();
}

class _StubAccountLinkPanelState extends State<StubAccountLinkPanel> {
  bool _showEmailField = false;
  bool _submitting = false;
  String? _error;
  final _emailController = TextEditingController();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.accountLinkService.linkEmail(email);
      if (!mounted) return;
      widget.onLinked();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = "Couldn't send the link. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final danger = isDark ? StubColors.dangerDark : StubColors.dangerLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StubProviderRow(icon: StubIcons.mail, label: 'Email', enabled: true, onTap: () => setState(() => _showEmailField = true)),
        StubProviderRow(icon: StubIcons.brandApple, label: 'Apple', enabled: false),
        StubProviderRow(icon: StubIcons.brandGoogle, label: 'Google', enabled: false),
        StubProviderRow(icon: StubIcons.phone, label: 'Phone', enabled: false),
        if (_showEmailField) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: 12),
          StubButton(label: _submitting ? 'Sending…' : 'Send link', onPressed: _submitting ? null : _submitEmail),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: StubText.archivo(fontSize: 13, color: danger)),
          ],
        ],
      ],
    );
  }
}
