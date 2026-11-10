import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dice_math/main.dart';
import 'package:dice_math/screens/practice.dart';
import 'package:dice_math/store.dart';
import 'dice_test.dart' show SequenceRandom;
import 'store_test.dart' show MemoryRepository, attempt;

Future<PracticeStore> makeStore() async {
  final store = PracticeStore(MemoryRepository());
  await store.load();
  while (store.equations.isNotEmpty) {
    await store.remove(0);
  }
  await store.putEquation('1d20 + 7');
  return store;
}

Future<void> openPractice(WidgetTester tester, PracticeStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PracticeScreen(store: store, random: SequenceRandom([3])),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'clean question, one submission, fast feedback, next roll and streak reset',
    (tester) async {
      final store = await makeStore();
      await openPractice(tester, store);
      expect(find.text('1d20 + 7'), findsNothing);
      expect(find.text('4'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(store.attempts.length, 1);
      expect(store.attempts.single.correct, isTrue);
      expect(store.attempts.single.streak, 1);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('?'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(store.attempts.length, 2);
      expect(store.attempts.last.correct, isFalse);
      expect(store.attempts.last.streak, 0);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('quitting an unanswered question records nothing', (
    tester,
  ) async {
    final store = await makeStore();
    await tester.pumpWidget(DiceMathApp(store: store));
    await tester.tap(find.text('Start practicing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quit practice'));
    await tester.pumpAndSettle();
    expect(store.attempts, isEmpty);
    expect(find.text('Start practicing'), findsOneWidget);
  });

  testWidgets(
    'backgrounding discards only unfinished work and waits for resume',
    (tester) async {
      final store = await makeStore();
      await openPractice(tester, store);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Resume practice'), findsOneWidget);
      expect(store.attempts, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('Resume practice'));
      await tester.pump();
      expect(find.text('?'), findsOneWidget);
      expect(store.attempts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('keypad supports corrections and negative answers', (
    tester,
  ) async {
    final store = await makeStore();
    await store.putEquation('1d20 - 7', index: 0);
    await openPractice(tester, store);
    await tester.tap(find.text('4').last);
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.tap(find.text('+/−'));
    await tester.tap(find.text('3').last);
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(store.attempts.single.answer, -3);
    expect(store.attempts.single.correct, isTrue);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'small screens show practice and populated progress without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await makeStore();
      await openPractice(tester, store);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(DiceMathApp(store: store));
      await store.record(attempt());
      await tester.pump();
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('large text and advantage fit compact screens', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await makeStore();
    await store.putEquation('adv(d1000) + 7000', index: 0);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PracticeScreen(store: store, random: SequenceRandom([999])),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('equation editor validates input and saves advantage', (
    tester,
  ) async {
    final store = await makeStore();
    await tester.pumpWidget(DiceMathApp(store: store));
    await tester.tap(find.text('Equations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add equation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.tap(find.text('Save equation'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'adv(d20) + 7');
    await tester.tap(find.text('Save equation'));
    await tester.pumpAndSettle();
    expect(store.equations.last.expression.notation, 'adv(1d20) + 7');
    expect(find.byType(TextField), findsNothing);
  });
}
