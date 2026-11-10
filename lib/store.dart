import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/dice.dart';
import 'models/history.dart';

abstract class PracticeRepository {
  Future<String?> read();
  Future<void> write(String value);
}

class PreferencesRepository implements PracticeRepository {
  final _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read() => _preferences.getString('dice_math_v1');
  @override
  Future<void> write(String value) =>
      _preferences.setString('dice_math_v1', value);
}

class EquationEntry {
  const EquationEntry(this.expression, {this.enabled = true});
  final DiceExpression expression;
  final bool enabled;
  Map<String, Object> toJson() => {
    'expression': expression.notation,
    'enabled': enabled,
  };
}

class PracticeStore extends ChangeNotifier {
  PracticeStore(this.repository);
  static const defaultSecondsPerTerm = 3;
  static const maxSecondsPerTerm = 60;
  static const _reviewInterval = 10;

  final PracticeRepository repository;
  List<EquationEntry> _equations = [
    EquationEntry(DiceExpression.parse('1d20 + 7')),
    EquationEntry(DiceExpression.parse('2d4')),
    EquationEntry(DiceExpression.parse('2d6 + 3')),
  ];
  final List<Attempt> _attempts = [];
  final _reviewBank = <(String, String), RolledQuestion>{};
  int _secondsPerTerm = defaultSecondsPerTerm;
  int get secondsPerTerm => _secondsPerTerm;
  List<EquationEntry> get equations => List.unmodifiable(_equations);
  List<Attempt> get attempts => List.unmodifiable(_attempts);
  List<DiceExpression> get enabled =>
      _equations.where((e) => e.enabled).map((e) => e.expression).toList();
  String? storageError;
  bool isLoaded = false;
  Future<void> _pending = Future.value();

  Future<void> load() async {
    try {
      final value = await repository.read();
      if (value != null) {
        final json = jsonDecode(value) as Map<String, dynamic>;
        final equations = (json['equations'] as List)
            .map(
              (e) => EquationEntry(
                DiceExpression.parse(e['expression'] as String),
                enabled: e['enabled'] as bool,
              ),
            )
            .toList();
        final attempts = (json['attempts'] as List)
            .map((e) => Attempt.fromJson(e as Map<String, dynamic>))
            .toList();
        final reviewBank = (json['reviewBank'] as List? ?? []).map(
          (e) => RolledQuestion.fromJson(e as Map<String, dynamic>),
        );
        final bankByCalculation = {
          for (final question in reviewBank)
            (question.equation, question.calculation): question,
        };
        final secondsPerTerm =
            json['secondsPerTerm'] as int? ?? defaultSecondsPerTerm;
        _equations = equations;
        _attempts
          ..clear()
          ..addAll(attempts);
        _reviewBank
          ..clear()
          ..addAll(bankByCalculation);
        _secondsPerTerm = secondsPerTerm.clamp(1, maxSecondsPerTerm);
      }
      storageError = null;
      isLoaded = true;
    } catch (_) {
      storageError =
          'Could not load saved practice. Restart the app to try again.';
    }
    notifyListeners();
  }

  Future<void> _save() {
    // Capture each mutation now and serialize writes so older snapshots cannot win.
    final value = jsonEncode({
      'equations': _equations.map((e) => e.toJson()).toList(),
      'attempts': _attempts.map((a) => a.toJson()).toList(),
      'reviewBank': _reviewBank.values.map((q) => q.toJson()).toList(),
      'secondsPerTerm': _secondsPerTerm,
    });
    _pending = _pending.then((_) async {
      try {
        await repository.write(value);
        storageError = null;
      } catch (_) {
        storageError =
            'Changes could not be saved. Keep the app open and tap Retry.';
      }
      notifyListeners();
    });
    notifyListeners();
    return _pending;
  }

  Future<void> retrySave() => _save();

  Future<void> setSecondsPerTerm(int seconds) {
    if (seconds < 1 || seconds > maxSecondsPerTerm) {
      throw const FormatException(
        'Enter a whole number from 1 to $maxSecondsPerTerm.',
      );
    }
    if (_secondsPerTerm == seconds) return Future.value();
    _secondsPerTerm = seconds;
    return _save();
  }

  RolledQuestion? reviewQuestion(Random random) {
    if ((_attempts.length + 1) % _reviewInterval != 0) return null;
    final enabledEquations = enabled.map((e) => e.notation).toSet();
    final eligible = _reviewBank.values
        .where((question) => enabledEquations.contains(question.equation))
        .toList();
    return eligible.isEmpty ? null : eligible[random.nextInt(eligible.length)];
  }

  Future<void> record(Attempt attempt, {RolledQuestion? question}) {
    _attempts.add(attempt);
    if (question != null) {
      final key = (question.equation, question.calculation);
      if (attempt.correct) {
        _reviewBank.remove(key);
      } else {
        _reviewBank[key] = question;
      }
    }
    return _save();
  }

  Future<void> putEquation(String input, {int? index}) {
    final expression = DiceExpression.parse(input);
    if (_equations.indexed.any(
      (e) => e.$1 != index && e.$2.expression.notation == expression.notation,
    )) {
      throw const FormatException(
        'That equation is already in your collection.',
      );
    }
    if (index == null) {
      _equations.add(EquationEntry(expression));
    } else {
      final previous = _equations[index];
      if (previous.expression.notation != expression.notation) {
        _reviewBank.removeWhere(
          (key, _) => key.$1 == previous.expression.notation,
        );
      }
      _equations[index] = EquationEntry(expression, enabled: previous.enabled);
    }
    return _save();
  }

  Future<void> toggle(int index) {
    final entry = _equations[index];
    _equations[index] = EquationEntry(
      entry.expression,
      enabled: !entry.enabled,
    );
    return _save();
  }

  Future<void> remove(int index) {
    final removed = _equations.removeAt(index);
    _reviewBank.removeWhere((key, _) => key.$1 == removed.expression.notation);
    return _save();
  }
}
