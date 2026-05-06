import '../models/enums.dart';
import '../models/models.dart';

/// Pre-loaded flashcard data for all 6 categories
/// Each category has 12-15 words with English/Filipino pairs
class SeedData {
  SeedData._();

  static List<Flashcard> get allFlashcards => [
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
