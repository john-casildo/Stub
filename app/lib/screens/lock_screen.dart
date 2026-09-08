import 'package:flutter/material.dart';
import '../data/device_auth_service.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_pressable.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.deviceAuthService, required this.onUnlock});

  final DeviceAuthService deviceAuthService;
  final VoidCallback onUnlock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _authenticating = false;
  bool _lastAttemptFailed = false;

  Future<void> _unlock() async {
    setState(() {
      _authenticating = true;
      _lastAttemptFailed = false;
    });
    final success = await widget.deviceAuthService.authenticate();
    if (!mounted) return;
    if (success) {
      widget.onUnlock();
      return;
    }
    setState(() {
      _authenticating = false;
      _lastAttemptFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fixed dark bezel — not theme-reactive, see DESIGN.md §4/§2.
    const bezel = Color(0xFF1B1712);
    const paperText = Color(0xFFF3ECDD);

    return Scaffold(
      backgroundColor: bezel,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: paperText.withValues(alpha: 0.3), width: 2),
                ),
                child: Center(child: StubIcon(StubIcons.lock, size: 30, color: paperText.withValues(alpha: 0.85))),
              ),
              const SizedBox(height: 22),
              Text('Stub is locked', style: StubText.archivo(fontSize: 20, fontWeight: FontWeight.w700, color: paperText)),
              const SizedBox(height: 6),
              Text('Your ledger, kept private', style: StubText.archivo(fontSize: 13, color: paperText.withValues(alpha: 0.55))),
              const SizedBox(height: 30),
              StubPressable(
                onTap: _authenticating ? null : _unlock,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  decoration: BoxDecoration(gradient: StubColors.gradPop(Brightness.dark), borderRadius: BorderRadius.circular(10)),
                  child: _authenticating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: StubColors.onAccentDark),
                        )
                      : Text('Unlock', style: StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: StubColors.onAccentDark)),
                ),
              ),
              if (_lastAttemptFailed) ...[
                const SizedBox(height: 16),
                Text(
                  "Couldn't verify it's you — try again",
                  style: StubText.archivo(fontSize: 12, color: paperText.withValues(alpha: 0.55)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
