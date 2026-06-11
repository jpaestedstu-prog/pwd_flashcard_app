import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration & initialisation helper.
///
/// **Free-tier (Spark plan) compatibility:** this app is designed to run
/// fully on Firebase's free Spark plan — no Blaze required. The only
/// Firebase products it uses are:
///   • **Firestore** (free quota: 50K reads + 20K writes per day, plenty
///     for a classroom-sized deployment)
///   • **Anonymous Authentication** (always free, no quota)
///
/// Cloud Functions are NOT used and have been removed from this project,
/// because deploying them requires Blaze. Server-side anti-cheat for the
/// progress collection is therefore not present; client-side validation
/// in [progress_sync_listener.dart] is the integrity layer. If you ever
/// upgrade to Blaze and want to re-add server-side validation, restore
/// the [functions/] folder from git history and re-add the
/// `"functions"` block to [firebase.json].
///
/// **Setup checklist for the permission-denied error in Manage Classes:**
///
///   1. **Enable Anonymous Auth** — Firebase Console → Authentication →
///      Sign-in method → Anonymous → Enable. Without this, every
///      Firestore read fails with `permission-denied` because the rules
///      require `request.auth != null`.
///   2. **Deploy the rules** — `firebase deploy --only firestore:rules`
///      from the project root. The default Firebase test-mode rules
///      expire after 30 days and then deny everything.
///   3. **One online launch per device** — the anonymous uid is created
///      on the first successful contact with Firebase Auth. After that,
///      it persists and the device can go offline indefinitely.
///
/// **Setup instructions:**
///
/// 1. Create a Firebase project at https://console.firebase.google.com
///
/// 2. Add platform apps and download config files:
///    - **Android:** download `google-services.json` and place it in
///      `android/app/google-services.json`
///    - **iOS:** download `GoogleService-Info.plist` and place it in
///      `ios/Runner/GoogleService-Info.plist`
///    - The Firebase CLI command `flutterfire configure` automates this
///      and also generates a `lib/firebase_options.dart` file. Either path
///      is fine — this service tries the platform default first.
///
/// 3. In the Firebase console, enable **Cloud Firestore** (Database →
///    Create database → start in test mode for development). The app
///    creates collections on demand; no manual schema needed.
///
/// 4. **Recommended Firestore data model** (created automatically as the
///    app writes data; included here for reference and security-rule
///    authoring):
///
///    ```
///    profiles/{profileId}
///      - id, name, role, avatarIndex, createdAt, disabilityType,
///        classroomId, isGuestPlayer
///
///    progress/{profileId}
///      - profileId, wordsLearned, streakDays, lastActivity,
///        categoryProgress (map), recentScores (array), totalStars,
///        spentStars, classroomId
///
///    custom_cards/{cardId}
///      - id, wordEnglish, wordFilipino, exampleSentence, imageAsset,
///        category, profileId
///
///    achievements/{profileId}/items/{achievementId}
///    shop_purchases/{profileId}/items/{itemId}
///    shop_equipped/{profileId}_{type}
///
///    classrooms/{classroomId}
///      - id, code (UNIQUE — enforce via security rules), name,
///        teacherId, createdAt, updatedAt
///
///    classroom_members/{classroomId}_{profileId}
///      - classroomId, profileId, displayName, joinedAt
///
///    session_logs/{autoId}
///      - profileId, date, durationSeconds, gamesPlayed, cardsReviewed
///
///    app_state/{key}
///      - key, value
///    ```
///
/// 5. **Recommended Firestore security rules** (paste into Rules tab,
///    relax for development; tighten before production):
///
///    ```
///    rules_version = '2';
///    service cloud.firestore {
///      match /databases/{database}/documents {
///        match /{document=**} {
///          allow read, write: if true;  // DEVELOPMENT ONLY
///        }
///      }
///    }
///    ```
class FirebaseService {
  FirebaseService._();

  /// Whether Firebase has been initialised successfully.
  static bool _initialised = false;

  /// Whether Firebase config is reachable.
  /// True after a successful [init]. Used by [LocalRepository._enqueue]
  /// and [JoinCodeService] to gate cloud writes.
  static bool get isConfigured => _initialised;

