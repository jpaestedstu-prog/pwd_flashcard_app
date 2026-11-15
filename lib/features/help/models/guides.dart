import 'package:flutter/material.dart';

/// The in-app **Help & Guides**: plain, step-by-step guides in English and
/// Filipino for learners, teachers and parents, and for every way of using
/// the app (touch, Gaze Control, voice, a game controller, a keyboard or
/// switch, a screen reader).
///
/// Rules for this file — the guides are only useful if they are true:
/// * Describe only what the app really does, with the names the screens
///   really show ("Settings → Accessibility → Font Size").
/// * Short sentences and everyday words: these are read by children, by
///   learners with intellectual disabilities, and aloud by the speech engine.
/// * Say what something needs (a camera, a microphone, Wi-Fi) and how to turn
///   it off again, not only how to turn it on.
///
/// Kept as Dart data rather than ARB strings: each guide is long prose in two
/// languages, and keeping both languages side by side keeps them in step.
/// `test/features/help/guides_test.dart` checks every guide is complete in
/// both languages.

/// A piece of guide text in both languages.
class GuideText {
  const GuideText(this.en, this.fil);

  final String en;
  final String fil;

  String of({required bool filipino}) => filipino ? fil : en;
}

/// One line of a section: plain text, optionally led by a bold [label]
/// ("Turn it on: …").
class GuideLine {
  const GuideLine(this.text, {this.label});

  final GuideText text;
  final GuideText? label;
}

/// A titled part of a guide. [numbered] sections are steps to follow in
/// order; the others are lists.
class GuideSection {
  const GuideSection(this.heading, this.lines, {this.numbered = false});

  final GuideText heading;
  final List<GuideLine> lines;
  final bool numbered;
}

/// Who a guide is mainly for — it decides the order on the Help page and
/// whether a child sees it.
enum GuideAudience { everyone, learners, educators }

class Guide {
  const Guide({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.summary,
    required this.audience,
    required this.sections,
  });

  final String id;
  final IconData icon;
  final Color color;
  final GuideText title;
  final GuideText summary;
  final GuideAudience audience;
  final List<GuideSection> sections;

  /// Everything in the guide, in reading order, for "Read aloud".
  String spokenText({required bool filipino}) {
    final parts = <String>[
      title.of(filipino: filipino),
      summary.of(filipino: filipino),
    ];
    for (final s in sections) {
      parts.add(s.heading.of(filipino: filipino));
      var n = 0;
      for (final line in s.lines) {
        n++;
        final label = line.label?.of(filipino: filipino);
        final text = line.text.of(filipino: filipino);
        final step = s.numbered
            ? (filipino ? 'Hakbang $n. ' : 'Step $n. ')
            : '';
        parts.add('$step${label == null ? '' : '$label: '}$text');
      }
    }
    return parts
        .map((p) => RegExp(r'[.!?:]$').hasMatch(p.trim()) ? p : '$p.')
        .join(' ');
  }
}

// ── Labels used in the per-option descriptions ────────────────────────────

const _what = GuideText('What it does', 'Ano ito');
const _who = GuideText('Who it helps', 'Para kanino');
const _on = GuideText('Turn it on', 'Paano i-on');
const _use = GuideText('How to use it', 'Paano gamitin');
const _need = GuideText('You need', 'Kailangan');
const _off = GuideText('Turn it off', 'Paano i-off');

/// Every guide, in a sensible default order. [guidesFor] reorders them.
const List<Guide> allGuides = [
  _students,
  _teachers,
  _parents,
  _accessibility,
  _gaze,
  _voice,
  _controller,
  _screenReader,
  _keyboard,
  _timeBreaks,
  _tvCast,
  _feedback,
];

/// The guides a profile sees, most useful first. A learner does not see the
/// teacher and parent guides; a teacher or parent sees everything, their own
/// guides first.
List<Guide> guidesFor({required bool educator}) {
  if (!educator) {
    return [
      for (final g in allGuides)
        if (g.audience != GuideAudience.educators) g,
    ];
  }
  return [
    for (final g in allGuides)
      if (g.audience == GuideAudience.educators) g,
    for (final g in allGuides)
      if (g.audience != GuideAudience.educators) g,
  ];
}

Guide? guideById(String id) {
  for (final g in allGuides) {
    if (g.id == id) return g;
  }
  return null;
}

// ── Students ───────────────────────────────────────────────────────────────

const _students = Guide(
  id: 'students',
  icon: Icons.school_rounded,
  color: Color(0xFF7E57C2),
  title: GuideText('For students', 'Para sa mag-aaral'),
  summary: GuideText(
    'How to learn words, play games and read stories.',
    'Paano matuto ng salita, maglaro, at magbasa ng kuwento.',
  ),
  audience: GuideAudience.learners,
  sections: [
    GuideSection(GuideText('Move around the app', 'Paglibot sa app'), [
      GuideLine(
        GuideText(
          'The tabs at the bottom are Home, Cards, Games, Stories and Progress.',
          'Ang mga tab sa ibaba ay Home, Cards, Games, Stories at Progress.',
        ),
      ),
      GuideLine(
        GuideText(
          'Tap a tab to open it. The back arrow at the top takes you back.',
          'I-tap ang tab para buksan. Ang back arrow sa itaas ay pabalik.',
        ),
      ),
    ]),
    GuideSection(GuideText('Learn words with cards', 'Matuto gamit ang cards'), [
      GuideLine(GuideText('Open Cards.', 'Buksan ang Cards.')),
      GuideLine(
        GuideText(
          'Choose a deck, like Animals or Colors.',
          'Pumili ng deck, gaya ng Animals o Colors.',
        ),
      ),
      GuideLine(
        GuideText(
          'Look at the picture. Tap the card to flip it and see the word.',
          'Tingnan ang larawan. I-tap ang card para baligtarin at makita ang salita.',
        ),
      ),
      GuideLine(
        GuideText(
          'Tap the speaker to hear the word. Tap FSL to watch the sign.',
          'I-tap ang speaker para marinig ang salita. I-tap ang FSL para makita ang senyas.',
        ),
      ),
      GuideLine(
        GuideText(
          'Tap Next for the next card.',
          'I-tap ang Next para sa susunod na card.',
        ),
      ),
    ], numbered: true),
    GuideSection(GuideText('Play and read', 'Maglaro at magbasa'), [
      GuideLine(
        GuideText(
          'Games: choose a game and follow the picture and words on the screen.',
          'Games: pumili ng laro at sundin ang larawan at salita sa screen.',
        ),
      ),
      GuideLine(
        GuideText(
          'Stories: choose a story. You can hear it read aloud.',
          'Stories: pumili ng kuwento. Maaari mo itong marinig na binabasa.',
        ),
      ),
      GuideLine(
        GuideText(
          'Progress: see your stars, words learned and badges.',
          'Progress: tingnan ang iyong mga bituin, natutunang salita at badge.',
        ),
      ),
    ]),
    GuideSection(
      GuideText(
        'When you need help or a rest',
        'Kapag kailangan mo ng tulong o pahinga',
      ),
      [
        GuideLine(
          GuideText(
            'Tired? Tap “I Need a Break” in a lesson or game. You come back to the same place after.',
            'Pagod? I-tap ang “I Need a Break” sa aralin o laro. Babalik ka sa parehong lugar pagkatapos.',
          ),
        ),
        GuideLine(
          GuideText(
            'Your teacher or parent may set break reminders. When one appears, choose “Take a break” or “Keep learning”.',
            'Maaaring maglagay ang guro o magulang ng paalala sa pahinga. Kapag lumabas ito, piliin ang “Magpahinga” o “Magpatuloy sa pag-aaral”.',
          ),
        ),
        GuideLine(
          GuideText(
            'My Day shows your day’s steps, like class, homework and rest.',
            'Ipinapakita ng My Day ang mga gagawin mo, gaya ng klase, assignment at pahinga.',
          ),
        ),
        GuideLine(
          GuideText(
            'The AI Buddy button can help you practise. It floats at the bottom of the screen.',
            'Makakatulong sa pagsasanay ang button ng AI Buddy. Nasa ibaba ito ng screen.',
          ),
        ),
      ],
    ),
    GuideSection(GuideText('Join your class', 'Sumali sa klase'), [
      GuideLine(
        GuideText(
          'Ask your teacher for the class code.',
          'Hingin sa guro ang code ng klase.',
        ),
      ),
      GuideLine(
        GuideText(
          'On Home, open Join a Class.',
          'Sa Home, buksan ang Join a Class.',
        ),
      ),
      GuideLine(
        GuideText(
          'Type the code and press Join.',
          'I-type ang code at pindutin ang Join.',
        ),
      ),
    ], numbered: true),
  ],
);

