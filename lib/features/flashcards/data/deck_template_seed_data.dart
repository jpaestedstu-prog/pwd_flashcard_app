import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/enums.dart';
import '../models/deck_template.dart';

/// Curated, ship-ready deck templates educators and parents can clone
/// into a learner's custom deck. Card counts target ~12-15 each — long
/// enough to cover a topic, short enough to finish in one session.
class DeckTemplateSeedData {
  DeckTemplateSeedData._();

  static const List<DeckTemplate> all = [
    _sightWordsK2,
    _filipinoBasics,
    _numbers1to20,
    _bodyParts,
    _emotionsFeelings,
    _dailyRoutines,
    _safetySigns,
    _animalsStarter,
  ];

  // ─── Sight Words K-2 (Dolch-aligned) ───────────────────
  static const _sightWordsK2 = DeckTemplate(
    id: 'tmpl_sight_words_k2',
    name: 'Sight Words K-2',
    nameFil: 'Mga Karaniwang Salita K-2',
    description: 'Dolch-aligned high-frequency words for early readers',
    descriptionFil: 'Mga karaniwang salita para sa mga nagsisimulang magbasa',
    icon: Icons.menu_book_rounded,
    color: AppColors.sectionLearning,
    category: FlashcardCategory.classroom,
    cards: [
      DeckTemplateCard(wordEnglish: 'the', wordFilipino: 'ang'),
      DeckTemplateCard(wordEnglish: 'and', wordFilipino: 'at'),
      DeckTemplateCard(wordEnglish: 'is', wordFilipino: 'ay'),
      DeckTemplateCard(wordEnglish: 'a', wordFilipino: 'isang'),
      DeckTemplateCard(wordEnglish: 'to', wordFilipino: 'sa'),
      DeckTemplateCard(wordEnglish: 'in', wordFilipino: 'sa loob'),
      DeckTemplateCard(wordEnglish: 'you', wordFilipino: 'ikaw'),
      DeckTemplateCard(wordEnglish: 'I', wordFilipino: 'ako'),
      DeckTemplateCard(wordEnglish: 'we', wordFilipino: 'kami'),
      DeckTemplateCard(wordEnglish: 'go', wordFilipino: 'pumunta'),
      DeckTemplateCard(wordEnglish: 'see', wordFilipino: 'makita'),
      DeckTemplateCard(wordEnglish: 'like', wordFilipino: 'gusto'),
      DeckTemplateCard(wordEnglish: 'play', wordFilipino: 'maglaro'),
      DeckTemplateCard(wordEnglish: 'come', wordFilipino: 'halika'),
      DeckTemplateCard(wordEnglish: 'help', wordFilipino: 'tulong'),
    ],
  );

  // ─── Filipino Basics ───────────────────────────────────
  static const _filipinoBasics = DeckTemplate(
    id: 'tmpl_filipino_basics',
    name: 'Filipino Basics',
    nameFil: 'Mga Pangunahing Salitang Filipino',
    description: 'Everyday Filipino words every PH learner should know',
    descriptionFil: 'Pang-araw-araw na salitang dapat alam ng bawat Pilipino',
    icon: Icons.translate_rounded,
    color: AppColors.sectionCommunication,
    category: FlashcardCategory.familyAndGreetings,
    cards: [
      DeckTemplateCard(wordEnglish: 'Hello', wordFilipino: 'Kamusta'),
      DeckTemplateCard(wordEnglish: 'Thank you', wordFilipino: 'Salamat'),
      DeckTemplateCard(wordEnglish: 'Please', wordFilipino: 'Pakiusap'),
      DeckTemplateCard(wordEnglish: 'Yes', wordFilipino: 'Oo'),
      DeckTemplateCard(wordEnglish: 'No', wordFilipino: 'Hindi'),
      DeckTemplateCard(wordEnglish: 'Sorry', wordFilipino: 'Paumanhin'),
      DeckTemplateCard(wordEnglish: 'Excuse me', wordFilipino: 'Mawalang-galang'),
      DeckTemplateCard(wordEnglish: 'Good morning', wordFilipino: 'Magandang umaga'),
      DeckTemplateCard(wordEnglish: 'Good night', wordFilipino: 'Magandang gabi'),
      DeckTemplateCard(wordEnglish: 'Friend', wordFilipino: 'Kaibigan'),
      DeckTemplateCard(wordEnglish: 'Family', wordFilipino: 'Pamilya'),
      DeckTemplateCard(wordEnglish: 'Water', wordFilipino: 'Tubig'),
      DeckTemplateCard(wordEnglish: 'Food', wordFilipino: 'Pagkain'),
      DeckTemplateCard(wordEnglish: 'House', wordFilipino: 'Bahay'),
    ],
  );

