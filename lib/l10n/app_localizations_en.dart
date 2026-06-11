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
  String get games => 'Games 🎮';

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
  String get version => 'Version 1.0.0 • Thesis Capstone Project';

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
    return 'Are you sure you want to delete \"$name\"? This cannot be undone.';
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
    return 'No FSL video available yet for \"$word\".';
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
  String get roleStudent => 'Student';

  @override
  String get roleChild => 'Child';

  @override
  String get roleTeacher => 'Teacher';

  @override
  String get roleParent => 'Parent';

  @override
  String get rolePlayerTagline => 'Just play — no progress saved';

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
  String get roleSetupTeacher => 'Set up your profile to manage learners.';

  @override
  String get roleSetupParent => 'Set up your profile to support your child.';

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
  String get wordHuntTapToLearn => 'Tap a word to learn it!';

  @override
  String wordHuntISee(String label) {
    return 'I see… $label';
  }

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
}