// ── Teachers ───────────────────────────────────────────────────────────────

const _teachers = Guide(
  id: 'teachers',
  icon: Icons.co_present_rounded,
  color: Color(0xFF3F51B5),
  title: GuideText('For teachers', 'Para sa guro'),
  summary: GuideText(
    'Set up a class, support each learner, assign work and see progress.',
    'Mag-set up ng klase, suportahan ang bawat mag-aaral, magbigay ng gawain at tingnan ang progreso.',
  ),
  audience: GuideAudience.educators,
  sections: [
    GuideSection(GuideText('Set up your class', 'I-set up ang klase'), [
      GuideLine(
        GuideText(
          'On your Home, open Manage Classes.',
          'Sa iyong Home, buksan ang Manage Classes.',
        ),
      ),
      GuideLine(
        GuideText(
          'Create a class and give it a name.',
          'Gumawa ng klase at pangalanan ito.',
        ),
      ),
      GuideLine(
        GuideText(
          'Use Share Code (Invite students) to give learners the join code.',
          'Gamitin ang Share Code (Invite students) para ibigay ang join code.',
        ),
      ),
      GuideLine(
        GuideText(
          'Each learner opens Join a Class on their Home and types the code.',
          'Bubuksan ng bawat mag-aaral ang Join a Class sa kanilang Home at ita-type ang code.',
        ),
      ),
    ], numbered: true),
    GuideSection(GuideText('Support each learner', 'Suportahan ang bawat mag-aaral'), [
      GuideLine(
        GuideText(
          'In Manage Classes, press ⋯ beside a learner. Choose Accessibility needs to set how they learn best (for example sign language first, audio first, gaze or simple words).',
          'Sa Manage Classes, pindutin ang ⋯ sa tabi ng mag-aaral. Piliin ang Accessibility needs para itakda kung paano sila pinakamahusay matuto.',
        ),
      ),
      GuideLine(
        GuideText(
          'The learner’s tablet receives these settings by itself.',
          'Kusa itong matatanggap ng tablet ng mag-aaral.',
        ),
      ),
      GuideLine(
        GuideText(
          'To set up Gaze Control or a game controller for a learner, open the learner from your dashboard and choose Gaze Control or Game Controller.',
          'Para i-set up ang Gaze Control o game controller ng mag-aaral, buksan ang mag-aaral mula sa dashboard at piliin ang Gaze Control o Game Controller.',
        ),
      ),
    ]),
    GuideSection(
      GuideText(
        'Assign work and see progress',
        'Magbigay ng gawain at tingnan ang progreso',
      ),
      [
        GuideLine(
          GuideText(
            'Assessments → Assign Tasks: give a test to a class or to some learners.',
            'Assessments → Assign Tasks: magbigay ng test sa klase o sa ilang mag-aaral.',
          ),
        ),
        GuideLine(
          GuideText(
            'Track Progress and Class Report show who finished and how they did.',
            'Ipinapakita ng Track Progress at Class Report kung sino ang natapos at ang resulta.',
          ),
        ),
        GuideLine(
          GuideText(
            'Roster & progress shows each learner’s words, games and study time.',
            'Ipinapakita ng Roster & progress ang mga salita, laro at oras ng pag-aaral ng bawat isa.',
          ),
        ),
        GuideLine(
          GuideText(
            'Live session lets the whole class answer together.',
            'Sa Live session, sabay-sabay sasagot ang buong klase.',
          ),
        ),
      ],
    ),
    GuideSection(GuideText('Time, routines and the TV', 'Oras, routine at TV'), [
      GuideLine(
        GuideText(
          'Press ⋯ beside a learner for Time limits, Alarms, Routine and Unlock screen. See the “Time limits, breaks and routines” guide.',
          'Pindutin ang ⋯ sa tabi ng mag-aaral para sa Time limits, Alarms, Routine at Unlock screen. Tingnan ang gabay na “Oras, pahinga at routine”.',
        ),
      ),
      GuideLine(
        GuideText(
          'TV Cast shows a lesson on a TV for the whole class. See the “TV Cast” guide.',
          'Ipinapakita ng TV Cast ang aralin sa TV para sa buong klase. Tingnan ang gabay na “TV Cast”.',
        ),
      ),
    ]),
  ],
);

// ── Parents ────────────────────────────────────────────────────────────────

const _parents = Guide(
  id: 'parents',
  icon: Icons.family_restroom_rounded,
  color: Color(0xFF00796B),
  title: GuideText('For parents', 'Para sa magulang'),
  summary: GuideText(
    'Connect with your child, guide their learning time and see their progress.',
    'Kumonekta sa iyong anak, gabayan ang oras ng pag-aaral at tingnan ang progreso.',
  ),
  audience: GuideAudience.educators,
  sections: [
    GuideSection(
      GuideText('Connect with your child', 'Kumonekta sa iyong anak'),
      [
        GuideLine(
          GuideText(
            'On your Home, open Manage Groups.',
            'Sa iyong Home, buksan ang Manage Groups.',
          ),
        ),
        GuideLine(
          GuideText(
            'Create a home group. Use Invite your child to get the code.',
            'Gumawa ng home group. Gamitin ang Invite your child para makuha ang code.',
          ),
        ),
        GuideLine(
          GuideText(
            'On your child’s profile, type the code to join.',
            'Sa profile ng iyong anak, i-type ang code para sumali.',
          ),
        ),
      ],
      numbered: true,
    ),
    GuideSection(GuideText('Guide their learning', 'Gabayan ang pag-aaral'), [
      GuideLine(
        GuideText(
          'In Manage Groups, press ⋯ beside your child for View progress, Time limits, Alarms, Routine, Accessibility needs and Unlock screen.',
          'Sa Manage Groups, pindutin ang ⋯ sa tabi ng anak para sa View progress, Time limits, Alarms, Routine, Accessibility needs at Unlock screen.',
        ),
      ),
      GuideLine(
        GuideText(
          'Parental Controls (on your Home and in Settings) set limits for the whole tablet.',
          'Ang Parental Controls (sa Home at sa Settings) ay naglalagay ng limitasyon sa buong tablet.',
        ),
      ),
      GuideLine(
        GuideText(
          'Parent Notes let you and the teacher share messages about your child.',
          'Sa Parent Notes, makakapagpalitan kayo ng guro ng mensahe tungkol sa anak.',
        ),
      ),
    ]),
    GuideSection(
      GuideText(
        'Help your child learn on their own',
        'Tulungan ang anak na matuto nang mag-isa',
      ),
      [
        GuideLine(
          GuideText(
            'Turn on only the help your child needs. Too many helpers at once can confuse.',
            'I-on lang ang tulong na kailangan ng anak. Nakakalito ang sobrang dami nang sabay.',
          ),
        ),
        GuideLine(
          GuideText(
            'Use short sessions and break reminders. Praise effort, not only right answers.',
            'Gumamit ng maikling sesyon at paalala sa pahinga. Purihin ang pagsisikap, hindi lang ang tamang sagot.',
          ),
        ),
        GuideLine(
          GuideText(
            'Use My Day so your child knows what comes next.',
            'Gamitin ang My Day para alam ng anak kung ano ang susunod.',
          ),
        ),
      ],
    ),
  ],
);

