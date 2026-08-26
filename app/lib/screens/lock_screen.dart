import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/stub_icon.dart';
import '../widgets/stub_pressable.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key, required this.onUnlock, required this.onUsePasscode});

  final VoidCallback onUnlock;
  final VoidCallback onUsePasscode;

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
                onTap: onUnlock,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  decoration: BoxDecoration(gradient: StubColors.gradPop(Brightness.dark), borderRadius: BorderRadius.circular(10)),
                  child: Text('Unlock with Face ID', style: StubText.archivo(fontSize: 14, fontWeight: FontWeight.w600, color: StubColors.onAccentDark)),
                ),
              ),
              const SizedBox(height: 16),
              StubPressable(
                onTap: onUsePasscode,
                ensureMinTapSize: true,
                child: Text('Use passcode', style: StubText.archivo(fontSize: 12, color: paperText.withValues(alpha: 0.45))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
