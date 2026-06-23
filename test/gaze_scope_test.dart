import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_action.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_overlay.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_scope.dart';

class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

/// Forces a particular [GazeSettings] without touching Hive.
class _FixedSettings extends GazeSettingsNotifier {
  _FixedSettings(this._value);
  final GazeSettings _value;
  @override
  GazeSettings build() => _value;
}

List<GazeAction> _actions() => const [
      GazeAction(
        zone: GazeZone.left,
        label: 'Prev',
        icon: Icons.arrow_back_rounded,
        color: Colors.teal,
        onSelect: _noop,
      ),
      GazeAction(
        zone: GazeZone.right,
        label: 'Next',
        icon: Icons.arrow_forward_rounded,
        color: Colors.green,
        onSelect: _noop,
      ),
    ];

void _noop() {}

Widget _host({
  required GazeSettings settings,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      gazeSettingsProvider.overrideWith(() => _FixedSettings(settings)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: GazeScope(
          actions: _actions(),
          camerasLoader: () async => const <CameraDescription>[],
          detectorFactory: _FakeDetector.new,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('disabled: renders child only, no overlay', (tester) async {
    await tester.pumpWidget(
      _host(
        settings: const GazeSettings(), // enabled == false
        child: const Text('content'),
      ),
    );
    await tester.pump();
    expect(find.text('content'), findsOneWidget);
    expect(find.byType(GazeOverlay), findsNothing);
  });

  testWidgets('enabled: shows the overlay over the child', (tester) async {
    await tester.pumpWidget(
      _host(
        settings: const GazeSettings(enabled: true),
        child: const Text('content'),
      ),
    );
    await tester.pump();
    expect(find.text('content'), findsOneWidget);
    expect(find.byType(GazeOverlay), findsOneWidget);
    // No camera in the test → a friendly status chip rather than a crash.
    expect(find.textContaining('no front camera'), findsOneWidget);
  });

  testWidgets('enabled: overlay lets touches fall through to the child',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        settings: const GazeSettings(enabled: true),
        child: Center(
          child: ElevatedButton(
            onPressed: () => tapped = true,
            child: const Text('beneath'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('beneath'));
    expect(tapped, isTrue);
  });

  testWidgets('scanning mode builds and tears down cleanly', (tester) async {
    await tester.pumpWidget(
      _host(
        settings: const GazeSettings(enabled: true, scanMode: true),
        child: const Text('content'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GazeScope), findsOneWidget);
    // Unmount → GazeScope.dispose cancels the scan timer (no pending-timer fail).
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