// ── Accessibility options ────────────────────────────────────────────────

const _accessibility = Guide(
  id: 'accessibility',
  icon: Icons.accessibility_new_rounded,
  color: Color(0xFFD31A5E),
  title: GuideText('Accessibility options', 'Mga opsyon sa accessibility'),
  summary: GuideText(
    'Choose only what helps you. You can use several together, and turn any of them off again.',
    'Piliin lang ang nakakatulong sa iyo. Maaaring gamitin nang sabay ang ilan, at i-off ulit kahit kailan.',
  ),
  audience: GuideAudience.everyone,
  sections: [
    GuideSection(GuideText('Before you start', 'Bago magsimula'), [
      GuideLine(
        GuideText(
          'These are options, not labels. You do not need to say what disability you have.',
          'Mga opsyon ito, hindi tatak. Hindi mo kailangang sabihin ang iyong kapansanan.',
        ),
      ),
      GuideLine(
        GuideText(
          'Most options are in Settings → Accessibility. Children and guests: tap the accessibility button on Home.',
          'Karamihan ay nasa Settings → Accessibility. Mga bata at guest: i-tap ang accessibility button sa Home.',
        ),
      ),
      GuideLine(
        GuideText(
          'If your teacher or parent manages your settings, ask them to change these for you.',
          'Kung guro o magulang ang namamahala sa iyong settings, hilingin sa kanila na palitan ito.',
        ),
      ),
    ]),
    GuideSection(
      GuideText('Font Size (bigger text)', 'Font Size (mas malaking letra)'),
      [
        GuideLine(
          GuideText(
            'Makes all words bigger.',
            'Pinalalaki ang lahat ng salita.',
          ),
          label: _what,
        ),
        GuideLine(
          GuideText(
            'People with low vision, and anyone who reads more easily with big letters.',
            'Mga may mahinang paningin, at sinumang mas madaling makabasa sa malaking letra.',
          ),
          label: _who,
        ),
        GuideLine(
          GuideText(
            'Settings → Accessibility → Font Size. Choose Large or Extra Large.',
            'Settings → Accessibility → Font Size. Piliin ang Large o Extra Large.',
          ),
          label: _on,
        ),
        GuideLine(
          GuideText('Nothing extra.', 'Walang dagdag na kailangan.'),
          label: _need,
        ),
        GuideLine(
          GuideText('Choose Normal again.', 'Piliin ulit ang Normal.'),
          label: _off,
        ),
      ],
    ),
    GuideSection(
      GuideText(
        'High Contrast Mode and Dark Mode',
        'High Contrast at Dark Mode',
      ),
      [
        GuideLine(
          GuideText(
            'High contrast uses strong colors and thick borders. Dark mode uses a dark background.',
            'Malakas na kulay at makapal na gilid ang High Contrast. Madilim na background ang Dark Mode.',
          ),
          label: _what,
        ),
        GuideLine(
          GuideText(
            'People with low vision or who find bright screens hard to look at.',
            'Mga may mahinang paningin o nahihirapan sa maliwanag na screen.',
          ),
          label: _who,
        ),
        GuideLine(
          GuideText(
            'Settings → Accessibility → High Contrast Mode (or Dark Mode).',
            'Settings → Accessibility → High Contrast Mode (o Dark Mode).',
          ),
          label: _on,
        ),
        GuideLine(
          GuideText(
            'Tap the same switch again.',
            'I-tap ulit ang parehong switch.',
          ),
          label: _off,
        ),
      ],
    ),
    GuideSection(GuideText('Dyslexia-friendly', 'Dyslexia-friendly'), [
      GuideLine(
        GuideText(
          'Uses an easier-to-read font and softer colors.',
          'Gumagamit ng mas madaling basahing font at malambot na kulay.',
        ),
        label: _what,
      ),
      GuideLine(
        GuideText(
          'People with dyslexia or reading difficulties.',
          'Mga may dyslexia o hirap sa pagbasa.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'Settings → Accessibility → Dyslexia-friendly.',
          'Settings → Accessibility → Dyslexia-friendly.',
        ),
        label: _on,
      ),
      GuideLine(
        GuideText(
          'Tap the same switch again.',
          'I-tap ulit ang parehong switch.',
        ),
        label: _off,
      ),
    ]),
    GuideSection(GuideText('Reduced Motion', 'Reduced Motion (bawas galaw)'), [
      GuideLine(
        GuideText(
          'Stops most moving and bouncing animations.',
          'Pinapahinto ang karamihan ng gumagalaw na animation.',
        ),
        label: _what,
      ),
      GuideLine(
        GuideText(
          'People who are distracted by movement, or feel unwell from it.',
          'Mga nadidistract sa galaw, o nahihilo dahil dito.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'Settings → Accessibility → Reduced Motion.',
          'Settings → Accessibility → Reduced Motion.',
        ),
        label: _on,
      ),
      GuideLine(
        GuideText(
          'Tap the same switch again.',
          'I-tap ulit ang parehong switch.',
        ),
        label: _off,
      ),
    ]),
    GuideSection(GuideText('Hear the words', 'Pakinggan ang mga salita'), [
      GuideLine(
        GuideText(
          'Text-to-Speech reads words aloud. Voice-Guided Navigation says the name of each screen.',
          'Binabasa nang malakas ng Text-to-Speech ang mga salita. Sinasabi ng Voice-Guided Navigation ang pangalan ng bawat screen.',
        ),
        label: _what,
      ),
      GuideLine(
        GuideText(
          'People who are blind or have low vision, and people who find reading hard.',
          'Mga bulag o may mahinang paningin, at mga nahihirapang magbasa.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'Settings → Audio → Text-to-Speech, and Settings → Accessibility → Voice-Guided Navigation. Speech Speed changes how fast it talks.',
          'Settings → Audio → Text-to-Speech, at Settings → Accessibility → Voice-Guided Navigation. Binabago ng Speech Speed ang bilis.',
        ),
        label: _on,
      ),
      GuideLine(
        GuideText(
          'The tablet’s sound turned on.',
          'Nakabukas ang tunog ng tablet.',
        ),
        label: _need,
      ),
      GuideLine(
        GuideText(
          'Tap the same switches again.',
          'I-tap ulit ang parehong mga switch.',
        ),
        label: _off,
      ),
    ]),
    GuideSection(GuideText('See, not only hear', 'Makita, hindi lang marinig'), [
      GuideLine(
        GuideText(
          'Words are always written on the screen. Cards and the FSL Dictionary have Filipino Sign Language videos. Time-up, “nearly time” and break notices appear on the screen, not only as sounds.',
          'Laging nakasulat ang mga salita sa screen. May video ng Filipino Sign Language ang cards at ang FSL Dictionary. Lumalabas sa screen ang abiso sa oras at pahinga, hindi lang bilang tunog.',
        ),
        label: _what,
      ),
      GuideLine(
        GuideText(
          'People who are Deaf or hard of hearing.',
          'Mga Deaf o mahina ang pandinig.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'Tap FSL on a card to watch the sign. Settings → Fullscreen shows sign videos bigger. Slow-Motion Mode makes signs easier to follow.',
          'I-tap ang FSL sa card para makita ang senyas. Pinalalaki ng Settings → Fullscreen ang video. Pinadadali ng Slow-Motion Mode ang pagsunod sa senyas.',
        ),
        label: _use,
      ),
      GuideLine(
        GuideText(
          'Internet the first time each sign video plays.',
          'Internet sa unang pag-play ng bawat video ng senyas.',
        ),
        label: _need,
      ),
    ]),
    GuideSection(
      GuideText(
        'Use the app without touching the screen',
        'Gamitin ang app nang hindi hinahawakan ang screen',
      ),
      [
        GuideLine(
          GuideText(
            'Gaze Control: move your head and blink. See the “Gaze Control” guide.',
            'Gaze Control: igalaw ang ulo at kumurap. Tingnan ang gabay na “Gaze Control”.',
          ),
        ),
        GuideLine(
          GuideText(
            'Voice commands, or voice only: speak to the app. See the “Voice commands” guide.',
            'Voice commands, o boses lang: kausapin ang app. Tingnan ang gabay na “Voice commands”.',
          ),
        ),
        GuideLine(
          GuideText(
            'Game controller: big buttons with spoken help. See the “Game controller” guide.',
            'Game controller: malalaking button na may tulong na boses. Tingnan ang gabay na “Game controller”.',
          ),
        ),
        GuideLine(
          GuideText(
            'Keyboard or switch: see the “Keyboard and switches” guide.',
            'Keyboard o switch: tingnan ang gabay na “Keyboard at switch”.',
          ),
        ),
        GuideLine(
          GuideText(
            'These work together. For example, use Gaze Control with voice commands.',
            'Gumagana ang mga ito nang sabay. Halimbawa, Gaze Control kasama ang voice commands.',
          ),
        ),
      ],
    ),
    GuideSection(GuideText('Learn at your own pace', 'Matuto sa sariling bilis'), [
      GuideLine(
        GuideText(
          'Adaptive Difficulty makes games easier or harder as you play (Settings → Learning Modes).',
          'Ang Adaptive Difficulty ay nagpapadali o nagpapahirap sa laro habang naglalaro (Settings → Learning Modes).',
        ),
      ),
      GuideLine(
        GuideText(
          '“I Need a Break” is in lessons and games. Break reminders can be set by your teacher or parent.',
          'Nasa aralin at laro ang “I Need a Break”. Maaaring maglagay ng paalala sa pahinga ang guro o magulang.',
        ),
      ),
      GuideLine(
        GuideText(
          'My Day shows the steps of your day in order, so you know what comes next.',
          'Ipinapakita ng My Day ang mga hakbang ng araw nang sunod-sunod, para alam mo ang susunod.',
        ),
      ),
    ]),
  ],
);