  // ─── Numbers 1-20 ──────────────────────────────────────
  static const _numbers1to20 = DeckTemplate(
    id: 'tmpl_numbers_1_20',
    name: 'Numbers 1-20',
    nameFil: 'Mga Numero 1-20',
    description: 'Count from one to twenty in English and Filipino',
    descriptionFil: 'Bilang mula isa hanggang dalawampu',
    icon: Icons.looks_one_rounded,
    color: AppColors.categoryNumbers,
    category: FlashcardCategory.numbers,
    cards: [
      DeckTemplateCard(wordEnglish: 'One', wordFilipino: 'Isa'),
      DeckTemplateCard(wordEnglish: 'Two', wordFilipino: 'Dalawa'),
      DeckTemplateCard(wordEnglish: 'Three', wordFilipino: 'Tatlo'),
      DeckTemplateCard(wordEnglish: 'Four', wordFilipino: 'Apat'),
      DeckTemplateCard(wordEnglish: 'Five', wordFilipino: 'Lima'),
      DeckTemplateCard(wordEnglish: 'Six', wordFilipino: 'Anim'),
      DeckTemplateCard(wordEnglish: 'Seven', wordFilipino: 'Pito'),
      DeckTemplateCard(wordEnglish: 'Eight', wordFilipino: 'Walo'),
      DeckTemplateCard(wordEnglish: 'Nine', wordFilipino: 'Siyam'),
      DeckTemplateCard(wordEnglish: 'Ten', wordFilipino: 'Sampu'),
      DeckTemplateCard(wordEnglish: 'Eleven', wordFilipino: 'Labing-isa'),
      DeckTemplateCard(wordEnglish: 'Twelve', wordFilipino: 'Labindalawa'),
      DeckTemplateCard(wordEnglish: 'Thirteen', wordFilipino: 'Labintatlo'),
      DeckTemplateCard(wordEnglish: 'Fifteen', wordFilipino: 'Labinlima'),
      DeckTemplateCard(wordEnglish: 'Twenty', wordFilipino: 'Dalawampu'),
    ],
  );

  // ─── Body Parts ────────────────────────────────────────
  static const _bodyParts = DeckTemplate(
    id: 'tmpl_body_parts',
    name: 'Body Parts',
    nameFil: 'Mga Bahagi ng Katawan',
    description: 'Name the parts of the body — face, limbs, and senses',
    descriptionFil: 'Mga bahagi ng katawan — mukha, kamay, paa',
    icon: Icons.accessibility_new_rounded,
    color: AppColors.categoryBody,
    category: FlashcardCategory.bodyParts,
    cards: [
      DeckTemplateCard(wordEnglish: 'Head', wordFilipino: 'Ulo'),
      DeckTemplateCard(wordEnglish: 'Eyes', wordFilipino: 'Mata'),
      DeckTemplateCard(wordEnglish: 'Ears', wordFilipino: 'Tainga'),
      DeckTemplateCard(wordEnglish: 'Nose', wordFilipino: 'Ilong'),
      DeckTemplateCard(wordEnglish: 'Mouth', wordFilipino: 'Bibig'),
      DeckTemplateCard(wordEnglish: 'Teeth', wordFilipino: 'Ngipin'),
      DeckTemplateCard(wordEnglish: 'Hand', wordFilipino: 'Kamay'),
      DeckTemplateCard(wordEnglish: 'Foot', wordFilipino: 'Paa'),
      DeckTemplateCard(wordEnglish: 'Arm', wordFilipino: 'Braso'),
      DeckTemplateCard(wordEnglish: 'Leg', wordFilipino: 'Binti'),
      DeckTemplateCard(wordEnglish: 'Finger', wordFilipino: 'Daliri'),
      DeckTemplateCard(wordEnglish: 'Hair', wordFilipino: 'Buhok'),
      DeckTemplateCard(wordEnglish: 'Heart', wordFilipino: 'Puso'),
    ],
  );

