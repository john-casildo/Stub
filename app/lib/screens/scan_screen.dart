import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/text_recognition_service.dart';
import '../models/transaction.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../util/receipt_parser.dart';
import '../widgets/stub_button.dart';
import '../widgets/stub_chip.dart';
import '../widgets/stub_icon.dart';

enum _ScanStage { choosingSource, choosingType, processing }

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.textRecognitionService,
    required this.onClose,
    required this.onScanned,
    this.debugInitialImagePath,
  });

  final TextRecognitionService textRecognitionService;
  final VoidCallback onClose;
  final void Function(ParsedReceipt parsed, TransactionSource source) onScanned;

  /// Test-only seam: real image capture goes through `image_picker`,
  /// which can't return a fake result inside a widget test. Setting this
  /// skips straight to the type-picker stage with this path, so the
  /// OCR/parse/onScanned wiring past that point can still be tested for
  /// real. Never set outside tests.
  final String? debugInitialImagePath;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late _ScanStage _stage =
      widget.debugInitialImagePath == null ? _ScanStage.choosingSource : _ScanStage.choosingType;
  late String? _imagePath = widget.debugInitialImagePath;
  TransactionSource? _selectedSource;

  Future<void> _pickImage(ImageSource imageSource) async {
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: imageSource);
    } catch (_) {
      // Covers permission-denied and any other platform-level failure —
      // there's nothing to recover into, so surface it and back out.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera access is needed to scan a receipt — enable it in Settings.')),
        );
      }
      widget.onClose();
      return;
    }
    if (picked == null) {
      widget.onClose();
      return;
    }
    setState(() {
      _imagePath = picked!.path;
      _stage = _ScanStage.choosingType;
    });
  }

  Future<void> _continue() async {
    final imagePath = _imagePath;
    final source = _selectedSource;
    if (imagePath == null || source == null) return;
    setState(() => _stage = _ScanStage.processing);
    ParsedReceipt parsed;
    try {
      final lines = await widget.textRecognitionService.recognizeText(imagePath);
      parsed = parseReceiptLines(lines);
    } catch (_) {
      parsed = const ParsedReceipt();
    }
    widget.onScanned(parsed, source);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? StubColors.inkDark : StubColors.inkLight;
    final ink50 = ink.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: isDark ? StubColors.bgDark : StubColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: StubIcon(StubIcons.x, size: 18, color: ink), onPressed: widget.onClose),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: switch (_stage) {
            _ScanStage.choosingSource => _SourcePicker(
                ink: ink,
                onPickCamera: () => _pickImage(ImageSource.camera),
                onPickGallery: () => _pickImage(ImageSource.gallery),
              ),
            _ScanStage.choosingType => _TypePicker(
                ink: ink,
                ink50: ink50,
                selected: _selectedSource,
                onSelect: (s) => setState(() => _selectedSource = s),
                onContinue: _continue,
              ),
            _ScanStage.processing => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.ink, required this.onPickCamera, required this.onPickGallery});
  final Color ink;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Scan a receipt', style: StubText.domine(fontSize: 20, color: ink)),
        const SizedBox(height: 24),
        StubButton(label: 'Take photo', onPressed: onPickCamera),
        const SizedBox(height: 12),
        StubButton(label: 'Choose from library', onPressed: onPickGallery),
      ],
    );
  }
}

class _TypePicker extends StatelessWidget {
  const _TypePicker({
    required this.ink,
    required this.ink50,
    required this.selected,
    required this.onSelect,
    required this.onContinue,
  });
  final Color ink;
  final Color ink50;
  final TransactionSource? selected;
  final ValueChanged<TransactionSource> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What kind of image is this?',
          style: StubText.archivo(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StubChip(
              label: 'Receipt',
              selected: selected == TransactionSource.receipt,
              onTap: () => onSelect(TransactionSource.receipt),
            ),
            StubChip(
              label: 'Payment app',
              selected: selected == TransactionSource.paymentApp,
              onTap: () => onSelect(TransactionSource.paymentApp),
            ),
            StubChip(
              label: 'Bank screenshot',
              selected: selected == TransactionSource.bankScreenshot,
              onTap: () => onSelect(TransactionSource.bankScreenshot),
            ),
          ],
        ),
        const Spacer(),
        StubButton(label: 'Continue', onPressed: selected == null ? null : onContinue),
      ],
    );
  }
}