  /// The default Firestore client (available after [init]).
  ///
  /// Reads/writes through this instance benefit from Firestore's built-in
  /// offline persistence on mobile platforms — pending writes survive
  /// app restarts and replay automatically when the device reconnects.
  static FirebaseFirestore get db => FirebaseFirestore.instance;

  /// Anonymous-auth UID for this device, or null if sign-in hasn't
  /// completed yet (first launch offline, or Firebase init failed).
  /// Stamped onto every owner-scoped Firestore write so security rules
  /// can verify the writer.
  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// The reason init failed (when [isConfigured] is false). Surfaced in
  /// the UI banner and logs so the developer can act on it.
  static String? lastInitError;

  /// The most recent [FirebaseOptions] passed to [init]. Used by
  /// [retryInit] so callers don't have to re-import the generated
  /// `firebase_options.dart` from feature widgets.
  static FirebaseOptions? _lastUsedOptions;

  /// Initialise Firebase. Safe to call multiple times.
  ///
  /// Pass [options] from `DefaultFirebaseOptions.currentPlatform`
  /// (generated by `flutterfire configure`) — this is **required on web**
  /// and recommended on every platform for explicit project pinning.
  ///
  /// On Android/iOS, [options] may be omitted IF `google-services.json` /
  /// `GoogleService-Info.plist` are wired up via the Google Services
  /// Gradle plugin / Xcode runtime config — but this auto-detection
  /// requires `flutterfire configure` to have patched the platform build
  /// files. The CLI is the supported, low-friction path.
  ///
  /// On failure, [isConfigured] stays false and [lastInitError] holds
  /// the reason. The app continues offline-only.
  static Future<void> init({FirebaseOptions? options}) async {
    if (_initialised) return;
    _lastUsedOptions = options ?? _lastUsedOptions;
    try {
      if (options != null) {
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }
      // Enable offline persistence (mobile platforms enable it by default
      // but setting it explicitly documents intent and survives platform
      // upgrades). Wrapped in try/catch because the call is a no-op on
      // platforms where it's already on.
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (_) {
        // Settings may already be locked in if Firestore was touched
        // before this point — safe to ignore.
      }
      _initialised = true;
      lastInitError = null;
      if (kDebugMode) {
        debugPrint('✓ FirebaseService: connected to '
            '${Firebase.app().options.projectId}');
      }
    } catch (e, stack) {
      lastInitError = e.toString();
      if (kDebugMode) {
        debugPrint('✗ FirebaseService.init failed: $e\n$stack');
        debugPrint('  → Run `flutterfire configure` from the project root '
            'to generate firebase_options.dart and platform configs.');
      }
      _initialised = false;
    }
  }