// ── Gaze Control ─────────────────────────────────────────────────────────

const _gaze = Guide(
  id: 'gaze',
  icon: Icons.remove_red_eye_rounded,
  color: Color(0xFF2368B8),
  title: GuideText('Gaze Control', 'Gaze Control'),
  summary: GuideText(
    'Use the app with head movements and blinks, without your hands.',
    'Gamitin ang app sa galaw ng ulo at pagkurap, nang walang kamay.',
  ),
  audience: GuideAudience.everyone,
  sections: [
    GuideSection(GuideText('About Gaze Control', 'Tungkol sa Gaze Control'), [
      GuideLine(
        GuideText(
          'A highlight moves when you turn your head. You choose the highlighted button with a long blink, by keeping still, or with a switch.',
          'Gumagalaw ang highlight kapag ibinaling mo ang ulo. Pinipili mo ang naka-highlight na button sa mahabang kurap, sa pananatiling tahimik, o sa switch.',
        ),
        label: _what,
      ),
      GuideLine(
        GuideText(
          'People who cannot use their hands or arms well.',
          'Mga hindi magamit nang maayos ang kamay o braso.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'The Android app (not a browser), the tablet’s front camera, good light on your face, and the tablet in front of you.',
          'Ang Android app (hindi browser), front camera ng tablet, maliwanag sa mukha, at nasa harap mo ang tablet.',
        ),
        label: _need,
      ),
    ]),
    GuideSection(GuideText('Turn it on', 'I-on ito'), [
      GuideLine(
        GuideText(
          'Open Settings → Accessibility → Gaze Control (Preview).',
          'Buksan ang Settings → Accessibility → Gaze Control (Preview).',
        ),
      ),
      GuideLine(
        GuideText(
          'Turn on Enable Gaze Control. Allow the camera when asked.',
          'I-on ang Enable Gaze Control. Payagan ang camera kapag tinanong.',
        ),
      ),
      GuideLine(
        GuideText(
          'Press “Try it now” to practise.',
          'Pindutin ang “Try it now” para magsanay.',
        ),
      ),
      GuideLine(
        GuideText(
          'Press “Set resting position” while you sit comfortably. This helps if your head rests turned or tilted, for example in a wheelchair.',
          'Pindutin ang “Set resting position” habang komportableng nakaupo. Nakakatulong ito kung nakabaling o nakatagilid ang ulo, halimbawa sa wheelchair.',
        ),
      ),
    ], numbered: true),
    GuideSection(GuideText('Use it', 'Gamitin ito'), [
      GuideLine(
        GuideText(
          'Turn your head left, right, up or down to move the highlight.',
          'Ibaling ang ulo pakaliwa, pakanan, pataas o pababa para ilipat ang highlight.',
        ),
      ),
      GuideLine(
        GuideText(
          'Choose with a long blink. Or turn on “Look and hold to choose” and keep still on a button.',
          'Pumili sa mahabang kurap. O i-on ang “Look and hold to choose” at manatiling tahimik sa button.',
        ),
      ),
      GuideLine(
        GuideText(
          '“How to choose” can use a switch or controller button instead of a blink.',
          'Sa “How to choose,” maaaring switch o button ng controller ang gamitin sa halip na kurap.',
        ),
      ),
      GuideLine(
        GuideText(
          'Cannot move your head? Turn on Scanning mode: buttons light up in turn, and you choose with a blink or a switch.',
          'Hindi maigalaw ang ulo? I-on ang Scanning mode: sunod-sunod na umiilaw ang mga button, at pipili ka sa kurap o switch.',
        ),
      ),
      GuideLine(
        GuideText(
          '“Read the highlight aloud” says each button’s name. The highlight ring shows it on the screen too.',
          'Sinasabi ng “Read the highlight aloud” ang pangalan ng bawat button. Makikita rin ito sa screen.',
        ),
      ),
    ]),
    GuideSection(GuideText('Make it fit you', 'Iangkop sa iyo'), [
      GuideLine(
        GuideText(
          'Tuning → Sensitivity: how big a head movement is needed.',
          'Tuning → Sensitivity: gaano kalaking galaw ng ulo ang kailangan.',
        ),
      ),
      GuideLine(
        GuideText(
          'Tuning → Hold time: how long to hold before it chooses. Longer means fewer mistakes.',
          'Tuning → Hold time: gaano katagal bago pumili. Mas mahaba, mas kaunting mali.',
        ),
      ),
      GuideLine(
        GuideText(
          'Tuning → Smoothing: choose Strong for shaking or jerky movements.',
          'Tuning → Smoothing: piliin ang Strong kung nanginginig ang galaw.',
        ),
      ),
    ]),
    GuideSection(GuideText('Pause and resume', 'I-pause at ituloy'), [
      GuideLine(
        GuideText(
          'With voice commands on, say “stop listening”. Nothing is chosen by accident while you rest or talk.',
          'Kapag naka-on ang voice commands, sabihin ang “huwag makinig”. Walang mapipili nang hindi sinasadya habang nagpapahinga o nakikipag-usap.',
        ),
      ),
      GuideLine(
        GuideText(
          'A banner shows that hands-free control is paused.',
          'May banner na nagsasabing naka-pause ang hands-free control.',
        ),
      ),
      GuideLine(
        GuideText(
          'To go on: say “resume”, make a long blink, press your switch, or tap the banner.',
          'Para magpatuloy: sabihin ang “ituloy”, kumurap nang matagal, pindutin ang switch, o i-tap ang banner.',
        ),
      ),
    ]),
    GuideSection(GuideText('Turn it off', 'I-off ito'), [
      GuideLine(
        GuideText(
          'Turn off Enable Gaze Control.',
          'I-off ang Enable Gaze Control.',
        ),
      ),
      GuideLine(
        GuideText(
          'The app asks you to keep the change. If nobody answers, it turns back on by itself, so a learner who cannot touch the screen is never stuck.',
          'Itatanong ng app kung itutuloy ang pagbabago. Kung walang sasagot, kusa itong babalik, para hindi maipit ang mag-aaral na hindi makahawak sa screen.',
        ),
      ),
      GuideLine(
        GuideText(
          'Teachers and parents: open the learner from your dashboard, then Gaze Control, to set it up for them.',
          'Mga guro at magulang: buksan ang mag-aaral mula sa dashboard, saka ang Gaze Control, para i-set up ito para sa kanila.',
        ),
      ),
    ]),
  ],
);