  // ─── Emotions & Feelings ───────────────────────────────
  static const _emotionsFeelings = DeckTemplate(
    id: 'tmpl_emotions_feelings',
    name: 'Emotions & Feelings',
    nameFil: 'Mga Damdamin',
    description: 'Name how you feel — happy, sad, scared, proud',
    descriptionFil: 'Pangalanan ang nararamdaman mo',
    icon: Icons.mood_rounded,
    color: AppColors.bannerMoodEnd,
    category: FlashcardCategory.emotions,
    cards: [
      DeckTemplateCard(wordEnglish: 'Happy', wordFilipino: 'Masaya'),
      DeckTemplateCard(wordEnglish: 'Sad', wordFilipino: 'Malungkot'),
      DeckTemplateCard(wordEnglish: 'Angry', wordFilipino: 'Galit'),
      DeckTemplateCard(wordEnglish: 'Scared', wordFilipino: 'Takot'),
      DeckTemplateCard(wordEnglish: 'Tired', wordFilipino: 'Pagod'),
      DeckTemplateCard(wordEnglish: 'Excited', wordFilipino: 'Nasasabik'),
      DeckTemplateCard(wordEnglish: 'Calm', wordFilipino: 'Mahinahon'),
      DeckTemplateCard(wordEnglish: 'Confused', wordFilipino: 'Nalilito'),
      DeckTemplateCard(wordEnglish: 'Proud', wordFilipino: 'Ipinagmamalaki'),
      DeckTemplateCard(wordEnglish: 'Shy', wordFilipino: 'Mahiyain'),
      DeckTemplateCard(wordEnglish: 'Surprised', wordFilipino: 'Nagulat'),
      DeckTemplateCard(wordEnglish: 'Lonely', wordFilipino: 'Nag-iisa'),
    ],
  );

  // ─── Daily Routines ────────────────────────────────────
  static const _dailyRoutines = DeckTemplate(
    id: 'tmpl_daily_routines',
    name: 'Daily Routines',
    nameFil: 'Pang-araw-araw na Gawain',
    description: 'Everyday actions — wake up, eat, brush teeth, sleep',
    descriptionFil: 'Mga gawain sa araw-araw',
    icon: Icons.schedule_rounded,
    color: AppColors.bannerGuidedStart,
    category: FlashcardCategory.daysAndTime,
    cards: [
      DeckTemplateCard(wordEnglish: 'Wake up', wordFilipino: 'Gumising'),
      DeckTemplateCard(wordEnglish: 'Brush teeth', wordFilipino: 'Magsipilyo'),
      DeckTemplateCard(wordEnglish: 'Take a bath', wordFilipino: 'Maligo'),
      DeckTemplateCard(wordEnglish: 'Get dressed', wordFilipino: 'Magbihis'),
      DeckTemplateCard(wordEnglish: 'Eat breakfast', wordFilipino: 'Mag-almusal'),
      DeckTemplateCard(wordEnglish: 'Go to school', wordFilipino: 'Pumunta sa paaralan'),
      DeckTemplateCard(wordEnglish: 'Study', wordFilipino: 'Mag-aral'),
      DeckTemplateCard(wordEnglish: 'Play', wordFilipino: 'Maglaro'),
      DeckTemplateCard(wordEnglish: 'Eat lunch', wordFilipino: 'Maghapunan'),
      DeckTemplateCard(wordEnglish: 'Read a book', wordFilipino: 'Magbasa ng libro'),
      DeckTemplateCard(wordEnglish: 'Wash hands', wordFilipino: 'Maghugas ng kamay'),
      DeckTemplateCard(wordEnglish: 'Go to sleep', wordFilipino: 'Matulog'),
    ],
  );

