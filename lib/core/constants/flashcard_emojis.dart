/// Maps each flashcard ID to a representative emoji character.
///
/// Emojis render as high-quality full-color illustrations on all platforms
/// (Google Noto Color Emoji on Android, Apple emoji on iOS/macOS).
/// This provides per-word visual differentiation without requiring separate
/// image asset files.
class FlashcardEmojis {
  FlashcardEmojis._();

  /// Lookup emoji for a flashcard by its ID.
  /// Returns a generic 📖 if the ID is not mapped (e.g. custom cards).
  static String forId(String id) => _map[id] ?? '📖';

  static const Map<String, String> _map = {
    // ─── Animals ────────────────────────────────────
    'a01': '🐕',  // Dog
    'a02': '🐈',  // Cat
    'a03': '🐦',  // Bird
    'a04': '🐟',  // Fish
    'a05': '🦋',  // Butterfly
    'a06': '🐴',  // Horse
    'a07': '🐔',  // Chicken
    'a08': '🐷',  // Pig
    'a09': '🐄',  // Cow
    'a10': '🐸',  // Frog
    'a11': '🐘',  // Elephant
    'a12': '🐰',  // Rabbit

    // ─── Colors & Shapes ────────────────────────────
    'c01': '🔴',  // Red
    'c02': '🔵',  // Blue
    'c03': '🟡',  // Yellow
    'c04': '🟢',  // Green
    'c05': '🟠',  // Orange
    'c06': '🟣',  // Purple
    'c07': '⭕',  // Circle
    'c08': '🔲',  // Square
    'c09': '📐',  // Triangle
    'c10': '⭐',  // Star
    'c11': '❤️',  // Heart
    'c12': '⚪',  // White
    'c13': '🌸',  // Flower

    // ─── Numbers ────────────────────────────────────
    'n01': '1️⃣',  // One
    'n02': '2️⃣',  // Two
    'n03': '3️⃣',  // Three
    'n04': '4️⃣',  // Four
    'n05': '5️⃣',  // Five
    'n06': '6️⃣',  // Six
    'n07': '7️⃣',  // Seven
    'n08': '8️⃣',  // Eight
    'n09': '9️⃣',  // Nine
    'n10': '🔟',  // Ten
    'n11': '🔢',  // Twenty
    'n12': '💯',  // Hundred

    // ─── Body Parts ─────────────────────────────────
    'b01': '🧑',  // Head
    'b02': '👀',  // Eyes
    'b03': '👂',  // Ears
    'b04': '👃',  // Nose
    'b05': '👄',  // Mouth
    'b06': '🤲',  // Hands
    'b07': '🦶',  // Feet
    'b08': '🖐️',  // Fingers
    'b09': '💇',  // Hair
    'b10': '🦷',  // Teeth
    'b11': '🏋️',  // Shoulders
    'b12': '🦵',  // Knees

    // ─── Food & Drinks ──────────────────────────────
    'f01': '🍚',  // Rice
    'f02': '💧',  // Water
    'f03': '🍞',  // Bread
    'f04': '🥛',  // Milk
    'f05': '🍎',  // Apple
    'f06': '🍌',  // Banana
    'f07': '🥚',  // Egg
    'f08': '🍗',  // Chicken (food)
    'f09': '🧃',  // Juice
    'f10': '🥦',  // Vegetables
    'f11': '🍲',  // Soup
    'f12': '🍬',  // Candy
    'f13': '🍼',  // Bottle
    'f14': '☕',  // Cup
    'f15': '🥄',  // Spoon
    'f16': '🍴',  // Fork
    'f17': '🍛',  // Plate

    // ─── Family & Greetings ─────────────────────────
    'g01': '👩',  // Mother
    'g02': '👨',  // Father
    'g03': '👦',  // Brother
    'g04': '👧',  // Sister
    'g05': '👵',  // Grandmother
    'g06': '👴',  // Grandfather
    'g07': '👋',  // Hello
    'g08': '🙏',  // Thank You
    'g09': '🙇',  // Please
    'g10': '😔',  // Sorry
    'g11': '🌅',  // Good Morning
    'g12': '🤝',  // Friend

    // ─── Clothing ───────────────────────────────────────
    'cl01': '👕',  // T-shirt
    'cl02': '👖',  // Pants
    'cl03': '👗',  // Dress
    'cl04': '🧦',  // Socks
    'cl05': '👟',  // Shoes
    'cl06': '🧢',  // Cap/Hat
    'cl07': '🧥',  // Jacket
    'cl08': '👔',  // Uniform
    'cl09': '🩳',  // Shorts
    'cl10': '🧤',  // Gloves
    'cl11': '👓',  // Glasses
    'cl12': '🎒',  // Backpack

    // ─── Weather ────────────────────────────────────────
    'w01': '☀️',  // Sunny
    'w02': '🌧️',  // Rainy
    'w03': '☁️',  // Cloudy
    'w04': '🌈',  // Rainbow
    'w05': '⛈️',  // Storm
    'w06': '💨',  // Windy
    'w07': '🌡️',  // Hot
    'w08': '❄️',  // Cold
    'w09': '🌊',  // Flood
    'w10': '⚡',  // Lightning
    'w11': '🌤️',  // Partly Cloudy
    'w12': '🌙',  // Night

    // ─── Classroom ──────────────────────────────────────
    'cr01': '📚',  // Book
    'cr02': '✏️',  // Pencil
    'cr03': '📝',  // Notebook
    'cr04': '🖍️',  // Crayon
    'cr05': '📏',  // Ruler
    'cr06': '✂️',  // Scissors
    'cr07': '🖊️',  // Pen
    'cr08': '🎨',  // Paint
    'cr09': '🧹',  // Broom
    'cr10': '🪑',  // Chair
    'cr11': '🏫',  // School
    'cr12': '👩‍🏫',  // Teacher
    'cr13': '🍽️',  // Table (table setting)
    'cr14': '📄',  // Paper
    'cr15': '⚽',  // Ball
    'cr16': '🚪',  // Door
    'cr17': '🪟',  // Window
    'cr18': '📺',  // Television
    'cr19': '📱',  // Phone

    // ─── Transportation ─────────────────────────────────
    't01': '🚗',  // Car
    't02': '🚌',  // Bus
    't03': '🚲',  // Bicycle
    't04': '✈️',  // Airplane
    't05': '🚢',  // Ship
    't06': '🚂',  // Train
    't07': '🛵',  // Motorcycle
    't08': '🚁',  // Helicopter
    't09': '🚕',  // Taxi
    't10': '🛶',  // Boat
    't11': '🚶',  // Walk
    't12': '🛤️',  // Road

    // ─── Emotions ───────────────────────────────────────
    'e01': '😊',  // Happy
    'e02': '😢',  // Sad
    'e03': '😠',  // Angry
    'e04': '😨',  // Scared
    'e05': '😲',  // Surprised
    'e06': '🥰',  // Loved
    'e07': '😴',  // Sleepy
    'e08': '🤒',  // Sick
    'e09': '😎',  // Proud
    'e10': '🤔',  // Confused
    'e11': '😁',  // Excited
    'e12': '😌',  // Calm

    // ─── Days & Time ────────────────────────────────────
    'd01': '📅',  // Monday
    'd02': '📅',  // Tuesday
    'd03': '📅',  // Wednesday
    'd04': '📅',  // Thursday
    'd05': '📅',  // Friday
    'd06': '🎉',  // Saturday
    'd07': '🎉',  // Sunday
    'd08': '🌅',  // Morning
    'd09': '🌇',  // Afternoon
    'd10': '🌆',  // Evening
    'd11': '⏰',  // Clock/Time
    'd12': '📆',  // Today

    // ─── Actions / Verbs ────────────────────────────────
    'ac01': '🏃',  // Run
    'ac02': '🚶',  // Walk
    'ac03': '🤸',  // Jump
    'ac04': '🍽️',  // Eat
    'ac05': '🥤',  // Drink
    'ac06': '😴',  // Sleep
    'ac07': '📚',  // Read
    'ac08': '✍️',  // Write
    'ac09': '🎤',  // Sing
    'ac10': '💃',  // Dance
    'ac11': '👏',  // Clap
    'ac12': '🪑',  // Sit
    'ac13': '🧍',  // Stand
    'ac14': '🚪',  // Open
    'ac15': '🔒',  // Close
    'ac16': '👋',  // Wave
    'ac17': '😢',  // Cry
    'ac18': '😂',  // Laugh
    'ac19': '🏊',  // Swim
    'ac20': '🛝',  // Play
  };
}