// ── Voice commands ───────────────────────────────────────────────────────

const _voice = Guide(
  id: 'voice',
  icon: Icons.mic_rounded,
  color: Color(0xFF9D3FAD),
  title: GuideText('Voice commands', 'Voice commands'),
  summary: GuideText(
    'Speak to move around and choose — with Gaze Control, or with your voice only.',
    'Magsalita para lumibot at pumili — kasama ang Gaze Control, o boses lang.',
  ),
  audience: GuideAudience.everyone,
  sections: [
    GuideSection(GuideText('About voice commands', 'Tungkol sa voice commands'), [
      GuideLine(
        GuideText(
          'The app listens for short commands and does them.',
          'Nakikinig ang app sa maiikling utos at ginagawa ang mga ito.',
        ),
        label: _what,
      ),
      GuideLine(
        GuideText(
          'People who cannot use their hands, with or without head movement.',
          'Mga hindi magamit ang kamay, may galaw man ng ulo o wala.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'The Android app, the microphone, and a fairly quiet room. It uses the tablet’s own free speech recognition; some tablets need the internet for it.',
          'Ang Android app, mikropono, at medyo tahimik na lugar. Gumagamit ito ng libreng speech recognition ng tablet; ang ilang tablet ay nangangailangan ng internet.',
        ),
        label: _need,
      ),
    ]),
    GuideSection(GuideText('Turn it on', 'I-on ito'), [
      GuideLine(
        GuideText(
          'Open Settings → Accessibility → Gaze Control (Preview) and turn on Enable Gaze Control.',
          'Buksan ang Settings → Accessibility → Gaze Control (Preview) at i-on ang Enable Gaze Control.',
        ),
      ),
      GuideLine(
        GuideText(
          'Under Voice, turn on Voice commands. Allow the microphone when asked.',
          'Sa ilalim ng Voice, i-on ang Voice commands. Payagan ang mikropono kapag tinanong.',
        ),
      ),
      GuideLine(
        GuideText(
          'No head movement? Also turn on “Voice only (camera off)”. The camera stays off and only your voice is used.',
          'Walang galaw ng ulo? I-on din ang “Boses lang (nakapatay ang camera)”. Nakapatay ang camera at boses mo lang ang gagamitin.',
        ),
      ),
    ], numbered: true),
    GuideSection(GuideText('What to say', 'Ano ang sasabihin'), [
      GuideLine(
        GuideText(
          '“left”, “right”, “up”, “down” — move the highlight. (“kaliwa”, “kanan”, “taas”, “baba”)',
          '“kaliwa”, “kanan”, “taas”, “baba” — ilipat ang highlight. (“left”, “right”, “up”, “down”)',
        ),
      ),
      GuideLine(
        GuideText(
          '“select” — open the highlighted button. (“piliin”)',
          '“piliin” — buksan ang naka-highlight na button. (“select”)',
        ),
      ),
      GuideLine(
        GuideText(
          'Say the name of a tab or a button you can see, like “Home”, “Cards” or “Games”. To start learning, say “Cards”.',
          'Sabihin ang pangalan ng tab o button na nakikita mo, gaya ng “Home”, “Cards” o “Games”. Para magsimulang matuto, sabihin ang “Cards”.',
        ),
      ),
      GuideLine(
        GuideText(
          '“next” and “back” — the next or previous card. (“susunod”, “balik”)',
          '“susunod” at “balik” — susunod o nakaraang card. (“next”, “back”)',
        ),
      ),
      GuideLine(
        GuideText(
          '“scroll down”, “scroll up” — move the page.',
          '“scroll down”, “scroll up” — igalaw ang pahina.',
        ),
      ),
      GuideLine(
        GuideText(
          '“go back” — leave this screen. (“isara”)',
          '“isara” — umalis sa screen na ito. (“go back”)',
        ),
      ),
      GuideLine(
        GuideText(
          '“read the screen” — hear what is on the screen. (“basahin ang screen”)',
          '“basahin ang screen” — pakinggan ang nasa screen. (“read the screen”)',
        ),
      ),
      GuideLine(
        GuideText(
          '“say again” — hear the last answer again. (“sabihin ulit”)',
          '“sabihin ulit” — pakinggan ulit ang huling sagot. (“say again”)',
        ),
      ),
      GuideLine(
        GuideText(
          '“what can I say” — hear this list. (“ano ang masasabi ko”)',
          '“ano ang masasabi ko” — pakinggan ang listahang ito. (“what can I say”)',
        ),
      ),
      GuideLine(
        GuideText(
          '“stop listening” — pause. “resume” — go on. (“huwag makinig”, “ituloy”)',
          '“huwag makinig” — pause. “ituloy” — magpatuloy. (“stop listening”, “resume”)',
        ),
      ),
    ]),
    GuideSection(GuideText('Tips', 'Mga tip'), [
      GuideLine(
        GuideText(
          'Speak clearly, one command at a time.',
          'Magsalita nang malinaw, isang utos sa bawat pagkakataon.',
        ),
      ),
      GuideLine(
        GuideText(
          'The small chip on the screen shows what the app heard — useful if you cannot hear the reply.',
          'Ipinapakita ng maliit na chip sa screen ang narinig ng app — kapaki-pakinabang kung hindi mo marinig ang sagot.',
        ),
      ),
      GuideLine(
        GuideText(
          'Some activities that use the camera (Sign It, Word Hunt) stop head control while they are open; voice keeps working.',
          'Ang ilang gawain na gumagamit ng camera (Sign It, Word Hunt) ay pinapahinto ang head control habang bukas; gumagana pa rin ang boses.',
        ),
      ),
    ]),
    GuideSection(GuideText('Turn it off', 'I-off ito'), [
      GuideLine(
        GuideText(
          'Turn off Voice commands in Settings → Accessibility → Gaze Control (Preview).',
          'I-off ang Voice commands sa Settings → Accessibility → Gaze Control (Preview).',
        ),
      ),
    ]),
  ],
);

