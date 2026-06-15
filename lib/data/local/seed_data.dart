import '../models/enums.dart';
import '../models/models.dart';

/// Pre-loaded flashcard data for all 12 categories
/// Each category has 12-19 words with English/Filipino pairs
class SeedData {
  SeedData._();

  /// Every seed flashcard with its [_definitions] entry applied. Built once
  /// and cached, so callers (which hit this often) reuse the same list and
  /// identity stays stable. Cards without a definition are returned as-is.
  static List<Flashcard> get allFlashcards => _allWithDefinitions;

  static final List<Flashcard> _allWithDefinitions = [
    for (final card in _rawSeed)
      _definitions.containsKey(card.id)
          ? card.copyWith(definition: _definitions[card.id])
          : card,
  ];

  static final List<Flashcard> _rawSeed = [
    ..._animals,
    ..._colorsAndShapes,
    ..._numbers,
    ..._bodyParts,
    ..._foodAndDrinks,
    ..._familyAndGreetings,
    ..._clothing,
    ..._weather,
    ..._classroom,
    ..._transportation,
    ..._emotions,
    ..._daysAndTime,
    ..._actions,
  ];

  static List<Flashcard> getByCategory(FlashcardCategory category) {
    return allFlashcards.where((f) => f.category == category).toList();
  }

