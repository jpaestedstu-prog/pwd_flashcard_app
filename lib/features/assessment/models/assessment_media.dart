import '../../../core/services/shared_media_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../routine/services/routine_media_store.dart';

/// Pictures, video, sound and sign language an educator attaches to an
/// assessment question, to an assignment's instructions, or to feedback on a
/// learner's work.
///
/// The same shape as a routine step's media (see `RoutineStep`), for the same
/// reasons: every slot is one string, so replacing a picture is editing one
/// value with no migration, and a slot holds any of the three sources the app
/// already understands —
///
///  * `https://…` — hosted media (the project's own clips live on Cloudinary).
///    A link reaches every device the assessment syncs to.
///  * `assets/…` — something bundled with the app.
///  * `file://…` — a file picked off *this* device, copied into app storage by
///    `AssessmentMediaStore`. It reaches only learners on this tablet until
///    it is shared.
///  * `shared://…` — a picked file once it has been shared through
///    `SharedMediaService` (Firestore, free plan), which reaches every
///    device. A file picked offline stays `file://` until it can be shared,
///    and the editor says which each one is.
///
/// [sign] is kept apart from [video] on purpose. A video is part of the
/// question and every learner sees it; a sign-language video is an
/// *alternative* to the words, shown to learners who sign — the same line
/// `AccessibilityContentPolicy.showFsl` draws everywhere else in the app.
enum AssessmentMediaKind {
  photo,
  gif,
  video,
  audio,
  // Appended last: the kinds are persisted by name, but keep the index stable
  // anyway so any ordered comparison of older data stays meaningful.
  sign,
}

extension AssessmentMediaKindX on AssessmentMediaKind {
  /// English name, for exports and anywhere a delegate is missing.
  String get label => switch (this) {
    AssessmentMediaKind.photo => 'Photo',
    AssessmentMediaKind.gif => 'GIF',
    AssessmentMediaKind.video => 'Video',
    AssessmentMediaKind.audio => 'Sound',
    AssessmentMediaKind.sign => 'FSL video',
  };

  /// Localized [label]. Takes a nullable l10n, like the other `...Of` getters
  /// in this module: these land in semantics labels on screens widget tests
  /// build without the delegate.
  String labelOf(AppLocalizations? l10n) => l10n == null
      ? label
      : switch (this) {
          AssessmentMediaKind.photo => l10n.assessMediaPhoto,
          AssessmentMediaKind.gif => l10n.assessMediaGif,
          AssessmentMediaKind.video => l10n.assessMediaVideo,
          AssessmentMediaKind.audio => l10n.assessMediaAudio,
          AssessmentMediaKind.sign => l10n.assessMediaSign,
        };

  /// Plays in a video player rather than an image widget.
  bool get isMoving =>
      this == AssessmentMediaKind.video || this == AssessmentMediaKind.sign;

  /// Shown as a picture (a GIF is an image to Flutter's decoder).
  bool get isPicture =>
      this == AssessmentMediaKind.photo || this == AssessmentMediaKind.gif;
}

/// The media attached to one question, one set of instructions, or one piece
/// of feedback. Empty slots are `''`.
class AssessmentMedia {
  final String photo;
  final String gif;
  final String video;
  final String audio;

  /// A Filipino Sign Language version of the words — the question, the
  /// instructions or the feedback, signed.
  final String sign;

  /// What the media shows or says, in words.
  ///
  /// One field doing two jobs, because they are the same text: it is read to
  /// a learner who cannot see the picture, and shown as a caption to one who
  /// cannot hear the video or the sound. On a question it must not give the
  /// answer away — the editor says so, since a picture's alt text announcing
  /// the answer is a bug this app has shipped before.
  final String description;

  const AssessmentMedia({
    this.photo = '',
    this.gif = '',
    this.video = '',
    this.audio = '',
    this.sign = '',
    this.description = '',
  });

  static const AssessmentMedia none = AssessmentMedia();

  String urlFor(AssessmentMediaKind kind) => switch (kind) {
    AssessmentMediaKind.photo => photo,
    AssessmentMediaKind.gif => gif,
    AssessmentMediaKind.video => video,
    AssessmentMediaKind.audio => audio,
    AssessmentMediaKind.sign => sign,
  };

  bool has(AssessmentMediaKind kind) => urlFor(kind).trim().isNotEmpty;

  /// The filled slots, in declaration order.
  List<AssessmentMediaKind> get supplied =>
      AssessmentMediaKind.values.where(has).toList();