// ── Game controller ──────────────────────────────────────────────────────

const _controller = Guide(
  id: 'controller',
  icon: Icons.sports_esports_rounded,
  color: Color(0xFFB34619),
  title: GuideText('Game controller', 'Game controller'),
  summary: GuideText(
    'Use a Bluetooth game controller. The app says where you are and what each button does.',
    'Gumamit ng Bluetooth game controller. Sinasabi ng app kung nasaan ka at ano ang ginagawa ng bawat button.',
  ),
  audience: GuideAudience.everyone,
  sections: [
    GuideSection(GuideText('About the controller', 'Tungkol sa controller'), [
      GuideLine(
        GuideText(
          'People who are blind or have low vision, and people who find a touchscreen hard to use.',
          'Mga bulag o may mahinang paningin, at mga nahihirapang gumamit ng touchscreen.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'A Bluetooth game controller. In a browser, use the latest Chrome or Edge.',
          'Isang Bluetooth game controller. Sa browser, gamitin ang pinakabagong Chrome o Edge.',
        ),
        label: _need,
      ),
    ]),
    GuideSection(GuideText('Turn it on', 'I-on ito'), [
      GuideLine(
        GuideText(
          'Pair the controller in the tablet’s Settings → Bluetooth.',
          'I-pair ang controller sa Settings → Bluetooth ng tablet.',
        ),
      ),
      GuideLine(
        GuideText(
          'In the app: Settings → Accessibility → Game Controller → Enable controller.',
          'Sa app: Settings → Accessibility → Game Controller → Enable controller.',
        ),
      ),
      GuideLine(
        GuideText(
          'Press “Practise the buttons” to learn them.',
          'Pindutin ang “Practise the buttons” para matutunan ang mga ito.',
        ),
      ),
    ], numbered: true),
    GuideSection(GuideText('The buttons', 'Ang mga button'), [
      GuideLine(
        GuideText('D-pad or left stick: move.', 'D-pad o left stick: gumalaw.'),
      ),
      GuideLine(
        GuideText(
          'A: press (yes). B: back or close (no).',
          'A: pindutin (oo). B: bumalik o isara (hindi).',
        ),
      ),
      GuideLine(
        GuideText(
          'X: read the screen. Y: say it again.',
          'X: basahin ang screen. Y: sabihin ulit.',
        ),
      ),
      GuideLine(
        GuideText(
          'L1 and R1: go to another section. L2 and R2: the previous or next item.',
          'L1 at R1: pumunta sa ibang section. L2 at R2: nakaraan o susunod na item.',
        ),
      ),
      GuideLine(
        GuideText(
          'Start: where am I? Select: the button guide.',
          'Start: nasaan ako? Select: gabay sa mga button.',
        ),
      ),
      GuideLine(
        GuideText(
          'Right stick up or down: scroll. L3: Home. R3: stop talking.',
          'Right stick pataas o pababa: scroll. L3: Home. R3: tumigil sa pagsasalita.',
        ),
      ),
    ]),
    GuideSection(GuideText('Make it fit you', 'Iangkop sa iyo'), [
      GuideLine(
        GuideText(
          '“Say what is happening” and Speech speed control the spoken help.',
          'Kinokontrol ng “Say what is happening” at Speech speed ang boses na tulong.',
        ),
      ),
      GuideLine(
        GuideText(
          '“Vibrate on each press” gives a buzz you can feel (if the controller can vibrate).',
          'Nagbibigay ng pag-vibrate ang “Vibrate on each press” (kung kaya ng controller).',
        ),
      ),
      GuideLine(
        GuideText(
          '“Ignore repeat presses within” helps if your hand shakes. “Swap A and B” fixes controllers with swapped buttons.',
          'Nakakatulong ang “Ignore repeat presses within” kung nanginginig ang kamay. Inaayos ng “Swap A and B” ang controller na baligtad ang button.',
        ),
      ),
    ]),
    GuideSection(GuideText('Turn it off', 'I-off ito'), [
      GuideLine(
        GuideText(
          'Turn off Enable controller.',
          'I-off ang Enable controller.',
        ),
      ),
    ]),
  ],
);

// ── Screen reader ────────────────────────────────────────────────────────

const _screenReader = Guide(
  id: 'screenReader',
  icon: Icons.record_voice_over_rounded,
  color: Color(0xFF2E7431),
  title: GuideText('Screen reader (TalkBack)', 'Screen reader (TalkBack)'),
  summary: GuideText(
    'Hear every button and word with Android’s built-in screen reader.',
    'Pakinggan ang bawat button at salita gamit ang screen reader ng Android.',
  ),
  audience: GuideAudience.everyone,
  sections: [
    GuideSection(GuideText('About TalkBack', 'Tungkol sa TalkBack'), [
      GuideLine(
        GuideText(
          'People who are blind or have low vision.',
          'Mga bulag o may mahinang paningin.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'Android’s TalkBack (free, already on most tablets).',
          'Ang TalkBack ng Android (libre, nasa karamihan ng tablet).',
        ),
        label: _need,
      ),
    ]),
    GuideSection(GuideText('Turn it on', 'I-on ito'), [
      GuideLine(
        GuideText(
          'Open the tablet’s Settings → Accessibility → TalkBack.',
          'Buksan ang Settings → Accessibility → TalkBack ng tablet.',
        ),
      ),
      GuideLine(GuideText('Turn TalkBack on.', 'I-on ang TalkBack.')),
      GuideLine(
        GuideText('Open FlashLearn PWD.', 'Buksan ang FlashLearn PWD.'),
      ),
    ], numbered: true),
    GuideSection(GuideText('Use it', 'Gamitin ito'), [
      GuideLine(
        GuideText(
          'Swipe right or left to move from one item to the next. TalkBack reads it.',
          'Mag-swipe pakanan o pakaliwa para lumipat sa bawat item. Babasahin ito ng TalkBack.',
        ),
      ),
      GuideLine(
        GuideText(
          'Double-tap anywhere to press the item that was read.',
          'Mag-double-tap kahit saan para pindutin ang nabasang item.',
        ),
      ),
      GuideLine(
        GuideText(
          'Buttons and pictures have names. Filipino words are marked so they can be read in Filipino.',
          'May pangalan ang mga button at larawan. Minarkahan ang mga salitang Filipino para mabasa sa Filipino.',
        ),
      ),
      GuideLine(
        GuideText(
          'While TalkBack is on, the app sends its own spoken messages through TalkBack.',
          'Habang naka-on ang TalkBack, ipinapadaan ng app ang sariling mensahe sa TalkBack.',
        ),
      ),
    ]),
    GuideSection(GuideText('Turn it off', 'I-off ito'), [
      GuideLine(
        GuideText(
          'In the tablet’s Settings → Accessibility → TalkBack, turn it off.',
          'Sa Settings → Accessibility → TalkBack ng tablet, i-off ito.',
        ),
      ),
    ]),
  ],
);

