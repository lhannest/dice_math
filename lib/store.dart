import 'dart:convert';
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
  final PracticeRepository repository;
  List<EquationEntry> _equations = [
    EquationEntry(DiceExpression.parse('1d20 + 7')),
    EquationEntry(DiceExpression.parse('2d4')),
    EquationEntry(DiceExpression.parse('2d6 + 3')),
  ];
  final List<Attempt> _attempts = [];
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
        _equations = equations;
        _attempts
          ..clear()
          ..addAll(attempts);
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
  Future<void> record(Attempt attempt) {
    _attempts.add(attempt);
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
      _equations[index] = EquationEntry(
        expression,
        enabled: _equations[index].enabled,
      );
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
    _equations.removeAt(index);
    return _save();
  }
}