  /// At least one slot is filled. A description on its own is not media.
  bool get hasAny => AssessmentMediaKind.values.any(has);

  /// Nothing to store at all.
  bool get isEmpty => !hasAny && description.trim().isEmpty;

  String get trimmedDescription => description.trim();

  /// The `file://` values in this bundle — files that live on one device.
  Set<String> get deviceFiles => {
    for (final kind in AssessmentMediaKind.values)
      if (RoutineMediaStore.isDeviceFile(urlFor(kind))) urlFor(kind).trim(),
  };

  bool get hasDeviceFiles => deviceFiles.isNotEmpty;

  /// Every value this app stored itself and must clean up when nothing
  /// refers to it any more: files on this device and shared files.
  /// Links and bundled assets belong to someone else and are never deleted.
  Set<String> get storedValues => {
    for (final kind in AssessmentMediaKind.values)
      if (RoutineMediaStore.isDeviceFile(urlFor(kind)) ||
          SharedMediaService.isShared(urlFor(kind)))
        urlFor(kind).trim(),
  };

  AssessmentMedia withSlot(AssessmentMediaKind kind, String url) {
    final v = url.trim();
    return AssessmentMedia(
      photo: kind == AssessmentMediaKind.photo ? v : photo,
      gif: kind == AssessmentMediaKind.gif ? v : gif,
      video: kind == AssessmentMediaKind.video ? v : video,
      audio: kind == AssessmentMediaKind.audio ? v : audio,
      sign: kind == AssessmentMediaKind.sign ? v : sign,
      description: description,
    );
  }

  AssessmentMedia withDescription(String text) => AssessmentMedia(
    photo: photo,
    gif: gif,
    video: video,
    audio: audio,
    sign: sign,
    description: text,
  );

  /// Only the filled keys, so a question with no media stores exactly what it
  /// stored before this existed.
  Map<String, dynamic> toJson() => {
    for (final kind in AssessmentMediaKind.values)
      if (has(kind)) kind.name: urlFor(kind).trim(),
    if (trimmedDescription.isNotEmpty) 'description': trimmedDescription,
  };

  /// Tolerant of anything: a missing field, a Hive map (`Map<dynamic,
  /// dynamic>`), or a malformed value from an older or foreign writer all read
  /// as "no media" rather than throwing inside a learner's test.
  factory AssessmentMedia.fromJson(Object? raw) {
    if (raw is! Map) return none;
    String read(String key) {
      final v = raw[key];
      return v is String ? v.trim() : '';
    }

    return AssessmentMedia(
      photo: read(AssessmentMediaKind.photo.name),
      gif: read(AssessmentMediaKind.gif.name),
      video: read(AssessmentMediaKind.video.name),
      audio: read(AssessmentMediaKind.audio.name),
      sign: read(AssessmentMediaKind.sign.name),
      description: read('description'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssessmentMedia &&
          other.photo == photo &&
          other.gif == gif &&
          other.video == video &&
          other.audio == audio &&
          other.sign == sign &&
          other.description == description;

  @override
  int get hashCode => Object.hash(photo, gif, video, audio, sign, description);
}

/// What an educator wrote — and showed, or signed — about one learner's work
/// on one assignment.
///
/// Stored on the assignment, keyed by learner, because the assignment is the
/// educator's own document: the rules already let them write it and let the
/// learner read it, so feedback needs no new collection and no rules deploy.
/// A result, by contrast, only its learner may write — which is what keeps
/// the score trustworthy, and why feedback cannot live there.
class AssessmentFeedback {
  final String note;
  final AssessmentMedia media;
  final DateTime updatedAt;

  const AssessmentFeedback({
    this.note = '',
    this.media = AssessmentMedia.none,
    required this.updatedAt,
  });

  bool get isEmpty => note.trim().isEmpty && !media.hasAny;

  Map<String, dynamic> toJson() => {
    if (note.trim().isNotEmpty) 'note': note.trim(),
    if (!media.isEmpty) 'media': media.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Null for anything unreadable, so one bad entry cannot hide the rest.
  static AssessmentFeedback? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse(raw['updatedAt']?.toString() ?? '');
    final note = raw['note'];
    final feedback = AssessmentFeedback(
      note: note is String ? note : '',
      media: AssessmentMedia.fromJson(raw['media']),
      updatedAt: at ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
    return feedback.isEmpty ? null : feedback;
  }
}
