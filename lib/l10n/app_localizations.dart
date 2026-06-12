import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fil'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FlashLearn PWD'**
  String get appTitle;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}! 👋'**
  String greeting(String name);

  /// No description provided for @readyToLearn.
  ///
  /// In en, this message translates to:
  /// **'Ready to learn new words today?'**
  String get readyToLearn;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day Streak'**
  String get dayStreak;

  /// No description provided for @words.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get words;

  /// No description provided for @stars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get stars;

  /// No description provided for @vocabularyCategories.
  ///
  /// In en, this message translates to:
  /// **'Vocabulary Categories'**
  String get vocabularyCategories;

  /// No description provided for @quickGames.
  ///
  /// In en, this message translates to:
  /// **'Quick Games'**
  String get quickGames;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get accessibility;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @highContrastMode.
  ///
  /// In en, this message translates to:
  /// **'High Contrast Mode'**
  String get highContrastMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// No description provided for @reducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduced Motion'**
  String get reducedMotion;

  /// No description provided for @dyslexiaMode.
  ///
  /// In en, this message translates to:
  /// **'Dyslexia-friendly'**
  String get dyslexiaMode;

  /// No description provided for @textToSpeech.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get textToSpeech;

  /// No description provided for @speechSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speech Speed'**
  String get speechSpeed;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get soundEffects;

  /// No description provided for @resetAllData.
  ///
  /// In en, this message translates to:
  /// **'Reset All Data'**
  String get resetAllData;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders;

  /// No description provided for @dailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder'**
  String get dailyReminder;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get reminderTime;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streak;

  /// No description provided for @mastery.
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get mastery;

  /// No description provided for @categoryProgress.
  ///
  /// In en, this message translates to:
  /// **'Category Progress'**
  String get categoryProgress;

  /// No description provided for @recentGames.
  ///
  /// In en, this message translates to:
  /// **'Recent Games'**
  String get recentGames;

  /// No description provided for @playGamePrompt.
  ///
  /// In en, this message translates to:
  /// **'Play a game to see your scores here!'**
  String get playGamePrompt;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s Progress'**
  String progressTitle(String name);

  /// No description provided for @games.
  ///
  /// In en, this message translates to:
  /// **'Games 🎮'**
  String get games;

  /// No description provided for @learnWhileHavingFun.
  ///
  /// In en, this message translates to:
  /// **'Learn new words while having fun!'**
  String get learnWhileHavingFun;

  /// No description provided for @chooseDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Choose Difficulty'**
  String get chooseDifficulty;

  /// No description provided for @chooseCategories.
  ///
  /// In en, this message translates to:
  /// **'Choose Categories'**
  String get chooseCategories;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start Game'**
  String get startGame;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correct;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @gameComplete.
  ///
  /// In en, this message translates to:
  /// **'Game Complete!'**
  String get gameComplete;

  /// No description provided for @playAgain.
  ///
  /// In en, this message translates to:
  /// **'Play Again'**
  String get playAgain;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @reviewAnswers.
  ///
  /// In en, this message translates to:
  /// **'Review Answers'**
  String get reviewAnswers;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @hint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hint;

  /// No description provided for @hintsLeft.
  ///
  /// In en, this message translates to:
  /// **'Hint ({count} left)'**
  String hintsLeft(int count);

  /// No description provided for @fillInTheBlank.
  ///
  /// In en, this message translates to:
  /// **'Fill in the blank'**
  String get fillInTheBlank;

  /// No description provided for @spellTheWord.
  ///
  /// In en, this message translates to:
  /// **'Spell the English word'**
  String get spellTheWord;

  /// No description provided for @matchPictureToWord.
  ///
  /// In en, this message translates to:
  /// **'Match the picture to the correct word!'**
  String get matchPictureToWord;

  /// No description provided for @sentenceBuilder.
  ///
  /// In en, this message translates to:
  /// **'Sentence Builder'**
  String get sentenceBuilder;

  /// No description provided for @fillMissingWord.
  ///
  /// In en, this message translates to:
  /// **'Fill in the missing word in the sentence!'**
  String get fillMissingWord;

  /// No description provided for @starShop.
  ///
  /// In en, this message translates to:
  /// **'Star Shop'**
  String get starShop;

  /// No description provided for @avatars.
  ///
  /// In en, this message translates to:
  /// **'Avatars'**
  String get avatars;

  /// No description provided for @themes.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themes;

  /// No description provided for @borders.
  ///
  /// In en, this message translates to:
  /// **'Borders'**
  String get borders;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy!'**
  String get buy;

  /// No description provided for @buyItem.
  ///
  /// In en, this message translates to:
  /// **'Buy {name}?'**
  String buyItem(String name);

  /// No description provided for @notEnoughStars.
  ///
  /// In en, this message translates to:
  /// **'Not enough stars! You need {count} more ⭐'**
  String notEnoughStars(int count);

  /// No description provided for @alreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'You already own this item!'**
  String get alreadyOwned;

  /// No description provided for @purchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'🎉 You got {name}!'**
  String purchaseSuccess(String name);

  /// No description provided for @studyTime.
  ///
  /// In en, this message translates to:
  /// **'Study Time'**
  String get studyTime;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get totalTime;

  /// No description provided for @avgSession.
  ///
  /// In en, this message translates to:
  /// **'Avg Session'**
  String get avgSession;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get last7Days;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @teacherDashboard.
  ///
  /// In en, this message translates to:
  /// **'{role} Dashboard'**
  String teacherDashboard(String role);

  /// No description provided for @overallMastery.
  ///
  /// In en, this message translates to:
  /// **'Overall Mastery'**
  String get overallMastery;

  /// No description provided for @categoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get categoryBreakdown;

  /// No description provided for @insightsRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Insights & Recommendations'**
  String get insightsRecommendations;

  /// No description provided for @needsPractice.
  ///
  /// In en, this message translates to:
  /// **'Needs Practice'**
  String get needsPractice;

  /// No description provided for @doingGreat.
  ///
  /// In en, this message translates to:
  /// **'Doing Great'**
  String get doingGreat;

  /// No description provided for @engagement.
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get engagement;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No game activity yet. Encourage the student to play games!'**
  String get noActivityYet;

  /// No description provided for @exportPdfReport.
  ///
  /// In en, this message translates to:
  /// **'Export PDF Report'**
  String get exportPdfReport;

  /// No description provided for @confirmResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset All Data?'**
  String get confirmResetTitle;

  /// No description provided for @confirmResetMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete all profiles, progress, and settings. This cannot be undone.'**
  String get confirmResetMessage;

  /// No description provided for @dailyWordChallenge.
  ///
  /// In en, this message translates to:
  /// **'Daily Word Challenge'**
  String get dailyWordChallenge;

  /// No description provided for @smartReview.
  ///
  /// In en, this message translates to:
  /// **'Smart Review'**
  String get smartReview;

  /// No description provided for @viewAllStudents.
  ///
  /// In en, this message translates to:
  /// **'View all students'**
  String get viewAllStudents;

  /// No description provided for @openDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open progress dashboard'**
  String get openDashboard;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @openShop.
  ///
  /// In en, this message translates to:
  /// **'Open star shop'**
  String get openShop;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0 • Thesis Capstone Project'**
  String get version;

  /// No description provided for @flashLearnPwd.
  ///
  /// In en, this message translates to:
  /// **'FlashLearn PWD'**
  String get flashLearnPwd;

  /// No description provided for @animals.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get animals;

  /// No description provided for @colorsAndShapes.
  ///
  /// In en, this message translates to:
  /// **'Colors & Shapes'**
  String get colorsAndShapes;

  /// No description provided for @numbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get numbers;

  /// No description provided for @bodyParts.
  ///
  /// In en, this message translates to:
  /// **'Body Parts'**
  String get bodyParts;

  /// No description provided for @foodAndDrinks.
  ///
  /// In en, this message translates to:
  /// **'Food & Drinks'**
  String get foodAndDrinks;

  /// No description provided for @familyAndGreetings.
  ///
  /// In en, this message translates to:
  /// **'Family & Greetings'**
  String get familyAndGreetings;

  /// No description provided for @wordMatch.
  ///
  /// In en, this message translates to:
  /// **'Word Match'**
  String get wordMatch;

  /// No description provided for @spellingBee.
  ///
  /// In en, this message translates to:
  /// **'Spelling Bee'**
  String get spellingBee;

  /// No description provided for @memoryMatch.
  ///
  /// In en, this message translates to:
  /// **'Memory Match'**
  String get memoryMatch;

  /// No description provided for @dragAndDrop.
  ///
  /// In en, this message translates to:
  /// **'Drag & Drop'**
  String get dragAndDrop;

  /// No description provided for @flashcardQuiz.
  ///
  /// In en, this message translates to:
  /// **'Flashcard Quiz'**
  String get flashcardQuiz;

  /// No description provided for @pronunciationPractice.
  ///
  /// In en, this message translates to:
  /// **'Pronunciation Practice'**
  String get pronunciationPractice;

  /// No description provided for @pickVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Pick which vocabulary to practice'**
  String get pickVocabulary;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get badges;

  /// No description provided for @keepItUp.
  ///
  /// In en, this message translates to:
  /// **'Keep it up! Consider trying harder difficulty levels.'**
  String get keepItUp;

  /// No description provided for @focusOn.
  ///
  /// In en, this message translates to:
  /// **'Focus on {category} flashcards and games.'**
  String focusOn(String category);

  /// No description provided for @streakActive.
  ///
  /// In en, this message translates to:
  /// **'{count}-day learning streak active!'**
  String streakActive(int count);

  /// No description provided for @noStreakMessage.
  ///
  /// In en, this message translates to:
  /// **'No active streak. Try daily practice.'**
  String get noStreakMessage;

  /// No description provided for @greatConsistency.
  ///
  /// In en, this message translates to:
  /// **'Great consistency! The student is building a habit.'**
  String get greatConsistency;

  /// No description provided for @encourageDaily.
  ///
  /// In en, this message translates to:
  /// **'Encourage the student to play at least once a day.'**
  String get encourageDaily;

  /// No description provided for @stories.
  ///
  /// In en, this message translates to:
  /// **'Stories 📖'**
  String get stories;

  /// No description provided for @readStoriesAndAnswer.
  ///
  /// In en, this message translates to:
  /// **'Read fun stories and answer questions!'**
  String get readStoriesAndAnswer;

  /// No description provided for @storyQuiz.
  ///
  /// In en, this message translates to:
  /// **'Story Quiz'**
  String get storyQuiz;

  /// No description provided for @takeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Take Quiz'**
  String get takeQuiz;

  /// No description provided for @nextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next Question'**
  String get nextQuestion;

  /// No description provided for @seeResults.
  ///
  /// In en, this message translates to:
  /// **'See Results'**
  String get seeResults;

  /// No description provided for @storySentences.
  ///
  /// In en, this message translates to:
  /// **'{count} sentences'**
  String storySentences(int count);

  /// No description provided for @storyQuestions.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String storyQuestions(int count);

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @tapToRead.
  ///
  /// In en, this message translates to:
  /// **'Tap to read'**
  String get tapToRead;

  /// No description provided for @switchToFilipino.
  ///
  /// In en, this message translates to:
  /// **'Switch to Filipino'**
  String get switchToFilipino;

  /// No description provided for @switchToEnglish.
  ///
  /// In en, this message translates to:
  /// **'Switch to English'**
  String get switchToEnglish;

  /// No description provided for @readAloud.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get readAloud;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupAndRestore;

  /// No description provided for @saveOrRestoreData.
  ///
  /// In en, this message translates to:
  /// **'Save or restore all app data'**
  String get saveOrRestoreData;

  /// No description provided for @classroomMode.
  ///
  /// In en, this message translates to:
  /// **'Classroom Mode'**
  String get classroomMode;

  /// No description provided for @monitorStudents.
  ///
  /// In en, this message translates to:
  /// **'Monitor all students in real time'**
  String get monitorStudents;

  /// No description provided for @classroomView.
  ///
  /// In en, this message translates to:
  /// **'Classroom View'**
  String get classroomView;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get idle;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get students;

  /// No description provided for @noStudentProfiles.
  ///
  /// In en, this message translates to:
  /// **'No student profiles found'**
  String get noStudentProfiles;

  /// No description provided for @accuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get accuracy;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get lastUpdated;

  /// No description provided for @voiceNavigation.
  ///
  /// In en, this message translates to:
  /// **'Voice-Guided Navigation'**
  String get voiceNavigation;

  /// No description provided for @voiceNavigationDesc.
  ///
  /// In en, this message translates to:
  /// **'Announce screens aloud'**
  String get voiceNavigationDesc;

  /// No description provided for @adaptiveDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Adaptive Difficulty'**
  String get adaptiveDifficulty;

  /// No description provided for @adaptiveDifficultyDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-suggest game difficulty'**
  String get adaptiveDifficultyDesc;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome! 👋'**
  String get welcome;

  /// No description provided for @whoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Who are you?'**
  String get whoAreYou;

  /// No description provided for @whatsYourName.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get whatsYourName;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name...'**
  String get enterYourName;

  /// No description provided for @chooseYourAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose your avatar'**
  String get chooseYourAvatar;

  /// No description provided for @letsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Go!'**
  String get letsGo;

  /// No description provided for @iWantToLearn.
  ///
  /// In en, this message translates to:
  /// **'I want to learn new words!'**
  String get iWantToLearn;

  /// No description provided for @iWantToHelp.
  ///
  /// In en, this message translates to:
  /// **'I want to help students learn'**
  String get iWantToHelp;

  /// No description provided for @iWantToSupport.
  ///
  /// In en, this message translates to:
  /// **'I want to support my child'**
  String get iWantToSupport;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back! 👋'**
  String get welcomeBack;

  /// No description provided for @chooseYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Choose your profile'**
  String get chooseYourProfile;

  /// No description provided for @addNewProfile.
  ///
  /// In en, this message translates to:
  /// **'Add New Profile'**
  String get addNewProfile;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN for {name}'**
  String enterPin(String name);

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. Try again.'**
  String get wrongPin;

  /// No description provided for @setPin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get setPin;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @removePin.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get removePin;

  /// No description provided for @pinRemoved.
  ///
  /// In en, this message translates to:
  /// **'PIN removed'**
  String get pinRemoved;

  /// No description provided for @pinSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN set successfully!'**
  String get pinSetSuccess;

  /// No description provided for @pinMustBe4Digits.
  ///
  /// In en, this message translates to:
  /// **'PIN must be exactly 4 digits'**
  String get pinMustBe4Digits;

  /// No description provided for @pinsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinsDoNotMatch;

  /// No description provided for @enterPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPinLabel;

  /// No description provided for @confirmPinLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get confirmPinLabel;

  /// No description provided for @choosePin.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN to protect your profile.'**
  String get choosePin;

  /// No description provided for @accessibilitySetup.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Setup'**
  String get accessibilitySetup;

  /// No description provided for @weWillOptimize.
  ///
  /// In en, this message translates to:
  /// **'We\'ll optimize the app for your needs.\nSelect the option that best describes you:'**
  String get weWillOptimize;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @recommendedSettings.
  ///
  /// In en, this message translates to:
  /// **'Recommended Settings'**
  String get recommendedSettings;

  /// No description provided for @noSpecialSettings.
  ///
  /// In en, this message translates to:
  /// **'No special settings needed!\nYou\'re all set with the defaults.'**
  String get noSpecialSettings;

  /// No description provided for @weWillApplySettings.
  ///
  /// In en, this message translates to:
  /// **'We\'ll apply these settings for {type}:'**
  String weWillApplySettings(String type);

  /// No description provided for @changeInSettings.
  ///
  /// In en, this message translates to:
  /// **'You can change these anytime in Settings ⚙️'**
  String get changeInSettings;

  /// No description provided for @applyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Apply & Continue'**
  String get applyAndContinue;

  /// No description provided for @youreAllSet.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set! 🎉'**
  String get youreAllSet;

  /// No description provided for @welcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String welcomeName(String name);

  /// No description provided for @appOptimizedFor.
  ///
  /// In en, this message translates to:
  /// **'Your app has been optimized for\n{type}'**
  String appOptimizedFor(String type);

  /// No description provided for @standardSettings.
  ///
  /// In en, this message translates to:
  /// **'Standard settings are ready to go.'**
  String get standardSettings;

  /// No description provided for @adjustAnytime.
  ///
  /// In en, this message translates to:
  /// **'You can adjust all settings anytime\nfrom the Settings page.'**
  String get adjustAnytime;

  /// No description provided for @letsStartLearning.
  ///
  /// In en, this message translates to:
  /// **'Let\'s Start Learning!'**
  String get letsStartLearning;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @flashcardDecks.
  ///
  /// In en, this message translates to:
  /// **'Flashcard Decks'**
  String get flashcardDecks;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category to start learning!'**
  String get chooseCategory;

  /// No description provided for @importLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importLabel;

  /// No description provided for @exportLabel.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportLabel;

  /// No description provided for @importedCards.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} flashcard(s)!'**
  String importedCards(int count);

  /// No description provided for @noDuplicates.
  ///
  /// In en, this message translates to:
  /// **'No new cards to import (all duplicates or cancelled).'**
  String get noDuplicates;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed — check the file format.'**
  String get importFailed;

  /// No description provided for @createCard.
  ///
  /// In en, this message translates to:
  /// **'Create Card'**
  String get createCard;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'{count} cards'**
  String cards(int count);

  /// No description provided for @deleteFlashcard.
  ///
  /// In en, this message translates to:
  /// **'Delete Flashcard?'**
  String get deleteFlashcard;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This cannot be undone.'**
  String deleteConfirm(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @flashcardDeleted.
  ///
  /// In en, this message translates to:
  /// **'Flashcard deleted'**
  String get flashcardDeleted;

  /// No description provided for @customCard.
  ///
  /// In en, this message translates to:
  /// **'Custom Card'**
  String get customCard;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @filipino.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get filipino;

  /// No description provided for @fsl.
  ///
  /// In en, this message translates to:
  /// **'FSL'**
  String get fsl;

  /// No description provided for @flip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get flip;

  /// No description provided for @filipinoSignLanguage.
  ///
  /// In en, this message translates to:
  /// **'Filipino Sign Language'**
  String get filipinoSignLanguage;

  /// No description provided for @noFslVideo.
  ///
  /// In en, this message translates to:
  /// **'No FSL video available yet for \"{word}\".'**
  String noFslVideo(String word);

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get gotIt;

  /// No description provided for @tapToSeeMore.
  ///
  /// In en, this message translates to:
  /// **'Tap to see more ✨'**
  String get tapToSeeMore;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get details;

  /// No description provided for @example.
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get example;

  /// No description provided for @tapToFlipBack.
  ///
  /// In en, this message translates to:
  /// **'Tap to flip back'**
  String get tapToFlipBack;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed:'**
  String get speed;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replay;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @unableToLoadVideo.
  ///
  /// In en, this message translates to:
  /// **'Unable to load video'**
  String get unableToLoadVideo;

  /// No description provided for @fslDictionary.
  ///
  /// In en, this message translates to:
  /// **'FSL Dictionary 🤟'**
  String get fslDictionary;

  /// No description provided for @searchWords.
  ///
  /// In en, this message translates to:
  /// **'Search words...'**
  String get searchWords;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @wordsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wordsCount(int count);

  /// No description provided for @videosWatched.
  ///
  /// In en, this message translates to:
  /// **'{count} videos watched'**
  String videosWatched(int count);

  /// No description provided for @noWordsFound.
  ///
  /// In en, this message translates to:
  /// **'No words found'**
  String get noWordsFound;

  /// No description provided for @noWordsToReview.
  ///
  /// In en, this message translates to:
  /// **'No words to review!'**
  String get noWordsToReview;

  /// No description provided for @playGamesFirst.
  ///
  /// In en, this message translates to:
  /// **'Play some games first to build up your word data.'**
  String get playGamesFirst;

  /// No description provided for @showAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show Answer'**
  String get showAnswer;

  /// No description provided for @stillLearning.
  ///
  /// In en, this message translates to:
  /// **'Still Learning'**
  String get stillLearning;

  /// No description provided for @iKnowIt.
  ///
  /// In en, this message translates to:
  /// **'I Know It!'**
  String get iKnowIt;

  /// No description provided for @reviewComplete.
  ///
  /// In en, this message translates to:
  /// **'Review Complete!'**
  String get reviewComplete;

  /// No description provided for @greatRecall.
  ///
  /// In en, this message translates to:
  /// **'Great recall! Keep it up!'**
  String get greatRecall;

  /// No description provided for @keepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep practicing — you\'ll get there!'**
  String get keepPracticing;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @reviewAgain.
  ///
  /// In en, this message translates to:
  /// **'Review Again'**
  String get reviewAgain;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @dragInstruction.
  ///
  /// In en, this message translates to:
  /// **'Drag the English word to its Filipino match!'**
  String get dragInstruction;

  /// No description provided for @tracing.
  ///
  /// In en, this message translates to:
  /// **'Tracing'**
  String get tracing;

  /// No description provided for @traceWord.
  ///
  /// In en, this message translates to:
  /// **'Trace: {word}'**
  String traceWord(String word);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @whatIsThisWord.
  ///
  /// In en, this message translates to:
  /// **'What is this word?'**
  String get whatIsThisWord;

  /// No description provided for @moves.
  ///
  /// In en, this message translates to:
  /// **'{count} moves'**
  String moves(int count);

  /// No description provided for @matched.
  ///
  /// In en, this message translates to:
  /// **'Matched: {current} / {total}'**
  String matched(int current, int total);

  /// No description provided for @stillLearningSwipe.
  ///
  /// In en, this message translates to:
  /// **'← Still\nLearning'**
  String get stillLearningSwipe;

  /// No description provided for @iKnowThisSwipe.
  ///
  /// In en, this message translates to:
  /// **'I Know\nThis! →'**
  String get iKnowThisSwipe;

  /// No description provided for @learning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get learning;

  /// No description provided for @iKnow.
  ///
  /// In en, this message translates to:
  /// **'I Know!'**
  String get iKnow;

  /// No description provided for @amazing.
  ///
  /// In en, this message translates to:
  /// **'🎉 Amazing!'**
  String get amazing;

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'💪 Keep Going!'**
  String get keepGoing;

  /// No description provided for @percentMastered.
  ///
  /// In en, this message translates to:
  /// **'{percent}% mastered'**
  String percentMastered(int percent);

  /// No description provided for @reviewWords.
  ///
  /// In en, this message translates to:
  /// **'Review Words'**
  String get reviewWords;

  /// No description provided for @again.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get again;

  /// No description provided for @listenAndPick.
  ///
  /// In en, this message translates to:
  /// **'Listen & Pick'**
  String get listenAndPick;

  /// No description provided for @listenEnglish.
  ///
  /// In en, this message translates to:
  /// **'Listen to the English word'**
  String get listenEnglish;

  /// No description provided for @listenFilipino.
  ///
  /// In en, this message translates to:
  /// **'Listen to the Filipino word'**
  String get listenFilipino;

  /// No description provided for @pickFilipino.
  ///
  /// In en, this message translates to:
  /// **'Pick the Filipino match!'**
  String get pickFilipino;

  /// No description provided for @pickEnglish.
  ///
  /// In en, this message translates to:
  /// **'Pick the English match!'**
  String get pickEnglish;

  /// No description provided for @tapSpeakerReplay.
  ///
  /// In en, this message translates to:
  /// **'🔊 Tap speaker to replay'**
  String get tapSpeakerReplay;

  /// No description provided for @noWordsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No words available for this category.'**
  String get noWordsAvailable;

  /// No description provided for @storyNotFound.
  ///
  /// In en, this message translates to:
  /// **'Story Not Found'**
  String get storyNotFound;

  /// No description provided for @storyNotFoundMsg.
  ///
  /// In en, this message translates to:
  /// **'Story not found.'**
  String get storyNotFoundMsg;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBack;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @quizNotFound.
  ///
  /// In en, this message translates to:
  /// **'Quiz Not Found'**
  String get quizNotFound;

  /// No description provided for @questionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionOf(int current, int total);

  /// No description provided for @equipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get equipped;

  /// No description provided for @tapToEquip.
  ///
  /// In en, this message translates to:
  /// **'Tap to Equip'**
  String get tapToEquip;

  /// No description provided for @starsAmount.
  ///
  /// In en, this message translates to:
  /// **'{count} stars'**
  String starsAmount(int count);

  /// No description provided for @viewLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'View Leaderboard'**
  String get viewLeaderboard;

  /// No description provided for @detailedAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Detailed Analytics'**
  String get detailedAnalytics;

  /// No description provided for @starCollection.
  ///
  /// In en, this message translates to:
  /// **'Star Collection'**
  String get starCollection;

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @leaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard 🏆'**
  String get leaderboard;

  /// No description provided for @noEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'No entries yet.\nPlay games and learn words to rank up!'**
  String get noEntriesYet;

  /// No description provided for @activeTotal.
  ///
  /// In en, this message translates to:
  /// **'{active} active / {total} total'**
  String activeTotal(int active, int total);

  /// No description provided for @createStudentMsg.
  ///
  /// In en, this message translates to:
  /// **'Students appear here after joining your class with a code.\nShare the class code from Manage Classes to invite them.'**
  String get createStudentMsg;

  /// No description provided for @switchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchProfile;

  /// No description provided for @clothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get clothing;

  /// No description provided for @weather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// No description provided for @classroom.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get classroom;

  /// No description provided for @transportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get transportation;

  /// No description provided for @emotions.
  ///
  /// In en, this message translates to:
  /// **'Emotions'**
  String get emotions;

  /// No description provided for @daysAndTime.
  ///
  /// In en, this message translates to:
  /// **'Days & Time'**
  String get daysAndTime;

  /// No description provided for @speechToText.
  ///
  /// In en, this message translates to:
  /// **'Speech-to-Text'**
  String get speechToText;

  /// No description provided for @fslPractice.
  ///
  /// In en, this message translates to:
  /// **'FSL Practice'**
  String get fslPractice;

  /// No description provided for @fslPracticeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn Filipino Sign Language!'**
  String get fslPracticeSubtitle;

  /// No description provided for @signToWord.
  ///
  /// In en, this message translates to:
  /// **'Sign → Word'**
  String get signToWord;

  /// No description provided for @wordToSign.
  ///
  /// In en, this message translates to:
  /// **'Word → Sign'**
  String get wordToSign;

  /// No description provided for @signToWordDesc.
  ///
  /// In en, this message translates to:
  /// **'Watch a sign language video, then pick the correct word.'**
  String get signToWordDesc;

  /// No description provided for @wordToSignDesc.
  ///
  /// In en, this message translates to:
  /// **'See a word, then pick which video shows the correct sign.'**
  String get wordToSignDesc;

  /// No description provided for @whatSignIsThis.
  ///
  /// In en, this message translates to:
  /// **'What word is this sign?'**
  String get whatSignIsThis;

  /// No description provided for @whichSignMeans.
  ///
  /// In en, this message translates to:
  /// **'Which sign means…'**
  String get whichSignMeans;

  /// No description provided for @notEnoughFslVideos.
  ///
  /// In en, this message translates to:
  /// **'Not enough FSL videos available for the selected categories.'**
  String get notEnoughFslVideos;

  /// No description provided for @fslPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Filipino Sign Language Practice'**
  String get fslPracticeTitle;

  /// No description provided for @fslPracticeDesc.
  ///
  /// In en, this message translates to:
  /// **'Watch sign language videos and test your knowledge.\nChoose a practice mode below!'**
  String get fslPracticeDesc;

  /// No description provided for @parentDashboard.
  ///
  /// In en, this message translates to:
  /// **'Parent Dashboard'**
  String get parentDashboard;

  /// No description provided for @familyOverview.
  ///
  /// In en, this message translates to:
  /// **'Family Overview'**
  String get familyOverview;

  /// No description provided for @yourChildren.
  ///
  /// In en, this message translates to:
  /// **'Your Children'**
  String get yourChildren;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @recommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get recommendations;

  /// No description provided for @wordsLearned.
  ///
  /// In en, this message translates to:
  /// **'Words Learned'**
  String get wordsLearned;

  /// No description provided for @activeToday.
  ///
  /// In en, this message translates to:
  /// **'Active today'**
  String get activeToday;

  /// No description provided for @lastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get lastActive;

  /// No description provided for @strengthsAndAreas.
  ///
  /// In en, this message translates to:
  /// **'Strengths & Areas to Improve'**
  String get strengthsAndAreas;

  /// No description provided for @createProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Profile'**
  String get createProfile;

  /// No description provided for @encouragePractice.
  ///
  /// In en, this message translates to:
  /// **'Encourage {name} to practice'**
  String encouragePractice(Object name);

  /// No description provided for @keepUpGreatWork.
  ///
  /// In en, this message translates to:
  /// **'Keep up the great work!'**
  String get keepUpGreatWork;

  /// No description provided for @learnWordsThrough.
  ///
  /// In en, this message translates to:
  /// **'Learn words through play! ✨'**
  String get learnWordsThrough;

  /// No description provided for @gettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting ready...'**
  String get gettingReady;

  /// No description provided for @fslFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fslFullscreen;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit Fullscreen'**
  String get exitFullscreen;

  /// No description provided for @rotateForLandscape.
  ///
  /// In en, this message translates to:
  /// **'Rotate or double-tap for landscape'**
  String get rotateForLandscape;

  /// No description provided for @hideCaptions.
  ///
  /// In en, this message translates to:
  /// **'Hide captions'**
  String get hideCaptions;

  /// No description provided for @showCaptions.
  ///
  /// In en, this message translates to:
  /// **'Show captions'**
  String get showCaptions;

  /// No description provided for @playbackSpeedSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback speed settings'**
  String get playbackSpeedSettings;

  /// No description provided for @closeFullscreenVideo.
  ///
  /// In en, this message translates to:
  /// **'Close fullscreen video'**
  String get closeFullscreenVideo;

  /// No description provided for @replayFromBeginning.
  ///
  /// In en, this message translates to:
  /// **'Replay from beginning'**
  String get replayFromBeginning;

  /// No description provided for @switchToPortrait.
  ///
  /// In en, this message translates to:
  /// **'Switch to portrait'**
  String get switchToPortrait;

  /// No description provided for @switchToLandscape.
  ///
  /// In en, this message translates to:
  /// **'Switch to landscape'**
  String get switchToLandscape;

  /// No description provided for @videoProgress.
  ///
  /// In en, this message translates to:
  /// **'Video progress'**
  String get videoProgress;

  /// No description provided for @pauseVideo.
  ///
  /// In en, this message translates to:
  /// **'Pause video'**
  String get pauseVideo;

  /// No description provided for @playVideo.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get playVideo;

  /// No description provided for @setSpeedTo.
  ///
  /// In en, this message translates to:
  /// **'Set speed to {speed}x'**
  String setSpeedTo(String speed);

  /// No description provided for @pinLockedTryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again in {duration}.'**
  String pinLockedTryAgainIn(String duration);

  /// No description provided for @forgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get forgotPin;

  /// No description provided for @recoveryCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your recovery code'**
  String get recoveryCodeTitle;

  /// No description provided for @recoveryCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Write this down. You\'ll need it if you forget your PIN. We can\'t show it again.'**
  String get recoveryCodeSubtitle;

  /// No description provided for @recoveryCodeConfirm.
  ///
  /// In en, this message translates to:
  /// **'I\'ve saved it'**
  String get recoveryCodeConfirm;

  /// No description provided for @enterRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery code'**
  String get enterRecoveryCode;

  /// No description provided for @recoveryCodeWrong.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t match.'**
  String get recoveryCodeWrong;

  /// No description provided for @recoveryViaEducatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask a teacher or parent'**
  String get recoveryViaEducatorTitle;

  /// No description provided for @recoveryViaEducatorPrompt.
  ///
  /// In en, this message translates to:
  /// **'Have a teacher or parent enter their PIN to reset {name}\'s PIN.'**
  String recoveryViaEducatorPrompt(String name);

  /// No description provided for @recoveryNoEducator.
  ///
  /// In en, this message translates to:
  /// **'No teacher or parent profile is set up on this device. Ask an adult to add one, or remove the profile to start over.'**
  String get recoveryNoEducator;

  /// No description provided for @pinResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN reset. Set a new one.'**
  String get pinResetSuccess;

  /// No description provided for @pinChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN updated.'**
  String get pinChangedSuccess;

  /// No description provided for @setNewPin.
  ///
  /// In en, this message translates to:
  /// **'Set a new PIN'**
  String get setNewPin;

  /// No description provided for @regenerateRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Regenerate recovery code'**
  String get regenerateRecoveryCode;

  /// No description provided for @showRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Show recovery code'**
  String get showRecoveryCode;

  /// No description provided for @setUpProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Up Profile'**
  String get setUpProfileTitle;

  /// No description provided for @letsSetUpProfile.
  ///
  /// In en, this message translates to:
  /// **'Let\'s set up your profile'**
  String get letsSetUpProfile;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterName;

  /// No description provided for @nameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get nameMinLength;

  /// No description provided for @ageOrBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Age / Birth Date'**
  String get ageOrBirthDate;

  /// No description provided for @tapToSelectBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Tap to select birth date'**
  String get tapToSelectBirthDate;

  /// No description provided for @selectBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Select birth date'**
  String get selectBirthDate;

  /// No description provided for @pleaseSelectBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a birth date'**
  String get pleaseSelectBirthDate;

  /// No description provided for @yearsOld.
  ///
  /// In en, this message translates to:
  /// **'{count} yrs old'**
  String yearsOld(int count);

  /// No description provided for @suggestedLevel.
  ///
  /// In en, this message translates to:
  /// **'✨ Suggested level: {level}'**
  String suggestedLevel(String level);

  /// No description provided for @pinProtection.
  ///
  /// In en, this message translates to:
  /// **'PIN Protection'**
  String get pinProtection;

  /// No description provided for @pinProtectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Add a 4-digit PIN to protect this profile'**
  String get pinProtectionDescription;

  /// No description provided for @enablePinLock.
  ///
  /// In en, this message translates to:
  /// **'Enable PIN lock'**
  String get enablePinLock;

  /// No description provided for @enterFourDigitPin.
  ///
  /// In en, this message translates to:
  /// **'Enter 4-digit PIN'**
  String get enterFourDigitPin;

  /// No description provided for @pinDigitsOnly.
  ///
  /// In en, this message translates to:
  /// **'PIN must contain only digits'**
  String get pinDigitsOnly;

  /// No description provided for @iHaveRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'I have a recovery code'**
  String get iHaveRecoveryCode;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @rolePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get rolePlayer;

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get roleStudent;

  /// No description provided for @roleChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get roleChild;

  /// No description provided for @roleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get roleTeacher;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleParent;

  /// No description provided for @rolePlayerTagline.
  ///
  /// In en, this message translates to:
  /// **'Just play — no progress saved'**
  String get rolePlayerTagline;

  /// No description provided for @roleStudentTagline.
  ///
  /// In en, this message translates to:
  /// **'Join with a class code'**
  String get roleStudentTagline;

  /// No description provided for @roleChildTagline.
  ///
  /// In en, this message translates to:
  /// **'Join with a home-group code'**
  String get roleChildTagline;

  /// No description provided for @roleTeacherTagline.
  ///
  /// In en, this message translates to:
  /// **'I want to help'**
  String get roleTeacherTagline;

  /// No description provided for @roleParentTagline.
  ///
  /// In en, this message translates to:
  /// **'I want to support'**
  String get roleParentTagline;

  /// No description provided for @roleSetupPlayer.
  ///
  /// In en, this message translates to:
  /// **'Guest mode — progress is saved on this device only.'**
  String get roleSetupPlayer;

  /// No description provided for @roleSetupTeacher.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile to manage learners.'**
  String get roleSetupTeacher;

  /// No description provided for @roleSetupParent.
  ///
  /// In en, this message translates to:
  /// **'Set up your profile to support your child.'**
  String get roleSetupParent;

  /// No description provided for @youJoined.
  ///
  /// In en, this message translates to:
  /// **'You joined {name}.'**
  String youJoined(String name);

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @welcomeSlide1Title.
  ///
  /// In en, this message translates to:
  /// **'Learn Filipino Sign Language'**
  String get welcomeSlide1Title;

  /// No description provided for @welcomeSlide1Body.
  ///
  /// In en, this message translates to:
  /// **'Fun flashcards, games, and FSL videos to build vocabulary every day.'**
  String get welcomeSlide1Body;

  /// No description provided for @welcomeSlide2Title.
  ///
  /// In en, this message translates to:
  /// **'Made for every learner'**
  String get welcomeSlide2Title;

  /// No description provided for @welcomeSlide2Body.
  ///
  /// In en, this message translates to:
  /// **'Students, children, teachers, and parents — each gets a setup that fits.'**
  String get welcomeSlide2Body;

  /// No description provided for @welcomeSlide3Title.
  ///
  /// In en, this message translates to:
  /// **'Accessible by design'**
  String get welcomeSlide3Title;

  /// No description provided for @welcomeSlide3Body.
  ///
  /// In en, this message translates to:
  /// **'High-contrast, dyslexia-friendly, text-to-speech, and reduced-motion options are built in.'**
  String get welcomeSlide3Body;

  /// No description provided for @splashLoadingResources.
  ///
  /// In en, this message translates to:
  /// **'Loading resources...'**
  String get splashLoadingResources;

  /// No description provided for @splashPreparingCards.
  ///
  /// In en, this message translates to:
  /// **'Preparing your cards...'**
  String get splashPreparingCards;

  /// No description provided for @splashAlmostReady.
  ///
  /// In en, this message translates to:
  /// **'Almost ready!'**
  String get splashAlmostReady;

  /// No description provided for @wordHuntTitle.
  ///
  /// In en, this message translates to:
  /// **'Word Hunt'**
  String get wordHuntTitle;

  /// No description provided for @wordHuntPointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at an object!'**
  String get wordHuntPointCamera;

  /// No description provided for @wordHuntTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo!'**
  String get wordHuntTakePhoto;

  /// No description provided for @wordHuntLooking.
  ///
  /// In en, this message translates to:
  /// **'Looking at your photo…'**
  String get wordHuntLooking;

  /// No description provided for @wordHuntFoundWords.
  ///
  /// In en, this message translates to:
  /// **'I found these words — tap one!'**
  String get wordHuntFoundWords;

  /// No description provided for @wordHuntNoneFound.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t find a word in this photo. Get closer and try again!'**
  String get wordHuntNoneFound;

  /// No description provided for @wordHuntRetake.
  ///
  /// In en, this message translates to:
  /// **'New photo'**
  String get wordHuntRetake;

  /// No description provided for @wordHuntNoCamera.
  ///
  /// In en, this message translates to:
  /// **'This device has no camera, so Word Hunt can\'t run here.'**
  String get wordHuntNoCamera;

  /// No description provided for @wordHuntCameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Word Hunt needs the camera to find objects around you. Please allow camera access.'**
  String get wordHuntCameraDenied;

  /// No description provided for @wordHuntCameraError.
  ///
  /// In en, this message translates to:
  /// **'The camera couldn\'t start. Please try again.'**
  String get wordHuntCameraError;

  /// No description provided for @wordHuntNewWord.
  ///
  /// In en, this message translates to:
  /// **'New word found! +1 ⭐'**
  String get wordHuntNewWord;

  /// No description provided for @wordHuntGreatFind.
  ///
  /// In en, this message translates to:
  /// **'New word found! Great job!'**
  String get wordHuntGreatFind;

  /// No description provided for @wordHuntSpeakEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get wordHuntSpeakEnglish;

  /// No description provided for @wordHuntSpeakFilipino.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get wordHuntSpeakFilipino;

  /// No description provided for @wordHuntFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get wordHuntFlashcards;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fil':
      return AppLocalizationsFil();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
