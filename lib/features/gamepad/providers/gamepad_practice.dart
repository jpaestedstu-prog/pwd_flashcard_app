import 'package:flutter/foundation.dart';

/// Whether the controller practice screen is open and wants the raw buttons.
///
/// The practice screen exists so a learner can press anything and be told what
/// it does, with nothing at stake. That only works if the presses do **not**
/// also navigate — otherwise pressing R1 to find out what R1 does would open
/// something and leave the practice screen behind.
///
/// So the host stands down while this is true, with one deliberate exception:
/// **L1 still goes back.** A learner who cannot see the screen must never be
/// able to enter a mode they cannot leave, and trusting the practice screen's
/// own handling to be the only way out is exactly the kind of dead end this
/// feature exists to remove.
///
/// A [ValueNotifier] rather than a Riverpod provider so the screen can set it
/// from `initState`/`dispose` without provider-modification hazards, matching
/// the other gamepad bridges.
final ValueNotifier<bool> gamepadPractice = ValueNotifier<bool>(false);
