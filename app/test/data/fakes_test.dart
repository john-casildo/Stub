import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/fakes.dart';
import 'package:stub/data/text_recognition_service.dart';
import 'package:stub/models/budget_limit.dart';

void main() {
  test('FakeCategoryRepository creates, lists, and deletes in memory', () async {
    final repo = FakeCategoryRepository();
    final created = await repo.create('Groceries');
    expect((await repo.list()).map((c) => c.name), contains('Groceries'));

    await repo.delete(created.id);
    expect(await repo.list(), isEmpty);
  });

  test('FakeCategoryRepository.create carries an optional currency override', () async {
    final repo = FakeCategoryRepository();
    final created = await repo.create('Groceries', currencyCode: 'CRC');
    expect(created.currencyCode, 'CRC');
    expect((await repo.list()).first.currencyCode, 'CRC');
  });

  test('FakeTransactionRepository creates, lists, updates, and deletes in memory', () async {
    final repo = FakeTransactionRepository();
    final t = await repo.create(FakeTransactionRepository.sample(categoryId: 'c1', merchant: 'Corner Market'));
    expect((await repo.list()).map((t) => t.merchant), contains('Corner Market'));

    await repo.update(t.copyWith(merchant: 'Corner Market 2'));
    expect((await repo.list()).first.merchant, 'Corner Market 2');

    await repo.delete(t.id);
    expect(await repo.list(), isEmpty);
  });

  test('FakeBudgetRepository creates and lists in memory', () async {
    final repo = FakeBudgetRepository();
    await repo.create(
      categoryId: 'c1',
      limitAmount: 300,
      periodType: BudgetPeriodType.monthly,
      periodStart: DateTime(2026, 8, 1),
    );
    expect((await repo.list()).first.limit, 300);
  });

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

  test('FakeAccountLinkService.setName sets firstName and lastName', () async {
    final service = FakeAccountLinkService();
    expect(service.firstName, isNull);
    expect(service.lastName, isNull);

    await service.setName(firstName: 'Ada', lastName: 'Lovelace');

    expect(service.firstName, 'Ada');
    expect(service.lastName, 'Lovelace');
  });

  test('FakeAccountLinkService.memberSince defaults to null and is settable', () async {
    final service = FakeAccountLinkService();
    expect(service.memberSince, isNull);

    final now = DateTime.now();
    final withMemberSince = FakeAccountLinkService(memberSince: now);
    expect(withMemberSince.memberSince, now);
  });

  test('FakeDeviceAuthService defaults to supported and succeeding', () async {
    final service = FakeDeviceAuthService();
    expect(await service.isSupported(), isTrue);
    expect(await service.authenticate(), isTrue);
  });

  test('FakeDeviceAuthService can be configured as unsupported or failing', () async {
    final unsupported = FakeDeviceAuthService(supported: false);
    expect(await unsupported.isSupported(), isFalse);

    final failing = FakeDeviceAuthService(succeeds: false);
    expect(await failing.authenticate(), isFalse);
  });

  test('FakeTextRecognitionService.recognizeText returns the configured result', () async {
    final service = FakeTextRecognitionService();
    expect(await service.recognizeText('any/path.jpg'), isEmpty);

    const lines = [RecognizedLine(text: 'Corner Market', boundingBox: Rect.zero)];
    final withResult = FakeTextRecognitionService(result: lines);
    expect(await withResult.recognizeText('any/path.jpg'), lines);
  });
}
