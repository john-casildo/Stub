import 'dart:async';

import 'package:flutter/material.dart';
import '../data/account_link_service.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/currency.dart';
import '../widgets/stub_bottom_nav.dart';
import '../widgets/stub_card.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_account_link_panel.dart';
import '../widgets/stub_pressable.dart';

/// Profile tab — anonymous/linked status, lifetime stats, and an entry
/// point into Settings. Reuses [StubAccountLinkPanel] rather than
/// re-implementing the email-link flow (see CLAUDE.md component
/// inventory). Doesn't push [Navigator] routes itself; `onOpenSettings`
/// lets `RootShell` own navigation, matching every other screen here.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.accountLinkService,
    required this.totalEverTracked,
    required this.categoryCount,
    required this.activeNavIndex,
    required this.navItems,
    required this.onNavTap,
    required this.onScanTap,
    required this.onOpenSettings,
  });

  final AccountLinkService accountLinkService;
  final double totalEverTracked;
  final int categoryCount;
  final int activeNavIndex;
  final List<StubNavItem> navItems;
  final ValueChanged<int> onNavTap;
  final VoidCallback onScanTap;
  final VoidCallback onOpenSettings;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  StreamSubscription<bool>? _linkStatusSub;

  @override
  void initState() {
    super.initState();
    // The status getters below are read synchronously in `build()`. Under
    // Supabase they're backed by an already-cached session, but
    // `HttpAccountLinkService` fills them in from an async `/account` fetch
    // — without this subscription the screen would show "Member since —" /
    // "Add your name" until some unrelated rebuild happened to come along.
    _linkStatusSub = widget.accountLinkService.linkStatusChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _linkStatusSub?.cancel();
    super.dispose();
  }

  String _memberSinceLabel() {
    final date = widget.accountLinkService.memberSince;
    if (date == null) return '—';
    return '${_months[date.month - 1]} ${date.year}';
  }

  Future<void> _editName() async {
    final service = widget.accountLinkService;
    final firstController = TextEditingController(text: service.firstName ?? '');
    final lastController = TextEditingController(text: service.lastName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: firstController, autofocus: true, decoration: const InputDecoration(labelText: 'First name')),
            TextField(controller: lastController, decoration: const InputDecoration(labelText: 'Last name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;
    final firstName = firstController.text.trim();
    final lastName = lastController.text.trim();
    if (firstName.isEmpty && lastName.isEmpty) return;
    try {
      await service.setName(firstName: firstName, lastName: lastName);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save your name. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);
    final service = widget.accountLinkService;

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile', style: StubText.domine(fontSize: 18, color: ink)),
              const SizedBox(height: 18),
              StubPressable(
                onTap: _editName,
                child: StubCard(
                  child: Row(
                    children: [
                      StubIcon(StubIcons.userCircle, size: 18, color: ink),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          service.firstName == null && service.lastName == null
                              ? 'Add your name'
                              : '${service.firstName ?? ''} ${service.lastName ?? ''}'.trim(),
                          style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
                        ),
                      ),
                      StubIcon(StubIcons.pencil, size: 16, color: ink50),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              StubCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.isAnonymous ? 'Anonymous — not backed up' : 'Linked via ${service.linkedEmail}',
                      style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
                    ),
                    const SizedBox(height: 4),
                    Text('Member since ${_memberSinceLabel()}', style: StubText.archivo(fontSize: 12, color: ink50)),
                    if (service.isAnonymous) ...[
                      const SizedBox(height: 16),
                      StubAccountLinkPanel(
                        accountLinkService: service,
                        onLinked: () => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              StubCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Stat(label: 'Tracked', value: formatCurrency(widget.totalEverTracked)),
                    _Stat(label: 'Categories', value: '${widget.categoryCount}'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              StubPressable(
                onTap: widget.onOpenSettings,
                child: StubCard(
                  child: Row(
                    children: [
                      StubIcon(StubIcons.pencil, size: 18, color: ink),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Settings', style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: ink))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: StubBottomNav(items: widget.navItems, activeIndex: widget.activeNavIndex, onTap: widget.onNavTap, onScanTap: widget.onScanTap),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: StubText.archivo(fontSize: 11, letterSpacing: 0.7, color: ink.withValues(alpha: 0.5))),
        const SizedBox(height: 4),
        Text(value, style: StubText.unbounded(fontSize: 16, color: ink)),
      ],
    );
  }
}
