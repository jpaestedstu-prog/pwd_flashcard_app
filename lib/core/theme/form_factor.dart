import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/platform_caps.dart';

/// What kind of screen the app is on. The one place that decides.
///
///  * [phone] — the short side is under 600 dp, whatever the browser or the
///    device, held either way up.
///  * [tablet] — a touch screen with a short side of 600 dp or more.
///  * [desktop] — a browser on a computer, in a window wide enough to use as
///    one: a mouse and a keyboard, not a finger.
///
/// The same app, the same shared themes and components; [AdaptiveTheme] layers
/// only what genuinely differs on top. A style the three forms share belongs
/// in `AppTheme`, not here.
enum FormFactor {
  phone,
  tablet,
  desktop;

  /// The form factor for a window of [size].
  ///
  /// [web] and [platform] default to the running app; a test passes them.
  static FormFactor forSize(Size size, {bool? web, TargetPlatform? platform}) {
    final isWeb = web ?? PlatformCaps.isWeb;
    final os = platform ?? defaultTargetPlatform;
    final computerOs =
        os == TargetPlatform.windows ||
        os == TargetPlatform.macOS ||
        os == TargetPlatform.linux;
    // A browser window on a computer dragged narrow is laid out as a phone.
    if (isWeb && computerOs && size.width >= 600) return FormFactor.desktop;
    return size.shortestSide >= 600 ? FormFactor.tablet : FormFactor.phone;
  }

  static FormFactor of(BuildContext context) =>
      forSize(MediaQuery.sizeOf(context));

  /// A mouse is the likely pointer, so hover and a click cursor are worth
  /// drawing and controls can stop at the size a mouse needs.
  bool get usesMouse => this == FormFactor.desktop;
}

/// The control sizes that differ between the [FormFactor]s.
///
/// Sizes come from the people using them: touch targets stay at least 56 dp
/// tall (many learners have limited motor control), and a mouse still gets
/// 48; a phone is short of width, so its buttons give up side padding, not
/// height.
@immutable
class FormMetrics {
  const FormMetrics({
    required this.buttonPadding,
    required this.textButtonPadding,
    required this.buttonMinSize,
    required this.textButtonMinSize,
    required this.fieldPadding,
    this.dialogMaxWidth,
    this.snackBarWidth,
    this.dialogInset,
  });

  /// Filled, elevated and outlined buttons.
  final EdgeInsets buttonPadding;
  final EdgeInsets textButtonPadding;
  final Size buttonMinSize;
  final Size textButtonMinSize;

  /// Inside a text field.
  final EdgeInsets fieldPadding;

  /// How wide a dialog may grow. Null: as wide as its content asks.
  final double? dialogMaxWidth;

  /// A floating snack bar's width. Null: across the window.
  final double? snackBarWidth;

  /// The gap around a dialog. Null: Flutter's own.
  final EdgeInsets? dialogInset;

  /// Narrower side padding than a tablet, the same 56 dp height: the
  /// app's buttons are big on purpose, for learners with less control.
  static const phone = FormMetrics(
    buttonPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    textButtonPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    buttonMinSize: Size(56, 56),
    textButtonMinSize: Size(56, 56),
    fieldPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    dialogInset: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
  );

  /// The sizes `AppTheme` is drawn with, so a tablet is unchanged.
  static const tablet = FormMetrics(
    buttonPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
    textButtonPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    buttonMinSize: Size(56, 56),
    textButtonMinSize: Size(56, 56),
    fieldPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    dialogMaxWidth: 560,
    snackBarWidth: 560,
  );

  static const desktop = FormMetrics(
    buttonPadding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    textButtonPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    buttonMinSize: Size(64, 48),
    textButtonMinSize: Size(48, 48),
    fieldPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    dialogMaxWidth: 560,
    snackBarWidth: 560,
  );

  static FormMetrics of(FormFactor factor) => switch (factor) {
    FormFactor.phone => phone,
    FormFactor.tablet => tablet,
    FormFactor.desktop => desktop,
  };
}

/// How much of a button's side padding is left at a text scale: bigger words
/// need the room more, the way Material's own default padding gives way.
@visibleForTesting
double sidePaddingFactor(double textScale) =>
    lerpDouble(1, 0.6, ((textScale - 1) / 0.5).clamp(0.0, 1.0))!;

/// [base], adjusted for [factor] at [textScale]. Only sizes change: colours,
/// shapes and type stay exactly as the shared theme has them.
ThemeData adaptTheme(ThemeData base, FormFactor factor, double textScale) {
  final m = FormMetrics.of(factor);
  final side = sidePaddingFactor(textScale);
  EdgeInsets giveWay(EdgeInsets e) =>
      EdgeInsets.symmetric(horizontal: e.left * side, vertical: e.top);

  ButtonStyle? sized(ButtonStyle? style, EdgeInsets padding, Size minSize) =>
      style?.copyWith(
        padding: WidgetStatePropertyAll(giveWay(padding)),
        minimumSize: WidgetStatePropertyAll(minSize),
      );

  final dialogMax = m.dialogMaxWidth;
  return base.copyWith(
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: sized(
        base.elevatedButtonTheme.style,
        m.buttonPadding,
        m.buttonMinSize,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: sized(
        base.filledButtonTheme.style,
        m.buttonPadding,
        m.buttonMinSize,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: sized(
        base.outlinedButtonTheme.style,
        m.buttonPadding,
        m.buttonMinSize,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: sized(
        base.textButtonTheme.style,
        m.textButtonPadding,
        m.textButtonMinSize,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      contentPadding: m.fieldPadding,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      insetPadding: m.dialogInset ?? base.dialogTheme.insetPadding,
      constraints: dialogMax == null
          ? null
          : BoxConstraints(minWidth: 280, maxWidth: dialogMax),
    ),
    snackBarTheme: m.snackBarWidth == null
        ? base.snackBarTheme
        : base.snackBarTheme.copyWith(width: m.snackBarWidth),
    scrollbarTheme: factor.usesMouse
        ? base.scrollbarTheme.copyWith(
            thumbVisibility: const WidgetStatePropertyAll(true),
            thickness: const WidgetStatePropertyAll(10),
            radius: const Radius.circular(6),
            interactive: true,
          )
        : base.scrollbarTheme,
  );
}

/// Applies [adaptTheme] to everything below it: goes around the app's screens
/// and overlays (`main.dart`), and around any test that wants what a learner
/// on that kind of screen gets.
class AdaptiveTheme extends StatelessWidget {
  const AdaptiveTheme({super.key, required this.child});

  final Widget child;

  /// One adapted theme per (theme, form, text scale): a new one on every
  /// rebuild would make the whole tree that reads the theme rebuild as well.
  static final _cache = Expando<Map<int, ThemeData>>();

  static ThemeData of(ThemeData base, FormFactor factor, double textScale) {
    final byKey = _cache[base] ??= <int, ThemeData>{};
    final key = Object.hash(factor, textScale);
    return byKey[key] ??= adaptTheme(base, factor, textScale);
  }

  @override
  Widget build(BuildContext context) {
    final factor = FormFactor.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return Theme(
      data: of(Theme.of(context), factor, textScale),
      child: child,
    );
  }
}
