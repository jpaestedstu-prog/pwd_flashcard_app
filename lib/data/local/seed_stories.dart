import '../models/enums.dart';

/// A cartoon ⇄ real-life illustration pair for a tap-to-flip picture on a story
/// page or quiz item.
///
/// Both fields are direct image URLs (currently Cloudinary `.png`), passed
/// through `MediaUrlResolver` at display time — which also accepts a
/// share-page link such as `https://postimg.cc/<id>` — and cached by
/// `StoryImageService`. A null pair on a page/question/option simply means
/// "no flip illustration here", so the rest of the UI is unaffected.
class StoryImagePair {
  /// Cartoon (illustrated) version — shown first, before the user taps.
  final String cartoonUrl;

  /// Real-life photograph — revealed when the user taps the cartoon.
  final String realUrl;

  const StoryImagePair({required this.cartoonUrl, required this.realUrl});
}

/// A question within a story for reading comprehension.
class StoryQuestion {
  final String questionEn;
  final String questionFil;
  final List<String> optionsEn;
  final List<String> optionsFil;
  final int correctIndex;

  /// Optional Filipino Sign Language clip for the question prompt, given as a
  /// direct media URL (currently Cloudinary `.mp4`). Null when this story has
  /// no sign-language track yet.
  final String? fslVideoUrl;

  /// Optional FSL clips for each answer option, parallel to [optionsEn] /
  /// [optionsFil], in the same direct-URL form as [fslVideoUrl]. Empty when
  /// unavailable; individual entries may be null so a partial set still works.
  /// Use [fslForOption] for safe, bounds-checked lookups.
  final List<String?> optionFslUrls;

  /// Optional cartoon ⇄ real-life flip illustration for the question prompt.
  /// Null when this question has no picture.
  final StoryImagePair? image;

  /// Optional flip illustrations for each answer option, parallel to
  /// [optionsEn] / [optionsFil]. Empty when unavailable; individual entries may
  /// be null. Use [imageForOption] for safe, bounds-checked lookups.
  final List<StoryImagePair?> optionImages;

  const StoryQuestion({
    required this.questionEn,
    required this.questionFil,
    required this.optionsEn,
    required this.optionsFil,
    required this.correctIndex,
    this.fslVideoUrl,
    this.optionFslUrls = const [],
    this.image,
    this.optionImages = const [],
  });

  /// FSL clip share-page URL for option [index], or null when none is
  /// registered (out of range or explicitly absent).
  String? fslForOption(int index) =>
      (index >= 0 && index < optionFslUrls.length)
      ? optionFslUrls[index]
      : null;

  /// Cartoon/real-life flip pair for option [index], or null when none is
  /// registered (out of range or explicitly absent).
  StoryImagePair? imageForOption(int index) =>
      (index >= 0 && index < optionImages.length) ? optionImages[index] : null;
}

/// A short story using vocabulary words for reading comprehension.
class Story {
  final String id;
  final String titleEn;
  final String titleFil;
  final List<String> sentencesEn;
  final List<String> sentencesFil;
  final List<String> vocabularyWordIds; // flashcard IDs used in this story
  final List<StoryQuestion> questions;
  final FlashcardCategory category;
  final String emoji; // visual indicator instead of image

  /// Optional Filipino Sign Language clips, parallel to [sentencesEn] /
  /// [sentencesFil] — one per story page. Empty when the story has no
  /// sign-language track; individual entries may be null. Use [fslForSentence]
  /// for safe, bounds-checked lookups.
  final List<String?> sentenceFslUrls;

  /// Optional cartoon ⇄ real-life flip illustrations, parallel to
  /// [sentencesEn] / [sentencesFil] — one per story page. Empty when the story
  /// has no pictures; individual entries may be null. Use [imageForSentence]
  /// for safe, bounds-checked lookups.
  final List<StoryImagePair?> sentenceImages;

  const Story({
    required this.id,
    required this.titleEn,
    required this.titleFil,
    required this.sentencesEn,
    required this.sentencesFil,
    required this.vocabularyWordIds,
    required this.questions,
    required this.category,
    required this.emoji,
    this.sentenceFslUrls = const [],
    this.sentenceImages = const [],
  });

  /// FSL clip share-page URL for the sentence at [index], or null when none is
  /// registered (out of range or explicitly absent).
  String? fslForSentence(int index) =>
      (index >= 0 && index < sentenceFslUrls.length)
      ? sentenceFslUrls[index]
      : null;

  /// Cartoon/real-life flip pair for the sentence at [index], or null when none
  /// is registered (out of range or explicitly absent).
  StoryImagePair? imageForSentence(int index) =>
      (index >= 0 && index < sentenceImages.length)
      ? sentenceImages[index]
      : null;
}

/// Pre-loaded stories for all 6 categories (2–3 per category).
class SeedStories {
  SeedStories._();

  static List<Story> get all => [
    ..._animalStories,
    ..._colorStories,
    ..._numberStories,
    ..._bodyStories,
    ..._foodStories,
    ..._familyStories,
    ..._clothingStories,
    ..._weatherStories,
    ..._classroomStories,
    ..._transportationStories,
    ..._emotionStories,
    ..._daysAndTimeStories,
  ];

  static List<Story> getByCategory(FlashcardCategory category) {
    return all.where((s) => s.category == category).toList();
  }

  // ─── Animals ───────────────────────────────────────

