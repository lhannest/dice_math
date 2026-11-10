# Dice Math

An offline Android app for practicing D&D dice arithmetic, built with Flutter.

## Practice

Enable equations in **Equations**, then tap **Start practicing**. Every enabled equation has an equal chance of being selected. Only the rolled numbers and fixed modifiers appear during a question.

Tap a number in the calculation to dim it once you’ve counted it. Tap it again to restore it.

Enter a total with the keypad or a physical keyboard. The app checks it as soon as you enter as many digits as the correct total has. For negative answers, enter the minus sign before the digits. A short success/error animation advances automatically to another question. Incorrect answers briefly show the correct total. Correct answers build a streak.

Practice continues until you leave. Each submitted answer saves independently; quitting never creates a result or counts an unfinished question. Backgrounding pauses practice; resuming gives a fresh roll so time away never affects response times.

## Equation syntax

| Expression | Meaning |
| --- | --- |
| `1d20 + 7` | One twenty-sided die plus seven |
| `2d4` | Two four-sided dice |
| `2d6 + 1d4 - 2` | Mixed dice and signed modifiers |
| `adv(d20) + 7` | Roll two d20s, keep the higher, add seven |
| `dis(d20) + 2` | Roll two d20s, keep the lower, add two |
| `2d20kh1` / `2d20kl1` | Alternate advantage/disadvantage notation |

`d20` is shorthand for `1d20`. Advantage and disadvantage apply to a single die of any supported size. During practice, `↑(4, 18)` means keep 18 and `↓(4, 18)` means keep 4. Addition and subtraction are supported; multiplication and nested expressions are not. Limits: 20 terms, 20 dice per normal term, 2–1,000 sides, and fixed modifiers up to 10,000.

## Progress

Accuracy, median response time for correct answers, best streak, daily trends, per-equation statistics, and recent answers are available for the last 7 days, 30 days, or all time. Once there are 40 answers in a view, the most recent 20 are compared with the preceding 20. Per-equation comparisons help control for changing difficulty. Empty days are not treated as zero accuracy or zero time.

The timer starts after the question's first frame and stops on submission. Feedback time is excluded. Equations and answer history are saved locally with `SharedPreferencesAsync`; the app needs no account or network connection. Uninstalling or clearing app data removes this history.

## Development

Use Flutter 3.41 / Dart 3.11 or newer, with an Android SDK configured.

```sh
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. Android API 24 or newer is required. The generated project still uses the development application ID and debug signing; configure an application ID and release signing before store distribution.

Tests cover parser validation, dice bounds, advantage/disadvantage, persistence and failed saves, statistics, the answer loop, backgrounding, quitting, keypad input, and compact layouts with enlarged text.

## Automated APK releases

The **Android release** GitHub Actions workflow runs on every branch push and can also be started manually. Each run checks the release publisher, analyzes and tests the app, and builds a release-mode APK using Flutter 3.41.2 and Java 17. A push containing several commits builds the pushed branch's latest commit.

Successful builds appear under the repository's **Releases** page. The release title includes the commit subject and SHA, and its notes include the full commit message and a link to the workflow run. Download the attached `dice-math-<commit>.apk`. The Android build number increases with the workflow run number.

After publishing, the workflow keeps the 10 most recently published CI releases and deletes older CI releases, their APKs, and their `ci-apk-*` tags. Manually created releases are preserved. Failed builds do not publish or prune releases, and rerunning a successful build preserves its existing APK.

The workflow uses GitHub's built-in token with `contents: write`; no personal access token is needed. APKs use the project's existing development signing configuration. Different fresh CI runners generate different debug keys, so replacing an installed APK from another run may require uninstalling it first (which clears local history). Configure a persistent release keystore before distributing updates.

Run the publisher's mocked API checks locally with:

```sh
node --test .github/scripts/release.test.cjs
```