  // â”€â”€â”€ Animals â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _animals = [
    const Flashcard(id: 'a01', wordEnglish: 'Dog', wordFilipino: 'Aso', exampleSentence: 'The dog is my best friend.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a02', wordEnglish: 'Cat', wordFilipino: 'Pusa', exampleSentence: 'The cat likes to sleep.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a03', wordEnglish: 'Bird', wordFilipino: 'Ibon', exampleSentence: 'The bird can fly high.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a04', wordEnglish: 'Fish', wordFilipino: 'Isda', exampleSentence: 'The fish swims in water.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a05', wordEnglish: 'Butterfly', wordFilipino: 'Paru-paro', exampleSentence: 'The butterfly is colorful.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a06', wordEnglish: 'Horse', wordFilipino: 'Kabayo', exampleSentence: 'The horse can run fast.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a07', wordEnglish: 'Chicken', wordFilipino: 'Manok', exampleSentence: 'The chicken lays eggs.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a08', wordEnglish: 'Pig', wordFilipino: 'Baboy', exampleSentence: 'The pig loves mud.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a09', wordEnglish: 'Cow', wordFilipino: 'Baka', exampleSentence: 'The cow gives us milk.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a10', wordEnglish: 'Frog', wordFilipino: 'Palaka', exampleSentence: 'The frog can jump high.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a11', wordEnglish: 'Elephant', wordFilipino: 'Elepante', exampleSentence: 'The elephant is very big.', category: FlashcardCategory.animals),
    const Flashcard(id: 'a12', wordEnglish: 'Rabbit', wordFilipino: 'Kuneho', exampleSentence: 'The rabbit has long ears.', category: FlashcardCategory.animals),
  ];

  // â”€â”€â”€ Colors & Shapes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _colorsAndShapes = [
    const Flashcard(id: 'c01', wordEnglish: 'Red', wordFilipino: 'Pula', exampleSentence: 'The apple is red.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c02', wordEnglish: 'Blue', wordFilipino: 'Asul', exampleSentence: 'The sky is blue.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c03', wordEnglish: 'Yellow', wordFilipino: 'Dilaw', exampleSentence: 'The sun is yellow.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c04', wordEnglish: 'Green', wordFilipino: 'Berde', exampleSentence: 'The grass is green.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c05', wordEnglish: 'Orange', wordFilipino: 'Kahel', exampleSentence: 'The orange is round.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c06', wordEnglish: 'Purple', wordFilipino: 'Lila', exampleSentence: 'The flower is purple.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c07', wordEnglish: 'Circle', wordFilipino: 'Bilog', exampleSentence: 'A ball is a circle.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c08', wordEnglish: 'Square', wordFilipino: 'Parisukat', exampleSentence: 'The box is a square.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c09', wordEnglish: 'Triangle', wordFilipino: 'Tatsulok', exampleSentence: 'A triangle has three sides.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c10', wordEnglish: 'Star', wordFilipino: 'Bituin', exampleSentence: 'The star is bright.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c11', wordEnglish: 'Heart', wordFilipino: 'Puso', exampleSentence: 'I drew a heart.', category: FlashcardCategory.colorsAndShapes),
    const Flashcard(id: 'c12', wordEnglish: 'White', wordFilipino: 'Puti', exampleSentence: 'The cloud is white.', category: FlashcardCategory.colorsAndShapes),
    // Everyday object the Word Hunt camera can recognize (ML Kit label).
    const Flashcard(id: 'c13', wordEnglish: 'Flower', wordFilipino: 'Bulaklak', exampleSentence: 'The flower smells nice.', category: FlashcardCategory.colorsAndShapes),
  ];

  // â”€â”€â”€ Numbers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _numbers = [
    const Flashcard(id: 'n01', wordEnglish: 'One', wordFilipino: 'Isa', exampleSentence: 'I have one pencil.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n02', wordEnglish: 'Two', wordFilipino: 'Dalawa', exampleSentence: 'I have two hands.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n03', wordEnglish: 'Three', wordFilipino: 'Tatlo', exampleSentence: 'There are three dogs.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n04', wordEnglish: 'Four', wordFilipino: 'Apat', exampleSentence: 'A table has four legs.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n05', wordEnglish: 'Five', wordFilipino: 'Lima', exampleSentence: 'I have five fingers.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n06', wordEnglish: 'Six', wordFilipino: 'Anim', exampleSentence: 'Six birds are flying.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n07', wordEnglish: 'Seven', wordFilipino: 'Pito', exampleSentence: 'Seven days in a week.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n08', wordEnglish: 'Eight', wordFilipino: 'Walo', exampleSentence: 'An octopus has eight arms.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n09', wordEnglish: 'Nine', wordFilipino: 'Siyam', exampleSentence: 'I see nine stars.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n10', wordEnglish: 'Ten', wordFilipino: 'Sampu', exampleSentence: 'Count to ten!', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n11', wordEnglish: 'Twenty', wordFilipino: 'Dalawampu', exampleSentence: 'I have twenty blocks.', category: FlashcardCategory.numbers),
    const Flashcard(id: 'n12', wordEnglish: 'Hundred', wordFilipino: 'Isang Daan', exampleSentence: 'There are a hundred pages.', category: FlashcardCategory.numbers),
  ];

  // â”€â”€â”€ Body Parts â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _bodyParts = [
    const Flashcard(id: 'b01', wordEnglish: 'Head', wordFilipino: 'Ulo', exampleSentence: 'I wear a hat on my head.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b02', wordEnglish: 'Eyes', wordFilipino: 'Mata', exampleSentence: 'I see with my eyes.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b03', wordEnglish: 'Ears', wordFilipino: 'Tenga', exampleSentence: 'I hear with my ears.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b04', wordEnglish: 'Nose', wordFilipino: 'Ilong', exampleSentence: 'I smell with my nose.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b05', wordEnglish: 'Mouth', wordFilipino: 'Bibig', exampleSentence: 'I eat with my mouth.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b06', wordEnglish: 'Hands', wordFilipino: 'Kamay', exampleSentence: 'I clap my hands.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b07', wordEnglish: 'Feet', wordFilipino: 'Paa', exampleSentence: 'I walk with my feet.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b08', wordEnglish: 'Fingers', wordFilipino: 'Daliri', exampleSentence: 'I have ten fingers.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b09', wordEnglish: 'Hair', wordFilipino: 'Buhok', exampleSentence: 'My hair is black.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b10', wordEnglish: 'Teeth', wordFilipino: 'Ngipin', exampleSentence: 'I brush my teeth.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b11', wordEnglish: 'Shoulders', wordFilipino: 'Balikat', exampleSentence: 'I shrug my shoulders.', category: FlashcardCategory.bodyParts),
    const Flashcard(id: 'b12', wordEnglish: 'Knees', wordFilipino: 'Tuhod', exampleSentence: 'I bend my knees.', category: FlashcardCategory.bodyParts),
  ];

  // â”€â”€â”€ Food & Drinks â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _foodAndDrinks = [
    const Flashcard(id: 'f01', wordEnglish: 'Rice', wordFilipino: 'Kanin', exampleSentence: 'We eat rice every day.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f02', wordEnglish: 'Water', wordFilipino: 'Tubig', exampleSentence: 'I drink water.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f03', wordEnglish: 'Bread', wordFilipino: 'Tinapay', exampleSentence: 'The bread is soft.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f04', wordEnglish: 'Milk', wordFilipino: 'Gatas', exampleSentence: 'Milk is good for bones.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f05', wordEnglish: 'Apple', wordFilipino: 'Mansanas', exampleSentence: 'An apple a day keeps the doctor away.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f06', wordEnglish: 'Banana', wordFilipino: 'Saging', exampleSentence: 'The banana is yellow.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f07', wordEnglish: 'Egg', wordFilipino: 'Itlog', exampleSentence: 'I eat eggs for breakfast.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f08', wordEnglish: 'Chicken', wordFilipino: 'Manok', exampleSentence: 'Chicken adobo is delicious.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f09', wordEnglish: 'Juice', wordFilipino: 'Katas', exampleSentence: 'I like orange juice.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f10', wordEnglish: 'Vegetables', wordFilipino: 'Gulay', exampleSentence: 'Vegetables are healthy.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f11', wordEnglish: 'Soup', wordFilipino: 'Sabaw', exampleSentence: 'The soup is warm.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f12', wordEnglish: 'Candy', wordFilipino: 'Kendi', exampleSentence: 'The candy is sweet.', category: FlashcardCategory.foodAndDrinks),
    // Everyday objects the Word Hunt camera can recognize (ML Kit labels).
    const Flashcard(id: 'f13', wordEnglish: 'Bottle', wordFilipino: 'Bote', exampleSentence: 'The bottle is full of water.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f14', wordEnglish: 'Cup', wordFilipino: 'Tasa', exampleSentence: 'I drink milk from a cup.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f15', wordEnglish: 'Spoon', wordFilipino: 'Kutsara', exampleSentence: 'I eat soup with a spoon.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f16', wordEnglish: 'Fork', wordFilipino: 'Tinidor', exampleSentence: 'I use a fork to eat.', category: FlashcardCategory.foodAndDrinks),
    const Flashcard(id: 'f17', wordEnglish: 'Plate', wordFilipino: 'Plato', exampleSentence: 'The food is on the plate.', category: FlashcardCategory.foodAndDrinks),
  ];

  // â”€â”€â”€ Family & Greetings â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _familyAndGreetings = [
    const Flashcard(id: 'g01', wordEnglish: 'Mother', wordFilipino: 'Nanay', exampleSentence: 'My mother loves me.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g02', wordEnglish: 'Father', wordFilipino: 'Tatay', exampleSentence: 'My father is strong.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g03', wordEnglish: 'Brother', wordFilipino: 'Kapatid na lalaki', exampleSentence: 'My brother plays with me.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g04', wordEnglish: 'Sister', wordFilipino: 'Kapatid na babae', exampleSentence: 'My sister is kind.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g05', wordEnglish: 'Grandmother', wordFilipino: 'Lola', exampleSentence: 'My grandmother tells stories.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g06', wordEnglish: 'Grandfather', wordFilipino: 'Lolo', exampleSentence: 'My grandfather is wise.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g07', wordEnglish: 'Hello', wordFilipino: 'Kumusta', exampleSentence: 'Hello! How are you?', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g08', wordEnglish: 'Thank You', wordFilipino: 'Salamat', exampleSentence: 'Thank you for helping me.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g09', wordEnglish: 'Please', wordFilipino: 'Pakiusap', exampleSentence: 'Please share with me.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g10', wordEnglish: 'Sorry', wordFilipino: 'Pasensya', exampleSentence: 'I am sorry for being late.', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g11', wordEnglish: 'Good Morning', wordFilipino: 'Magandang Umaga', exampleSentence: 'Good morning, teacher!', category: FlashcardCategory.familyAndGreetings),
    const Flashcard(id: 'g12', wordEnglish: 'Friend', wordFilipino: 'Kaibigan', exampleSentence: 'You are my best friend.', category: FlashcardCategory.familyAndGreetings),
  ];

  // â”€â”€â”€ Clothing â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _clothing = [
    const Flashcard(id: 'cl01', wordEnglish: 'T-shirt', wordFilipino: 'T-shirt', exampleSentence: 'I wear a blue t-shirt.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl02', wordEnglish: 'Pants', wordFilipino: 'Pantalon', exampleSentence: 'My pants are long.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl03', wordEnglish: 'Dress', wordFilipino: 'Bestida', exampleSentence: 'She wears a pretty dress.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl04', wordEnglish: 'Socks', wordFilipino: 'Medyas', exampleSentence: 'I put on my socks.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl05', wordEnglish: 'Shoes', wordFilipino: 'Sapatos', exampleSentence: 'My shoes are new.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl06', wordEnglish: 'Cap', wordFilipino: 'Sombrero', exampleSentence: 'I wear a cap in the sun.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl07', wordEnglish: 'Jacket', wordFilipino: 'Dyaket', exampleSentence: 'I need a jacket when it is cold.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl08', wordEnglish: 'Uniform', wordFilipino: 'Uniporme', exampleSentence: 'I wear a uniform to school.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl09', wordEnglish: 'Shorts', wordFilipino: 'Shorts', exampleSentence: 'I wear shorts when it is hot.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl10', wordEnglish: 'Gloves', wordFilipino: 'Guwantes', exampleSentence: 'Gloves keep my hands warm.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl11', wordEnglish: 'Glasses', wordFilipino: 'Salamin sa mata', exampleSentence: 'I wear glasses to see better.', category: FlashcardCategory.clothing),
    const Flashcard(id: 'cl12', wordEnglish: 'Backpack', wordFilipino: 'Bag', exampleSentence: 'My backpack has my books.', category: FlashcardCategory.clothing),
  ];

  // â”€â”€â”€ Weather â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _weather = [
    const Flashcard(id: 'w01', wordEnglish: 'Sunny', wordFilipino: 'Maaraw', exampleSentence: 'It is sunny today.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w02', wordEnglish: 'Rainy', wordFilipino: 'Maulan', exampleSentence: 'It is rainy outside.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w03', wordEnglish: 'Cloudy', wordFilipino: 'Maulap', exampleSentence: 'The sky is cloudy.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w04', wordEnglish: 'Rainbow', wordFilipino: 'Bahaghari', exampleSentence: 'I see a beautiful rainbow.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w05', wordEnglish: 'Storm', wordFilipino: 'Bagyo', exampleSentence: 'The storm is very strong.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w06', wordEnglish: 'Windy', wordFilipino: 'Mahangin', exampleSentence: 'It is windy today.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w07', wordEnglish: 'Hot', wordFilipino: 'Mainit', exampleSentence: 'It is very hot in summer.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w08', wordEnglish: 'Cold', wordFilipino: 'Malamig', exampleSentence: 'It is cold in December.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w09', wordEnglish: 'Flood', wordFilipino: 'Baha', exampleSentence: 'The rain caused a flood.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w10', wordEnglish: 'Lightning', wordFilipino: 'Kidlat', exampleSentence: 'Lightning is bright and fast.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w11', wordEnglish: 'Partly Cloudy', wordFilipino: 'Bahagyang Maulap', exampleSentence: 'It is partly cloudy today.', category: FlashcardCategory.weather),
    const Flashcard(id: 'w12', wordEnglish: 'Night', wordFilipino: 'Gabi', exampleSentence: 'The stars come out at night.', category: FlashcardCategory.weather),
  ];

  // â”€â”€â”€ Classroom â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _classroom = [
    const Flashcard(id: 'cr01', wordEnglish: 'Book', wordFilipino: 'Aklat', exampleSentence: 'I like to read a book.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr02', wordEnglish: 'Pencil', wordFilipino: 'Lapis', exampleSentence: 'I write with a pencil.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr03', wordEnglish: 'Notebook', wordFilipino: 'Kuwaderno', exampleSentence: 'I write in my notebook.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr04', wordEnglish: 'Crayon', wordFilipino: 'Krayola', exampleSentence: 'I color with a crayon.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr05', wordEnglish: 'Ruler', wordFilipino: 'Ruler', exampleSentence: 'I measure with a ruler.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr06', wordEnglish: 'Scissors', wordFilipino: 'Gunting', exampleSentence: 'I cut paper with scissors.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr07', wordEnglish: 'Pen', wordFilipino: 'Bolpen', exampleSentence: 'The pen has blue ink.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr08', wordEnglish: 'Paint', wordFilipino: 'Pintura', exampleSentence: 'I paint a picture.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr09', wordEnglish: 'Eraser', wordFilipino: 'Pambura', exampleSentence: 'I erase my mistake.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr10', wordEnglish: 'Chair', wordFilipino: 'Upuan', exampleSentence: 'I sit on a chair.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr11', wordEnglish: 'School', wordFilipino: 'Paaralan', exampleSentence: 'I go to school every day.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr12', wordEnglish: 'Teacher', wordFilipino: 'Guro', exampleSentence: 'Our teacher is kind.', category: FlashcardCategory.classroom),
    // Everyday objects the Word Hunt camera can recognize (ML Kit labels).
    const Flashcard(id: 'cr13', wordEnglish: 'Table', wordFilipino: 'Mesa', exampleSentence: 'The book is on the table.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr14', wordEnglish: 'Paper', wordFilipino: 'Papel', exampleSentence: 'I write on the paper.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr15', wordEnglish: 'Ball', wordFilipino: 'Bola', exampleSentence: 'We play with a ball.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr16', wordEnglish: 'Door', wordFilipino: 'Pinto', exampleSentence: 'Please close the door.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr17', wordEnglish: 'Window', wordFilipino: 'Bintana', exampleSentence: 'I look out the window.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr18', wordEnglish: 'Television', wordFilipino: 'Telebisyon', exampleSentence: 'We watch television at home.', category: FlashcardCategory.classroom),
    const Flashcard(id: 'cr19', wordEnglish: 'Phone', wordFilipino: 'Telepono', exampleSentence: 'My mother has a phone.', category: FlashcardCategory.classroom),
  ];

  // â”€â”€â”€ Transportation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _transportation = [
    const Flashcard(id: 't01', wordEnglish: 'Car', wordFilipino: 'Kotse', exampleSentence: 'We ride in a car.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't02', wordEnglish: 'Bus', wordFilipino: 'Bus', exampleSentence: 'The bus takes us to school.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't03', wordEnglish: 'Bicycle', wordFilipino: 'Bisikleta', exampleSentence: 'I ride my bicycle in the park.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't04', wordEnglish: 'Airplane', wordFilipino: 'Eroplano', exampleSentence: 'The airplane flies in the sky.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't05', wordEnglish: 'Ship', wordFilipino: 'Barko', exampleSentence: 'The ship sails on the sea.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't06', wordEnglish: 'Train', wordFilipino: 'Tren', exampleSentence: 'The train goes very fast.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't07', wordEnglish: 'Motorcycle', wordFilipino: 'Motorsiklo', exampleSentence: 'A motorcycle has two wheels.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't08', wordEnglish: 'Helicopter', wordFilipino: 'Helikopter', exampleSentence: 'The helicopter flies above us.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't09', wordEnglish: 'Taxi', wordFilipino: 'Taksi', exampleSentence: 'We take a taxi in the city.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't10', wordEnglish: 'Boat', wordFilipino: 'Bangka', exampleSentence: 'The boat floats on water.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't11', wordEnglish: 'Walk', wordFilipino: 'Lakad', exampleSentence: 'I walk to school.', category: FlashcardCategory.transportation),
    const Flashcard(id: 't12', wordEnglish: 'Road', wordFilipino: 'Daan', exampleSentence: 'Look both ways before crossing the road.', category: FlashcardCategory.transportation),
  ];

  // â”€â”€â”€ Emotions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _emotions = [
    const Flashcard(id: 'e01', wordEnglish: 'Happy', wordFilipino: 'Masaya', exampleSentence: 'I am happy today!', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e02', wordEnglish: 'Sad', wordFilipino: 'Malungkot', exampleSentence: 'She feels sad today.', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e03', wordEnglish: 'Angry', wordFilipino: 'Galit', exampleSentence: 'Do not be angry.', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e04', wordEnglish: 'Scared', wordFilipino: 'Takot', exampleSentence: 'The child is scared of the dark.', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e05', wordEnglish: 'Surprised', wordFilipino: 'Nagulat', exampleSentence: 'I was surprised by the gift!', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e06', wordEnglish: 'Loved', wordFilipino: 'Minamahal', exampleSentence: 'I feel loved by my family.', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e07', wordEnglish: 'Sleepy', wordFilipino: 'Inaantok', exampleSentence: 'I feel sleepy at night.', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e08', wordEnglish: 'Sick', wordFilipino: 'May sakit', exampleSentence: 'He is sick and needs rest.', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e09', wordEnglish: 'Proud', wordFilipino: 'Proud', exampleSentence: 'I am proud of my work.', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e10', wordEnglish: 'Confused', wordFilipino: 'Naguguluhan', exampleSentence: 'I am confused by the puzzle.', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e11', wordEnglish: 'Excited', wordFilipino: 'Nasasabik', exampleSentence: 'I am excited for the trip!', category: FlashcardCategory.emotions),
    const Flashcard(id: 'e12', wordEnglish: 'Calm', wordFilipino: 'Kalmado', exampleSentence: 'Take a deep breath and stay calm.', category: FlashcardCategory.emotions),
  ];

  // â”€â”€â”€ Days & Time â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  static final List<Flashcard> _daysAndTime = [
    const Flashcard(id: 'd01', wordEnglish: 'Monday', wordFilipino: 'Lunes', exampleSentence: 'Monday is the first day of school.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd02', wordEnglish: 'Tuesday', wordFilipino: 'Martes', exampleSentence: 'We have art class on Tuesday.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd03', wordEnglish: 'Wednesday', wordFilipino: 'Miyerkules', exampleSentence: 'Wednesday is in the middle of the week.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd04', wordEnglish: 'Thursday', wordFilipino: 'Huwebes', exampleSentence: 'Thursday comes before Friday.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd05', wordEnglish: 'Friday', wordFilipino: 'Biyernes', exampleSentence: 'Friday is the last school day.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd06', wordEnglish: 'Saturday', wordFilipino: 'Sabado', exampleSentence: 'I play outside on Saturday.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd07', wordEnglish: 'Sunday', wordFilipino: 'Linggo', exampleSentence: 'Sunday is a rest day.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd08', wordEnglish: 'Morning', wordFilipino: 'Umaga', exampleSentence: 'I wake up in the morning.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd09', wordEnglish: 'Afternoon', wordFilipino: 'Hapon', exampleSentence: 'I eat lunch in the afternoon.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd10', wordEnglish: 'Evening', wordFilipino: 'Gabi', exampleSentence: 'We eat dinner in the evening.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd11', wordEnglish: 'Clock', wordFilipino: 'Orasan', exampleSentence: 'The clock shows the time.', category: FlashcardCategory.daysAndTime),
    const Flashcard(id: 'd12', wordEnglish: 'Today', wordFilipino: 'Ngayon', exampleSentence: 'Today is a beautiful day!', category: FlashcardCategory.daysAndTime),
  ];

  // ─── Actions / Verbs ─────────────────────────────────────────────
  // Action words pair best with a short looping "Show Me" clip (a character
  // performing the action) — far clearer than a static picture or a written
  // definition. Clips/photos attach by category+word through the media
  // manifests (assets/data/action_clip_manifest.json + photo manifest).
  static final List<Flashcard> _actions = [
    const Flashcard(id: 'ac01', wordEnglish: 'Run', wordFilipino: 'Tumakbo', exampleSentence: 'The boy can run fast.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac02', wordEnglish: 'Walk', wordFilipino: 'Maglakad', exampleSentence: 'We walk to school every day.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac03', wordEnglish: 'Jump', wordFilipino: 'Tumalon', exampleSentence: 'I can jump very high.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac04', wordEnglish: 'Eat', wordFilipino: 'Kumain', exampleSentence: 'We eat rice for lunch.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac05', wordEnglish: 'Drink', wordFilipino: 'Uminom', exampleSentence: 'I drink water every day.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac06', wordEnglish: 'Sleep', wordFilipino: 'Matulog', exampleSentence: 'Babies sleep a lot.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac07', wordEnglish: 'Read', wordFilipino: 'Magbasa', exampleSentence: 'I read a book at night.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac08', wordEnglish: 'Write', wordFilipino: 'Magsulat', exampleSentence: 'She can write her name.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac09', wordEnglish: 'Sing', wordFilipino: 'Kumanta', exampleSentence: 'We sing in music class.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac10', wordEnglish: 'Dance', wordFilipino: 'Sumayaw', exampleSentence: 'They dance at the party.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac11', wordEnglish: 'Clap', wordFilipino: 'Pumalakpak', exampleSentence: 'We clap for the winner.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac12', wordEnglish: 'Sit', wordFilipino: 'Umupo', exampleSentence: 'Please sit on the chair.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac13', wordEnglish: 'Stand', wordFilipino: 'Tumayo', exampleSentence: 'We stand for the flag.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac14', wordEnglish: 'Open', wordFilipino: 'Magbukas', exampleSentence: 'Open the door, please.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac15', wordEnglish: 'Close', wordFilipino: 'Magsara', exampleSentence: 'Close the window now.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac16', wordEnglish: 'Wave', wordFilipino: 'Kumaway', exampleSentence: 'I wave goodbye to mom.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac17', wordEnglish: 'Cry', wordFilipino: 'Umiyak', exampleSentence: 'The baby starts to cry.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac18', wordEnglish: 'Laugh', wordFilipino: 'Tumawa', exampleSentence: 'We laugh at the funny joke.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac19', wordEnglish: 'Swim', wordFilipino: 'Lumangoy', exampleSentence: 'Fish swim in the sea.', category: FlashcardCategory.actions),
    const Flashcard(id: 'ac20', wordEnglish: 'Play', wordFilipino: 'Maglaro', exampleSentence: 'Kids play in the park.', category: FlashcardCategory.actions),
  ];

  // ─── Definitions ─────────────────────────────────────────────────
  // Short, kid-friendly meanings keyed by flashcard id, applied to every
  // seed card via [allFlashcards]. Surfaced in the Word Hunt camera sheet
  // (and available anywhere through [Flashcard.definition]). English-only,
  // matching the example sentences. Fully offline — no dictionary lookups.
  static const Map<String, String> _definitions = {
    // Animals
    'a01': 'A dog is a friendly animal that many people keep as a pet.',
    'a02': "A cat is a small furry pet that says 'meow' and likes to nap.",
    'a03': 'A bird is an animal with feathers and wings that can fly and sing.',
    'a04': 'A fish is an animal that lives in water and breathes through gills.',
    'a05':
        'A butterfly is an insect with big colorful wings that flies from flower to flower.',
    'a06': 'A horse is a large strong animal that people can ride.',
    'a07': "A chicken is a farm bird that lays eggs and says 'cluck'.",
    'a08': 'A pig is a pink farm animal that likes to roll in the mud.',
    'a09': "A cow is a big farm animal that gives us milk and says 'moo'.",
    'a10': 'A frog is a small green animal that jumps and lives near water.',
    'a11': 'An elephant is a huge gray animal with big ears and a long trunk.',
    'a12': 'A rabbit is a small soft animal with long ears that hops.',
    // Colors & Shapes
    'c01': 'Red is the bright color of apples, tomatoes, and fire trucks.',
    'c02': 'Blue is the color of the clear sky and the deep sea.',
    'c03': 'Yellow is the bright color of the sun and bananas.',
    'c04': 'Green is the color of grass, leaves, and many plants.',
    'c05': 'Orange is the color you get by mixing red and yellow, like a carrot.',
    'c06': 'Purple is the color made by mixing red and blue, like grapes.',
    'c07': 'A circle is a round shape with no corners, like a wheel.',
    'c08': 'A square is a shape with four equal sides and four corners.',
    'c09': 'A triangle is a shape with three straight sides and three corners.',
    'c10': 'A star is a shape with five points, like the ones in the night sky.',
    'c11': 'A heart is a shape we use to show love.',
    'c12': 'White is the color of clouds, milk, and fresh snow.',
    'c13': 'A flower is the colorful, sweet-smelling part of a plant.',
    // Numbers
    'n01': 'One is the first counting number, written as 1.',
    'n02': 'Two is the number that comes after one, written as 2.',
    'n03': 'Three is the number that comes after two, written as 3.',
    'n04': 'Four is the number that comes after three, written as 4.',
    'n05': 'Five is the number of fingers on one hand, written as 5.',
    'n06': 'Six is the number that comes after five, written as 6.',
    'n07': 'Seven is the number of days in a week, written as 7.',
    'n08': 'Eight is the number that comes after seven, written as 8.',
    'n09': 'Nine is the number that comes after eight, written as 9.',
    'n10': 'Ten is the number of fingers on both hands, written as 10.',
    'n11': 'Twenty is two groups of ten, written as 20.',
    'n12': 'A hundred is ten groups of ten, written as 100.',
    // Body Parts
    'b01': 'The head is the top part of your body where your face is.',
    'b02': 'Eyes are the parts of your face that you use to see.',
    'b03': 'Ears are the parts of your body that you use to hear.',
    'b04': 'The nose is the part of your face you use to smell and breathe.',
    'b05': 'The mouth is the part of your face you use to eat and talk.',
    'b06': 'Hands are the parts at the ends of your arms that hold things.',
    'b07': 'Feet are the parts at the ends of your legs that you stand on.',
    'b08': 'Fingers are the long parts of your hand that grab and point.',
    'b09': 'Hair is the soft strands that grow on top of your head.',
    'b10': 'Teeth are the hard white parts in your mouth used to chew.',
    'b11': 'Shoulders are where your arms join the top of your body.',
    'b12': 'Knees are the parts in the middle of your legs that bend.',
    // Food & Drinks
    'f01': 'Rice is small white grains that many people eat as a meal.',
    'f02': 'Water is the clear drink we need every day to stay healthy.',
    'f03': 'Bread is a soft food made from flour that we bake and eat.',
    'f04': 'Milk is a white drink from cows that helps bones grow strong.',
    'f05': 'An apple is a round, crunchy fruit that can be red, green, or yellow.',
    'f06': 'A banana is a long, curved yellow fruit that is soft and sweet.',
    'f07': 'An egg is an oval food from chickens that we cook and eat.',
    'f08': 'Chicken is the meat from a chicken that people cook and eat.',
    'f09': 'Juice is a sweet drink made by squeezing fruit.',
    'f10': 'Vegetables are healthy plant foods like carrots, beans, and spinach.',
    'f11': 'Soup is a warm liquid food made by cooking things in water.',
    'f12': 'Candy is a small sweet treat made mostly of sugar.',
    'f13': 'A bottle is a container with a narrow top that holds drinks.',
    'f14': 'A cup is a small open container that you drink from.',
    'f15': 'A spoon is a tool with a small bowl shape for eating soup and rice.',
    'f16': 'A fork is a tool with pointed prongs for picking up food.',
    'f17': 'A plate is a flat dish that you put your food on.',
    // Family & Greetings
    'g01': 'A mother is a woman who has a child and cares for the family.',
    'g02': 'A father is a man who has a child and cares for the family.',
    'g03': 'A brother is a boy who has the same parents as you.',
    'g04': 'A sister is a girl who has the same parents as you.',
    'g05': 'A grandmother is the mother of your mother or father.',
    'g06': 'A grandfather is the father of your mother or father.',
    'g07': "'Hello' is a friendly word you say when you greet someone.",
    'g08': "'Thank you' is what you say to show you are grateful.",
    'g09': "'Please' is a polite word you use when you ask for something.",
    'g10': "'Sorry' is what you say when you feel bad about a mistake.",
    'g11': "'Good morning' is a greeting you say early in the day.",
    'g12': 'A friend is someone you like and enjoy spending time with.',
    // Clothing
    'cl01': 'A t-shirt is a light shirt with short sleeves you pull over your head.',
    'cl02': 'Pants are clothes that cover each leg from your waist to your ankles.',
    'cl03': 'A dress is a one-piece outfit, often worn by girls and women.',
    'cl04': 'Socks are soft clothes you wear on your feet inside your shoes.',
    'cl05': 'Shoes are what you wear on your feet to protect them when you walk.',
    'cl06': 'A cap is a soft hat with a brim that shades your eyes from the sun.',
    'cl07': 'A jacket is warm clothing you wear over your shirt when it is cold.',
    'cl08': 'A uniform is the special set of clothes you wear to school or a job.',
    'cl09': 'Shorts are short pants that end above the knees for hot days.',
    'cl10': 'Gloves are clothes you wear on your hands to keep them warm or safe.',
    'cl11': 'Glasses are lenses you wear over your eyes to help you see clearly.',
    'cl12': 'A backpack is a bag you carry on your back to hold your things.',
    // Weather
    'w01': 'Sunny means the sky is clear and the sun is shining brightly.',
    'w02': 'Rainy means water is falling from the clouds as rain.',
    'w03': 'Cloudy means the sky is covered with gray clouds.',
    'w04': 'A rainbow is a colorful arc of light in the sky after the rain.',
    'w05': 'A storm is rough weather with strong wind, heavy rain, and thunder.',
    'w06': 'Windy means the air is moving fast and blowing things around.',
    'w07': 'Hot means the weather is very warm and makes you sweat.',
    'w08': 'Cold means the weather is chilly and makes you shiver.',
    'w09': 'A flood is when too much water covers land that is usually dry.',
    'w10': 'Lightning is a bright flash of electricity in the sky during a storm.',
    'w11': 'Partly cloudy means there are some clouds and some sunshine.',
    'w12': 'Night is the dark part of the day when the sun is down.',
    // Classroom
    'cr01': 'A book is pages joined together that you read to learn or enjoy.',
    'cr02': 'A pencil is a thin tool you use to write or draw, and you can erase it.',
    'cr03': 'A notebook is a book of blank pages where you write your notes.',
    'cr04': 'A crayon is a colored wax stick you use to color pictures.',
    'cr05': 'A ruler is a straight tool you use to measure and draw straight lines.',
    'cr06': 'Scissors are a tool with two blades that you use to cut paper.',
    'cr07': 'A pen is a tool with ink that you use to write.',
    'cr08': 'Paint is colored liquid you brush on to make pictures.',
    'cr09': 'An eraser is a soft tool you use to rub out pencil marks.',
    'cr10': 'A chair is a seat with a back where one person sits.',
    'cr11': 'A school is a place where children go to learn.',
    'cr12': 'A teacher is a person whose job is to help students learn.',
    'cr13': 'A table is a piece of furniture with a flat top and legs.',
    'cr14': 'Paper is a thin flat material that you write, draw, or print on.',
    'cr15': 'A ball is a round object that you throw, kick, or bounce in games.',
    'cr16': 'A door is the part of a room you open and close to go in or out.',
    'cr17': 'A window is an opening in a wall with glass that lets in light.',
    'cr18': 'A television is a screen that shows moving pictures and sound.',
    'cr19': 'A phone is a device you use to call and talk to people far away.',
    // Transportation
    't01': 'A car is a vehicle with four wheels that people drive on roads.',
    't02': 'A bus is a long vehicle that carries many people at once.',
    't03': 'A bicycle is a two-wheeled ride you move by pushing the pedals.',
    't04': 'An airplane is a vehicle with wings that flies people through the sky.',
    't05': 'A ship is a very large boat that carries people or goods across the sea.',
    't06': 'A train is a line of cars that runs on tracks and carries many people.',
    't07': 'A motorcycle is a fast two-wheeled vehicle with an engine.',
    't08': 'A helicopter is a flying machine with spinning blades on top.',
    't09': 'A taxi is a car you pay to drive you where you want to go.',
    't10': 'A boat is a vehicle that floats and carries people on water.',
    't11': 'To walk is to move on your feet, step by step.',
    't12': 'A road is a hard path that cars and people travel on.',
    // Emotions
    'e01': 'Happy is the good feeling you have when you are glad and smiling.',
    'e02': 'Sad is the down feeling you have when something makes you unhappy.',
    'e03': 'Angry is the strong feeling you have when something upsets you.',
    'e04': 'Scared is the feeling you have when something frightens you.',
    'e05': 'Surprised is the feeling you get when something unexpected happens.',
    'e06': 'Loved is the warm feeling of knowing people care about you.',
    'e07': 'Sleepy is the feeling of being tired and ready to sleep.',
    'e08': 'Sick is the feeling of being unwell in your body.',
    'e09': 'Proud is the happy feeling you get when you do something well.',
    'e10': 'Confused is the feeling of not understanding something.',
    'e11': 'Excited is the bubbly feeling of really looking forward to something.',
    'e12': 'Calm is the peaceful, relaxed feeling of being quiet inside.',
    // Days & Time
    'd01': 'Monday is the first day of the school week.',
    'd02': 'Tuesday is the day that comes after Monday.',
    'd03': 'Wednesday is the day in the middle of the week.',
    'd04': 'Thursday is the day that comes after Wednesday.',
    'd05': 'Friday is the last day of the school week.',
    'd06': 'Saturday is a weekend day when there is no school.',
    'd07': 'Sunday is a weekend day for rest and family.',
    'd08': 'Morning is the early part of the day when the sun comes up.',
    'd09': 'Afternoon is the part of the day after noon and before evening.',
    'd10': 'Evening is the part of the day when the sun goes down.',
    'd11': 'A clock is a device that shows you what time it is.',
    'd12': 'Today is this day, the one that is happening right now.',

    // ─── Actions / Verbs ──────────────────────────────────
    'ac01': 'To run is to move very fast using your legs.',
    'ac02': 'To walk is to move by putting one foot in front of the other.',
    'ac03': 'To jump is to push yourself up into the air with your legs.',
    'ac04': 'To eat is to put food in your mouth and swallow it.',
    'ac05': 'To drink is to take water or juice into your mouth.',
    'ac06': 'To sleep is to close your eyes and rest your whole body.',
    'ac07': 'To read is to look at words and understand what they say.',
    'ac08': 'To write is to make letters and words with a pen or pencil.',
    'ac09': 'To sing is to make music with your voice.',
    'ac10': 'To dance is to move your body to music.',
    'ac11': 'To clap is to hit your hands together to make a sound.',
    'ac12': 'To sit is to rest your body on a chair or the floor.',
    'ac13': 'To stand is to be up on your feet.',
    'ac14': 'To open is to move something so it is no longer closed.',
    'ac15': 'To close is to shut something so nothing can pass through.',
    'ac16': 'To wave is to move your hand to say hello or goodbye.',
    'ac17': 'To cry is to have tears fall from your eyes when you are sad.',
    'ac18': 'To laugh is to make a happy sound when something is funny.',
    'ac19': 'To swim is to move through the water with your body.',
    'ac20': 'To play is to have fun with games or toys.',
  };

  /// Generate default decks (one per category)
  static List<FlashcardDeck> get defaultDecks {
    return FlashcardCategory.values.map((cat) {
      final cards = getByCategory(cat);
      return FlashcardDeck(
        id: 'deck_${cat.name}',
        name: cat.label,
        category: cat,
        flashcardIds: cards.map((c) => c.id).toList(),
      );
    }).toList();
  }
}