  /// Sign in anonymously so every Firestore write carries a verifiable
  /// `request.auth.uid`. Anonymous Auth keeps the kid-facing UX unchanged
  /// (no sign-up, no password) while giving security rules an identity to
  /// pin owner-scoped data to.
  ///
  /// Idempotent: returns immediately if a user is already signed in.
  /// Non-throwing: failures (offline first-launch, Auth disabled in the
  /// Firebase console) are logged and the app continues offline-only.
  static Future<void> signInAnonymously() async {
    if (!_initialised) return;
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (kDebugMode) {
        debugPrint('✓ FirebaseService: anonymous uid '
            '${FirebaseAuth.instance.currentUser?.uid}');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('✗ FirebaseService.signInAnonymously failed: $e\n$stack');
        debugPrint('  → Enable Anonymous sign-in in the Firebase console: '
            'Authentication → Sign-in method → Anonymous → Enable.');
      }
    }
  }

  /// Ensures an anonymous Firebase Auth session exists *right now*, then
  /// returns the resolved uid (or null if it still couldn't be obtained).
  ///
  /// Use this before any Firestore read whose security rule starts with
  /// `if signedIn()`. If the app's startup `signInAnonymously()` raced
  /// with the user's tap (or failed silently because Anonymous auth is
  /// disabled in the console), this is the surface that surfaces the
  /// real cause instead of a generic permission-denied error downstream.
  static Future<String?> ensureSignedIn() async {
    if (!_initialised) return null;
    final existing = FirebaseAuth.instance.currentUser?.uid;
    if (existing != null) return existing;
    await signInAnonymously();
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// Whether the currently signed-in user has been upgraded from anonymous
  /// to a permanent (email-linked) account. Used by the settings UI to
  /// show "Linked to email@…" vs "Backup & Link Account".
  static bool get hasLinkedAccount {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (user.isAnonymous) return false;
    return user.email != null && user.email!.isNotEmpty;
  }

  /// Email of the linked permanent account, or null when running as
  /// anonymous. Surfaced in settings ("Linked to alice@example.com").
  static String? get linkedEmail =>
      hasLinkedAccount ? FirebaseAuth.instance.currentUser?.email : null;

  /// Link the current anonymous account to an email + password credential.
  ///
  /// Preserves the existing `User.uid`, so every `owner_uid`-stamped
  /// Firestore document continues to work — no data migration needed.
  /// After a successful link the user can sign back in on any device with
  /// the same credential and recover their full profile from Firestore.
  ///
  /// Throws [FirebaseAuthException] for known auth errors (codes:
  /// `email-already-in-use`, `weak-password`, `invalid-email`,
  /// `provider-already-linked`, `network-request-failed`). Callers should
  /// translate these to user-friendly messages.
  ///
  /// Requires [isConfigured] == true and a current anonymous session.
  static Future<void> linkAnonymousToEmail({
    required String email,
    required String password,
  }) async {
    if (!_initialised) {
      throw StateError('Firebase not initialised');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('No current user to link');
    }
    if (!user.isAnonymous) {
      throw StateError('Account is already linked to a permanent provider');
    }
    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    await user.linkWithCredential(credential);
    if (kDebugMode) {
      debugPrint('✓ FirebaseService: linked anonymous uid ${user.uid} '
          'to email ${email.trim()}');
    }
  }

  /// Sign in with an existing email/password account.
  ///
  /// This is the "restore on a new device" flow: the user installs the
  /// app fresh, lands on the anonymous session created by [signInAnonymously],
  /// then chooses "I already have an account" — which calls this method.
  /// On success, `User.uid` switches to the linked account's uid, so the
  /// caller MUST trigger a cloud-pull rehydration to repopulate Hive from
  /// the Firestore documents stamped with that uid.
  ///
  /// Throws [FirebaseAuthException] for known auth errors (codes:
  /// `user-not-found`, `wrong-password`, `invalid-email`, `user-disabled`,
  /// `network-request-failed`).
  static Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_initialised) {
      throw StateError('Firebase not initialised');
    }
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (kDebugMode) {
      debugPrint('✓ FirebaseService: signed in as '
          '${FirebaseAuth.instance.currentUser?.uid}');
    }
  }

  /// Send a password-reset email for the given address.
  ///
  /// Firebase Auth itself rate-limits these — there is no client-side
  /// throttle needed. The user receives an email with a deep link to
  /// Firebase's hosted reset page; no in-app handler required.
  static Future<void> sendPasswordReset(String email) async {
    if (!_initialised) {
      throw StateError('Firebase not initialised');
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign the current user out and immediately establish a fresh anonymous
  /// session so the app stays functional offline.
  ///
  /// Used when the user signs out of a linked account to "hand off" the
  /// device — the local Hive data is intentionally NOT cleared here; the
  /// caller is responsible for wiping local profiles if they want a clean
  /// device. (See `HiveService.clearAllData()`.)
  static Future<void> signOut() async {
    if (!_initialised) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('✗ FirebaseService.signOut failed: $e\n$stack');
      }
    }
    // Restore the anonymous fallback so cloud writes can resume.
    await signInAnonymously();
  }

  /// Re-attempt Firebase initialisation after a previous failure.
  ///
  /// Called by the CloudRetryBanner when the user taps "Retry now" — the
  /// previous fail-paths (no network, options not generated yet, console
  /// project rotated) often clear themselves between launches but require
  /// a re-init to take effect. Reuses the last [FirebaseOptions] passed to
  /// [init] so feature widgets don't have to import the generated
  /// `firebase_options.dart`.
  ///
  /// Returns whether Firebase is configured after the retry. The caller
  /// should rebuild any provider that gates on [isConfigured].
  static Future<bool> retryInit() async {
    if (_initialised) return true;
    await init(options: _lastUsedOptions);
    if (_initialised) {
      await signInAnonymously();
    }
    return _initialised;
  }
}