// ── Keyboard and switches ───────────────────────────────────────────────

const _keyboard = Guide(
  id: 'keyboard',
  icon: Icons.keyboard_rounded,
  color: Color(0xFF4F5FBB),
  title: GuideText('Keyboard and switches', 'Keyboard at switch'),
  summary: GuideText(
    'Move around with arrow keys, or choose with one switch.',
    'Lumibot gamit ang arrow keys, o pumili gamit ang isang switch.',
  ),
  audience: GuideAudience.everyone,
  sections: [
    GuideSection(GuideText('Keyboard', 'Keyboard'), [
      GuideLine(
        GuideText(
          'People who cannot use a touchscreen but can press keys.',
          'Mga hindi makagamit ng touchscreen pero nakakapindot ng key.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'A Bluetooth or USB keyboard, or a device that sends arrow keys.',
          'Bluetooth o USB keyboard, o device na nagpapadala ng arrow keys.',
        ),
        label: _need,
      ),
      GuideLine(
        GuideText(
          'Arrow keys move the highlight. Enter or Space presses. Escape goes back.',
          'Inililipat ng arrow keys ang highlight. Pumipindot ang Enter o Space. Pabalik ang Escape.',
        ),
        label: _use,
      ),
    ]),
    GuideSection(GuideText('One switch', 'Isang switch'), [
      GuideLine(
        GuideText(
          'People who can press only one button.',
          'Mga isang button lang ang kayang pindutin.',
        ),
        label: _who,
      ),
      GuideLine(
        GuideText(
          'A Bluetooth switch or any button on a game controller.',
          'Bluetooth switch o anumang button ng game controller.',
        ),
        label: _need,
      ),
      GuideLine(
        GuideText(
          'Settings → Accessibility → Gaze Control (Preview). Turn on Enable Gaze Control. In “How to choose”, pick “A switch or controller button”. Turn on Scanning mode.',
          'Settings → Accessibility → Gaze Control (Preview). I-on ang Enable Gaze Control. Sa “How to choose”, piliin ang “A switch or controller button”. I-on ang Scanning mode.',
        ),
        label: _on,
      ),
      GuideLine(
        GuideText(
          'Buttons light up one after another. Press your switch when the one you want lights up. The camera stays off.',
          'Sunod-sunod na umiilaw ang mga button. Pindutin ang switch kapag umilaw ang gusto mo. Nakapatay ang camera.',
        ),
        label: _use,
      ),
      GuideLine(
        GuideText(
          'Turn off Scanning mode, or Enable Gaze Control.',
          'I-off ang Scanning mode, o ang Enable Gaze Control.',
        ),
        label: _off,
      ),
    ]),
  ],
);

// ── Time limits, breaks and routines ────────────────────────────────────

const _timeBreaks = Guide(
  id: 'timeBreaks',
  icon: Icons.schedule_rounded,
  color: Color(0xFF8F5B00),
  title: GuideText(
    'Time limits, breaks and routines',
    'Oras, pahinga at routine',
  ),
  summary: GuideText(
    'Set healthy learning time, break reminders, alarms and a daily routine for a learner.',
    'Magtakda ng maayos na oras ng pag-aaral, paalala sa pahinga, alarma at routine para sa mag-aaral.',
  ),
  audience: GuideAudience.educators,
  sections: [
    GuideSection(
      GuideText(
        'Open a learner’s settings',
        'Buksan ang settings ng mag-aaral',
      ),
      [
        GuideLine(
          GuideText(
            'Open Manage Classes (teachers) or Manage Groups (parents).',
            'Buksan ang Manage Classes (guro) o Manage Groups (magulang).',
          ),
        ),
        GuideLine(
          GuideText(
            'Press ⋯ beside the learner.',
            'Pindutin ang ⋯ sa tabi ng mag-aaral.',
          ),
        ),
        GuideLine(
          GuideText(
            'Choose Time limits, Alarms or Routine.',
            'Piliin ang Time limits, Alarms o Routine.',
          ),
        ),
      ],
      numbered: true,
    ),
    GuideSection(GuideText('Time limits', 'Time limits'), [
      GuideLine(
        GuideText(
          'Daily time limit: how many minutes a day the learner can use the app.',
          'Daily time limit: ilang minuto bawat araw magagamit ng mag-aaral ang app.',
        ),
      ),
      GuideLine(
        GuideText(
          'Allowed schedule: the days and hours the app can be used.',
          'Allowed schedule: mga araw at oras na magagamit ang app.',
        ),
      ),
      GuideLine(
        GuideText(
          'Warn before the lock: a notice a few minutes before time is up, so they can finish.',
          'Warn before the lock: abiso ilang minuto bago maubos ang oras, para matapos nila.',
        ),
      ),
      GuideLine(
        GuideText(
          'The learner sees how many minutes are left in that notice and in break reminders.',
          'Makikita ng mag-aaral ang natitirang minuto sa abisong iyon at sa paalala sa pahinga.',
        ),
      ),
      GuideLine(
        GuideText(
          'When time is up you choose: a chime, a spoken message, the name the learner calls you, and a sign language video.',
          'Kapag ubos na ang oras, ikaw ang pipili: tunog, binibigkas na mensahe, ang tawag sa iyo ng mag-aaral, at video ng sign language.',
        ),
      ),
    ]),
    GuideSection(GuideText('Break reminders', 'Paalala sa pahinga'), [
      GuideLine(
        GuideText(
          'In Time limits, turn on “Remind them to take a break”.',
          'Sa Time limits, i-on ang “Ipaalala na magpahinga”.',
        ),
      ),
      GuideLine(
        GuideText(
          'Choose how many minutes of learning come between reminders (10 to 60).',
          'Piliin kung ilang minuto ng pag-aaral bago ang bawat paalala (10 hanggang 60).',
        ),
      ),
      GuideLine(
        GuideText(
          'The reminder never locks the app. The learner chooses “Take a break” or “Keep learning”.',
          'Hindi nito nila-lock ang app. Pipili ang mag-aaral ng “Magpahinga” o “Magpatuloy sa pag-aaral”.',
        ),
      ),
      GuideLine(
        GuideText(
          'It is shown on the screen and spoken (if speech is on), and waits during tests, live sessions and games with others.',
          'Lumalabas ito sa screen at binibigkas (kung naka-on ang boses), at naghihintay habang may test, live session at larong may kasama.',
        ),
      ),
      GuideLine(
        GuideText(
          'Press Save at the bottom of Time limits.',
          'Pindutin ang Save sa ibaba ng Time limits.',
        ),
      ),
    ]),
    GuideSection(GuideText('Alarms and routines', 'Alarma at routine'), [
      GuideLine(
        GuideText(
          'Alarms: set times when the screen locks, for example meal time or bedtime.',
          'Alarms: magtakda ng oras na magla-lock ang screen, halimbawa oras ng pagkain o pagtulog.',
        ),
      ),
      GuideLine(
        GuideText(
          'Routine (My Day): build the day’s steps in order — class, homework, practice, rest. Each step can have a time and a reminder.',
          'Routine (My Day): buuin ang mga hakbang ng araw — klase, assignment, pagsasanay, pahinga. Maaaring may oras at paalala ang bawat hakbang.',
        ),
      ),
      GuideLine(
        GuideText(
          'Unlock screen: give more time when the learner is locked out.',
          'Unlock screen: magbigay ng dagdag na oras kapag naka-lock ang mag-aaral.',
        ),
      ),
      GuideLine(
        GuideText(
          'Parental Controls set limits for the whole tablet.',
          'Nagtatakda ng limitasyon sa buong tablet ang Parental Controls.',
        ),
      ),
    ]),
  ],
);

