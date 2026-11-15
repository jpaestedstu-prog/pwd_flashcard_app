import 'package:flutter/foundation.dart';

/// Hands-free control **paused by the learner**.
///
/// A learner who drives the app with their head, blinks, scanning or voice
/// sometimes needs it to stop listening for a while — to talk with a teacher,
/// to rest, to look around — without anything opening by accident. Saying
/// "stop listening" pauses it; while paused, head moves, look-and-hold and the
/// scanning highlight do nothing, and voice listens only for "resume".
///
/// Only *deliberate* inputs bring it back: saying "resume", a long blink, a
/// press on a switch or controller, or a tap on the "Paused" banner
/// (`HandsFreePausedBanner`). Head movement never does — that is exactly the
/// input a pause exists to ignore.
///
/// One app-wide flag rather than per-scope state, because the learner paused
/// *the app*, not one screen: opening a game while paused must stay paused.
final ValueNotifier<bool> handsFreePaused = ValueNotifier<bool>(false);

/// Pauses hands-free control (see [handsFreePaused]).
void pauseHandsFree() => handsFreePaused.value = true;

/// Resumes hands-free control (see [handsFreePaused]).
void resumeHandsFree() => handsFreePaused.value = false;