  static final _animalStories = [
    const Story(
      id: 's_a01',
      titleEn: 'A Day at the Farm',
      titleFil: 'Isang Araw sa Bukid',
      emoji: '🐄',
      category: FlashcardCategory.animals,
      vocabularyWordIds: ['a01', 'a07', 'a08', 'a09'],
      sentencesEn: [
        'Anna woke up early to visit the farm.',
        'She saw a big cow eating grass in the field.',
        'A friendly dog ran to greet her at the gate.',
        'The chicken was walking with its little chicks.',
        'The pig was rolling happily in the mud.',
      ],
      sentencesFil: [
        'Maaga nagising si Anna para bisitahin ang bukid.',
        'Nakita niya ang isang malaking baka na kumakain ng damo.',
        'Isang magiliw na aso ang tumakbo para salubungin siya.',
        'Ang manok ay naglalakad kasama ang mga sisiw nito.',
        'Ang baboy ay masayang gumugulong sa putik.',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250769/STORY_1_bxhfru.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250770/STORY_2_sftvtc.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250818/STORY_3_zwoi7s.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250771/STORY_4_yheon0.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250818/STORY_5_cqm4xo.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165067/STORY_1_sjsqab.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241294/STORY_1_qfntb2.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165081/STORY_2_lwr8js.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241308/STORY_2_skb546.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165081/STORY_3_wlpeob.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241308/STORY_3_xdc6mf.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165071/STORY_4_jqq7qm.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241306/STORY_4_ke8sih.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165075/STORY_5_swkjz6.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241308/STORY_5_jgl5ho.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'Where did Anna visit?',
          questionFil: 'Saan bumisita si Anna?',
          optionsEn: ['The beach', 'The farm', 'The school'],
          optionsFil: ['Sa beach', 'Sa bukid', 'Sa paaralan'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250757/QUESTION_1_wrj2nk.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250757/QUESTION_1_-_A_rjuqwn.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250757/QUESTION_1_-_B_apolko.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250759/QUESTION_1_-_C_fxzvlm.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165058/QUESTION_1_co07mc.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241248/QUESTION_1_ehpyw9.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165049/QUESTION_1_-_A_dkqkk4.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241253/QUESTION_1_-_A_a6ojp4.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165053/QUESTION_1_-_B_m9hfxi.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241259/QUESTION_1_-_B_rwkq0t.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165054/QUESTION_1_-_C_ys8phu.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241258/QUESTION_1_-_C_qlnsey.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What was the cow doing?',
          questionFil: 'Ano ang ginagawa ng baka?',
          optionsEn: ['Sleeping', 'Eating grass', 'Drinking water'],
          optionsFil: ['Natutulog', 'Kumakain ng damo', 'Umiinom ng tubig'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250758/QUESTION_2_weiidk.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250758/QUESTION_2_-_A_enxawm.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250757/QUESTION_2_-_B_iuyykq.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250758/QUESTION_2_-_C_dpjcnr.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165080/QUESTION_2_txvmqy.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241279/QUESTION_2_aztylk.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165053/QUESTION_2_-_A_gyqokg.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241278/QUESTION_2_-_A_old5rp.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165061/QUESTION_2_-_B_qajjqf.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241285/QUESTION_2_-_B_vm44kw.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165081/QUESTION_2_-_C_pbmjvd.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241258/QUESTION_2_-_C_lqr8gd.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What was the pig doing?',
          questionFil: 'Ano ang ginagawa ng baboy?',
          optionsEn: ['Eating food', 'Swimming', 'Rolling in mud'],
          optionsFil: ['Kumakain', 'Lumalangoy', 'Gumugulong sa putik'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250760/QUESTION_3_o9ru4b.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250757/QUESTION_3_-_A_ewglke.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250758/QUESTION_3_-_B_rfplr3.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250760/QUESTION_3_-_C_ylzpjc.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165067/QUESTION_3_fbgvbj.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241303/QUESTION_3_lfgu2n.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165082/QUESTION_3_-_A_jvulfx.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241278/QUESTION_3_-_A_vm1css.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165060/QUESTION_3_-_B_e0fdgp.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241288/QUESTION_3_-_B_osqiao.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165067/QUESTION_3_-_C_lis14a.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785241289/QUESTION_3_-_C_bthsur.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_a02',
      titleEn: 'The Bird and the Fish',
      titleFil: 'Ang Ibon at ang Isda',
      emoji: '🐦',
      category: FlashcardCategory.animals,
      vocabularyWordIds: ['a03', 'a04', 'a05', 'a10'],
      sentencesEn: [
        'A little bird sat on a branch near the pond.',
        'It watched a fish swim around in the clear water.',
        'A colorful butterfly flew past them both.',
        'The frog jumped from a rock into the water with a splash!',
        'The bird sang a happy song for all its friends.',
      ],
      sentencesFil: [
        'Isang maliit na ibon ang umupo sa sanga malapit sa lawa.',
        'Pinanood nito ang isda na lumangoy sa malinaw na tubig.',
        'Isang makulay na paru-paro ang lumipad sa pagitan nila.',
        'Ang palaka ay tumalon mula sa bato papunta sa tubig!',
        'Ang ibon ay umawit ng masayang kanta para sa mga kaibigan.',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'Where was the bird sitting?',
          questionFil: 'Saan nakaupo ang ibon?',
          optionsEn: ['On a rock', 'On a branch', 'On the ground'],
          optionsFil: ['Sa bato', 'Sa sanga', 'Sa lupa'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What did the frog do?',
          questionFil: 'Ano ang ginawa ng palaka?',
          optionsEn: ['Flew away', 'Jumped into water', 'Climbed a tree'],
          optionsFil: ['Lumipad palayo', 'Tumalon sa tubig', 'Umakyat sa puno'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What did the bird do at the end?',
          questionFil: 'Ano ang ginawa ng ibon sa huli?',
          optionsEn: ['Fell asleep', 'Flew away', 'Sang a song'],
          optionsFil: ['Nakatulog', 'Lumipad palayo', 'Umawit ng kanta'],
          correctIndex: 2,
        ),
      ],
    ),
  ];

  // ─── Colors & Shapes ──────────────────────────────

  static final _colorStories = [
    const Story(
      id: 's_c01',
      titleEn: 'The Rainbow Garden',
      titleFil: 'Ang Hardin ng Bahaghari',
      emoji: '🌈',
      category: FlashcardCategory.colorsAndShapes,
      vocabularyWordIds: ['c01', 'c02', 'c03', 'c04', 'c06'],
      sentencesEn: [
        'Maria went to a beautiful garden after the rain.',
        'She saw red roses and yellow sunflowers.',
        'The leaves on the trees were green and fresh.',
        'Pretty purple flowers grew beside the path.',
        'The sky above was bright blue with a rainbow!',
      ],
      sentencesFil: [
        'Pumunta si Maria sa isang magandang hardin pagkatapos ng ulan.',
        'Nakita niya ang mga pulang rosas at dilaw na sunflower.',
        'Ang mga dahon ng puno ay berde at sariwa.',
        'Mga magandang lilang bulaklak ang tumubo sa tabi ng daan.',
        'Ang langit sa itaas ay maliwanag na asul na may bahaghari!',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250880/STORY_1_xrdqmw.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250881/STORY_2_e6ujmv.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250883/STORY_3_popzpc.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250895/STORY_4_yglv5r.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250901/STORY_5_xng3na.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165464/STORY_1_kauvwj.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165515/STORY_1_p8zmcy.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165469/STORY_2_hpsijm.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165512/STORY_2_zqjc94.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165472/STORY_3_ti5lvw.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165511/STORY_3_cg2zx2.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165472/STORY_4_dhwf7o.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165501/STORY_4_kqhlzx.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165473/STORY_5_cho74e.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165497/STORY_5_x3zftv.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'When did Maria go to the garden?',
          questionFil: 'Kailan pumunta si Maria sa hardin?',
          optionsEn: ['Before school', 'After the rain', 'In the morning'],
          optionsFil: ['Bago mag-aral', 'Pagkatapos ng ulan', 'Sa umaga'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250855/QUESTION_1_atod8q.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250772/QUESTION_1_-_A_vtbdpw.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250763/QUESTION_1_-_B_sxht0c.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250806/QUESTION_1_-_C_cj7tjn.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165474/QUESTION_1_licauo.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165516/QUESTION_1_r6y38g.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165475/QUESTION_1_-_A_cwhp84.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165508/QUESTION_1_-_A_aviodj.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165446/QUESTION_1_-_B_n1pjte.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165512/QUESTION_1_-_B_cajych.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165449/QUESTION_1_-_C_i2iclh.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165496/QUESTION_1_-_C_hzsy02.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What color were the roses?',
          questionFil: 'Ano ang kulay ng mga rosas?',
          optionsEn: ['Blue', 'Red', 'Yellow'],
          optionsFil: ['Asul', 'Pula', 'Dilaw'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250808/QUESTION_2_c50gmo.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250798/QUESTION_2_-_A_xbrv8v.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250809/QUESTION_2_-_B_jpteqg.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250814/QUESTION_2_-_C_ap4pz1.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165458/QUESTION_2_o7ncwf.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165496/QUESTION_2_uiilhl.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165451/QUESTION_2_-_A_amnu7l.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165522/QUESTION_2_-_A_bviiqm.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165458/QUESTION_2_-_B_jm8nv5.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165492/QUESTION_2_-_B_ebds8k.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165464/QUESTION_2_-_C_witcq9.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165494/QUESTION_2_-_C_rpdhvp.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What was in the sky?',
          questionFil: 'Ano ang nasa langit?',
          optionsEn: ['A bird', 'A rainbow', 'A star'],
          optionsFil: ['Isang ibon', 'Isang bahaghari', 'Isang bituin'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250848/QUESTION_3_jyy43r.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250762/QUESTION_3_-_A_ordixm.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250796/QUESTION_3_-_B_ztngdq.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250779/QUESTION_3_-_C_bxbtao.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165470/QUESTION_3_cc4sa9.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165521/QUESTION_3_dtqsie.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165464/QUESTION_3_-_A_agofnk.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165490/QUESTION_3_-_A_zguwvb.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165458/QUESTION_3_-_B_maosig.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165507/QUESTION_3_-_B_fve4ut.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165463/QUESTION_3_-_C_h8t8r3.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165499/QUESTION_3_-_C_ab5vlp.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_c02',
      titleEn: 'Drawing Shapes',
      titleFil: 'Pagguhit ng mga Hugis',
      emoji: '🎨',
      category: FlashcardCategory.colorsAndShapes,
      vocabularyWordIds: ['c07', 'c08', 'c09', 'c10', 'c11'],
      sentencesEn: [
        'Ben loves to draw in art class.',
        'First, he drew a big circle for the sun.',
        'Then, he added a square house with a triangle roof.',
        'He put star decorations on the house wall.',
        'Finally, he drew a heart on the door for love.',
      ],
      sentencesFil: [
        'Gustong-gusto ni Ben ang mag-drawing sa art class.',
        'Una, gumuhit siya ng malaking bilog para sa araw.',
        'Pagkatapos, nagdagdag siya ng parisukat na bahay na may tatsulok na bubong.',
        'Naglagay siya ng mga bituin na dekorasyon sa dingding.',
        'Sa huli, gumuhit siya ng puso sa pinto para sa pagmamahal.',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'What shape did Ben draw for the sun?',
          questionFil: 'Anong hugis ang iginuhit ni Ben para sa araw?',
          optionsEn: ['Square', 'Circle', 'Triangle'],
          optionsFil: ['Parisukat', 'Bilog', 'Tatsulok'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What shape was the roof?',
          questionFil: 'Anong hugis ang bubong?',
          optionsEn: ['Circle', 'Star', 'Triangle'],
          optionsFil: ['Bilog', 'Bituin', 'Tatsulok'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'What did Ben draw on the door?',
          questionFil: 'Ano ang iginuhit ni Ben sa pinto?',
          optionsEn: ['A star', 'A circle', 'A heart'],
          optionsFil: ['Isang bituin', 'Isang bilog', 'Isang puso'],
          correctIndex: 2,
        ),
      ],
    ),
  ];

  // ─── Numbers ──────────────────────────────────────

  static final _numberStories = [
    const Story(
      id: 's_n01',
      titleEn: 'Counting at the Park',
      titleFil: 'Pagbibilang sa Parke',
      emoji: '🔢',
      category: FlashcardCategory.numbers,
      vocabularyWordIds: ['n01', 'n02', 'n03', 'n04', 'n05'],
      sentencesEn: [
        'Liza went to the park with her family.',
        'She saw one big tree in the middle.',
        'Two birds were sitting on its branches.',
        'Three children were playing on the swings.',
        'She counted four benches and sat on the fifth one.',
      ],
      sentencesFil: [
        'Pumunta si Liza sa parke kasama ang pamilya niya.',
        'Nakita niya ang isang malaking puno sa gitna.',
        'Dalawang ibon ang nakaupo sa mga sanga.',
        'Tatlong bata ang naglalaro sa swing.',
        'Binilang niya ang apat na upuan at umupo sa pang-lima.',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250904/STORY_1_vej3ea.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250895/STORY_2_w3pbho.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250909/STORY_3_xoslkv.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250881/STORY_4_sj1kwa.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250904/STORY_5_d6jlm0.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165660/STORY_1_de1na0.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165690/STORY_1_gxgxd7.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165659/STORY_2_fhyafg.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165700/STORY_2_ni4tld.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165663/STORY_3_bmztan.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165696/STORY_3_voug6m.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165664/STORY_4_d2jkes.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165702/STORY_4_k3otfc.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165666/STORY_5_k2r9rr.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165696/STORY_5_xjoa4p.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'How many trees did Liza see?',
          questionFil: 'Ilang puno ang nakita ni Liza?',
          optionsEn: ['Two', 'One', 'Three'],
          optionsFil: ['Dalawa', 'Isa', 'Tatlo'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250882/QUESTION_1_iipzam.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250848/QUESTION_1_-_A_vw29dl.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250811/QUESTION_1_-_B_hujnvm.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250853/QUESTION_1_-_C_cnqgv4.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165640/QUESTION_1_fd5eni.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165675/QUESTION_1_omkvu4.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165643/QUESTION_1_-_A_cxzsi0.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165670/QUESTION_1_-_A_b0e0rp.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165636/QUESTION_1_-_B_vg458c.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165672/QUESTION_1_-_B_ou9zgw.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165635/QUESTION_1_-_C_gu3exz.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165675/QUESTION_1_-_C_xrd6xk.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'How many children were playing?',
          questionFil: 'Ilang bata ang naglalaro?',
          optionsEn: ['Four', 'Two', 'Three'],
          optionsFil: ['Apat', 'Dalawa', 'Tatlo'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250882/QUESTION_2_m1dkpk.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250857/QUESTION_2_-_A_t1xwhw.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250853/QUESTION_2_-_B_yfdajj.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250855/QUESTION_2_-_C_y4unab.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165648/QUESTION_2_jpuqx1.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165682/QUESTION_2_tcm5wk.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165639/QUESTION_2_-_A_xjmsii.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165677/QUESTION_2_-_A_rgde4t.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165644/QUESTION_2_-_B_hbpkny.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165678/QUESTION_2_-_B_b1vjek.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165646/QUESTION_2_-_C_x34elg.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165680/QUESTION_2_-_C_oogsnq.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'Which bench did Liza sit on?',
          questionFil: 'Sa aling upuan umupo si Liza?',
          optionsEn: ['The first', 'The third', 'The fifth'],
          optionsFil: ['Sa una', 'Sa pangatlo', 'Sa pang-lima'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250851/QUESTION_3_z4nbni.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250878/QUESTION_3_-_A_nk0kcf.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250846/QUESTION_3_-_B_pebqff.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250810/QUESTION_3_-_C_nxxsit.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165656/QUESTION_3_ewtgal.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165693/QUESTION_3_xyussc.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165650/QUESTION_3_-_A_egurk2.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165685/QUESTION_3_-_A_k2q1ny.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165654/QUESTION_3_-_B_xxxwhz.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165687/QUESTION_3_-_B_fvgppz.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165652/QUESTION_3_-_C_iexjwv.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785165689/QUESTION_3_-_C_xbeir4.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_n02',
      titleEn: 'My Number Book',
      titleFil: 'Ang Aklat ng mga Numero Ko',
      emoji: '📖',
      category: FlashcardCategory.numbers,
      vocabularyWordIds: ['n06', 'n07', 'n08', 'n09', 'n10'],
      sentencesEn: [
        'Jake made a counting book for school.',
        'He drew six stars on the first page.',
        'On the next page, he drew seven balloons.',
        'Then he drew eight flowers and nine butterflies.',
        'The last page had ten happy smiley faces!',
      ],
      sentencesFil: [
        'Gumawa si Jake ng counting book para sa paaralan.',
        'Gumuhit siya ng anim na bituin sa unang pahina.',
        'Sa sunod na pahina, gumuhit siya ng pitong lobo.',
        'Pagkatapos ay gumuhit siya ng walong bulaklak at siyam na paru-paro.',
        'Ang huling pahina ay may sampung masasayang mukha!',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'How many stars did Jake draw?',
          questionFil: 'Ilang bituin ang iginuhit ni Jake?',
          optionsEn: ['Five', 'Six', 'Seven'],
          optionsFil: ['Lima', 'Anim', 'Pito'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'How many flowers did Jake draw?',
          questionFil: 'Ilang bulaklak ang iginuhit ni Jake?',
          optionsEn: ['Eight', 'Nine', 'Ten'],
          optionsFil: ['Walo', 'Siyam', 'Sampu'],
          correctIndex: 0,
        ),
        StoryQuestion(
          questionEn: 'What was on the last page?',
          questionFil: 'Ano ang nasa huling pahina?',
          optionsEn: ['Butterflies', 'Stars', 'Smiley faces'],
          optionsFil: ['Mga paru-paro', 'Mga bituin', 'Mga masasayang mukha'],
          correctIndex: 2,
        ),
      ],
    ),
  ];

  // ─── Body Parts ───────────────────────────────────

  static final _bodyStories = [
    const Story(
      id: 's_b01',
      titleEn: 'Morning Exercise',
      titleFil: 'Ehersisyo sa Umaga',
      emoji: '🤸',
      category: FlashcardCategory.bodyParts,
      vocabularyWordIds: ['b01', 'b06', 'b07', 'b11', 'b12'],
      sentencesEn: [
        'Every morning, the class starts with exercise.',
        'First, they touch their head and nod.',
        'They clap their hands and stomp their feet.',
        'They roll their shoulders round and round.',
        'They bend their knees up and down — exercise is fun!',
      ],
      sentencesFil: [
        'Tuwing umaga, nagsisimula ang klase sa ehersisyo.',
        'Una, hinawakan nila ang kanilang ulo at tumango.',
        'Pumalakpak sila ng kanilang mga kamay at tumapak ng paa.',
        'Iniikot nila ang kanilang mga balikat.',
        'Binabali nila ang mga tuhod pataas at pababa — masaya ang ehersisyo!',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250893/STORY_1_jclp6h.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250902/STORY_2_mxqfop.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250899/STORY_3_pfge8j.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250905/STORY_4_btxcrx.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250908/STORY_5_asqzge.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166079/STORY_1_rdaa5a.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166081/STORY_1_mqrxws.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166073/STORY_2_eqzz5i.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166096/STORY_2_dzl1sv.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166077/STORY_3_zyvuug.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166094/STORY_3_i9igby.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166064/STORY_4_o6x9cn.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166070/STORY_4_ezbut9.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166066/STORY_5_z7ziwl.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166083/STORY_5_f5zwf3.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'When do they exercise?',
          questionFil: 'Kailan sila nag-eehersisyo?',
          optionsEn: ['After lunch', 'Every morning', 'Before bed'],
          optionsFil: [
            'Pagkatapos ng tanghalian',
            'Tuwing umaga',
            'Bago matulog',
          ],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250853/QUESTION_1_bte2vr.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250807/QUESTION_1_-_A_usxbqy.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250850/QUESTION_1_-_B_cmaswp.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250852/QUESTION_1_-_C_zqqbam.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166058/QUESTION_1_zusiql.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166044/QUESTION_1_cc3kgv.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166030/QUESTION_1_-_A_qo4dbp.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166030/QUESTION_1_-_A_crtzwt.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166047/QUESTION_1_-_B_dijr7g.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166032/QUESTION_1_-_B_aaci4n.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166056/QUESTION_1_-_C_on8vdi.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166033/QUESTION_1_-_C_kncnjz.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What did they do with their hands?',
          questionFil: 'Ano ang ginawa nila sa kanilang mga kamay?',
          optionsEn: ['Waved', 'Clapped', 'Pointed'],
          optionsFil: ['Kumaway', 'Pumalakpak', 'Nagturo'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250875/QUESTION_2_hopk3p.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250807/QUESTION_2_-_A_zojlwc.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250848/QUESTION_2_-_B_afyzc6.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250846/QUESTION_2_-_C_irlor0.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166091/QUESTION_2_g5c5zr.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166040/QUESTION_2_owdzxb.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166054/QUESTION_2_-_A_aa2jlr.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166038/QUESTION_2_-_A_mkzdmp.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166068/QUESTION_2_-_B_tc988h.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166036/QUESTION_2_-_B_jhd2ri.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166060/QUESTION_2_-_C_zjasc7.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166046/QUESTION_2_-_C_zojuof.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What body part did they bend?',
          questionFil: 'Anong bahagi ng katawan ang kanilang binali?',
          optionsEn: ['Elbows', 'Knees', 'Wrists'],
          optionsFil: ['Mga siko', 'Mga tuhod', 'Mga pulso'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250878/QUESTION_3_rsfuug.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250878/QUESTION_3_-_A_lf9vai.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250895/QUESTION_3_-_B_bqb5v0.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250850/QUESTION_3_-_C_dfzuc1.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166085/QUESTION_3_vqbjps.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166089/QUESTION_3_gelpya.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166062/QUESTION_3_-_A_m42iew.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166041/QUESTION_3_-_A_sunvxy.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166049/QUESTION_3_-_B_q3zuhq.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166074/QUESTION_3_-_B_hgr557.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166052/QUESTION_3_-_C_gty4xe.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166087/QUESTION_3_-_C_inlewc.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_b02',
      titleEn: 'My Five Senses',
      titleFil: 'Ang Limang Pandama Ko',
      emoji: '👀',
      category: FlashcardCategory.bodyParts,
      vocabularyWordIds: ['b02', 'b03', 'b04', 'b05', 'b08'],
      sentencesEn: [
        'Our body helps us sense the world around us!',
        'We use our eyes to see beautiful things.',
        'Our ears help us hear music and voices.',
        'With our nose, we can smell yummy food.',
        'We use our mouth to taste and our fingers to touch.',
      ],
      sentencesFil: [
        'Tinutulungan tayo ng katawan natin na madama ang mundo!',
        'Ginagamit natin ang ating mga mata para makakita.',
        'Ang ating tenga ay tumutulong sa atin na makarinig ng musika.',
        'Sa ating ilong, naamoy natin ang masarap na pagkain.',
        'Ginagamit natin ang bibig para matikman at ang daliri para mahawakan.',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'What do we use to see?',
          questionFil: 'Ano ang ginagamit natin para makakita?',
          optionsEn: ['Ears', 'Eyes', 'Nose'],
          optionsFil: ['Tenga', 'Mata', 'Ilong'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What helps us hear?',
          questionFil: 'Ano ang tumutulong sa atin para makarinig?',
          optionsEn: ['Mouth', 'Fingers', 'Ears'],
          optionsFil: ['Bibig', 'Daliri', 'Tenga'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'What do we smell with?',
          questionFil: 'Saan natin naaaamoy?',
          optionsEn: ['Nose', 'Mouth', 'Hands'],
          optionsFil: ['Ilong', 'Bibig', 'Kamay'],
          correctIndex: 0,
        ),
      ],
    ),
  ];

  // ─── Food & Drinks ────────────────────────────────

  static final _foodStories = [
    const Story(
      id: 's_f01',
      titleEn: 'Breakfast Time',
      titleFil: 'Oras ng Almusal',
      emoji: '🍳',
      category: FlashcardCategory.foodAndDrinks,
      vocabularyWordIds: ['f01', 'f02', 'f04', 'f05', 'f07'],
      sentencesEn: [
        'Carlo woke up hungry this morning.',
        'Mama cooked rice and eggs for breakfast.',
        'He drank a glass of cold milk.',
        'For dessert, he ate a red apple.',
        'He also drank water to stay healthy.',
      ],
      sentencesFil: [
        'Nagising si Carlo na gutom ngayong umaga.',
        'Nagluto si Mama ng kanin at itlog para sa almusal.',
        'Uminom siya ng isang basong malamig na gatas.',
        'Para sa dessert, kumain siya ng pulang mansanas.',
        'Uminom din siya ng tubig para maging malusog.',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250867/STORY_1_apcm8a.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250830/STORY_2_l5szzw.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250829/STORY_3_ros8dj.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250830/STORY_4_cgpyre.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250889/STORY_5_t3pp3e.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166813/STORY_1_nljulg.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166850/STORY_1_oryxnu.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166817/STORY_2_zvau0f.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166852/STORY_2_wzbkyx.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166816/STORY_3_rriymx.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166859/STORY_3_x52yyi.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166820/STORY_4_d9grnb.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166854/STORY_4_itxhvf.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166824/STORY_5_ccqpf8.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166856/STORY_5_dsmw5g.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'Who cooked breakfast?',
          questionFil: 'Sino ang nagluto ng almusal?',
          optionsEn: ['Carlo', 'Mama', 'Papa'],
          optionsFil: ['Si Carlo', 'Si Mama', 'Si Papa'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250787/QUESTION_1_rrgvyh.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250771/QUESTION_1_-_A_ijscil.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250759/QUESTION_1_-_B_oxn6oq.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250771/QUESTION_1_-_C_zbhpsn.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166796/QUESTION_1_y2c0vr.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166833/QUESTION_1_pllcuz.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166792/QUESTION_1_-_A_bpwf3u.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166822/QUESTION_1_-_A_i8bsos.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166791/QUESTION_1_-_B_aftwbc.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166829/QUESTION_1_-_B_csy2fm.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166789/QUESTION_1_-_C_i8cx7m.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166826/QUESTION_1_-_C_hjlysp.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What did Carlo eat with rice?',
          questionFil: 'Ano ang kinain ni Carlo kasama ng kanin?',
          optionsEn: ['Bread', 'Eggs', 'Banana'],
          optionsFil: ['Tinapay', 'Itlog', 'Saging'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250829/QUESTION_2_cybb9j.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250762/QUESTION_2_-_A_rinf5y.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250760/QUESTION_2_-_B_s1z8lp.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250818/QUESTION_2_-_C_psxwij.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166801/QUESTION_2_luin5c.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166839/QUESTION_2_xr9hoy.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166794/QUESTION_2_-_A_ev8rvk.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166835/QUESTION_2_-_A_geyahq.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166803/QUESTION_2_-_B_ay3sqy.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166831/QUESTION_2_-_B_d7z7nq.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166798/QUESTION_2_-_C_rggfzg.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166837/QUESTION_2_-_C_cv5b1d.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What fruit did Carlo eat?',
          questionFil: 'Anong prutas ang kinain ni Carlo?',
          optionsEn: ['Banana', 'Apple', 'Orange'],
          optionsFil: ['Saging', 'Mansanas', 'Kahel'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250818/QUESTION_3_cvg4ve.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250760/QUESTION_3_-_A_zqga22.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250760/QUESTION_3_-_B_lqhqyb.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250819/QUESTION_3_-_C_dsh9zk.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166811/QUESTION_3_igjvhv.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166848/QUESTION_3_n3ert3.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166807/QUESTION_3_-_A_pyrrre.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166841/QUESTION_3_-_A_ok09q0.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166804/QUESTION_3_-_B_apqwsn.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166843/QUESTION_3_-_B_prhvpd.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166809/QUESTION_3_-_C_lhezxe.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166846/QUESTION_3_-_C_alctby.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_f02',
      titleEn: 'The School Lunch',
      titleFil: 'Tanghalian sa Paaralan',
      emoji: '🍱',
      category: FlashcardCategory.foodAndDrinks,
      vocabularyWordIds: ['f03', 'f06', 'f08', 'f09', 'f10'],
      sentencesEn: [
        'It was lunchtime at school!',
        'Nina opened her lunch box and found chicken and vegetables.',
        'Her friend shared a banana for snack.',
        'They drank orange juice from their bottles.',
        'Nina also had bread for a little extra treat.',
      ],
      sentencesFil: [
        'Oras na ng tanghalian sa paaralan!',
        'Binuksan ni Nina ang lunch box at nakita ang manok at gulay.',
        'Ibinahagi ng kaibigan niya ang isang saging para sa meryenda.',
        'Uminom sila ng katas ng kahel mula sa kanilang mga bote.',
        'May tinapay din si Nina para sa dagdag na meryenda.',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'What was in Nina\'s lunch box?',
          questionFil: 'Ano ang nasa lunch box ni Nina?',
          optionsEn: [
            'Rice and soup',
            'Chicken and vegetables',
            'Bread and milk',
          ],
          optionsFil: ['Kanin at sabaw', 'Manok at gulay', 'Tinapay at gatas'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What fruit did her friend share?',
          questionFil: 'Anong prutas ang ibinahagi ng kaibigan niya?',
          optionsEn: ['Apple', 'Banana', 'Candy'],
          optionsFil: ['Mansanas', 'Saging', 'Kendi'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What did they drink?',
          questionFil: 'Ano ang ininom nila?',
          optionsEn: ['Water', 'Milk', 'Orange juice'],
          optionsFil: ['Tubig', 'Gatas', 'Katas ng kahel'],
          correctIndex: 2,
        ),
      ],
    ),
  ];

  // ─── Family & Greetings ────────────────────────────

  static final _familyStories = [
    const Story(
      id: 's_g01',
      titleEn: 'A Family Sunday',
      titleFil: 'Linggo ng Pamilya',
      emoji: '👨‍👩‍👧‍👦',
      category: FlashcardCategory.familyAndGreetings,
      vocabularyWordIds: ['g01', 'g02', 'g03', 'g04', 'g07'],
      sentencesEn: [
        'Every Sunday, the family spends time together.',
        'Mother cooks a special meal for everyone.',
        'Father helps clean the house.',
        'Brother and sister play in the garden.',
        '"Hello, Lola!" they shout when Grandmother arrives.',
      ],
      sentencesFil: [
        'Tuwing Linggo, nagsasama-sama ang pamilya.',
        'Nagluluto si Nanay ng espesyal na pagkain para sa lahat.',
        'Tinutulungan ni Tatay na linisin ang bahay.',
        'Naglalaro sa hardin ang kapatid na lalaki at babae.',
        '"Kumusta, Lola!" sigaw nila nang dumating ang Lola.',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250900/STORY_1_exbu51.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250895/STORY_2_blvmes.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250849/STORY_3_k72xes.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250894/STORY_4_rs7pst.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250898/STORY_5_xlq0m6.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166960/STORY_1_ht4nyf.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166996/STORY_1_acaekl.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166958/STORY_2_b8unze.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166999/STORY_2_mbmdhu.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166965/STORY_3_gdl5w7.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167005/STORY_3_x0xod1.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166963/STORY_4_qdm22p.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167004/STORY_4_gwozg5.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166967/STORY_5_kukacn.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167001/STORY_5_wglo3y.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'When does the family spend time together?',
          questionFil: 'Kailan nagsasama-sama ang pamilya?',
          optionsEn: ['Monday', 'Friday', 'Sunday'],
          optionsFil: ['Lunes', 'Biyernes', 'Linggo'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250857/QUESTION_1_ezalhy.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250796/QUESTION_1_-_A_u2lgud.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250805/QUESTION_1_-_B_ct79jz.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250804/QUESTION_1_-_C_m7acj4.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166938/QUESTION_1_j8xuhg.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166976/QUESTION_1_x47iae.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166933/QUESTION_1_-_A_yr9wdp.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166969/QUESTION_1_-_A_fkoxdy.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166931/QUESTION_1_-_B_jfjb0g.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166971/QUESTION_1_-_B_wf8xdi.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166936/QUESTION_1_-_C_oo83yx.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166974/QUESTION_1_-_C_mlwani.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What does Mother do?',
          questionFil: 'Ano ang ginagawa ni Nanay?',
          optionsEn: ['Plays games', 'Cooks a meal', 'Reads a book'],
          optionsFil: ['Naglalaro', 'Nagluluto', 'Nagbabasa ng libro'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250852/QUESTION_2_tlhdlq.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250803/QUESTION_2_-_A_kwohxv.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250850/QUESTION_2_-_B_la2x7u.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250805/QUESTION_2_-_C_ensk2b.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166947/QUESTION_2_ajucwb.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166985/QUESTION_2_opzxb7.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166940/QUESTION_2_-_A_axvi2q.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166978/QUESTION_2_-_A_a7n4bc.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166942/QUESTION_2_-_B_ez6nhg.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166980/QUESTION_2_-_B_rv5wlr.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166945/QUESTION_2_-_C_ebzkmv.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166982/QUESTION_2_-_C_prygcc.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'Who arrives at the end?',
          questionFil: 'Sino ang dumating sa huli?',
          optionsEn: ['A friend', 'The teacher', 'Grandmother'],
          optionsFil: ['Isang kaibigan', 'Ang guro', 'Ang Lola'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250847/QUESTION_3_vl2gjr.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250846/QUESTION_3_-_A_q8wmjv.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250807/QUESTION_3_-_B_jqwwrh.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250804/QUESTION_3_-_C_psth1z.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166954/QUESTION_3_yylgul.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166996/QUESTION_3_hqmrag.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166951/QUESTION_3_-_A_xjtytw.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166987/QUESTION_3_-_A_omwdsg.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166949/QUESTION_3_-_B_mov8s5.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166990/QUESTION_3_-_B_tudb2t.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166956/QUESTION_3_-_C_mntxe3.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785166992/QUESTION_3_-_C_itai8t.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_g02',
      titleEn: 'Saying Nice Words',
      titleFil: 'Pagsasabi ng Magagandang Salita',
      emoji: '💬',
      category: FlashcardCategory.familyAndGreetings,
      vocabularyWordIds: ['g08', 'g09', 'g10', 'g11', 'g12'],
      sentencesEn: [
        'Every day, Mia uses kind words.',
        'In the morning she says, "Good morning, everyone!"',
        'When she wants something, she says "please."',
        'When someone helps her, she says "thank you."',
        'When she makes a mistake, she says "sorry" to her friend.',
      ],
      sentencesFil: [
        'Araw-araw, gumagamit si Mia ng magagandang salita.',
        'Sa umaga, sinasabi niya, "Magandang umaga sa lahat!"',
        'Kapag may gusto siya, sinasabi niyang "pakiusap."',
        'Kapag may tumulong sa kanya, sinasabi niyang "salamat."',
        'Kapag nagkamali siya, sinasabi niyang "pasensya" sa kaibigan niya.',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'What does Mia say in the morning?',
          questionFil: 'Ano ang sinasabi ni Mia sa umaga?',
          optionsEn: ['Goodbye', 'Good morning', 'Thank you'],
          optionsFil: ['Paalam', 'Magandang umaga', 'Salamat'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What does Mia say when she wants something?',
          questionFil: 'Ano ang sinasabi ni Mia kapag may gusto siya?',
          optionsEn: ['Sorry', 'Thank you', 'Please'],
          optionsFil: ['Pasensya', 'Salamat', 'Pakiusap'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'When does Mia say "sorry"?',
          questionFil: 'Kailan sinasabi ni Mia ang "pasensya"?',
          optionsEn: [
            'When helped',
            'When she makes a mistake',
            'In the morning',
          ],
          optionsFil: ['Kapag tinulungan', 'Kapag nagkamali siya', 'Sa umaga'],
          correctIndex: 1,
        ),
      ],
    ),
  ];

  // ─── Clothing Stories ─────────────────────────────────
  static final List<Story> _clothingStories = [
    const Story(
      id: 's_cl01',
      titleEn: 'Getting Ready for School',
      titleFil: 'Paghahanda para sa Paaralan',
      emoji: '👕',
      category: FlashcardCategory.clothing,
      vocabularyWordIds: ['cl01', 'cl02', 'cl05', 'cl08'],
      sentencesEn: [
        'Every morning, Ben gets ready for school.',
        'He puts on his white t-shirt first.',
        'Then he wears his blue pants.',
        'He puts on his school uniform on top.',
        'Finally, he wears his shoes and goes to school.',
      ],
      sentencesFil: [
        'Tuwing umaga, naghahanda si Ben para sa paaralan.',
        'Isinusuot niya muna ang kanyang puting t-shirt.',
        'Pagkatapos ay isinusuot niya ang kanyang asul na pantalon.',
        'Isinusuot niya ang kanyang uniporme sa ibabaw.',
        'Sa huli, sinusuot niya ang kanyang sapatos at pumupunta sa paaralan.',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250873/STORY_1_ibovuj.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250875/STORY_2_xjtbas.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250892/STORY_3_xqj2rj.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250844/STORY_4_jeipwa.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250891/STORY_5_xwolir.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167065/STORY_1_rxk3tg.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167104/STORY_1_dh099m.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167067/STORY_2_k3agyq.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167106/STORY_2_uvvd7r.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167069/STORY_3_q08uko.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167108/STORY_3_u72uwe.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167074/STORY_4_bmregw.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167111/STORY_4_g4sjfs.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167072/STORY_5_bldklb.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167113/STORY_5_m7fhfz.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'What does Ben put on first?',
          questionFil: 'Ano ang unang isinusuot ni Ben?',
          optionsEn: ['Shoes', 'T-shirt', 'Pants'],
          optionsFil: ['Sapatos', 'T-shirt', 'Pantalon'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250844/QUESTION_1_ptnqt5.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250798/QUESTION_1_-_A_xx5a4a.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250842/QUESTION_1_-_B_r8ozfr.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250794/QUESTION_1_-_C_kmzibb.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167043/QUESTION_1_g6sg95.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167083/QUESTION_1_vpndjp.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167036/QUESTION_1_-_A_cf7kck.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167075/QUESTION_1_-_A_i4pdus.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167038/QUESTION_1_-_B_u6uyey.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167078/QUESTION_1_-_B_aij8z7.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167041/QUESTION_1_-_C_wkpziz.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167080/QUESTION_1_-_C_phc7my.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What color are Ben\'s pants?',
          questionFil: 'Anong kulay ang pantalon ni Ben?',
          optionsEn: ['Red', 'Green', 'Blue'],
          optionsFil: ['Pula', 'Berde', 'Asul'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250842/QUESTION_2_xyn3um.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250839/QUESTION_2_-_A_prljls.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250839/QUESTION_2_-_B_rn1y62.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250844/QUESTION_2_-_C_wiepc1.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167053/QUESTION_2_nqkywi.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167092/QUESTION_2_p715on.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167045/QUESTION_2_-_A_qxcx3m.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167087/QUESTION_2_-_A_vju0bp.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167048/QUESTION_2_-_B_nvrykq.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167085/QUESTION_2_-_B_aaqm6b.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167050/QUESTION_2_-_C_obfw6w.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167089/QUESTION_2_-_C_fjenmg.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What does Ben wear last?',
          questionFil: 'Ano ang huling isinusuot ni Ben?',
          optionsEn: ['Uniform', 'Shoes', 'T-shirt'],
          optionsFil: ['Uniporme', 'Sapatos', 'T-shirt'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250872/QUESTION_3_bgbnk3.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250803/QUESTION_3_-_A_divttx.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250838/QUESTION_3_-_B_wrphj5.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250841/QUESTION_3_-_C_oiigvz.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167062/QUESTION_3_ceiaog.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167102/QUESTION_3_ghhjpx.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167055/QUESTION_3_-_A_hpz4uk.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167094/QUESTION_3_-_A_web1vf.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167057/QUESTION_3_-_B_rihpl2.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167096/QUESTION_3_-_B_suaw45.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167059/QUESTION_3_-_C_nvuzu0.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167098/QUESTION_3_-_C_z7elvu.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_cl02',
      titleEn: 'Rainy Day Outfit',
      titleFil: 'Damit sa Maulan na Araw',
      emoji: '🧥',
      category: FlashcardCategory.clothing,
      vocabularyWordIds: ['cl06', 'cl07', 'cl04', 'cl10'],
      sentencesEn: [
        'It is raining today.',
        'Lina wears her warm jacket.',
        'She puts on thick socks to keep her feet warm.',
        'She wears her cap so rain won\'t fall on her face.',
        'She also wears gloves because it is cold outside.',
      ],
      sentencesFil: [
        'Umuulan ngayon.',
        'Isinusuot ni Lina ang kanyang makapal na dyaket.',
        'Nagsusuot siya ng makapal na medyas para mainit ang paa niya.',
        'Nagsusuot siya ng sombrero para hindi mabasang ang mukha niya.',
        'Nagsusuot din siya ng guwantes dahil malamig sa labas.',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'What is the weather like?',
          questionFil: 'Ano ang lagay ng panahon?',
          optionsEn: ['Sunny', 'Rainy', 'Windy'],
          optionsFil: ['Maaraw', 'Maulan', 'Mahangin'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'Why does Lina wear a cap?',
          questionFil: 'Bakit nagsusuot ng sombrero si Lina?',
          optionsEn: [
            'To look nice',
            'So rain won\'t fall on her face',
            'To stay cool',
          ],
          optionsFil: [
            'Para maganda',
            'Para hindi mabasang ang mukha',
            'Para lumamig',
          ],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'Why does Lina wear gloves?',
          questionFil: 'Bakit nagsusuot ng guwantes si Lina?',
          optionsEn: ['It is hot', 'It is cold', 'It is sunny'],
          optionsFil: ['Mainit', 'Malamig', 'Maaraw'],
          correctIndex: 1,
        ),
      ],
    ),
  ];

  // ─── Weather Stories ──────────────────────────────────
  static final List<Story> _weatherStories = [
    const Story(
      id: 's_w01',
      titleEn: 'A Sunny Day at the Park',
      titleFil: 'Isang Maaraw na Araw sa Parke',
      emoji: '☀️',
      category: FlashcardCategory.weather,
      vocabularyWordIds: ['w01', 'w07', 'w03', 'w04'],
      sentencesEn: [
        'Today is a very sunny day.',
        'It is hot outside, so Ana brings water.',
        'In the afternoon, the sky becomes cloudy.',
        'Then it rains a little bit.',
        'After the rain, Ana sees a beautiful rainbow!',
      ],
      sentencesFil: [
        'Napakaaraw ngayon.',
        'Mainit sa labas, kaya nagdala ng tubig si Ana.',
        'Sa hapon, naging maulap ang langit.',
        'Pagkatapos ay umulan nang kaunti.',
        'Pagkatapos umulan, nakakita si Ana ng magandang bahaghari!',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250872/STORY_1_oj6whu.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250880/STORY_2_bnwkmt.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250875/STORY_3_rnhcxm.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250794/STORY_4_rd6e70.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250890/STORY_5_abudes.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167229/STORY_1_prjoid.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167277/STORY_1_h2eror.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167232/STORY_2_sd6guv.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167272/STORY_2_zjivlt.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167234/STORY_3_hzwij6.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167274/STORY_3_k7zvce.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167237/STORY_4_iioq5g.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167279/STORY_4_ckda3s.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167239/STORY_5_n3qcvp.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167282/STORY_5_zsjkvp.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'How is the weather at the start?',
          questionFil: 'Ano ang panahon sa simula?',
          optionsEn: ['Rainy', 'Sunny', 'Cloudy'],
          optionsFil: ['Maulan', 'Maaraw', 'Maulap'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250871/QUESTION_1_whgmi8.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250794/QUESTION_1_-_A_bm0vtr.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250838/QUESTION_1_-_B_ude22x.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250837/QUESTION_1_-_C_c4szhy.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167199/QUESTION_1_gwb11s.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167251/QUESTION_1_cokdai.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167207/QUESTION_1_-_A_o9nxh6.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167242/QUESTION_1_-_A_k8trz7.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167201/QUESTION_1_-_B_mhtstp.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167245/QUESTION_1_-_B_cgvm6d.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167204/QUESTION_1_-_C_a9oe4g.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167248/QUESTION_1_-_C_efxya8.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'Why does Ana bring water?',
          questionFil: 'Bakit nagdala ng tubig si Ana?',
          optionsEn: ['It is cold', 'It is hot', 'It is night'],
          optionsFil: ['Malamig', 'Mainit', 'Gabi na'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250837/QUESTION_2_wcmj7i.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250788/QUESTION_2_-_A_rvuckq.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250786/QUESTION_2_-_B_udao8t.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250786/QUESTION_2_-_C_ypphcl.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167216/QUESTION_2_amr8xu.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167260/QUESTION_2_n0xj8d.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167212/QUESTION_2_-_A_mxqvdb.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167252/QUESTION_2_-_A_frqphx.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167211/QUESTION_2_-_B_f4emby.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167255/QUESTION_2_-_B_cgdm2t.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167213/QUESTION_2_-_C_gmcird.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167257/QUESTION_2_-_C_plh78w.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What does Ana see after the rain?',
          questionFil: 'Ano ang nakita ni Ana pagkatapos ng ulan?',
          optionsEn: ['Lightning', 'A rainbow', 'A storm'],
          optionsFil: ['Kidlat', 'Bahaghari', 'Bagyo'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250842/QUESTION_3_qxyzcu.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250806/QUESTION_3_-_A_zgndbg.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250804/QUESTION_3_-_B_qhohuq.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250843/QUESTION_3_-_C_lutldi.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167227/QUESTION_3_ook1tq.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167267/QUESTION_3_dsx7uq.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167220/QUESTION_3_-_A_gfvnkv.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167262/QUESTION_3_-_A_dbdmvh.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167222/QUESTION_3_-_B_hgtvds.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167265/QUESTION_3_-_B_rhumcm.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167225/QUESTION_3_-_C_lyfncq.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167270/QUESTION_3_-_C_rvnbcu.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_w02',
      titleEn: 'The Big Storm',
      titleFil: 'Ang Malakas na Bagyo',
      emoji: '⛈️',
      category: FlashcardCategory.weather,
      vocabularyWordIds: ['w05', 'w06', 'w10', 'w02'],
      sentencesEn: [
        'One night, a big storm comes to the town.',
        'The wind blows very hard and it is very windy.',
        'Lightning flashes across the dark sky.',
        'It rains and rains all night long.',
        'In the morning, the storm is over and the sun comes out.',
      ],
      sentencesFil: [
        'Isang gabi, may dumating na malakas na bagyo sa bayan.',
        'Napakalakas ng hangin at napakahangin.',
        'Kumikidlat sa madilim na langit.',
        'Umulan nang umulan buong gabi.',
        'Sa umaga, tapos na ang bagyo at lumabas ang araw.',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'When does the storm come?',
          questionFil: 'Kailan dumating ang bagyo?',
          optionsEn: ['In the morning', 'At noon', 'At night'],
          optionsFil: ['Sa umaga', 'Sa tanghali', 'Sa gabi'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'What flashes across the sky?',
          questionFil: 'Ano ang kumikislap sa langit?',
          optionsEn: ['Rainbow', 'Lightning', 'Stars'],
          optionsFil: ['Bahaghari', 'Kidlat', 'Bituin'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What happens in the morning?',
          questionFil: 'Ano ang nangyari sa umaga?',
          optionsEn: ['More rain', 'The sun comes out', 'More wind'],
          optionsFil: ['Ulan pa', 'Lumabas ang araw', 'Hangin pa'],
          correctIndex: 1,
        ),
      ],
    ),
  ];

  // ─── Classroom Stories ────────────────────────────────
  static final List<Story> _classroomStories = [
    const Story(
      id: 's_cr01',
      titleEn: 'My First Day of School',
      titleFil: 'Ang Unang Araw Ko sa Paaralan',
      emoji: '🏫',
      category: FlashcardCategory.classroom,
      vocabularyWordIds: ['cr01', 'cr02', 'cr03', 'cr12'],
      sentencesEn: [
        'Today is Carlo\'s first day of school.',
        'His teacher gives him a new book.',
        'She also gives him a pencil and a notebook.',
        'The teacher is very kind and helpful.',
        'Carlo is happy at his new school!',
      ],
      sentencesFil: [
        'Ngayon ang unang araw ni Carlo sa paaralan.',
        'Binigay ng guro niya ang bagong aklat.',
        'Binigyan din siya ng lapis at kuwaderno.',
        'Ang guro ay napakabait at matulungin.',
        'Masaya si Carlo sa kanyang bagong paaralan!',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250870/STORY_1_xw2fsh.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250888/STORY_2_cgjeth.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250870/STORY_3_povyfl.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250888/STORY_4_c9k9ku.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250871/STORY_5_qzythw.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167359/STORY_1_azaqsc.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167401/STORY_1_v0r46f.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167366/STORY_2_onpvbz.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167406/STORY_2_c5ql9d.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167367/STORY_3_z2hyxr.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167409/STORY_3_r79vzr.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167372/STORY_4_crn1yx.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167411/STORY_4_dpxczy.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167373/STORY_5_s3ctey.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167413/STORY_5_juhgbg.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'Whose first day of school is it?',
          questionFil: 'Kanino ang unang araw sa paaralan?',
          optionsEn: ['Ana', 'Carlo', 'Ben'],
          optionsFil: ['Ana', 'Carlo', 'Ben'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250835/QUESTION_1_vyjznp.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250795/QUESTION_1_-_A_puarkz.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250762/QUESTION_1_-_B_cumqsp.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250784/QUESTION_1_-_C_x1t1ze.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167337/QUESTION_1_dmpo10.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167382/QUESTION_1_kfjrt8.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167331/QUESTION_1_-_A_ym1wc2.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167373/QUESTION_1_-_A_agcyq0.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167329/QUESTION_1_-_B_xxwgq9.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167375/QUESTION_1_-_B_swr2yg.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167334/QUESTION_1_-_C_fj08w2.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167378/QUESTION_1_-_C_zhtypv.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What does the teacher give Carlo?',
          questionFil: 'Ano ang ibinigay ng guro kay Carlo?',
          optionsEn: ['Toys', 'A book', 'Food'],
          optionsFil: ['Laruan', 'Aklat', 'Pagkain'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250835/QUESTION_2_qgjvho.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250838/QUESTION_2_-_A_pngwnz.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250787/QUESTION_2_-_B_etngwo.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250786/QUESTION_2_-_C_hvv7ex.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167347/QUESTION_2_ivzf93.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167392/QUESTION_2_uknl0h.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167339/QUESTION_2_-_A_qvxjs1.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167384/QUESTION_2_-_A_evjomd.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167342/QUESTION_2_-_B_gj8xlc.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167386/QUESTION_2_-_B_dzdoen.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167344/QUESTION_2_-_C_elbn3t.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167388/QUESTION_2_-_C_iu5eq5.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'How does Carlo feel?',
          questionFil: 'Ano ang naramdaman ni Carlo?',
          optionsEn: ['Sad', 'Scared', 'Happy'],
          optionsFil: ['Malungkot', 'Takot', 'Masaya'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250842/QUESTION_3_pf8nle.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250789/QUESTION_3_-_A_tq0cjx.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250793/QUESTION_3_-_B_j5pbqn.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250796/QUESTION_3_-_C_okdvg0.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167356/QUESTION_3_cwrmpt.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167404/QUESTION_3_oxolh1.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167349/QUESTION_3_-_A_l31jgl.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167393/QUESTION_3_-_A_ebunix.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167351/QUESTION_3_-_B_rlgrnk.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167396/QUESTION_3_-_B_lgjxmj.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167354/QUESTION_3_-_C_jqzsww.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167398/QUESTION_3_-_C_v5pdbe.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_cr02',
      titleEn: 'Art Class Fun',
      titleFil: 'Masayang Klase sa Sining',
      emoji: '🎨',
      category: FlashcardCategory.classroom,
      vocabularyWordIds: ['cr04', 'cr06', 'cr08', 'cr05'],
      sentencesEn: [
        'Today is art class day!',
        'Maria takes out her crayons and paint.',
        'She uses scissors to cut colorful paper.',
        'She uses a ruler to draw straight lines.',
        'Maria makes a beautiful picture for her mother!',
      ],
      sentencesFil: [
        'Araw ng klase sa sining ngayon!',
        'Inilabas ni Maria ang kanyang krayola at pintura.',
        'Gumamit siya ng gunting para gupitin ang makukulay na papel.',
        'Gumamit siya ng ruler para gumuhit ng tuwid na linya.',
        'Gumawa si Maria ng magandang larawan para sa kanyang nanay!',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'What class is it?',
          questionFil: 'Anong klase ngayon?',
          optionsEn: ['Math', 'Art', 'Science'],
          optionsFil: ['Matematika', 'Sining', 'Agham'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What does Maria use to cut paper?',
          questionFil: 'Ano ang ginamit ni Maria para gupitin ang papel?',
          optionsEn: ['Ruler', 'Scissors', 'Pencil'],
          optionsFil: ['Ruler', 'Gunting', 'Lapis'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'Who is the picture for?',
          questionFil: 'Para kanino ang larawan?',
          optionsEn: ['Her teacher', 'Her friend', 'Her mother'],
          optionsFil: ['Sa guro niya', 'Sa kaibigan niya', 'Sa nanay niya'],
          correctIndex: 2,
        ),
      ],
    ),
  ];

  // ─── Transportation Stories ───────────────────────────
  static final List<Story> _transportationStories = [
    const Story(
      id: 's_t01',
      titleEn: 'A Trip to the City',
      titleFil: 'Biyahe Patungo sa Lungsod',
      emoji: '🚌',
      category: FlashcardCategory.transportation,
      vocabularyWordIds: ['t01', 't02', 't09', 't12'],
      sentencesEn: [
        'Papa and Leo go to the city.',
        'They ride a bus from their town.',
        'In the city, they take a taxi to the mall.',
        'They see many cars on the busy road.',
        'Leo loves watching all the vehicles!',
      ],
      sentencesFil: [
        'Pumunta si Papa at Leo sa lungsod.',
        'Sumakay sila ng bus mula sa kanilang bayan.',
        'Sa lungsod, sumakay sila ng taksi papunta sa mall.',
        'Nakakita sila ng maraming kotse sa masikip na daan.',
        'Gustong-gusto ni Leo ang panoorin ang lahat ng sasakyan!',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250869/STORY_1_rjillv.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250892/STORY_2_sx3y3w.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250868/STORY_3_hfupnm.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250888/STORY_4_dryn6u.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250868/STORY_5_ckvh9o.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167527/STORY_1_lovl6u.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167553/STORY_1_ejrl4t.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167506/STORY_2_scnrrj.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167562/STORY_2_nyqhkk.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167491/STORY_3_rrk6le.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167514/STORY_3_dleuin.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167541/STORY_4_fffimi.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167500/STORY_4_qiu6j4.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167509/STORY_5_mieuer.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167519/STORY_5_m4hhy4.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'Where do Papa and Leo go?',
          questionFil: 'Saan pumunta si Papa at Leo?',
          optionsEn: ['The park', 'The city', 'The farm'],
          optionsFil: ['Sa parke', 'Sa lungsod', 'Sa bukid'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250834/QUESTION_1_gukb9a.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250796/QUESTION_1_-_A_bevkbq.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250780/QUESTION_1_-_B_er3knp.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250787/QUESTION_1_-_C_zovnc2.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167475/QUESTION_1_ip4ds4.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167491/QUESTION_1_ij2zdq.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167483/QUESTION_1_-_A_mf7nby.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167566/QUESTION_1_-_A_nrvopv.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167498/QUESTION_1_-_B_qjo8wc.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167545/QUESTION_1_-_B_h0ghag.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167535/QUESTION_1_-_C_sswfym.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167561/QUESTION_1_-_C_lhxhxs.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What do they ride from their town?',
          questionFil: 'Ano ang sinakyan nila mula sa bayan?',
          optionsEn: ['Car', 'Taxi', 'Bus'],
          optionsFil: ['Kotse', 'Taksi', 'Bus'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250868/QUESTION_2_uysdzn.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250786/QUESTION_2_-_A_isprki.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250785/QUESTION_2_-_B_dvfrsy.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250782/QUESTION_2_-_C_bgdzla.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167495/QUESTION_2_brzd3u.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167511/QUESTION_2_pezbhk.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167503/QUESTION_2_-_A_rpv9a2.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167530/QUESTION_2_-_A_gg6x9f.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167477/QUESTION_2_-_B_exo8iz.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167538/QUESTION_2_-_B_r8wqwu.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167481/QUESTION_2_-_C_sixn9s.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167558/QUESTION_2_-_C_me7pwp.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What is on the busy road?',
          questionFil: 'Ano ang nasa masikip na daan?',
          optionsEn: ['Animals', 'Many cars', 'Boats'],
          optionsFil: ['Mga hayop', 'Maraming kotse', 'Mga bangka'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250835/QUESTION_3_krf89m.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250837/QUESTION_3_-_A_upbt0w.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250788/QUESTION_3_-_B_h4hpng.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250794/QUESTION_3_-_C_feofws.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167522/QUESTION_3_nomthb.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167532/QUESTION_3_mekg97.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167516/QUESTION_3_-_A_jfynhv.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167548/QUESTION_3_-_A_yhajnb.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167525/QUESTION_3_-_B_ivverf.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167560/QUESTION_3_-_B_a3hgqg.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167485/QUESTION_3_-_C_nhqls7.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167540/QUESTION_3_-_C_bcspmh.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_t02',
      titleEn: 'By Land, Sea, and Air',
      titleFil: 'Sa Lupa, Dagat, at Himpapawid',
      emoji: '✈️',
      category: FlashcardCategory.transportation,
      vocabularyWordIds: ['t03', 't04', 't05', 't06'],
      sentencesEn: [
        'There are many ways to travel!',
        'A bicycle goes on the road.',
        'A train travels on tracks very fast.',
        'A ship sails across the big ocean.',
        'An airplane flies high up in the sky!',
      ],
      sentencesFil: [
        'Maraming paraan para maglakbay!',
        'Ang bisikleta ay tumatakbo sa daan.',
        'Ang tren ay naglalakbay nang napakabilis sa riles.',
        'Ang barko ay naglalayag sa malaking karagatan.',
        'Ang eroplano ay lumilipad nang mataas sa langit!',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'Where does a bicycle go?',
          questionFil: 'Saan tumatakbo ang bisikleta?',
          optionsEn: ['In the sky', 'On the road', 'On the sea'],
          optionsFil: ['Sa langit', 'Sa daan', 'Sa dagat'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What sails across the ocean?',
          questionFil: 'Ano ang naglalayag sa karagatan?',
          optionsEn: ['Airplane', 'Train', 'Ship'],
          optionsFil: ['Eroplano', 'Tren', 'Barko'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'Where does an airplane fly?',
          questionFil: 'Saan lumilipad ang eroplano?',
          optionsEn: ['On the road', 'On the water', 'In the sky'],
          optionsFil: ['Sa daan', 'Sa tubig', 'Sa langit'],
          correctIndex: 2,
        ),
      ],
    ),
  ];

  // ─── Emotion Stories ──────────────────────────────────
  static final List<Story> _emotionStories = [
    const Story(
      id: 's_e01',
      titleEn: 'A Day of Many Feelings',
      titleFil: 'Isang Araw ng Maraming Damdamin',
      emoji: '😊',
      category: FlashcardCategory.emotions,
      vocabularyWordIds: ['e01', 'e02', 'e05', 'e11'],
      sentencesEn: [
        'Today is a special day for Joy.',
        'In the morning, she feels happy because it is her birthday!',
        'She feels excited about the party later.',
        'When her friend cannot come, she feels a little sad.',
        'But then her friend surprises her at the door — she is so surprised!',
      ],
      sentencesFil: [
        'Espesyal na araw ngayon para kay Joy.',
        'Sa umaga, masaya siya dahil kaarawan niya!',
        'Nasasabik siya sa party mamaya.',
        'Nang hindi makapunta ang kaibigan niya, medyo nalungkot siya.',
        'Pero bigla siyang na-surprise ng kaibigan niya sa pintuan — nagulat siya!',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250834/STORY_1_jud6jw.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250898/STORY_2_uhpgbx.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250865/STORY_3_sxrt7d.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250885/STORY_4_bnkyiu.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250897/STORY_5_el5pno.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167662/STORY_1_yvu0ws.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167654/STORY_1_spflzn.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167626/STORY_2_dvdiwe.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167672/STORY_2_kc8v88.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167646/STORY_3_zosjok.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167643/STORY_3_oceenr.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167629/STORY_4_qv3rhm.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167664/STORY_4_sivsw4.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167659/STORY_5_pz7qfc.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167656/STORY_5_wnaqdr.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'Why is Joy happy?',
          questionFil: 'Bakit masaya si Joy?',
          optionsEn: ['It is sunny', 'It is her birthday', 'She has new shoes'],
          optionsFil: ['Maaraw', 'Kaarawan niya', 'May bago siyang sapatos'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250779/QUESTION_1_ocpbli.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250832/QUESTION_1_-_A_qjhy3w.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250778/QUESTION_1_-_B_xmwrrb.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250832/QUESTION_1_-_C_w0p6kn.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167621/QUESTION_1_ceeclo.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167632/QUESTION_1_oclbzc.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167596/QUESTION_1_-_A_kmnykq.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167594/QUESTION_1_-_A_joeuiy.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167608/QUESTION_1_-_B_tv7qiw.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167624/QUESTION_1_-_B_fpyrmf.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167590/QUESTION_1_-_C_bsr5v4.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167598/QUESTION_1_-_C_kqclpa.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'How does Joy feel when her friend cannot come?',
          questionFil:
              'Ano ang naramdaman ni Joy nang hindi makapunta ang kaibigan?',
          optionsEn: ['Angry', 'Sad', 'Excited'],
          optionsFil: ['Galit', 'Malungkot', 'Nasasabik'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250865/QUESTION_2_fpkpy0.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250776/QUESTION_2_-_A_eixtko.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250762/QUESTION_2_-_B_vtzvw8.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250776/QUESTION_2_-_C_rvyfua.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167614/QUESTION_2_ehzazw.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167615/QUESTION_2_b1q1z1.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167588/QUESTION_2_-_A_xpikoa.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167634/QUESTION_2_-_A_zhlvmk.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167613/QUESTION_2_-_B_mnsvjp.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167649/QUESTION_2_-_B_ytbtfj.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167602/QUESTION_2_-_C_x860ke.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167640/QUESTION_2_-_C_ju9boo.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What happens at the door?',
          questionFil: 'Ano ang nangyari sa pintuan?',
          optionsEn: [
            'She gets a gift',
            'Her friend surprises her',
            'She leaves',
          ],
          optionsFil: [
            'May regalo siya',
            'Na-surprise siya ng kaibigan',
            'Umalis siya',
          ],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250777/QUESTION_3_ghebzo.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250781/QUESTION_3_-_A_zj2zpg.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250833/QUESTION_3_-_B_ndqtus.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250779/QUESTION_3_-_C_vqlkh5.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167635/QUESTION_3_kisvjm.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167618/QUESTION_3_fjapyw.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167605/QUESTION_3_-_A_umre4y.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167651/QUESTION_3_-_A_jsyuls.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167638/QUESTION_3_-_B_p8cm6g.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167675/QUESTION_3_-_B_ycxwhm.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167670/QUESTION_3_-_C_lggeqk.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785167667/QUESTION_3_-_C_rqpww5.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_e02',
      titleEn: 'Learning to Be Calm',
      titleFil: 'Natutong Maging Kalmado',
      emoji: '😌',
      category: FlashcardCategory.emotions,
      vocabularyWordIds: ['e03', 'e04', 'e10', 'e12'],
      sentencesEn: [
        'Marco sometimes feels angry when things go wrong.',
        'He gets confused during hard math problems.',
        'His teacher says, "It is okay to feel scared or confused."',
        'She teaches him to take deep breaths.',
        'After breathing, Marco feels calm and tries again.',
      ],
      sentencesFil: [
        'Minsan nagagalit si Marco kapag mali ang nangyayari.',
        'Naguguluhan siya sa mahirap na problema sa math.',
        'Sabi ng guro niya, "Okay lang matakot o maguluhan."',
        'Tinuturuan siya na huminga nang malalim.',
        'Pagkatapos huminga, naging kalmado si Marco at sinubukan ulit.',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'How does Marco feel when things go wrong?',
          questionFil: 'Ano ang naramdaman ni Marco kapag mali ang nangyayari?',
          optionsEn: ['Happy', 'Angry', 'Sleepy'],
          optionsFil: ['Masaya', 'Galit', 'Inaantok'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What does the teacher teach Marco?',
          questionFil: 'Ano ang itinuro ng guro kay Marco?',
          optionsEn: ['To run', 'To cry', 'To take deep breaths'],
          optionsFil: ['Tumakbo', 'Umiyak', 'Huminga nang malalim'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'How does Marco feel after breathing?',
          questionFil: 'Ano ang naramdaman ni Marco pagkatapos huminga?',
          optionsEn: ['Calm', 'Angry', 'Confused'],
          optionsFil: ['Kalmado', 'Galit', 'Naguguluhan'],
          correctIndex: 0,
        ),
      ],
    ),
  ];

  // ─── Days & Time Stories ──────────────────────────────
  static final List<Story> _daysAndTimeStories = [
    const Story(
      id: 's_d01',
      titleEn: 'My Week',
      titleFil: 'Ang Linggo Ko',
      emoji: '📅',
      category: FlashcardCategory.daysAndTime,
      vocabularyWordIds: ['d01', 'd03', 'd05', 'd06'],
      sentencesEn: [
        'Every Monday, Rina goes to school.',
        'On Wednesday, she has her favorite art class.',
        'Friday is exciting because the weekend is coming!',
        'On Saturday, Rina plays with her friends.',
        'She loves every day of the week!',
      ],
      sentencesFil: [
        'Tuwing Lunes, pumupunta si Rina sa paaralan.',
        'Tuwing Miyerkules, may paborito siyang klase sa sining.',
        'Ang Biyernes ay kapana-panabik dahil papalapit na ang weekend!',
        'Tuwing Sabado, naglalaro si Rina kasama ang mga kaibigan niya.',
        'Mahal niya ang bawat araw ng linggo!',
      ],
      // FSL sign-language clip per story page (parallel to the sentences above).
      sentenceFslUrls: [
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250870/STORY_1_qmpkku.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250865/STORY_2_tex2iz.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250885/STORY_3_xotli3.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250866/STORY_4_xqiuxa.mp4',
        'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250832/STORY_5_useeou.mp4',
      ],
      // Cartoon ⇄ real-life tap-to-flip picture per story page (parallel to the
      // sentences above). Tap the cartoon to reveal the real photograph.
      sentenceImages: [
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168272/STORY_1_hthyml.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168274/STORY_1_yg70de.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168255/STORY_2_reowrd.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168303/STORY_2_apfa3p.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168292/STORY_3_moh0ey.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168277/STORY_3_om2fsb.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168286/STORY_4_ne7tnx.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168269/STORY_4_sb5b86.png',
        ),
        StoryImagePair(
          cartoonUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168289/STORY_5_gnfcr5.png',
          realUrl:
              'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168306/STORY_5_dh6ore.png',
        ),
      ],
      questions: [
        StoryQuestion(
          questionEn: 'When does Rina go to school?',
          questionFil: 'Kailan pumupunta sa paaralan si Rina?',
          optionsEn: ['Saturday', 'Monday', 'Sunday'],
          optionsFil: ['Sabado', 'Lunes', 'Linggo'],
          correctIndex: 1,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250784/QUESTION_1_l8gekl.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250772/QUESTION_1_-_A_g3gyw1.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250771/QUESTION_1_-_B_ealakj.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250772/QUESTION_1_-_C_ouucxo.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168233/QUESTION_1_mkdkbo.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168238/QUESTION_1_hepqm4.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168226/QUESTION_1_-_A_exkur0.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168229/QUESTION_1_-_A_fbp9ny.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168309/QUESTION_1_-_B_skpigj.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168298/QUESTION_1_-_B_dblmnf.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168258/QUESTION_1_-_C_a4dnbf.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168317/QUESTION_1_-_C_geswed.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'When is art class?',
          questionFil: 'Kailan ang klase sa sining?',
          optionsEn: ['Monday', 'Friday', 'Wednesday'],
          optionsFil: ['Lunes', 'Biyernes', 'Miyerkules'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250774/QUESTION_2_v6lusw.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250762/QUESTION_2_-_A_x5po02.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250886/QUESTION_2_-_B_faser7.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250774/QUESTION_2_-_C_avbtk2.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168236/QUESTION_2_rvjexd.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168230/QUESTION_2_koqzxl.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168314/QUESTION_2_-_A_rpyssw.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168280/QUESTION_2_-_A_gffqnm.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168295/QUESTION_2_-_B_oz8m8e.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168264/QUESTION_2_-_B_fuzfay.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168261/QUESTION_2_-_C_kia6fb.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168311/QUESTION_2_-_C_x8gxs3.png',
            ), // C
          ],
        ),
        StoryQuestion(
          questionEn: 'What does Rina do on Saturday?',
          questionFil: 'Ano ang ginagawa ni Rina tuwing Sabado?',
          optionsEn: ['Study', 'Sleep', 'Play with friends'],
          optionsFil: ['Mag-aral', 'Matulog', 'Maglaro kasama mga kaibigan'],
          correctIndex: 2,
          fslVideoUrl:
              'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250832/QUESTION_3_dswqxf.mp4',
          optionFslUrls: [
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250773/QUESTION_3_-_A_vgceot.mp4', // A
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250780/QUESTION_3_-_B_hxd1de.mp4', // B
            'https://res.cloudinary.com/lorjhyp9/video/upload/v1785250830/QUESTION_3_-_C_savo39.mp4', // C
          ],
          image: StoryImagePair(
            cartoonUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168253/QUESTION_3_pvq7wj.png',
            realUrl:
                'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168266/QUESTION_3_dhpkvo.png',
          ),
          optionImages: [
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168244/QUESTION_3_-_A_qewprf.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168247/QUESTION_3_-_A_dqtsox.png',
            ), // A
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168250/QUESTION_3_-_B_sbylxn.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168241/QUESTION_3_-_B_erumyb.png',
            ), // B
            StoryImagePair(
              cartoonUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168283/QUESTION_3_-_C_eillq2.png',
              realUrl:
                  'https://res.cloudinary.com/lorjhyp9/image/upload/v1785168300/QUESTION_3_-_C_y8jhu7.png',
            ), // C
          ],
        ),
      ],
    ),
    const Story(
      id: 's_d02',
      titleEn: 'Morning, Afternoon, Evening',
      titleFil: 'Umaga, Hapon, Gabi',
      emoji: '⏰',
      category: FlashcardCategory.daysAndTime,
      vocabularyWordIds: ['d08', 'd09', 'd10', 'd11'],
      sentencesEn: [
        'In the morning, Tomas wakes up when the clock says seven.',
        'He eats breakfast and goes to school.',
        'In the afternoon, Tomas eats lunch and plays.',
        'In the evening, the family eats dinner together.',
        'Tomas looks at the clock — it is time for bed!',
      ],
      sentencesFil: [
        'Sa umaga, gumigising si Tomas kapag pito na sa orasan.',
        'Kumakain siya ng almusal at pumupunta sa paaralan.',
        'Sa hapon, kumakain si Tomas ng tanghalian at naglalaro.',
        'Sa gabi, sabay-sabay kumakain ng hapunan ang pamilya.',
        'Tiningnan ni Tomas ang orasan — oras na para matulog!',
      ],
      questions: [
        StoryQuestion(
          questionEn: 'When does Tomas wake up?',
          questionFil: 'Kailan gumigising si Tomas?',
          optionsEn: ['In the evening', 'In the afternoon', 'In the morning'],
          optionsFil: ['Sa gabi', 'Sa hapon', 'Sa umaga'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'What does the family do in the evening?',
          questionFil: 'Ano ang ginagawa ng pamilya sa gabi?',
          optionsEn: ['Play', 'Eat dinner together', 'Go to school'],
          optionsFil: [
            'Maglaro',
            'Sabay kumain ng hapunan',
            'Pumunta sa paaralan',
          ],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What time does Tomas wake up?',
          questionFil: 'Anong oras gumigising si Tomas?',
          optionsEn: ['Five', 'Seven', 'Nine'],
          optionsFil: ['Lima', 'Pito', 'Siyam'],
          correctIndex: 1,
        ),
      ],
    ),
  ];
}
