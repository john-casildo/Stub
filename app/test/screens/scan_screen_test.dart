import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/models/transaction.dart';
import 'package:stub/screens/scan_screen.dart';
import 'package:stub/util/receipt_parser.dart';

void main() {
  testWidgets('Picking a source type and continuing calls onScanned with the parsed result', (tester) async {
    ParsedReceipt? scannedParsed;
    TransactionSource? scannedSource;

    final service = FakeTextRecognitionService();

    // Real capture goes through `image_picker`, which can't return a fake
    // result inside a widget test — `debugInitialImagePath` is a test-only
    // seam that skips straight to the type-picker stage with a fake path,
    // so the OCR/parse/onScanned wiring past that point is still tested
    // for real. See Step 4 for its definition.
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          textRecognitionService: service,
          onClose: () {},
          onScanned: (parsed, source) {
            scannedParsed = parsed;
            scannedSource = source;
          },
          debugInitialImagePath: 'test/fixtures/fake.jpg',
        ),
      ),
    );

    expect(find.text('Receipt'), findsOneWidget);
    await tester.tap(find.text('Receipt'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    // _continue now does a real (if here immediately-failing, since the
    // fixture path doesn't exist) dart:io file read via
    // normalizeImageOrientation before the fake OCR call — genuine async
    // I/O doesn't resolve via plain tester.pump() in a testWidgets test,
    // it needs runAsync to let the real event loop complete it. Not
    // pumpAndSettle: the processing stage's indeterminate
    // CircularProgressIndicator never stops requesting frames.
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump();

    expect(scannedSource, TransactionSource.receipt);
    expect(scannedParsed, isNotNull);
  });

  testWidgets('The source picker shows a tip about flat, well-lit photos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          textRecognitionService: FakeTextRecognitionService(),
          onClose: () {},
          onScanned: (_, _) {},
        ),
      ),
    );

    expect(find.textContaining('well-lit'), findsOneWidget);
    expect(find.textContaining('flat'), findsOneWidget);
  });

  testWidgets('Continue is disabled until a source type is picked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanScreen(
          textRecognitionService: FakeTextRecognitionService(),
          onClose: () {},
          onScanned: (_, _) {},
          debugInitialImagePath: 'test/fixtures/fake.jpg',
        ),
      ),
    );

    final continueButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue'));
    expect(continueButton.onPressed, isNull);
  });
}
