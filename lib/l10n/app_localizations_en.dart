// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FlashLearn PWD';

  @override
  String greeting(String name) {
    return 'Hi, $name! 👋';
  }

  @override
  String get readyToLearn => 'Ready to learn new words today?';

  @override
  String get dayStreak => 'Day Streak';

  @override
  String get words => 'Words';

  @override
  String get stars => 'Stars';

  @override
  String get vocabularyCategories => 'Vocabulary Categories';

  @override
  String get quickGames => 'Quick Games';

  @override
  String get settings => 'Settings';

  @override
  String get profile => 'Profile';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get audio => 'Audio';

  @override
  String get about => 'About';

  @override
  String get highContrastMode => 'High Contrast Mode';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get fontSize => 'Font Size';

  @override
  String get reducedMotion => 'Reduced Motion';

  @override
  String get dyslexiaMode => 'Dyslexia-friendly';

  @override
  String get textToSpeech => 'Text-to-Speech';

  @override
  String get speechSpeed => 'Speech Speed';

  @override
  String get soundEffects => 'Sound Effects';

  @override
  String get resetAllData => 'Reset All Data';

  @override
  String get cancel => 'Cancel';

  @override
  String get reset => 'Reset';

  @override
  String get language => 'Language';

  @override
  String get reminders => 'Reminders';

  @override
  String get dailyReminder => 'Daily Reminder';

  @override
  String get reminderTime => 'Reminder Time';

  @override
  String get notifications => 'Notifications';

  @override
  String get progress => 'Progress';

  @override
  String get streak => 'Streak';

  @override
  String get mastery => 'Mastery';

  @override
  String get categoryProgress => 'Category Progress';

  @override
  String get recentGames => 'Recent Games';

  @override
  String get playGamePrompt => 'Play a game to see your scores here!';

  @override
  String progressTitle(String name) {
    return '$name\'s Progress';
  }

  @override
  String get games => 'Games';

  @override
  String get learnWhileHavingFun => 'Learn new words while having fun!';

  @override
  String get chooseDifficulty => 'Choose Difficulty';

  @override
  String get chooseCategories => 'Choose Categories';

  @override
  String get allCategories => 'All Categories';

  @override
  String get easy => 'Easy';

  @override
  String get medium => 'Medium';

  @override
  String get hard => 'Hard';

  @override
  String get startGame => 'Start Game';

  @override
  String get correct => 'Correct!';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get gameComplete => 'Game Complete!';

  @override
  String get playAgain => 'Play Again';

  @override
  String get exit => 'Exit';

  @override
  String get reviewAnswers => 'Review Answers';

  @override
  String get score => 'Score';

  @override
  String get hint => 'Hint';

  @override
  String hintsLeft(int count) {
    return 'Hint ($count left)';
  }

  @override
  String get fillInTheBlank => 'Fill in the blank';

  @override
  String get spellTheWord => 'Spell the English word';

  @override
  String get matchPictureToWord => 'Match the picture to the correct word!';

  @override
  String get sentenceBuilder => 'Sentence Builder';

  @override
  String get fillMissingWord => 'Fill in the missing word in the sentence!';

  @override
  String get starShop => 'Star Shop';

  @override
  String get avatars => 'Avatars';

  @override
  String get themes => 'Themes';

  @override
  String get borders => 'Borders';

  @override
  String get titles => 'Titles';

  @override
  String get sounds => 'Sounds';

  @override
  String get effects => 'Effects';

  @override
  String get themeOverriddenByContrast =>
      'High Contrast is on, so this theme won\'t change your colours until you turn it off.';

  @override
  String get themeOverriddenByDyslexia =>
      'Dyslexia-friendly mode is on, so this theme won\'t change your colours until you turn it off.';

  @override
  String get effectPlaysGently =>
      'Reduced Motion is on, so this effect will play gently.';

  @override
  String get soundPackNeedsSound =>
      'Sound Effects are off, so this pack won\'t be heard until you turn them on.';

  @override
  String get recommendedForYou => 'Recommended for you';

  @override
  String get seeIt => 'See it';

  @override
  String get hearIt => 'Hear it';

  @override
  String previewOf(String name) {
    return 'Preview of $name';
  }

  @override
  String starsToGo(int count) {
    return '$count more stars to go';
  }

  @override
  String get keepEarning => 'Keep earning';

  @override
  String get goodToKnow => 'Good to know';

  @override
  String itemNotReady(String name) {
    return '$name is not ready yet.';
  }

  @override
  String starsRefunded(int count) {
    return '⭐ $count stars are back — something you bought isn\'t ready yet, so we returned it.';
  }

  @override
  String get owned => 'Owned';

  @override
  String get buy => 'Buy!';

  @override
  String buyItem(String name) {
    return 'Buy $name?';
  }

  @override
  String notEnoughStars(int count) {
    return 'Not enough stars! You need $count more ⭐';
  }

  @override
  String get alreadyOwned => 'You already own this item!';

  @override
  String purchaseSuccess(String name) {
    return '🎉 You got $name!';
  }

  @override
  String get studyTime => 'Study Time';

  @override
  String get totalTime => 'Total Time';

  @override
  String get avgSession => 'Avg Session';

  @override
  String get sessions => 'Sessions';

  @override
  String get last7Days => 'Last 7 Days';

  @override
  String get dashboard => 'Dashboard';

  @override
  String teacherDashboard(String role) {
    return '$role Dashboard';
  }

  @override
  String get overallMastery => 'Overall Mastery';

  @override
  String get categoryBreakdown => 'Category Breakdown';

  @override
  String get insightsRecommendations => 'Insights & Recommendations';

  @override
  String get needsPractice => 'Needs Practice';

  @override
  String get doingGreat => 'Doing Great';

  @override
  String get engagement => 'Engagement';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get noActivityYet =>
      'No game activity yet. Encourage the student to play games!';

  @override
  String get exportPdfReport => 'Export PDF Report';

  @override
  String get confirmResetTitle => 'Reset All Data?';

  @override
  String get confirmResetMessage =>
      'This will delete all profiles, progress, and settings. This cannot be undone.';

  @override
  String get dailyWordChallenge => 'Daily Word Challenge';

  @override
  String get smartReview => 'Smart Review';

  @override
  String get viewAllStudents => 'View all students';

  @override
  String get openDashboard => 'Open progress dashboard';

  @override
  String get openSettings => 'Open settings';

  @override
  String get openShop => 'Open star shop';

  @override
  String get version => 'Version 1.1.0 • Thesis Capstone Project';

  @override
  String get flashLearnPwd => 'FlashLearn PWD';

  @override
  String get animals => 'Animals';

  @override
  String get colorsAndShapes => 'Colors & Shapes';

  @override
  String get numbers => 'Numbers';

  @override
  String get bodyParts => 'Body Parts';

  @override
  String get foodAndDrinks => 'Food & Drinks';

  @override
  String get familyAndGreetings => 'Family & Greetings';

  @override
  String get wordMatch => 'Word Match';

  @override
  String get spellingBee => 'Spelling Bee';

  @override
  String get memoryMatch => 'Memory Match';

  @override
  String get dragAndDrop => 'Drag & Drop';

  @override
  String get flashcardQuiz => 'Flashcard Quiz';

  @override
  String get pronunciationPractice => 'Pronunciation Practice';

  @override
  String get pickVocabulary => 'Pick which vocabulary to practice';

  @override
  String get badges => 'Badges';

  @override
  String get keepItUp =>
      'Keep it up! Consider trying harder difficulty levels.';

  @override
  String focusOn(String category) {
    return 'Focus on $category flashcards and games.';
  }

  @override
  String streakActive(int count) {
    return '$count-day learning streak active!';
  }

  @override
  String get noStreakMessage => 'No active streak. Try daily practice.';

  @override
  String get greatConsistency =>
      'Great consistency! The student is building a habit.';

  @override
  String get encourageDaily =>
      'Encourage the student to play at least once a day.';

  @override
  String get stories => 'Stories 📖';

  @override
  String get readStoriesAndAnswer => 'Read fun stories and answer questions!';

  @override
  String get storyQuiz => 'Story Quiz';

  @override
  String get takeQuiz => 'Take Quiz';

  @override
  String get nextQuestion => 'Next Question';

  @override
  String get seeResults => 'See Results';

  @override
  String storySentences(int count) {
    return '$count sentences';
  }

  @override
  String storyQuestions(int count) {
    return '$count questions';
  }

  @override
  String get locked => 'Locked';

  @override
  String get tapToRead => 'Tap to read';

  @override
  String get switchToFilipino => 'Switch to Filipino';

  @override
  String get switchToEnglish => 'Switch to English';

  @override
  String get readAloud => 'Read aloud';

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get saveOrRestoreData => 'Save or restore all app data';

  @override
  String get classroomMode => 'Classroom Mode';

  @override
  String get monitorStudents => 'Monitor all students in real time';

  @override
  String get classroomView => 'Classroom View';

  @override
  String get refresh => 'Refresh';

  @override
  String get active => 'Active';

  @override
  String get idle => 'Idle';

  @override
  String get students => 'Students';

  @override
  String get noStudentProfiles => 'No student profiles found';

  @override
  String get accuracy => 'Accuracy';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get voiceNavigation => 'Voice-Guided Navigation';

  @override
  String get voiceNavigationDesc => 'Announce screens aloud';

  @override
  String get adaptiveDifficulty => 'Adaptive Difficulty';

  @override
  String get adaptiveDifficultyDesc => 'Auto-suggest game difficulty';

  @override
  String get welcome => 'Welcome! 👋';

  @override
  String get whoAreYou => 'Who are you?';

  @override
  String get whatsYourName => 'What\'s your name?';

  @override
  String get enterYourName => 'Enter your name...';

  @override
  String get chooseYourAvatar => 'Choose your avatar';

  @override
  String get letsGo => 'Let\'s Go!';

  @override
  String get iWantToLearn => 'I want to learn new words!';

  @override
  String get iWantToHelp => 'I want to help students learn';

  @override
  String get iWantToSupport => 'I want to support my child';

  @override
  String get welcomeBack => 'Welcome Back! 👋';

  @override
  String get chooseYourProfile => 'Choose your profile';

  @override
  String get addNewProfile => 'Add New Profile';

  @override
  String enterPin(String name) {
    return 'Enter PIN for $name';
  }

  @override
  String get wrongPin => 'Wrong PIN. Try again.';

  @override
  String get setPin => 'Set PIN';

  @override
  String get changePin => 'Change PIN';

  @override
  String get removePin => 'Remove PIN';

  @override
  String get pinRemoved => 'PIN removed';

  @override
  String get pinSetSuccess => 'PIN set successfully!';

  @override
  String get pinMustBe4Digits => 'PIN must be exactly 4 digits';

  @override
  String get pinsDoNotMatch => 'PINs do not match';

  @override
  String get enterPinLabel => 'Enter PIN';

  @override
  String get confirmPinLabel => 'Confirm PIN';

  @override
  String get choosePin => 'Choose a 4-digit PIN to protect your profile.';

  @override
  String get accessibilitySetup => 'Accessibility Setup';

  @override
  String get weWillOptimize =>
      'We\'ll optimize the app for your needs.\nSelect the option that best describes you:';

  @override
  String get continueButton => 'Continue';

  @override
  String get recommendedSettings => 'Recommended Settings';

  @override
  String get noSpecialSettings =>
      'No special settings needed!\nYou\'re all set with the defaults.';

  @override
  String weWillApplySettings(String type) {
    return 'We\'ll apply these settings for $type:';
  }

  @override
  String get changeInSettings => 'You can change these anytime in Settings ⚙️';

  @override
  String get applyAndContinue => 'Apply & Continue';

  @override
  String get youreAllSet => 'You\'re All Set! 🎉';

  @override
  String welcomeName(String name) {
    return 'Welcome, $name!';
  }

  @override
  String appOptimizedFor(String type) {
    return 'Your app has been optimized for\n$type';
  }

  @override
  String get standardSettings => 'Standard settings are ready to go.';

  @override
  String get adjustAnytime =>
      'You can adjust all settings anytime\nfrom the Settings page.';

  @override
  String get letsStartLearning => 'Let\'s Start Learning!';

  @override
  String get skip => 'Skip';

  @override
  String get flashcardDecks => 'Flashcard Decks';

  @override
  String get chooseCategory => 'Choose a category to start learning!';

  @override
  String get importLabel => 'Import';

  @override
  String get exportLabel => 'Export';

  @override
  String importedCards(int count) {
    return 'Imported $count flashcard(s)!';
  }

  @override
  String get noDuplicates =>
      'No new cards to import (all duplicates or cancelled).';

  @override
  String get importFailed => 'Import failed — check the file format.';

  @override
  String get createCard => 'Create Card';

  @override
  String cards(int count) {
    return '$count cards';
  }

  @override
  String get deleteFlashcard => 'Delete Flashcard?';

  @override
  String deleteConfirm(String name) {
    return 'Are you sure you want to delete “$name”? This cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get flashcardDeleted => 'Flashcard deleted';

  @override
  String get customCard => 'Custom Card';

  @override
  String get edit => 'Edit';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get english => 'English';

  @override
  String get filipino => 'Filipino';

  @override
  String get fsl => 'FSL';

  @override
  String get flip => 'Flip';

  @override
  String get filipinoSignLanguage => 'Filipino Sign Language';

  @override
  String noFslVideo(String word) {
    return 'No FSL video available yet for “$word”.';
  }

  @override
  String get gotIt => 'Got it!';

  @override
  String get tapToSeeMore => 'Tap to see more ✨';

  @override
  String get details => 'DETAILS';

  @override
  String get example => 'Example';

  @override
  String get tapToFlipBack => 'Tap to flip back';

  @override
  String get speed => 'Speed:';

  @override
  String get replay => 'Replay';

  @override
  String get close => 'Close';

  @override
  String get unableToLoadVideo => 'Unable to load video';

  @override
  String get fslDictionary => 'FSL Dictionary 🤟';

  @override
  String get searchWords => 'Search words...';

  @override
  String get all => 'All';

  @override
  String wordsCount(int count) {
    return '$count words';
  }

  @override
  String videosWatched(int count) {
    return '$count videos watched';
  }

  @override
  String get noWordsFound => 'No words found';

  @override
  String get noWordsToReview => 'No words to review!';

  @override
  String get playGamesFirst =>
      'Play some games first to build up your word data.';

  @override
  String get showAnswer => 'Show Answer';

  @override
  String get stillLearning => 'Still Learning';

  @override
  String get iKnowIt => 'I Know It!';

  @override
  String get reviewComplete => 'Review Complete!';

  @override
  String get greatRecall => 'Great recall! Keep it up!';

  @override
  String get keepPracticing => 'Keep practicing — you\'ll get there!';

  @override
  String get total => 'Total';

  @override
  String get reviewAgain => 'Review Again';

  @override
  String get done => 'Done';

  @override
  String get dragInstruction => 'Drag the English word to its Filipino match!';

  @override
  String get tracing => 'Tracing';

  @override
  String traceWord(String word) {
    return 'Trace: $word';
  }

  @override
  String get clear => 'Clear';

  @override
  String get check => 'Check';

  @override
  String get whatIsThisWord => 'What is this word?';

  @override
  String moves(int count) {
    return '$count moves';
  }

  @override
  String matched(int current, int total) {
    return 'Matched: $current / $total';
  }

  @override
  String get stillLearningSwipe => '← Still\nLearning';

  @override
  String get iKnowThisSwipe => 'I Know\nThis! →';

  @override
  String get learning => 'Learning';

  @override
  String get iKnow => 'I Know!';

  @override
  String get amazing => '🎉 Amazing!';

  @override
  String get keepGoing => '💪 Keep Going!';

  @override
  String percentMastered(int percent) {
    return '$percent% mastered';
  }

  @override
  String get reviewWords => 'Review Words';

  @override
  String get again => 'Again';

  @override
  String get listenAndPick => 'Listen & Pick';

  @override
  String get listenEnglish => 'Listen to the English word';

  @override
  String get listenFilipino => 'Listen to the Filipino word';

  @override
  String get pickFilipino => 'Pick the Filipino match!';

  @override
  String get pickEnglish => 'Pick the English match!';

  @override
  String get tapSpeakerReplay => '🔊 Tap speaker to replay';

  @override
  String get noWordsAvailable => 'No words available for this category.';

  @override
  String get storyNotFound => 'Story Not Found';

  @override
  String get storyNotFoundMsg => 'Story not found.';

  @override
  String get goBack => 'Go Back';

  @override
  String get back => 'Back';

  @override
  String get quizNotFound => 'Quiz Not Found';

  @override
  String questionOf(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get equipped => 'Equipped';

  @override
  String get tapToEquip => 'Tap to Equip';

  @override
  String starsAmount(int count) {
    return '$count stars';
  }

  @override
  String get viewLeaderboard => 'View Leaderboard';

  @override
  String get detailedAnalytics => 'Detailed Analytics';

  @override
  String get starCollection => 'Star Collection';

  @override
  String get achievements => 'Achievements';

  @override
  String get days => 'days';

  @override
  String get leaderboard => 'Leaderboard 🏆';

  @override
  String get noEntriesYet =>
      'No entries yet.\nPlay games and learn words to rank up!';

  @override
  String activeTotal(int active, int total) {
    return '$active active / $total total';
  }

  @override
  String get createStudentMsg =>
      'Students appear here after joining your class with a code.\nShare the class code from Manage Classes to invite them.';

  @override
  String get switchProfile => 'Switch';

  @override
  String get clothing => 'Clothing';

  @override
  String get weather => 'Weather';

  @override
  String get classroom => 'Classroom';

  @override
  String get transportation => 'Transportation';

  @override
  String get emotions => 'Emotions';

  @override
  String get daysAndTime => 'Days & Time';

  @override
  String get speechToText => 'Speech-to-Text';

  @override
  String get fslPractice => 'FSL Practice';

  @override
  String get fslPracticeSubtitle => 'Learn Filipino Sign Language!';

  @override
  String get signToWord => 'Sign → Word';

  @override
  String get wordToSign => 'Word → Sign';

  @override
  String get signToWordDesc =>
      'Watch a sign language video, then pick the correct word.';

  @override
  String get wordToSignDesc =>
      'See a word, then pick which video shows the correct sign.';

  @override
  String get whatSignIsThis => 'What word is this sign?';

  @override
  String get whichSignMeans => 'Which sign means…';

  @override
  String get notEnoughFslVideos =>
      'Not enough FSL videos available for the selected categories.';

  @override
  String get fslPracticeTitle => 'Filipino Sign Language Practice';

  @override
  String get fslPracticeDesc =>
      'Watch sign language videos and test your knowledge.\nChoose a practice mode below!';

  @override
  String get parentDashboard => 'Parent Dashboard';

  @override
  String get familyOverview => 'Family Overview';

  @override
  String get yourChildren => 'Your Children';

  @override
  String get thisWeek => 'This Week';

  @override
  String get recommendations => 'Recommendations';

  @override
  String get wordsLearned => 'Words Learned';

  @override
  String get activeToday => 'Active today';

  @override
  String get lastActive => 'Last active';

  @override
  String get strengthsAndAreas => 'Strengths & Areas to Improve';

  @override
  String get createProfile => 'Create Profile';

  @override
  String encouragePractice(Object name) {
    return 'Encourage $name to practice';
  }

  @override
  String get keepUpGreatWork => 'Keep up the great work!';

  @override
  String get learnWordsThrough => 'Learn words through play! ✨';

  @override
  String get gettingReady => 'Getting ready...';

  @override
  String get fslFullscreen => 'Fullscreen';

  @override
  String get exitFullscreen => 'Exit Fullscreen';

  @override
  String get rotateForLandscape => 'Rotate or double-tap for landscape';

  @override
  String get hideCaptions => 'Hide captions';

  @override
  String get showCaptions => 'Show captions';

  @override
  String get playbackSpeedSettings => 'Playback speed settings';

  @override
  String get closeFullscreenVideo => 'Close fullscreen video';

  @override
  String get replayFromBeginning => 'Replay from beginning';

  @override
  String get switchToPortrait => 'Switch to portrait';

  @override
  String get switchToLandscape => 'Switch to landscape';

  @override
  String get videoProgress => 'Video progress';

  @override
  String get pauseVideo => 'Pause video';

  @override
  String get playVideo => 'Play video';

  @override
  String setSpeedTo(String speed) {
    return 'Set speed to ${speed}x';
  }

  @override
  String pinLockedTryAgainIn(String duration) {
    return 'Too many tries. Try again in $duration.';
  }

  @override
  String get forgotPin => 'Forgot PIN?';

  @override
  String get recoveryCodeTitle => 'Save your recovery code';

  @override
  String get recoveryCodeSubtitle =>
      'Write this down. You\'ll need it if you forget your PIN. We can\'t show it again.';

  @override
  String get recoveryCodeConfirm => 'I\'ve saved it';

  @override
  String get enterRecoveryCode => 'Enter your recovery code';

  @override
  String get recoveryCodeWrong => 'That code didn\'t match.';

  @override
  String get recoveryViaEducatorTitle => 'Ask a teacher or parent';

  @override
  String recoveryViaEducatorPrompt(String name) {
    return 'Have a teacher or parent enter their PIN to reset $name\'s PIN.';
  }

  @override
  String get recoveryNoEducator =>
      'No teacher or parent profile is set up on this device. Ask an adult to add one, or remove the profile to start over.';

  @override
  String get pinResetSuccess => 'PIN reset. Set a new one.';

  @override
  String get pinChangedSuccess => 'PIN updated.';

  @override
  String get setNewPin => 'Set a new PIN';

  @override
  String get regenerateRecoveryCode => 'Regenerate recovery code';

  @override
  String get showRecoveryCode => 'Show recovery code';

  @override
  String get setUpProfileTitle => 'Set Up Profile';

  @override
  String get letsSetUpProfile => 'Let\'s set up your profile';

  @override
  String get nameLabel => 'Name';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get nameMinLength => 'Name must be at least 2 characters';

  @override
  String get ageOrBirthDate => 'Age / Birth Date';

  @override
  String get tapToSelectBirthDate => 'Tap to select birth date';

  @override
  String get selectBirthDate => 'Select birth date';

  @override
  String get pleaseSelectBirthDate => 'Please select a birth date';

  @override
  String yearsOld(int count) {
    return '$count yrs old';
  }

  @override
  String suggestedLevel(String level) {
    return '✨ Suggested level: $level';
  }

  @override
  String get pinProtection => 'PIN Protection';

  @override
  String get pinProtectionDescription =>
      'Add a 4-digit PIN to protect this profile';

  @override
  String get enablePinLock => 'Enable PIN lock';

  @override
  String get enterFourDigitPin => 'Enter 4-digit PIN';

  @override
  String get pinDigitsOnly => 'PIN must contain only digits';

  @override
  String get iHaveRecoveryCode => 'I have a recovery code';

  @override
  String get saving => 'Saving…';

  @override
  String get rolePlayer => 'Player';

  @override
  String get rolePlayerGuest => 'Guest Player';

  @override
  String get rolePlayerProgress => 'Player (with Progress)';

  @override
  String get roleStudent => 'Student Profile (PWD)';

  @override
  String get roleChild => 'Child Profile (PWD)';

  @override
  String get roleTeacher => 'Teacher Profile';

  @override
  String get roleParent => 'Parent/Guardian Profile';

  @override
  String get groupPlayerProfiles => 'Player Profiles';

  @override
  String get groupPlayerProfilesDesc =>
      'For gameplay and PWD awareness learning.';

  @override
  String get groupClassroom => 'Classroom';

  @override
  String get groupClassroomDesc => 'Teacher-managed learning environment.';

  @override
  String get groupFamily => 'Family Group';

  @override
  String get groupFamilyDesc => 'Parent/Guardian-managed learning environment.';

  @override
  String get rolePlayerTagline => 'Just play — no progress saved';

  @override
  String get rolePlayerGuestTagline =>
      'Jump in and play — stays on this device, not backed up';

  @override
  String get rolePlayerProgressTagline =>
      'Save your XP, streaks & badges and back them up';

  @override
  String get roleStudentTagline => 'Join with a class code';

  @override
  String get roleChildTagline => 'Join with a home-group code';

  @override
  String get roleTeacherTagline => 'I want to help';

  @override
  String get roleParentTagline => 'I want to support';

  @override
  String get roleSetupPlayer =>
      'Guest mode — progress is saved on this device only.';

  @override
  String get roleSetupPlayerGuest =>
      'Guest mode — play freely. Progress stays on this device and isn\'t backed up.';

  @override
  String get roleSetupPlayerProgress =>
      'Your XP, streaks and badges are kept. Add a PIN to back up and restore on another device.';

  @override
  String get roleSetupTeacher => 'Set up your profile to manage learners.';

  @override
  String get roleSetupParent => 'Set up your profile to support your child.';

  @override
  String get pwdAwarenessEntry => 'Learn about PWD awareness';

  @override
  String get pwdAwarenessTitle => 'PWD Awareness';

  @override
  String get pwdAwarenessSubtitle =>
      'Understanding & respecting Persons with Disabilities';

  @override
  String youJoined(String name) {
    return 'You joined $name.';
  }

  @override
  String get getStarted => 'Get Started';

  @override
  String get welcomeSlide1Title => 'Learn Filipino Sign Language';

  @override
  String get welcomeSlide1Body =>
      'Fun flashcards, games, and FSL videos to build vocabulary every day.';

  @override
  String get welcomeSlide2Title => 'Made for every learner';

  @override
  String get welcomeSlide2Body =>
      'Students, children, teachers, and parents — each gets a setup that fits.';

  @override
  String get welcomeSlide3Title => 'Accessible by design';

  @override
  String get welcomeSlide3Body =>
      'High-contrast, dyslexia-friendly, text-to-speech, and reduced-motion options are built in.';

  @override
  String get splashLoadingResources => 'Loading resources...';

  @override
  String get splashPreparingCards => 'Preparing your cards...';

  @override
  String get splashAlmostReady => 'Almost ready!';

  @override
  String get wordHuntTitle => 'Word Hunt';

  @override
  String get wordHuntPointCamera => 'Point your camera at an object!';

  @override
  String get wordHuntTakePhoto => 'Take a photo!';

  @override
  String get wordHuntFlipCamera => 'Flip camera';

  @override
  String get wordHuntLooking => 'Looking at your photo…';

  @override
  String get wordHuntFoundWords => 'I found these words — tap one!';

  @override
  String get wordHuntNoneFound =>
      'I couldn\'t find a word in this photo. Get closer and try again!';

  @override
  String get wordHuntRetake => 'New photo';

  @override
  String get wordHuntNoCamera =>
      'This device has no camera, so Word Hunt can\'t run here.';

  @override
  String get wordHuntCameraDenied =>
      'Word Hunt needs the camera to find objects around you. Please allow camera access.';

  @override
  String get wordHuntCameraError =>
      'The camera couldn\'t start. Please try again.';

  @override
  String get wordHuntNewWord => 'New word found! +1 ⭐';

  @override
  String get wordHuntGreatFind => 'New word found! Great job!';

  @override
  String get wordHuntSpeakEnglish => 'English';

  @override
  String get wordHuntSpeakFilipino => 'Filipino';

  @override
  String get wordHuntFlashcards => 'Flashcards';

  @override
  String get wordHuntMeaning => 'Meaning';

  @override
  String get wordHuntMyFinds => 'My Finds';

  @override
  String get wordHuntCollectionTitle => '🎒 My Finds';

  @override
  String wordHuntFoundOf(int found, int total) {
    return '$found of $total words found';
  }

  @override
  String wordHuntStarsToday(int earned, int cap) {
    return '$earned of $cap camera stars today';
  }

  @override
  String get wordHuntCollectionEmpty =>
      'You haven\'t found any words yet. Point the camera at something around you!';

  @override
  String get wordHuntStartHunting => 'Start hunting';

  @override
  String get wordHuntStillToFind => 'Still to find';

  @override
  String get wordHuntFound => 'Found';

  @override
  String get wordHuntTargets => 'Try to find:';

  @override
  String get wordHuntNewBadge => 'NEW';

  @override
  String get wordHuntAllFound =>
      'You found every word the camera knows. Amazing! 🏆';

  @override
  String wordHuntSpokenFound(int count, String words) {
    return 'I found $count words: $words';
  }

  @override
  String get wordHuntSayTakePhoto => 'Say “take a photo”';

  @override
  String wordHuntFoundTarget(String words) {
    return 'Found it! $words was on your list.';
  }

  @override
  String wordHuntFoundTargets(String words) {
    return 'Found them! $words were on your list.';
  }

  @override
  String wordHuntStreakDays(int days) {
    return '$days-day hunt streak';
  }

  @override
  String wordHuntFindsToday(int count) {
    return '$count found today';
  }

  @override
  String wordHuntNextBadge(int remaining, String badge) {
    return '$remaining more to unlock $badge';
  }

  @override
  String get wordHuntCameraBusyReason =>
      'This activity points the camera at the world around you, so it needs the camera to itself. Head control will pause while it is open.';

  @override
  String get customizeProgress => 'Customize progress';

  @override
  String get customize => 'Customize';

  @override
  String get signs => 'Signs';

  @override
  String bestStreak(int days) {
    return 'best $days';
  }

  @override
  String starsLeftToSpend(int count) {
    return '$count left';
  }

  @override
  String get streakCalendar => 'Streak Calendar';

  @override
  String get certificates => 'Certificates';

  @override
  String get advancedAnalytics => 'Learning Insights';

  @override
  String get firstBadgePrompt => 'Keep learning to unlock your first badge!';

  @override
  String badgesEarned(int earned, int total) {
    return '$earned of $total earned';
  }

  @override
  String get reading => 'Reading';

  @override
  String get storiesRead => 'Stories read';

  @override
  String get perfectQuizzes => '3-star quizzes';

  @override
  String get signLanguage => 'Sign Language';

  @override
  String get signsWatched => 'Watched';

  @override
  String get signsCanMake => 'I can sign';

  @override
  String get signsConfirmed => 'Teacher confirmed';

  @override
  String get daysActive => 'Days active';

  @override
  String get minutesStudied => 'Minutes';

  @override
  String get newWords => 'New words';

  @override
  String get weeklyEmpty =>
      'Nothing yet this week — play a game or read a story and it will show up here.';

  @override
  String get hearMyProgress => 'Hear my progress';

  @override
  String get studyMinutes => 'Study Min';

  @override
  String spokenProgressSummary(
    int level,
    String title,
    int words,
    int stars,
    int streak,
    int best,
    int games,
  ) {
    return 'You are level $level, $title. You have learned $words words and earned $stars stars. Your streak is $streak days, and your best ever is $best days. You have played $games games.';
  }

  @override
  String spokenWeekSummary(int days, int games, int stars) {
    return 'This week you were active on $days days, played $games games and earned $stars stars.';
  }

  @override
  String get chartLess => 'Less';

  @override
  String get chartMore => 'More';

  @override
  String get chartDifficultyHistory => 'Difficulty Adaptation History';

  @override
  String get chartReviewHeatmap => 'Review Activity Heatmap';

  @override
  String get chartStarsEarnedVsSpent => 'Earned vs spent';

  @override
  String get chartStarsAvailable => 'Available';

  @override
  String get chartStarsSpent => 'Spent';

  @override
  String get catShortAnimals => 'Animals';

  @override
  String get catShortColors => 'Colors';

  @override
  String get catShortNumbers => 'Numbers';

  @override
  String get catShortBody => 'Body';

  @override
  String get catShortFood => 'Food';

  @override
  String get catShortFamily => 'Family';

  @override
  String get catShortClothing => 'Cloth';

  @override
  String get catShortWeather => 'Weather';

  @override
  String get catShortClassroom => 'Class';

  @override
  String get catShortTransport => 'Travel';

  @override
  String get catShortEmotions => 'Feels';

  @override
  String get catShortDays => 'Days';

  @override
  String get catShortActions => 'Action';

  @override
  String get gameShortMatch => 'Match';

  @override
  String get gameShortSpell => 'Spell';

  @override
  String get gameShortQuiz => 'Quiz';

  @override
  String get gameShortMemory => 'Memory';

  @override
  String get gameShortDrag => 'Drag';

  @override
  String get gameShortPronun => 'Pronun';

  @override
  String get gameShortSentence => 'Sent';

  @override
  String get gameShortStory => 'Story';

  @override
  String get gameShortTrace => 'Trace';

  @override
  String get gameShortFsl => 'FSL';

  @override
  String get gameShortJigsaw => 'Jigsaw';

  @override
  String get gameShortPicWord => 'PicWord';

  @override
  String get gameShortYesNo => 'Yes/No';

  @override
  String get gameShortOdd => 'Odd';

  @override
  String get gameShortLetter => 'Letter';

  @override
  String get chartActivityMapTitle => 'Activity Map 📅';

  @override
  String get chartActivityMapSubtitle => 'Daily study activity — last 8 weeks';

  @override
  String get chartCategoryMasteryTitle => 'Category Mastery 🎯';

  @override
  String get chartDifficultyHigh => 'High (≥80%)';

  @override
  String get chartDifficultyMedium => 'Medium (50-80%)';

  @override
  String get chartDifficultyLow => 'Low (<50%)';

  @override
  String get chartNoGameScores => 'No game scores yet. Play some games! 🎮';

  @override
  String get chartGamePerformanceTitle => 'Game Performance 🎮';

  @override
  String get chartGamePerformanceSubtitle => 'Average score (%) per game type';

  @override
  String get chartWordsLearnedTitle => 'Words Learned 📈';

  @override
  String get chartWordsLearnedSubtitle =>
      'Cumulative word progress — last 30 days';

  @override
  String get chartStarsOverviewTitle => 'Stars Overview ⭐';

  @override
  String get chartNoStars => 'No stars earned yet. Keep learning! ✨';

  @override
  String get chartStudyTimeTitle => 'Study Time ⏱️';

  @override
  String get chartStudyTimeSubtitle => 'Minutes studied per day (last 7 days)';

  @override
  String get chartMinutesShort => 'min';

  @override
  String get chartCategoryMasterySubtitle =>
      'Your progress across all vocabulary categories';

  @override
  String get chartDifficultySubtitle =>
      'How your accuracy changes across games over time';

  @override
  String get chartDifficultyEmpty =>
      'Play some games to see your\ndifficulty adaptation history!';

  @override
  String get gameTipDifficulty =>
      '💡 Tip: Try different difficulty levels to challenge yourself!';

  @override
  String get gameTipDaily => '🔥 Playing games daily builds stronger memory!';

  @override
  String get gameTipReview => '🌟 Review words you missed to learn faster!';

  @override
  String get gameTipStartEasy =>
      '🎯 Start with Easy mode, then level up when ready!';

  @override
  String get gameTipVariety =>
      '🧩 Each game teaches in a different way — try them all!';

  @override
  String get gameTipTimed => '⏱️ Timed mode is great for building speed!';

  @override
  String get playTogether => 'Play Together';

  @override
  String get playTogetherSubtitle => 'Race a friend — just for fun!';

  @override
  String get playTogetherSemantics =>
      'Play Together. Race a friend online or on this device, just for fun.';

  @override
  String gamesPickedForYou(int count) {
    return '$count games picked for you';
  }

  @override
  String get badgeNew => 'NEW';

  @override
  String get notPlayedYet => 'Not played yet.';

  @override
  String yourBestStars(int best) {
    return 'Your best: $best of 3 stars.';
  }

  @override
  String playGameSemantics(String game, String description) {
    return 'Play $game. $description';
  }

  @override
  String get chooseYourDifficulty => 'Choose your difficulty';

  @override
  String get beatTheClock => 'Beat the Clock ⏱️';

  @override
  String get beatTheClockSubtitle => '60 seconds to finish!';

  @override
  String get lastPlayed => 'Last played';

  @override
  String get startWithAllCategories => 'Start with All Categories';

  @override
  String get startWithOneCategory => 'Start with 1 Category';

  @override
  String startWithCategories(int count) {
    return 'Start with $count Categories';
  }

  @override
  String get comingSoon => 'Coming soon';

  @override
  String gameReviewTitle(String game) {
    return '$game Review';
  }

  @override
  String reviewCorrectCount(int count) {
    return '$count correct';
  }

  @override
  String reviewWrongCount(int count) {
    return '$count wrong';
  }

  @override
  String get yourAnswerLabel => 'Your answer: ';

  @override
  String get paused => 'Paused';

  @override
  String get resumeGame => 'Resume';

  @override
  String get iNeedABreak => 'I Need a Break';

  @override
  String get restartGame => 'Restart';

  @override
  String get restartGameTitle => 'Restart this game?';

  @override
  String get restartGameBody =>
      'Your current progress in this round will be lost.';

  @override
  String get quitToGames => 'Quit to Games';

  @override
  String get pauseLabel => 'Pause';

  @override
  String get resultAmazing => 'Amazing! 🌟';

  @override
  String get resultAmazingHint =>
      'You\'re a superstar! Try a harder level next!';

  @override
  String get resultAmazingHintNoLevels =>
      'You\'re a superstar! You read every question right!';

  @override
  String get resultGreat => 'Great Job! 🎉';

  @override
  String get resultGreatHint => 'You\'re doing wonderfully! Keep it up!';

  @override
  String get resultGood => 'Good Try! 👍';

  @override
  String get resultGoodHint => 'You\'re learning! Review the words you missed.';

  @override
  String get resultKeepPracticing => 'Keep Practicing! 💪';

  @override
  String get resultKeepPracticingHint =>
      'Every try makes you stronger! Try again!';

  @override
  String get fslPracticeHeading => 'Filipino Sign Language Practice';

  @override
  String get fslSignToWord => 'Sign → Word';

  @override
  String get fslSignToWordSubtitle =>
      'Watch a sign language video, then pick the correct word from choices.';

  @override
  String get fslWordToSign => 'Word → Sign';

  @override
  String get fslWordToSignSubtitle =>
      'See a word, then pick which video shows the correct sign.';

  @override
  String get fslSignIt => 'Sign It!';

  @override
  String get fslSignItSubtitle =>
      'Watch a sign, copy it in the camera, then check yourself.';

  @override
  String get fslSignItSubtitleGaze =>
      'Watch a sign, copy it in the camera, then check yourself. Uses your hands — head control pauses here.';

  @override
  String get fslVideosComingSoon =>
      'FSL videos are still being added. Try the FSL Dictionary in the meantime.';

  @override
  String get resumeBadge => 'PAUSED';

  @override
  String get resumeTitle => 'Continue where you left off?';

  @override
  String resumeBody(int round, int total) {
    return 'You stopped at round $round of $total.';
  }

  @override
  String get resumeContinue => 'Continue';

  @override
  String get resumeStartOver => 'Start Over';

  @override
  String resumeRoundProgress(int round, int total) {
    return 'Round $round of $total';
  }

  @override
  String get notEnoughWords => 'Not enough words';

  @override
  String notEnoughWordsBody(String game) {
    return 'Pick more categories to play $game.';
  }

  @override
  String get backToGames => 'Back to Games';

  @override
  String get fslPracticeIntro =>
      'Watch sign language videos and test your knowledge.\nChoose a practice mode below!';

  @override
  String starsEarnedChip(int count) {
    return '+$count ⭐ earned';
  }

  @override
  String gameResultsSemantics(int score, int total, int rating, int stars) {
    return 'Game results: $score out of $total, rating $rating out of 3 stars, $stars stars earned';
  }

  @override
  String get jigsawPuzzle => 'Jigsaw Puzzle';

  @override
  String get pictureWord => 'Picture-Word';

  @override
  String get yesOrNo => 'Yes or No';

  @override
  String get oddOneOut => 'Odd One Out';

  @override
  String get firstLetter => 'First Letter';

  @override
  String get gameDescWordMatch => 'Match the picture to the correct word!';

  @override
  String get gameDescSpellingBee => 'Unscramble the letters to spell the word!';

  @override
  String get gameDescMemoryMatch => 'Find matching pairs of cards!';

  @override
  String get gameDescDragAndDrop => 'Drag each word to its matching picture!';

  @override
  String get gameDescFlashcardQuiz =>
      'Swipe right if you know it, left to learn!';

  @override
  String get gameDescPronunciation => 'Listen and pick the correct word!';

  @override
  String get gameDescSentenceBuilder =>
      'Fill in the missing word in the sentence!';

  @override
  String get gameDescStoryQuiz => 'Read a story and answer questions!';

  @override
  String get gameDescTracing => 'Trace the letters of each word!';

  @override
  String get gameDescFslPractice => 'Learn Filipino Sign Language!';

  @override
  String get gameDescJigsawPuzzle => 'Assemble the picture puzzle!';

  @override
  String get gameDescPictureWord => 'Match pictures to words by listening!';

  @override
  String get gameDescYesOrNo => 'Is this the right word? Tap Yes or No!';

  @override
  String get gameDescOddOneOut => 'Tap the word that does not belong!';

  @override
  String get gameDescFirstLetter => 'Pick the letter the word starts with!';

  @override
  String get difficultyDescEasy =>
      'Fewer questions, more hints — great for beginners!';

  @override
  String get difficultyDescMedium =>
      'Balanced challenge — the standard experience';

  @override
  String get difficultyDescHard =>
      'More questions, fewer hints — test your skills!';

  @override
  String get suggestStarting =>
      'You\'re just getting started! We\'ll begin with easy questions.';

  @override
  String suggestScopeGame(String game, int percent) {
    return 'In $game, your recent accuracy is $percent%.';
  }

  @override
  String suggestScopeRecent(int percent) {
    return 'Across your recent games, your accuracy is $percent%.';
  }

  @override
  String suggestScopeLifetime(int percent) {
    return 'Your accuracy is $percent%.';
  }

  @override
  String get suggestTierEasy =>
      'Let\'s practice with easier questions to build confidence!';

  @override
  String get suggestTierMedium => 'A balanced challenge to keep you growing!';

  @override
  String get suggestTierHard =>
      'You\'re doing great — time for a real challenge!';

  @override
  String gameRoundHeader(String game, int current, int total) {
    return '$game  •  $current/$total';
  }

  @override
  String get findPictureFor => 'Find the picture for:';

  @override
  String get whichWordMatches => 'Which word matches?';

  @override
  String get whichDoesNotBelong => 'Which one does not belong?';

  @override
  String get startsWithWhichLetter => 'starts with which letter?';

  @override
  String get isThisPrompt => 'Is this…';

  @override
  String heardTryAgain(String spoken) {
    return 'Heard: “$spoken” — try again!';
  }

  @override
  String cameraWordsFound(int count) {
    return '📷 You\'ve found $count words with your camera!';
  }

  @override
  String oddOneOutHint(int count, String category) {
    return '$count are $category';
  }

  @override
  String get allPiecesPlaced => 'All pieces placed! 🎉';

  @override
  String get jigsawHowTo => 'Tap a piece, then tap a grid slot';

  @override
  String movesUsed(int count) {
    return 'Moves: $count';
  }

  @override
  String knownCount(int count) {
    return '$count known';
  }

  @override
  String stillLearningCount(int count) {
    return '$count still learning';
  }

  @override
  String answerChoiceSemantics(String answer) {
    return 'Answer choice: $answer';
  }

  @override
  String answerSemantics(String answer) {
    return 'Answer: $answer';
  }

  @override
  String get correctAnswerSuffix => ', correct answer';

  @override
  String get wrongAnswerSuffix => ', wrong answer';

  @override
  String questionEnglishFor(String word) {
    return 'Question: What is the English word for $word?';
  }

  @override
  String findPictureForSemantics(String word) {
    return 'Find the picture for: $word';
  }

  @override
  String pictureOfSemantics(String word) {
    return 'Picture of $word';
  }

  @override
  String whichWordMatchesSemantics(String word) {
    return 'Which word matches this picture? $word';
  }

  @override
  String firstLetterQuestion(String word) {
    return 'Question: which letter does the word $word start with?';
  }

  @override
  String yesNoQuestion(String pictureWord, String english, String filipino) {
    return 'Question: is this picture of a $pictureWord the word $english, $filipino? Answer Yes or No.';
  }

  @override
  String flashcardSemantics(String english, String filipino, String category) {
    return 'Flashcard: $english, $filipino, category $category. Swipe right for I Know, left for Still Learning';
  }

  @override
  String flashcardProgressSemantics(
    int current,
    int total,
    int known,
    int learning,
  ) {
    return 'Card $current of $total, $known known, $learning still learning';
  }

  @override
  String draggableWordSemantics(String word) {
    return 'Draggable word: $word, drag to matching Filipino word';
  }

  @override
  String dropTargetMatched(String filipino, String english) {
    return 'Matched: $filipino is $english';
  }

  @override
  String dropTargetEmpty(String filipino) {
    return 'Drop target: $filipino, not yet matched';
  }

  @override
  String slotFilled(int position, String letter) {
    return 'Slot $position: $letter, tap to remove';
  }

  @override
  String slotEmpty(int position) {
    return 'Slot $position: empty';
  }

  @override
  String letterAlreadyUsed(String letter) {
    return 'Letter $letter, already used';
  }

  @override
  String letterTapToPlace(String letter) {
    return 'Letter $letter, tap to place';
  }

  @override
  String get playSoundEnglish => 'Play sound: tap to hear the English word';

  @override
  String get playSoundFilipino => 'Play sound: tap to hear the Filipino word';

  @override
  String roundScoreSemantics(int current, int total, int score) {
    return 'Round $current of $total, score $score';
  }

  @override
  String spelledSoFar(String letters) {
    return 'Answer: $letters';
  }

  @override
  String get wordComplete => 'word complete';

  @override
  String oddOneOutQuestion(String words) {
    return 'Question: which word does not belong? The words are $words.';
  }

  @override
  String oddOneOutHintSpoken(int count, String category) {
    return ' $count of them are $category.';
  }

  @override
  String get fslWatchAndChoose =>
      'Watch the sign language video and choose the correct word';

  @override
  String get fslWhatWordIsThisSign => 'What word is this sign?';

  @override
  String get fslWhichSignMeans => 'Which sign means…';

  @override
  String videoChoice(int index) {
    return 'Video choice $index';
  }

  @override
  String dropTargetHolding(String filipino, String word) {
    return 'Drop target: $filipino, currently has $word (wrong)';
  }

  @override
  String dropTargetEmptyHint(String filipino) {
    return 'Drop target: $filipino, empty, drop English match here';
  }

  @override
  String memoryCardMatched(String word) {
    return 'Matched card: $word';
  }

  @override
  String memoryCardShowing(String word) {
    return 'Card showing: $word';
  }

  @override
  String get memoryCardFaceDown => 'Face-down card, tap to flip';

  @override
  String get breakButton => 'Break';

  @override
  String get iNeedABreakTooltip => 'I need a break';

  @override
  String get replayVideo => 'Replay';

  @override
  String get showMe => 'Show Me';

  @override
  String get answerYes => 'Yes';

  @override
  String get answerNo => 'No';

  @override
  String jigsawPuzzleProgress(int current, int total) {
    return 'Puzzle $current of $total';
  }

  @override
  String jigsawCompleteFor(String word) {
    return 'Complete the puzzle for: $word';
  }

  @override
  String jigsawPieceSemantics(int row, int column) {
    return 'Puzzle piece row $row, column $column, tap to place';
  }

  @override
  String memoryProgressSemantics(int matched, int total, int moves) {
    return 'Matched $matched of $total pairs in $moves moves';
  }

  @override
  String jigsawPiecePlaced(int row, int column) {
    return 'Puzzle piece row $row, column $column, placed correctly';
  }

  @override
  String get gazePrev => 'Prev';

  @override
  String get gazeNext => 'Next';

  @override
  String get gazeChoose => 'Choose';

  @override
  String get gazeFlip => 'Flip';

  @override
  String get gazePlace => 'Place';

  @override
  String get gazeUndo => 'Undo';

  @override
  String showMeTitle(String word) {
    return 'Show Me — $word';
  }

  @override
  String get collabLearnTogether => 'Learn Together!';

  @override
  String get collabTeamTagline =>
      'You\'re one team — you score together, not against each other.';

  @override
  String get collabPlayer2NameLabel => 'Player 2\'s Name:';

  @override
  String get collabPlayer2NameSemantics => 'Player 2\'s name';

  @override
  String get collabPlayer2NameHint => 'Enter name...';

  @override
  String get collabChooseActivity => 'Choose an Activity';

  @override
  String get collabEnterPlayer2Name => 'Enter Player 2\'s name';

  @override
  String get collabNoWords => 'No words available right now';

  @override
  String get collabHearAgain => 'Hear it again';

  @override
  String get collabWordRelay => 'Word Relay';

  @override
  String get collabPictureGuess => 'Picture Guess';

  @override
  String get collabSignChallenge => 'Sign Challenge';

  @override
  String get collabStoryBuilder => 'Story Builder';

  @override
  String get collabWordRelayDesc =>
      'Take turns spelling words letter by letter';

  @override
  String get collabPictureGuessDesc =>
      'One player describes, the other guesses the picture';

  @override
  String get collabSignChallengeDesc =>
      'Sign the word, then guess your partner\'s sign';

  @override
  String get collabStoryBuilderDesc =>
      'Build a story together, one sentence at a time';

  @override
  String get collabTeam => 'Team';

  @override
  String collabPromptDescribe(String name, String partner) {
    return '$name, describe the word for $partner';
  }

  @override
  String collabPromptNextLetter(String name) {
    return '$name, what\'s the next letter?';
  }

  @override
  String collabPromptAddSentence(String name) {
    return '$name, add the next sentence';
  }

  @override
  String collabPromptGuess(String name) {
    return '$name, guess the word';
  }

  @override
  String collabAnswerWas(String word) {
    return 'The answer was $word';
  }

  @override
  String get collabHintClue => 'Type a clue...';

  @override
  String get collabHintLetter => 'One letter...';

  @override
  String get collabHintSentence => 'Add the next sentence...';

  @override
  String get collabHintGuess => 'Guess the word...';

  @override
  String get collabWordToSpell => 'Word to spell:';

  @override
  String get collabWordToDescribe => 'Word to describe:';

  @override
  String get collabSignToShow => 'Sign to show:';

  @override
  String get collabWhatIsTheWord => 'What is the word?';

  @override
  String get collabClueLabel => 'Clue:';

  @override
  String get collabBuildStoryTogether => 'Build the story together!';

  @override
  String get collabStartTheStory => 'Start the story!';

  @override
  String get collabWatchTheSign => 'Watch the sign';

  @override
  String collabPhraseBig(String word) {
    return 'The $word is big.';
  }

  @override
  String collabPhraseISee(String word) {
    return 'I can see a $word.';
  }

  @override
  String collabPhraseHappy(String word) {
    return 'The $word is happy.';
  }

  @override
  String collabPhraseWeLike(String word) {
    return 'We like the $word.';
  }

  @override
  String get collabGreatTeamwork => 'Great teamwork!';

  @override
  String collabPointsTogether(int score, int total) {
    return '$score of $total points together';
  }

  @override
  String get collabSubmitAnswer => 'Submit';

  @override
  String collabSetUpForYou(String list) {
    return 'Set up for you: $list.';
  }

  @override
  String get collabAdaptTapToAnswer => 'tap to answer';

  @override
  String get collabAdaptReadAloud => 'read aloud';

  @override
  String get collabAdaptBiggerButtons => 'bigger buttons';

  @override
  String get collabAdaptShorter => 'shorter session';

  @override
  String get collabLeaveTitle => 'Leave this activity?';

  @override
  String get collabLeaveBody =>
      'Your place is saved — you can carry on together later.';

  @override
  String get collabLeaveConfirm => 'Leave';

  @override
  String get collabKeepPlaying => 'Keep playing';

  @override
  String collabClueCategory(String category) {
    return 'Category: $category';
  }

  @override
  String collabClueFirstLetter(String letter) {
    return 'It starts with $letter.';
  }

  @override
  String collabClueLength(int count) {
    return 'It has $count letters.';
  }

  @override
  String collabPassSpoken(String name) {
    return 'Or show it — pass to $name';
  }

  @override
  String get settingOn => 'On';

  @override
  String get settingOff => 'Off';

  @override
  String get settingHighContrastDesc => 'Bolder colors & thicker borders';

  @override
  String get settingDarkModeDesc => 'Easier on the eyes in low light';

  @override
  String get settingDyslexiaDesc =>
      'Cream background, Lexend font, wider letter spacing';

  @override
  String get settingReducedMotionDesc => 'Minimize animations';

  @override
  String get settingVoiceNavOnDesc => 'Announces screens & buttons aloud';

  @override
  String get settingVoiceNavOffDesc => 'Enable for visually impaired users';

  @override
  String get settingAdaptiveOnDesc =>
      'Auto-suggests difficulty based on progress';

  @override
  String get settingAdaptiveOffDesc => 'Manual difficulty selection only';

  @override
  String get settingGazeControlDesc =>
      'Hands-free: move your head or blink to select';

  @override
  String get settingGamepadDesc =>
      'Navigate by Bluetooth gamepad, with spoken feedback';

  @override
  String get settingFullscreenOnDesc =>
      'Nav bar hidden, app bars collapsed — until you turn it off';

  @override
  String get settingFullscreenOffDesc =>
      'Hide the nav bar and app bars for class or TV display';

  @override
  String get settingSlowMotionOnDesc =>
      'Games & flashcards animate at half speed';

  @override
  String get settingSlowMotionOffDesc =>
      'Slow gameplay & flashcard animations down';

  @override
  String get settingLearningAssistOnDesc =>
      'Shows “why” hints and a 50/50 helper in quizzes';

  @override
  String get settingLearningAssistOffDesc =>
      'Plain quizzes — no hints or explanations';

  @override
  String get settingTtsDesc => 'Hear words spoken aloud';

  @override
  String get settingSoundEffectsDesc => 'Game sounds & feedback';

  @override
  String get settingSttOnDesc => 'Voice input enabled in games';

  @override
  String get settingSttOffDesc => 'Tap to enable voice input for games';

  @override
  String get settingCompanionOnDesc =>
      'Floating buddy — tap it any time for help';

  @override
  String get settingCompanionOffDesc => 'Turn on your floating learning buddy';

  @override
  String get settingVocabReviewDesc => 'Reminds you to review weak words';

  @override
  String get settingBackupRestoreDesc => 'Save or restore all app data';

  @override
  String get settingRecoveryCodeDesc => 'Restore this profile on a new device';

  @override
  String get settingCloudAccountDesc =>
      'Sign in with email to restore on any device';

  @override
  String get settingClassroomModeDesc => 'Monitor all students in real time';

  @override
  String get settingAccessibilitySetupDesc =>
      'Restart the accessibility wizard';

  @override
  String get settingManageProfilesDesc =>
      'Delete profiles saved on this device';

  @override
  String get settingChildControlsDesc =>
      'Set time limits & content restrictions';

  @override
  String get settingReplayTutorialsDesc =>
      'Show tutorial guides again on all screens';

  @override
  String get settingPurposeDesc =>
      'Interactive vocabulary building app for PWD students using flashcards, games, and Filipino Sign Language.';

  @override
  String get settingResearchDataOnDesc =>
      'Sending anonymous crash & usage data to the research team';

  @override
  String get settingResearchDataOffDesc => 'Off — no data leaves this device';

  @override
  String settingDailyMissionDesc(int count) {
    return '$count words per day';
  }

  @override
  String get settingGazeControlTitle => 'Gaze Control (Preview)';

  @override
  String get settingGamepadTitle => 'Game Controller';

  @override
  String get settingSectionPresentation => 'Presentation';

  @override
  String get settingSectionLearningModes => 'Learning Modes';

  @override
  String get settingSlowMotionTitle => 'Slow-Motion Mode';

  @override
  String get settingLearningAssistTitle => 'Learning Assist';

  @override
  String get settingDailyMissionTitle => 'Daily Mission Size';

  @override
  String get settingCompanionTitle => 'AI Companion';

  @override
  String get settingVocabReviewTitle => 'Vocab Review Reminder';

  @override
  String get settingSectionMyDay => 'My Day';

  @override
  String get settingRoutineTitle => 'Routine';

  @override
  String get settingRoutineOnDesc =>
      'My Day shows on your home — plan your day, step by step';

  @override
  String get settingRoutineOffDesc =>
      'Turn on My Day to plan your day, step by step';

  @override
  String get settingSectionData => 'Data';

  @override
  String get settingBackupRestoreTitle => 'Backup & Restore';

  @override
  String get settingRecoveryCodeTitle => 'Cloud Recovery Code';

  @override
  String get settingCloudAccountTitle => 'Backup & Link Account';

  @override
  String get settingAccessibilitySetupTitle => 'Re-run Accessibility Setup';

  @override
  String get settingManageProfilesTitle => 'Manage Profiles';

  @override
  String get settingChildControlsTitle => 'Parental Controls';

  @override
  String get settingReplayTutorialsTitle => 'Replay Tutorials';

  @override
  String get settingPurposeTitle => 'Purpose';

  @override
  String get settingResearchDataTitle => 'Help improve the app';

  @override
  String get fontSizeSmall => 'Small';

  @override
  String get fontSizeNormal => 'Normal';

  @override
  String get fontSizeLarge => 'Large';

  @override
  String get fontSizeExtraLarge => 'Extra Large';

  @override
  String get speechSpeedVerySlow => 'Very Slow';

  @override
  String get speechSpeedSlow => 'Slow';

  @override
  String get speechSpeedNormal => 'Normal';

  @override
  String get speechSpeedFast => 'Fast';

  @override
  String speechSpeedSpoken(String label, int step, int stops) {
    return '$label, $step of $stops';
  }

  @override
  String setFontSizeTo(String size) {
    return 'Set font size to $size';
  }

  @override
  String get changeLabel => 'Change';

  @override
  String get changePinTitle => 'Change PIN';

  @override
  String get setProfilePinTitle => 'Set Profile PIN';

  @override
  String get pinPrompt => 'Choose a 4-digit PIN to protect your profile.';

  @override
  String get disabilityVisual => 'Visual Impairment';

  @override
  String get disabilityHearing => 'Hearing Impairment';

  @override
  String get disabilityMotor => 'Motor Impairment';

  @override
  String get disabilityCognitive => 'Cognitive/Learning';

  @override
  String get disabilityMultiple => 'Multiple Disabilities';

  @override
  String get disabilityNone => 'No Accessibility Needs';

  @override
  String get disabilityCognitiveFull => 'Cognitive/Learning Disability';

  @override
  String get disabilityVisualDesc =>
      'Difficulty seeing, low vision, or color blindness';

  @override
  String get disabilityHearingDesc => 'Difficulty hearing or deaf';

  @override
  String get disabilityMotorDesc =>
      'Difficulty with fine motor skills or touch';

  @override
  String get disabilityCognitiveDesc =>
      'Dyslexia, ADHD, or learning difficulties';

  @override
  String get disabilityMultipleDesc => 'Combination of accessibility needs';

  @override
  String get disabilityNoneDesc => 'Standard settings, no special adjustments';

  @override
  String get roleNameStudent => 'Student';

  @override
  String get roleNameTeacher => 'Teacher';

  @override
  String get roleNameParent => 'Parent';

  @override
  String get roleNameChild => 'Child';

  @override
  String get roleNamePlayer => 'Player';

  @override
  String dashboardTitleForPerson(String name) {
    return '$name Dashboard';
  }

  @override
  String dashboardTitleForRole(String role) {
    return '$role Dashboard';
  }

  @override
  String eduWelcome(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get eduSubtitleParent => 'Monitor your children\'s learning';

  @override
  String get eduSubtitleTeacher => 'Manage your class progress';

  @override
  String get eduQuickActions => 'Quick Actions';

  @override
  String get eduMore => 'More';

  @override
  String get eduContent => 'Content';

  @override
  String get eduAssessmentsProgress => 'Assessments & Progress';

  @override
  String get eduResearch => 'Research';

  @override
  String get eduNeedsHelp => 'Needs Help';

  @override
  String get eduInactive7d => 'Inactive 7d+';

  @override
  String get eduActiveToday => 'Active Today';

  @override
  String get eduReports => 'Reports';

  @override
  String get eduWeeklySummary => 'Weekly summary';

  @override
  String get eduParentalControlsTile => 'Parental Controls';

  @override
  String get eduLimitsSafety => 'Limits & safety';

  @override
  String get eduCards => 'Cards';

  @override
  String get eduBrowseDecks => 'Browse decks';

  @override
  String get eduShareCode => 'Share Code';

  @override
  String get eduInviteChild => 'Invite your child';

  @override
  String get eduInviteStudents => 'Invite students';

  @override
  String get eduTvCast => 'TV Cast';

  @override
  String get eduMessages => 'Messages';

  @override
  String get eduTeacherNotes => 'Teacher Notes';

  @override
  String get eduParentNotes => 'Parent Notes';

  @override
  String get eduAssessments => 'Assessments';

  @override
  String get eduAssignTasks => 'Assign Tasks';

  @override
  String get eduTrackProgress => 'Track Progress';

  @override
  String get eduManageGroups => 'Manage Groups';

  @override
  String get eduManageClasses => 'Manage Classes';

  @override
  String get eduRosterProgress => 'Roster & progress';

  @override
  String get eduAnalytics => 'Analytics';

  @override
  String get eduClassInsights => 'Class insights';

  @override
  String get eduClassroomTile => 'Classroom';

  @override
  String get eduLiveSession => 'Live session';

  @override
  String get eduWorksheets => 'Worksheets';

  @override
  String get eduExperimentSetup => 'Experiment Setup';

  @override
  String get eduSusSurvey => 'SUS Survey';

  @override
  String get eduResearchExport => 'Research Export';

  @override
  String get eduDashboardCtaSub =>
      'Detailed insights, alerts, and recommendations';

  @override
  String get eduNoChildrenDesc =>
      'Create a home group, then share the code with your child to join.';

  @override
  String get eduNoStudentsDesc =>
      'Create a class, then share the code with your students to join.';

  @override
  String get assessPreTest => 'Pre-Test';

  @override
  String get assessPostTest => 'Post-Test';

  @override
  String get assessCategoryMastery => 'Category Mastery';

  @override
  String get assessCustom => 'Custom Assessment';

  @override
  String get assessPreTestDesc =>
      'Measure your starting knowledge before learning';

  @override
  String get assessPostTestDesc =>
      'See how much you\'ve improved after learning';

  @override
  String get assessCategoryMasteryDesc =>
      'Test your mastery of a specific category';

  @override
  String get assessCustomDesc => 'Teacher-created assessment';

  @override
  String get formatMultipleChoice => 'Multiple Choice';

  @override
  String get formatFillInBlank => 'Fill in the Blank';

  @override
  String get formatMatchPairs => 'Match Pairs';

  @override
  String get formatTrueFalse => 'True or False';

  @override
  String get formatSignVideo => 'Watch the Sign';

  @override
  String get signQuestionPrompt => 'Watch the sign. Which word is it?';

  @override
  String get assessCenterTitle => 'Assessment Center';

  @override
  String get assessCenterLearnerSub => 'Measure your learning progress';

  @override
  String get assessCenterEducatorSub =>
      'Build, assign and track your learners\' tests';

  @override
  String get assessPrePostSection => 'Pre-Test & Post-Test';

  @override
  String get assessPrePostLearnerBlurb =>
      'Take a pre-test before studying, then a post-test after — see your growth!';

  @override
  String get assessPrePostEducatorBlurb =>
      'Your learners sit these. Assign the pre-test first, then the post-test after the lessons — the gain appears here.';

  @override
  String get assessMasterySection => 'Category Mastery Tests';

  @override
  String get assessMasteryBlurb =>
      'Test your knowledge in specific vocabulary categories';

  @override
  String get assessAssignedToYou => 'Assigned to You';

  @override
  String get assessRecentResults => 'Recent Results';

  @override
  String get assessSeeAll => 'See All';

  @override
  String get assessClassReport => 'Class report';

  @override
  String get assessYourAttempts => 'Your attempts';

  @override
  String get assessAttemptCounts => 'Counts';

  @override
  String get assessAttemptsOne => '1 attempt';

  @override
  String assessAttemptsMany(int count) {
    return '$count attempts';
  }

  @override
  String get assessNoLearnersYet => 'No learners yet';

  @override
  String get assessNoLearnersDesc =>
      'Share a class or home-group code, then assign the pre-test.';

  @override
  String get assessNeedPreTestFirst => 'Complete a Pre-Test first';

  @override
  String get assessKeepStudying => 'Keep studying';

  @override
  String assessKeepStudyingFor(String what) {
    return 'Keep studying — $what';
  }

  @override
  String assessMoreDays(int count) {
    return '$count more days';
  }

  @override
  String get assessOneMoreDay => '1 more day';

  @override
  String assessMoreStudyDays(int count) {
    return '$count more study days';
  }

  @override
  String get assessOneMoreStudyDay => '1 more study day';

  @override
  String assessAndJoin(String a, String b) {
    return '$a and $b';
  }

  @override
  String get assessRetakeLocked =>
      'Already done — ask your teacher to reopen it';

  @override
  String get assessReadyForPost => 'Ready for post-test';

  @override
  String get assessPostAssigned => 'Post-test assigned';

  @override
  String get assessPreOutstanding => 'Pre-test outstanding';

  @override
  String assessPostIn(String wait) {
    return 'Pre-test done · post-test suggested after $wait';
  }

  @override
  String get assessPreFromEducator =>
      'Your teacher or parent will give you this test';

  @override
  String get assessPostFromEducator =>
      'Your teacher or parent will open this after your lessons';

  @override
  String get assessClipsPreparing => 'Getting the sign videos ready…';

  @override
  String get assessClipsMissingTitle => 'The sign videos need the internet';

  @override
  String get assessClipsMissingBody =>
      'This test has sign-language videos that are not on this tablet yet. Connect to Wi‑Fi, then try again. The test has not started.';

  @override
  String get assessClipsTryAgain => 'Try again';

  @override
  String get assessClipsGoBack => 'Go back';

  @override
  String get eduClassReport => 'Class Report';

  @override
  String get supportSectionTitle => 'Learner Support';

  @override
  String supportSectionBlurb(String category) {
    return 'How $category works for this learner. These can be changed any time.';
  }

  @override
  String get supportGroupCommunication => 'Communication & language';

  @override
  String get supportGroupCommunicationDesc =>
      'How this learner takes in language. Pick one.';

  @override
  String get supportGroupHearingExtras => 'Hearing supports';

  @override
  String get supportGroupVisualAccess => 'Reading the screen';

  @override
  String get supportGroupVisualAccessDesc =>
      'How this learner gets at what is on screen. Pick one.';

  @override
  String get supportGroupVisualExtras => 'Vision supports';

  @override
  String get supportGroupInput => 'Controlling the app';

  @override
  String get supportGroupInputDesc =>
      'How this learner moves around the app. Pick one.';

  @override
  String get supportGroupMotorExtras => 'Movement supports';

  @override
  String get supportGroupThinking => 'Learning support';

  @override
  String get supportGroupThinkingDesc =>
      'How instructions should reach this learner. Pick one.';

  @override
  String get supportGroupCognitiveExtras => 'Understanding supports';

  @override
  String get supportGroupOther => 'Other supports';

  @override
  String get supportGroupOptional => 'Optional supports';

  @override
  String get supportGroupExtrasDesc => 'Add anything else that helps.';

  @override
  String get supportGroupNoneDesc => 'Nothing here is required.';

  @override
  String get supportSignFsl => 'Filipino Sign Language (FSL)';

  @override
  String get supportSignFslDesc =>
      'Signs used in Filipino Deaf schools. The app’s sign clips are in FSL.';

  @override
  String get supportSignAsl => 'American Sign Language (ASL)';

  @override
  String get supportSignAslDesc => 'Signs used in American Deaf communities.';

  @override
  String get supportSignSee => 'Signing Exact English (SEE)';

  @override
  String get supportSignSeeDesc =>
      'Signs that follow English word order, sign for sign.';

  @override
  String get supportCuedSpeech => 'Cued Speech';

  @override
  String get supportCuedSpeechDesc =>
      'Hand shapes near the mouth that make speech sounds visible.';

  @override
  String get supportOralLipReading => 'Speech & Lip Reading';

  @override
  String get supportOralLipReadingDesc =>
      'Learns by watching the mouth and using any remaining hearing.';

  @override
  String get supportWrittenCaptions => 'Written words only';

  @override
  String get supportWrittenCaptionsDesc =>
      'Reads text instead of signing. Sign clips stay hidden.';

  @override
  String get supportCaptionsAlwaysOn => 'Captions always on';

  @override
  String get supportCaptionsAlwaysOnDesc =>
      'Every video and story shows its text. Noted on the profile for the teaching team.';

  @override
  String get supportVisualAlerts => 'Flash instead of sound';

  @override
  String get supportVisualAlertsDesc =>
      'Screen flashes and badges stand in for chimes.';

  @override
  String get supportAudioFirst => 'Listen first (screen reader)';

  @override
  String get supportAudioFirstDesc =>
      'Everything is spoken; the screen is the second channel.';

  @override
  String get supportLargePrint => 'Large print';

  @override
  String get supportLargePrintDesc => 'Very large type, few items per screen.';

  @override
  String get supportSpokenAnswerChoices => 'Read the choices aloud';

  @override
  String get supportSpokenAnswerChoicesDesc =>
      'Each answer choice is spoken before the learner picks.';

  @override
  String get supportInputTouch => 'Touch';

  @override
  String get supportInputTouchDesc => 'Taps the screen as usual.';

  @override
  String get supportInputGaze => 'Eye gaze (hands-free)';

  @override
  String get supportInputGazeDesc => 'Controls the app by looking at it.';

  @override
  String get supportInputSwitch => 'Switch or gamepad';

  @override
  String get supportInputSwitchDesc =>
      'Uses a Bluetooth gamepad or switch instead of touch.';

  @override
  String get supportSimplifiedLanguage => 'Simple words';

  @override
  String get supportSimplifiedLanguageDesc =>
      'Short sentences and everyday words.';

  @override
  String get supportPicturePrompts => 'Picture support';

  @override
  String get supportPicturePromptsDesc =>
      'A picture goes with every instruction. Noted on the profile for the teaching team.';

  @override
  String get supportStepByStep => 'One step at a time';

  @override
  String get supportStepByStepDesc =>
      'One instruction at a time, with a clear next step.';

  @override
  String get supportRepeatInstructions => 'Repeat instructions';

  @override
  String get supportRepeatInstructionsDesc =>
      'Instructions can be replayed as often as needed. Noted on the profile for the teaching team.';

  @override
  String get supportFewerChoices => 'Fewer answer choices';

  @override
  String get supportFewerChoicesDesc =>
      'Questions offer two choices instead of four.';

  @override
  String get supportExtendedTestTime => 'Extra time on tests';

  @override
  String get supportExtendedTestTimeDesc =>
      'Timed assessments give this learner half again as long.';

  @override
  String get reportForEducatorsTitle => 'For teachers and parents';

  @override
  String get reportForEducatorsDesc =>
      'This report reads a whole class at once. Your own results live in the Assessment Center.';

  @override
  String get reportCheckNewResults => 'Check for new results';

  @override
  String get reportNoLearnersDesc =>
      'Share a class or home-group code, then assign the pre-test. The report fills in as results come back.';

  @override
  String get reportAssignWork => 'Assign work';

  @override
  String get reportGainSection => 'Learning gain by accessibility';

  @override
  String get reportGainSectionDesc =>
      'Averages over the learners who have finished both halves. Anyone still missing one is counted separately.';

  @override
  String get reportGainNone =>
      'No learner has finished both halves yet, so there is nothing to average. Assign the pre-test first.';

  @override
  String get reportItemsSection => 'Hardest items';

  @override
  String get reportItemsSectionDesc =>
      'Every question the class has answered, hardest first. “Split the class” with a low separation usually means the wording, not the word.';

  @override
  String get reportItemsNone =>
      'No answers recorded yet. This fills in as your learners finish assessments.';

  @override
  String get reportAttemptsSection => 'Attempts';

  @override
  String get reportAttemptsSectionDesc =>
      'The most recent sitting of each half is the one a learning gain is measured from.';

  @override
  String get reportMetricPre => 'Pre';

  @override
  String get reportMetricPost => 'Post';

  @override
  String get reportMetricGain => 'Gain';

  @override
  String get reportMetricNormalized => 'Normalized';

  @override
  String get reportMetricMeasured => 'Measured';

  @override
  String get reportMetricWaiting => 'Still waiting';

  @override
  String get reportMetricMedian => 'Median';

  @override
  String get reportMetricSeparation => 'Separation';

  @override
  String get reportMetricOftenAnswered => 'Often answered';

  @override
  String get reportAttemptNone => 'none';

  @override
  String reportAttemptEarlier(int count) {
    return '(+$count earlier)';
  }

  @override
  String get reportDifficultyEasy => 'Easy for the class';

  @override
  String get reportDifficultyMost => 'Most got it';

  @override
  String get reportDifficultySplit => 'Split the class';

  @override
  String get reportDifficultyHard => 'Hard';

  @override
  String get reportDifficultyNobody => 'Almost nobody';

  @override
  String get reportNeedsReview =>
      'Your strongest learners did no better on this one — worth rereading the wording.';

  @override
  String reportGainSemantics(
    String category,
    int count,
    int pre,
    int post,
    int gain,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count learners measured',
      one: '1 learner measured',
    );
    return '$category. $_temp0. Mean pre-test $pre percent, post-test $post percent, gain $gain percent.';
  }

  @override
  String reportGainNoneSemantics(String category, int count) {
    return '$category. No learner has finished both halves yet. $count waiting.';
  }

  @override
  String reportItemCorrectSemantics(int correct, int attempts, int percent) {
    return '$correct of $attempts correct, $percent percent';
  }

  @override
  String reportItemWrongSemantics(String answer) {
    return 'Most common wrong answer, $answer';
  }

  @override
  String get reportItemReviewSemantics => 'This item may need rewording';

  @override
  String get rxTitle => 'Research Data Export';

  @override
  String get rxHeader => 'Thesis Research Export';

  @override
  String get rxIntro =>
      'Export anonymized data for the learners you tick below. Names are replaced with IDs that stay the same in every export, so files from several devices can be merged.';

  @override
  String get rxParticipants => 'Participants';

  @override
  String get rxParticipantsHint =>
      'Only ticked learners are exported. Your own classes and home groups are ticked for you.';

  @override
  String rxSelectedCount(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get rxTickAll => 'Tick all';

  @override
  String get rxUntickAll => 'Untick all';

  @override
  String get rxYourGroups => 'In your classes and home groups';

  @override
  String get rxOtherLearners => 'Other learners on this tablet';

  @override
  String get rxOtherLearnersHint =>
      'Not in your classes or home groups — left out unless you tick them.';

  @override
  String get rxDataAvailable => 'Data Available';

  @override
  String get rxLearners => 'Learners';

  @override
  String get rxGameScores => 'Game scores';

  @override
  String get rxSessions => 'Sessions logged';

  @override
  String get rxAssessmentResults => 'Assessment results';

  @override
  String get rxMoodEntries => 'Mood entries';

  @override
  String get rxGainReports => 'Learning gain reports';

  @override
  String get rxFilesIncluded => 'Files Included';

  @override
  String get rxFileStudentsOverview =>
      'Demographics & aggregate stats per student';

  @override
  String get rxFileLearningCurves =>
      'Game scores over time (for trend analysis)';

  @override
  String get rxFileSessionPatterns => 'Session logs with day-of-week patterns';

  @override
  String get rxFileCategoryMastery => 'Per-category mastery % for each student';

  @override
  String get rxFileWordAccuracy => 'Spaced-repetition per-word accuracy data';

  @override
  String get rxFileAssessmentResults => 'Pre/post test scores & learning gains';

  @override
  String get rxFileMoodData => 'Mood check-ins correlated with activities';

  @override
  String get rxFileAdaptiveDifficulty =>
      'Difficulty adjustments & accuracy over time';

  @override
  String get rxFileSummaryStats => 'High-level aggregates for quick reference';

  @override
  String rxExportButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Export Research Data ($count learners)',
      one: 'Export Research Data (1 learner)',
    );
    return '$_temp0';
  }

  @override
  String get rxGenerating => 'Generating…';

  @override
  String get rxNobodyTicked => 'Tick at least one learner to export.';

  @override
  String get rxNoLearners =>
      'No learner profiles yet. Learners appear here once they join your class or home group.';

  @override
  String get rxExported => 'Research data exported successfully!';

  @override
  String rxExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String qpFilipinoWordFor(String word) {
    return 'What is the Filipino word for “$word”?';
  }

  @override
  String qpEnglishWordFor(String word) {
    return 'What is the English word for “$word”?';
  }

  @override
  String qpFillBlank(String word) {
    return 'Fill in the blank: The Filipino translation of “$word” is _____.';
  }

  @override
  String qpTrueFalse(String english, String shown) {
    return 'True or False: “$english” is “$shown” in Filipino.';
  }

  @override
  String qpInFilipinoIs(String english, String shown) {
    return '“$english” in Filipino is “$shown”';
  }

  @override
  String qpMatch(String word) {
    return 'Match: “$word” → ?';
  }

  @override
  String qpTypeFilipino(String word) {
    return 'Type the Filipino word for “$word”:';
  }

  @override
  String qpTypeEnglish(String word) {
    return 'Type the English word for “$word”:';
  }

  @override
  String get qpTrue => 'True';

  @override
  String get qpFalse => 'False';

  @override
  String get testQuitTooltip => 'Quit assessment';

  @override
  String get testQuitTitle => 'Quit Assessment?';

  @override
  String get testQuitBody =>
      'Your progress will be lost. Are you sure you want to quit?';

  @override
  String get testQuitContinue => 'Continue';

  @override
  String get testQuitConfirm => 'Quit';

  @override
  String testQuestionOf(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String testProgressSemantics(int percent) {
    return 'Progress: $percent percent complete';
  }

  @override
  String get testShowHint => 'Show Hint';

  @override
  String get testHideHint => 'Hide Hint';

  @override
  String get testFinish => 'Finish Assessment';

  @override
  String get testNext => 'Next Question';

  @override
  String get testTypeHere => 'Type your answer here...';

  @override
  String get testSubmit => 'Submit Answer';

  @override
  String testHintAnswer(String answer) {
    return 'Correct answer: $answer';
  }

  @override
  String get testCorrect => 'Correct!';

  @override
  String get testNotQuite => 'Not quite right';

  @override
  String testTheAnswerIs(String answer) {
    return 'The correct answer is: $answer';
  }

  @override
  String testMinutesLeft(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes remaining',
      one: '1 minute remaining',
    );
    return '$_temp0';
  }

  @override
  String testSecondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds remaining',
      one: '1 second remaining',
    );
    return '$_temp0';
  }

  @override
  String get gradeExcellent => 'Excellent';

  @override
  String get gradeVeryGood => 'Very Good';

  @override
  String get gradeGood => 'Good';

  @override
  String get gradeNeedsImprovement => 'Needs Improvement';

  @override
  String get gradeKeepPracticing => 'Keep Practicing';

  @override
  String get supportShortLipReading => 'Lip reading';

  @override
  String get supportShortWritten => 'Written';

  @override
  String get supportShortAudioFirst => 'Audio first';

  @override
  String get supportShortGaze => 'Gaze';

  @override
  String get supportShortTouch => 'Touch';

  @override
  String sumComplete(String type) {
    return '$type Complete!';
  }

  @override
  String get sumTime => 'Time';

  @override
  String get sumCorrect => 'Correct';

  @override
  String get sumWrong => 'Wrong';

  @override
  String get sumCategoryBreakdown => 'Category Breakdown';

  @override
  String get sumQuestionReview => 'Question Review';

  @override
  String get sumBackToHub => 'Back to Hub';

  @override
  String get sumViewAnalytics => 'View Analytics';

  @override
  String sumCategorySemantics(String category, int percent) {
    return '$category: $percent percent';
  }

  @override
  String get resTitle => 'Assessment Analytics';

  @override
  String resCompletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assessments completed',
      one: '1 assessment completed',
    );
    return '$_temp0';
  }

  @override
  String get resEmpty => 'No assessments completed yet';

  @override
  String get resTakeOne => 'Take an Assessment';

  @override
  String get resTrend => 'Score Trend Over Time';

  @override
  String get resCategoryMastery => 'Category Mastery';

  @override
  String get resHistory => 'Assessment History';

  @override
  String get resLearningGain => 'Learning Gain';

  @override
  String get resPerCategoryGains => 'Per-Category Gains';

  @override
  String get resAvgScore => 'Avg Score';

  @override
  String get resAssessments => 'Assessments';

  @override
  String get resTotalTime => 'Total Time';

  @override
  String get resNeedTwo => 'Complete 2+ assessments to see trends';

  @override
  String resHistoryLine(String date, int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$date • $_temp0 • $duration';
  }

  @override
  String resAttemptSemantics(int percent, String date) {
    return '$percent percent on $date';
  }

  @override
  String get resAttemptCountsSemantics =>
      'This is the attempt your learning gain uses';

  @override
  String resSatWith(String supports) {
    return 'Sat with $supports';
  }

  @override
  String gainImproved(int pre, int post, int gain) {
    return 'Score improved from $pre% to $post% (+$gain%)';
  }

  @override
  String gainSame(int pre) {
    return 'Score remained at $pre%';
  }

  @override
  String gainChanged(int pre, int post, int gain) {
    return 'Score changed from $pre% to $post% ($gain%)';
  }

  @override
  String get hubResultsTooltip => 'View assessment results and analytics';

  @override
  String get hubCreate => 'Create';

  @override
  String get hubAssign => 'Assign';

  @override
  String get hubTrack => 'Track';

  @override
  String get hubQuizBuilder => 'Quiz Builder';

  @override
  String get hubQuizBuilderDesc => 'Create custom quizzes from any flashcards';

  @override
  String get hubCustomAssessments => 'Custom Assessments';

  @override
  String get hubCreateCustomTooltip => 'Create a new custom assessment';

  @override
  String get hubNoCustom => 'No custom assessments yet';

  @override
  String get hubNoCustomHint => 'Tap + to create one for your students';

  @override
  String get hubViewAllResults => 'View all results';

  @override
  String hubGainSemantics(String summary) {
    return 'Learning gain report. $summary';
  }

  @override
  String get hubGainTitle => 'Learning Gain Report';

  @override
  String hubCardLockedSemantics(String type, String reason) {
    return '$type. Locked. $reason';
  }

  @override
  String hubCardDoneSemantics(String type, int percent) {
    return '$type. Completed. Latest score $percent percent. Tap to retake.';
  }

  @override
  String hubCardNewSemantics(String type) {
    return '$type. Not yet taken. Tap to start.';
  }

  @override
  String hubBest(int percent) {
    return 'Best: $percent%';
  }

  @override
  String get hubTapToStart => 'Tap to start';

  @override
  String hubMasteryTriedSemantics(String category, int percent, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
    );
    return '$category mastery test. Best score: $percent percent, $_temp0. Tap to start.';
  }

  @override
  String hubMasteryNewSemantics(String category) {
    return '$category mastery test. Not attempted yet. Tap to start.';
  }

  @override
  String get hubNotTested => 'Not tested';

  @override
  String hubQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String get hubOverdue => 'Overdue';

  @override
  String hubDue(String date) {
    return 'Due $date';
  }

  @override
  String hubCustomTileSemantics(String title, String questions) {
    return '$title. $questions. Tap to take.';
  }

  @override
  String get hubDeleteTitle => 'Delete Assessment?';

  @override
  String hubDeleteBody(String title) {
    return 'Are you sure you want to delete “$title”? This cannot be undone.';
  }

  @override
  String get hubCancel => 'Cancel';

  @override
  String get hubDelete => 'Delete';

  @override
  String hubResultSemantics(
    String type,
    int percent,
    String grade,
    String date,
  ) {
    return '$type. Score: $percent percent. $grade. Completed $date.';
  }

  @override
  String get hubNoLearners => 'No learners yet';

  @override
  String get hubNoLearnersHint =>
      'Share a class or home-group code, then assign the pre-test.';

  @override
  String hubGain(String gain) {
    return 'Gain $gain';
  }

  @override
  String hubLearnerRowSemantics(String name, String status) {
    return '$name. $status. Tap to open their profile.';
  }

  @override
  String get hubPre => 'Pre';

  @override
  String get hubPost => 'Post';

  @override
  String get bannerOverdue => 'Overdue Assignments';

  @override
  String get bannerPending => 'Pending Assignments';

  @override
  String bannerSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count assessments to complete',
      one: 'You have 1 assessment to complete',
    );
    return '$_temp0';
  }

  @override
  String bannerSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending assessments assigned to you',
      one: '1 pending assessment assigned to you',
    );
    return '$_temp0';
  }

  @override
  String get titleAllCategories => 'All Categories';

  @override
  String titleMastery(String category) {
    return '$category Mastery Test';
  }

  @override
  String get asgPreFirst =>
      'Assign a pre-test first — the post-test mirrors it.';

  @override
  String get asgQuizEmpty => 'That quiz has no cards left to ask about.';

  @override
  String asgAssigned(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assessment assigned to $count learners!',
      one: 'Assessment assigned to 1 learner!',
    );
    return '$_temp0';
  }

  @override
  String asgLocalOnly(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Saved for $count learners on this device — not sent yet. It will upload when syncing is working.',
      one:
          'Saved for 1 learner on this device — not sent yet. It will upload when syncing is working.',
    );
    return '$_temp0';
  }

  @override
  String get asgNotOwner =>
      'Saved on this device only. This profile was restored on another device, so that one now handles syncing. Restore it back here to send work to your learners.';

  @override
  String get asgClassPre => 'Class Pre-Test';

  @override
  String get asgClassPost => 'Class Post-Test';

  @override
  String get asgTitle => 'Assign Assessment';

  @override
  String get asgStudyLabel => 'Study pre-test & post-test';

  @override
  String get asgStudyCaption =>
      'The same questions for everyone you select. Assign the post-test when the study period ends.';

  @override
  String get asgQuizzes => 'Quizzes';

  @override
  String get asgQuizzesCaption => 'Makes a fresh test each time you assign it';

  @override
  String get asgSaved => 'Saved assessments';

  @override
  String get asgSavedCaption => 'A fixed set of questions';

  @override
  String asgSelectStudents(int selected, int total) {
    return 'Select Students ($selected/$total)';
  }

  @override
  String get asgSelectAll => 'Select All';

  @override
  String get asgDeselectAll => 'Deselect All';

  @override
  String get asgDeadline => 'Deadline (optional)';

  @override
  String get asgSetDeadline => 'Set Deadline';

  @override
  String get asgRemoveDeadline => 'Remove deadline';

  @override
  String get asgInstructions => 'Instructions (optional)';

  @override
  String get asgInstructionsHint => 'Add instructions for students...';

  @override
  String get asgAssigning => 'Assigning...';

  @override
  String get asgMadeFresh => 'made fresh when you assign';

  @override
  String get asgMirrors => 'mirrors the pre-test each learner sat';

  @override
  String get asgNoChildren => 'No children yet';

  @override
  String get asgNoStudents => 'No students yet';

  @override
  String get asgShareHomeHint =>
      'Share your home group code so your child can join, then assign them work here.';

  @override
  String get asgShareClassHint =>
      'Share your class code so students can join, then assign them work here.';

  @override
  String get asgShareGroupCode => 'Share Group Code';

  @override
  String get asgShareClassCode => 'Share Class Code';

  @override
  String get trkTitle => 'Assignment Tracking';

  @override
  String get trkRefresh => 'Check for new results';

  @override
  String get trkDeleteTitle => 'Delete Assignment?';

  @override
  String get trkDeleteBody =>
      'This will remove the assignment. Student results will be kept.';

  @override
  String get trkNotOwner =>
      'Removed here only. This profile was restored on another device, so that one now handles syncing — your learners still have this assignment.';

  @override
  String trkDue(String date) {
    return 'Due: $date';
  }

  @override
  String get trkEmpty => 'No assignments yet';

  @override
  String get trkEmptyHint =>
      'Assign assessments to students and track their progress here.';

  @override
  String gmScreenTitle(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Home Groups',
      'other': 'Manage Classes',
    });
    return '$_temp0';
  }

  @override
  String gmCreateHint(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'e.g. The Santos Family',
      'other': 'e.g. Grade 3 - Math',
    });
    return '$_temp0';
  }

  @override
  String gmShareBlurb(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Open the app, tap “Join a home group”, and enter the code.',
      'other': 'Open the app, tap “Join a class”, and enter the code.',
    });
    return '$_temp0';
  }

  @override
  String get gmRefresh => 'Refresh';

  @override
  String gmNewGroup(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'New home group',
      'other': 'New class',
    });
    return '$_temp0';
  }

  @override
  String gmEmptyTitle(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'No home groups yet',
      'other': 'No classes yet',
    });
    return '$_temp0';
  }

  @override
  String gmEmptyBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Create a home group, then share the join code so your children can join from their own devices.',
      'other':
          'Create a class, then share the join code so your students can join from their own devices.',
    });
    return '$_temp0';
  }

  @override
  String gmCreateGroup(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Create home group',
      'other': 'Create class',
    });
    return '$_temp0';
  }

  @override
  String gmGroupName(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Home group name',
      'other': 'Class name',
    });
    return '$_temp0';
  }

  @override
  String get gmCreate => 'Create';

  @override
  String gmNameRequired(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Home group name is required',
      'other': 'Class name is required',
    });
    return '$_temp0';
  }

  @override
  String gmCreated(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Home group created.',
      'other': 'Class created.',
    });
    return '$_temp0';
  }

  @override
  String get gmOverview => 'Overview';

  @override
  String gmGroupCount(String audience, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count home groups',
      one: '1 home group',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count classes',
      one: '1 class',
    );
    String _temp2 = intl.Intl.selectLogic(audience, {
      'parent': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String gmMemberCount(String audience, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count children',
      one: '1 child',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count students',
      one: '1 student',
    );
    String _temp2 = intl.Intl.selectLogic(audience, {
      'parent': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String gmGroupsLabel(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'home groups',
      'other': 'classes',
    });
    return '$_temp0';
  }

  @override
  String gmMembersLabel(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'children',
      'other': 'students',
    });
    return '$_temp0';
  }

  @override
  String get gmActive => 'active';

  @override
  String get gmEnrolled => 'enrolled';

  @override
  String get gmNewestJoin => 'Newest join';

  @override
  String get gmNoJoins => 'no joins yet';

  @override
  String get gmMostRecent => 'most recent';

  @override
  String get gmLoadingRoster => 'Loading roster…';

  @override
  String gmGroupActions(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Home group actions',
      'other': 'Class actions',
    });
    return '$_temp0';
  }

  @override
  String get gmRename => 'Rename';

  @override
  String get gmAccessibility => 'Accessibility';

  @override
  String get gmNewJoinCode => 'New join code';

  @override
  String get gmLeaderboard => 'Leaderboard';

  @override
  String get gmLockRetakes => 'Lock test retakes';

  @override
  String get gmAllowRetakes => 'Allow test retakes';

  @override
  String gmDeleteGroup(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Delete home group',
      'other': 'Delete class',
    });
    return '$_temp0';
  }

  @override
  String get gmHideRoster => 'Hide roster';

  @override
  String get gmShowRoster => 'Show roster';

  @override
  String get gmCopyCode => 'Copy code';

  @override
  String get gmShareCode => 'Share code';

  @override
  String gmRosterError(String error) {
    return 'Roster error: $error';
  }

  @override
  String gmNoMembers(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'No children have joined yet — share the code above.',
      'other': 'No students have joined yet — share the code above.',
    });
    return '$_temp0';
  }

  @override
  String gmSelected(int count) {
    return '$count selected';
  }

  @override
  String gmRemoveCount(int count) {
    return 'Remove ($count)';
  }

  @override
  String get gmLockTitle => 'Lock test retakes?';

  @override
  String get gmAllowTitle => 'Allow test retakes?';

  @override
  String gmLockBody(String name) {
    return 'Learners in “$name” will not be able to sit the pre-test or post-test again once they have finished it. Assessments you assign are unaffected.';
  }

  @override
  String gmAllowBody(String name) {
    return 'Learners in “$name” will be able to sit the pre-test or post-test again. The most recent sitting is the one their learning gain is measured from.';
  }

  @override
  String get gmLock => 'Lock';

  @override
  String get gmAllow => 'Allow';

  @override
  String get gmRetakesLocked => 'Test retakes locked.';

  @override
  String get gmRetakesAllowed => 'Test retakes allowed.';

  @override
  String gmCouldNotSave(String error) {
    return 'Could not save: $error';
  }

  @override
  String gmCopied(String code) {
    return 'Copied $code';
  }

  @override
  String gmShareText(String name, String code, String blurb) {
    return 'Join “$name” on FlashLearn PWD with code $code. $blurb';
  }

  @override
  String get gmShareSubject => 'FlashLearn PWD join code';

  @override
  String gmCouldNotShare(String error) {
    return 'Could not share: $error';
  }

  @override
  String gmRenameGroup(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Rename home group',
      'other': 'Rename class',
    });
    return '$_temp0';
  }

  @override
  String get gmSave => 'Save';

  @override
  String gmRenamed(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Home group renamed.',
      'other': 'Class renamed.',
    });
    return '$_temp0';
  }

  @override
  String gmAccessibilitySet(String type) {
    return 'Accessibility set to $type.';
  }

  @override
  String gmCouldNotUpdate(String error) {
    return 'Could not update: $error';
  }

  @override
  String get gmResetTitle => 'Reset join code?';

  @override
  String gmResetBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'A new code will be generated. Children who already joined stay enrolled, but the old code stops working.',
      'other':
          'A new code will be generated. Students who already joined stay enrolled, but the old code stops working.',
    });
    return '$_temp0';
  }

  @override
  String get gmReset => 'Reset';

  @override
  String get gmNewCodeGenerated => 'New code generated.';

  @override
  String gmCouldNotRegenerate(String error) {
    return 'Could not regenerate: $error';
  }

  @override
  String gmDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String gmDeleteBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'All children will be unenrolled. Their profiles and progress stay on their own devices.',
      'other':
          'All students will be unenrolled. Their profiles and progress stay on their own devices.',
    });
    return '$_temp0';
  }

  @override
  String gmCouldNotDelete(String error) {
    return 'Could not delete: $error';
  }

  @override
  String get gmRenameInRoster => 'Rename in roster';

  @override
  String gmDisplayNameIn(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Display name in this home group',
      'other': 'Display name in this class',
    });
    return '$_temp0';
  }

  @override
  String get gmDisplayNameRequired => 'Display name is required';

  @override
  String gmRenameMemberNote(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'This will rename the child in your roster and on their device.',
      'other':
          'This will rename the student in your roster and on their device.',
    });
    return '$_temp0';
  }

  @override
  String gmMemberRenamed(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Child renamed.',
      'other': 'Student renamed.',
    });
    return '$_temp0';
  }

  @override
  String gmUnlockedFor(String name, String duration) {
    return '$name unlocked for $duration.';
  }

  @override
  String gmCouldNotUnlock(String error) {
    return 'Could not unlock: $error';
  }

  @override
  String gmRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String gmRemoveBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'They\'ll be unenrolled from this home group. Their profile and progress are kept on their device.',
      'other':
          'They\'ll be unenrolled from this class. Their profile and progress are kept on their device.',
    });
    return '$_temp0';
  }

  @override
  String get gmRemove => 'Remove';

  @override
  String gmCouldNotRemove(String error) {
    return 'Could not remove: $error';
  }

  @override
  String gmRemoveManyTitle(String audience, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count children?',
      one: 'Remove 1 child?',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Remove $count students?',
      one: 'Remove 1 student?',
    );
    String _temp2 = intl.Intl.selectLogic(audience, {
      'parent': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String gmRemoveManyBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Their profiles and progress are kept on their devices; they just lose this home group linkage.',
      'other':
          'Their profiles and progress are kept on their devices; they just lose this class linkage.',
    });
    return '$_temp0';
  }

  @override
  String gmMemberActions(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Child actions',
      'other': 'Student actions',
    });
    return '$_temp0';
  }

  @override
  String get gmViewProgress => 'View progress';

  @override
  String get gmNotes => 'Notes';

  @override
  String get gmTimeLimits => 'Time limits';

  @override
  String get gmAlarms => 'Alarms';

  @override
  String get gmRoutine => 'Routine';

  @override
  String get gmUnlockScreen => 'Unlock screen';

  @override
  String gmRemoveFrom(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Remove from home group',
      'other': 'Remove from class',
    });
    return '$_temp0';
  }

  @override
  String gmJoined(String date, String ago) {
    return 'Joined $date · $ago';
  }

  @override
  String gmUnlockTitle(String name) {
    return 'Unlock $name';
  }

  @override
  String get gmUnlockBody =>
      'How long should the lock screen stay off? The screen will lock again automatically when this window expires.';

  @override
  String get gm15min => '15 min';

  @override
  String get gm30min => '30 min';

  @override
  String get gm1hour => '1 hour';

  @override
  String gmHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String gmMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get gmJustNow => 'just now';

  @override
  String gmMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String gmHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String gmDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String gmWeeksAgo(int count) {
    return '${count}w ago';
  }

  @override
  String get acpApplies =>
      'Applies to learners who join from now on. Anyone already enrolled keeps their current setup.';

  @override
  String get acpJoinersGet =>
      'Students who join this code get this version of the app automatically — no setup needed on their side.';

  @override
  String get clipFailedSemantics =>
      'This sign could not be loaded. Answer from what you know, or skip the question.';

  @override
  String get clipSemantics =>
      'A sign-language clip. It repeats on its own; double tap to play it again.';

  @override
  String get clipReplay => 'Play the sign again';

  @override
  String get clipFailedTitle => 'This sign would not load';

  @override
  String get clipFailedBody =>
      'Connect to the internet and try again, or answer from what you already know.';

  @override
  String get navGoBack => 'Go back';

  @override
  String get offlineBanner => 'You’re offline — everything still works!';

  @override
  String get homePlayerProfile => 'Player Profile';

  @override
  String get homeMyDay => 'My Day';

  @override
  String get homeMoodCheckIn => 'Mood Check-In';

  @override
  String get homeDailyChallenge => 'Daily Challenge';

  @override
  String get homeAssignments => 'Assignments';

  @override
  String get homePlayAndLearn => 'Play & Learn';

  @override
  String get homeGamesSub => 'Play & learn';

  @override
  String get homeWordsSub => 'Flashcards';

  @override
  String get homeStories => 'Stories';

  @override
  String get homeStoriesSub => 'Read & answer';

  @override
  String get homeFslSub => 'Sign language';

  @override
  String homeToPractice(int count) {
    return '$count to practice';
  }

  @override
  String get homeReviewSub => 'Review words';

  @override
  String get homeProgressSub => 'Your journey';

  @override
  String get homeLearningStudy => 'Learning & Study';

  @override
  String get homeLearningPaths => 'Learning Paths';

  @override
  String get homeGuidedPractice => 'Guided Practice';

  @override
  String get homeHardWords => 'Hard Words';

  @override
  String get homeWhatToStudy => 'What to Study';

  @override
  String get homeAssessmentProgress => 'Assessment & Progress';

  @override
  String get homeLearningGains => 'Learning Gains';

  @override
  String get homeMyPortfolio => 'My Portfolio';

  @override
  String get homeMyGoals => 'My Goals';

  @override
  String get homeHowWasIt => 'How was it?';

  @override
  String get homeCommunication => 'Communication & Language';

  @override
  String get homeFslDictionary => 'FSL Dictionary';

  @override
  String get homeSocial => 'Social & Collaboration';

  @override
  String get homeJoinAClass => 'Join a class';

  @override
  String get homeJoinTheClass => 'Join the class';

  @override
  String get homeLiveClassBody =>
      'Answer live questions for stars and raise your hand for help.';

  @override
  String get homeLiveClassSemantics =>
      'Join the live class activity and raise your hand.';

  @override
  String get homeHaveClassCode => 'Have a class code?';

  @override
  String get homeJoinClassBody =>
      'Join a class to save your progress and let your teacher follow along.';

  @override
  String get homeJoinClassSemantics =>
      'Have a class code? Join a class to save your progress.';

  @override
  String get homePeerCollab => 'Peer Collab';

  @override
  String get homeMyNotes => 'My Notes';

  @override
  String get homeWellbeing => 'Personal & Wellbeing';

  @override
  String get homeStickerAlbum => 'Sticker Album';

  @override
  String get homeMyNotebook => 'My Notebook';

  @override
  String homeStatsSemantics(int streak, int words, int balance, int total) {
    return 'Stats: $streak day streak, $words words learned, $balance stars to spend out of $total earned';
  }

  @override
  String get homeDailyReward => 'Daily Reward';

  @override
  String get homeDailyRewardTitle => 'Daily Reward!';

  @override
  String homeDayNumber(int day) {
    return 'Day $day';
  }

  @override
  String homeDayShort(int day) {
    return 'D$day';
  }

  @override
  String homeYouEarnedStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You earned $count stars.',
      one: 'You earned 1 star.',
    );
    return '$_temp0';
  }

  @override
  String get homeComeBackTomorrow => 'Come back tomorrow for more!';

  @override
  String get homeCollect => 'Collect';

  @override
  String get homeCollectStar => 'Collect! 🌟';

  @override
  String get homeDailyChallengeChip => '🏆 Daily Challenge';

  @override
  String homeDayStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak',
      one: '1 day streak',
    );
    return '$_temp0';
  }

  @override
  String get homeOpenDailyChallenge =>
      'View full daily challenge with calendar and stats';

  @override
  String get homeViewAll => 'View All';

  @override
  String get homeWhatInFilipino => 'What is this in Filipino?';

  @override
  String get homeCorrectBonus => 'Correct! +2 bonus stars ⭐';

  @override
  String homeAnswerIs(String word) {
    return 'The answer is: $word';
  }

  @override
  String get homeChallengeComplete => 'Challenge Complete! ✨';

  @override
  String homeAnswerWas(String word) {
    return 'The answer was: $word';
  }

  @override
  String homeLevelSemantics(int level, String title, int xp, String next) {
    return 'Player Profile. Level $level $title, $xp XP total, $next. Opens your stats, rewards and achievements.';
  }

  @override
  String homeXpToLevel(int xp, int level, String title) {
    return '$xp XP to level $level $title';
  }

  @override
  String get homeMaxLevel => 'max level reached';

  @override
  String childGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get childFriend => 'Friend';

  @override
  String get childWhatToDo => 'What do you want to do today?';

  @override
  String get childMyFeelings => 'My Feelings';

  @override
  String get childSignDictionary => 'Sign Dictionary';

  @override
  String get childPracticeWords => 'Practice Words';

  @override
  String get childMyProgress => 'My Progress';

  @override
  String get childExplore => 'Explore & Create';

  @override
  String get childAdventureMap => 'Adventure Map';

  @override
  String get childPracticeWithMe => 'Practice With Me';

  @override
  String get childBuddy => 'Buddy';

  @override
  String get childFriends => 'Friends';

  @override
  String get childRewards => 'Rewards & Feelings';

  @override
  String get childPlayerCard => 'My Player Card';

  @override
  String get childStickers => 'Stickers';

  @override
  String get childSwitchProfile => 'Switch profile';

  @override
  String childStatsSemantics(int streak, int words, int stars) {
    return 'My day: $streak day streak, $words words learned, $stars stars earned';
  }

  @override
  String get eduRecentStudents => 'Recent Students';

  @override
  String eduStudentStats(int words, int streak, int stars) {
    return '$words words  •  🔥 $streak streak  •  ⭐ $stars';
  }

  @override
  String eduDeckSemantics(String category, int count) {
    return '$category deck, $count cards';
  }

  @override
  String eduDeckCards(int count) {
    return '$count cards';
  }

  @override
  String catCardSemantics(String category, int count, int percent) {
    return '$category flashcards, $count words, $percent percent progress';
  }

  @override
  String catCardWords(int count) {
    return '$count words';
  }

  @override
  String get playerFallbackName => 'Player';

  @override
  String get playerModeNote =>
      'You’re in Player mode. Your fun stays on this device.';

  @override
  String get playerStartLearning => 'Start Learning';

  @override
  String get playerBrowseFlashcards => 'Browse flashcards';

  @override
  String get playerSaveStars => 'Save your stars across devices';

  @override
  String get playerSaveBody =>
      'Join a class or home group to back up your progress and learn with others.';

  @override
  String get playerJoinClass => 'Join class';

  @override
  String get playerJoinGroup => 'Join group';

  @override
  String levelSemantics(int level, String title, int xp, String next) {
    return 'Level $level $title, $xp XP total, $next';
  }

  @override
  String levelXpToShort(int xp, int level, String title) {
    return '$xp XP to Lv.$level $title';
  }

  @override
  String get levelUpTitle => 'LEVEL UP!';

  @override
  String levelReached(int level) {
    return 'You’ve reached Level $level!';
  }

  @override
  String get levelTapAnywhere => 'Tap anywhere to continue';

  @override
  String get deckBrowseTemplates => 'Browse templates';

  @override
  String deckSemantics(String category, int count, int percent) {
    return '$category deck. $count cards. $percent percent complete.';
  }

  @override
  String deckChipSemantics(String label) {
    return '$label custom flashcards';
  }

  @override
  String viewerNofM(int index, int total) {
    return '$index of $total.';
  }

  @override
  String viewerDeleteConfirm(String word) {
    return 'Are you sure you want to delete “$word”? This cannot be undone.';
  }

  @override
  String get viewerShowMe => 'Show Me';

  @override
  String get viewerExamples => 'Examples';

  @override
  String get viewerWriteNote => 'Write a note about this word';

  @override
  String get viewerPauseAuto => 'Pause auto-play';

  @override
  String get viewerStartAuto => 'Start auto-play';

  @override
  String viewerFlippedSemantics(String english, String filipino) {
    return '$english in Filipino is $filipino. Tap to flip back.';
  }

  @override
  String viewerFrontSemantics(String english, String category) {
    return '$english, $category category. Tap to see details.';
  }

  @override
  String viewerButton(String label) {
    return '$label button';
  }

  @override
  String get viewerGazeStarting => 'Starting gaze…';

  @override
  String get viewerGazeLook => 'Look at the screen';

  @override
  String get viewerGazeChoose => 'Look ◀ ▶ to choose · blink to open';

  @override
  String progMasterySemantics(int percent, int mastered, int total) {
    return 'Overall mastery: $percent percent. $mastered out of $total words learned.';
  }

  @override
  String progStarsEarned(int count) {
    return '$count stars earned';
  }

  @override
  String progStarsCollected(int count) {
    return '⭐ $count stars collected!';
  }

  @override
  String progAchievementUnlocked(String title) {
    return '$title achievement, unlocked';
  }

  @override
  String progAchievementLocked(String title) {
    return '$title achievement, locked';
  }

  @override
  String get progJustNow => 'Just now';

  @override
  String get progYesterday => 'Yesterday';

  @override
  String progGameSemantics(
    String game,
    int score,
    int total,
    int percent,
    int stars,
    String when,
  ) {
    return '$game: $score of $total, $percent percent, $stars stars, $when';
  }

  @override
  String progCategoryRowSemantics(
    String category,
    int mastered,
    int total,
    int percent,
  ) {
    return '$category category: $mastered of $total words mastered, $percent percent';
  }

  @override
  String dcExplain(String english, String filipino) {
    return '“$english” is “$filipino” in Filipino.';
  }

  @override
  String get dcTitle => '🎯 Daily Mission';

  @override
  String get dcChip => '✨ Daily Mission';

  @override
  String get dcNoWords => 'No words available for today’s mission yet.';

  @override
  String dcWordNofM(int index, int total) {
    return 'Word $index of $total';
  }

  @override
  String get dcListen => 'Listen to English pronunciation';

  @override
  String get dcFinish => 'Finish Mission';

  @override
  String get dcNextWord => 'Next Word';

  @override
  String get dcCorrect => 'Correct! +1 star ⭐';

  @override
  String get dcNotQuite => 'Not quite!';

  @override
  String get dcPerfect => 'Perfect mission! 🎉';

  @override
  String get dcComplete => 'Mission complete! ✨';

  @override
  String dcYouGot(int correct, int total) {
    return 'You got $correct of $total correct.';
  }

  @override
  String dcYouGotStars(int correct, int total, int stars) {
    return 'You got $correct of $total correct and earned $stars ⭐.';
  }

  @override
  String get dcComeBack => 'Come back tomorrow for a new mission';

  @override
  String get dcTodayDone => 'Today’s mission completed! ✨';

  @override
  String dcFiftySemantics(int remaining) {
    return 'Fifty-fifty hint, removes two wrong answers, $remaining left';
  }

  @override
  String get dcStreakStart => 'Start your streak today!';

  @override
  String dcStreakGoing(int streak) {
    return '$streak day streak — keep going!';
  }

  @override
  String dcStreakAmazing(int streak) {
    return '$streak day streak — amazing!';
  }

  @override
  String dcStreakFire(int streak) {
    return '$streak day streak — on fire!';
  }

  @override
  String dcStreakLegend(int streak) {
    return '$streak day streak — legendary!';
  }

  @override
  String get dcStreakHint => 'Complete the daily mission to extend your streak';

  @override
  String dcRemovedByHint(String text) {
    return '$text, removed by hint';
  }

  @override
  String get dcPrevMonth => 'Previous month';

  @override
  String get dcNextMonth => 'Next month';

  @override
  String get dcCurrentStreak => 'Current Streak';

  @override
  String get dcDaysCompleted => 'Days Completed';

  @override
  String get dcStarsEarned => 'Stars Earned';

  @override
  String get dcBadgesEarned => 'Badges Earned';

  @override
  String get dcBadge3Day => '3-Day Streak';

  @override
  String get dcBadgeWeekly => 'Weekly Warrior';

  @override
  String get dcBadgeMonthly => 'Monthly Master';

  @override
  String get dcBadge10 => '10 Days Done';

  @override
  String get dcBadge50 => '50 Days Done';

  @override
  String get dcBadge100 => 'Century Club';

  @override
  String get fslOfflineSigns => 'Offline signs';

  @override
  String get fslHasSign => 'Has sign';

  @override
  String fslMySigns(int count) {
    return 'My Signs · $count';
  }

  @override
  String fslICanSign(int count) {
    return 'I can sign · $count';
  }

  @override
  String fslWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return '$_temp0';
  }

  @override
  String fslWatchedOf(int watched, int total) {
    return '$watched of $total signs watched';
  }

  @override
  String fslWatchSemantics(String english, String filipino) {
    return '$english, $filipino. Watch the sign.';
  }

  @override
  String fslWatchedSemantics(String english, String filipino) {
    return '$english, $filipino. Already watched. Watch the sign.';
  }

  @override
  String fslNoVideoSemantics(String english, String filipino) {
    return '$english, $filipino. No sign video yet.';
  }

  @override
  String fslRemoveMySigns(String word) {
    return 'Remove $word from My Signs';
  }

  @override
  String fslAddMySigns(String word) {
    return 'Add $word to My Signs';
  }

  @override
  String get lpAdventureMap => 'Adventure Map 🗺️';

  @override
  String get lpPillDone => 'DONE';

  @override
  String get lpPillStart => 'START';

  @override
  String get lpPillEnter => 'ENTER';

  @override
  String get lpPillReplay => 'REPLAY';

  @override
  String get lpWorldMastered => 'You mastered the whole world!';

  @override
  String get lpWorldExplore => 'Explore every region to become a champion';

  @override
  String get lpTitle => 'Learning Paths';

  @override
  String get lpMapTooltip => 'Adventure map';

  @override
  String get lpJourney => 'Your Learning Journey 🗺️';

  @override
  String get lpIntro =>
      'Complete each path to unlock the next one. Master all 12 categories to become a vocabulary champion!';

  @override
  String lpPathsCompleted(int done, int total) {
    return '$done / $total paths completed';
  }

  @override
  String get lpTrailTooltip => 'Adventure trail';

  @override
  String get lpMastered => 'Path Mastered!';

  @override
  String lpCompletedAll(String path) {
    return 'You’ve completed all steps in $path!';
  }

  @override
  String lpVocabulary(String category) {
    return '$category vocabulary';
  }

  @override
  String get lpRetry => 'Retry';

  @override
  String get lpStart => 'Start';

  @override
  String get lpPrevFirst => 'Complete the previous step first';

  @override
  String get lpAdventureDone => 'Adventure complete!';

  @override
  String get lpClimb => 'Climb the trail to master every step';

  @override
  String lpCardSemantics(String path, int done, int total) {
    return '$path learning path. $done of $total steps completed.';
  }

  @override
  String get lpCardLocked => 'Locked. Complete the previous path to unlock.';

  @override
  String get lpNodeCompleted => 'Completed';

  @override
  String get lpNodeCurrent => 'Current';

  @override
  String get lpNodeAvailable => 'Available';

  @override
  String get lpNodeLocked => 'Locked';

  @override
  String srEnglishWord(String word) {
    return 'English word: $word';
  }

  @override
  String srFilipinoTranslation(String word) {
    return 'Filipino translation: $word';
  }

  @override
  String get srGreat => 'Great recall! Keep it up!';

  @override
  String get srKeepPracticing => 'Keep practicing — you’ll get there!';

  @override
  String get hwPractice => 'Practice';

  @override
  String get hwStruggling => 'Struggling';

  @override
  String get hwAttempted => 'Attempted';

  @override
  String get hwEmptyTitle => 'No hard words!';

  @override
  String get hwEmptyBody =>
      'You’re doing great! Keep playing games and words you struggle with will appear here.';

  @override
  String hwCardSemantics(
    String english,
    String filipino,
    int percent,
    int correct,
    int total,
  ) {
    return '$english, $filipino. Accuracy: $percent percent. $correct correct out of $total attempts.';
  }

  @override
  String get joinClassTitle => 'Join a Class';

  @override
  String get joinClassIntro => 'Enter the code your teacher gave you.';

  @override
  String get joinClassCode => 'Class code';

  @override
  String get joinCodeLength => 'Code must be 6 characters';

  @override
  String get joinChecking => 'Checking…';

  @override
  String get joinGroupTitle => 'Join Home Group';

  @override
  String get joinGroupIntro => 'Enter the code your parent or guardian shared.';

  @override
  String get joinGroupCode => 'Home-group code';

  @override
  String get joinGroupTip =>
      'Tip: ask your parent to check their internet connection, or try again in a moment.';

  @override
  String get scTitle => 'Streak Calendar';

  @override
  String get scBestStreak => 'Best Streak';

  @override
  String get scThisMonth => 'This Month';

  @override
  String get scTotalActive => 'Total Active';

  @override
  String scDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get scMilestones => 'Streak Milestones';

  @override
  String calDaySemantics(int day) {
    return 'Day $day';
  }

  @override
  String get calStudied => ', studied';

  @override
  String get calToday => ', today';

  @override
  String get calM3 => '3 Days';

  @override
  String get calW1 => '1 Week';

  @override
  String get calW2 => '2 Weeks';

  @override
  String get calMo1 => '1 Month';

  @override
  String get calMo2 => '2 Months';

  @override
  String get calD100 => '100 Days';

  @override
  String calMilestoneAchieved(String label) {
    return '$label streak milestone, achieved';
  }

  @override
  String calMilestoneNotYet(String label) {
    return '$label streak milestone, not yet achieved';
  }

  @override
  String sdToMilestone(int count, int milestone) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days to $milestone-day milestone',
      one: '1 day to $milestone-day milestone',
    );
    return '$_temp0';
  }

  @override
  String sdBest(int days) {
    return 'Best: $days days';
  }

  @override
  String get sdTierStarting => 'Just Starting';

  @override
  String get sdTierBuilding => 'Building Up';

  @override
  String get sdTierFire => 'On Fire!';

  @override
  String get sdTierBlazing => 'Blazing';

  @override
  String get sdTierChampion => 'Streak Champion';

  @override
  String certCategoryTitle(String category) {
    return '$category Mastery';
  }

  @override
  String certWordsLearned(int learned, int total) {
    return '$learned/$total words learned';
  }

  @override
  String certStreakTitle(int days) {
    return '$days-Day Streak';
  }

  @override
  String get certStreakSub => 'Consistent study dedication';

  @override
  String get certExcellence => 'Learning Excellence';

  @override
  String certWordsStars(int words, int stars) {
    return '$words words, $stars stars';
  }

  @override
  String get certTitle => 'My Certificates';

  @override
  String get certEmpty => 'No certificates yet';

  @override
  String get certEmptyHint =>
      'Keep learning to earn certificates!\nMaster a category (80%+), build a 7-day streak,\nor learn 50+ words.';

  @override
  String certSemantics(String title, String subtitle) {
    return 'Certificate: $title. $subtitle. Tap to preview and share.';
  }

  @override
  String certFileName(String title) {
    return 'Certificate - $title';
  }

  @override
  String certFailed(String error) {
    return 'Failed to generate certificate: $error';
  }

  @override
  String huntMore(int count) {
    return '+$count more';
  }

  @override
  String get goalsTitle => 'My Goals';

  @override
  String get goalsActive => 'Active Goals';

  @override
  String get goalsNone => 'No goals yet';

  @override
  String get goalsNoneHint => 'Set a learning goal to stay motivated!';

  @override
  String goalsCompleted(int count) {
    return 'Completed ($count)';
  }

  @override
  String goalsExpired(int count) {
    return 'Expired ($count)';
  }

  @override
  String get goalsNew => 'New Goal';

  @override
  String get goalsTracker => 'Goal Tracker';

  @override
  String goalsSummary(int active, int completed) {
    return '$active active · $completed completed';
  }

  @override
  String get goalsTypeWords => 'Words Learned';

  @override
  String get goalsTypeGames => 'Games Completed';

  @override
  String get goalsTypeMastery => 'Category Mastery';

  @override
  String get goalsTypeStreak => 'Streak Days';

  @override
  String get goalsTypeStars => 'Stars Earned';

  @override
  String get goalsExpiredShort => 'Expired';

  @override
  String get goalsDueToday => 'Due today';

  @override
  String get goalsDueTomorrow => 'Due tomorrow';

  @override
  String goalsDueIn(int days) {
    return 'Due in $days days';
  }

  @override
  String get goalsACategory => 'a category';

  @override
  String goalsLearnN(int n) {
    return 'Learn $n words';
  }

  @override
  String goalsCompleteN(int n) {
    return 'Complete $n games';
  }

  @override
  String goalsMasteryN(int n, String category) {
    return 'Reach $n% mastery in $category';
  }

  @override
  String goalsStreakN(int n) {
    return 'Maintain a $n-day streak';
  }

  @override
  String goalsStarsN(int n) {
    return 'Earn $n stars';
  }

  @override
  String get goalsSetNew => 'Set a New Goal';

  @override
  String get goalsWhat => 'What do you want to achieve?';

  @override
  String get goalsWhichCategory => 'Which category?';

  @override
  String get goalsTarget => 'Target';

  @override
  String get goalsDeadline => 'Set a deadline';

  @override
  String goalsDaysShort(int days) {
    return '${days}d';
  }

  @override
  String get goalsCreate => 'Create Goal';

  @override
  String get lgNoProfile => 'No Profile Selected';

  @override
  String get lgNoProfileBody => 'Select a profile to view learning gain data.';

  @override
  String get lgGoBack => 'Go Back';

  @override
  String get lgEducatorTitle => 'Learning gains belong to your learners';

  @override
  String get lgEducatorBody =>
      'You assign the pre-test and post-test; the gain is theirs. Open Assessment Tracking to see who has sat which half.';

  @override
  String get lgOpenTracking => 'Open tracking';

  @override
  String get lgTakeTest => 'Take Test';

  @override
  String get lgNoData => 'No Learning Data Yet';

  @override
  String get lgNoDataBody =>
      'Take a Pre-Test first to establish your baseline, then take a Post-Test after learning to see your improvement!';

  @override
  String get lgTakePre => 'Take Pre-Test';

  @override
  String get lgReadyPost => 'Ready for your Post-Test?';

  @override
  String get lgReadyPostBody =>
      'You’ve completed your Pre-Test! Take the Post-Test to see how much you’ve learned.';

  @override
  String get lgTakePost => 'Take Post-Test';

  @override
  String get lgAverageScores => 'Average Scores';

  @override
  String get lgRecent => 'Recent Assessments';

  @override
  String lgTotal(int count) {
    return '$count total';
  }

  @override
  String lgFocusOn(String category) {
    return 'Focus on $category';
  }

  @override
  String lgFocusBody(int percent) {
    return 'Your weakest category at $percent%. Try reviewing flashcards and playing games in this category.';
  }

  @override
  String get lgPracticeMore => 'Practice More';

  @override
  String get lgPracticeMoreBody =>
      'Try reviewing flashcards and playing games before retaking the post-test.';

  @override
  String get lgExcellent => 'Excellent Performance!';

  @override
  String get lgExcellentBody =>
      'You’re doing amazing! Try harder difficulty levels to keep challenging yourself.';

  @override
  String lgBestAt(String category) {
    return 'Best at $category';
  }

  @override
  String lgBestBody(int percent) {
    return 'Your strongest category at $percent%! Great job!';
  }

  @override
  String lgMostImproved(String category) {
    return 'Most Improved: $category';
  }

  @override
  String lgImprovedBy(int percent) {
    return 'Improved by $percent% — keep it up!';
  }

  @override
  String get lgRecommendations => 'Recommendations';

  @override
  String get lgNoCategoryData => 'No category data available';

  @override
  String get lgScoreByCategory => 'Score by Category';

  @override
  String get lgPreShort => 'Pre';

  @override
  String get lgPostShort => 'Post';

  @override
  String get lgGreatImprovement => 'Great Improvement!';

  @override
  String get lgKeepPracticing => 'Keep Practicing!';

  @override
  String get lgCategoryBreakdown => 'Category Breakdown';

  @override
  String get lgTrend => 'Score Trend Over Time';

  @override
  String get lgPreTests => 'Pre-Tests';

  @override
  String get lgPostTests => 'Post-Tests';

  @override
  String get scPortfolio => 'My Portfolio';

  @override
  String get scSharePortfolio => 'Share Portfolio';

  @override
  String get scAutoCurate => 'Auto-curate portfolio';

  @override
  String scItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get scAddNote => 'Add Note';

  @override
  String scAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count new items to your portfolio!',
      one: 'Added 1 new item to your portfolio!',
    );
    return '$_temp0';
  }

  @override
  String get scUpToDate => 'Portfolio is already up to date!';

  @override
  String get scRemoveTitle => 'Remove from Portfolio?';

  @override
  String scRemoveBody(String title) {
    return 'Remove “$title” from your showcase? You can always add it back later.';
  }

  @override
  String get scAddANote => 'Add a Note';

  @override
  String get scNoteTitle => 'Title';

  @override
  String get scNoteTitleHint => 'e.g., “My Favorite Game”';

  @override
  String get scNote => 'Note';

  @override
  String get scNoteHint => 'Write about your learning journey...';

  @override
  String get scAdd => 'Add';

  @override
  String get scTypeAchievement => 'Achievement';

  @override
  String get scTypeHighScore => 'High Score';

  @override
  String get scTypeMastery => 'Category Mastery';

  @override
  String get scTypePath => 'Learning Path';

  @override
  String get scTypeStreak => 'Streak Milestone';

  @override
  String get scTypeAssessment => 'Assessment';

  @override
  String get scTypeNote => 'Note';

  @override
  String get scPinned => 'Pinned.';

  @override
  String get scUnpin => 'Unpin';

  @override
  String get scPinTop => 'Pin to top';

  @override
  String get scRemoveFrom => 'Remove from showcase';

  @override
  String get scShowcaseBest => 'Showcase your best moments!';

  @override
  String get scStatItems => 'Items';

  @override
  String get scStatPinned => 'Pinned';

  @override
  String get scStatAwards => 'Awards';

  @override
  String get scEmptyTitle => 'Your Portfolio is Empty';

  @override
  String get scEmptyBody =>
      'Start by auto-curating your best moments or add items manually as you learn!';

  @override
  String get scEmptyAction => 'Auto-Curate My Portfolio';

  @override
  String get scPdfTitle => 'Portfolio Summary PDF';

  @override
  String scItemsFor(int count, String name) {
    return '$count items • $name';
  }

  @override
  String get scShareHint =>
      'Share with your teacher or parent to show your progress!';

  @override
  String wodLearned(String emoji) {
    return 'Word learned! $emoji';
  }

  @override
  String get tbPrev => 'Prev';

  @override
  String get tbSpeak => 'Speak';

  @override
  String get tbAdd => 'Add';

  @override
  String get tbTooLong =>
      'That is as long as a sentence can be. Speak it or clear it.';

  @override
  String get tbUnpinned => 'Phrase unpinned.';

  @override
  String get tbSaved => 'Phrase saved.';

  @override
  String get tbChangeReason => 'to change this board';

  @override
  String get tbTitle => 'Talk Board';

  @override
  String get tbEditBoard => 'Edit my board';

  @override
  String get tbBuildBoard => 'Build my board';

  @override
  String get tbToEnglish => 'Switch to English';

  @override
  String get tbToFilipino => 'Switch to Filipino';

  @override
  String tbSavedPhrase(String phrase) {
    return 'Saved phrase: $phrase. Tap to say it.';
  }

  @override
  String tbRecentPhrase(String phrase) {
    return 'Recent phrase: $phrase. Tap to say it.';
  }

  @override
  String get tbHint => 'Tap tiles below to build a sentence';

  @override
  String get tbSpeakSentence => 'Speak sentence';

  @override
  String get tbUnsave => 'Remove this sentence from saved phrases';

  @override
  String get tbSave => 'Save this sentence';

  @override
  String get tbRemoveLast => 'Remove last tile';

  @override
  String get tbClearAll => 'Clear all tiles';

  @override
  String tbCategory(String label) {
    return '$label category';
  }

  @override
  String tbTileSemantics(String spoken) {
    return '$spoken. Tap to add, long press to hear.';
  }

  @override
  String agTooMany(String time) {
    return 'Too many tries. Wait $time.';
  }

  @override
  String get agEnterPin => 'Enter the 4-digit PIN.';

  @override
  String get agPinMismatch =>
      'That PIN did not match. Ask your parent or teacher.';

  @override
  String get agNewQuestion => 'Not quite. Here is a new question.';

  @override
  String agMinutes(int n) {
    return '$n min';
  }

  @override
  String agSeconds(int n) {
    return '$n s';
  }

  @override
  String get agTitle => 'Ask an adult';

  @override
  String agPinNeeded(String reason) {
    return 'A parent or teacher PIN is needed $reason.';
  }

  @override
  String agAnswerThis(String reason) {
    return 'Answer this $reason.';
  }

  @override
  String agTimes(int a, int b) {
    return 'What is $a times $b?';
  }

  @override
  String get agAnswer => 'Answer';

  @override
  String agEndEarly(String title) {
    return 'to end $title early';
  }

  @override
  String get lbTitle => 'Leaderboard';

  @override
  String get lbNoRankings => 'No rankings yet';

  @override
  String get lbNoRankingsBody =>
      'Complete activities and games to appear on the leaderboard!';

  @override
  String get lbHidden => 'Hidden from members — enable in Leaderboard settings';

  @override
  String get lbSeason => 'Season active — ranking recent activity';

  @override
  String get lbJoinTitle => 'Join to see the leaderboard';

  @override
  String get lbJoinChild =>
      'Join your family home group to see how you rank with everyone!';

  @override
  String get lbJoinStudent =>
      'Join your class to see how you rank with your classmates!';

  @override
  String get lbJoinGroup => 'Join a Home Group';

  @override
  String get lbNotEnabled => 'Leaderboard not enabled yet';

  @override
  String get lbNotEnabledBody =>
      'Your teacher or parent hasn’t turned on the leaderboard for your group yet. Check back soon!';

  @override
  String get lbNoClasses => 'No classes yet';

  @override
  String get lbNoGroups => 'No home groups yet';

  @override
  String get lbNoClassesBody =>
      'Create a class and invite students to start a leaderboard.';

  @override
  String get lbNoGroupsBody =>
      'Create a home group and invite your children to start a leaderboard.';

  @override
  String get lbManageClasses => 'Manage Classes';

  @override
  String get lbManageGroups => 'Manage Home Groups';

  @override
  String get lbError => 'Couldn’t load the leaderboard';

  @override
  String get lbErrorBody =>
      'Check your connection and try again. Your last-known rankings show when you’re back online.';

  @override
  String get lbSort => 'Sort';

  @override
  String get lbPeriod => 'Period';

  @override
  String get lbYou => 'You';

  @override
  String get lbSortStars => 'Stars';

  @override
  String get lbSortWords => 'Words Learned';

  @override
  String get lbSortStreak => 'Streak';

  @override
  String get lbSortOverall => 'Overall';

  @override
  String get lbAllTime => 'All Time';

  @override
  String get lbThisWeek => 'This Week';

  @override
  String get lbThisMonth => 'This Month';

  @override
  String lbWords(int count) {
    return '$count words';
  }

  @override
  String lbDays(int count) {
    return '$count days';
  }

  @override
  String lbPts(int count) {
    return '$count pts';
  }

  @override
  String setProfileSemantics(String name, String role) {
    return 'Profile: $name, $role. Tap switch to change profile.';
  }

  @override
  String get setNoProfile => 'No profile';

  @override
  String get setUnknownRole => 'unknown role';

  @override
  String get dbExportCsv => 'Export data as CSV spreadsheet';

  @override
  String get dbExportPdf => 'Export progress report as PDF';

  @override
  String get dbExportResearch => 'Export research data for thesis analysis';

  @override
  String get dbBadges => 'Badges';

  @override
  String get dbOverallMastery => 'Overall Mastery';

  @override
  String get dbCategoryBreakdown => 'Category Breakdown';

  @override
  String get dbInsights => 'Insights & Recommendations';

  @override
  String get dbNoData =>
      'No learning data yet. Once the student starts playing games and reviewing flashcards, insights will appear here.';

  @override
  String get dbNeedsPractice => 'Needs Practice';

  @override
  String dbFocusOn(String category) {
    return 'Focus on $category flashcards and games.';
  }

  @override
  String get dbDoingGreat => 'Doing Great';

  @override
  String get dbKeepItUp =>
      'Keep it up! Consider trying harder difficulty levels.';

  @override
  String get dbEngagement => 'Engagement';

  @override
  String dbStreakActive(int streak) {
    return '$streak-day learning streak active!';
  }

  @override
  String get dbNoStreak => 'No active streak. Try daily practice.';

  @override
  String get dbConsistent =>
      'Great consistency! The student is building a habit.';

  @override
  String get dbEncourage =>
      'Encourage the student to play at least once a day.';

  @override
  String get dbStudyTime => 'Study Time';

  @override
  String get dbRecentActivity => 'Recent Activity';

  @override
  String get dbNoGames =>
      'No game activity yet. Encourage the student to play games!';

  @override
  String get dbStudentProgress => 'Student Progress';

  @override
  String get dbMastery => 'Mastery';

  @override
  String get dbRecentAvg => 'Recent Game Avg';

  @override
  String get dbDailyStreak => 'Daily Challenge Streak';

  @override
  String dbDays(int count) {
    return '$count days';
  }

  @override
  String get dbTotalTime => 'Total Time';

  @override
  String get dbAvgSession => 'Avg Session';

  @override
  String get dbSessions => 'Sessions';

  @override
  String get dbLast7Days => 'Last 7 Days';

  @override
  String get sfSearch => 'Search students...';

  @override
  String get sfGrade => 'Grade';

  @override
  String get sfSection => 'Section';

  @override
  String sfResults(int count) {
    return '$count results';
  }

  @override
  String get sfClearAll => 'Clear all';

  @override
  String get sfTags => 'Tags';

  @override
  String sfTagsN(int count) {
    return 'Tags ($count)';
  }

  @override
  String get sfKinder => 'Kinder';

  @override
  String sfGradeN(int n) {
    return 'Grade $n';
  }

  @override
  String get sfHighSchool => 'High School';

  @override
  String get sfCollege => 'College';

  @override
  String get sfActAll => 'All';

  @override
  String get sfActToday => 'Active Today';

  @override
  String get sfActWeek => 'Active This Week';

  @override
  String get sfActInactive => 'Inactive 7+ Days';

  @override
  String get sfSortName => 'Name';

  @override
  String get sfSortGrade => 'Grade Level';

  @override
  String get sfSortWords => 'Words Learned';

  @override
  String get sfSortStreak => 'Streak';

  @override
  String get sfSortStars => 'Stars';

  @override
  String get sfSortLastActive => 'Last Active';

  @override
  String get sfSortAccuracy => 'Accuracy';

  @override
  String get sfSortJoined => 'Date Joined';

  @override
  String get msClearFilters => 'Clear filters';

  @override
  String msCardSemantics(String name, int words, int stars, int streak) {
    return '$name, $words words learned, $stars stars, $streak day streak';
  }

  @override
  String get cdExportCsv => 'Export CSV report';

  @override
  String get cdRefresh => 'Refresh';

  @override
  String cdLoadError(String error) {
    return 'Could not load dashboard:\n$error';
  }

  @override
  String cdLastUpdated(String time) {
    return 'Last updated: $time';
  }

  @override
  String get cdNoStudents => 'No student profiles found';

  @override
  String get cdNoStudentsBody =>
      'Create student profiles to see them here.\nEach student will appear with their progress.';

  @override
  String get splDeleteTitle => 'Delete Profile?';

  @override
  String splDeleteBody(String name) {
    return 'Are you sure you want to delete “$name”? This will permanently remove all progress data for this student.';
  }

  @override
  String get splDeleteEducator =>
      ' Any classes they own will no longer have a teacher managing them.';

  @override
  String splDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get splManageProfiles => 'Manage Profiles';

  @override
  String get splStudentProfiles => 'Student Profiles';

  @override
  String get splImportExport => 'Import / Export';

  @override
  String splLoadError(String error) {
    return 'Could not load students:\n$error';
  }

  @override
  String get splNoOthers => 'No other profiles on this device';

  @override
  String get splNoStudents => 'No student profiles yet';

  @override
  String get splNoStudentsBody =>
      'Students appear here after joining your class with a code.';

  @override
  String get splShareCode => 'Share Class Code';

  @override
  String splAge(int age) {
    return '$age yrs old';
  }

  @override
  String get splNoAge => 'No age or level set';

  @override
  String storyLocked(String title) {
    return '$title — locked';
  }

  @override
  String storyTapToRead(String title) {
    return '$title — tap to read';
  }

  @override
  String get storyReadSuffix => ', read';

  @override
  String get storyRead => 'Read';

  @override
  String get fiPictureClue => 'Picture clue';

  @override
  String get fiTapCartoon => 'Tap to see the cartoon picture.';

  @override
  String get fiTapReal => 'Tap to see the real picture.';

  @override
  String fiRealOf(String word) {
    return 'Real picture of $word.';
  }

  @override
  String fiRealLifeOf(String word) {
    return 'Real-life picture of $word';
  }

  @override
  String fiCartoonOf(String word) {
    return 'Cartoon picture of $word';
  }

  @override
  String get mascotBuddy => 'Mascot buddy';

  @override
  String profileAgeYrs(int age) {
    return '$age yrs';
  }

  @override
  String scpScored(int score, int total, int stars) {
    return 'Scored $score/$total and earned $stars stars!';
  }

  @override
  String scpMastered(String category) {
    return '$category Mastered!';
  }

  @override
  String scpMasteryDesc(int percent, String category) {
    return 'Achieved $percent% mastery in $category';
  }

  @override
  String scpStreakTitle(int days) {
    return '$days-Day Streak!';
  }

  @override
  String scpStreakDesc(int days) {
    return 'Maintained a learning streak of $days days in a row!';
  }

  @override
  String scpAssessDesc(int score, int total, String test) {
    return 'Scored $score/$total on $test';
  }

  @override
  String get lvlBeginner => 'Beginner';

  @override
  String get lvlElementary => 'Elementary';

  @override
  String get lvlIntermediate => 'Intermediate';

  @override
  String get lvlAdvanced => 'Advanced';

  @override
  String get lvlBeginnerDesc =>
      'Just starting out — simple words and short sessions.';

  @override
  String get lvlElementaryDesc =>
      'Building vocabulary — slightly longer lessons.';

  @override
  String get lvlIntermediateDesc =>
      'Comfortable with most lessons — full-length games.';

  @override
  String get lvlAdvancedDesc =>
      'Ready for harder challenges and complex stories.';

  @override
  String get signNotSet => 'Not set';

  @override
  String get signLearning => 'Learning';

  @override
  String get signCanSign => 'I can sign this';

  @override
  String get signUnreviewed => 'Not checked yet';

  @override
  String get signConfirmed => 'Confirmed';

  @override
  String get signNeedsPractice => 'Needs practice';

  @override
  String get lockSumBanner => 'Advance warning banner';

  @override
  String lockSumChimes(int count) {
    return 'Alarm chime ×$count';
  }

  @override
  String get lockSumOneChime => 'One gentle alarm chime';

  @override
  String get lockSumSpokenTwice => 'Spoken message (said twice)';

  @override
  String get lockSumSpoken => 'Spoken message';

  @override
  String get lockSumPicture => 'Picture of who to hand it to';

  @override
  String get lockSumFslFirst => 'FSL video first (tap to flip to the picture)';

  @override
  String get lockSumFslBack => 'FSL video on the back of the picture';

  @override
  String get lockSumAlarmFirst =>
      'Alarm animation first (tap to flip to the picture)';

  @override
  String get lockSumAlarmBack =>
      'Alarm animation on the back of the picture (tap to flip)';

  @override
  String get lockSumVisual => 'Pulsing visual alert';

  @override
  String get lockSumVibration => 'Vibration cue';

  @override
  String get lockSumReader => 'Screen-reader announcement';

  @override
  String get lockSumSimple => 'Short, simple wording';

  @override
  String get lockSumSwitch => 'Large “Switch account” button';

  @override
  String get lockWhyVisual =>
      'Shorter day and frequent breaks — audio-led learning takes longer per item and reduces eye strain.';

  @override
  String get lockWhyHearing =>
      'Standard session length; the hand-off is delivered as an FSL video and a large caption instead of speech.';

  @override
  String get lockWhyMotor =>
      'Shorter day and frequent breaks — sustained tapping and holding is tiring. All lock buttons are extra large.';

  @override
  String get lockWhyCognitive =>
      'Short, predictable sessions with a fixed daily window. The lock uses one chime and one short sentence.';

  @override
  String get lockWhyMultiple =>
      'The most supportive settings of every profile combined: short sessions, simple wording, the spoken message said twice, and large buttons.';

  @override
  String get lockWhyNone =>
      'Standard session length with an alarm and a spoken hand-off message.';

  @override
  String get tlTitle => 'Time limits';

  @override
  String tlTitleFor(String name) {
    return 'Time limits — $name';
  }

  @override
  String get tlSave => 'Save';

  @override
  String tlLoadError(String error) {
    return 'Could not load: $error';
  }

  @override
  String get tlDaily => 'Daily time limit';

  @override
  String tlMinPerDay(int minutes) {
    return '$minutes min per day';
  }

  @override
  String get tlNoLimit => 'No limit';

  @override
  String tlMinutesPerDay(int minutes) {
    return '$minutes minutes per day';
  }

  @override
  String get tlSchedule => 'Allowed schedule';

  @override
  String get tlRestrict => 'Restrict by time of day';

  @override
  String get tlAnyTime => 'Any time';

  @override
  String get tlStart => 'Allowed start';

  @override
  String get tlEnd => 'Allowed end';

  @override
  String get tlWhenUp => 'When time is up';

  @override
  String get tlWhenUpBody =>
      'The child hears an alarm, then a message telling them who to hand the device to.';

  @override
  String get tlWarn => 'Warn before the lock';

  @override
  String tlWarnOn(int minutes) {
    return 'A banner $minutes minutes before, so they can finish what they are doing.';
  }

  @override
  String get tlWarnOff => 'The lock screen will be the first warning.';

  @override
  String tlNotice(int minutes) {
    return '$minutes minutes of notice';
  }

  @override
  String get tlAlarm => 'Play an alarm sound';

  @override
  String get tlAlarmBody =>
      'Also alerts the adult in the room, so it stays on for learners who are deaf or hard of hearing.';

  @override
  String get tlSpeak => 'Speak the message out loud';

  @override
  String get tlSpeakOn => 'Spoken after the alarm.';

  @override
  String get tlSpeakOff =>
      'This learner’s profile does not use speech — the message is shown as a large caption instead.';

  @override
  String get tlLockIntro =>
      'When a limit is reached, the child sees a “Time’s up” lock screen that requires your PIN to dismiss. They keep all progress, and a “Switch account” button lets someone else use the device without unlocking this profile.';

  @override
  String tlApplied(String profile) {
    return 'Applied the recommended settings for $profile. Tap Save to confirm.';
  }

  @override
  String tlSaveError(String error) {
    return 'Could not save: $error';
  }

  @override
  String get tlNotCached =>
      'This learner’s profile isn’t cached on this device yet, so the accessibility-specific guidance is hidden. Every setting below still applies.';

  @override
  String get tlAtLock => 'At lock time this learner gets:';

  @override
  String tlUseRecommended(int minutes) {
    return 'Use recommended ($minutes min/day)';
  }

  @override
  String get tlCallYou => 'What should the child call you?';

  @override
  String get tlCallHint => 'e.g. Teacher Ana, Dad, Lola';

  @override
  String get tlBlankDefault => 'Leave blank to use the default.';

  @override
  String tlBlankAvatar(String honorific) {
    return 'Leave blank to use “$honorific”, taken from the avatar on your profile.';
  }

  @override
  String get tlWillHear => 'The child will hear';

  @override
  String get tlFslUrl => 'Sign-language (FSL) video URL';

  @override
  String get tlFslBlank =>
      'Leave blank to use the built-in FSL clip for whoever the child hands the device to (Ma’am / Sir / Mommy / Daddy). Shown on the lock screen for learners who are deaf or hard of hearing; downloaded once, then plays offline.';

  @override
  String get tlFslSet =>
      'Shown on the lock screen for learners who are deaf or hard of hearing. The clip is downloaded once and then plays offline.';

  @override
  String get tlFslUnused =>
      'This learner’s profile does not show the FSL video, so this is stored but unused unless their profile changes.';

  @override
  String get tlNoClip =>
      'No clip set. The lock screen will show the written message only until a URL is added here.';

  @override
  String get tlEveryDay => 'Schedule applies every day';

  @override
  String get tlSelectedDays => 'Schedule applies only on selected days';

  @override
  String tuTooMany(String time) {
    return 'Too many attempts. Try again in $time.';
  }

  @override
  String tuActiveProfile(String name) {
    return 'Active profile: $name';
  }

  @override
  String get tuEnterPin => 'Enter a 4-digit PIN.';

  @override
  String get tuWrongPin => 'Incorrect PIN. Ask your parent or teacher.';

  @override
  String get tuUseRecovery => 'Use recovery code';

  @override
  String get tuRecoveryBody =>
      'Enter the recovery code printed when this profile’s PIN was set. Codes are case-insensitive.';

  @override
  String get tuRecoveryCode => 'Recovery code';

  @override
  String get tuRecoveryMismatch => 'Recovery code did not match.';

  @override
  String get tuSignVideo => 'sign-language video';

  @override
  String get tuAlarm => 'alarm';

  @override
  String get tuSignVideoTap => 'Sign-language video. Tap to see the picture.';

  @override
  String get tuAlarmTap => 'Alarm clock animation. Tap to see the picture.';

  @override
  String tuTapToSeeClip(String caption, String clip) {
    return '$caption Tap to see the $clip.';
  }

  @override
  String get tuTapPicture => 'Tap to see the picture';

  @override
  String tuTapClip(String clip) {
    return 'Tap to see the $clip';
  }

  @override
  String get tuFullScreen => 'Watch in full screen';

  @override
  String get tuEnterAdultPin => 'Enter parent / teacher PIN to continue';

  @override
  String get tuForgotPin => 'Forgot PIN? Use recovery code';

  @override
  String get tuSwitchNote =>
      'Switching accounts does not unlock this profile — it stays locked until an adult enters the PIN.';

  @override
  String get tuNoAdult =>
      'No parent or teacher is linked to this device yet, so the lock cannot be dismissed here. Ask the device owner to sign in once.';

  @override
  String get alNew => 'New alarm';

  @override
  String alLoadError(String error) {
    return 'Could not load: $error';
  }

  @override
  String get alNone => 'No alarms set yet.\nTap “New alarm” to create one.';

  @override
  String get alEveryDay => 'Every day';

  @override
  String get alNotifyOnly => 'Notify only';

  @override
  String get alLockScreen => 'Lock screen';

  @override
  String get alEndSession => 'End session';

  @override
  String alSaveError(String error) {
    return 'Could not save: $error';
  }

  @override
  String get alEdit => 'Edit alarm';

  @override
  String get alLabelHint => 'e.g. Bedtime, Homework time';

  @override
  String get alTime => 'Time';

  @override
  String get alRepeat => 'Repeat on';

  @override
  String get alNoDays => 'No days selected → fires every day';

  @override
  String get alWhen => 'When alarm fires';

  @override
  String get alLockPin => 'Lock screen (parent PIN to unlock)';

  @override
  String get alEndHome => 'End session and return home';

  @override
  String get scTitleCheck => 'Sign Check';

  @override
  String scNoClaims(String name) {
    return '$name has not marked any signs yet. Claims appear here after they use “I can sign this” in the dictionary or finish a Sign It round.';
  }

  @override
  String scHowTo(String name) {
    return 'Watch the reference clip, ask $name to sign it, then record what you saw. Confirming is what earns them the sign.';
  }

  @override
  String scToCheck(int count) {
    return '$count to check';
  }

  @override
  String get scOnlyUnchecked => 'Only ones I haven’t checked';

  @override
  String get scNothingLeft => 'Nothing left to check. Nice work.';

  @override
  String get scSaysCan => 'Says: “I can sign this”';

  @override
  String get scSaysNotYet => 'Says: “Not yet”';

  @override
  String get scWatchRef => 'Watch the reference sign';

  @override
  String get scConfirm => 'Confirm';

  @override
  String get cdsCustomize => 'Customize progress';

  @override
  String get cdsActiveToday => 'Active today';

  @override
  String cdsLastActive(String when) {
    return 'Last active $when';
  }

  @override
  String cdsStreak(int days) {
    return '$days day streak';
  }

  @override
  String get cdsRecentGames => 'Recent Games';

  @override
  String cdsSignCheck(int count) {
    return 'Sign Check · $count to review';
  }

  @override
  String get cdsDailyRoutine => 'Daily Routine';

  @override
  String get cdsFullDashboard => 'View Full Dashboard';

  @override
  String get cdsToday => 'today';

  @override
  String get cdsYesterday => 'yesterday';

  @override
  String cdsDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String cdsWeeksAgo(int count) {
    return '$count weeks ago';
  }

  @override
  String get cdsQuickStats => 'Quick Stats';

  @override
  String cdsOfTotal(int total) {
    return 'of $total total';
  }

  @override
  String get cdsAvailable => 'available';

  @override
  String get cdsSignsWatched => 'Signs Watched';

  @override
  String cdsOfSigns(int total) {
    return 'of $total signs';
  }

  @override
  String get cdsFslClips => 'FSL clips';

  @override
  String get cdsGreat => 'Great!';

  @override
  String get cdsGoodProgress => 'Good progress';

  @override
  String get cdsCategories => 'Categories';

  @override
  String get cdsMasteredPct => 'mastered (≥80%)';

  @override
  String get cdsThisWeek => 'this week';

  @override
  String get cdsGamesPlayed => 'Games Played';

  @override
  String cdsSessions(int count) {
    return '$count sessions';
  }

  @override
  String get cdsHuntFinds => 'Word Hunt Finds';

  @override
  String cdsHuntStreak(int days) {
    return '$days-day streak';
  }

  @override
  String get cdsWithCamera => 'with the camera';

  @override
  String get cdsStrengths => 'Strengths & Areas to Improve';

  @override
  String cdsStrongest(String category) {
    return 'Strongest: $category';
  }

  @override
  String cdsPctMastery(int percent) {
    return '$percent% mastery';
  }

  @override
  String cdsNeedsWork(String category) {
    return 'Needs work: $category';
  }

  @override
  String cdsPctMasteryMore(int percent) {
    return '$percent% mastery — encourage more practice here';
  }

  @override
  String cdsUnexplored(int count) {
    return '$count categories unexplored';
  }

  @override
  String get cdsJustStarting => 'Just getting started!';

  @override
  String cdsEncourage(String name) {
    return 'Encourage $name to try some flashcards or games.';
  }

  @override
  String get pcSaved => 'Parental controls saved! ✅';

  @override
  String get pcTitle => 'Parental Controls';

  @override
  String get pcIntro =>
      'Set restrictions to manage how students use the app. These controls apply to all student profiles on this device.';

  @override
  String get pcDaily => 'Daily Time Limit';

  @override
  String get pcEnableLimit => 'Enable Time Limit';

  @override
  String pcMinutesPerDay(int minutes) {
    return '$minutes minutes per day';
  }

  @override
  String get pcNoRestriction => 'No time restriction';

  @override
  String pcMin(int minutes) {
    return '$minutes min';
  }

  @override
  String get pc15 => '15 min';

  @override
  String get pc3h => '3 hours';

  @override
  String get pcSchedule => 'Usage Schedule';

  @override
  String get pcEnableSchedule => 'Enable Schedule';

  @override
  String pcAllowed(String start, String end) {
    return 'Allowed: $start – $end';
  }

  @override
  String get pcNoTimeOfDay => 'No time-of-day restriction';

  @override
  String get pcStart => 'Start';

  @override
  String get pcEnd => 'End';

  @override
  String get pcFeatures => 'Feature Restrictions';

  @override
  String get pcBlockShop => 'Block Star Shop';

  @override
  String get pcBlockShopSub => 'Prevent students from spending stars';

  @override
  String get pcBlockMulti => 'Block Multiplayer';

  @override
  String get pcBlockMultiSub => 'Disable multiplayer quiz mode';

  @override
  String get pcBlockMsg => 'Block Messaging';

  @override
  String get pcBlockMsgSub => 'Disable in-app messaging';

  @override
  String get pcBlockedGames => 'Blocked Games';

  @override
  String get pcBlockedGamesSub => 'Select games to hide from students';

  @override
  String get pcBlockedCats => 'Blocked Categories';

  @override
  String get pcBlockedCatsSub =>
      'Select categories to hide from flashcards & games';

  @override
  String get pcReset => 'Reset All Controls';

  @override
  String get pcVeryShort => 'Very Short';

  @override
  String get pcShort => 'Short';

  @override
  String get pcModerate => 'Moderate';

  @override
  String get pcStandard => 'Standard';

  @override
  String get pcExtended => 'Extended';

  @override
  String get lgcTitle => 'Learning Gain';

  @override
  String get woStudyMinutes => 'Study minutes';

  @override
  String get apAdaptive => 'Adaptive Difficulty';

  @override
  String get apDyslexia => 'Dyslexia-friendly';

  @override
  String get apFslVideos => 'FSL Videos';

  @override
  String get apFontSize => 'Font Size';

  @override
  String get apGaze => 'Gaze Control';

  @override
  String get apHighContrast => 'High Contrast';

  @override
  String get apReducedMotion => 'Reduced Motion';

  @override
  String get apSoundEffects => 'Sound Effects';

  @override
  String get apTts => 'Text-to-Speech';

  @override
  String get apVoiceNav => 'Voice Navigation';

  @override
  String get apOn => 'On';

  @override
  String get apOff => 'Off';

  @override
  String get apPrioritized => 'Prioritized';

  @override
  String get apXl130 => 'Extra Large (130%)';

  @override
  String get apXl140 => 'Extra Large (140%)';

  @override
  String get apLarge120 => 'Large (120%)';

  @override
  String get apHandsFree => 'On (hands-free)';

  @override
  String get apSlow => 'On (Slow)';

  @override
  String get apVerySlow => 'On (Very Slow)';

  @override
  String obWelcome(String name) {
    return 'Welcome, $name! 🎉';
  }

  @override
  String get obWelcomeLearner =>
      'You’re all set up and ready to start learning! Let’s take a quick tour of everything you can do.';

  @override
  String get obWelcomeTeacher =>
      'Your account is ready! Let’s show you the key features you’ll use to guide your students.';

  @override
  String get obWelcomeParent =>
      'Your account is ready! Let’s show you the key features you’ll use to support your child’s learning.';

  @override
  String get obFlashTitle => 'Learn with Flashcards 📚';

  @override
  String get obFlashLearner =>
      'Browse vocabulary categories like Animals, Colors, Numbers, and more. Each card has pictures, Filipino Sign Language, and text-to-speech to help you learn.';

  @override
  String get obFlashAdult =>
      'Students learn vocabulary through interactive flashcards with pictures, FSL support, and text-to-speech across multiple categories.';

  @override
  String get obGamesTitle => 'Play Fun Games 🎮';

  @override
  String get obGamesLearner =>
      'Practice what you’ve learned with Word Match, Spelling Bee, Memory Match, Jigsaw Puzzle, and more! Earn stars ⭐ for every game you play.';

  @override
  String get obGamesAdult =>
      'Students reinforce vocabulary through 10+ educational games with adjustable difficulty and category filters.';

  @override
  String get obProgressTitle => 'Track Your Progress ⭐';

  @override
  String get obProgressLearner =>
      'See your streak, stars, and words learned on your dashboard. Unlock achievement badges and spend stars in the Star Shop for cool avatars and themes!';

  @override
  String get obProgressAdult =>
      'Monitor learning progress with detailed dashboards showing mastery rates, streaks, category breakdowns, and exportable reports.';

  @override
  String get obAccessTitle => 'Made for Everyone ♿';

  @override
  String get obAccessBody =>
      'FlashLearn PWD is designed for learners with disabilities. Adjust text size, contrast, animations, and audio in Settings to match your needs. Presets are available for visual, hearing, motor, and cognitive accessibility.';

  @override
  String get obReadyTitle => 'You’re Ready! 🚀';

  @override
  String get obReadyLearner =>
      'Tap a category on the home screen to learn your first words, or jump into a game to start earning stars. Have fun!';

  @override
  String get obReadyTeacher =>
      'Explore the home screen to discover all available features. Use the dashboard to monitor student progress.';

  @override
  String get obReadyParent =>
      'Explore the home screen to discover all available features. Sit with your child and learn together!';

  @override
  String get asOptimize =>
      'We’ll optimize the app for your needs.\nSelect the option that best describes you:';

  @override
  String get asNoSpecial =>
      'No special settings needed!\nYou’re all set with the defaults.';

  @override
  String get asDyslexiaSub =>
      'Cream background, Lexend font, wider letter spacing — easier reading for everyone.';

  @override
  String get asMotionSub =>
      'Less animation, instant page transitions — good for motion sensitivity or older devices.';

  @override
  String get asChangeLater => 'You can change these anytime in Settings ⚙️';

  @override
  String get asAllSet => 'You’re All Set! 🎉';

  @override
  String asOptimizedFor(String type) {
    return 'Your app has been optimized for\n$type.';
  }

  @override
  String get asStandardReady => 'Standard settings are ready to go.';

  @override
  String get asAdjustLater =>
      'You can adjust all settings anytime\nfrom the Settings page.';

  @override
  String get asSaveFinish => 'Save & Finish';

  @override
  String get asComfort => 'Comfort tweaks you can try later';

  @override
  String get mrClass => 'You’ve been removed from your class.';

  @override
  String get mrGroup => 'You’ve been removed from your home group.';

  @override
  String mrFrom(String name) {
    return 'You’ve been removed from $name.';
  }

  @override
  String get mrSafeClass =>
      'Your progress is safe on this device. You can join a different class using a new code.';

  @override
  String get mrSafeGroup =>
      'Your progress is safe on this device. You can join a different home group using a new code.';

  @override
  String get mrReturning => 'Returning to setup automatically…';

  @override
  String get spdCategoryProgress => 'Category Progress';

  @override
  String get spdRecentScores => 'Recent Game Scores';

  @override
  String get spdDetails => 'Profile Details';

  @override
  String get spdPinProtected => 'PIN Protected';

  @override
  String spdMastered(int mastered, int total) {
    return '$mastered of $total categories mastered';
  }

  @override
  String get spdBirthDate => 'Birth Date';

  @override
  String get spdEditProfile => 'Edit Profile';

  @override
  String get psAddNew => 'Add New Profile';

  @override
  String get psPinLength => 'PIN must be exactly 4 digits';

  @override
  String get epEnterName => 'Please enter a name';

  @override
  String get epPinMismatch => 'PINs do not match';

  @override
  String get epUpdated => 'Profile updated! ✅';

  @override
  String get epApplyPresetsTitle => 'Apply Accessibility Presets?';

  @override
  String epApplyPresetsBody(String type) {
    return 'Your disability type changed to “$type”. Would you like to auto-configure accessibility settings?';
  }

  @override
  String get epKeepCurrent => 'Keep Current';

  @override
  String get epApplyPresets => 'Apply Presets';

  @override
  String get epNoProfileBody => 'Please select a profile to edit.';

  @override
  String get epTapAvatar => 'Tap below to change avatar';

  @override
  String epAvatarSemantics(String name) {
    return '$name avatar';
  }

  @override
  String get epSelectedSuffix => ', selected';

  @override
  String get epPremium => 'Premium Avatars';

  @override
  String get epEarnStars => 'Earn stars in games to unlock special avatars!';

  @override
  String epCosts(String emoji, String name, int cost) {
    return '$emoji $name costs $cost ⭐ — visit the Star Shop!';
  }

  @override
  String epPremiumSemantics(String name) {
    return '$name premium avatar';
  }

  @override
  String get epOwnedSuffix => ', owned';

  @override
  String epLockedSuffix(int cost) {
    return ', locked, $cost stars';
  }

  @override
  String get epName => 'Name';

  @override
  String get epEnterYourName => 'Enter your name';

  @override
  String get epLearningLevel => 'Learning Level';

  @override
  String get epSetByTeacher => 'Set by your teacher';

  @override
  String get epGradeLevel => 'Grade Level';

  @override
  String get epSelectGrade => 'Select grade level';

  @override
  String get epNotSet => 'Not set';

  @override
  String get epSection => 'Section / Class';

  @override
  String get epSectionHint => 'e.g., Section A, Rose';

  @override
  String epAge(int age) {
    return '(Age: $age)';
  }

  @override
  String get epTags => 'Tags';

  @override
  String get epTagsHelp => 'Add custom labels to organize students';

  @override
  String get epAddTag => 'Add a tag...';

  @override
  String get epInterests => 'Learning Interests';

  @override
  String get epInterestsHelp => 'Pick favourite topics to personalise lessons';

  @override
  String get epAccessProfile => 'Accessibility Profile';

  @override
  String get epAccessHelp =>
      'Changing this will offer to auto-configure accessibility settings';

  @override
  String get epPinProtection => 'PIN Protection';

  @override
  String get epIsProtected => 'This profile is PIN-protected';

  @override
  String get epAddPin => 'Add a 4-digit PIN to protect this profile';

  @override
  String get epRemovePin => 'Remove PIN';

  @override
  String get epPinRemovedOnSave => 'PIN will be removed when you save';

  @override
  String get epEnablePin => 'Enable PIN lock';

  @override
  String get epEnterPin => 'Enter 4-digit PIN';

  @override
  String get epConfirmPin => 'Confirm PIN';

  @override
  String get epRole => 'Role';

  @override
  String get epCannotChange => 'Cannot be changed';

  @override
  String get setVoiceTour => 'Voice Guide & Tour';

  @override
  String get setVoiceTourSub => 'Hear how each screen works';

  @override
  String get setTutorialsReset => 'Tutorials will appear again on each screen!';

  @override
  String get setPinRemoved => 'PIN removed';

  @override
  String get setPinSet => 'PIN set successfully!';

  @override
  String get setEnterPin => 'Enter PIN';

  @override
  String get setNoDataLeaves => 'No data leaves this device';

  @override
  String get brTitle => 'Backup & Restore';

  @override
  String get brKeepSafe => 'Keep Your Data Safe';

  @override
  String get brIntro =>
      'Back up all profiles, progress, achievements, shop purchases, settings, and custom flashcards. Restore on any device.';

  @override
  String brLastBackup(String when) {
    return 'Last backup: $when';
  }

  @override
  String get brCreate => 'Create Backup';

  @override
  String get brCreateSub => 'Export all app data as a .flashlearn file';

  @override
  String get brCreating => 'Creating…';

  @override
  String get brBackUpNow => 'Back Up Now';

  @override
  String get brRestoreFrom => 'Restore from Backup';

  @override
  String get brRestoreSub => 'Import a .flashlearn file to restore all data';

  @override
  String get brRestoring => 'Restoring…';

  @override
  String get brRestore => 'Restore';

  @override
  String get brIncluded => 'WHAT’S INCLUDED';

  @override
  String get brProfiles => 'All student profiles';

  @override
  String get brProgress => 'Progress & achievements';

  @override
  String get brStars => 'Stars & shop purchases';

  @override
  String get brCustomCards => 'Custom flashcards';

  @override
  String get brSettings => 'App settings & accessibility';

  @override
  String get brAnalytics => 'Session analytics';

  @override
  String get brSpaced => 'Spaced repetition data';

  @override
  String get brWarning =>
      'Restoring a backup will replace all current data. Consider creating a backup first before restoring.';

  @override
  String get brCreated => 'Backup created successfully!';

  @override
  String get brCreateFailed => 'Failed to create backup.';

  @override
  String get brRestoreTitle => 'Restore Backup?';

  @override
  String get brRestoreBody =>
      'This will replace ALL current data with the backup data. This action cannot be undone.\n\nMake sure to create a backup of your current data first.';

  @override
  String ieExported(String name) {
    return '$name exported successfully';
  }

  @override
  String ieExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String ieImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get ieImportTitle => 'Import Student Profile';

  @override
  String get ieImportSub =>
      'Restore a student profile from a JSON file exported by another device.';

  @override
  String get ieImporting => 'Importing…';

  @override
  String get ieChooseFile => 'Choose File';

  @override
  String get ieExportStudent => 'Export a Student';

  @override
  String get ieExportSub =>
      'Tap a student below to export their profile, progress, and achievements as a JSON file.';

  @override
  String get ieNoStudents => 'No student profiles to export';

  @override
  String get ieExport => 'Export';

  @override
  String get baEnterEmail => 'Enter an email';

  @override
  String get baValidEmail => 'Enter a valid email address';

  @override
  String get baPwLength => 'Password must be at least 8 characters';

  @override
  String get baPwMismatch => 'Passwords do not match';

  @override
  String get baEmailInUse =>
      'That email already has an account. Choose “I already have an account” instead.';

  @override
  String get baWeakPw =>
      'That password is too easy to guess. Use 8+ characters.';

  @override
  String get baBadEmail => 'That doesn’t look like a valid email address.';

  @override
  String get baWrongCreds => 'Email or password is incorrect.';

  @override
  String get baDisabled => 'That account has been disabled.';

  @override
  String get baOffline =>
      'No internet connection. Try again when you’re online.';

  @override
  String get baTooMany => 'Too many tries. Wait a minute and try again.';

  @override
  String get baLinkedElsewhere =>
      'This device is already linked to a different account.';

  @override
  String baSignInFailed(String code) {
    return 'Sign-in failed ($code).';
  }

  @override
  String baLinked(String email) {
    return 'Account linked! Your data is now backed up to $email.';
  }

  @override
  String get baSignedInNone =>
      'Signed in. No backup data was found for this account.';

  @override
  String baSignedInRestored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Signed in. Restored $count profiles from the cloud.',
      one: 'Signed in. Restored 1 profile from the cloud.',
    );
    return '$_temp0';
  }

  @override
  String get baEnterEmailFirst =>
      'Enter your email above before requesting a reset.';

  @override
  String baResetSent(String email) {
    return 'Password reset email sent to $email.';
  }

  @override
  String get baSignOutTitle => 'Sign out of linked account?';

  @override
  String get baSignOutBody =>
      'The app will keep working offline, but new cloud writes will use a fresh anonymous session. Your local profiles stay on this device — they are not deleted.';

  @override
  String get baSignOut => 'Sign out';

  @override
  String get baSignedOut => 'Signed out.';

  @override
  String get baTitle => 'Backup & Link Account';

  @override
  String get baActive => 'Backup is active';

  @override
  String get baNone => 'No backup yet';

  @override
  String baLinkedTo(String email) {
    return 'Linked to $email. Sign in with this email on a new device to restore your profiles and progress.';
  }

  @override
  String get baUnknownEmail => '(unknown email)';

  @override
  String get baLocalOnly =>
      'Your data is stored on this device only. Link an email below so you can recover everything if the device is lost or reset.';

  @override
  String get baSignInRestore => 'Sign in to restore';

  @override
  String get baCreateBackup => 'Create a backup';

  @override
  String get baUseOther =>
      'Use the email and password you set on your other device.';

  @override
  String get baPickCreds =>
      'Pick an email and password to back up this device. No verification email required.';

  @override
  String get baEmail => 'Email';

  @override
  String get baPassword => 'Password';

  @override
  String get baHidePw => 'Hide password';

  @override
  String get baShowPw => 'Show password';

  @override
  String get baConfirmPw => 'Confirm password';

  @override
  String get baSignInRestoreBtn => 'Sign in & restore';

  @override
  String get baLinkDevice => 'Link this device';

  @override
  String get baCreateOne => 'Don’t have an account yet? Create one';

  @override
  String get baHaveOne => 'I already have an account — sign in';

  @override
  String get baForgot => 'Forgot password? Send reset email';

  @override
  String get baSendReset => 'Send password reset email';

  @override
  String get baSignOutLinked => 'Sign out of linked account';

  @override
  String get rcNotFound =>
      'We couldn’t find a profile for that code. Double-check each letter and try again.';

  @override
  String get rcAlreadyUsed =>
      'This recovery code has already been used. Generate a new one from the original device, or contact your teacher.';

  @override
  String get rcInvalid =>
      'That code doesn’t look right. Check for letters that look similar (e.g. zero / O).';

  @override
  String get rcDenied =>
      'The cloud refused this request. Ask your teacher to check the app’s cloud setup.';

  @override
  String get rcCollision => 'Could not make a unique code. Please try again.';

  @override
  String get rcNetwork =>
      'Could not reach the cloud. Check the internet connection and try again.';

  @override
  String get rcUnknown => 'Something went wrong. Please try again.';

  @override
  String rcWelcomeBack(String name) {
    return 'Welcome back, $name!';
  }

  @override
  String rcRestoreFailed(String error) {
    return 'Something went wrong while restoring your profile: $error';
  }

  @override
  String get rcTitle => 'Recover Profile';

  @override
  String get rcFormatHint => 'Letters only, any case. Dashes are optional.';

  @override
  String get rcRestoreMine => 'Restore my profile';

  @override
  String get rcNoCloud =>
      'Cloud sync is not connected on this device. Connect to the internet to recover a profile.';

  @override
  String get rcLookingUp => 'Looking up code…';

  @override
  String get rcVerifying => 'Verifying…';

  @override
  String get rcRestoring => 'Restoring profile…';

  @override
  String get rcLoadingProgress => 'Loading progress…';

  @override
  String get rcDone => 'Done!';

  @override
  String get rcWelcome => 'Welcome back!';

  @override
  String get rcIntro =>
      'Enter the recovery code you saved from your previous device to restore your profile and progress here.';

  @override
  String get rcEnterCode => 'Please enter your recovery code';

  @override
  String get rcCodeFormat =>
      'Codes are 10 letters/numbers (with optional dashes)';

  @override
  String get rcCreated => 'Recovery code created. Save it somewhere safe.';

  @override
  String get rcBackupTitle => 'Backup & Recovery';

  @override
  String get rcSelectProfile =>
      'Select a profile first to view its recovery code.';

  @override
  String rcExplain(String name) {
    return 'A recovery code lets $name restore their profile and progress on a new device if this one is lost or replaced.';
  }

  @override
  String get rcNoneYet => 'No recovery code yet';

  @override
  String get rcGenerateNow =>
      'Generate a one-time code now. Write it down or take a photo — you’ll need it to restore this profile on another device.';

  @override
  String get rcGenerating => 'Generating…';

  @override
  String get rcGenerate => 'Generate recovery code';

  @override
  String get rcCodeCreated => 'Code created!';

  @override
  String get rcYourCode => 'Your recovery code';

  @override
  String get rcCopied => 'Recovery code copied to clipboard';

  @override
  String get rcCopy => 'Copy to clipboard';

  @override
  String get rcSaveWarning =>
      'Save this code somewhere safe. If you lose it AND lose access to this device, the profile cannot be recovered.';

  @override
  String get rcRegenerating => 'Regenerating…';

  @override
  String get rcNewCode => 'Generate a new code';

  @override
  String get rcRevokes => 'Regenerating revokes the previous code.';

  @override
  String get jcNoClass =>
      'No class found with that code. Check the code with your teacher.';

  @override
  String get jcNoGroup =>
      'No home group found with that code. Check the code with your parent.';

  @override
  String get jcNetwork =>
      'Couldn’t check the code. Make sure the tablet is online, then try again.';

  @override
  String get jcUnknown =>
      'Something went wrong while joining. Please try again.';

  @override
  String get csxAuthTitle => 'Cloud sign-in not ready';

  @override
  String get csxAuthBody =>
      'The app couldn’t sign in anonymously, so Firestore is rejecting writes. Common fixes:\n\n1) Firebase Console → Authentication → Sign-in method → enable Anonymous.\n2) Deploy the security rules: `firebase deploy --only firestore:rules`.\n3) Connect the device to the internet for one launch so the sign-in can complete.';

  @override
  String get csxLockedTitle => 'Profile locked to another device';

  @override
  String get csxLockedBody =>
      'This profile was created on a different device (or before the app was reinstalled). Tap “Reset for this device” to claim it for this anonymous sign-in, or sign in on the original device.';

  @override
  String get csxSetupTitle => 'Cloud setup incomplete';

  @override
  String get csxSetupBody =>
      'Firestore rejected the request. Run through these steps once, then try again:\n\n1) Firebase Console → Authentication → Sign-in method → enable Anonymous.\n2) From the project root: `firebase deploy --only firestore:rules`.\n3) Pull the device online for at least one launch.';

  @override
  String get csxOffline => 'Offline';

  @override
  String get csxOfflineBody =>
      'You’re seeing your last saved data. New changes will sync when this device is back online.';

  @override
  String get csxWrong => 'Something went wrong';

  @override
  String get csxWrongBody =>
      'Try again. If this keeps happening, expand the details below and share them with support.';

  @override
  String get csxDetails => 'Details';

  @override
  String get csxRetrying => 'Retrying…';

  @override
  String get csxReset => 'Profile reset for this device.';

  @override
  String csxResetFailed(String error) {
    return 'Reset failed: $error';
  }

  @override
  String get csxResetButton => 'Reset for this device';

  @override
  String get ssCloudSync => 'Cloud Sync';

  @override
  String get ssNotConfigured => 'Not configured';

  @override
  String get ssIssue => 'Sync Issue';

  @override
  String ssFailedRetry(int count) {
    return '$count failed — tap to retry';
  }

  @override
  String get ssPending => 'Pending Sync';

  @override
  String get ssAllUploaded => 'All data uploaded';

  @override
  String get ssFailed => 'Sync Failed';

  @override
  String get ssTapRetry => 'Tap to retry';

  @override
  String get ssWhenOnline => 'Will sync when online';

  @override
  String get ssTapSync => 'Tap to sync now';

  @override
  String get crbOff => 'Cloud sync OFF — local-only mode.';

  @override
  String crbBody(String reason) {
    return 'Codes you create here can’t be joined from other devices. $reason';
  }

  @override
  String ssUploadingN(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Uploading $count changes',
      one: 'Uploading 1 change',
    );
    return '$_temp0';
  }

  @override
  String get ssUploading => 'Uploading data';

  @override
  String get ssJustNow => 'Synced just now';

  @override
  String ssMinutes(int count) {
    return 'Synced ${count}m ago';
  }

  @override
  String ssHours(int count) {
    return 'Synced ${count}h ago';
  }

  @override
  String ssDays(int count) {
    return 'Synced ${count}d ago';
  }

  @override
  String get vgTitle => 'Voice-Guided Mode';

  @override
  String get vgEnabled => 'Voice navigation is now enabled.';

  @override
  String get vgSpeed => 'Voice Speed';

  @override
  String get vgSlow => 'Slow';

  @override
  String get vgFast => 'Fast';

  @override
  String get vgLanguage => 'Voice Language';

  @override
  String get vgSpeaking => 'Speaking...';

  @override
  String get vgTest => 'Test Voice';

  @override
  String get vgTour => 'Guided Tour';

  @override
  String get vgTourIntro =>
      'Take a step-by-step tour of the entire app with voice narration for each screen.';

  @override
  String get vgStartTour => 'Start Tour';

  @override
  String get vgPrevious => 'Previous';

  @override
  String get vgFinish => 'Finish Tour';

  @override
  String get vgQuick => 'Quick Screen Announcements';

  @override
  String get vgQuickIntro =>
      'Tap any button below to hear a description of that screen.';

  @override
  String get vgVerySlow => 'Very Slow';

  @override
  String get vgNormal => 'Normal';

  @override
  String get vgVeryFast => 'Very Fast';

  @override
  String get vgTourDone => 'Guided tour complete. You’re all set!';

  @override
  String get vgNav => 'Voice Navigation';

  @override
  String get vgActive => 'Active — Screen changes and buttons are announced';

  @override
  String get vgTapEnable => 'Tap the switch to enable voice announcements';

  @override
  String get vgChipHome => '🏠 Home';

  @override
  String get vgChipCards => '📚 Flashcards';

  @override
  String get vgChipGames => '🎮 Games';

  @override
  String get vgChipProgress => '📊 Progress';

  @override
  String get vgChipStories => '📖 Stories';

  @override
  String get vgChipShop => '⭐ Shop';

  @override
  String get vgChipSettings => '⚙️ Settings';

  @override
  String get gpTitle => '🎮  Game Controller';

  @override
  String get gpPractise => 'Practise the controller';

  @override
  String get gpPractiseButtons => 'Practise the buttons';

  @override
  String get gpPractiseHelp =>
      'Press anything and hear what it does. Nothing in the app moves while practising.';

  @override
  String get gpEnable => 'Enable controller';

  @override
  String get gpEnabledOn => 'A paired controller can drive the app';

  @override
  String get gpEnabledOff => 'Off — touch only';

  @override
  String get gpSpeech => 'Speech';

  @override
  String get gpSay => 'Say what is happening';

  @override
  String get gpSayHelp =>
      'Announces each section, each item and every question. Leave this on for a learner who cannot see the screen.';

  @override
  String get gpSpeed => 'Speech speed';

  @override
  String get gpSpeedHelp =>
      'Experienced listeners often want this faster than it starts. It sets the speaking speed for the whole app, so stories and vocabulary read at the same pace.';

  @override
  String get gpReadItem => 'Read each item';

  @override
  String get gpReadItemHelp =>
      'Says the name and position — “Games, 3 of 8” — as the cursor lands on it.';

  @override
  String get gpMoving => 'Moving between sections';

  @override
  String get gpAsk => 'Ask before switching';

  @override
  String get gpAskHelp =>
      'Left and right ask “Do you want to go to the Cards section?” — A for yes, B for no. Turn off to switch straight away.';

  @override
  String get gpComfort => 'Comfort';

  @override
  String get gpVibrate => 'Vibrate on each press';

  @override
  String get gpVibrateHelp =>
      'A silent confirmation that the press registered, even while a previous sentence is still finishing.';

  @override
  String get gpDedupe => 'Ignore repeat presses within';

  @override
  String gpMs(int ms) {
    return '$ms ms';
  }

  @override
  String get gpDedupeHelp =>
      'Raise this for a learner whose grip produces extra presses. Lower it if deliberate quick presses are being missed.';

  @override
  String get gpHold => 'Hold to keep moving';

  @override
  String get gpHoldHelp =>
      'Holding up or down keeps stepping through items, instead of one press per step. Opening, going back and switching section never repeat.';

  @override
  String get gpWait => 'Wait before repeating';

  @override
  String get gpWaitHelp =>
      'Long enough that an ordinary press never starts a repeat.';

  @override
  String get gpRepeat => 'Repeat every';

  @override
  String get gpRepeatHelp =>
      'Slow enough that each item is still announced in full.';

  @override
  String get gpSwap => 'Swap A and B';

  @override
  String get gpSwapHelp =>
      'Only if “yes” and “no” come out backwards — some controllers label the bottom button B rather than A.';

  @override
  String get gpGuide => 'Button guide';

  @override
  String get gpGuideHelp =>
      'The learner can hear this list at any time by pressing Select.';

  @override
  String get gpVerySlow => 'Very slow';

  @override
  String get gpVeryFast => 'Very fast';

  @override
  String gpConnectedTo(String name) {
    return 'Controller connected: $name';
  }

  @override
  String get gpNoController => 'No controller connected';

  @override
  String get gpConnected => 'Controller connected';

  @override
  String get gpNone => 'No controller';

  @override
  String get gpPair =>
      'Pair one in Android Settings → Bluetooth, then come back here.';

  @override
  String get gppTitle => '🎮  Practice';

  @override
  String get gppNoController =>
      'No controller connected. Switch it on and it will start responding here.';

  @override
  String get gppPressAny => 'Press any button on the controller';

  @override
  String get gppPressAnyShort => 'Press any button';

  @override
  String get gppWillTell =>
      'I will tell you what it does. Nothing else will happen.';

  @override
  String gppTried(int tried, int total) {
    return 'Tried $tried of $total';
  }

  @override
  String get gppStartOver => 'Start over';

  @override
  String get gppLeave => 'Press L1 twice to leave.';

  @override
  String get hfReasonSign =>
      'This activity records you signing, so it needs the camera to itself. Head control will pause while it is open.';

  @override
  String get hfVoiceHint => 'You can still say “go back” to leave at any time.';

  @override
  String hfUsesCamera(String activity) {
    return '$activity uses the camera';
  }

  @override
  String get hfNoVoice =>
      'To leave, use the Back button at the top — or turn on Voice commands in Settings → Accessibility → Gaze Control first, so you can say “go back”.';

  @override
  String get hfNotNow => 'Not now';

  @override
  String get hfOpenAnyway => 'Open anyway';

  @override
  String get hfHuntVoice =>
      'You can say “take a photo” to shoot, a word’s name to open it, and “go back” to leave.';

  @override
  String get gzPrevious => '⬅  Previous';

  @override
  String get gzNext => 'Next  ➡';

  @override
  String get gzHear => '🔊  Hear Word';

  @override
  String get gzFlip => '🔄  Flip Card';

  @override
  String get gzSelect => '✓  Select (blink)';

  @override
  String get gzPreview => '👁️  Gaze Control (Preview)';

  @override
  String get gzHearWord => 'Hear Word';

  @override
  String get gzFlipCard => 'Flip Card';

  @override
  String get gzLook => '😊  Look at the screen';

  @override
  String get gzNoCamera =>
      'Gaze Control needs a front camera, which this device doesn’t have.';

  @override
  String get gzPermission =>
      'Camera access is needed to track your head. Enable it in Settings, then try again.';

  @override
  String get gzCameraFailed => 'The camera couldn’t start. Please try again.';

  @override
  String get gzTryAgain => 'Try Again';

  @override
  String get gzBlink => '😉  Blink to choose';

  @override
  String get gzStatusNoCamera => 'Gaze: no front camera';

  @override
  String get gzStatusPermission => 'Gaze: camera permission needed';

  @override
  String get gzUnavailable => 'Gaze unavailable';

  @override
  String get gzsTitle => '👁️  Gaze Control';

  @override
  String get gzsEnable => 'Enable Gaze Control';

  @override
  String get gzsOn => 'Head movements & blinks can drive the app';

  @override
  String get gzsTryNow => 'Try gaze control now';

  @override
  String get gzsTryIt => 'Try it now';

  @override
  String get gzsHandsFree => 'Hands-free navigation';

  @override
  String get gzsNavOnly => 'Bottom nav only';

  @override
  String get gzsNavOnlySub =>
      'The head D-pad moves the highlight across the bottom tabs. Blink (or look up) to open.';

  @override
  String get gzsNavTiles => 'Bottom nav + feature tiles';

  @override
  String get gzsNavTilesSub =>
      'Also reach the feature tiles on Home, Cards, Games, Stories & Progress: look ◀ ▶ across a row, ▲ ▼ between rows, and blink to open.';

  @override
  String get gzsVoice => 'Voice';

  @override
  String get gzsVoiceCommands => 'Voice commands';

  @override
  String get gzsVoiceSub =>
      'Say “left”, “right”, “up”, “down” to move the highlight, “select” to open it — or a button’s name (“next”, “flip”, “games”), “scroll down”, “go back”.';

  @override
  String get gzsTuning => 'Tuning';

  @override
  String get gzsSensitivity => 'Sensitivity';

  @override
  String get gzsSensitivityHelp => 'Higher = a smaller head movement selects.';

  @override
  String get gzsHold => 'Hold time';

  @override
  String gzsSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String get gzsHoldHelp => 'How long to look at a button before it activates.';

  @override
  String get gzsBlink => 'Blink to confirm';

  @override
  String get gzsBlinkSub => 'A long, deliberate blink acts as “select”';

  @override
  String get gzsScanning => 'Scanning (no head movement)';

  @override
  String get gzsScanMode => 'Scanning mode';

  @override
  String get gzsScanSub =>
      'Buttons highlight one by one — blink to pick. For learners who can’t move their head.';

  @override
  String get gzsScanSpeed => 'Scan speed';

  @override
  String get gzsScanHelp =>
      'How long each button stays highlighted before moving on.';

  @override
  String get gzsCalibration => 'Device calibration';

  @override
  String get gzsMirror => 'Mirror left / right';

  @override
  String get gzsMirrorSub => 'Turn off if Left and Right feel swapped';

  @override
  String get gzsInvert => 'Invert up / down';

  @override
  String get gzsInvertSub => 'Turn on if Up and Down feel swapped';

  @override
  String get gzsLowest => 'Lowest';

  @override
  String get gzsLow => 'Low';

  @override
  String get gzsBalanced => 'Balanced';

  @override
  String get gzsHigh => 'High';

  @override
  String get gzsHighest => 'Highest';

  @override
  String get gzsIntro =>
      'Control the app hands-free. Move your head toward a button and hold briefly to choose it, or blink to confirm. Everything runs on this device — no internet needed.';

  @override
  String get gzsScopeHint =>
      'Choose how far the hands-free D-pad reaches. Either way it stays off until “Enable Gaze Control” is on, and touch always works.';

  @override
  String get gzsCalibrationHint =>
      'These fix a device where the directions feel reversed. Tap “Try it now” above, and if a movement picks the wrong side, toggle the matching switch.';

  @override
  String get lsNoProfile => 'No profile selected';

  @override
  String get lsLiveSession => 'Live Session';

  @override
  String get lsJoinClass => 'Join the Class';

  @override
  String get lsHostTitle => 'Host live games & quizzes from TV Cast';

  @override
  String get lsHostBody =>
      'Open TV Cast, start casting, then choose “Live Activity” to build questions, set star scoring, and see raised hands and the scoreboard on the TV.';

  @override
  String get lsOpenCast => 'Open TV Cast';

  @override
  String get lsJoinFirst => 'Join a class first';

  @override
  String get lsChildJoin =>
      'Ask your parent for the home-group code, then join from Settings to take part in live activities.';

  @override
  String get lsStudentJoin =>
      'You are not in a classroom yet. Tap “Join a class” to take part in live activities.';

  @override
  String get lsConnect => 'Connect to the internet';

  @override
  String get lsConnectBody =>
      'Live activities need a connection so you can join your class in real time. Connect to Wi-Fi or mobile data and reopen this screen.';

  @override
  String get lsNoActivity =>
      'No live activity yet. Your teacher will start one soon.';

  @override
  String get lsGetReady => 'Get ready! Waiting for the next question…';

  @override
  String get lsHandRaised => 'Hand raised. Your teacher can see your name.';

  @override
  String get lsHandLowered => 'Hand lowered.';

  @override
  String lsCorrectStars(int count) {
    return 'Correct! You earned $count stars.';
  }

  @override
  String get lsCorrect => 'Correct!';

  @override
  String get lsGoodTry => 'Good try. Wait for the next question.';

  @override
  String lsFirstCorrect(int count) {
    return 'First correct answer! Bonus $count stars.';
  }

  @override
  String get lsGotIt => 'I got it! ✋';

  @override
  String get lsNotYet => 'Not yet';

  @override
  String get lsGotItShort => 'Got it!';

  @override
  String lsQuestionNofM(int number, int total) {
    return 'Question $number of $total';
  }

  @override
  String get lsWatchSign =>
      'Watch the sign on the TV, then choose the matching word.';

  @override
  String get lsWhichPicture => 'Which word matches the picture?';

  @override
  String get lsCorrectAnswer => ', correct answer';

  @override
  String get lsYourWrong => ', your answer, incorrect';

  @override
  String lsCorrectStarsEmoji(int count) {
    return 'Correct! You earned $count ⭐';
  }

  @override
  String get lsCorrectEmoji => 'Correct! 🎉';

  @override
  String get lsKeepGoing => 'Good try! Keep going 💪';

  @override
  String get lsLowerYourHand => 'Lower your hand';

  @override
  String get lsRaiseForHelp => 'Raise your hand to ask your teacher for help';

  @override
  String get lsLowerHand => 'Lower hand';

  @override
  String get lsRaiseHand => 'Raise hand';

  @override
  String get mpTaken => 'This game already has another player.';

  @override
  String get mpNeedsInternet => 'Online play needs an internet connection.';

  @override
  String get mpWarming => 'Sign-in is still warming up. Try again in a moment.';

  @override
  String get mpSlow => 'Network is slow. Check your connection and try again.';

  @override
  String get mpDenied =>
      'Couldn’t reach the game service. If this keeps happening, ask your teacher to redeploy the app rules.';

  @override
  String get mpStartFailed => 'Couldn’t start the game. Try again in a moment.';

  @override
  String get mpStart => 'Start';

  @override
  String get mpChoose => 'Choose';

  @override
  String get mpDone => 'Done';

  @override
  String get mpNotEnough =>
      'Not enough words to play yet — add a few flashcards first!';

  @override
  String get mpNoProfile => 'No active profile.';

  @override
  String mpPlayWith(String name) {
    return 'Play with $name';
  }

  @override
  String get mqTitle => 'Multiplayer Quiz';

  @override
  String get mqStart => 'Start Battle!';

  @override
  String mqTurn(String name) {
    return '$name’s Turn!';
  }

  @override
  String mqRound(int round, int total) {
    return 'Round $round of $total';
  }

  @override
  String get mqTapStart => 'Tap anywhere to start!';

  @override
  String get mqDraw => 'It’s a Draw!';

  @override
  String get mqNotEnough => 'Not enough flashcards to play!';

  @override
  String get mqBestStreak => 'Best Streak';

  @override
  String get mpWhichWord => 'Which word is this?';

  @override
  String get mqWhatInEnglish => 'What is this in English?';

  @override
  String siRound(int round, int total) {
    return 'Round $round of $total.';
  }

  @override
  String siSignThis(String english, String filipino) {
    return 'Sign this word: $english, $filipino.';
  }

  @override
  String get siTitle => 'Sign It!';

  @override
  String get siSelfAssessed => 'Self-assessed signs';

  @override
  String get siWatchAgain => 'Watch the sign again';

  @override
  String get siGotIt => 'I got it';

  @override
  String get siGotItBang => 'I got it!';

  @override
  String siTitleRound(int round, int total) {
    return 'Sign It!  •  $round/$total';
  }

  @override
  String get siWatchThen => 'Watch, then sign it back!';

  @override
  String get siYourTake => 'Your take';

  @override
  String get siYou => 'You';

  @override
  String get siNoPermission =>
      'Camera permission off.\nYou can still watch and practise!';

  @override
  String get siNoCamera =>
      'No camera found.\nJust watch and practise the sign!';

  @override
  String get siCameraOff =>
      'Camera unavailable.\nJust watch and practise the sign!';

  @override
  String fvNeedsInternet(String word) {
    return 'The sign for “$word” needs the internet to load the first time. Connect and try again — after that it works offline.';
  }

  @override
  String fvNoVideo(String word) {
    return 'No FSL video available yet for “$word”.';
  }

  @override
  String get fvCanYou => 'Can you sign this?';

  @override
  String get fvTeacherConfirmed => 'Your teacher confirmed this sign';

  @override
  String get fvKeepPractising => 'Your teacher says keep practising this one';

  @override
  String get fpLoadFailed => 'Unable to load video';

  @override
  String get fpClose => 'Close fullscreen video';

  @override
  String get fpHideCaptions => 'Hide captions';

  @override
  String get fpShowCaptions => 'Show captions';

  @override
  String get fpSpeedSettings => 'Playback speed settings';

  @override
  String get fpPause => 'Pause video';

  @override
  String get fpPlay => 'Play video';

  @override
  String fpSetSpeed(String speed) {
    return 'Set speed to ${speed}x';
  }

  @override
  String get fpReplay => 'Replay from beginning';

  @override
  String get fpPauseShort => 'Pause';

  @override
  String get fpPlayShort => 'Play';

  @override
  String get fpProgress => 'Video progress';

  @override
  String get opByCategory => 'By category';

  @override
  String get opTitle => 'Offline Signs';

  @override
  String get opIntro =>
      'Save sign videos to this device so they play without internet.';

  @override
  String opSavedOf(int ready, int total) {
    return '$ready of $total signs saved';
  }

  @override
  String opUsing(String size) {
    return 'Using $size on this device';
  }

  @override
  String get opNothing => 'Nothing saved yet';

  @override
  String opSaving(String label, int done, int total) {
    return 'Saving “$label”… $done of $total';
  }

  @override
  String get opStop => 'Stop';

  @override
  String get opAllSaved => 'All signs saved';

  @override
  String opSaveAll(int count) {
    return 'Save all $count';
  }

  @override
  String opFailed(int count) {
    return '$count couldn’t be saved — check the connection and try again. Those words still work online.';
  }

  @override
  String get opNoSigns => 'No signs recorded yet';

  @override
  String opCatSaved(int ready, int total) {
    return '$ready of $total saved';
  }

  @override
  String opSaveCat(String category) {
    return 'Save $category offline';
  }

  @override
  String opRemoveCat(String category) {
    return 'Remove $category downloads';
  }

  @override
  String get feSoon => 'FSL videos coming soon';

  @override
  String get feRecording =>
      'We’re still recording sign-language videos for these categories. Practice with the flashcards in the meantime!';

  @override
  String get feReady => 'Ready to practice now:';

  @override
  String get feChooseAnother => 'Choose another category';

  @override
  String get siStopRec => 'Stop recording';

  @override
  String get siRecordMe => 'Record myself signing';

  @override
  String siSignThisLabel(String english, String filipino) {
    return 'Sign this word: $english, $filipino';
  }

  @override
  String get siReference => 'Reference';

  @override
  String get siRecord => 'Record';

  @override
  String get aqOptions => 'Accessibility options';

  @override
  String get aqIntro => 'Make the app easier to see, hear, and use.';

  @override
  String get aqTextSize => 'Text Size';

  @override
  String get aqHcSub => 'Bolder colors and outlines';

  @override
  String get aqEasyRead => 'Easy-Read Font';

  @override
  String get aqEasyReadSub => 'Friendlier spacing for reading';

  @override
  String get aqReadAloud => 'Read Aloud';

  @override
  String get aqReadAloudSub => 'Speak words and buttons';

  @override
  String get aqReduceMotion => 'Reduce Motion';

  @override
  String get aqReduceMotionSub => 'Calmer, simpler animations';

  @override
  String aqTextSizeLabel(String label) {
    return 'Text size $label';
  }

  @override
  String get btTitle => 'Take a Break';

  @override
  String get btBack => 'Back to lesson';

  @override
  String get btPick =>
      'Pick what feels good. You can go back to your lesson anytime.';

  @override
  String get btCalmer => 'Feeling calmer?';

  @override
  String get btStay => 'Stay a little longer';

  @override
  String get btHowFeel => 'How are you feeling?';

  @override
  String get btBreathe => 'Breathe';

  @override
  String get btBubbles => 'Pop Bubbles';

  @override
  String get btBreatheSub => 'Slow, calming breaths';

  @override
  String get btBubblesSub => 'Gently pop the bubbles';

  @override
  String get sqSeeScore => 'See my score';

  @override
  String get sqNextQuestion => 'Next question';

  @override
  String get sqListenEn => 'Listen to this choice in English';

  @override
  String get sqListenTl => 'Listen to this choice in Tagalog';

  @override
  String get sqSeeResults => 'See Results';

  @override
  String get sqNextQuestionCap => 'Next Question';

  @override
  String sqNotQuite(String answer) {
    return 'Not quite. $answer.';
  }

  @override
  String sqQuestionNofM(int number, int total) {
    return 'Question $number of $total';
  }

  @override
  String get srNextPage => 'Next page';

  @override
  String get srReadPage => 'Read this page aloud';

  @override
  String get srGoQuiz => 'Go to the quiz';

  @override
  String srPageNofM(int number, int total) {
    return 'Page $number of $total';
  }

  @override
  String get abCreate => 'Create Assessment';

  @override
  String get abDetails => 'Assessment Details';

  @override
  String get abTitleField => 'Assessment Title';

  @override
  String get abTitleRequired => 'Title is required';

  @override
  String get abDescription => 'Description (optional)';

  @override
  String get abDifficulty => 'Difficulty';

  @override
  String get abTimeLimit => 'Time Limit';

  @override
  String abMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String abQuestionsCount(int count) {
    return 'Questions ($count)';
  }

  @override
  String get abNoQuestions => 'No Questions Yet';

  @override
  String get abNoQuestionsBody =>
      'Add your first question to build the assessment.';

  @override
  String get abAddFirst => 'Add First Question';

  @override
  String get abAddQuestion => 'Add Question';

  @override
  String get abNeedOne => 'Add at least one question';

  @override
  String get abCustomDesc => 'Custom teacher assessment';

  @override
  String abSaved(String title) {
    return 'Assessment “$title” saved!';
  }

  @override
  String get abDiscardTitle => 'Discard Assessment?';

  @override
  String get abDiscardBody =>
      'You have unsaved questions. Are you sure you want to go back?';

  @override
  String get abKeepEditing => 'Keep Editing';

  @override
  String get abDiscard => 'Discard';

  @override
  String abAnswer(String answer) {
    return 'Answer: $answer';
  }

  @override
  String abChoices(String choices) {
    return 'Choices: $choices';
  }

  @override
  String get abEditQuestion => 'Edit Question';

  @override
  String get abQuestionType => 'Question Type';

  @override
  String get abQuestionText => 'Question Text *';

  @override
  String get abCorrectAnswer => 'Correct Answer *';

  @override
  String get abChoicesTitle => 'Choices';

  @override
  String abChoiceN(String letter) {
    return 'Choice $letter';
  }

  @override
  String get abAddChoice => 'Add Choice';

  @override
  String get abCategory => 'Category (optional)';

  @override
  String get abHint => 'Hint (optional)';

  @override
  String get abUpdateQuestion => 'Update Question';

  @override
  String get abTextRequired => 'Question text and answer are required';

  @override
  String get abAnswerInChoices =>
      'Correct answer must match one of the choices';

  @override
  String get qbTitle => 'Quiz Builder';

  @override
  String get qbMyQuiz => 'My Quiz';

  @override
  String get qbQuizTitle => 'Quiz Title';

  @override
  String get qbQuestionTypes => 'Question Types';

  @override
  String get qbTimeLimit => 'Time Limit (optional)';

  @override
  String get qbNoLimit => 'No limit';

  @override
  String qbSelectWords(int count) {
    return 'Select Words ($count selected)';
  }

  @override
  String get qbSelectAll => 'Select All';

  @override
  String get qbDeselectAll => 'Deselect All';

  @override
  String get qbAtLeast3 => 'Select at least 3 words to create a quiz';

  @override
  String get qbSaved => 'Saved Quizzes';

  @override
  String qbSummary(int count, String difficulty, String formats) {
    return '$count words • $difficulty • $formats';
  }

  @override
  String get qbStart => 'Start Quiz';

  @override
  String qbDuplicate(String title) {
    return 'You already have a quiz called “$title”. Give this one a different name.';
  }

  @override
  String qbSavedOne(String title) {
    return 'Quiz “$title” saved!';
  }

  @override
  String get qbNoCards => 'No valid cards found for this quiz';

  @override
  String get qbDeleteTitle => 'Delete Quiz?';

  @override
  String qbDeleteBody(String title) {
    return 'Delete “$title”?';
  }

  @override
  String bbMax(int count) {
    return 'Maximum $count tiles reached';
  }

  @override
  String get bbAlready => 'Tile already added';

  @override
  String bbAdded(String label) {
    return '“$label” added to the board';
  }

  @override
  String get bbNeedName => 'Please give the board a name';

  @override
  String get bbCleared => 'Board cleared — the tab is hidden on Talk Board';

  @override
  String bbSaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiles',
      one: '1 tile',
    );
    return '“$name” saved with $_temp0';
  }

  @override
  String get bbDiscardTitle => 'Discard changes?';

  @override
  String get bbDiscardBody =>
      'This board has changes that have not been saved yet.';

  @override
  String get bbKeepEditing => 'Keep editing';

  @override
  String get bbMyBoard => 'My Board';

  @override
  String get bbDoneEditing => 'Done editing';

  @override
  String get bbReorder => 'Reorder/remove tiles';

  @override
  String get bbPreview => 'Preview with speech';

  @override
  String get bbNameField => 'Board name (shown as the tab)';

  @override
  String get bbTapBelow => 'Tap tiles below, or make your own word';

  @override
  String bbMyWord(String word) {
    return '$word · my word';
  }

  @override
  String bbRemove(String label) {
    return 'Remove $label';
  }

  @override
  String bbCount(int count, int max) {
    return '$count / $max tiles';
  }

  @override
  String get bbClearAll => 'Clear All';

  @override
  String get bbMakeWord => 'Make my own word';

  @override
  String get bbAlreadyAdded => 'already added';

  @override
  String get bbTapToAdd => 'tap to add';

  @override
  String get bbSaveBoard => 'Save Board';

  @override
  String get bbEditWord => 'Edit word';

  @override
  String get bbWordEn => 'Word (English)';

  @override
  String get bbWordEnHint => 'e.g. Ate Maria';

  @override
  String get bbWordFil => 'Word (Filipino) — optional';

  @override
  String get bbWordFilHint => 'Leave blank to reuse the English word';

  @override
  String get bbPicture => 'Picture';

  @override
  String bbPictureN(int number) {
    return 'Picture $number';
  }

  @override
  String get cfUpdated => 'Flashcard updated! ✏️';

  @override
  String get cfCreated => 'Flashcard created! 🎉';

  @override
  String get cfEditTitle => 'Edit Flashcard';

  @override
  String get cfCreateTitle => 'Create Flashcard';

  @override
  String get cfCategory => 'Category';

  @override
  String get cfWordFil => 'Word (Filipino)';

  @override
  String get cfHintEn => 'e.g. Butterfly';

  @override
  String get cfHintFil => 'e.g. Paru-paro';

  @override
  String get cfEnterWord => 'Enter a word';

  @override
  String get cfEnterTranslation => 'Enter a translation';

  @override
  String get cfExample => 'Example Sentence (optional)';

  @override
  String get cfExampleHint => 'e.g. The butterfly is colorful.';

  @override
  String get cfUpdate => 'Update Flashcard';

  @override
  String get cfYourWord => 'Your Word';

  @override
  String get cfNoSpeech => 'Speech recognition not available on this device.';

  @override
  String get cfVoiceReady => 'Voice Ready';

  @override
  String get cfImage => 'Image';

  @override
  String get cfTapImage => 'Tap to add an image';

  @override
  String get cfListening => 'Listening…';

  @override
  String get cfDictate => 'Dictate';

  @override
  String dtAdded(int count, String name) {
    return 'Added $count cards from $name';
  }

  @override
  String get dtFailed => 'Could not add template';

  @override
  String get dtTitle => 'Deck Templates';

  @override
  String get dtHeading => 'Pre-built decks for quick setup';

  @override
  String get dtIntro =>
      'Tap “Use this deck” to copy these bilingual cards into your custom deck.';

  @override
  String dtCards(int count) {
    return '$count cards';
  }

  @override
  String get dtPreview => 'Preview';

  @override
  String get dtUseDeck => 'Use deck';

  @override
  String get dtAdding => 'Adding…';

  @override
  String dtUseThis(int count) {
    return 'Use this deck ($count cards)';
  }

  @override
  String get awWhatTitle => 'What does “PWD” mean?';

  @override
  String get awWhatBody =>
      'PWD stands for Persons with Disabilities — people who have a long-term physical, sensory, cognitive, or learning condition. Disability is a natural part of human diversity. Use person-first language: say “a person with a disability,” not “a disabled person.” Every learner deserves the same respect and the same chance to learn.';

  @override
  String get awKindsTitle => 'Common kinds of disability';

  @override
  String get awRespectTitle => 'Interacting respectfully';

  @override
  String get awRespect1 =>
      'Speak directly to the person, not to their companion or interpreter.';

  @override
  String get awRespect2 =>
      'Ask before you help — don’t assume someone needs it.';

  @override
  String get awRespect3 => 'Be patient and give people time to respond.';

  @override
  String get awRespect4 =>
      'Keep language simple and clear; avoid labels and pity.';

  @override
  String get awRespect5 =>
      'A wheelchair, cane, or guide is personal space — don’t touch it without permission.';

  @override
  String get awCommTitle => 'Communicating accessibly';

  @override
  String get awCommBody =>
      'Many Deaf and hard-of-hearing Filipinos communicate through Filipino Sign Language (FSL) — a complete language with its own grammar. Captions, plain text, pictures, and sign-language video all make information reach more people. This app teaches vocabulary alongside FSL clips so signing learners are included from the start.';

  @override
  String get awHelpsTitle => 'How FlashLearn PWD helps';

  @override
  String get awHelps1 =>
      'High-contrast and dyslexia-friendly themes for easier reading.';

  @override
  String get awHelps2 =>
      'Adjustable font size, reduced motion, and text-to-speech.';

  @override
  String get awHelps3 =>
      'Filipino Sign Language videos in flashcards and stories.';

  @override
  String get awHelps4 =>
      'Hands-free gaze control — move your head or blink to select.';

  @override
  String get wrOverview => 'Weekly Overview';

  @override
  String get wrDailyTime => 'Daily Study Time';

  @override
  String get wrCategoryMastery => 'Category Mastery';

  @override
  String get wrRecentScores => 'Recent Game Scores';

  @override
  String get wrInsights => 'Insights & Recommendations';

  @override
  String get wrTrend => 'Week-over-Week Trend';

  @override
  String get wrFamilyTitle => 'Family Progress Report';

  @override
  String wrGeneratedOn(String date) {
    return 'Generated on $date';
  }

  @override
  String get wrWeeklyTitle => 'Weekly Progress Report';

  @override
  String get wrDayStreak => 'day streak';

  @override
  String wrFooter(int page, int pages) {
    return 'Generated by FlashLearn PWD - Page $page of $pages';
  }

  @override
  String get wrTotalStars => 'Total Stars';

  @override
  String get wrWordsLearned => 'Words Learned';

  @override
  String get wrGamesPlayed => 'Games Played';

  @override
  String get wrStudyTime => 'Study Time';

  @override
  String wrStars(int count) {
    return '$count stars';
  }

  @override
  String wrWords(int count) {
    return '$count words';
  }

  @override
  String wrGames(int count) {
    return '$count games';
  }

  @override
  String wrMinutesThisWeek(int minutes) {
    return '${minutes}m this week';
  }

  @override
  String wrAccuracyPct(String percent) {
    return '$percent% accuracy';
  }

  @override
  String get wrDate => 'Date';

  @override
  String get wrMinutes => 'Minutes';

  @override
  String get wrVisual => 'Visual';

  @override
  String get wrCategory => 'Category';

  @override
  String get wrProgress => 'Progress';

  @override
  String get wrMasteryBar => 'Mastery Bar';

  @override
  String get wrNoScores => 'No recent game scores this week.';

  @override
  String get wrGame => 'Game';

  @override
  String get wrScore => 'Score';

  @override
  String get wrStarsCol => 'Stars';

  @override
  String get wrDuration => 'Duration';

  @override
  String wrStrongest(String category) {
    return 'Strongest area: $category';
  }

  @override
  String get wrStrongestSub => 'Keep up the excellent work in this category!';

  @override
  String wrWeakest(String category) {
    return 'Needs practice: $category';
  }

  @override
  String get wrWeakestSub => 'Focus on this category for improvement.';

  @override
  String wrUnexplored(String categories) {
    return 'Not yet explored: $categories';
  }

  @override
  String get wrUnexploredSub => 'Try introducing these categories this week.';

  @override
  String wrAccuracy(String percent) {
    return 'Accuracy: $percent%';
  }

  @override
  String get wrAccuracyHigh =>
      'Outstanding accuracy! Consider increasing difficulty.';

  @override
  String get wrAccuracyLow => 'Extra review sessions may help improve scores.';

  @override
  String wrLowSessions(int count) {
    return 'Low session count: $count sessions this month';
  }

  @override
  String get wrLowSessionsSub =>
      'Try to have at least 3-4 learning sessions per week.';

  @override
  String wrMastered(int count) {
    return '$count categories mastered (>=80%)';
  }

  @override
  String wrMasteredSub(int count) {
    return 'Great progress! $count more to go.';
  }

  @override
  String get wrStartLearning => 'Start learning to see personalized insights!';

  @override
  String get wrTimeUp => 'Study time increased compared to last week!';

  @override
  String get wrTimeDown => 'Study time decreased compared to last week.';

  @override
  String wrThisLast(int thisWeek, int lastWeek) {
    return 'This week: ${thisWeek}min | Last week: ${lastWeek}min';
  }

  @override
  String get wrsTitle => 'Weekly Reports';

  @override
  String get wrsFamily => 'Family Report';

  @override
  String get wrsNoStudents => 'No student profiles found';

  @override
  String get wrsNoStudentsBody =>
      'Create a student profile to generate reports.';

  @override
  String get wrsHeading => 'Progress Reports';

  @override
  String get wrsIntro =>
      'Generate professional PDF reports showing weekly stats, category mastery, game scores, and personalized insights.';

  @override
  String get wrsSelectChild => 'Select a child to generate report';

  @override
  String wrsSubject(String name) {
    return 'Weekly Progress Report — $name';
  }

  @override
  String get wrsFailedGenerate =>
      'Could not make the report. Please try again.';

  @override
  String get wrsFailedPreview => 'Could not show the report. Please try again.';

  @override
  String wrsPreviewTitle(String name) {
    return 'Report Preview — $name';
  }

  @override
  String get wrsSharePdf => 'Share PDF';

  @override
  String get wrsNoPreview =>
      'On-screen preview isn’t available on this device.';

  @override
  String get wrsNoPreviewBody =>
      'The report was generated successfully — tap below to open, save, or send it as a PDF.';

  @override
  String wrsStreakDays(int count) {
    return '${count}d';
  }

  @override
  String get prTitle => 'Student Progress Report';

  @override
  String get prWordsLearned => 'Words Learned';

  @override
  String prOfTotal(int total) {
    return 'of $total';
  }

  @override
  String prStreakDays(int count) {
    return '$count days';
  }

  @override
  String get prCategoryBreakdown => 'Category Breakdown';

  @override
  String get prLearningAnalysis => 'Learning Analysis';

  @override
  String get prTotalAttempts => 'Total Attempts';

  @override
  String get prStruggling => 'Struggling Words';

  @override
  String get prOverallAccuracy => 'Overall Accuracy';

  @override
  String get prNotAvailable => 'N/A';

  @override
  String get prNeedPractice => 'Words Needing Practice';

  @override
  String get prWordEn => 'Word (EN)';

  @override
  String get prWordFil => 'Word (FIL)';

  @override
  String get prAttempts => 'Attempts';

  @override
  String get prRecentActivity => 'Recent Game Activity';

  @override
  String get prPercentage => 'Percentage';

  @override
  String get prTagline => 'Interactive Vocabulary Learning';

  @override
  String get prFooter => 'FlashLearn PWD - Thesis Capstone Project';

  @override
  String prPageOf(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String prFocusOn(String category) {
    return 'Focus on $category';
  }

  @override
  String prFocusOnBody(int percent) {
    return 'This category has the lowest progress at $percent%. Encourage the student to use flashcards and play games in this category.';
  }

  @override
  String get prSmartReview => 'Use Smart Review';

  @override
  String prSmartReviewBody(int count) {
    return 'There are $count words the student struggles with. The Smart Review feature uses spaced repetition to prioritize them.';
  }

  @override
  String get prHabit => 'Build Daily Habit';

  @override
  String prHabitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'The current streak is $_temp0. Encourage daily practice to build consistency.';
  }

  @override
  String get prConsistency => 'Great Consistency!';

  @override
  String prConsistencyBody(int count) {
    return 'The student has a $count-day streak. Positive reinforcement will help maintain this habit.';
  }

  @override
  String get prHarder => 'Try Harder Difficulty';

  @override
  String prHarderBody(String category, int percent) {
    return '$category progress is at $percent%. Consider increasing the game difficulty for extra challenge.';
  }

  @override
  String get erLast7 => 'Last 7 days';

  @override
  String get erLast30 => 'Last 30 days';

  @override
  String get erLast90 => 'Last 90 days';

  @override
  String get erPickClass => 'Pick a classroom first.';

  @override
  String erShareText(String classroom, String range) {
    return 'Progress report — $classroom ($range)';
  }

  @override
  String erShareSubject(String classroom) {
    return 'Progress report — $classroom';
  }

  @override
  String get erFailed => 'Export failed. Please try again.';

  @override
  String get erTitleShort => 'Export Report';

  @override
  String get erSignIn => 'Sign in as a teacher to export reports.';

  @override
  String get erTitle => 'Export Progress Report';

  @override
  String get erLoadFailed => 'Could not load classrooms. Please try again.';

  @override
  String get erNoClasses =>
      'You don’t have any classrooms yet. Create a classroom first to export progress reports.';

  @override
  String get erHeading => 'Progress Report (CSV)';

  @override
  String get erIntro =>
      'Generate a spreadsheet of every student’s progress in the selected window. Use it for IEPs, parent updates, or classroom records.';

  @override
  String get erClassroom => 'Classroom';

  @override
  String get erDateRange => 'Date Range';

  @override
  String get erBuilding => 'Building CSV…';

  @override
  String get erExport => 'Export & share CSV';

  @override
  String get erShareNote =>
      'The file will open the device share sheet so you can email it, save it to Drive, or upload it to your school portal.';

  @override
  String get cePdfTitle => 'CERTIFICATE OF ACHIEVEMENT';

  @override
  String get cePdfPresented => 'This certificate is proudly presented to';

  @override
  String cePdfFor(String achievement) {
    return 'For $achievement';
  }

  @override
  String cePdfDate(String date) {
    return 'Date: $date';
  }

  @override
  String get ceTypeAssessment => 'Assessment Completion';

  @override
  String get ceTypeStreak => 'Streak Milestone';

  @override
  String get ceTypeOverall => 'Overall Progress';

  @override
  String ceCatTitle(String category) {
    return '$category Category Mastery';
  }

  @override
  String ceCatDetail(int learned, int total, String category) {
    return 'Successfully learned $learned out of $total words in the $category vocabulary category.';
  }

  @override
  String ceStreakTitle(int days) {
    return '$days-Day Learning Streak';
  }

  @override
  String ceStreakDetail(int days) {
    return 'Demonstrated outstanding dedication by maintaining a $days-day consecutive study streak.';
  }

  @override
  String ceOverallDetail(int words, int stars, int days) {
    return 'Learned $words words, earned $stars stars, and maintained a $days-day streak.';
  }

  @override
  String get wsTracing => 'Word Tracing';

  @override
  String get wsMatching => 'Picture Matching';

  @override
  String get wsMatchingHeader => 'Picture/Word Matching';

  @override
  String get wsFill => 'Fill in the Blank';

  @override
  String get wsSearch => 'Word Search';

  @override
  String get wsTracingDesc =>
      'Trace English and Filipino words with dotted letters';

  @override
  String get wsMatchingDesc =>
      'Draw lines to match words with their translations';

  @override
  String get wsFillDesc =>
      'Complete sentences with the correct vocabulary word';

  @override
  String get wsSearchDesc => 'Find hidden vocabulary words in a letter grid';

  @override
  String get wsTraceInstr =>
      'Trace each word carefully. Practice writing both English and Filipino!';

  @override
  String get wsEnglishColon => 'English: ';

  @override
  String get wsFilipinoColon => 'Filipino: ';

  @override
  String get wsMatchInstr =>
      'Draw a line from each English word on the left to its Filipino translation on the right.';

  @override
  String get wsEnglish => 'English';

  @override
  String get wsFilipino => 'Filipino';

  @override
  String get wsAnswers =>
      'Answers: _______________________________________________';

  @override
  String get wsFillInstr =>
      'Fill in each blank with the correct word from the word bank below.';

  @override
  String get wsWordBank => 'Word Bank:';

  @override
  String get wsSearchInstr =>
      'Find and circle all the hidden words in the grid below!';

  @override
  String wsMeta(String category, String difficulty) {
    return 'Category: $category  •  Difficulty: $difficulty';
  }

  @override
  String get wsName => 'Name: ____________________';

  @override
  String get wsDate => 'Date: ____________________';

  @override
  String wsFooter(int page, int pages) {
    return 'Page $page of $pages  •  Generated by FlashLearn PWD';
  }

  @override
  String get wscTitle => 'Printable Worksheets';

  @override
  String get wscIntro =>
      'Create practice worksheets your students can print and use offline!';

  @override
  String get wscType => 'Worksheet Type';

  @override
  String get wscGenerating => 'Generating...';

  @override
  String get wscPreviewPrint => 'Preview & Print';

  @override
  String wscWords(int count) {
    return '$count words';
  }

  @override
  String pfTitle(String name) {
    return '$name’s Learning Portfolio';
  }

  @override
  String get pfOverview => 'Overview';

  @override
  String get pfDayStreak => 'Day Streak';

  @override
  String get pfItems => 'Portfolio Items';

  @override
  String get pfPinned => 'Pinned Highlights';

  @override
  String get pfAllItems => 'All Portfolio Items';

  @override
  String get pfType => 'Type';

  @override
  String get pfItemTitle => 'Title';

  @override
  String get pfDescription => 'Description';

  @override
  String get pfSummaryByType => 'Summary by Type';

  @override
  String get sdDetails => 'Details';

  @override
  String get sdEarned => 'Earned';

  @override
  String get sdYes => 'Yes';

  @override
  String get sdNo => 'No';

  @override
  String get sdPersonalNote => 'Personal Note';

  @override
  String get bpSemantics =>
      'Pop the bubbles. This is just for fun — there is no score.';

  @override
  String get crbReconnected => 'Cloud sync reconnected.';

  @override
  String get lwDismiss => 'Dismiss';

  @override
  String egSemantics(String word) {
    return 'See example photos of $word';
  }

  @override
  String smSemantics(String word) {
    return 'Show me $word';
  }

  @override
  String get siReRecord => 'Re-record';

  @override
  String mqPlayerN(int number) {
    return 'Player $number';
  }

  @override
  String get mqRematch => 'Rematch!';

  @override
  String get mpRematch => 'Rematch';

  @override
  String gzTarget(String label) {
    return 'Gaze target: $label';
  }

  @override
  String get frRequests => 'Friend requests';

  @override
  String get alMarkRead => 'Mark as read';

  @override
  String get exSaved => 'Experiment settings saved!';

  @override
  String exGroup(String label) {
    return '$label group';
  }

  @override
  String alDeleteTitle(String label) {
    return 'Delete “$label”?';
  }

  @override
  String get alLabel => 'Label';

  @override
  String get alEnabled => 'Enabled';

  @override
  String get tlEnforce => 'Enforce a daily limit';

  @override
  String get tlSaved => 'Saved.';

  @override
  String get pcSaveFailed =>
      'Couldn’t save parental controls. Please try again.';

  @override
  String get tuVerify => 'Verify';

  @override
  String get tuSwitchAccount => 'Switch account';

  @override
  String woAvgPer(String noun) {
    return 'Avg/$noun';
  }

  @override
  String get aaSelectProfile => 'Select a profile to view adaptive analytics.';

  @override
  String get daSelectProfile => 'Select a profile to view detailed analytics.';

  @override
  String get lcTitle => 'Leaderboard Settings';

  @override
  String get lcVisibility => 'Visibility';

  @override
  String get lcShow => 'Show leaderboard to members';

  @override
  String get lcRankBy => 'Rank by';

  @override
  String get lcPeriod => 'Time period';

  @override
  String get lcNewSeason => 'Start new season';

  @override
  String get lcClearSeason => 'Clear season';

  @override
  String get lcHide => 'Hide members';

  @override
  String get lcNoMembers => 'No members have joined yet.';

  @override
  String get ptAccuracyTrend => 'Accuracy Trend 📊';

  @override
  String get ptpTitle => 'Customize Progress';

  @override
  String get ptpIntro => 'Pick a look and a layout for the Progress page';

  @override
  String get ptpTheme => 'Theme';

  @override
  String get ptpLayout => 'Layout';

  @override
  String sqQuizTitle(String title) {
    return 'Quiz: $title';
  }

  @override
  String get sqEnglish => 'English';

  @override
  String get sqTagalog => 'Tagalog';

  @override
  String get srPrevPage => 'Previous page';

  @override
  String get scmpKeyMetrics => 'Key Metrics';

  @override
  String get taAvgAccuracy => 'Avg Accuracy';

  @override
  String get nfIllustration => 'Lost page illustration';

  @override
  String get nfTitle => 'Oops! Page not found';

  @override
  String get nfBody =>
      'It looks like this page has wandered off.\nLet’s get you back on track!';

  @override
  String get nfGoHomeSem => 'Go back to home screen';

  @override
  String get nfGoHome => 'Go Home';

  @override
  String get nfGoBackSem => 'Go back to previous page';

  @override
  String get ciOnline => 'Online';

  @override
  String get ciOffline => 'No internet — your work is saved locally';

  @override
  String get spdCreated => 'Created';

  @override
  String get ssSyncing => 'Syncing…';

  @override
  String get ssSynced => 'Synced!';

  @override
  String get splashLogo => 'FlashLearn logo';

  @override
  String get ctDark => 'Dark';

  @override
  String get ctLight => 'Light';

  @override
  String get ctClassroom => 'Classroom';

  @override
  String get ctPlayful => 'Playful';

  @override
  String get ctCalm => 'Calm / Focus';

  @override
  String get ctSeasonal => 'Seasonal';

  @override
  String get ctHighContrast => 'High contrast';

  @override
  String get ctDyslexia => 'Dyslexia-friendly';

  @override
  String get ctDarkDesc => 'High-legibility dark — the classic look.';

  @override
  String get ctLightDesc => 'Bright and clean for well-lit rooms.';

  @override
  String get ctClassroomDesc => 'Crisp and neutral — maximum readability.';

  @override
  String get ctPlayfulDesc => 'Vibrant and rounded, with big emoji for kids.';

  @override
  String get ctCalmDesc => 'Soft, low-stimulation, calm pacing (no animation).';

  @override
  String get ctSeasonalDesc => 'Festive accents that follow the season.';

  @override
  String get ctHighContrastDesc => 'Black/white/yellow for low vision.';

  @override
  String get ctDyslexiaDesc => 'Lexend on cream, with looser spacing.';

  @override
  String get ctSizeNormal => 'Normal';

  @override
  String get ctSizeLarge => 'Large';

  @override
  String get ctSizeXl => 'Extra large';

  @override
  String get ctLangBoth => 'Both';

  @override
  String get ctLeaderboard => 'Leaderboard';

  @override
  String get ctClassWins => 'Class wins';

  @override
  String get ctLeaderboardDesc => 'Top 10 by stars, ranked.';

  @override
  String get ctClassWinsDesc =>
      'What the class did together, then everyone A–Z — no ranking.';

  @override
  String get tcWifiLost =>
      'Wi-Fi disconnected — the TV can’t reach this cast. Reconnect to the same Wi-Fi to continue.';

  @override
  String get tcNetChanged =>
      'You’re on a different network now — the TV can’t reach this cast. Reconnect to the original Wi-Fi, or tap Restart for a new code.';

  @override
  String get tcRestart => 'Restart';

  @override
  String get tcNoWifi =>
      'Wi-Fi not detected. Connect to the same network as your TV.';

  @override
  String get tcStopTitle => 'Stop casting?';

  @override
  String get tcStopBody =>
      'This ends the current cast and disconnects any TVs. You can start again anytime.';

  @override
  String get tcStopped => 'Casting stopped';

  @override
  String get tcTitle => 'TV Cast';

  @override
  String get tcTeacherBack => 'Teacher is back (resume cast)';

  @override
  String get tcTeacherOut => 'Show “Teacher is out” on TV';

  @override
  String get tcStopCasting => 'Stop casting';

  @override
  String get tcWhatToCast => 'What to cast';

  @override
  String get tcSwitchesNow => 'The TV switches the moment you tap.';

  @override
  String get tcNowShowing => 'Now showing on TV';

  @override
  String get tcPacing => 'Pacing';

  @override
  String get tcPlayback => 'Playback';

  @override
  String get tcStepLesson => 'Step the lesson from here.';

  @override
  String get tcReplayAudio => 'Replay audio';

  @override
  String get tcDisplayStyle => 'TV display style';

  @override
  String get tcDisplayStyleSub => 'How the lesson looks on the big screen.';

  @override
  String get tcLessonTimer => 'Lesson timer';

  @override
  String get tcReadability => 'Readability on TV';

  @override
  String get tcShowOnTv => 'Show on TV';

  @override
  String get tcShowOnTvSub => 'Optional name shown in the corner of the TV.';

  @override
  String get tcAudio => 'Audio';

  @override
  String get tcFullscreen => 'Fullscreen';

  @override
  String get tcTvRemote => 'TV remote';

  @override
  String get tcAnyTv => 'Cast to any TV';

  @override
  String get tcAnyTvBody =>
      'Works on any TV with a web browser — Samsung, LG, Sony, Fire TV, Chromecast with Google TV, smart projectors, or any laptop plugged into HDMI. You open the link in the TV’s own browser — this is not the same as mirroring or casting your tablet, so sound comes from the TV.';

  @override
  String get tcStarting => 'Starting…';

  @override
  String get tcStart => 'Start Casting';

  @override
  String get tcWaitingTv => 'Waiting for TV to connect…';

  @override
  String get tcTeacherOutNote =>
      'The TV is showing “The teacher is out”. Tap the walk icon to resume casting.';

  @override
  String get tcFlashcards => 'Flashcards';

  @override
  String get tcFlashcardsSub => 'Word, picture & photo';

  @override
  String get tcFsl => 'FSL';

  @override
  String get tcFslSub => 'Sign-language clips';

  @override
  String get tcStories => 'Stories';

  @override
  String get tcStoriesSub => 'Read page by page';

  @override
  String get tcLiveActivity => 'Live Activity';

  @override
  String get tcLiveActivitySub => 'Quiz the whole room';

  @override
  String get tcProgress => 'Progress';

  @override
  String get tcProgressSub => 'Class wins & stars';

  @override
  String get tcStory => 'Story';

  @override
  String get tcPickAbove =>
      'Pick what to cast above. The TV will switch instantly.';

  @override
  String get tcTextSize => 'Text size on TV';

  @override
  String get tcTextSizeNote =>
      'Makes the word, story line, sign caption and answer choices bigger — for learners reading from the back, or with low vision.';

  @override
  String get tcLanguage => 'Language on TV';

  @override
  String get tcBothLangs => 'The TV shows and speaks both languages.';

  @override
  String get tcReadyOffline => 'Ready to cast offline';

  @override
  String get tcPrepare => 'Prepare for casting';

  @override
  String get tcStopDownloading => 'Stop downloading';

  @override
  String get tcCheckAgain => 'Check again';

  @override
  String get tcFsOnNote =>
      'The TV fills the whole screen and auto-resizes to fit any TV — Smart TV, Chromecast / Google TV, Fire TV, projector or HDMI laptop. On some TVs, press OK on the remote once to finish filling the screen.';

  @override
  String get tcFsOffNote =>
      'The TV keeps the browser bars. Turn on to fill the whole screen.';

  @override
  String get tcFsOnTv => 'Fullscreen on TV';

  @override
  String get tcBigPicNa =>
      'Works with Flashcards, FSL Videos and Stories. Pick one of those to use it — a live activity needs its answer choices on screen.';

  @override
  String get tcBigPicOn =>
      'The picture, GIF or sign video fills the TV. The whole picture stays in view (never cropped) and the word stays underneath; the category badge and example sentence are hidden to make room.';

  @override
  String get tcBigPicOff =>
      'The picture sits inside the card. Turn on to fill the TV with it — easier to see from the back of the room, or for a learner with low vision.';

  @override
  String get tcBigPic => 'Fullscreen picture & video';

  @override
  String get tcRecent => 'Recent casts';

  @override
  String get tcClear => 'Clear';

  @override
  String get tcClearTitle => 'Clear cast history?';

  @override
  String get tcClearBody =>
      'This removes the record of your past casts from this device. It does not affect any student data.';

  @override
  String get tcEarlier => 'Earlier';

  @override
  String get tcLive => 'Live';

  @override
  String get tcUnderMinute => '<1 min';

  @override
  String get tcFslSigns => 'FSL signs';

  @override
  String get tcLessonCast => 'Lesson cast';

  @override
  String get tcTimerNote =>
      'Show a countdown in the corner of the TV — for transitions, quiet reading, or “five more minutes”. The lesson keeps playing underneath it.';

  @override
  String get tcResumeTimer => 'Resume timer';

  @override
  String get tcPauseTimer => 'Pause timer';

  @override
  String get tcClearTimer => 'Clear timer';

  @override
  String get tcTimesUpNote =>
      'The TV is showing “Time’s up!”. Clear it, or start another.';

  @override
  String get tcTimerShowing => 'Showing on the TV, over the lesson.';

  @override
  String get tcRemoteLabel => 'Control from the TV remote';

  @override
  String get tcRemoteOn =>
      'Press ◀ or ▶ on the TV remote to move between cards, signs or story pages, and play/pause to hold. Handy when you’re at the board and the tablet is on your desk. (OK still just turns on the TV’s sound.)';

  @override
  String get tcRemoteOff =>
      'The TV remote can’t change the lesson. Turn on if you want to step through from the board — or leave off for a screen left unattended.';

  @override
  String get tcTrouble => 'Having trouble?';

  @override
  String get tcTipSameWifi =>
      'Both phone and TV must be on the SAME Wi-Fi network.';

  @override
  String get tcTipApIsolation =>
      'If you’re on a school or guest Wi-Fi, “AP isolation” may block phone-to-TV traffic. Try a regular home network.';

  @override
  String get tcTipSamsung =>
      'Samsung TV: open the “Internet” app, type the URL.';

  @override
  String get tcTipLg => 'LG TV: open “Web Browser” from the home dashboard.';

  @override
  String get tcTipFire =>
      'Fire TV: install Silk Browser (free), then open URL.';

  @override
  String get tcTipChromecast =>
      'Chromecast with Google TV: open Chrome from the apps list, type the URL.';

  @override
  String get tcTipApple =>
      'Apple TV: AirPlay-mirror a laptop browser showing the URL.';

  @override
  String get tcTipFullscreen =>
      'Not filling the whole TV? Make sure “Fullscreen on TV” is on above. On some TVs (e.g. Chromecast / Google TV) press OK on the remote once to finish filling the screen.';

  @override
  String get tcTipLeave =>
      'You can leave this screen — the cast keeps running. A “Casting to TV” bar stays at the bottom of the app so you can pause or skip from anywhere, and tapping it brings you back here.';

  @override
  String get tcTipPrivate =>
      'Only TVs that open your exact cast link (it ends in your cast code) can see the lesson. Starting a new cast makes a new code and retires the old link.';

  @override
  String get tcTipQuiet =>
      'Too quiet? The app already speaks at maximum — raise the TV’s volume (or the phone’s, if sound plays from the phone).';

  @override
  String get tcNameHint => 'e.g. Ms. Cruz — Grade 2 (optional)';

  @override
  String get tcAutoAdvance => 'Auto-advance';

  @override
  String get tcTapOnlyOn =>
      'The TV shows the emoji; use the Flip button to reveal the real photo (and flip back). Works on any TV.';

  @override
  String get tcTapOnlyOff =>
      'The TV shows the emoji only — the photo is hidden.';

  @override
  String get tcTapOnly => 'Tap Only';

  @override
  String get tcShowEmoji => 'Show emoji';

  @override
  String get tcFlipPhoto => 'Flip to photo';

  @override
  String get tcPhotoShowing =>
      'The TV is showing the real photo. Tap to flip back to the emoji.';

  @override
  String get tcHideClip => 'Hide clip';

  @override
  String get tcShowMe => 'Show Me';

  @override
  String get tcClipPlaying =>
      'Playing the clip on the TV. Tap to go back to the card.';

  @override
  String get tcFlipAnim => 'Tap to Flip Animation (Cartoon ↔ Picture)';

  @override
  String get tcPictureShowing =>
      'The TV is showing the real picture. Tap to flip back to the cartoon.';

  @override
  String get tcCartoonShowing =>
      'The TV is showing the cartoon. Tap to flip to the real picture on the TV.';

  @override
  String get tcHideFsl => 'Hide FSL';

  @override
  String get tcWatchFsl => 'Watch in FSL';

  @override
  String get tcFslPlaying =>
      'Playing the sign-language video on the TV. Tap to go back to the story.';

  @override
  String get tcReadyToPlay => 'Ready to play';

  @override
  String get tcPreparingVideo => 'Preparing video…';

  @override
  String get tcTvSpeaks =>
      'The TV speaks each word and story page (English + Filipino).';

  @override
  String get tcPhoneReads => 'This phone reads each word / story page aloud.';

  @override
  String get tcTurnOnTts => 'Turn on Text-to-Speech in Settings to hear this.';

  @override
  String get tcSpeakWords => 'Speak words & narrate';

  @override
  String get tcPlaySoundOn => 'Play sound on';

  @override
  String get tcThisPhone => 'This phone';

  @override
  String get tcPhoneSound =>
      'Plays from this phone (or a phone-connected speaker).';

  @override
  String get tcTvVolume =>
      'Words play at full volume on the TV — raise the TV’s own volume so every student, including those who need it louder, can hear clearly.';

  @override
  String get tcPhoneVolume =>
      'Words play at full volume — use this phone’s volume buttons to make them louder.';

  @override
  String get tcVideoSound => 'Play TV video sound';

  @override
  String get tcVideoSoundNote =>
      'Off by default so signs stay muted (Deaf-friendly). Turn on for signs that include a spoken voiceover. May not work on older TVs.';

  @override
  String get tcWaitingATv => 'Waiting for a TV to connect…';

  @override
  String get tcTvPlaying => 'The TV is playing the sound.';

  @override
  String get tcPressOk =>
      'Press OK on the TV remote once to turn on its sound.';

  @override
  String get tcTvCantSpeak =>
      'This TV can’t speak words. Tap “This phone” to hear narration here instead.';

  @override
  String get tcTvGettingReady =>
      'Getting the TV ready… if it stays silent, press OK on the TV remote once.';

  @override
  String get tcLoadingSigns => 'Loading signs…';

  @override
  String get tcNoFsl => 'No FSL videos in this category yet.';

  @override
  String get tcTapSign => 'Tap a sign to show it now';

  @override
  String get tcPickCategory => 'Pick a category to start.';

  @override
  String get tcNoWords => 'No words in this category.';

  @override
  String get tcPickStory => 'Pick a story.';

  @override
  String get tcFinished =>
      'Finished — the TV is showing “The End”. Back re-reads the last page.';

  @override
  String get tcNoLeaderboard => 'Leaderboard — no student data yet.';

  @override
  String get tcLiveWaiting => 'Live activity — waiting for a question.';

  @override
  String get tcNothingCast => 'Nothing is being cast.';

  @override
  String get tcTimesUp => 'Time’s up';

  @override
  String get tcStartFailed => 'Could not start the cast. Please try again.';

  @override
  String get tcReplayPage => 'Hear the current page again on this phone.';

  @override
  String get tcReplayWord => 'Hear the current word again on this phone.';

  @override
  String tcViewers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count viewers connected',
      one: '1 viewer connected',
    );
    return '$_temp0';
  }

  @override
  String tcOneLang(String language) {
    return 'The TV shows and speaks $language only — the other language is hidden, not removed, so you can switch back mid-lesson.';
  }

  @override
  String tcDownloading(int done, int total) {
    return 'Downloading $done of $total';
  }

  @override
  String tcDownloadAll(String target) {
    return 'Download every sign, clip and picture in $target now, so the TV never waits mid-lesson — and the cast keeps working if the Wi-Fi drops.';
  }

  @override
  String tcPrepareTarget(String target) {
    return 'Prepare $target';
  }

  @override
  String tcNothingToDownload(String target) {
    return 'Nothing to download for $target — it casts from the app.';
  }

  @override
  String tcSomeFailed(int ready, int total, int failed) {
    return '$ready of $total ready. $failed couldn’t be downloaded — those will load during the lesson if the network is up.';
  }

  @override
  String tcAllReady(int total, String target) {
    return 'All $total items are on this device. $target will cast instantly, even with no internet.';
  }

  @override
  String tcUpdatesItself(String description) {
    return '$description Updates by itself as your class works.';
  }

  @override
  String tcOlderCasts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count older casts kept (90 days).',
      one: '1 older cast kept (90 days).',
    );
    return '$_temp0';
  }

  @override
  String tcToday(String time) {
    return 'Today, $time';
  }

  @override
  String tcYesterday(String time) {
    return 'Yesterday, $time';
  }

  @override
  String tcCards(int count) {
    return '$count cards';
  }

  @override
  String tcPages(int count) {
    return '$count pages';
  }

  @override
  String tcQsAnswers(int questions, int answers) {
    return '$questions Qs · $answers answers';
  }

  @override
  String tcSeconds(int count) {
    return '$count sec';
  }

  @override
  String tcHoursMinutes(int hours, int minutes) {
    return '$hours hr $minutes min';
  }

  @override
  String tcOfCasting(String duration) {
    return '$duration of casting';
  }

  @override
  String tcCardsSigns(int count) {
    return '$count cards / signs shown';
  }

  @override
  String tcStoryPages(int count) {
    return '$count story pages';
  }

  @override
  String tcLiveQs(int questions, int answers) {
    return '$questions live questions · $answers answers';
  }

  @override
  String tcTvsAtOnce(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count TVs at once',
      one: '1 TV at once',
    );
    return '$_temp0';
  }

  @override
  String tcAdvanceOn(String noun) {
    return 'Moves to the next $noun on its own every few seconds.';
  }

  @override
  String tcAdvanceOff(String noun) {
    return 'Stays on each $noun until you tap Next.';
  }

  @override
  String get tcNounPage => 'page';

  @override
  String get tcNounSign => 'sign';

  @override
  String get tcNounCard => 'card';

  @override
  String tcFlipWord(String word) {
    return 'Flip “$word” on the TV to its real photo.';
  }

  @override
  String tcPlayClip(String word) {
    return 'Play a short clip of “$word” in motion on the TV.';
  }

  @override
  String tcPlayPageFsl(int number) {
    return 'Play page $number in Filipino Sign Language on the TV.';
  }

  @override
  String tcPageOf(int number, int total) {
    return 'Page $number / $total';
  }

  @override
  String tcLeaderboardTop(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Leaderboard — top $count students.',
      one: 'Leaderboard — top 1 student.',
    );
    return '$_temp0';
  }

  @override
  String tcLiveAnswered(int count) {
    return 'Live activity — $count answered.';
  }

  @override
  String get tcpNotOnWifi =>
      'This tablet is not on Wi-Fi. The TV and the tablet have to be on the same Wi-Fi network to cast — connect to Wi-Fi and try again.';

  @override
  String get tcpAway => 'Showing “the teacher is out” — tap to resume.';

  @override
  String get tcpNoTv => 'No TV connected yet';

  @override
  String tcpWatching(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count TVs watching',
      one: '1 TV watching',
    );
    return '$_temp0';
  }

  @override
  String get tcpNothing => 'Nothing selected';

  @override
  String get tcpCasting => 'Casting to TV';

  @override
  String tcpCastingCode(String code) {
    return 'Casting to TV · code $code';
  }

  @override
  String cspSemantics(String mode, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Casting to TV. $mode. $count viewers connected.',
      one: 'Casting to TV. $mode. 1 viewer connected.',
    );
    return '$_temp0';
  }

  @override
  String get cspTeacherOut => 'Casting — teacher is out';

  @override
  String cspWatching(String mode, int count) {
    return '$mode · $count watching';
  }

  @override
  String get cspPrev => 'Previous on TV';

  @override
  String get cspResume => 'Resume cast';

  @override
  String get cspPause => 'Pause cast';

  @override
  String get cspNext => 'Next on TV';

  @override
  String get tqOpen => 'Open this on your TV';

  @override
  String get tqHow =>
      'In the TV’s own web browser, scan the code or type this URL (don’t mirror or cast your tablet — that keeps the sound on the tablet):';

  @override
  String get tqCopied => 'URL copied';

  @override
  String get tqCode => 'Cast code';

  @override
  String tqCodeSemantics(String code) {
    return 'Cast code $code';
  }

  @override
  String get tqPrivate =>
      'Only TVs opening this exact link can see the cast. The code changes every time you start casting.';

  @override
  String get trPrevious => 'Previous';

  @override
  String get trPlay => 'Play';

  @override
  String get trPause => 'Pause';

  @override
  String get tlpNeedsNet =>
      'Live games & quizzes need an internet connection so learner devices can join in real time. Connect to Wi-Fi or mobile data (it stays on the free plan) and try again.';

  @override
  String get tlpNoGroup =>
      'Create a home group first (Manage Family), then your child can join the live activity from their own device.';

  @override
  String get tlpNoClass =>
      'Create a classroom first (Manage Classes), then your students can join the live activity from their own devices.';

  @override
  String get tlpStartTitle => 'Start a live activity';

  @override
  String get tlpStartBody =>
      'Learners in the chosen class join from their own device, answer on screen, and earn stars. Their raised hands show on the TV.';

  @override
  String get tlpHost => 'Class / group to host';

  @override
  String get tlpStartSem => 'Start live activity session';

  @override
  String get tlpStart => 'Start live session';

  @override
  String get tlpStartFailed =>
      'Could not start the live session. Check your connection.';

  @override
  String get tlpTip =>
      'Tip: the question, raised hands, and scoreboard all show on the TV. Learners answer on their own devices.';

  @override
  String get tlpSent => 'Question sent to learners & TV';

  @override
  String get tlpRunning => 'Live session running';

  @override
  String tlpAnswered(int count) {
    return '$count answered the current question';
  }

  @override
  String get tlpEndSem => 'End live session';

  @override
  String get tlpEnd => 'End';

  @override
  String get tlpScoring => 'Star scoring';

  @override
  String tlpBase(int stars) {
    return 'Base $stars★';
  }

  @override
  String tlpSpeed(int stars) {
    return ' • speed +$stars';
  }

  @override
  String tlpFirst(int stars) {
    return ' • first +$stars';
  }

  @override
  String tlpCap(int stars) {
    return ' • cap $stars';
  }

  @override
  String get tlpPerCorrect => 'Stars per correct answer';

  @override
  String get tlpSpeedBonus => 'Speed bonus (extra for fast answers)';

  @override
  String get tlpSpeedWindow => 'Speed window (seconds)';

  @override
  String get tlpFirstBonus => 'First-correct bonus';

  @override
  String get tlpSessionCap => 'Session star cap (0 = no cap)';

  @override
  String tlpDecrease(String label) {
    return 'Decrease $label';
  }

  @override
  String tlpIncrease(String label) {
    return 'Increase $label';
  }

  @override
  String get tlpNoQuestion => 'No question on screen. Build & push one below.';

  @override
  String tlpMc(String prompt) {
    return 'Multiple choice: $prompt';
  }

  @override
  String tlpTf(String prompt) {
    return 'True or False: $prompt';
  }

  @override
  String tlpPictureN(int count) {
    return 'Picture choice ($count options)';
  }

  @override
  String get tlpFslSelf => 'FSL sign — self check';

  @override
  String tlpFslN(int count) {
    return 'FSL sign ($count options)';
  }

  @override
  String get tlpFlashcard => 'Flashcard';

  @override
  String get tlpHands => 'Raised hands';

  @override
  String tlpHandsN(int count) {
    return 'Raised hands ($count)';
  }

  @override
  String get tlpNoHands => 'No one is asking for help right now.';

  @override
  String tlpHandSem(String name) {
    return '$name raised their hand. Activate to clear.';
  }

  @override
  String get tlpHandled => 'Mark handled';

  @override
  String get tlpSend => 'Send a question';

  @override
  String get tlpBuildPush => 'Build & push question';

  @override
  String get tlpNewQuiz => 'New quiz';

  @override
  String get tlpSavedQuizzes => 'Saved quizzes';

  @override
  String tlpQuestionsN(int count) {
    return '$count questions';
  }

  @override
  String get tlpRunQuiz => 'Run this quiz';

  @override
  String get tlpDeleteQuiz => 'Delete quiz';

  @override
  String tlpRunningSet(String title, int number, int total) {
    return 'Running “$title” — question $number of $total';
  }

  @override
  String get tlpScoreboard => 'Live scoreboard';

  @override
  String get tlpNoAnswers => 'No answers yet.';

  @override
  String get tlpNewQuestion => 'New question';

  @override
  String get tlpPushTv => 'Push to TV';

  @override
  String get tlpPicture => 'Picture';

  @override
  String get tlpMcLabel => 'Multiple choice';

  @override
  String get tlpTfLabel => 'True / False';

  @override
  String get tlpFslSign => 'FSL sign';

  @override
  String get tlpQuestion => 'Question';

  @override
  String get tlpOptionsHint => 'Answer options (tap ✓ to mark the correct one)';

  @override
  String tlpMarkCorrect(int number) {
    return 'Mark option $number correct';
  }

  @override
  String tlpOption(int number) {
    return 'Option $number';
  }

  @override
  String get tlpOptional => ' (optional)';

  @override
  String get tlpStatement => 'Statement';

  @override
  String get tlpTrue => 'True';

  @override
  String get tlpFalse => 'False';

  @override
  String get tlpAutoOptions =>
      'Learners pick the matching word from 4 options (auto-generated).';

  @override
  String get tlpSelfCheck => 'Self-check (learner taps “I got it”)';

  @override
  String get tlpSelfCheckNote =>
      'No options — the learner judges their own sign.';

  @override
  String get tlpPickOptions => 'Learners pick the matching word from options.';

  @override
  String get tlpNeedOptions =>
      'Add a question and at least two options, and mark the correct one.';

  @override
  String get tlpNeedStatement => 'Type a statement.';

  @override
  String get tlpNeedCard => 'Pick a flashcard first.';

  @override
  String get tlpUnsupported => 'Unsupported.';

  @override
  String get tlpQuizTitle => 'Quiz title';

  @override
  String get tlpNoQuestions => 'No questions yet. Add your first below.';

  @override
  String get tlpAddQuestion => 'Add question';

  @override
  String get tlpSaveQuiz => 'Save quiz';

  @override
  String tlpTfShort(String prompt) {
    return 'T/F: $prompt';
  }

  @override
  String get tlpPictureChoice => 'Picture choice';

  @override
  String get tlpFslSelfShort => 'FSL self-check';

  @override
  String get tlpNoFslCat => 'No FSL signs in this category yet — try another.';

  @override
  String get lrTimeUp => 'Time’s up for today';

  @override
  String lrUsed(int used, int limit) {
    return 'You’ve used $used of $limit minutes.';
  }

  @override
  String get lrOutsideHours => 'Outside study hours';

  @override
  String lrAllowed(String start, String end) {
    return 'Allowed: $start – $end.';
  }

  @override
  String get lrAlarm => 'Alarm';

  @override
  String get lrTakeBreak => 'Time to take a break.';

  @override
  String get lrRoutineTime => 'Routine time';

  @override
  String get lrFinishThis => 'Finish this to carry on.';

  @override
  String get nsDailyTitle => '📚 Time to Learn!';

  @override
  String get nsDailyBody => 'Let’s practice some new words today!';

  @override
  String get nsReviewTitle => '🧠 Words Need Your Attention!';

  @override
  String nsReviewBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You have $count words to review. Let’s strengthen your memory!',
      one: 'You have 1 word to review. Let’s strengthen your memory!',
    );
    return '$_temp0';
  }

  @override
  String get nsReviewNone =>
      'Time to review your vocabulary and keep your streak going!';

  @override
  String get asAlarm => '⏰ Alarm';

  @override
  String get asMoment => 'Time to take a moment.';

  @override
  String get asWrapUp => 'Time to wrap up — tap to view.';

  @override
  String get asTitle => 'Alert Settings';

  @override
  String get asEnable => 'Enable Alerts';

  @override
  String get asEnableSub => 'Get notified about student activity';

  @override
  String get asThresholds => 'Thresholds';

  @override
  String get asAccuracyBelow => 'Accuracy alert below';

  @override
  String get asInactivityAfter => 'Inactivity alert after';

  @override
  String asDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get asTypes => 'Alert Types';

  @override
  String asRecent(int count) {
    return 'Recent Alerts ($count)';
  }

  @override
  String get asNone => 'No alerts yet';

  @override
  String asMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String asHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String asDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get atLowAccuracy => 'Low Accuracy';

  @override
  String get atStreakBroken => 'Streak Broken';

  @override
  String get atInactivity => 'Inactivity';

  @override
  String get atOverdue => 'Assignment Overdue';

  @override
  String get atAchievement => 'Achievement Earned';

  @override
  String get atAssessment => 'Assessment Completed';

  @override
  String amLowAccuracy(String name, String accuracy, String threshold) {
    return '$name’s accuracy is $accuracy% (below $threshold% threshold)';
  }

  @override
  String amInactive(String name, String days) {
    return '$name has been inactive for $days days';
  }

  @override
  String amStreak(String name) {
    return '$name’s streak was broken';
  }

  @override
  String get daTitle => 'Detailed Analytics';

  @override
  String get daAvgSession => 'Average Session';

  @override
  String daMinutesPerSession(String minutes) {
    return '$minutes minutes per session';
  }

  @override
  String get aaCategoryOverview => 'Category Overview';

  @override
  String aaMastered(int count) {
    return '$count Mastered';
  }

  @override
  String aaLearning(int count) {
    return '$count Learning';
  }

  @override
  String aaNew(int count) {
    return '$count New';
  }

  @override
  String get aaSessionInsights => 'Session Insights';

  @override
  String get aaAvgSession => 'Avg Session';

  @override
  String get aaTotalSessions => 'Total Sessions';

  @override
  String ptTitle(String name) {
    return '$name — Timeline';
  }

  @override
  String get ptAccuracySub => 'Average daily accuracy — last 30 days';

  @override
  String get ptStudyTime => 'Study Time ⏱️';

  @override
  String get ptMinutesSub => 'Minutes per day — last 30 days';

  @override
  String ptAvgPerDay(int minutes) {
    return 'Avg: $minutes min/day';
  }

  @override
  String get ptCategoryProgress => 'Category Progress 📚';

  @override
  String get ptNotEnough => 'Not enough data yet';

  @override
  String get scmpSelect2 => 'Select at least 2 students to compare';

  @override
  String get scmpSelect23 => 'Select 2–3 students above to compare';

  @override
  String get scmpStreakDays => 'Streak (days)';

  @override
  String get scmpStarsEarned => 'Stars Earned';

  @override
  String get scmpCategoryComparison => 'Category Comparison';

  @override
  String get scmpStrengths => 'Strengths & Weaknesses';

  @override
  String get cmSignIn => 'Please sign in to manage classes.';

  @override
  String get mqRoundsPerPlayer => 'Rounds per Player';

  @override
  String get gzFocusHint => 'Look ◀ ▶ ▲ ▼ to move · blink to press';

  @override
  String get spdSupport => 'Support';

  @override
  String get lgcPerCategory => 'Per-Category Breakdown';

  @override
  String get rsTimer => 'Timer';

  @override
  String get ebTitle => 'Oops! Something went wrong';

  @override
  String get ebBody =>
      'This part of the app ran into a problem.\nTry going back or restarting the app.';

  @override
  String get gwAuto => 'Auto';

  @override
  String gwStarsOf(int stars, int max) {
    return '$stars out of $max stars';
  }

  @override
  String get cdPlaying => 'Playing Games';

  @override
  String get cdReviewing => 'Reviewing Flashcards';

  @override
  String get cdStudying => 'Studying';

  @override
  String get brRestored => 'Backup restored successfully!';

  @override
  String get brNoFile => 'No file selected.';

  @override
  String get brCantRead => 'Could not read the file.';

  @override
  String get brPickFailed =>
      'Could not open the file picker. Please try again.';

  @override
  String get brCorrupt => 'Invalid backup file. The file may be corrupted.';

  @override
  String get brBadFormat => 'Invalid backup format. Could not read the data.';

  @override
  String get brNewer =>
      'This backup was made with a newer version of FlashLearn PWD. Please update the app first.';

  @override
  String get brNoData => 'Invalid backup structure. No data found.';

  @override
  String get brRestoreFailed =>
      'Could not restore the backup. Please try again.';

  @override
  String get csxNotConnected => 'Cloud sync isn’t connected';

  @override
  String get csxNotConnectedBody =>
      'Restart the app. If it still isn’t connected, check this device’s internet.';

  @override
  String ieImported(String name) {
    return 'Successfully imported “$name”';
  }

  @override
  String get ieNoFile => 'No file selected';

  @override
  String get ieCantRead => 'Could not read the file';

  @override
  String get ieBadFormat => 'Invalid file format';

  @override
  String get ieNotProfile =>
      'This file does not contain a valid student profile';

  @override
  String get ieExists =>
      'A profile with this ID already exists. Delete it first or export from a different device.';

  @override
  String get ieReadFailed => 'Could not read the file. Please try again.';

  @override
  String get ehNetwork => 'Network error. Please check your connection.';

  @override
  String get ehFormat => 'Data format error. Some data may be corrupted.';

  @override
  String get ehTimeout => 'Operation timed out. Please try again.';

  @override
  String get ehGeneric =>
      'Something went wrong. The app will continue working.';

  @override
  String dwsUnlocked(String badge) {
    return '$badge unlocked!';
  }

  @override
  String get assessMediaPhoto => 'Photo';

  @override
  String get assessMediaGif => 'GIF';

  @override
  String get assessMediaVideo => 'Video';

  @override
  String get assessMediaAudio => 'Sound';

  @override
  String get assessMediaSign => 'FSL video';

  @override
  String get assessMediaSectionTitle => 'Pictures, video & sign language';

  @override
  String get assessMediaSectionHelp =>
      'Optional. Each learner meets these in the way that suits them — a Deaf learner sees the FSL video first, a learner with low vision hears the sound and the description.';

  @override
  String assessMediaAdd(String kind) {
    return 'Add $kind';
  }

  @override
  String get assessMediaFromDevice => 'Choose from this device';

  @override
  String get assessMediaOnDevice =>
      'On this tablet only — learners on another device won\'t see it.';

  @override
  String get assessMediaPasteLink => 'Or paste a link';

  @override
  String get assessMediaLinkHint => 'https://… (a direct link to the file)';

  @override
  String get assessMediaUseLink => 'Use this link';

  @override
  String get assessMediaLinkInvalid => 'Paste a link that starts with https://';

  @override
  String get assessMediaLinkReaches => 'A link reaches every device.';

  @override
  String get assessMediaPreview => 'Preview';

  @override
  String get assessMediaReplace => 'Replace';

  @override
  String get assessMediaRemove => 'Remove';

  @override
  String assessMediaTooLarge(int size) {
    return 'That file is too big. Choose one under $size MB.';
  }

  @override
  String get assessMediaPickFailed =>
      'That file could not be added. Try another one.';

  @override
  String get assessMediaDescribe => 'Describe it in words';

  @override
  String get assessMediaDescribeHelp =>
      'Read aloud to learners who can\'t see it, and shown as a caption to learners who can\'t hear it.';

  @override
  String get assessMediaDescribeHelpQuestion =>
      'Read aloud to learners who can\'t see it, and shown as a caption to learners who can\'t hear it. Don\'t give the answer away.';

  @override
  String get assessMediaSignHelp =>
      'Shown to learners who sign. To ask about a sign itself, put the clip under Video so every learner sees it.';

  @override
  String assessMediaTipFor(String names, String advice) {
    return 'For $names: $advice';
  }

  @override
  String get assessMediaTipHearing =>
      'add an FSL video, and put any sound into words.';

  @override
  String get assessMediaTipVisual =>
      'add a sound, and describe pictures in words — they will be read aloud.';

  @override
  String get assessMediaTipCognitive =>
      'one clear photo works best — they see one thing at a time.';

  @override
  String get assessMediaTipMotor =>
      'videos play by themselves, so no small buttons are needed.';

  @override
  String get assessMediaTipMultiple =>
      'add an FSL video and a photo, and describe them in words.';

  @override
  String get assessMediaTipWordsOnly =>
      'put everything into words — it is shown as a caption.';

  @override
  String get assessMediaSignHeading => 'Sign language';

  @override
  String get assessMediaFilmedInFsl => 'Filmed in FSL';

  @override
  String get assessMediaCaption => 'What it shows or says';

  @override
  String get assessMediaReadAloud => 'Read it to me';

  @override
  String assessMediaShowMore(int count) {
    return 'Show more ($count)';
  }

  @override
  String get assessMediaTapToEnlarge => 'Tap to see it bigger';

  @override
  String get assessMediaPlayAnimation => 'Play the moving picture';

  @override
  String get assessMediaStopAnimation => 'Stop the moving picture';

  @override
  String get assessMediaPlay => 'Play';

  @override
  String get assessMediaPause => 'Pause';

  @override
  String get assessMediaReplay => 'Watch again';

  @override
  String get assessMediaClose => 'Close';

  @override
  String assessMediaOnOtherDevice(String kind) {
    return 'This $kind is saved on your teacher\'s tablet, so it can\'t show here.';
  }

  @override
  String assessMediaCouldNotLoad(String kind) {
    return 'This $kind could not be loaded. Try again when you are online.';
  }

  @override
  String get assessMediaPreparing => 'Getting the pictures and videos ready…';

  @override
  String get assessMediaMissingTitle =>
      'Some pictures or videos aren\'t on this tablet';

  @override
  String get assessMediaMissingBody =>
      'Connect to Wi‑Fi and try again, or start without them. The test has not started.';

  @override
  String get assessMediaStartAnyway => 'Start without them';

  @override
  String get assessInstructionsMediaTitle =>
      'Pictures, video or sign language for the instructions';

  @override
  String get assessBriefingTitle => 'Before you start';

  @override
  String get assessBriefingStart => 'Start the test';

  @override
  String get assessBriefingLater => 'Not now';

  @override
  String assessFeedbackFor(String name) {
    return 'Feedback for $name';
  }

  @override
  String assessFeedbackOn(String title) {
    return 'Feedback on $title';
  }

  @override
  String get assessFeedbackFromEducator => 'From your teacher or parent';

  @override
  String get assessFeedbackNote => 'Your note';

  @override
  String get assessFeedbackNoteHint =>
      'What went well, and what to practise next';

  @override
  String get assessFeedbackSave => 'Send feedback';

  @override
  String get assessFeedbackRemove => 'Remove feedback';

  @override
  String get assessFeedbackEmpty =>
      'Write a note or add a picture, video or sound first.';

  @override
  String get assessFeedbackNotFinished => 'Not finished yet';

  @override
  String assessFeedbackScore(int percent) {
    return 'Score: $percent%';
  }

  @override
  String get assessFeedbackForYou => 'Feedback for You';

  @override
  String assessFeedbackAdd(String name) {
    return 'Add feedback for $name';
  }

  @override
  String assessFeedbackEdit(String name) {
    return 'Edit feedback for $name';
  }

  @override
  String assessFeedbackSaved(String name) {
    return 'Feedback sent to $name.';
  }

  @override
  String get assessFeedbackRemoved => 'Feedback removed.';

  @override
  String assessFeedbackLocalOnly(String name) {
    return 'Feedback saved on this device — not sent yet. It will reach $name when syncing is working.';
  }

  @override
  String get assessFeedbackNotOwner =>
      'Saved on this device only. This profile was restored on another device, so that one now handles syncing — the feedback was not sent.';

  @override
  String get assessFeedbackTapToOpen => 'Tap to open';

  @override
  String get assessFeedbackHas => 'Feedback sent';

  @override
  String get assessMediaShared => 'Shared — reaches every device.';

  @override
  String get assessMediaNotShared => 'On this tablet only — not shared yet.';

  @override
  String assessMediaSharing(int percent) {
    return 'Sharing… $percent%';
  }

  @override
  String get assessMediaShareNow => 'Share now';

  @override
  String assessMediaFromDeviceShared(int size) {
    return 'It is shared with every device (files up to $size MB).';
  }

  @override
  String assessMediaShareTooLarge(int size) {
    return 'Over $size MB — this file stays on this tablet only.';
  }

  @override
  String get assessMediaShareFailed =>
      'Couldn’t share it right now. It is saved on this tablet and will be shared when you are online.';

  @override
  String get assessMediaShareNotOwner =>
      'This profile is now managed from another device, so files can’t be shared from this one.';

  @override
  String get captureRecordTitle => 'Record a video';

  @override
  String get capturePhotoTitle => 'Take a photo';

  @override
  String get captureStart => 'Start recording';

  @override
  String get captureStop => 'Stop';

  @override
  String get captureTakePhoto => 'Take photo';

  @override
  String get captureSwitchCamera => 'Switch camera';

  @override
  String get captureUse => 'Use this video';

  @override
  String get captureUsePhoto => 'Use this photo';

  @override
  String get captureRetake => 'Record again';

  @override
  String get captureRetakePhoto => 'Take again';

  @override
  String get captureClose => 'Close';

  @override
  String get captureRecordingNow => 'Recording';

  @override
  String captureTimeLeft(int seconds) {
    return '$seconds s left';
  }

  @override
  String get captureGetReady => 'Get ready…';

  @override
  String get captureStarted => 'Recording started';

  @override
  String get captureStopped => 'Recording stopped';

  @override
  String captureMaxLength(int seconds) {
    return 'Up to $seconds seconds';
  }

  @override
  String get captureNoCamera => 'This tablet has no camera the app can use.';

  @override
  String get captureDenied =>
      'The camera or microphone is turned off for FlashLearn. Turn them on in the tablet’s settings, then try again.';

  @override
  String get captureFailed => 'The camera could not start. Try again.';

  @override
  String get captureTryAgain => 'Try again';

  @override
  String get captureRecordedHint =>
      'Your video is ready. Use it, or record again.';

  @override
  String get assessMediaRecordVideo => 'Record with the camera';

  @override
  String get assessMediaTakePhoto => 'Take a photo with the camera';

  @override
  String get assessMediaRecordSignTitle => 'Record in FSL';

  @override
  String get assessPictureChoicesHelp =>
      'Add a picture to any choice. Learners who don’t read yet can tap the picture; learners with low vision still hear the words.';

  @override
  String get assessPictureAnswers => 'Picture answers';

  @override
  String assessChoicePictureAdd(String letter) {
    return 'Add a picture to choice $letter';
  }

  @override
  String assessChoicePicture(String letter) {
    return 'Picture for choice $letter';
  }

  @override
  String get assessChoicePictureReplace => 'Replace the picture';

  @override
  String get assessChoicePictureRemove => 'Remove the picture';
}
