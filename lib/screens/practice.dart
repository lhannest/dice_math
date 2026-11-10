import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dice.dart';
import '../models/history.dart';
import '../store.dart';
import '../theme.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({required this.store, this.random, super.key});
  final PracticeStore store;
  final Random? random;
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with WidgetsBindingObserver {
  late final Random _random = widget.random ?? Random();
  late final List<DiceExpression> _equations = widget.store.enabled;
  final Stopwatch _clock = Stopwatch();
  final FocusNode _keyboard = FocusNode();
  final Set<int> _counted = {};
  late RolledQuestion _question;
  String _answer = '';
  int _streak = 0;
  bool? _correct;
  bool _paused = false;
  bool _ready = false;
  Timer? _advance;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newQuestion();
  }

  void _newQuestion() {
    _clock.stop();
    _ready = false;
    _question = _equations[_random.nextInt(_equations.length)].roll(_random);
    _counted.clear();
    _answer = '';
    _correct = null;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_paused && generation == _generation) {
        _clock
          ..reset()
          ..start();
        _ready = true;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_paused) {
      _advance?.cancel();
      _clock.stop();
      setState(() {
        _paused = true;
        _ready = false;
      });
    }
  }

  void _resume() {
    setState(() {
      _paused = false;
      _newQuestion();
    });
    _keyboard.requestFocus();
  }

  void _type(String key) {
    if (!_ready || _paused || _correct != null) return;
    setState(() {
      if (key == 'back') {
        if (_answer.isNotEmpty) {
          _answer = _answer.substring(0, _answer.length - 1);
        }
      } else if (key == 'sign') {
        _answer = _answer.startsWith('-') ? _answer.substring(1) : '-$_answer';
      } else {
        if (_answer == '0') {
          _answer = key;
        } else if (_answer == '-0') {
          _answer = '-$key';
        } else {
          _answer += key;
        }
      }
    });
    if (_answer.replaceFirst('-', '').length ==
        _question.total.abs().toString().length) {
      _submit(int.parse(_answer));
    }
  }

  void _submit(int answer) {
    _clock.stop();
    final correct = answer == _question.total;
    widget.store.record(
      Attempt(
        at: DateTime.now(),
        equation: _question.equation,
        calculation: _question.calculation,
        answer: answer,
        expected: _question.total,
        milliseconds: _clock.elapsedMilliseconds,
        streak: correct ? _streak + 1 : 0,
      ),
    );
    setState(() {
      _ready = false;
      _correct = correct;
      _streak = correct ? _streak + 1 : 0;
    });
    if (!MediaQuery.of(context).disableAnimations) {
      if (correct) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
    _advance = Timer(const Duration(milliseconds: 380), () {
      if (mounted && !_paused) setState(_newQuestion);
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character != null && RegExp(r'^\d$').hasMatch(character)) {
      _type(character);
    } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _type('back');
    } else if (event.logicalKey == LogicalKeyboardKey.minus) {
      _type('sign');
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advance?.cancel();
    _clock.stop();
    _keyboard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedbackColor = _correct == true ? success : failure;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Focus(
      autofocus: true,
      focusNode: _keyboard,
      onKeyEvent: _handleKey,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Quit practice',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: muted),
                        ),
                        Expanded(
                          child: Semantics(
                            liveRegion: true,
                            label: '$_streak correct in a row',
                            child: ExcludeSemantics(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_fire_department_outlined,
                                    size: 20,
                                    color: _streak > 0 ? gold : muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_streak',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: _streak > 0 ? gold : muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: widget.store,
                    builder: (context, _) => widget.store.storageError == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              widget.store.storageError!,
                              style: const TextStyle(
                                color: failure,
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: _paused
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Take your time.',
                                style: TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'A fresh roll when you’re ready.',
                                style: TextStyle(color: muted),
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: _resume,
                                child: const Text('Resume practice'),
                              ),
                            ],
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) => SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: IntrinsicHeight(
                                  child: Column(
                                    children: [
                                      const Spacer(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 20,
                                        ),
                                        child: Wrap(
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            for (final (index, number)
                                                in _question.numbers.indexed)
                                              _buildNumber(index, number),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: 82,
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: AnimatedSwitcher(
                                                duration: Duration(
                                                  milliseconds: reduceMotion
                                                      ? 0
                                                      : 100,
                                                ),
                                                child: _correct == null
                                                    ? Semantics(
                                                        label: 'Answer',
                                                        value: _answer.isEmpty
                                                            ? 'empty'
                                                            : _answer,
                                                        child: Text(
                                                          _answer.isEmpty
                                                              ? '?'
                                                              : _answer
                                                                    .replaceAll(
                                                                      '-',
                                                                      '−',
                                                                    ),
                                                          key: const ValueKey(
                                                            'answer',
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 48,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                _answer.isEmpty
                                                                ? muted
                                                                      .withValues(
                                                                        alpha:
                                                                            .4,
                                                                      )
                                                                : gold,
                                                          ),
                                                        ),
                                                      )
                                                    : Semantics(
                                                        liveRegion: true,
                                                        label: _correct!
                                                            ? 'Correct'
                                                            : 'Incorrect. The answer is ${_question.total}',
                                                        child: Row(
                                                          key: ValueKey(
                                                            _correct,
                                                          ),
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Icon(
                                                              _correct!
                                                                  ? Icons
                                                                        .check_circle_rounded
                                                                  : Icons
                                                                        .cancel_rounded,
                                                              color:
                                                                  feedbackColor,
                                                              size: 34,
                                                            ),
                                                            if (!_correct!) ...[
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              Text(
                                                                '${_question.total}',
                                                                style: TextStyle(
                                                                  fontSize: 40,
                                                                  color:
                                                                      feedbackColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          12,
                                          24,
                                          16,
                                        ),
                                        child: Column(
                                          children: [
                                            for (final row in [
                                              ['1', '2', '3'],
                                              ['4', '5', '6'],
                                              ['7', '8', '9'],
                                              ['sign', '0', 'back'],
                                            ])
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Row(
                                                  children: row
                                                      .map(
                                                        (key) => Expanded(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 4,
                                                                ),
                                                            child: _KeyButton(
                                                              value: key,
                                                              height: max(
                                                                constraints.maxHeight <
                                                                        600
                                                                    ? 48.0
                                                                    : 60.0,
                                                                MediaQuery.textScalerOf(
                                                                          context,
                                                                        ).scale(
                                                                          26,
                                                                        ) *
                                                                        1.25 +
                                                                    12,
                                                              ),
                                                              onPressed:
                                                                  _correct ==
                                                                      null
                                                                  ? () => _type(
                                                                      key,
                                                                    )
                                                                  : null,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumber(int index, RolledNumber number) {
    final counted = _counted.contains(index);
    final operator = number.sign < 0
        ? 'minus '
        : index > 0
        ? 'plus '
        : '';
    final spokenNumber = switch (number.mode) {
      RollMode.normal => '${number.values.first}',
      RollMode.advantage => 'higher of ${number.values.join(' and ')}',
      RollMode.disadvantage => 'lower of ${number.values.join(' and ')}',
    };
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Semantics(
        label: '$operator$spokenNumber',
        button: true,
        toggled: counted,
        child: InkWell(
          onTap: () => setState(() {
            if (!_counted.add(index)) _counted.remove(index);
          }),
          child: ExcludeSemantics(
            child: Opacity(
              opacity: counted ? .75 : 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (operator.isNotEmpty) ...[
                    Text(
                      number.sign < 0 ? '−' : '+',
                      style: const TextStyle(fontSize: 28, color: muted),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    number.display,
                    style: TextStyle(
                      fontSize: number.mode == RollMode.normal ? 40 : 30,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.value,
    required this.onPressed,
    required this.height,
  });
  final String value;
  final VoidCallback? onPressed;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
    label: switch (value) {
      'back' => 'Delete digit',
      'sign' => 'Toggle negative',
      _ => value,
    },
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    child: ExcludeSemantics(
      child: Material(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: height,
            child: Center(
              child: value == 'back'
                  ? const Icon(Icons.backspace_outlined, size: 22, color: muted)
                  : Text(
                      value == 'sign' ? '+/−' : value,
                      style: TextStyle(
                        fontSize: value == 'sign' ? 22 : 26,
                        color: value == 'sign' ? muted : null,
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
