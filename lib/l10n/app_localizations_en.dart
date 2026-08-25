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
  String get recommendedForYou => 'Recommended for you';

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
  String get wordHuntSayTakePhoto => 'Say \"take a photo\"';

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
  String get hearIt => 'Hear it';

  @override
  String heardTryAgain(String spoken) {
    return 'Heard: \"$spoken\" — try again!';
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
}
