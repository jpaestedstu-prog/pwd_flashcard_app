import '../models/enums.dart';

/// A question within a story for reading comprehension.
class StoryQuestion {
  final String questionEn;
  final String questionFil;
  final List<String> optionsEn;
  final List<String> optionsFil;
  final int correctIndex;

  const StoryQuestion({
    required this.questionEn,
    required this.questionFil,
    required this.optionsEn,
    required this.optionsFil,
    required this.correctIndex,
  });
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
  });
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
      questions: [
        StoryQuestion(
          questionEn: 'Where did Anna visit?',
          questionFil: 'Saan bumisita si Anna?',
          optionsEn: ['The beach', 'The farm', 'The school'],
          optionsFil: ['Sa beach', 'Sa bukid', 'Sa paaralan'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What was the cow doing?',
          questionFil: 'Ano ang ginagawa ng baka?',
          optionsEn: ['Sleeping', 'Eating grass', 'Drinking water'],
          optionsFil: ['Natutulog', 'Kumakain ng damo', 'Umiinom ng tubig'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What was the pig doing?',
          questionFil: 'Ano ang ginagawa ng baboy?',
          optionsEn: ['Eating food', 'Swimming', 'Rolling in mud'],
          optionsFil: ['Kumakain', 'Lumalangoy', 'Gumugulong sa putik'],
          correctIndex: 2,
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
      questions: [
        StoryQuestion(
          questionEn: 'When did Maria go to the garden?',
          questionFil: 'Kailan pumunta si Maria sa hardin?',
          optionsEn: ['Before school', 'After the rain', 'In the morning'],
          optionsFil: ['Bago mag-aral', 'Pagkatapos ng ulan', 'Sa umaga'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What color were the roses?',
          questionFil: 'Ano ang kulay ng mga rosas?',
          optionsEn: ['Blue', 'Red', 'Yellow'],
          optionsFil: ['Asul', 'Pula', 'Dilaw'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What was in the sky?',
          questionFil: 'Ano ang nasa langit?',
          optionsEn: ['A bird', 'A rainbow', 'A star'],
          optionsFil: ['Isang ibon', 'Isang bahaghari', 'Isang bituin'],
          correctIndex: 1,
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
      questions: [
        StoryQuestion(
          questionEn: 'How many trees did Liza see?',
          questionFil: 'Ilang puno ang nakita ni Liza?',
          optionsEn: ['Two', 'One', 'Three'],
          optionsFil: ['Dalawa', 'Isa', 'Tatlo'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'How many children were playing?',
          questionFil: 'Ilang bata ang naglalaro?',
          optionsEn: ['Four', 'Two', 'Three'],
          optionsFil: ['Apat', 'Dalawa', 'Tatlo'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'Which bench did Liza sit on?',
          questionFil: 'Sa aling upuan umupo si Liza?',
          optionsEn: ['The first', 'The third', 'The fifth'],
          optionsFil: ['Sa una', 'Sa pangatlo', 'Sa pang-lima'],
          correctIndex: 2,
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
      questions: [
        StoryQuestion(
          questionEn: 'When do they exercise?',
          questionFil: 'Kailan sila nag-eehersisyo?',
          optionsEn: ['After lunch', 'Every morning', 'Before bed'],
          optionsFil: ['Pagkatapos ng tanghalian', 'Tuwing umaga', 'Bago matulog'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What did they do with their hands?',
          questionFil: 'Ano ang ginawa nila sa kanilang mga kamay?',
          optionsEn: ['Waved', 'Clapped', 'Pointed'],
          optionsFil: ['Kumaway', 'Pumalakpak', 'Nagturo'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What body part did they bend?',
          questionFil: 'Anong bahagi ng katawan ang kanilang binali?',
          optionsEn: ['Elbows', 'Knees', 'Wrists'],
          optionsFil: ['Mga siko', 'Mga tuhod', 'Mga pulso'],
          correctIndex: 1,
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
      questions: [
        StoryQuestion(
          questionEn: 'Who cooked breakfast?',
          questionFil: 'Sino ang nagluto ng almusal?',
          optionsEn: ['Carlo', 'Mama', 'Papa'],
          optionsFil: ['Si Carlo', 'Si Mama', 'Si Papa'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What did Carlo eat with rice?',
          questionFil: 'Ano ang kinain ni Carlo kasama ng kanin?',
          optionsEn: ['Bread', 'Eggs', 'Banana'],
          optionsFil: ['Tinapay', 'Itlog', 'Saging'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What fruit did Carlo eat?',
          questionFil: 'Anong prutas ang kinain ni Carlo?',
          optionsEn: ['Banana', 'Apple', 'Orange'],
          optionsFil: ['Saging', 'Mansanas', 'Kahel'],
          correctIndex: 1,
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
          optionsEn: ['Rice and soup', 'Chicken and vegetables', 'Bread and milk'],
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
      questions: [
        StoryQuestion(
          questionEn: 'When does the family spend time together?',
          questionFil: 'Kailan nagsasama-sama ang pamilya?',
          optionsEn: ['Monday', 'Friday', 'Sunday'],
          optionsFil: ['Lunes', 'Biyernes', 'Linggo'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'What does Mother do?',
          questionFil: 'Ano ang ginagawa ni Nanay?',
          optionsEn: ['Plays games', 'Cooks a meal', 'Reads a book'],
          optionsFil: ['Naglalaro', 'Nagluluto', 'Nagbabasa ng libro'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'Who arrives at the end?',
          questionFil: 'Sino ang dumating sa huli?',
          optionsEn: ['A friend', 'The teacher', 'Grandmother'],
          optionsFil: ['Isang kaibigan', 'Ang guro', 'Ang Lola'],
          correctIndex: 2,
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
          optionsEn: ['When helped', 'When she makes a mistake', 'In the morning'],
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
      questions: [
        StoryQuestion(
          questionEn: 'What does Ben put on first?',
          questionFil: 'Ano ang unang isinusuot ni Ben?',
          optionsEn: ['Shoes', 'T-shirt', 'Pants'],
          optionsFil: ['Sapatos', 'T-shirt', 'Pantalon'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What color are Ben\'s pants?',
          questionFil: 'Anong kulay ang pantalon ni Ben?',
          optionsEn: ['Red', 'Green', 'Blue'],
          optionsFil: ['Pula', 'Berde', 'Asul'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'What does Ben wear last?',
          questionFil: 'Ano ang huling isinusuot ni Ben?',
          optionsEn: ['Uniform', 'Shoes', 'T-shirt'],
          optionsFil: ['Uniporme', 'Sapatos', 'T-shirt'],
          correctIndex: 1,
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
          optionsEn: ['To look nice', 'So rain won\'t fall on her face', 'To stay cool'],
          optionsFil: ['Para maganda', 'Para hindi mabasang ang mukha', 'Para lumamig'],
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
      questions: [
        StoryQuestion(
          questionEn: 'How is the weather at the start?',
          questionFil: 'Ano ang panahon sa simula?',
          optionsEn: ['Rainy', 'Sunny', 'Cloudy'],
          optionsFil: ['Maulan', 'Maaraw', 'Maulap'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'Why does Ana bring water?',
          questionFil: 'Bakit nagdala ng tubig si Ana?',
          optionsEn: ['It is cold', 'It is hot', 'It is night'],
          optionsFil: ['Malamig', 'Mainit', 'Gabi na'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What does Ana see after the rain?',
          questionFil: 'Ano ang nakita ni Ana pagkatapos ng ulan?',
          optionsEn: ['Lightning', 'A rainbow', 'A storm'],
          optionsFil: ['Kidlat', 'Bahaghari', 'Bagyo'],
          correctIndex: 1,
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
      questions: [
        StoryQuestion(
          questionEn: 'Whose first day of school is it?',
          questionFil: 'Kanino ang unang araw sa paaralan?',
          optionsEn: ['Ana', 'Carlo', 'Ben'],
          optionsFil: ['Ana', 'Carlo', 'Ben'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What does the teacher give Carlo?',
          questionFil: 'Ano ang ibinigay ng guro kay Carlo?',
          optionsEn: ['Toys', 'A book', 'Food'],
          optionsFil: ['Laruan', 'Aklat', 'Pagkain'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'How does Carlo feel?',
          questionFil: 'Ano ang naramdaman ni Carlo?',
          optionsEn: ['Sad', 'Scared', 'Happy'],
          optionsFil: ['Malungkot', 'Takot', 'Masaya'],
          correctIndex: 2,
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
      questions: [
        StoryQuestion(
          questionEn: 'Where do Papa and Leo go?',
          questionFil: 'Saan pumunta si Papa at Leo?',
          optionsEn: ['The park', 'The city', 'The farm'],
          optionsFil: ['Sa parke', 'Sa lungsod', 'Sa bukid'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What do they ride from their town?',
          questionFil: 'Ano ang sinakyan nila mula sa bayan?',
          optionsEn: ['Car', 'Taxi', 'Bus'],
          optionsFil: ['Kotse', 'Taksi', 'Bus'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'What is on the busy road?',
          questionFil: 'Ano ang nasa masikip na daan?',
          optionsEn: ['Animals', 'Many cars', 'Boats'],
          optionsFil: ['Mga hayop', 'Maraming kotse', 'Mga bangka'],
          correctIndex: 1,
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
      questions: [
        StoryQuestion(
          questionEn: 'Why is Joy happy?',
          questionFil: 'Bakit masaya si Joy?',
          optionsEn: ['It is sunny', 'It is her birthday', 'She has new shoes'],
          optionsFil: ['Maaraw', 'Kaarawan niya', 'May bago siyang sapatos'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'How does Joy feel when her friend cannot come?',
          questionFil: 'Ano ang naramdaman ni Joy nang hindi makapunta ang kaibigan?',
          optionsEn: ['Angry', 'Sad', 'Excited'],
          optionsFil: ['Galit', 'Malungkot', 'Nasasabik'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'What happens at the door?',
          questionFil: 'Ano ang nangyari sa pintuan?',
          optionsEn: ['She gets a gift', 'Her friend surprises her', 'She leaves'],
          optionsFil: ['May regalo siya', 'Na-surprise siya ng kaibigan', 'Umalis siya'],
          correctIndex: 1,
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
      questions: [
        StoryQuestion(
          questionEn: 'When does Rina go to school?',
          questionFil: 'Kailan pumupunta sa paaralan si Rina?',
          optionsEn: ['Saturday', 'Monday', 'Sunday'],
          optionsFil: ['Sabado', 'Lunes', 'Linggo'],
          correctIndex: 1,
        ),
        StoryQuestion(
          questionEn: 'When is art class?',
          questionFil: 'Kailan ang klase sa sining?',
          optionsEn: ['Monday', 'Friday', 'Wednesday'],
          optionsFil: ['Lunes', 'Biyernes', 'Miyerkules'],
          correctIndex: 2,
        ),
        StoryQuestion(
          questionEn: 'What does Rina do on Saturday?',
          questionFil: 'Ano ang ginagawa ni Rina tuwing Sabado?',
          optionsEn: ['Study', 'Sleep', 'Play with friends'],
          optionsFil: ['Mag-aral', 'Matulog', 'Maglaro kasama mga kaibigan'],
          correctIndex: 2,
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
          optionsFil: ['Maglaro', 'Sabay kumain ng hapunan', 'Pumunta sa paaralan'],
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