// ── TV Cast ──────────────────────────────────────────────────────────────

const _tvCast = Guide(
  id: 'tvCast',
  icon: Icons.cast_rounded,
  color: Color(0xFF007569),
  title: GuideText('TV Cast', 'TV Cast'),
  summary: GuideText(
    'Show a lesson on a TV so the whole class or family can see it.',
    'Ipakita ang aralin sa TV para makita ng buong klase o pamilya.',
  ),
  audience: GuideAudience.educators,
  sections: [
    GuideSection(GuideText('What you need', 'Ang kailangan'), [
      GuideLine(
        GuideText(
          'The Android app on a tablet or phone (casting does not work from a browser).',
          'Ang Android app sa tablet o phone (hindi gumagana mula sa browser).',
        ),
      ),
      GuideLine(
        GuideText(
          'A TV with a web browser, on the same Wi-Fi as the tablet. Not every TV can do this.',
          'TV na may web browser, sa parehong Wi-Fi ng tablet. Hindi lahat ng TV ay kaya ito.',
        ),
      ),
    ]),
    GuideSection(GuideText('Start casting', 'Magsimulang mag-cast'), [
      GuideLine(
        GuideText(
          'On your Home, open TV Cast.',
          'Sa iyong Home, buksan ang TV Cast.',
        ),
      ),
      GuideLine(
        GuideText(
          'Choose the class or group, then what to cast.',
          'Piliin ang klase o grupo, saka ang ika-cast.',
        ),
      ),
      GuideLine(
        GuideText(
          'On the TV, open the web browser and type the link shown on the tablet. (Samsung: the “Internet” app. Chromecast with Google TV: Chrome.)',
          'Sa TV, buksan ang web browser at i-type ang link na nasa tablet. (Samsung: ang “Internet” app. Chromecast with Google TV: Chrome.)',
        ),
      ),
      GuideLine(
        GuideText(
          'Step the lesson from the tablet. Press Stop casting when you finish.',
          'Ituloy ang aralin mula sa tablet. Pindutin ang Stop casting kapag tapos na.',
        ),
      ),
    ], numbered: true),
    GuideSection(
      GuideText('If casting does not work', 'Kung hindi gumana ang pag-cast'),
      [
        GuideLine(
          GuideText(
            'Check that the tablet and the TV are on the same Wi-Fi.',
            'Tiyaking nasa parehong Wi-Fi ang tablet at TV.',
          ),
        ),
        GuideLine(
          GuideText(
            'No browser on the TV? Connect a laptop to the TV with an HDMI cable and open the link on the laptop. (Apple TV: AirPlay a laptop’s browser.)',
            'Walang browser ang TV? Ikonekta ang laptop sa TV gamit ang HDMI cable at buksan ang link sa laptop. (Apple TV: i-AirPlay ang browser ng laptop.)',
          ),
        ),
        GuideLine(
          GuideText(
            'No TV or Wi-Fi? Use the tablet itself with a small group.',
            'Walang TV o Wi-Fi? Gamitin ang tablet mismo sa maliit na grupo.',
          ),
        ),
        GuideLine(
          GuideText(
            'Only TVs that open your exact cast link can see the lesson.',
            'Ang mga TV lang na nagbukas ng eksaktong cast link mo ang makakakita ng aralin.',
          ),
        ),
      ],
    ),
  ],
);

// ── Rate & Feedback ──────────────────────────────────────────────────────

const _feedback = Guide(
  id: 'feedback',
  icon: Icons.rate_review_rounded,
  color: Color(0xFFD68A00),
  title: GuideText('Rate & Feedback', 'Rating at Feedback'),
  summary: GuideText(
    'Tell the FlashLearn PWD team what you think, report a problem or share an idea.',
    'Sabihin sa FlashLearn PWD team ang iyong opinyon, mag-ulat ng problema o magbahagi ng ideya.',
  ),
  audience: GuideAudience.everyone,
  sections: [
    GuideSection(GuideText('Send feedback', 'Magpadala ng feedback'), [
      GuideLine(
        GuideText(
          'Open Settings → About → Rate & Feedback. The feedback page opens in your browser.',
          'Buksan ang Settings → About → Rating at Feedback. Bubukas ang feedback page sa iyong browser.',
        ),
      ),
      GuideLine(
        GuideText(
          'Choose stars (optional), who you are, and the kind of message.',
          'Pumili ng bituin (opsyonal), kung sino ka, at uri ng mensahe.',
        ),
      ),
      GuideLine(
        GuideText(
          'Write your message. Please do not write names, phone numbers or details about a child.',
          'Isulat ang mensahe. Huwag isulat ang pangalan, numero ng telepono o detalye tungkol sa bata.',
        ),
      ),
      GuideLine(
        GuideText(
          'Press “Send to the team”.',
          'Pindutin ang “Ipadala sa team”.',
        ),
      ),
    ], numbered: true),
    GuideSection(GuideText('What happens next', 'Ano ang susunod'), [
      GuideLine(
        GuideText(
          '“Your feedback has been sent successfully!” means the team received it.',
          'Ang “Matagumpay na naipadala ang inyong feedback!” ay nangangahulugang natanggap ito ng team.',
        ),
      ),
      GuideLine(
        GuideText(
          '“Your feedback could not be sent. Please try again.” means it did not arrive. Check the internet and try again.',
          'Ang “Hindi naipadala ang inyong feedback. Pakisubukan ulit.” ay nangangahulugang hindi ito dumating. Tingnan ang internet at subukan ulit.',
        ),
      ),
      GuideLine(
        GuideText(
          'Want a reply? Use “Open in your email app”. Your feedback is sent only when you press Send in your email app.',
          'Gusto ng sagot? Gamitin ang “Buksan sa inyong email app”. Maipapadala lang ito kapag pinindot mo ang Send sa email app.',
        ),
      ),
    ]),
    GuideSection(GuideText('You need', 'Kailangan'), [
      GuideLine(GuideText('The internet.', 'Internet.')),
    ]),
  ],
);