  // ─── Safety Signs ──────────────────────────────────────
  // High mission fit for PWD learners — environment-recognition is a
  // core independent-living skill.
  static const _safetySigns = DeckTemplate(
    id: 'tmpl_safety_signs',
    name: 'Safety Signs',
    nameFil: 'Mga Babala sa Kaligtasan',
    description: 'Recognize stop, exit, danger, and other safety signs',
    descriptionFil: 'Mga senyas ng kaligtasan na dapat kilalanin',
    icon: Icons.shield_rounded,
    color: AppColors.error,
    category: FlashcardCategory.classroom,
    cards: [
      DeckTemplateCard(wordEnglish: 'Stop', wordFilipino: 'Tigil'),
      DeckTemplateCard(wordEnglish: 'Go', wordFilipino: 'Tuloy'),
      DeckTemplateCard(wordEnglish: 'Wait', wordFilipino: 'Hintay'),
      DeckTemplateCard(wordEnglish: 'Exit', wordFilipino: 'Labasan'),
      DeckTemplateCard(wordEnglish: 'Entrance', wordFilipino: 'Pasukan'),
      DeckTemplateCard(wordEnglish: 'Danger', wordFilipino: 'Panganib'),
      DeckTemplateCard(wordEnglish: 'Warning', wordFilipino: 'Babala'),
      DeckTemplateCard(wordEnglish: 'Caution', wordFilipino: 'Mag-ingat'),
      DeckTemplateCard(wordEnglish: 'No entry', wordFilipino: 'Bawal pumasok'),
      DeckTemplateCard(wordEnglish: 'No smoking', wordFilipino: 'Bawal manigarilyo'),
      DeckTemplateCard(wordEnglish: 'Fire exit', wordFilipino: 'Labasan sa sunog'),
      DeckTemplateCard(wordEnglish: 'First aid', wordFilipino: 'Pangunang lunas'),
    ],
  );

  // ─── Animals Starter ───────────────────────────────────
  static const _animalsStarter = DeckTemplate(
    id: 'tmpl_animals_starter',
    name: 'Animals Starter Pack',
    nameFil: 'Mga Hayop (Panimula)',
    description: 'Common pets, farm animals, and wildlife',
    descriptionFil: 'Mga alagang hayop, hayop sa bukid, at sa kagubatan',
    icon: Icons.pets_rounded,
    color: AppColors.categoryAnimals,
    category: FlashcardCategory.animals,
    cards: [
      DeckTemplateCard(wordEnglish: 'Dog', wordFilipino: 'Aso'),
      DeckTemplateCard(wordEnglish: 'Cat', wordFilipino: 'Pusa'),
      DeckTemplateCard(wordEnglish: 'Bird', wordFilipino: 'Ibon'),
      DeckTemplateCard(wordEnglish: 'Fish', wordFilipino: 'Isda'),
      DeckTemplateCard(wordEnglish: 'Chicken', wordFilipino: 'Manok'),
      DeckTemplateCard(wordEnglish: 'Cow', wordFilipino: 'Baka'),
      DeckTemplateCard(wordEnglish: 'Pig', wordFilipino: 'Baboy'),
      DeckTemplateCard(wordEnglish: 'Horse', wordFilipino: 'Kabayo'),
      DeckTemplateCard(wordEnglish: 'Goat', wordFilipino: 'Kambing'),
      DeckTemplateCard(wordEnglish: 'Duck', wordFilipino: 'Pato'),
      DeckTemplateCard(wordEnglish: 'Rabbit', wordFilipino: 'Kuneho'),
      DeckTemplateCard(wordEnglish: 'Butterfly', wordFilipino: 'Paruparo'),
      DeckTemplateCard(wordEnglish: 'Carabao', wordFilipino: 'Kalabaw'),
    ],
  );
}
