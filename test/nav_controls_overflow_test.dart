import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/widgets/app_action_bar.dart';
import 'package:pwdpwdpwd/widgets/app_back_button.dart';
import 'package:pwdpwdpwd/widgets/app_icon_button.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow matrix for the shared, accessible navigation controls
/// (`AppIconButton` / `AppBackButton`) and the overflow-safe `AppActionBar`.
///
/// Each is rendered at every tablet size × orientation × accessibility font
/// scale (1.0 / 1.3 / 2.0) and asserted to lay out without a RenderFlex /
/// layout exception — the concrete "works on every Android tablet, every
/// Android version" guarantee for the Back / Next / Menu / Exit / Close family.
///
/// The widgets are `ConsumerWidget`s, so each is wrapped in a [ProviderScope];
/// the haptic / sound providers are only read on *press*, never during layout,
/// so no real services or router are needed here.

Widget _scope(Widget child) => ProviderScope(child: child);

void main() {
  testWidgets('AppIconButton (disabled) never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => _scope(const AppIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Close',
        onPressed: null,
      )),
    );
  });

  testWidgets('AppIconButton (enlarged primary target) never overflows',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => _scope(AppIconButton(
        icon: Icons.menu_rounded,
        tooltip: 'Menu',
        minSize: 64,
        iconSize: 32,
        onPressed: () {},
      )),
    );
  });

  testWidgets('AppBackButton never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => _scope(const AppBackButton()),
    );
  });

  // A long, multi-button tool strip (mirrors the flashcard viewer's
  // Prev / Listen / FSL / Flip / Next row) must WRAP rather than overflow.
  testWidgets('AppActionBar (wrap) tool strip never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => _scope(AppActionBar(
        alignment: WrapAlignment.spaceEvenly,
        children: [
          for (final (IconData icon, String label) in const [
            (Icons.arrow_back_rounded, 'Previous'),
            (Icons.volume_up_rounded, 'Filipino'),
            (Icons.sign_language_rounded, 'FSL'),
            (Icons.flip_rounded, 'Flip'),
            (Icons.arrow_forward_rounded, 'Next'),
          ])
            _MiniToolButton(icon: icon, label: label),
        ],
      )),
      host: LayoutHost.scrollable,
    );
  });

  // Equal-width primary/secondary pair (mirrors Replay / Close, Back / Next).
  // The deliberately long label stresses the narrow-width stacking path.
  testWidgets('AppActionBar (equalWidth) pair never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => _scope(AppActionBar(
        equalWidth: true,
        spacing: 16,
        children: [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Replay the whole sentence again'),
          ),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Close'),
          ),
        ],
      )),
      host: LayoutHost.scrollable,
    );
  });
}

/// A compact icon-over-label button mirroring the flashcard viewer's private
/// `_ActionButton` (fixed box + scale-down label), used to prove the strip
/// wraps and each cell self-protects at any font scale.
class _MiniToolButton extends StatelessWidget {
  const _MiniToolButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 26),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 54 + 24,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, maxLines: 1),
          ),
        ),
      ],
    );
  }
}
