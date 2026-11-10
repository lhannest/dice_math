import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dice_math/models/dice.dart';
import 'package:dice_math/models/history.dart';
import 'package:dice_math/store.dart';

class MemoryRepository implements PracticeRepository {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    if (fail) throw StateError('disk unavailable');
    value = data;
  }
}

Attempt attempt({bool correct = true, int ms = 1000, int streak = 1}) =>
    Attempt(
      at: DateTime(2026, 11, 9),
      equation: '1d20 + 7',
      calculation: '4 + 7',
      answer: correct ? 11 : 10,
      expected: 11,
      milliseconds: ms,
      streak: correct ? streak : 0,
    );

void main() {
  test('review rolls and timer settings survive reload and mastery', () async {
    final repository = MemoryRepository();
    final store = PracticeStore(repository);
    await store.load();
    await store.setSecondsPerTerm(4);
    final question = RolledQuestion('1d20 + 7', const [
      RolledNumber(sign: 1, values: [4]),
      RolledNumber(sign: 1, values: [7]),
    ]);
    for (var i = 0; i < 8; i++) {
      await store.record(attempt(correct: false), question: question);
    }
    final random = Random(0);
    expect(store.reviewQuestion(random), isNull);
    await store.record(attempt(correct: false), question: question);

    final restored = PracticeStore(repository);
    await restored.load();
    expect(restored.secondsPerTerm, 4);
    final review = restored.reviewQuestion(random)!;
    expect(review.calculation, question.calculation);
    expect(review.total, question.total);
    await restored.toggle(0);
    expect(restored.reviewQuestion(random), isNull);
    await restored.toggle(0);
    await restored.record(attempt(), question: review);
    for (var i = 0; i < 9; i++) {
      await restored.record(attempt());
    }
    expect(restored.reviewQuestion(random), isNull);
  });

  test('equations and submitted answers survive a complete reload', () async {
    final repository = MemoryRepository();
    final store = PracticeStore(repository);
    await store.load();
    await store.putEquation('adv(d20) + 2');
    await store.toggle(0);
    await store.record(attempt(ms: 1234));
    final restored = PracticeStore(repository);
    await restored.load();
    expect(restored.equations.last.expression.notation, 'adv(1d20) + 2');
    expect(restored.equations.first.enabled, isFalse);
    expect(restored.attempts.single.milliseconds, 1234);
    expect(restored.attempts.single.calculation, '4 + 7');
    expect(restored.storageError, isNull);
  });

  test(
    'queued writes retain every submitted answer and latest edits',
    () async {
      final repository = MemoryRepository();
      final store = PracticeStore(repository);
      await store.load();
      final writes = List.generate(40, (i) => store.record(attempt(ms: i)));
      writes.add(store.putEquation('dis(d20) - 1'));
      await Future.wait(writes);
      final restored = PracticeStore(repository);
      await restored.load();
      expect(restored.attempts.length, 40);
      expect(restored.equations.last.expression.notation, 'dis(1d20) − 1');
    },
  );

  test(
    'failed saves retain in-memory data and retry the current snapshot',
    () async {
      final repository = MemoryRepository()..fail = true;
      final store = PracticeStore(repository);
      await store.load();
      await store.record(attempt());
      expect(store.storageError, isNotNull);
      expect(store.attempts.length, 1);
      repository.fail = false;
      await store.retrySave();
      expect(store.storageError, isNull);
      expect((jsonDecode(repository.value!)['attempts'] as List).length, 1);
    },
  );

  test('unreadable history is preserved for a load retry', () async {
    final repository = MemoryRepository()..value = 'invalid';
    final store = PracticeStore(repository);
    await store.load();
    expect(store.isLoaded, isFalse);
    expect(store.storageError, isNotNull);
    expect(repository.value, 'invalid');
    repository.value = null;
    await store.load();
    expect(store.isLoaded, isTrue);
  });

  test(
    'canonical duplicates are rejected; all equations can be disabled or deleted',
    () async {
      final store = PracticeStore(MemoryRepository());
      await store.load();
      expect(() => store.putEquation('D20+7'), throwsFormatException);
      for (var i = 0; i < store.equations.length; i++) {
        await store.toggle(i);
      }
      expect(store.enabled, isEmpty);
      while (store.equations.isNotEmpty) {
        await store.remove(0);
      }
      expect(store.equations, isEmpty);
    },
  );

  test(
    'speed excludes wrong answers and streaks do not cross practice runs',
    () {
      final stats = PracticeStats([
        attempt(ms: 1000),
        attempt(ms: 3000, streak: 2),
        attempt(ms: 9000, correct: false),
        attempt(ms: 2000),
        attempt(ms: 4000, streak: 2),
        attempt(ms: 1000),
      ]);
      expect(stats.count, 6);
      expect(stats.correct, 5);
      expect(stats.medianSeconds, 2);
      expect(stats.bestStreak, 2);
      expect(
        PracticeStats([attempt(ms: 1000), attempt(ms: 3000)]).medianSeconds,
        2,
      );
      expect(PracticeStats([attempt(correct: false)]).medianSeconds, isNull);
    },
  );
}
