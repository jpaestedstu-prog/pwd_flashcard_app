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
  /// **'Games'**
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

  /// No description provided for @titles.
  ///
  /// In en, this message translates to:
  /// **'Titles'**
  String get titles;

  /// No description provided for @sounds.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get sounds;

  /// No description provided for @effects.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get effects;

  /// No description provided for @themeOverriddenByContrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast is on, so this theme won\'t change your colours until you turn it off.'**
  String get themeOverriddenByContrast;

  /// No description provided for @themeOverriddenByDyslexia.
  ///
  /// In en, this message translates to:
  /// **'Dyslexia-friendly mode is on, so this theme won\'t change your colours until you turn it off.'**
  String get themeOverriddenByDyslexia;

  /// No description provided for @effectPlaysGently.
  ///
  /// In en, this message translates to:
  /// **'Reduced Motion is on, so this effect will play gently.'**
  String get effectPlaysGently;

  /// No description provided for @soundPackNeedsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects are off, so this pack won\'t be heard until you turn them on.'**
  String get soundPackNeedsSound;

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get recommendedForYou;

  /// No description provided for @seeIt.
  ///
  /// In en, this message translates to:
  /// **'See it'**
  String get seeIt;

  /// No description provided for @hearIt.
  ///
  /// In en, this message translates to:
  /// **'Hear it'**
  String get hearIt;

  /// No description provided for @previewOf.
  ///
  /// In en, this message translates to:
  /// **'Preview of {name}'**
  String previewOf(String name);

  /// No description provided for @starsToGo.
  ///
  /// In en, this message translates to:
  /// **'{count} more stars to go'**
  String starsToGo(int count);

  /// No description provided for @keepEarning.
  ///
  /// In en, this message translates to:
  /// **'Keep earning'**
  String get keepEarning;

  /// No description provided for @goodToKnow.
  ///
  /// In en, this message translates to:
  /// **'Good to know'**
  String get goodToKnow;

  /// No description provided for @itemNotReady.
  ///
  /// In en, this message translates to:
  /// **'{name} is not ready yet.'**
  String itemNotReady(String name);

  /// No description provided for @starsRefunded.
  ///
  /// In en, this message translates to:
  /// **'⭐ {count} stars are back — something you bought isn\'t ready yet, so we returned it.'**
  String starsRefunded(int count);

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
  /// **'Version 1.1.0 • Thesis Capstone Project'**
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
  /// **'Are you sure you want to delete “{name}”? This cannot be undone.'**
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
  /// **'No FSL video available yet for “{word}”.'**
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

  /// No description provided for @rolePlayerGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest Player'**
  String get rolePlayerGuest;

  /// No description provided for @rolePlayerProgress.
  ///
  /// In en, this message translates to:
  /// **'Player (with Progress)'**
  String get rolePlayerProgress;

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student Profile (PWD)'**
  String get roleStudent;

  /// No description provided for @roleChild.
  ///
  /// In en, this message translates to:
  /// **'Child Profile (PWD)'**
  String get roleChild;

  /// No description provided for @roleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher Profile'**
  String get roleTeacher;

  /// No description provided for @roleParent.
  ///
  /// In en, this message translates to:
  /// **'Parent/Guardian Profile'**
  String get roleParent;

  /// No description provided for @groupPlayerProfiles.
  ///
  /// In en, this message translates to:
  /// **'Player Profiles'**
  String get groupPlayerProfiles;

  /// No description provided for @groupPlayerProfilesDesc.
  ///
  /// In en, this message translates to:
  /// **'For gameplay and PWD awareness learning.'**
  String get groupPlayerProfilesDesc;

  /// No description provided for @groupClassroom.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get groupClassroom;

  /// No description provided for @groupClassroomDesc.
  ///
  /// In en, this message translates to:
  /// **'Teacher-managed learning environment.'**
  String get groupClassroomDesc;

  /// No description provided for @groupFamily.
  ///
  /// In en, this message translates to:
  /// **'Family Group'**
  String get groupFamily;

  /// No description provided for @groupFamilyDesc.
  ///
  /// In en, this message translates to:
  /// **'Parent/Guardian-managed learning environment.'**
  String get groupFamilyDesc;

  /// No description provided for @rolePlayerTagline.
  ///
  /// In en, this message translates to:
  /// **'Just play — no progress saved'**
  String get rolePlayerTagline;

  /// No description provided for @rolePlayerGuestTagline.
  ///
  /// In en, this message translates to:
  /// **'Jump in and play — stays on this device, not backed up'**
  String get rolePlayerGuestTagline;

  /// No description provided for @rolePlayerProgressTagline.
  ///
  /// In en, this message translates to:
  /// **'Save your XP, streaks & badges and back them up'**
  String get rolePlayerProgressTagline;

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

  /// No description provided for @roleSetupPlayerGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest mode — play freely. Progress stays on this device and isn\'t backed up.'**
  String get roleSetupPlayerGuest;

  /// No description provided for @roleSetupPlayerProgress.
  ///
  /// In en, this message translates to:
  /// **'Your XP, streaks and badges are kept. Add a PIN to back up and restore on another device.'**
  String get roleSetupPlayerProgress;

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

  /// No description provided for @pwdAwarenessEntry.
  ///
  /// In en, this message translates to:
  /// **'Learn about PWD awareness'**
  String get pwdAwarenessEntry;

  /// No description provided for @pwdAwarenessTitle.
  ///
  /// In en, this message translates to:
  /// **'PWD Awareness'**
  String get pwdAwarenessTitle;

  /// No description provided for @pwdAwarenessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Understanding & respecting Persons with Disabilities'**
  String get pwdAwarenessSubtitle;

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

  /// No description provided for @wordHuntFlipCamera.
  ///
  /// In en, this message translates to:
  /// **'Flip camera'**
  String get wordHuntFlipCamera;

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

  /// No description provided for @wordHuntMeaning.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get wordHuntMeaning;

  /// No description provided for @wordHuntMyFinds.
  ///
  /// In en, this message translates to:
  /// **'My Finds'**
  String get wordHuntMyFinds;

  /// No description provided for @wordHuntCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'🎒 My Finds'**
  String get wordHuntCollectionTitle;

  /// No description provided for @wordHuntFoundOf.
  ///
  /// In en, this message translates to:
  /// **'{found} of {total} words found'**
  String wordHuntFoundOf(int found, int total);

  /// No description provided for @wordHuntStarsToday.
  ///
  /// In en, this message translates to:
  /// **'{earned} of {cap} camera stars today'**
  String wordHuntStarsToday(int earned, int cap);

  /// No description provided for @wordHuntCollectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t found any words yet. Point the camera at something around you!'**
  String get wordHuntCollectionEmpty;

  /// No description provided for @wordHuntStartHunting.
  ///
  /// In en, this message translates to:
  /// **'Start hunting'**
  String get wordHuntStartHunting;

  /// No description provided for @wordHuntStillToFind.
  ///
  /// In en, this message translates to:
  /// **'Still to find'**
  String get wordHuntStillToFind;

  /// No description provided for @wordHuntFound.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get wordHuntFound;

  /// No description provided for @wordHuntTargets.
  ///
  /// In en, this message translates to:
  /// **'Try to find:'**
  String get wordHuntTargets;

  /// No description provided for @wordHuntNewBadge.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get wordHuntNewBadge;

  /// No description provided for @wordHuntAllFound.
  ///
  /// In en, this message translates to:
  /// **'You found every word the camera knows. Amazing! 🏆'**
  String get wordHuntAllFound;

  /// No description provided for @wordHuntSpokenFound.
  ///
  /// In en, this message translates to:
  /// **'I found {count} words: {words}'**
  String wordHuntSpokenFound(int count, String words);

  /// No description provided for @wordHuntSayTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Say “take a photo”'**
  String get wordHuntSayTakePhoto;

  /// No description provided for @wordHuntFoundTarget.
  ///
  /// In en, this message translates to:
  /// **'Found it! {words} was on your list.'**
  String wordHuntFoundTarget(String words);

  /// No description provided for @wordHuntFoundTargets.
  ///
  /// In en, this message translates to:
  /// **'Found them! {words} were on your list.'**
  String wordHuntFoundTargets(String words);

  /// No description provided for @wordHuntStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{days}-day hunt streak'**
  String wordHuntStreakDays(int days);

  /// No description provided for @wordHuntFindsToday.
  ///
  /// In en, this message translates to:
  /// **'{count} found today'**
  String wordHuntFindsToday(int count);

  /// No description provided for @wordHuntNextBadge.
  ///
  /// In en, this message translates to:
  /// **'{remaining} more to unlock {badge}'**
  String wordHuntNextBadge(int remaining, String badge);

  /// No description provided for @wordHuntCameraBusyReason.
  ///
  /// In en, this message translates to:
  /// **'This activity points the camera at the world around you, so it needs the camera to itself. Head control will pause while it is open.'**
  String get wordHuntCameraBusyReason;

  /// No description provided for @customizeProgress.
  ///
  /// In en, this message translates to:
  /// **'Customize progress'**
  String get customizeProgress;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'Customize'**
  String get customize;

  /// No description provided for @signs.
  ///
  /// In en, this message translates to:
  /// **'Signs'**
  String get signs;

  /// No description provided for @bestStreak.
  ///
  /// In en, this message translates to:
  /// **'best {days}'**
  String bestStreak(int days);

  /// No description provided for @starsLeftToSpend.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String starsLeftToSpend(int count);

  /// No description provided for @streakCalendar.
  ///
  /// In en, this message translates to:
  /// **'Streak Calendar'**
  String get streakCalendar;

  /// No description provided for @certificates.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificates;

  /// No description provided for @advancedAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Learning Insights'**
  String get advancedAnalytics;

  /// No description provided for @firstBadgePrompt.
  ///
  /// In en, this message translates to:
  /// **'Keep learning to unlock your first badge!'**
  String get firstBadgePrompt;

  /// No description provided for @badgesEarned.
  ///
  /// In en, this message translates to:
  /// **'{earned} of {total} earned'**
  String badgesEarned(int earned, int total);

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @storiesRead.
  ///
  /// In en, this message translates to:
  /// **'Stories read'**
  String get storiesRead;

  /// No description provided for @perfectQuizzes.
  ///
  /// In en, this message translates to:
  /// **'3-star quizzes'**
  String get perfectQuizzes;

  /// No description provided for @signLanguage.
  ///
  /// In en, this message translates to:
  /// **'Sign Language'**
  String get signLanguage;

  /// No description provided for @signsWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get signsWatched;

  /// No description provided for @signsCanMake.
  ///
  /// In en, this message translates to:
  /// **'I can sign'**
  String get signsCanMake;

  /// No description provided for @signsConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Teacher confirmed'**
  String get signsConfirmed;

  /// No description provided for @daysActive.
  ///
  /// In en, this message translates to:
  /// **'Days active'**
  String get daysActive;

  /// No description provided for @minutesStudied.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutesStudied;

  /// No description provided for @newWords.
  ///
  /// In en, this message translates to:
  /// **'New words'**
  String get newWords;

  /// No description provided for @weeklyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet this week — play a game or read a story and it will show up here.'**
  String get weeklyEmpty;

  /// No description provided for @hearMyProgress.
  ///
  /// In en, this message translates to:
  /// **'Hear my progress'**
  String get hearMyProgress;

  /// No description provided for @studyMinutes.
  ///
  /// In en, this message translates to:
  /// **'Study Min'**
  String get studyMinutes;

  /// No description provided for @spokenProgressSummary.
  ///
  /// In en, this message translates to:
  /// **'You are level {level}, {title}. You have learned {words} words and earned {stars} stars. Your streak is {streak} days, and your best ever is {best} days. You have played {games} games.'**
  String spokenProgressSummary(
    int level,
    String title,
    int words,
    int stars,
    int streak,
    int best,
    int games,
  );

  /// No description provided for @spokenWeekSummary.
  ///
  /// In en, this message translates to:
  /// **'This week you were active on {days} days, played {games} games and earned {stars} stars.'**
  String spokenWeekSummary(int days, int games, int stars);

  /// No description provided for @chartLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get chartLess;

  /// No description provided for @chartMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chartMore;

  /// No description provided for @chartDifficultyHistory.
  ///
  /// In en, this message translates to:
  /// **'Difficulty Adaptation History'**
  String get chartDifficultyHistory;

  /// No description provided for @chartReviewHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Review Activity Heatmap'**
  String get chartReviewHeatmap;

  /// No description provided for @chartStarsEarnedVsSpent.
  ///
  /// In en, this message translates to:
  /// **'Earned vs spent'**
  String get chartStarsEarnedVsSpent;

  /// No description provided for @chartStarsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get chartStarsAvailable;

  /// No description provided for @chartStarsSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get chartStarsSpent;

  /// No description provided for @catShortAnimals.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get catShortAnimals;

  /// No description provided for @catShortColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get catShortColors;

  /// No description provided for @catShortNumbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get catShortNumbers;

  /// No description provided for @catShortBody.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get catShortBody;

  /// No description provided for @catShortFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get catShortFood;

  /// No description provided for @catShortFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get catShortFamily;

  /// No description provided for @catShortClothing.
  ///
  /// In en, this message translates to:
  /// **'Cloth'**
  String get catShortClothing;

  /// No description provided for @catShortWeather.
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get catShortWeather;

  /// No description provided for @catShortClassroom.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get catShortClassroom;

  /// No description provided for @catShortTransport.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get catShortTransport;

  /// No description provided for @catShortEmotions.
  ///
  /// In en, this message translates to:
  /// **'Feels'**
  String get catShortEmotions;

  /// No description provided for @catShortDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get catShortDays;

  /// No description provided for @catShortActions.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get catShortActions;

  /// No description provided for @gameShortMatch.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get gameShortMatch;

  /// No description provided for @gameShortSpell.
  ///
  /// In en, this message translates to:
  /// **'Spell'**
  String get gameShortSpell;

  /// No description provided for @gameShortQuiz.
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get gameShortQuiz;

  /// No description provided for @gameShortMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get gameShortMemory;

  /// No description provided for @gameShortDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag'**
  String get gameShortDrag;

  /// No description provided for @gameShortPronun.
  ///
  /// In en, this message translates to:
  /// **'Pronun'**
  String get gameShortPronun;

  /// No description provided for @gameShortSentence.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get gameShortSentence;

  /// No description provided for @gameShortStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get gameShortStory;

  /// No description provided for @gameShortTrace.
  ///
  /// In en, this message translates to:
  /// **'Trace'**
  String get gameShortTrace;

  /// No description provided for @gameShortFsl.
  ///
  /// In en, this message translates to:
  /// **'FSL'**
  String get gameShortFsl;

  /// No description provided for @gameShortJigsaw.
  ///
  /// In en, this message translates to:
  /// **'Jigsaw'**
  String get gameShortJigsaw;

  /// No description provided for @gameShortPicWord.
  ///
  /// In en, this message translates to:
  /// **'PicWord'**
  String get gameShortPicWord;

  /// No description provided for @gameShortYesNo.
  ///
  /// In en, this message translates to:
  /// **'Yes/No'**
  String get gameShortYesNo;

  /// No description provided for @gameShortOdd.
  ///
  /// In en, this message translates to:
  /// **'Odd'**
  String get gameShortOdd;

  /// No description provided for @gameShortLetter.
  ///
  /// In en, this message translates to:
  /// **'Letter'**
  String get gameShortLetter;

  /// No description provided for @chartActivityMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Map 📅'**
  String get chartActivityMapTitle;

  /// No description provided for @chartActivityMapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Daily study activity — last 8 weeks'**
  String get chartActivityMapSubtitle;

  /// No description provided for @chartCategoryMasteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Category Mastery 🎯'**
  String get chartCategoryMasteryTitle;

  /// No description provided for @chartDifficultyHigh.
  ///
  /// In en, this message translates to:
  /// **'High (≥80%)'**
  String get chartDifficultyHigh;

  /// No description provided for @chartDifficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (50-80%)'**
  String get chartDifficultyMedium;

  /// No description provided for @chartDifficultyLow.
  ///
  /// In en, this message translates to:
  /// **'Low (<50%)'**
  String get chartDifficultyLow;

  /// No description provided for @chartNoGameScores.
  ///
  /// In en, this message translates to:
  /// **'No game scores yet. Play some games! 🎮'**
  String get chartNoGameScores;

  /// No description provided for @chartGamePerformanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Performance 🎮'**
  String get chartGamePerformanceTitle;

  /// No description provided for @chartGamePerformanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Average score (%) per game type'**
  String get chartGamePerformanceSubtitle;

  /// No description provided for @chartWordsLearnedTitle.
  ///
  /// In en, this message translates to:
  /// **'Words Learned 📈'**
  String get chartWordsLearnedTitle;

  /// No description provided for @chartWordsLearnedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cumulative word progress — last 30 days'**
  String get chartWordsLearnedSubtitle;

  /// No description provided for @chartStarsOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Stars Overview ⭐'**
  String get chartStarsOverviewTitle;

  /// No description provided for @chartNoStars.
  ///
  /// In en, this message translates to:
  /// **'No stars earned yet. Keep learning! ✨'**
  String get chartNoStars;

  /// No description provided for @chartStudyTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Study Time ⏱️'**
  String get chartStudyTimeTitle;

  /// No description provided for @chartStudyTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Minutes studied per day (last 7 days)'**
  String get chartStudyTimeSubtitle;

  /// No description provided for @chartMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get chartMinutesShort;

  /// No description provided for @chartCategoryMasterySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress across all vocabulary categories'**
  String get chartCategoryMasterySubtitle;

  /// No description provided for @chartDifficultySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your accuracy changes across games over time'**
  String get chartDifficultySubtitle;

  /// No description provided for @chartDifficultyEmpty.
  ///
  /// In en, this message translates to:
  /// **'Play some games to see your\ndifficulty adaptation history!'**
  String get chartDifficultyEmpty;

  /// No description provided for @gameTipDifficulty.
  ///
  /// In en, this message translates to:
  /// **'💡 Tip: Try different difficulty levels to challenge yourself!'**
  String get gameTipDifficulty;

  /// No description provided for @gameTipDaily.
  ///
  /// In en, this message translates to:
  /// **'🔥 Playing games daily builds stronger memory!'**
  String get gameTipDaily;

  /// No description provided for @gameTipReview.
  ///
  /// In en, this message translates to:
  /// **'🌟 Review words you missed to learn faster!'**
  String get gameTipReview;

  /// No description provided for @gameTipStartEasy.
  ///
  /// In en, this message translates to:
  /// **'🎯 Start with Easy mode, then level up when ready!'**
  String get gameTipStartEasy;

  /// No description provided for @gameTipVariety.
  ///
  /// In en, this message translates to:
  /// **'🧩 Each game teaches in a different way — try them all!'**
  String get gameTipVariety;

  /// No description provided for @gameTipTimed.
  ///
  /// In en, this message translates to:
  /// **'⏱️ Timed mode is great for building speed!'**
  String get gameTipTimed;

  /// No description provided for @playTogether.
  ///
  /// In en, this message translates to:
  /// **'Play Together'**
  String get playTogether;

  /// No description provided for @playTogetherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Race a friend — just for fun!'**
  String get playTogetherSubtitle;

  /// No description provided for @playTogetherSemantics.
  ///
  /// In en, this message translates to:
  /// **'Play Together. Race a friend online or on this device, just for fun.'**
  String get playTogetherSemantics;

  /// No description provided for @gamesPickedForYou.
  ///
  /// In en, this message translates to:
  /// **'{count} games picked for you'**
  String gamesPickedForYou(int count);

  /// No description provided for @badgeNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get badgeNew;

  /// No description provided for @notPlayedYet.
  ///
  /// In en, this message translates to:
  /// **'Not played yet.'**
  String get notPlayedYet;

  /// No description provided for @yourBestStars.
  ///
  /// In en, this message translates to:
  /// **'Your best: {best} of 3 stars.'**
  String yourBestStars(int best);

  /// No description provided for @playGameSemantics.
  ///
  /// In en, this message translates to:
  /// **'Play {game}. {description}'**
  String playGameSemantics(String game, String description);

  /// No description provided for @chooseYourDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Choose your difficulty'**
  String get chooseYourDifficulty;

  /// No description provided for @beatTheClock.
  ///
  /// In en, this message translates to:
  /// **'Beat the Clock ⏱️'**
  String get beatTheClock;

  /// No description provided for @beatTheClockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'60 seconds to finish!'**
  String get beatTheClockSubtitle;

  /// No description provided for @lastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played'**
  String get lastPlayed;

  /// No description provided for @startWithAllCategories.
  ///
  /// In en, this message translates to:
  /// **'Start with All Categories'**
  String get startWithAllCategories;

  /// No description provided for @startWithOneCategory.
  ///
  /// In en, this message translates to:
  /// **'Start with 1 Category'**
  String get startWithOneCategory;

  /// No description provided for @startWithCategories.
  ///
  /// In en, this message translates to:
  /// **'Start with {count} Categories'**
  String startWithCategories(int count);

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @gameReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'{game} Review'**
  String gameReviewTitle(String game);

  /// No description provided for @reviewCorrectCount.
  ///
  /// In en, this message translates to:
  /// **'{count} correct'**
  String reviewCorrectCount(int count);

  /// No description provided for @reviewWrongCount.
  ///
  /// In en, this message translates to:
  /// **'{count} wrong'**
  String reviewWrongCount(int count);

  /// No description provided for @yourAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your answer: '**
  String get yourAnswerLabel;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @resumeGame.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeGame;

  /// No description provided for @iNeedABreak.
  ///
  /// In en, this message translates to:
  /// **'I Need a Break'**
  String get iNeedABreak;

  /// No description provided for @restartGame.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restartGame;

  /// No description provided for @restartGameTitle.
  ///
  /// In en, this message translates to:
  /// **'Restart this game?'**
  String get restartGameTitle;

  /// No description provided for @restartGameBody.
  ///
  /// In en, this message translates to:
  /// **'Your current progress in this round will be lost.'**
  String get restartGameBody;

  /// No description provided for @quitToGames.
  ///
  /// In en, this message translates to:
  /// **'Quit to Games'**
  String get quitToGames;

  /// No description provided for @pauseLabel.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseLabel;

  /// No description provided for @resultAmazing.
  ///
  /// In en, this message translates to:
  /// **'Amazing! 🌟'**
  String get resultAmazing;

  /// No description provided for @resultAmazingHint.
  ///
  /// In en, this message translates to:
  /// **'You\'re a superstar! Try a harder level next!'**
  String get resultAmazingHint;

  /// No description provided for @resultAmazingHintNoLevels.
  ///
  /// In en, this message translates to:
  /// **'You\'re a superstar! You read every question right!'**
  String get resultAmazingHintNoLevels;

  /// No description provided for @resultGreat.
  ///
  /// In en, this message translates to:
  /// **'Great Job! 🎉'**
  String get resultGreat;

  /// No description provided for @resultGreatHint.
  ///
  /// In en, this message translates to:
  /// **'You\'re doing wonderfully! Keep it up!'**
  String get resultGreatHint;

  /// No description provided for @resultGood.
  ///
  /// In en, this message translates to:
  /// **'Good Try! 👍'**
  String get resultGood;

  /// No description provided for @resultGoodHint.
  ///
  /// In en, this message translates to:
  /// **'You\'re learning! Review the words you missed.'**
  String get resultGoodHint;

  /// No description provided for @resultKeepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep Practicing! 💪'**
  String get resultKeepPracticing;

  /// No description provided for @resultKeepPracticingHint.
  ///
  /// In en, this message translates to:
  /// **'Every try makes you stronger! Try again!'**
  String get resultKeepPracticingHint;

  /// No description provided for @fslPracticeHeading.
  ///
  /// In en, this message translates to:
  /// **'Filipino Sign Language Practice'**
  String get fslPracticeHeading;

  /// No description provided for @fslSignToWord.
  ///
  /// In en, this message translates to:
  /// **'Sign → Word'**
  String get fslSignToWord;

  /// No description provided for @fslSignToWordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watch a sign language video, then pick the correct word from choices.'**
  String get fslSignToWordSubtitle;

  /// No description provided for @fslWordToSign.
  ///
  /// In en, this message translates to:
  /// **'Word → Sign'**
  String get fslWordToSign;

  /// No description provided for @fslWordToSignSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See a word, then pick which video shows the correct sign.'**
  String get fslWordToSignSubtitle;

  /// No description provided for @fslSignIt.
  ///
  /// In en, this message translates to:
  /// **'Sign It!'**
  String get fslSignIt;

  /// No description provided for @fslSignItSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watch a sign, copy it in the camera, then check yourself.'**
  String get fslSignItSubtitle;

  /// No description provided for @fslSignItSubtitleGaze.
  ///
  /// In en, this message translates to:
  /// **'Watch a sign, copy it in the camera, then check yourself. Uses your hands — head control pauses here.'**
  String get fslSignItSubtitleGaze;

  /// No description provided for @fslVideosComingSoon.
  ///
  /// In en, this message translates to:
  /// **'FSL videos are still being added. Try the FSL Dictionary in the meantime.'**
  String get fslVideosComingSoon;

  /// No description provided for @resumeBadge.
  ///
  /// In en, this message translates to:
  /// **'PAUSED'**
  String get resumeBadge;

  /// No description provided for @resumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue where you left off?'**
  String get resumeTitle;

  /// No description provided for @resumeBody.
  ///
  /// In en, this message translates to:
  /// **'You stopped at round {round} of {total}.'**
  String resumeBody(int round, int total);

  /// No description provided for @resumeContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get resumeContinue;

  /// No description provided for @resumeStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get resumeStartOver;

  /// No description provided for @resumeRoundProgress.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String resumeRoundProgress(int round, int total);

  /// No description provided for @notEnoughWords.
  ///
  /// In en, this message translates to:
  /// **'Not enough words'**
  String get notEnoughWords;

  /// No description provided for @notEnoughWordsBody.
  ///
  /// In en, this message translates to:
  /// **'Pick more categories to play {game}.'**
  String notEnoughWordsBody(String game);

  /// No description provided for @backToGames.
  ///
  /// In en, this message translates to:
  /// **'Back to Games'**
  String get backToGames;

  /// No description provided for @fslPracticeIntro.
  ///
  /// In en, this message translates to:
  /// **'Watch sign language videos and test your knowledge.\nChoose a practice mode below!'**
  String get fslPracticeIntro;

  /// No description provided for @starsEarnedChip.
  ///
  /// In en, this message translates to:
  /// **'+{count} ⭐ earned'**
  String starsEarnedChip(int count);

  /// No description provided for @gameResultsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Game results: {score} out of {total}, rating {rating} out of 3 stars, {stars} stars earned'**
  String gameResultsSemantics(int score, int total, int rating, int stars);

  /// No description provided for @jigsawPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Jigsaw Puzzle'**
  String get jigsawPuzzle;

  /// No description provided for @pictureWord.
  ///
  /// In en, this message translates to:
  /// **'Picture-Word'**
  String get pictureWord;

  /// No description provided for @yesOrNo.
  ///
  /// In en, this message translates to:
  /// **'Yes or No'**
  String get yesOrNo;

  /// No description provided for @oddOneOut.
  ///
  /// In en, this message translates to:
  /// **'Odd One Out'**
  String get oddOneOut;

  /// No description provided for @firstLetter.
  ///
  /// In en, this message translates to:
  /// **'First Letter'**
  String get firstLetter;

  /// No description provided for @gameDescWordMatch.
  ///
  /// In en, this message translates to:
  /// **'Match the picture to the correct word!'**
  String get gameDescWordMatch;

  /// No description provided for @gameDescSpellingBee.
  ///
  /// In en, this message translates to:
  /// **'Unscramble the letters to spell the word!'**
  String get gameDescSpellingBee;

  /// No description provided for @gameDescMemoryMatch.
  ///
  /// In en, this message translates to:
  /// **'Find matching pairs of cards!'**
  String get gameDescMemoryMatch;

  /// No description provided for @gameDescDragAndDrop.
  ///
  /// In en, this message translates to:
  /// **'Drag each word to its matching picture!'**
  String get gameDescDragAndDrop;

  /// No description provided for @gameDescFlashcardQuiz.
  ///
  /// In en, this message translates to:
  /// **'Swipe right if you know it, left to learn!'**
  String get gameDescFlashcardQuiz;

  /// No description provided for @gameDescPronunciation.
  ///
  /// In en, this message translates to:
  /// **'Listen and pick the correct word!'**
  String get gameDescPronunciation;

  /// No description provided for @gameDescSentenceBuilder.
  ///
  /// In en, this message translates to:
  /// **'Fill in the missing word in the sentence!'**
  String get gameDescSentenceBuilder;

  /// No description provided for @gameDescStoryQuiz.
  ///
  /// In en, this message translates to:
  /// **'Read a story and answer questions!'**
  String get gameDescStoryQuiz;

  /// No description provided for @gameDescTracing.
  ///
  /// In en, this message translates to:
  /// **'Trace the letters of each word!'**
  String get gameDescTracing;

  /// No description provided for @gameDescFslPractice.
  ///
  /// In en, this message translates to:
  /// **'Learn Filipino Sign Language!'**
  String get gameDescFslPractice;

  /// No description provided for @gameDescJigsawPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Assemble the picture puzzle!'**
  String get gameDescJigsawPuzzle;

  /// No description provided for @gameDescPictureWord.
  ///
  /// In en, this message translates to:
  /// **'Match pictures to words by listening!'**
  String get gameDescPictureWord;

  /// No description provided for @gameDescYesOrNo.
  ///
  /// In en, this message translates to:
  /// **'Is this the right word? Tap Yes or No!'**
  String get gameDescYesOrNo;

  /// No description provided for @gameDescOddOneOut.
  ///
  /// In en, this message translates to:
  /// **'Tap the word that does not belong!'**
  String get gameDescOddOneOut;

  /// No description provided for @gameDescFirstLetter.
  ///
  /// In en, this message translates to:
  /// **'Pick the letter the word starts with!'**
  String get gameDescFirstLetter;

  /// No description provided for @difficultyDescEasy.
  ///
  /// In en, this message translates to:
  /// **'Fewer questions, more hints — great for beginners!'**
  String get difficultyDescEasy;

  /// No description provided for @difficultyDescMedium.
  ///
  /// In en, this message translates to:
  /// **'Balanced challenge — the standard experience'**
  String get difficultyDescMedium;

  /// No description provided for @difficultyDescHard.
  ///
  /// In en, this message translates to:
  /// **'More questions, fewer hints — test your skills!'**
  String get difficultyDescHard;

  /// No description provided for @suggestStarting.
  ///
  /// In en, this message translates to:
  /// **'You\'re just getting started! We\'ll begin with easy questions.'**
  String get suggestStarting;

  /// No description provided for @suggestScopeGame.
  ///
  /// In en, this message translates to:
  /// **'In {game}, your recent accuracy is {percent}%.'**
  String suggestScopeGame(String game, int percent);

  /// No description provided for @suggestScopeRecent.
  ///
  /// In en, this message translates to:
  /// **'Across your recent games, your accuracy is {percent}%.'**
  String suggestScopeRecent(int percent);

  /// No description provided for @suggestScopeLifetime.
  ///
  /// In en, this message translates to:
  /// **'Your accuracy is {percent}%.'**
  String suggestScopeLifetime(int percent);

  /// No description provided for @suggestTierEasy.
  ///
  /// In en, this message translates to:
  /// **'Let\'s practice with easier questions to build confidence!'**
  String get suggestTierEasy;

  /// No description provided for @suggestTierMedium.
  ///
  /// In en, this message translates to:
  /// **'A balanced challenge to keep you growing!'**
  String get suggestTierMedium;

  /// No description provided for @suggestTierHard.
  ///
  /// In en, this message translates to:
  /// **'You\'re doing great — time for a real challenge!'**
  String get suggestTierHard;

  /// No description provided for @gameRoundHeader.
  ///
  /// In en, this message translates to:
  /// **'{game}  •  {current}/{total}'**
  String gameRoundHeader(String game, int current, int total);

  /// No description provided for @findPictureFor.
  ///
  /// In en, this message translates to:
  /// **'Find the picture for:'**
  String get findPictureFor;

  /// No description provided for @whichWordMatches.
  ///
  /// In en, this message translates to:
  /// **'Which word matches?'**
  String get whichWordMatches;

  /// No description provided for @whichDoesNotBelong.
  ///
  /// In en, this message translates to:
  /// **'Which one does not belong?'**
  String get whichDoesNotBelong;

  /// No description provided for @startsWithWhichLetter.
  ///
  /// In en, this message translates to:
  /// **'starts with which letter?'**
  String get startsWithWhichLetter;

  /// No description provided for @isThisPrompt.
  ///
  /// In en, this message translates to:
  /// **'Is this…'**
  String get isThisPrompt;

  /// No description provided for @heardTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Heard: “{spoken}” — try again!'**
  String heardTryAgain(String spoken);

  /// No description provided for @cameraWordsFound.
  ///
  /// In en, this message translates to:
  /// **'📷 You\'ve found {count} words with your camera!'**
  String cameraWordsFound(int count);

  /// No description provided for @oddOneOutHint.
  ///
  /// In en, this message translates to:
  /// **'{count} are {category}'**
  String oddOneOutHint(int count, String category);

  /// No description provided for @allPiecesPlaced.
  ///
  /// In en, this message translates to:
  /// **'All pieces placed! 🎉'**
  String get allPiecesPlaced;

  /// No description provided for @jigsawHowTo.
  ///
  /// In en, this message translates to:
  /// **'Tap a piece, then tap a grid slot'**
  String get jigsawHowTo;

  /// No description provided for @movesUsed.
  ///
  /// In en, this message translates to:
  /// **'Moves: {count}'**
  String movesUsed(int count);

  /// No description provided for @knownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} known'**
  String knownCount(int count);

  /// No description provided for @stillLearningCount.
  ///
  /// In en, this message translates to:
  /// **'{count} still learning'**
  String stillLearningCount(int count);

  /// No description provided for @answerChoiceSemantics.
  ///
  /// In en, this message translates to:
  /// **'Answer choice: {answer}'**
  String answerChoiceSemantics(String answer);

  /// No description provided for @answerSemantics.
  ///
  /// In en, this message translates to:
  /// **'Answer: {answer}'**
  String answerSemantics(String answer);

  /// No description provided for @correctAnswerSuffix.
  ///
  /// In en, this message translates to:
  /// **', correct answer'**
  String get correctAnswerSuffix;

  /// No description provided for @wrongAnswerSuffix.
  ///
  /// In en, this message translates to:
  /// **', wrong answer'**
  String get wrongAnswerSuffix;

  /// No description provided for @questionEnglishFor.
  ///
  /// In en, this message translates to:
  /// **'Question: What is the English word for {word}?'**
  String questionEnglishFor(String word);

  /// No description provided for @findPictureForSemantics.
  ///
  /// In en, this message translates to:
  /// **'Find the picture for: {word}'**
  String findPictureForSemantics(String word);

  /// No description provided for @pictureOfSemantics.
  ///
  /// In en, this message translates to:
  /// **'Picture of {word}'**
  String pictureOfSemantics(String word);

  /// No description provided for @whichWordMatchesSemantics.
  ///
  /// In en, this message translates to:
  /// **'Which word matches this picture? {word}'**
  String whichWordMatchesSemantics(String word);

  /// No description provided for @firstLetterQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question: which letter does the word {word} start with?'**
  String firstLetterQuestion(String word);

  /// No description provided for @yesNoQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question: is this picture of a {pictureWord} the word {english}, {filipino}? Answer Yes or No.'**
  String yesNoQuestion(String pictureWord, String english, String filipino);

  /// No description provided for @flashcardSemantics.
  ///
  /// In en, this message translates to:
  /// **'Flashcard: {english}, {filipino}, category {category}. Swipe right for I Know, left for Still Learning'**
  String flashcardSemantics(String english, String filipino, String category);

  /// No description provided for @flashcardProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'Card {current} of {total}, {known} known, {learning} still learning'**
  String flashcardProgressSemantics(
    int current,
    int total,
    int known,
    int learning,
  );

  /// No description provided for @draggableWordSemantics.
  ///
  /// In en, this message translates to:
  /// **'Draggable word: {word}, drag to matching Filipino word'**
  String draggableWordSemantics(String word);

  /// No description provided for @dropTargetMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched: {filipino} is {english}'**
  String dropTargetMatched(String filipino, String english);

  /// No description provided for @dropTargetEmpty.
  ///
  /// In en, this message translates to:
  /// **'Drop target: {filipino}, not yet matched'**
  String dropTargetEmpty(String filipino);

  /// No description provided for @slotFilled.
  ///
  /// In en, this message translates to:
  /// **'Slot {position}: {letter}, tap to remove'**
  String slotFilled(int position, String letter);

  /// No description provided for @slotEmpty.
  ///
  /// In en, this message translates to:
  /// **'Slot {position}: empty'**
  String slotEmpty(int position);

  /// No description provided for @letterAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'Letter {letter}, already used'**
  String letterAlreadyUsed(String letter);

  /// No description provided for @letterTapToPlace.
  ///
  /// In en, this message translates to:
  /// **'Letter {letter}, tap to place'**
  String letterTapToPlace(String letter);

  /// No description provided for @playSoundEnglish.
  ///
  /// In en, this message translates to:
  /// **'Play sound: tap to hear the English word'**
  String get playSoundEnglish;

  /// No description provided for @playSoundFilipino.
  ///
  /// In en, this message translates to:
  /// **'Play sound: tap to hear the Filipino word'**
  String get playSoundFilipino;

  /// No description provided for @roundScoreSemantics.
  ///
  /// In en, this message translates to:
  /// **'Round {current} of {total}, score {score}'**
  String roundScoreSemantics(int current, int total, int score);

  /// No description provided for @spelledSoFar.
  ///
  /// In en, this message translates to:
  /// **'Answer: {letters}'**
  String spelledSoFar(String letters);

  /// No description provided for @wordComplete.
  ///
  /// In en, this message translates to:
  /// **'word complete'**
  String get wordComplete;

  /// No description provided for @oddOneOutQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question: which word does not belong? The words are {words}.'**
  String oddOneOutQuestion(String words);

  /// No description provided for @oddOneOutHintSpoken.
  ///
  /// In en, this message translates to:
  /// **' {count} of them are {category}.'**
  String oddOneOutHintSpoken(int count, String category);

  /// No description provided for @fslWatchAndChoose.
  ///
  /// In en, this message translates to:
  /// **'Watch the sign language video and choose the correct word'**
  String get fslWatchAndChoose;

  /// No description provided for @fslWhatWordIsThisSign.
  ///
  /// In en, this message translates to:
  /// **'What word is this sign?'**
  String get fslWhatWordIsThisSign;

  /// No description provided for @fslWhichSignMeans.
  ///
  /// In en, this message translates to:
  /// **'Which sign means…'**
  String get fslWhichSignMeans;

  /// No description provided for @videoChoice.
  ///
  /// In en, this message translates to:
  /// **'Video choice {index}'**
  String videoChoice(int index);

  /// No description provided for @dropTargetHolding.
  ///
  /// In en, this message translates to:
  /// **'Drop target: {filipino}, currently has {word} (wrong)'**
  String dropTargetHolding(String filipino, String word);

  /// No description provided for @dropTargetEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Drop target: {filipino}, empty, drop English match here'**
  String dropTargetEmptyHint(String filipino);

  /// No description provided for @memoryCardMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched card: {word}'**
  String memoryCardMatched(String word);

  /// No description provided for @memoryCardShowing.
  ///
  /// In en, this message translates to:
  /// **'Card showing: {word}'**
  String memoryCardShowing(String word);

  /// No description provided for @memoryCardFaceDown.
  ///
  /// In en, this message translates to:
  /// **'Face-down card, tap to flip'**
  String get memoryCardFaceDown;

  /// No description provided for @breakButton.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get breakButton;

  /// No description provided for @iNeedABreakTooltip.
  ///
  /// In en, this message translates to:
  /// **'I need a break'**
  String get iNeedABreakTooltip;

  /// No description provided for @replayVideo.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replayVideo;

  /// No description provided for @showMe.
  ///
  /// In en, this message translates to:
  /// **'Show Me'**
  String get showMe;

  /// No description provided for @answerYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get answerYes;

  /// No description provided for @answerNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get answerNo;

  /// No description provided for @jigsawPuzzleProgress.
  ///
  /// In en, this message translates to:
  /// **'Puzzle {current} of {total}'**
  String jigsawPuzzleProgress(int current, int total);

  /// No description provided for @jigsawCompleteFor.
  ///
  /// In en, this message translates to:
  /// **'Complete the puzzle for: {word}'**
  String jigsawCompleteFor(String word);

  /// No description provided for @jigsawPieceSemantics.
  ///
  /// In en, this message translates to:
  /// **'Puzzle piece row {row}, column {column}, tap to place'**
  String jigsawPieceSemantics(int row, int column);

  /// No description provided for @memoryProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'Matched {matched} of {total} pairs in {moves} moves'**
  String memoryProgressSemantics(int matched, int total, int moves);

  /// No description provided for @jigsawPiecePlaced.
  ///
  /// In en, this message translates to:
  /// **'Puzzle piece row {row}, column {column}, placed correctly'**
  String jigsawPiecePlaced(int row, int column);

  /// No description provided for @gazePrev.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get gazePrev;

  /// No description provided for @gazeNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get gazeNext;

  /// No description provided for @gazeChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get gazeChoose;

  /// No description provided for @gazeFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get gazeFlip;

  /// No description provided for @gazePlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get gazePlace;

  /// No description provided for @gazeUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get gazeUndo;

  /// No description provided for @showMeTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Me — {word}'**
  String showMeTitle(String word);

  /// No description provided for @collabLearnTogether.
  ///
  /// In en, this message translates to:
  /// **'Learn Together!'**
  String get collabLearnTogether;

  /// No description provided for @collabTeamTagline.
  ///
  /// In en, this message translates to:
  /// **'You\'re one team — you score together, not against each other.'**
  String get collabTeamTagline;

  /// No description provided for @collabPlayer2NameLabel.
  ///
  /// In en, this message translates to:
  /// **'Player 2\'s Name:'**
  String get collabPlayer2NameLabel;

  /// No description provided for @collabPlayer2NameSemantics.
  ///
  /// In en, this message translates to:
  /// **'Player 2\'s name'**
  String get collabPlayer2NameSemantics;

  /// No description provided for @collabPlayer2NameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter name...'**
  String get collabPlayer2NameHint;

  /// No description provided for @collabChooseActivity.
  ///
  /// In en, this message translates to:
  /// **'Choose an Activity'**
  String get collabChooseActivity;

  /// No description provided for @collabEnterPlayer2Name.
  ///
  /// In en, this message translates to:
  /// **'Enter Player 2\'s name'**
  String get collabEnterPlayer2Name;

  /// No description provided for @collabNoWords.
  ///
  /// In en, this message translates to:
  /// **'No words available right now'**
  String get collabNoWords;

  /// No description provided for @collabHearAgain.
  ///
  /// In en, this message translates to:
  /// **'Hear it again'**
  String get collabHearAgain;

  /// No description provided for @collabWordRelay.
  ///
  /// In en, this message translates to:
  /// **'Word Relay'**
  String get collabWordRelay;

  /// No description provided for @collabPictureGuess.
  ///
  /// In en, this message translates to:
  /// **'Picture Guess'**
  String get collabPictureGuess;

  /// No description provided for @collabSignChallenge.
  ///
  /// In en, this message translates to:
  /// **'Sign Challenge'**
  String get collabSignChallenge;

  /// No description provided for @collabStoryBuilder.
  ///
  /// In en, this message translates to:
  /// **'Story Builder'**
  String get collabStoryBuilder;

  /// No description provided for @collabWordRelayDesc.
  ///
  /// In en, this message translates to:
  /// **'Take turns spelling words letter by letter'**
  String get collabWordRelayDesc;

  /// No description provided for @collabPictureGuessDesc.
  ///
  /// In en, this message translates to:
  /// **'One player describes, the other guesses the picture'**
  String get collabPictureGuessDesc;

  /// No description provided for @collabSignChallengeDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign the word, then guess your partner\'s sign'**
  String get collabSignChallengeDesc;

  /// No description provided for @collabStoryBuilderDesc.
  ///
  /// In en, this message translates to:
  /// **'Build a story together, one sentence at a time'**
  String get collabStoryBuilderDesc;

  /// No description provided for @collabTeam.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get collabTeam;

  /// No description provided for @collabPromptDescribe.
  ///
  /// In en, this message translates to:
  /// **'{name}, describe the word for {partner}'**
  String collabPromptDescribe(String name, String partner);

  /// No description provided for @collabPromptNextLetter.
  ///
  /// In en, this message translates to:
  /// **'{name}, what\'s the next letter?'**
  String collabPromptNextLetter(String name);

  /// No description provided for @collabPromptAddSentence.
  ///
  /// In en, this message translates to:
  /// **'{name}, add the next sentence'**
  String collabPromptAddSentence(String name);

  /// No description provided for @collabPromptGuess.
  ///
  /// In en, this message translates to:
  /// **'{name}, guess the word'**
  String collabPromptGuess(String name);

  /// No description provided for @collabAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'The answer was {word}'**
  String collabAnswerWas(String word);

  /// No description provided for @collabHintClue.
  ///
  /// In en, this message translates to:
  /// **'Type a clue...'**
  String get collabHintClue;

  /// No description provided for @collabHintLetter.
  ///
  /// In en, this message translates to:
  /// **'One letter...'**
  String get collabHintLetter;

  /// No description provided for @collabHintSentence.
  ///
  /// In en, this message translates to:
  /// **'Add the next sentence...'**
  String get collabHintSentence;

  /// No description provided for @collabHintGuess.
  ///
  /// In en, this message translates to:
  /// **'Guess the word...'**
  String get collabHintGuess;

  /// No description provided for @collabWordToSpell.
  ///
  /// In en, this message translates to:
  /// **'Word to spell:'**
  String get collabWordToSpell;

  /// No description provided for @collabWordToDescribe.
  ///
  /// In en, this message translates to:
  /// **'Word to describe:'**
  String get collabWordToDescribe;

  /// No description provided for @collabSignToShow.
  ///
  /// In en, this message translates to:
  /// **'Sign to show:'**
  String get collabSignToShow;

  /// No description provided for @collabWhatIsTheWord.
  ///
  /// In en, this message translates to:
  /// **'What is the word?'**
  String get collabWhatIsTheWord;

  /// No description provided for @collabClueLabel.
  ///
  /// In en, this message translates to:
  /// **'Clue:'**
  String get collabClueLabel;

  /// No description provided for @collabBuildStoryTogether.
  ///
  /// In en, this message translates to:
  /// **'Build the story together!'**
  String get collabBuildStoryTogether;

  /// No description provided for @collabStartTheStory.
  ///
  /// In en, this message translates to:
  /// **'Start the story!'**
  String get collabStartTheStory;

  /// No description provided for @collabWatchTheSign.
  ///
  /// In en, this message translates to:
  /// **'Watch the sign'**
  String get collabWatchTheSign;

  /// No description provided for @collabPhraseBig.
  ///
  /// In en, this message translates to:
  /// **'The {word} is big.'**
  String collabPhraseBig(String word);

  /// No description provided for @collabPhraseISee.
  ///
  /// In en, this message translates to:
  /// **'I can see a {word}.'**
  String collabPhraseISee(String word);

  /// No description provided for @collabPhraseHappy.
  ///
  /// In en, this message translates to:
  /// **'The {word} is happy.'**
  String collabPhraseHappy(String word);

  /// No description provided for @collabPhraseWeLike.
  ///
  /// In en, this message translates to:
  /// **'We like the {word}.'**
  String collabPhraseWeLike(String word);

  /// No description provided for @collabGreatTeamwork.
  ///
  /// In en, this message translates to:
  /// **'Great teamwork!'**
  String get collabGreatTeamwork;

  /// No description provided for @collabPointsTogether.
  ///
  /// In en, this message translates to:
  /// **'{score} of {total} points together'**
  String collabPointsTogether(int score, int total);

  /// No description provided for @collabSubmitAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get collabSubmitAnswer;

  /// No description provided for @collabSetUpForYou.
  ///
  /// In en, this message translates to:
  /// **'Set up for you: {list}.'**
  String collabSetUpForYou(String list);

  /// No description provided for @collabAdaptTapToAnswer.
  ///
  /// In en, this message translates to:
  /// **'tap to answer'**
  String get collabAdaptTapToAnswer;

  /// No description provided for @collabAdaptReadAloud.
  ///
  /// In en, this message translates to:
  /// **'read aloud'**
  String get collabAdaptReadAloud;

  /// No description provided for @collabAdaptBiggerButtons.
  ///
  /// In en, this message translates to:
  /// **'bigger buttons'**
  String get collabAdaptBiggerButtons;

  /// No description provided for @collabAdaptShorter.
  ///
  /// In en, this message translates to:
  /// **'shorter session'**
  String get collabAdaptShorter;

  /// No description provided for @collabLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this activity?'**
  String get collabLeaveTitle;

  /// No description provided for @collabLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your place is saved — you can carry on together later.'**
  String get collabLeaveBody;

  /// No description provided for @collabLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get collabLeaveConfirm;

  /// No description provided for @collabKeepPlaying.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get collabKeepPlaying;

  /// No description provided for @collabClueCategory.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String collabClueCategory(String category);

  /// No description provided for @collabClueFirstLetter.
  ///
  /// In en, this message translates to:
  /// **'It starts with {letter}.'**
  String collabClueFirstLetter(String letter);

  /// No description provided for @collabClueLength.
  ///
  /// In en, this message translates to:
  /// **'It has {count} letters.'**
  String collabClueLength(int count);

  /// No description provided for @collabPassSpoken.
  ///
  /// In en, this message translates to:
  /// **'Or show it — pass to {name}'**
  String collabPassSpoken(String name);

  /// Spoken state of a settings switch that is turned on
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get settingOn;

  /// Spoken state of a settings switch that is turned off
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingOff;

  /// No description provided for @settingHighContrastDesc.
  ///
  /// In en, this message translates to:
  /// **'Bolder colors & thicker borders'**
  String get settingHighContrastDesc;

  /// No description provided for @settingDarkModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Easier on the eyes in low light'**
  String get settingDarkModeDesc;

  /// No description provided for @settingDyslexiaDesc.
  ///
  /// In en, this message translates to:
  /// **'Cream background, Lexend font, wider letter spacing'**
  String get settingDyslexiaDesc;

  /// No description provided for @settingReducedMotionDesc.
  ///
  /// In en, this message translates to:
  /// **'Minimize animations'**
  String get settingReducedMotionDesc;

  /// No description provided for @settingVoiceNavOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Announces screens & buttons aloud'**
  String get settingVoiceNavOnDesc;

  /// No description provided for @settingVoiceNavOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Enable for visually impaired users'**
  String get settingVoiceNavOffDesc;

  /// No description provided for @settingAdaptiveOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Auto-suggests difficulty based on progress'**
  String get settingAdaptiveOnDesc;

  /// No description provided for @settingAdaptiveOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Manual difficulty selection only'**
  String get settingAdaptiveOffDesc;

  /// No description provided for @settingGazeControlDesc.
  ///
  /// In en, this message translates to:
  /// **'Hands-free: move your head or blink to select'**
  String get settingGazeControlDesc;

  /// No description provided for @settingGamepadDesc.
  ///
  /// In en, this message translates to:
  /// **'Navigate by Bluetooth gamepad, with spoken feedback'**
  String get settingGamepadDesc;

  /// No description provided for @settingFullscreenOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Nav bar hidden, app bars collapsed — until you turn it off'**
  String get settingFullscreenOnDesc;

  /// No description provided for @settingFullscreenOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Hide the nav bar and app bars for class or TV display'**
  String get settingFullscreenOffDesc;

  /// No description provided for @settingSlowMotionOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Games & flashcards animate at half speed'**
  String get settingSlowMotionOnDesc;

  /// No description provided for @settingSlowMotionOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Slow gameplay & flashcard animations down'**
  String get settingSlowMotionOffDesc;

  /// No description provided for @settingLearningAssistOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Shows “why” hints and a 50/50 helper in quizzes'**
  String get settingLearningAssistOnDesc;

  /// No description provided for @settingLearningAssistOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Plain quizzes — no hints or explanations'**
  String get settingLearningAssistOffDesc;

  /// No description provided for @settingTtsDesc.
  ///
  /// In en, this message translates to:
  /// **'Hear words spoken aloud'**
  String get settingTtsDesc;

  /// No description provided for @settingSoundEffectsDesc.
  ///
  /// In en, this message translates to:
  /// **'Game sounds & feedback'**
  String get settingSoundEffectsDesc;

  /// No description provided for @settingSttOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Voice input enabled in games'**
  String get settingSttOnDesc;

  /// No description provided for @settingSttOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap to enable voice input for games'**
  String get settingSttOffDesc;

  /// No description provided for @settingCompanionOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Floating buddy — tap it any time for help'**
  String get settingCompanionOnDesc;

  /// No description provided for @settingCompanionOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Turn on your floating learning buddy'**
  String get settingCompanionOffDesc;

  /// No description provided for @settingVocabReviewDesc.
  ///
  /// In en, this message translates to:
  /// **'Reminds you to review weak words'**
  String get settingVocabReviewDesc;

  /// No description provided for @settingBackupRestoreDesc.
  ///
  /// In en, this message translates to:
  /// **'Save or restore all app data'**
  String get settingBackupRestoreDesc;

  /// No description provided for @settingRecoveryCodeDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore this profile on a new device'**
  String get settingRecoveryCodeDesc;

  /// No description provided for @settingCloudAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email to restore on any device'**
  String get settingCloudAccountDesc;

  /// No description provided for @settingClassroomModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Monitor all students in real time'**
  String get settingClassroomModeDesc;

  /// No description provided for @settingAccessibilitySetupDesc.
  ///
  /// In en, this message translates to:
  /// **'Restart the accessibility wizard'**
  String get settingAccessibilitySetupDesc;

  /// No description provided for @settingManageProfilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Delete profiles saved on this device'**
  String get settingManageProfilesDesc;

  /// No description provided for @settingChildControlsDesc.
  ///
  /// In en, this message translates to:
  /// **'Set time limits & content restrictions'**
  String get settingChildControlsDesc;

  /// No description provided for @settingReplayTutorialsDesc.
  ///
  /// In en, this message translates to:
  /// **'Show tutorial guides again on all screens'**
  String get settingReplayTutorialsDesc;

  /// No description provided for @settingPurposeDesc.
  ///
  /// In en, this message translates to:
  /// **'Interactive vocabulary building app for PWD students using flashcards, games, and Filipino Sign Language.'**
  String get settingPurposeDesc;

  /// No description provided for @settingResearchDataOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Sending anonymous crash & usage data to the research team'**
  String get settingResearchDataOnDesc;

  /// No description provided for @settingResearchDataOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Off — no data leaves this device'**
  String get settingResearchDataOffDesc;

  /// No description provided for @settingDailyMissionDesc.
  ///
  /// In en, this message translates to:
  /// **'{count} words per day'**
  String settingDailyMissionDesc(int count);

  /// No description provided for @settingGazeControlTitle.
  ///
  /// In en, this message translates to:
  /// **'Gaze Control (Preview)'**
  String get settingGazeControlTitle;

  /// No description provided for @settingGamepadTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Controller'**
  String get settingGamepadTitle;

  /// No description provided for @settingSectionPresentation.
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get settingSectionPresentation;

  /// No description provided for @settingSectionLearningModes.
  ///
  /// In en, this message translates to:
  /// **'Learning Modes'**
  String get settingSectionLearningModes;

  /// No description provided for @settingSlowMotionTitle.
  ///
  /// In en, this message translates to:
  /// **'Slow-Motion Mode'**
  String get settingSlowMotionTitle;

  /// No description provided for @settingLearningAssistTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Assist'**
  String get settingLearningAssistTitle;

  /// No description provided for @settingDailyMissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Mission Size'**
  String get settingDailyMissionTitle;

  /// No description provided for @settingCompanionTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Companion'**
  String get settingCompanionTitle;

  /// No description provided for @settingVocabReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Vocab Review Reminder'**
  String get settingVocabReviewTitle;

  /// No description provided for @settingSectionMyDay.
  ///
  /// In en, this message translates to:
  /// **'My Day'**
  String get settingSectionMyDay;

  /// No description provided for @settingRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get settingRoutineTitle;

  /// No description provided for @settingRoutineOnDesc.
  ///
  /// In en, this message translates to:
  /// **'My Day shows on your home — plan your day, step by step'**
  String get settingRoutineOnDesc;

  /// No description provided for @settingRoutineOffDesc.
  ///
  /// In en, this message translates to:
  /// **'Turn on My Day to plan your day, step by step'**
  String get settingRoutineOffDesc;

  /// No description provided for @settingSectionData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingSectionData;

  /// No description provided for @settingBackupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingBackupRestoreTitle;

  /// No description provided for @settingRecoveryCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud Recovery Code'**
  String get settingRecoveryCodeTitle;

  /// No description provided for @settingCloudAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Link Account'**
  String get settingCloudAccountTitle;

  /// No description provided for @settingAccessibilitySetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Re-run Accessibility Setup'**
  String get settingAccessibilitySetupTitle;

  /// No description provided for @settingManageProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Profiles'**
  String get settingManageProfilesTitle;

  /// No description provided for @settingChildControlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Parental Controls'**
  String get settingChildControlsTitle;

  /// No description provided for @settingReplayTutorialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay Tutorials'**
  String get settingReplayTutorialsTitle;

  /// No description provided for @settingPurposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get settingPurposeTitle;

  /// No description provided for @settingResearchDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app'**
  String get settingResearchDataTitle;

  /// No description provided for @fontSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get fontSizeSmall;

  /// No description provided for @fontSizeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get fontSizeNormal;

  /// No description provided for @fontSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get fontSizeLarge;

  /// No description provided for @fontSizeExtraLarge.
  ///
  /// In en, this message translates to:
  /// **'Extra Large'**
  String get fontSizeExtraLarge;

  /// No description provided for @speechSpeedVerySlow.
  ///
  /// In en, this message translates to:
  /// **'Very Slow'**
  String get speechSpeedVerySlow;

  /// No description provided for @speechSpeedSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get speechSpeedSlow;

  /// No description provided for @speechSpeedNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get speechSpeedNormal;

  /// No description provided for @speechSpeedFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get speechSpeedFast;

  /// No description provided for @speechSpeedSpoken.
  ///
  /// In en, this message translates to:
  /// **'{label}, {step} of {stops}'**
  String speechSpeedSpoken(String label, int step, int stops);

  /// No description provided for @setFontSizeTo.
  ///
  /// In en, this message translates to:
  /// **'Set font size to {size}'**
  String setFontSizeTo(String size);

  /// No description provided for @changeLabel.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeLabel;

  /// No description provided for @changePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePinTitle;

  /// No description provided for @setProfilePinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Profile PIN'**
  String get setProfilePinTitle;

  /// No description provided for @pinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN to protect your profile.'**
  String get pinPrompt;

  /// No description provided for @disabilityVisual.
  ///
  /// In en, this message translates to:
  /// **'Visual Impairment'**
  String get disabilityVisual;

  /// No description provided for @disabilityHearing.
  ///
  /// In en, this message translates to:
  /// **'Hearing Impairment'**
  String get disabilityHearing;

  /// No description provided for @disabilityMotor.
  ///
  /// In en, this message translates to:
  /// **'Motor Impairment'**
  String get disabilityMotor;

  /// No description provided for @disabilityCognitive.
  ///
  /// In en, this message translates to:
  /// **'Cognitive/Learning'**
  String get disabilityCognitive;

  /// No description provided for @disabilityMultiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple Disabilities'**
  String get disabilityMultiple;

  /// No description provided for @disabilityNone.
  ///
  /// In en, this message translates to:
  /// **'No Accessibility Needs'**
  String get disabilityNone;

  /// No description provided for @disabilityCognitiveFull.
  ///
  /// In en, this message translates to:
  /// **'Cognitive/Learning Disability'**
  String get disabilityCognitiveFull;

  /// No description provided for @disabilityVisualDesc.
  ///
  /// In en, this message translates to:
  /// **'Difficulty seeing, low vision, or color blindness'**
  String get disabilityVisualDesc;

  /// No description provided for @disabilityHearingDesc.
  ///
  /// In en, this message translates to:
  /// **'Difficulty hearing or deaf'**
  String get disabilityHearingDesc;

  /// No description provided for @disabilityMotorDesc.
  ///
  /// In en, this message translates to:
  /// **'Difficulty with fine motor skills or touch'**
  String get disabilityMotorDesc;

  /// No description provided for @disabilityCognitiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Dyslexia, ADHD, or learning difficulties'**
  String get disabilityCognitiveDesc;

  /// No description provided for @disabilityMultipleDesc.
  ///
  /// In en, this message translates to:
  /// **'Combination of accessibility needs'**
  String get disabilityMultipleDesc;

  /// No description provided for @disabilityNoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Standard settings, no special adjustments'**
  String get disabilityNoneDesc;

  /// No description provided for @roleNameStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get roleNameStudent;

  /// No description provided for @roleNameTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get roleNameTeacher;

  /// No description provided for @roleNameParent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get roleNameParent;

  /// No description provided for @roleNameChild.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get roleNameChild;

  /// No description provided for @roleNamePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get roleNamePlayer;

  /// No description provided for @dashboardTitleForPerson.
  ///
  /// In en, this message translates to:
  /// **'{name} Dashboard'**
  String dashboardTitleForPerson(String name);

  /// No description provided for @dashboardTitleForRole.
  ///
  /// In en, this message translates to:
  /// **'{role} Dashboard'**
  String dashboardTitleForRole(String role);

  /// No description provided for @eduWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String eduWelcome(String name);

  /// No description provided for @eduSubtitleParent.
  ///
  /// In en, this message translates to:
  /// **'Monitor your children\'s learning'**
  String get eduSubtitleParent;

  /// No description provided for @eduSubtitleTeacher.
  ///
  /// In en, this message translates to:
  /// **'Manage your class progress'**
  String get eduSubtitleTeacher;

  /// No description provided for @eduQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get eduQuickActions;

  /// No description provided for @eduMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get eduMore;

  /// No description provided for @eduContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get eduContent;

  /// No description provided for @eduAssessmentsProgress.
  ///
  /// In en, this message translates to:
  /// **'Assessments & Progress'**
  String get eduAssessmentsProgress;

  /// No description provided for @eduResearch.
  ///
  /// In en, this message translates to:
  /// **'Research'**
  String get eduResearch;

  /// No description provided for @eduNeedsHelp.
  ///
  /// In en, this message translates to:
  /// **'Needs Help'**
  String get eduNeedsHelp;

  /// No description provided for @eduInactive7d.
  ///
  /// In en, this message translates to:
  /// **'Inactive 7d+'**
  String get eduInactive7d;

  /// No description provided for @eduActiveToday.
  ///
  /// In en, this message translates to:
  /// **'Active Today'**
  String get eduActiveToday;

  /// No description provided for @eduReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get eduReports;

  /// No description provided for @eduWeeklySummary.
  ///
  /// In en, this message translates to:
  /// **'Weekly summary'**
  String get eduWeeklySummary;

  /// No description provided for @eduParentalControlsTile.
  ///
  /// In en, this message translates to:
  /// **'Parental Controls'**
  String get eduParentalControlsTile;

  /// No description provided for @eduLimitsSafety.
  ///
  /// In en, this message translates to:
  /// **'Limits & safety'**
  String get eduLimitsSafety;

  /// No description provided for @eduCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get eduCards;

  /// No description provided for @eduBrowseDecks.
  ///
  /// In en, this message translates to:
  /// **'Browse decks'**
  String get eduBrowseDecks;

  /// No description provided for @eduShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get eduShareCode;

  /// No description provided for @eduInviteChild.
  ///
  /// In en, this message translates to:
  /// **'Invite your child'**
  String get eduInviteChild;

  /// No description provided for @eduInviteStudents.
  ///
  /// In en, this message translates to:
  /// **'Invite students'**
  String get eduInviteStudents;

  /// No description provided for @eduTvCast.
  ///
  /// In en, this message translates to:
  /// **'TV Cast'**
  String get eduTvCast;

  /// No description provided for @eduMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get eduMessages;

  /// No description provided for @eduTeacherNotes.
  ///
  /// In en, this message translates to:
  /// **'Teacher Notes'**
  String get eduTeacherNotes;

  /// No description provided for @eduParentNotes.
  ///
  /// In en, this message translates to:
  /// **'Parent Notes'**
  String get eduParentNotes;

  /// No description provided for @eduAssessments.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get eduAssessments;

  /// No description provided for @eduAssignTasks.
  ///
  /// In en, this message translates to:
  /// **'Assign Tasks'**
  String get eduAssignTasks;

  /// No description provided for @eduTrackProgress.
  ///
  /// In en, this message translates to:
  /// **'Track Progress'**
  String get eduTrackProgress;

  /// No description provided for @eduManageGroups.
  ///
  /// In en, this message translates to:
  /// **'Manage Groups'**
  String get eduManageGroups;

  /// No description provided for @eduManageClasses.
  ///
  /// In en, this message translates to:
  /// **'Manage Classes'**
  String get eduManageClasses;

  /// No description provided for @eduRosterProgress.
  ///
  /// In en, this message translates to:
  /// **'Roster & progress'**
  String get eduRosterProgress;

  /// No description provided for @eduAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get eduAnalytics;

  /// No description provided for @eduClassInsights.
  ///
  /// In en, this message translates to:
  /// **'Class insights'**
  String get eduClassInsights;

  /// No description provided for @eduClassroomTile.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get eduClassroomTile;

  /// No description provided for @eduLiveSession.
  ///
  /// In en, this message translates to:
  /// **'Live session'**
  String get eduLiveSession;

  /// No description provided for @eduWorksheets.
  ///
  /// In en, this message translates to:
  /// **'Worksheets'**
  String get eduWorksheets;

  /// No description provided for @eduExperimentSetup.
  ///
  /// In en, this message translates to:
  /// **'Experiment Setup'**
  String get eduExperimentSetup;

  /// No description provided for @eduSusSurvey.
  ///
  /// In en, this message translates to:
  /// **'SUS Survey'**
  String get eduSusSurvey;

  /// No description provided for @eduResearchExport.
  ///
  /// In en, this message translates to:
  /// **'Research Export'**
  String get eduResearchExport;

  /// No description provided for @eduDashboardCtaSub.
  ///
  /// In en, this message translates to:
  /// **'Detailed insights, alerts, and recommendations'**
  String get eduDashboardCtaSub;

  /// No description provided for @eduNoChildrenDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a home group, then share the code with your child to join.'**
  String get eduNoChildrenDesc;

  /// No description provided for @eduNoStudentsDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a class, then share the code with your students to join.'**
  String get eduNoStudentsDesc;

  /// No description provided for @assessPreTest.
  ///
  /// In en, this message translates to:
  /// **'Pre-Test'**
  String get assessPreTest;

  /// No description provided for @assessPostTest.
  ///
  /// In en, this message translates to:
  /// **'Post-Test'**
  String get assessPostTest;

  /// No description provided for @assessCategoryMastery.
  ///
  /// In en, this message translates to:
  /// **'Category Mastery'**
  String get assessCategoryMastery;

  /// No description provided for @assessCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Assessment'**
  String get assessCustom;

  /// No description provided for @assessPreTestDesc.
  ///
  /// In en, this message translates to:
  /// **'Measure your starting knowledge before learning'**
  String get assessPreTestDesc;

  /// No description provided for @assessPostTestDesc.
  ///
  /// In en, this message translates to:
  /// **'See how much you\'ve improved after learning'**
  String get assessPostTestDesc;

  /// No description provided for @assessCategoryMasteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Test your mastery of a specific category'**
  String get assessCategoryMasteryDesc;

  /// No description provided for @assessCustomDesc.
  ///
  /// In en, this message translates to:
  /// **'Teacher-created assessment'**
  String get assessCustomDesc;

  /// No description provided for @formatMultipleChoice.
  ///
  /// In en, this message translates to:
  /// **'Multiple Choice'**
  String get formatMultipleChoice;

  /// No description provided for @formatFillInBlank.
  ///
  /// In en, this message translates to:
  /// **'Fill in the Blank'**
  String get formatFillInBlank;

  /// No description provided for @formatMatchPairs.
  ///
  /// In en, this message translates to:
  /// **'Match Pairs'**
  String get formatMatchPairs;

  /// No description provided for @formatTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'True or False'**
  String get formatTrueFalse;

  /// No description provided for @formatSignVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch the Sign'**
  String get formatSignVideo;

  /// No description provided for @signQuestionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Watch the sign. Which word is it?'**
  String get signQuestionPrompt;

  /// No description provided for @assessCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Assessment Center'**
  String get assessCenterTitle;

  /// No description provided for @assessCenterLearnerSub.
  ///
  /// In en, this message translates to:
  /// **'Measure your learning progress'**
  String get assessCenterLearnerSub;

  /// No description provided for @assessCenterEducatorSub.
  ///
  /// In en, this message translates to:
  /// **'Build, assign and track your learners\' tests'**
  String get assessCenterEducatorSub;

  /// No description provided for @assessPrePostSection.
  ///
  /// In en, this message translates to:
  /// **'Pre-Test & Post-Test'**
  String get assessPrePostSection;

  /// No description provided for @assessPrePostLearnerBlurb.
  ///
  /// In en, this message translates to:
  /// **'Take a pre-test before studying, then a post-test after — see your growth!'**
  String get assessPrePostLearnerBlurb;

  /// No description provided for @assessPrePostEducatorBlurb.
  ///
  /// In en, this message translates to:
  /// **'Your learners sit these. Assign the pre-test first, then the post-test after the lessons — the gain appears here.'**
  String get assessPrePostEducatorBlurb;

  /// No description provided for @assessMasterySection.
  ///
  /// In en, this message translates to:
  /// **'Category Mastery Tests'**
  String get assessMasterySection;

  /// No description provided for @assessMasteryBlurb.
  ///
  /// In en, this message translates to:
  /// **'Test your knowledge in specific vocabulary categories'**
  String get assessMasteryBlurb;

  /// No description provided for @assessAssignedToYou.
  ///
  /// In en, this message translates to:
  /// **'Assigned to You'**
  String get assessAssignedToYou;

  /// No description provided for @assessRecentResults.
  ///
  /// In en, this message translates to:
  /// **'Recent Results'**
  String get assessRecentResults;

  /// No description provided for @assessSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get assessSeeAll;

  /// No description provided for @assessClassReport.
  ///
  /// In en, this message translates to:
  /// **'Class report'**
  String get assessClassReport;

  /// No description provided for @assessYourAttempts.
  ///
  /// In en, this message translates to:
  /// **'Your attempts'**
  String get assessYourAttempts;

  /// No description provided for @assessAttemptCounts.
  ///
  /// In en, this message translates to:
  /// **'Counts'**
  String get assessAttemptCounts;

  /// No description provided for @assessAttemptsOne.
  ///
  /// In en, this message translates to:
  /// **'1 attempt'**
  String get assessAttemptsOne;

  /// No description provided for @assessAttemptsMany.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts'**
  String assessAttemptsMany(int count);

  /// No description provided for @assessNoLearnersYet.
  ///
  /// In en, this message translates to:
  /// **'No learners yet'**
  String get assessNoLearnersYet;

  /// No description provided for @assessNoLearnersDesc.
  ///
  /// In en, this message translates to:
  /// **'Share a class or home-group code, then assign the pre-test.'**
  String get assessNoLearnersDesc;

  /// No description provided for @assessNeedPreTestFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete a Pre-Test first'**
  String get assessNeedPreTestFirst;

  /// No description provided for @assessKeepStudying.
  ///
  /// In en, this message translates to:
  /// **'Keep studying'**
  String get assessKeepStudying;

  /// No description provided for @assessKeepStudyingFor.
  ///
  /// In en, this message translates to:
  /// **'Keep studying — {what}'**
  String assessKeepStudyingFor(String what);

  /// No description provided for @assessMoreDays.
  ///
  /// In en, this message translates to:
  /// **'{count} more days'**
  String assessMoreDays(int count);

  /// No description provided for @assessOneMoreDay.
  ///
  /// In en, this message translates to:
  /// **'1 more day'**
  String get assessOneMoreDay;

  /// No description provided for @assessMoreStudyDays.
  ///
  /// In en, this message translates to:
  /// **'{count} more study days'**
  String assessMoreStudyDays(int count);

  /// No description provided for @assessOneMoreStudyDay.
  ///
  /// In en, this message translates to:
  /// **'1 more study day'**
  String get assessOneMoreStudyDay;

  /// No description provided for @assessAndJoin.
  ///
  /// In en, this message translates to:
  /// **'{a} and {b}'**
  String assessAndJoin(String a, String b);

  /// No description provided for @assessRetakeLocked.
  ///
  /// In en, this message translates to:
  /// **'Already done — ask your teacher to reopen it'**
  String get assessRetakeLocked;

  /// No description provided for @assessReadyForPost.
  ///
  /// In en, this message translates to:
  /// **'Ready for post-test'**
  String get assessReadyForPost;

  /// No description provided for @assessPostAssigned.
  ///
  /// In en, this message translates to:
  /// **'Post-test assigned'**
  String get assessPostAssigned;

  /// No description provided for @assessPreOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Pre-test outstanding'**
  String get assessPreOutstanding;

  /// No description provided for @assessPostIn.
  ///
  /// In en, this message translates to:
  /// **'Pre-test done · post-test suggested after {wait}'**
  String assessPostIn(String wait);

  /// No description provided for @assessPreFromEducator.
  ///
  /// In en, this message translates to:
  /// **'Your teacher or parent will give you this test'**
  String get assessPreFromEducator;

  /// No description provided for @assessPostFromEducator.
  ///
  /// In en, this message translates to:
  /// **'Your teacher or parent will open this after your lessons'**
  String get assessPostFromEducator;

  /// No description provided for @assessClipsPreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting the sign videos ready…'**
  String get assessClipsPreparing;

  /// No description provided for @assessClipsMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'The sign videos need the internet'**
  String get assessClipsMissingTitle;

  /// No description provided for @assessClipsMissingBody.
  ///
  /// In en, this message translates to:
  /// **'This test has sign-language videos that are not on this tablet yet. Connect to Wi‑Fi, then try again. The test has not started.'**
  String get assessClipsMissingBody;

  /// No description provided for @assessClipsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get assessClipsTryAgain;

  /// No description provided for @assessClipsGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get assessClipsGoBack;

  /// No description provided for @eduClassReport.
  ///
  /// In en, this message translates to:
  /// **'Class Report'**
  String get eduClassReport;

  /// No description provided for @supportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Learner Support'**
  String get supportSectionTitle;

  /// No description provided for @supportSectionBlurb.
  ///
  /// In en, this message translates to:
  /// **'How {category} works for this learner. These can be changed any time.'**
  String supportSectionBlurb(String category);

  /// No description provided for @supportGroupCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication & language'**
  String get supportGroupCommunication;

  /// No description provided for @supportGroupCommunicationDesc.
  ///
  /// In en, this message translates to:
  /// **'How this learner takes in language. Pick one.'**
  String get supportGroupCommunicationDesc;

  /// No description provided for @supportGroupHearingExtras.
  ///
  /// In en, this message translates to:
  /// **'Hearing supports'**
  String get supportGroupHearingExtras;

  /// No description provided for @supportGroupVisualAccess.
  ///
  /// In en, this message translates to:
  /// **'Reading the screen'**
  String get supportGroupVisualAccess;

  /// No description provided for @supportGroupVisualAccessDesc.
  ///
  /// In en, this message translates to:
  /// **'How this learner gets at what is on screen. Pick one.'**
  String get supportGroupVisualAccessDesc;

  /// No description provided for @supportGroupVisualExtras.
  ///
  /// In en, this message translates to:
  /// **'Vision supports'**
  String get supportGroupVisualExtras;

  /// No description provided for @supportGroupInput.
  ///
  /// In en, this message translates to:
  /// **'Controlling the app'**
  String get supportGroupInput;

  /// No description provided for @supportGroupInputDesc.
  ///
  /// In en, this message translates to:
  /// **'How this learner moves around the app. Pick one.'**
  String get supportGroupInputDesc;

  /// No description provided for @supportGroupMotorExtras.
  ///
  /// In en, this message translates to:
  /// **'Movement supports'**
  String get supportGroupMotorExtras;

  /// No description provided for @supportGroupThinking.
  ///
  /// In en, this message translates to:
  /// **'Learning support'**
  String get supportGroupThinking;

  /// No description provided for @supportGroupThinkingDesc.
  ///
  /// In en, this message translates to:
  /// **'How instructions should reach this learner. Pick one.'**
  String get supportGroupThinkingDesc;

  /// No description provided for @supportGroupCognitiveExtras.
  ///
  /// In en, this message translates to:
  /// **'Understanding supports'**
  String get supportGroupCognitiveExtras;

  /// No description provided for @supportGroupOther.
  ///
  /// In en, this message translates to:
  /// **'Other supports'**
  String get supportGroupOther;

  /// No description provided for @supportGroupOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional supports'**
  String get supportGroupOptional;

  /// No description provided for @supportGroupExtrasDesc.
  ///
  /// In en, this message translates to:
  /// **'Add anything else that helps.'**
  String get supportGroupExtrasDesc;

  /// No description provided for @supportGroupNoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Nothing here is required.'**
  String get supportGroupNoneDesc;

  /// No description provided for @supportSignFsl.
  ///
  /// In en, this message translates to:
  /// **'Filipino Sign Language (FSL)'**
  String get supportSignFsl;

  /// No description provided for @supportSignFslDesc.
  ///
  /// In en, this message translates to:
  /// **'Signs used in Filipino Deaf schools. The app’s sign clips are in FSL.'**
  String get supportSignFslDesc;

  /// No description provided for @supportSignAsl.
  ///
  /// In en, this message translates to:
  /// **'American Sign Language (ASL)'**
  String get supportSignAsl;

  /// No description provided for @supportSignAslDesc.
  ///
  /// In en, this message translates to:
  /// **'Signs used in American Deaf communities.'**
  String get supportSignAslDesc;

  /// No description provided for @supportSignSee.
  ///
  /// In en, this message translates to:
  /// **'Signing Exact English (SEE)'**
  String get supportSignSee;

  /// No description provided for @supportSignSeeDesc.
  ///
  /// In en, this message translates to:
  /// **'Signs that follow English word order, sign for sign.'**
  String get supportSignSeeDesc;

  /// No description provided for @supportCuedSpeech.
  ///
  /// In en, this message translates to:
  /// **'Cued Speech'**
  String get supportCuedSpeech;

  /// No description provided for @supportCuedSpeechDesc.
  ///
  /// In en, this message translates to:
  /// **'Hand shapes near the mouth that make speech sounds visible.'**
  String get supportCuedSpeechDesc;

  /// No description provided for @supportOralLipReading.
  ///
  /// In en, this message translates to:
  /// **'Speech & Lip Reading'**
  String get supportOralLipReading;

  /// No description provided for @supportOralLipReadingDesc.
  ///
  /// In en, this message translates to:
  /// **'Learns by watching the mouth and using any remaining hearing.'**
  String get supportOralLipReadingDesc;

  /// No description provided for @supportWrittenCaptions.
  ///
  /// In en, this message translates to:
  /// **'Written words only'**
  String get supportWrittenCaptions;

  /// No description provided for @supportWrittenCaptionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Reads text instead of signing. Sign clips stay hidden.'**
  String get supportWrittenCaptionsDesc;

  /// No description provided for @supportCaptionsAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Captions always on'**
  String get supportCaptionsAlwaysOn;

  /// No description provided for @supportCaptionsAlwaysOnDesc.
  ///
  /// In en, this message translates to:
  /// **'Every video and story shows its text. Noted on the profile for the teaching team.'**
  String get supportCaptionsAlwaysOnDesc;

  /// No description provided for @supportVisualAlerts.
  ///
  /// In en, this message translates to:
  /// **'Flash instead of sound'**
  String get supportVisualAlerts;

  /// No description provided for @supportVisualAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Screen flashes and badges stand in for chimes.'**
  String get supportVisualAlertsDesc;

  /// No description provided for @supportAudioFirst.
  ///
  /// In en, this message translates to:
  /// **'Listen first (screen reader)'**
  String get supportAudioFirst;

  /// No description provided for @supportAudioFirstDesc.
  ///
  /// In en, this message translates to:
  /// **'Everything is spoken; the screen is the second channel.'**
  String get supportAudioFirstDesc;

  /// No description provided for @supportLargePrint.
  ///
  /// In en, this message translates to:
  /// **'Large print'**
  String get supportLargePrint;

  /// No description provided for @supportLargePrintDesc.
  ///
  /// In en, this message translates to:
  /// **'Very large type, few items per screen.'**
  String get supportLargePrintDesc;

  /// No description provided for @supportSpokenAnswerChoices.
  ///
  /// In en, this message translates to:
  /// **'Read the choices aloud'**
  String get supportSpokenAnswerChoices;

  /// No description provided for @supportSpokenAnswerChoicesDesc.
  ///
  /// In en, this message translates to:
  /// **'Each answer choice is spoken before the learner picks.'**
  String get supportSpokenAnswerChoicesDesc;

  /// No description provided for @supportInputTouch.
  ///
  /// In en, this message translates to:
  /// **'Touch'**
  String get supportInputTouch;

  /// No description provided for @supportInputTouchDesc.
  ///
  /// In en, this message translates to:
  /// **'Taps the screen as usual.'**
  String get supportInputTouchDesc;

  /// No description provided for @supportInputGaze.
  ///
  /// In en, this message translates to:
  /// **'Eye gaze (hands-free)'**
  String get supportInputGaze;

  /// No description provided for @supportInputGazeDesc.
  ///
  /// In en, this message translates to:
  /// **'Controls the app by looking at it.'**
  String get supportInputGazeDesc;

  /// No description provided for @supportInputSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch or gamepad'**
  String get supportInputSwitch;

  /// No description provided for @supportInputSwitchDesc.
  ///
  /// In en, this message translates to:
  /// **'Uses a Bluetooth gamepad or switch instead of touch.'**
  String get supportInputSwitchDesc;

  /// No description provided for @supportSimplifiedLanguage.
  ///
  /// In en, this message translates to:
  /// **'Simple words'**
  String get supportSimplifiedLanguage;

  /// No description provided for @supportSimplifiedLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Short sentences and everyday words.'**
  String get supportSimplifiedLanguageDesc;

  /// No description provided for @supportPicturePrompts.
  ///
  /// In en, this message translates to:
  /// **'Picture support'**
  String get supportPicturePrompts;

  /// No description provided for @supportPicturePromptsDesc.
  ///
  /// In en, this message translates to:
  /// **'A picture goes with every instruction. Noted on the profile for the teaching team.'**
  String get supportPicturePromptsDesc;

  /// No description provided for @supportStepByStep.
  ///
  /// In en, this message translates to:
  /// **'One step at a time'**
  String get supportStepByStep;

  /// No description provided for @supportStepByStepDesc.
  ///
  /// In en, this message translates to:
  /// **'One instruction at a time, with a clear next step.'**
  String get supportStepByStepDesc;

  /// No description provided for @supportRepeatInstructions.
  ///
  /// In en, this message translates to:
  /// **'Repeat instructions'**
  String get supportRepeatInstructions;

  /// No description provided for @supportRepeatInstructionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Instructions can be replayed as often as needed. Noted on the profile for the teaching team.'**
  String get supportRepeatInstructionsDesc;

  /// No description provided for @supportFewerChoices.
  ///
  /// In en, this message translates to:
  /// **'Fewer answer choices'**
  String get supportFewerChoices;

  /// No description provided for @supportFewerChoicesDesc.
  ///
  /// In en, this message translates to:
  /// **'Questions offer two choices instead of four.'**
  String get supportFewerChoicesDesc;

  /// No description provided for @supportExtendedTestTime.
  ///
  /// In en, this message translates to:
  /// **'Extra time on tests'**
  String get supportExtendedTestTime;

  /// No description provided for @supportExtendedTestTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'Timed assessments give this learner half again as long.'**
  String get supportExtendedTestTimeDesc;

  /// No description provided for @reportForEducatorsTitle.
  ///
  /// In en, this message translates to:
  /// **'For teachers and parents'**
  String get reportForEducatorsTitle;

  /// No description provided for @reportForEducatorsDesc.
  ///
  /// In en, this message translates to:
  /// **'This report reads a whole class at once. Your own results live in the Assessment Center.'**
  String get reportForEducatorsDesc;

  /// No description provided for @reportCheckNewResults.
  ///
  /// In en, this message translates to:
  /// **'Check for new results'**
  String get reportCheckNewResults;

  /// No description provided for @reportNoLearnersDesc.
  ///
  /// In en, this message translates to:
  /// **'Share a class or home-group code, then assign the pre-test. The report fills in as results come back.'**
  String get reportNoLearnersDesc;

  /// No description provided for @reportAssignWork.
  ///
  /// In en, this message translates to:
  /// **'Assign work'**
  String get reportAssignWork;

  /// No description provided for @reportGainSection.
  ///
  /// In en, this message translates to:
  /// **'Learning gain by accessibility'**
  String get reportGainSection;

  /// No description provided for @reportGainSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Averages over the learners who have finished both halves. Anyone still missing one is counted separately.'**
  String get reportGainSectionDesc;

  /// No description provided for @reportGainNone.
  ///
  /// In en, this message translates to:
  /// **'No learner has finished both halves yet, so there is nothing to average. Assign the pre-test first.'**
  String get reportGainNone;

  /// No description provided for @reportItemsSection.
  ///
  /// In en, this message translates to:
  /// **'Hardest items'**
  String get reportItemsSection;

  /// No description provided for @reportItemsSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Every question the class has answered, hardest first. “Split the class” with a low separation usually means the wording, not the word.'**
  String get reportItemsSectionDesc;

  /// No description provided for @reportItemsNone.
  ///
  /// In en, this message translates to:
  /// **'No answers recorded yet. This fills in as your learners finish assessments.'**
  String get reportItemsNone;

  /// No description provided for @reportAttemptsSection.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get reportAttemptsSection;

  /// No description provided for @reportAttemptsSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'The most recent sitting of each half is the one a learning gain is measured from.'**
  String get reportAttemptsSectionDesc;

  /// No description provided for @reportMetricPre.
  ///
  /// In en, this message translates to:
  /// **'Pre'**
  String get reportMetricPre;

  /// No description provided for @reportMetricPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get reportMetricPost;

  /// No description provided for @reportMetricGain.
  ///
  /// In en, this message translates to:
  /// **'Gain'**
  String get reportMetricGain;

  /// No description provided for @reportMetricNormalized.
  ///
  /// In en, this message translates to:
  /// **'Normalized'**
  String get reportMetricNormalized;

  /// No description provided for @reportMetricMeasured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get reportMetricMeasured;

  /// No description provided for @reportMetricWaiting.
  ///
  /// In en, this message translates to:
  /// **'Still waiting'**
  String get reportMetricWaiting;

  /// No description provided for @reportMetricMedian.
  ///
  /// In en, this message translates to:
  /// **'Median'**
  String get reportMetricMedian;

  /// No description provided for @reportMetricSeparation.
  ///
  /// In en, this message translates to:
  /// **'Separation'**
  String get reportMetricSeparation;

  /// No description provided for @reportMetricOftenAnswered.
  ///
  /// In en, this message translates to:
  /// **'Often answered'**
  String get reportMetricOftenAnswered;

  /// No description provided for @reportAttemptNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get reportAttemptNone;

  /// No description provided for @reportAttemptEarlier.
  ///
  /// In en, this message translates to:
  /// **'(+{count} earlier)'**
  String reportAttemptEarlier(int count);

  /// No description provided for @reportDifficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy for the class'**
  String get reportDifficultyEasy;

  /// No description provided for @reportDifficultyMost.
  ///
  /// In en, this message translates to:
  /// **'Most got it'**
  String get reportDifficultyMost;

  /// No description provided for @reportDifficultySplit.
  ///
  /// In en, this message translates to:
  /// **'Split the class'**
  String get reportDifficultySplit;

  /// No description provided for @reportDifficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get reportDifficultyHard;

  /// No description provided for @reportDifficultyNobody.
  ///
  /// In en, this message translates to:
  /// **'Almost nobody'**
  String get reportDifficultyNobody;

  /// No description provided for @reportNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Your strongest learners did no better on this one — worth rereading the wording.'**
  String get reportNeedsReview;

  /// No description provided for @reportGainSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category}. {count, plural, =1{1 learner measured} other{{count} learners measured}}. Mean pre-test {pre} percent, post-test {post} percent, gain {gain} percent.'**
  String reportGainSemantics(
    String category,
    int count,
    int pre,
    int post,
    int gain,
  );

  /// No description provided for @reportGainNoneSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category}. No learner has finished both halves yet. {count} waiting.'**
  String reportGainNoneSemantics(String category, int count);

  /// No description provided for @reportItemCorrectSemantics.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {attempts} correct, {percent} percent'**
  String reportItemCorrectSemantics(int correct, int attempts, int percent);

  /// No description provided for @reportItemWrongSemantics.
  ///
  /// In en, this message translates to:
  /// **'Most common wrong answer, {answer}'**
  String reportItemWrongSemantics(String answer);

  /// No description provided for @reportItemReviewSemantics.
  ///
  /// In en, this message translates to:
  /// **'This item may need rewording'**
  String get reportItemReviewSemantics;

  /// No description provided for @rxTitle.
  ///
  /// In en, this message translates to:
  /// **'Research Data Export'**
  String get rxTitle;

  /// No description provided for @rxHeader.
  ///
  /// In en, this message translates to:
  /// **'Thesis Research Export'**
  String get rxHeader;

  /// No description provided for @rxIntro.
  ///
  /// In en, this message translates to:
  /// **'Export anonymized data for the learners you tick below. Names are replaced with IDs that stay the same in every export, so files from several devices can be merged.'**
  String get rxIntro;

  /// No description provided for @rxParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get rxParticipants;

  /// No description provided for @rxParticipantsHint.
  ///
  /// In en, this message translates to:
  /// **'Only ticked learners are exported. Your own classes and home groups are ticked for you.'**
  String get rxParticipantsHint;

  /// No description provided for @rxSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{selected} of {total} selected'**
  String rxSelectedCount(int selected, int total);

  /// No description provided for @rxTickAll.
  ///
  /// In en, this message translates to:
  /// **'Tick all'**
  String get rxTickAll;

  /// No description provided for @rxUntickAll.
  ///
  /// In en, this message translates to:
  /// **'Untick all'**
  String get rxUntickAll;

  /// No description provided for @rxYourGroups.
  ///
  /// In en, this message translates to:
  /// **'In your classes and home groups'**
  String get rxYourGroups;

  /// No description provided for @rxOtherLearners.
  ///
  /// In en, this message translates to:
  /// **'Other learners on this tablet'**
  String get rxOtherLearners;

  /// No description provided for @rxOtherLearnersHint.
  ///
  /// In en, this message translates to:
  /// **'Not in your classes or home groups — left out unless you tick them.'**
  String get rxOtherLearnersHint;

  /// No description provided for @rxDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'Data Available'**
  String get rxDataAvailable;

  /// No description provided for @rxLearners.
  ///
  /// In en, this message translates to:
  /// **'Learners'**
  String get rxLearners;

  /// No description provided for @rxGameScores.
  ///
  /// In en, this message translates to:
  /// **'Game scores'**
  String get rxGameScores;

  /// No description provided for @rxSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions logged'**
  String get rxSessions;

  /// No description provided for @rxAssessmentResults.
  ///
  /// In en, this message translates to:
  /// **'Assessment results'**
  String get rxAssessmentResults;

  /// No description provided for @rxMoodEntries.
  ///
  /// In en, this message translates to:
  /// **'Mood entries'**
  String get rxMoodEntries;

  /// No description provided for @rxGainReports.
  ///
  /// In en, this message translates to:
  /// **'Learning gain reports'**
  String get rxGainReports;

  /// No description provided for @rxFilesIncluded.
  ///
  /// In en, this message translates to:
  /// **'Files Included'**
  String get rxFilesIncluded;

  /// No description provided for @rxFileStudentsOverview.
  ///
  /// In en, this message translates to:
  /// **'Demographics & aggregate stats per student'**
  String get rxFileStudentsOverview;

  /// No description provided for @rxFileLearningCurves.
  ///
  /// In en, this message translates to:
  /// **'Game scores over time (for trend analysis)'**
  String get rxFileLearningCurves;

  /// No description provided for @rxFileSessionPatterns.
  ///
  /// In en, this message translates to:
  /// **'Session logs with day-of-week patterns'**
  String get rxFileSessionPatterns;

  /// No description provided for @rxFileCategoryMastery.
  ///
  /// In en, this message translates to:
  /// **'Per-category mastery % for each student'**
  String get rxFileCategoryMastery;

  /// No description provided for @rxFileWordAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Spaced-repetition per-word accuracy data'**
  String get rxFileWordAccuracy;

  /// No description provided for @rxFileAssessmentResults.
  ///
  /// In en, this message translates to:
  /// **'Pre/post test scores & learning gains'**
  String get rxFileAssessmentResults;

  /// No description provided for @rxFileMoodData.
  ///
  /// In en, this message translates to:
  /// **'Mood check-ins correlated with activities'**
  String get rxFileMoodData;

  /// No description provided for @rxFileAdaptiveDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty adjustments & accuracy over time'**
  String get rxFileAdaptiveDifficulty;

  /// No description provided for @rxFileSummaryStats.
  ///
  /// In en, this message translates to:
  /// **'High-level aggregates for quick reference'**
  String get rxFileSummaryStats;

  /// No description provided for @rxExportButton.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Export Research Data (1 learner)} other{Export Research Data ({count} learners)}}'**
  String rxExportButton(int count);

  /// No description provided for @rxGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get rxGenerating;

  /// No description provided for @rxNobodyTicked.
  ///
  /// In en, this message translates to:
  /// **'Tick at least one learner to export.'**
  String get rxNobodyTicked;

  /// No description provided for @rxNoLearners.
  ///
  /// In en, this message translates to:
  /// **'No learner profiles yet. Learners appear here once they join your class or home group.'**
  String get rxNoLearners;

  /// No description provided for @rxExported.
  ///
  /// In en, this message translates to:
  /// **'Research data exported successfully!'**
  String get rxExported;

  /// No description provided for @rxExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String rxExportFailed(String error);

  /// No description provided for @qpFilipinoWordFor.
  ///
  /// In en, this message translates to:
  /// **'What is the Filipino word for “{word}”?'**
  String qpFilipinoWordFor(String word);

  /// No description provided for @qpEnglishWordFor.
  ///
  /// In en, this message translates to:
  /// **'What is the English word for “{word}”?'**
  String qpEnglishWordFor(String word);

  /// No description provided for @qpFillBlank.
  ///
  /// In en, this message translates to:
  /// **'Fill in the blank: The Filipino translation of “{word}” is _____.'**
  String qpFillBlank(String word);

  /// No description provided for @qpTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'True or False: “{english}” is “{shown}” in Filipino.'**
  String qpTrueFalse(String english, String shown);

  /// No description provided for @qpInFilipinoIs.
  ///
  /// In en, this message translates to:
  /// **'“{english}” in Filipino is “{shown}”'**
  String qpInFilipinoIs(String english, String shown);

  /// No description provided for @qpMatch.
  ///
  /// In en, this message translates to:
  /// **'Match: “{word}” → ?'**
  String qpMatch(String word);

  /// No description provided for @qpTypeFilipino.
  ///
  /// In en, this message translates to:
  /// **'Type the Filipino word for “{word}”:'**
  String qpTypeFilipino(String word);

  /// No description provided for @qpTypeEnglish.
  ///
  /// In en, this message translates to:
  /// **'Type the English word for “{word}”:'**
  String qpTypeEnglish(String word);

  /// No description provided for @qpTrue.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get qpTrue;

  /// No description provided for @qpFalse.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get qpFalse;

  /// No description provided for @testQuitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Quit assessment'**
  String get testQuitTooltip;

  /// No description provided for @testQuitTitle.
  ///
  /// In en, this message translates to:
  /// **'Quit Assessment?'**
  String get testQuitTitle;

  /// No description provided for @testQuitBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress will be lost. Are you sure you want to quit?'**
  String get testQuitBody;

  /// No description provided for @testQuitContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get testQuitContinue;

  /// No description provided for @testQuitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get testQuitConfirm;

  /// No description provided for @testQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String testQuestionOf(int current, int total);

  /// No description provided for @testProgressSemantics.
  ///
  /// In en, this message translates to:
  /// **'Progress: {percent} percent complete'**
  String testProgressSemantics(int percent);

  /// No description provided for @testShowHint.
  ///
  /// In en, this message translates to:
  /// **'Show Hint'**
  String get testShowHint;

  /// No description provided for @testHideHint.
  ///
  /// In en, this message translates to:
  /// **'Hide Hint'**
  String get testHideHint;

  /// No description provided for @testFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish Assessment'**
  String get testFinish;

  /// No description provided for @testNext.
  ///
  /// In en, this message translates to:
  /// **'Next Question'**
  String get testNext;

  /// No description provided for @testTypeHere.
  ///
  /// In en, this message translates to:
  /// **'Type your answer here...'**
  String get testTypeHere;

  /// No description provided for @testSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Answer'**
  String get testSubmit;

  /// No description provided for @testHintAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String testHintAnswer(String answer);

  /// No description provided for @testCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get testCorrect;

  /// No description provided for @testNotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite right'**
  String get testNotQuite;

  /// No description provided for @testTheAnswerIs.
  ///
  /// In en, this message translates to:
  /// **'The correct answer is: {answer}'**
  String testTheAnswerIs(String answer);

  /// No description provided for @testMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute remaining} other{{minutes} minutes remaining}}'**
  String testMinutesLeft(int minutes);

  /// No description provided for @testSecondsLeft.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, =1{1 second remaining} other{{seconds} seconds remaining}}'**
  String testSecondsLeft(int seconds);

  /// No description provided for @gradeExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get gradeExcellent;

  /// No description provided for @gradeVeryGood.
  ///
  /// In en, this message translates to:
  /// **'Very Good'**
  String get gradeVeryGood;

  /// No description provided for @gradeGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get gradeGood;

  /// No description provided for @gradeNeedsImprovement.
  ///
  /// In en, this message translates to:
  /// **'Needs Improvement'**
  String get gradeNeedsImprovement;

  /// No description provided for @gradeKeepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep Practicing'**
  String get gradeKeepPracticing;

  /// No description provided for @supportShortLipReading.
  ///
  /// In en, this message translates to:
  /// **'Lip reading'**
  String get supportShortLipReading;

  /// No description provided for @supportShortWritten.
  ///
  /// In en, this message translates to:
  /// **'Written'**
  String get supportShortWritten;

  /// No description provided for @supportShortAudioFirst.
  ///
  /// In en, this message translates to:
  /// **'Audio first'**
  String get supportShortAudioFirst;

  /// No description provided for @supportShortGaze.
  ///
  /// In en, this message translates to:
  /// **'Gaze'**
  String get supportShortGaze;

  /// No description provided for @supportShortTouch.
  ///
  /// In en, this message translates to:
  /// **'Touch'**
  String get supportShortTouch;

  /// No description provided for @sumComplete.
  ///
  /// In en, this message translates to:
  /// **'{type} Complete!'**
  String sumComplete(String type);

  /// No description provided for @sumTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get sumTime;

  /// No description provided for @sumCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get sumCorrect;

  /// No description provided for @sumWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get sumWrong;

  /// No description provided for @sumCategoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get sumCategoryBreakdown;

  /// No description provided for @sumQuestionReview.
  ///
  /// In en, this message translates to:
  /// **'Question Review'**
  String get sumQuestionReview;

  /// No description provided for @sumBackToHub.
  ///
  /// In en, this message translates to:
  /// **'Back to Hub'**
  String get sumBackToHub;

  /// No description provided for @sumViewAnalytics.
  ///
  /// In en, this message translates to:
  /// **'View Analytics'**
  String get sumViewAnalytics;

  /// No description provided for @sumCategorySemantics.
  ///
  /// In en, this message translates to:
  /// **'{category}: {percent} percent'**
  String sumCategorySemantics(String category, int percent);

  /// No description provided for @resTitle.
  ///
  /// In en, this message translates to:
  /// **'Assessment Analytics'**
  String get resTitle;

  /// No description provided for @resCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 assessment completed} other{{count} assessments completed}}'**
  String resCompletedCount(int count);

  /// No description provided for @resEmpty.
  ///
  /// In en, this message translates to:
  /// **'No assessments completed yet'**
  String get resEmpty;

  /// No description provided for @resTakeOne.
  ///
  /// In en, this message translates to:
  /// **'Take an Assessment'**
  String get resTakeOne;

  /// No description provided for @resTrend.
  ///
  /// In en, this message translates to:
  /// **'Score Trend Over Time'**
  String get resTrend;

  /// No description provided for @resCategoryMastery.
  ///
  /// In en, this message translates to:
  /// **'Category Mastery'**
  String get resCategoryMastery;

  /// No description provided for @resHistory.
  ///
  /// In en, this message translates to:
  /// **'Assessment History'**
  String get resHistory;

  /// No description provided for @resLearningGain.
  ///
  /// In en, this message translates to:
  /// **'Learning Gain'**
  String get resLearningGain;

  /// No description provided for @resPerCategoryGains.
  ///
  /// In en, this message translates to:
  /// **'Per-Category Gains'**
  String get resPerCategoryGains;

  /// No description provided for @resAvgScore.
  ///
  /// In en, this message translates to:
  /// **'Avg Score'**
  String get resAvgScore;

  /// No description provided for @resAssessments.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get resAssessments;

  /// No description provided for @resTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get resTotalTime;

  /// No description provided for @resNeedTwo.
  ///
  /// In en, this message translates to:
  /// **'Complete 2+ assessments to see trends'**
  String get resNeedTwo;

  /// No description provided for @resHistoryLine.
  ///
  /// In en, this message translates to:
  /// **'{date} • {count, plural, =1{1 question} other{{count} questions}} • {duration}'**
  String resHistoryLine(String date, int count, String duration);

  /// No description provided for @resAttemptSemantics.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent on {date}'**
  String resAttemptSemantics(int percent, String date);

  /// No description provided for @resAttemptCountsSemantics.
  ///
  /// In en, this message translates to:
  /// **'This is the attempt your learning gain uses'**
  String get resAttemptCountsSemantics;

  /// No description provided for @resSatWith.
  ///
  /// In en, this message translates to:
  /// **'Sat with {supports}'**
  String resSatWith(String supports);

  /// No description provided for @gainImproved.
  ///
  /// In en, this message translates to:
  /// **'Score improved from {pre}% to {post}% (+{gain}%)'**
  String gainImproved(int pre, int post, int gain);

  /// No description provided for @gainSame.
  ///
  /// In en, this message translates to:
  /// **'Score remained at {pre}%'**
  String gainSame(int pre);

  /// No description provided for @gainChanged.
  ///
  /// In en, this message translates to:
  /// **'Score changed from {pre}% to {post}% ({gain}%)'**
  String gainChanged(int pre, int post, int gain);

  /// No description provided for @hubResultsTooltip.
  ///
  /// In en, this message translates to:
  /// **'View assessment results and analytics'**
  String get hubResultsTooltip;

  /// No description provided for @hubCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get hubCreate;

  /// No description provided for @hubAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get hubAssign;

  /// No description provided for @hubTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get hubTrack;

  /// No description provided for @hubQuizBuilder.
  ///
  /// In en, this message translates to:
  /// **'Quiz Builder'**
  String get hubQuizBuilder;

  /// No description provided for @hubQuizBuilderDesc.
  ///
  /// In en, this message translates to:
  /// **'Create custom quizzes from any flashcards'**
  String get hubQuizBuilderDesc;

  /// No description provided for @hubCustomAssessments.
  ///
  /// In en, this message translates to:
  /// **'Custom Assessments'**
  String get hubCustomAssessments;

  /// No description provided for @hubCreateCustomTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create a new custom assessment'**
  String get hubCreateCustomTooltip;

  /// No description provided for @hubNoCustom.
  ///
  /// In en, this message translates to:
  /// **'No custom assessments yet'**
  String get hubNoCustom;

  /// No description provided for @hubNoCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create one for your students'**
  String get hubNoCustomHint;

  /// No description provided for @hubViewAllResults.
  ///
  /// In en, this message translates to:
  /// **'View all results'**
  String get hubViewAllResults;

  /// No description provided for @hubGainSemantics.
  ///
  /// In en, this message translates to:
  /// **'Learning gain report. {summary}'**
  String hubGainSemantics(String summary);

  /// No description provided for @hubGainTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Gain Report'**
  String get hubGainTitle;

  /// No description provided for @hubCardLockedSemantics.
  ///
  /// In en, this message translates to:
  /// **'{type}. Locked. {reason}'**
  String hubCardLockedSemantics(String type, String reason);

  /// No description provided for @hubCardDoneSemantics.
  ///
  /// In en, this message translates to:
  /// **'{type}. Completed. Latest score {percent} percent. Tap to retake.'**
  String hubCardDoneSemantics(String type, int percent);

  /// No description provided for @hubCardNewSemantics.
  ///
  /// In en, this message translates to:
  /// **'{type}. Not yet taken. Tap to start.'**
  String hubCardNewSemantics(String type);

  /// No description provided for @hubBest.
  ///
  /// In en, this message translates to:
  /// **'Best: {percent}%'**
  String hubBest(int percent);

  /// No description provided for @hubTapToStart.
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get hubTapToStart;

  /// No description provided for @hubMasteryTriedSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category} mastery test. Best score: {percent} percent, {count, plural, =1{1 attempt} other{{count} attempts}}. Tap to start.'**
  String hubMasteryTriedSemantics(String category, int percent, int count);

  /// No description provided for @hubMasteryNewSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category} mastery test. Not attempted yet. Tap to start.'**
  String hubMasteryNewSemantics(String category);

  /// No description provided for @hubNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get hubNotTested;

  /// No description provided for @hubQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String hubQuestionCount(int count);

  /// No description provided for @hubOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get hubOverdue;

  /// No description provided for @hubDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String hubDue(String date);

  /// No description provided for @hubCustomTileSemantics.
  ///
  /// In en, this message translates to:
  /// **'{title}. {questions}. Tap to take.'**
  String hubCustomTileSemantics(String title, String questions);

  /// No description provided for @hubDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Assessment?'**
  String get hubDeleteTitle;

  /// No description provided for @hubDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete “{title}”? This cannot be undone.'**
  String hubDeleteBody(String title);

  /// No description provided for @hubCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get hubCancel;

  /// No description provided for @hubDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get hubDelete;

  /// No description provided for @hubResultSemantics.
  ///
  /// In en, this message translates to:
  /// **'{type}. Score: {percent} percent. {grade}. Completed {date}.'**
  String hubResultSemantics(
    String type,
    int percent,
    String grade,
    String date,
  );

  /// No description provided for @hubNoLearners.
  ///
  /// In en, this message translates to:
  /// **'No learners yet'**
  String get hubNoLearners;

  /// No description provided for @hubNoLearnersHint.
  ///
  /// In en, this message translates to:
  /// **'Share a class or home-group code, then assign the pre-test.'**
  String get hubNoLearnersHint;

  /// No description provided for @hubGain.
  ///
  /// In en, this message translates to:
  /// **'Gain {gain}'**
  String hubGain(String gain);

  /// No description provided for @hubLearnerRowSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}. {status}. Tap to open their profile.'**
  String hubLearnerRowSemantics(String name, String status);

  /// No description provided for @hubPre.
  ///
  /// In en, this message translates to:
  /// **'Pre'**
  String get hubPre;

  /// No description provided for @hubPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get hubPost;

  /// No description provided for @bannerOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue Assignments'**
  String get bannerOverdue;

  /// No description provided for @bannerPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Assignments'**
  String get bannerPending;

  /// No description provided for @bannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have 1 assessment to complete} other{You have {count} assessments to complete}}'**
  String bannerSubtitle(int count);

  /// No description provided for @bannerSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 pending assessment assigned to you} other{{count} pending assessments assigned to you}}'**
  String bannerSemantics(int count);

  /// No description provided for @titleAllCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get titleAllCategories;

  /// No description provided for @titleMastery.
  ///
  /// In en, this message translates to:
  /// **'{category} Mastery Test'**
  String titleMastery(String category);

  /// No description provided for @asgPreFirst.
  ///
  /// In en, this message translates to:
  /// **'Assign a pre-test first — the post-test mirrors it.'**
  String get asgPreFirst;

  /// No description provided for @asgQuizEmpty.
  ///
  /// In en, this message translates to:
  /// **'That quiz has no cards left to ask about.'**
  String get asgQuizEmpty;

  /// No description provided for @asgAssigned.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Assessment assigned to 1 learner!} other{Assessment assigned to {count} learners!}}'**
  String asgAssigned(int count);

  /// No description provided for @asgLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved for 1 learner on this device — not sent yet. It will upload when syncing is working.} other{Saved for {count} learners on this device — not sent yet. It will upload when syncing is working.}}'**
  String asgLocalOnly(int count);

  /// No description provided for @asgNotOwner.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device only. This profile was restored on another device, so that one now handles syncing. Restore it back here to send work to your learners.'**
  String get asgNotOwner;

  /// No description provided for @asgClassPre.
  ///
  /// In en, this message translates to:
  /// **'Class Pre-Test'**
  String get asgClassPre;

  /// No description provided for @asgClassPost.
  ///
  /// In en, this message translates to:
  /// **'Class Post-Test'**
  String get asgClassPost;

  /// No description provided for @asgTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign Assessment'**
  String get asgTitle;

  /// No description provided for @asgStudyLabel.
  ///
  /// In en, this message translates to:
  /// **'Study pre-test & post-test'**
  String get asgStudyLabel;

  /// No description provided for @asgStudyCaption.
  ///
  /// In en, this message translates to:
  /// **'The same questions for everyone you select. Assign the post-test when the study period ends.'**
  String get asgStudyCaption;

  /// No description provided for @asgQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Quizzes'**
  String get asgQuizzes;

  /// No description provided for @asgQuizzesCaption.
  ///
  /// In en, this message translates to:
  /// **'Makes a fresh test each time you assign it'**
  String get asgQuizzesCaption;

  /// No description provided for @asgSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved assessments'**
  String get asgSaved;

  /// No description provided for @asgSavedCaption.
  ///
  /// In en, this message translates to:
  /// **'A fixed set of questions'**
  String get asgSavedCaption;

  /// No description provided for @asgSelectStudents.
  ///
  /// In en, this message translates to:
  /// **'Select Students ({selected}/{total})'**
  String asgSelectStudents(int selected, int total);

  /// No description provided for @asgSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get asgSelectAll;

  /// No description provided for @asgDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get asgDeselectAll;

  /// No description provided for @asgDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline (optional)'**
  String get asgDeadline;

  /// No description provided for @asgSetDeadline.
  ///
  /// In en, this message translates to:
  /// **'Set Deadline'**
  String get asgSetDeadline;

  /// No description provided for @asgRemoveDeadline.
  ///
  /// In en, this message translates to:
  /// **'Remove deadline'**
  String get asgRemoveDeadline;

  /// No description provided for @asgInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions (optional)'**
  String get asgInstructions;

  /// No description provided for @asgInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'Add instructions for students...'**
  String get asgInstructionsHint;

  /// No description provided for @asgAssigning.
  ///
  /// In en, this message translates to:
  /// **'Assigning...'**
  String get asgAssigning;

  /// No description provided for @asgMadeFresh.
  ///
  /// In en, this message translates to:
  /// **'made fresh when you assign'**
  String get asgMadeFresh;

  /// No description provided for @asgMirrors.
  ///
  /// In en, this message translates to:
  /// **'mirrors the pre-test each learner sat'**
  String get asgMirrors;

  /// No description provided for @asgNoChildren.
  ///
  /// In en, this message translates to:
  /// **'No children yet'**
  String get asgNoChildren;

  /// No description provided for @asgNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students yet'**
  String get asgNoStudents;

  /// No description provided for @asgShareHomeHint.
  ///
  /// In en, this message translates to:
  /// **'Share your home group code so your child can join, then assign them work here.'**
  String get asgShareHomeHint;

  /// No description provided for @asgShareClassHint.
  ///
  /// In en, this message translates to:
  /// **'Share your class code so students can join, then assign them work here.'**
  String get asgShareClassHint;

  /// No description provided for @asgShareGroupCode.
  ///
  /// In en, this message translates to:
  /// **'Share Group Code'**
  String get asgShareGroupCode;

  /// No description provided for @asgShareClassCode.
  ///
  /// In en, this message translates to:
  /// **'Share Class Code'**
  String get asgShareClassCode;

  /// No description provided for @trkTitle.
  ///
  /// In en, this message translates to:
  /// **'Assignment Tracking'**
  String get trkTitle;

  /// No description provided for @trkRefresh.
  ///
  /// In en, this message translates to:
  /// **'Check for new results'**
  String get trkRefresh;

  /// No description provided for @trkDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Assignment?'**
  String get trkDeleteTitle;

  /// No description provided for @trkDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the assignment. Student results will be kept.'**
  String get trkDeleteBody;

  /// No description provided for @trkNotOwner.
  ///
  /// In en, this message translates to:
  /// **'Removed here only. This profile was restored on another device, so that one now handles syncing — your learners still have this assignment.'**
  String get trkNotOwner;

  /// No description provided for @trkDue.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String trkDue(String date);

  /// No description provided for @trkEmpty.
  ///
  /// In en, this message translates to:
  /// **'No assignments yet'**
  String get trkEmpty;

  /// No description provided for @trkEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Assign assessments to students and track their progress here.'**
  String get trkEmptyHint;

  /// No description provided for @gmScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Home Groups} other{Manage Classes}}'**
  String gmScreenTitle(String audience);

  /// No description provided for @gmCreateHint.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{e.g. The Santos Family} other{e.g. Grade 3 - Math}}'**
  String gmCreateHint(String audience);

  /// No description provided for @gmShareBlurb.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Open the app, tap “Join a home group”, and enter the code.} other{Open the app, tap “Join a class”, and enter the code.}}'**
  String gmShareBlurb(String audience);

  /// No description provided for @gmRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get gmRefresh;

  /// No description provided for @gmNewGroup.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{New home group} other{New class}}'**
  String gmNewGroup(String audience);

  /// No description provided for @gmEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{No home groups yet} other{No classes yet}}'**
  String gmEmptyTitle(String audience);

  /// No description provided for @gmEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Create a home group, then share the join code so your children can join from their own devices.} other{Create a class, then share the join code so your students can join from their own devices.}}'**
  String gmEmptyBody(String audience);

  /// No description provided for @gmCreateGroup.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Create home group} other{Create class}}'**
  String gmCreateGroup(String audience);

  /// No description provided for @gmGroupName.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Home group name} other{Class name}}'**
  String gmGroupName(String audience);

  /// No description provided for @gmCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get gmCreate;

  /// No description provided for @gmNameRequired.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Home group name is required} other{Class name is required}}'**
  String gmNameRequired(String audience);

  /// No description provided for @gmCreated.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Home group created.} other{Class created.}}'**
  String gmCreated(String audience);

  /// No description provided for @gmOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get gmOverview;

  /// No description provided for @gmGroupCount.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{{count, plural, =1{1 home group} other{{count} home groups}}} other{{count, plural, =1{1 class} other{{count} classes}}}}'**
  String gmGroupCount(String audience, int count);

  /// No description provided for @gmMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{{count, plural, =1{1 child} other{{count} children}}} other{{count, plural, =1{1 student} other{{count} students}}}}'**
  String gmMemberCount(String audience, int count);

  /// No description provided for @gmGroupsLabel.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{home groups} other{classes}}'**
  String gmGroupsLabel(String audience);

  /// No description provided for @gmMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{children} other{students}}'**
  String gmMembersLabel(String audience);

  /// No description provided for @gmActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get gmActive;

  /// No description provided for @gmEnrolled.
  ///
  /// In en, this message translates to:
  /// **'enrolled'**
  String get gmEnrolled;

  /// No description provided for @gmNewestJoin.
  ///
  /// In en, this message translates to:
  /// **'Newest join'**
  String get gmNewestJoin;

  /// No description provided for @gmNoJoins.
  ///
  /// In en, this message translates to:
  /// **'no joins yet'**
  String get gmNoJoins;

  /// No description provided for @gmMostRecent.
  ///
  /// In en, this message translates to:
  /// **'most recent'**
  String get gmMostRecent;

  /// No description provided for @gmLoadingRoster.
  ///
  /// In en, this message translates to:
  /// **'Loading roster…'**
  String get gmLoadingRoster;

  /// No description provided for @gmGroupActions.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Home group actions} other{Class actions}}'**
  String gmGroupActions(String audience);

  /// No description provided for @gmRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get gmRename;

  /// No description provided for @gmAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get gmAccessibility;

  /// No description provided for @gmNewJoinCode.
  ///
  /// In en, this message translates to:
  /// **'New join code'**
  String get gmNewJoinCode;

  /// No description provided for @gmLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get gmLeaderboard;

  /// No description provided for @gmLockRetakes.
  ///
  /// In en, this message translates to:
  /// **'Lock test retakes'**
  String get gmLockRetakes;

  /// No description provided for @gmAllowRetakes.
  ///
  /// In en, this message translates to:
  /// **'Allow test retakes'**
  String get gmAllowRetakes;

  /// No description provided for @gmDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Delete home group} other{Delete class}}'**
  String gmDeleteGroup(String audience);

  /// No description provided for @gmHideRoster.
  ///
  /// In en, this message translates to:
  /// **'Hide roster'**
  String get gmHideRoster;

  /// No description provided for @gmShowRoster.
  ///
  /// In en, this message translates to:
  /// **'Show roster'**
  String get gmShowRoster;

  /// No description provided for @gmCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get gmCopyCode;

  /// No description provided for @gmShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share code'**
  String get gmShareCode;

  /// No description provided for @gmRosterError.
  ///
  /// In en, this message translates to:
  /// **'Roster error: {error}'**
  String gmRosterError(String error);

  /// No description provided for @gmNoMembers.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{No children have joined yet — share the code above.} other{No students have joined yet — share the code above.}}'**
  String gmNoMembers(String audience);

  /// No description provided for @gmSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String gmSelected(int count);

  /// No description provided for @gmRemoveCount.
  ///
  /// In en, this message translates to:
  /// **'Remove ({count})'**
  String gmRemoveCount(int count);

  /// No description provided for @gmLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock test retakes?'**
  String get gmLockTitle;

  /// No description provided for @gmAllowTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow test retakes?'**
  String get gmAllowTitle;

  /// No description provided for @gmLockBody.
  ///
  /// In en, this message translates to:
  /// **'Learners in “{name}” will not be able to sit the pre-test or post-test again once they have finished it. Assessments you assign are unaffected.'**
  String gmLockBody(String name);

  /// No description provided for @gmAllowBody.
  ///
  /// In en, this message translates to:
  /// **'Learners in “{name}” will be able to sit the pre-test or post-test again. The most recent sitting is the one their learning gain is measured from.'**
  String gmAllowBody(String name);

  /// No description provided for @gmLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get gmLock;

  /// No description provided for @gmAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get gmAllow;

  /// No description provided for @gmRetakesLocked.
  ///
  /// In en, this message translates to:
  /// **'Test retakes locked.'**
  String get gmRetakesLocked;

  /// No description provided for @gmRetakesAllowed.
  ///
  /// In en, this message translates to:
  /// **'Test retakes allowed.'**
  String get gmRetakesAllowed;

  /// No description provided for @gmCouldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String gmCouldNotSave(String error);

  /// No description provided for @gmCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {code}'**
  String gmCopied(String code);

  /// No description provided for @gmShareText.
  ///
  /// In en, this message translates to:
  /// **'Join “{name}” on FlashLearn PWD with code {code}. {blurb}'**
  String gmShareText(String name, String code, String blurb);

  /// No description provided for @gmShareSubject.
  ///
  /// In en, this message translates to:
  /// **'FlashLearn PWD join code'**
  String get gmShareSubject;

  /// No description provided for @gmCouldNotShare.
  ///
  /// In en, this message translates to:
  /// **'Could not share: {error}'**
  String gmCouldNotShare(String error);

  /// No description provided for @gmRenameGroup.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Rename home group} other{Rename class}}'**
  String gmRenameGroup(String audience);

  /// No description provided for @gmSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get gmSave;

  /// No description provided for @gmRenamed.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Home group renamed.} other{Class renamed.}}'**
  String gmRenamed(String audience);

  /// No description provided for @gmAccessibilitySet.
  ///
  /// In en, this message translates to:
  /// **'Accessibility set to {type}.'**
  String gmAccessibilitySet(String type);

  /// No description provided for @gmCouldNotUpdate.
  ///
  /// In en, this message translates to:
  /// **'Could not update: {error}'**
  String gmCouldNotUpdate(String error);

  /// No description provided for @gmResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset join code?'**
  String get gmResetTitle;

  /// No description provided for @gmResetBody.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{A new code will be generated. Children who already joined stay enrolled, but the old code stops working.} other{A new code will be generated. Students who already joined stay enrolled, but the old code stops working.}}'**
  String gmResetBody(String audience);

  /// No description provided for @gmReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get gmReset;

  /// No description provided for @gmNewCodeGenerated.
  ///
  /// In en, this message translates to:
  /// **'New code generated.'**
  String get gmNewCodeGenerated;

  /// No description provided for @gmCouldNotRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Could not regenerate: {error}'**
  String gmCouldNotRegenerate(String error);

  /// No description provided for @gmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String gmDeleteTitle(String name);

  /// No description provided for @gmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{All children will be unenrolled. Their profiles and progress stay on their own devices.} other{All students will be unenrolled. Their profiles and progress stay on their own devices.}}'**
  String gmDeleteBody(String audience);

  /// No description provided for @gmCouldNotDelete.
  ///
  /// In en, this message translates to:
  /// **'Could not delete: {error}'**
  String gmCouldNotDelete(String error);

  /// No description provided for @gmRenameInRoster.
  ///
  /// In en, this message translates to:
  /// **'Rename in roster'**
  String get gmRenameInRoster;

  /// No description provided for @gmDisplayNameIn.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Display name in this home group} other{Display name in this class}}'**
  String gmDisplayNameIn(String audience);

  /// No description provided for @gmDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required'**
  String get gmDisplayNameRequired;

  /// No description provided for @gmRenameMemberNote.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{This will rename the child in your roster and on their device.} other{This will rename the student in your roster and on their device.}}'**
  String gmRenameMemberNote(String audience);

  /// No description provided for @gmMemberRenamed.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Child renamed.} other{Student renamed.}}'**
  String gmMemberRenamed(String audience);

  /// No description provided for @gmUnlockedFor.
  ///
  /// In en, this message translates to:
  /// **'{name} unlocked for {duration}.'**
  String gmUnlockedFor(String name, String duration);

  /// No description provided for @gmCouldNotUnlock.
  ///
  /// In en, this message translates to:
  /// **'Could not unlock: {error}'**
  String gmCouldNotUnlock(String error);

  /// No description provided for @gmRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String gmRemoveTitle(String name);

  /// No description provided for @gmRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{They\'ll be unenrolled from this home group. Their profile and progress are kept on their device.} other{They\'ll be unenrolled from this class. Their profile and progress are kept on their device.}}'**
  String gmRemoveBody(String audience);

  /// No description provided for @gmRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get gmRemove;

  /// No description provided for @gmCouldNotRemove.
  ///
  /// In en, this message translates to:
  /// **'Could not remove: {error}'**
  String gmCouldNotRemove(String error);

  /// No description provided for @gmRemoveManyTitle.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{{count, plural, =1{Remove 1 child?} other{Remove {count} children?}}} other{{count, plural, =1{Remove 1 student?} other{Remove {count} students?}}}}'**
  String gmRemoveManyTitle(String audience, int count);

  /// No description provided for @gmRemoveManyBody.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Their profiles and progress are kept on their devices; they just lose this home group linkage.} other{Their profiles and progress are kept on their devices; they just lose this class linkage.}}'**
  String gmRemoveManyBody(String audience);

  /// No description provided for @gmMemberActions.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Child actions} other{Student actions}}'**
  String gmMemberActions(String audience);

  /// No description provided for @gmViewProgress.
  ///
  /// In en, this message translates to:
  /// **'View progress'**
  String get gmViewProgress;

  /// No description provided for @gmNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get gmNotes;

  /// No description provided for @gmTimeLimits.
  ///
  /// In en, this message translates to:
  /// **'Time limits'**
  String get gmTimeLimits;

  /// No description provided for @gmAlarms.
  ///
  /// In en, this message translates to:
  /// **'Alarms'**
  String get gmAlarms;

  /// No description provided for @gmRoutine.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get gmRoutine;

  /// No description provided for @gmUnlockScreen.
  ///
  /// In en, this message translates to:
  /// **'Unlock screen'**
  String get gmUnlockScreen;

  /// No description provided for @gmRemoveFrom.
  ///
  /// In en, this message translates to:
  /// **'{audience, select, parent{Remove from home group} other{Remove from class}}'**
  String gmRemoveFrom(String audience);

  /// No description provided for @gmJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined {date} · {ago}'**
  String gmJoined(String date, String ago);

  /// No description provided for @gmUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock {name}'**
  String gmUnlockTitle(String name);

  /// No description provided for @gmUnlockBody.
  ///
  /// In en, this message translates to:
  /// **'How long should the lock screen stay off? The screen will lock again automatically when this window expires.'**
  String get gmUnlockBody;

  /// No description provided for @gm15min.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get gm15min;

  /// No description provided for @gm30min.
  ///
  /// In en, this message translates to:
  /// **'30 min'**
  String get gm30min;

  /// No description provided for @gm1hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get gm1hour;

  /// No description provided for @gmHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String gmHours(int count);

  /// No description provided for @gmMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String gmMinutes(int count);

  /// No description provided for @gmJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get gmJustNow;

  /// No description provided for @gmMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String gmMinutesAgo(int count);

  /// No description provided for @gmHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String gmHoursAgo(int count);

  /// No description provided for @gmDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String gmDaysAgo(int count);

  /// No description provided for @gmWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}w ago'**
  String gmWeeksAgo(int count);

  /// No description provided for @acpApplies.
  ///
  /// In en, this message translates to:
  /// **'Applies to learners who join from now on. Anyone already enrolled keeps their current setup.'**
  String get acpApplies;

  /// No description provided for @acpJoinersGet.
  ///
  /// In en, this message translates to:
  /// **'Students who join this code get this version of the app automatically — no setup needed on their side.'**
  String get acpJoinersGet;

  /// No description provided for @clipFailedSemantics.
  ///
  /// In en, this message translates to:
  /// **'This sign could not be loaded. Answer from what you know, or skip the question.'**
  String get clipFailedSemantics;

  /// No description provided for @clipSemantics.
  ///
  /// In en, this message translates to:
  /// **'A sign-language clip. It repeats on its own; double tap to play it again.'**
  String get clipSemantics;

  /// No description provided for @clipReplay.
  ///
  /// In en, this message translates to:
  /// **'Play the sign again'**
  String get clipReplay;

  /// No description provided for @clipFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'This sign would not load'**
  String get clipFailedTitle;

  /// No description provided for @clipFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet and try again, or answer from what you already know.'**
  String get clipFailedBody;

  /// No description provided for @navGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get navGoBack;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You’re offline — everything still works!'**
  String get offlineBanner;

  /// No description provided for @homePlayerProfile.
  ///
  /// In en, this message translates to:
  /// **'Player Profile'**
  String get homePlayerProfile;

  /// No description provided for @homeMyDay.
  ///
  /// In en, this message translates to:
  /// **'My Day'**
  String get homeMyDay;

  /// No description provided for @homeMoodCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Mood Check-In'**
  String get homeMoodCheckIn;

  /// No description provided for @homeDailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Daily Challenge'**
  String get homeDailyChallenge;

  /// No description provided for @homeAssignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get homeAssignments;

  /// No description provided for @homePlayAndLearn.
  ///
  /// In en, this message translates to:
  /// **'Play & Learn'**
  String get homePlayAndLearn;

  /// No description provided for @homeGamesSub.
  ///
  /// In en, this message translates to:
  /// **'Play & learn'**
  String get homeGamesSub;

  /// No description provided for @homeWordsSub.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get homeWordsSub;

  /// No description provided for @homeStories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get homeStories;

  /// No description provided for @homeStoriesSub.
  ///
  /// In en, this message translates to:
  /// **'Read & answer'**
  String get homeStoriesSub;

  /// No description provided for @homeFslSub.
  ///
  /// In en, this message translates to:
  /// **'Sign language'**
  String get homeFslSub;

  /// No description provided for @homeToPractice.
  ///
  /// In en, this message translates to:
  /// **'{count} to practice'**
  String homeToPractice(int count);

  /// No description provided for @homeReviewSub.
  ///
  /// In en, this message translates to:
  /// **'Review words'**
  String get homeReviewSub;

  /// No description provided for @homeProgressSub.
  ///
  /// In en, this message translates to:
  /// **'Your journey'**
  String get homeProgressSub;

  /// No description provided for @homeLearningStudy.
  ///
  /// In en, this message translates to:
  /// **'Learning & Study'**
  String get homeLearningStudy;

  /// No description provided for @homeLearningPaths.
  ///
  /// In en, this message translates to:
  /// **'Learning Paths'**
  String get homeLearningPaths;

  /// No description provided for @homeGuidedPractice.
  ///
  /// In en, this message translates to:
  /// **'Guided Practice'**
  String get homeGuidedPractice;

  /// No description provided for @homeHardWords.
  ///
  /// In en, this message translates to:
  /// **'Hard Words'**
  String get homeHardWords;

  /// No description provided for @homeWhatToStudy.
  ///
  /// In en, this message translates to:
  /// **'What to Study'**
  String get homeWhatToStudy;

  /// No description provided for @homeAssessmentProgress.
  ///
  /// In en, this message translates to:
  /// **'Assessment & Progress'**
  String get homeAssessmentProgress;

  /// No description provided for @homeLearningGains.
  ///
  /// In en, this message translates to:
  /// **'Learning Gains'**
  String get homeLearningGains;

  /// No description provided for @homeMyPortfolio.
  ///
  /// In en, this message translates to:
  /// **'My Portfolio'**
  String get homeMyPortfolio;

  /// No description provided for @homeMyGoals.
  ///
  /// In en, this message translates to:
  /// **'My Goals'**
  String get homeMyGoals;

  /// No description provided for @homeHowWasIt.
  ///
  /// In en, this message translates to:
  /// **'How was it?'**
  String get homeHowWasIt;

  /// No description provided for @homeCommunication.
  ///
  /// In en, this message translates to:
  /// **'Communication & Language'**
  String get homeCommunication;

  /// No description provided for @homeFslDictionary.
  ///
  /// In en, this message translates to:
  /// **'FSL Dictionary'**
  String get homeFslDictionary;

  /// No description provided for @homeSocial.
  ///
  /// In en, this message translates to:
  /// **'Social & Collaboration'**
  String get homeSocial;

  /// No description provided for @homeJoinAClass.
  ///
  /// In en, this message translates to:
  /// **'Join a class'**
  String get homeJoinAClass;

  /// No description provided for @homeJoinTheClass.
  ///
  /// In en, this message translates to:
  /// **'Join the class'**
  String get homeJoinTheClass;

  /// No description provided for @homeLiveClassBody.
  ///
  /// In en, this message translates to:
  /// **'Answer live questions for stars and raise your hand for help.'**
  String get homeLiveClassBody;

  /// No description provided for @homeLiveClassSemantics.
  ///
  /// In en, this message translates to:
  /// **'Join the live class activity and raise your hand.'**
  String get homeLiveClassSemantics;

  /// No description provided for @homeHaveClassCode.
  ///
  /// In en, this message translates to:
  /// **'Have a class code?'**
  String get homeHaveClassCode;

  /// No description provided for @homeJoinClassBody.
  ///
  /// In en, this message translates to:
  /// **'Join a class to save your progress and let your teacher follow along.'**
  String get homeJoinClassBody;

  /// No description provided for @homeJoinClassSemantics.
  ///
  /// In en, this message translates to:
  /// **'Have a class code? Join a class to save your progress.'**
  String get homeJoinClassSemantics;

  /// No description provided for @homePeerCollab.
  ///
  /// In en, this message translates to:
  /// **'Peer Collab'**
  String get homePeerCollab;

  /// No description provided for @homeMyNotes.
  ///
  /// In en, this message translates to:
  /// **'My Notes'**
  String get homeMyNotes;

  /// No description provided for @homeWellbeing.
  ///
  /// In en, this message translates to:
  /// **'Personal & Wellbeing'**
  String get homeWellbeing;

  /// No description provided for @homeStickerAlbum.
  ///
  /// In en, this message translates to:
  /// **'Sticker Album'**
  String get homeStickerAlbum;

  /// No description provided for @homeMyNotebook.
  ///
  /// In en, this message translates to:
  /// **'My Notebook'**
  String get homeMyNotebook;

  /// No description provided for @homeStatsSemantics.
  ///
  /// In en, this message translates to:
  /// **'Stats: {streak} day streak, {words} words learned, {balance} stars to spend out of {total} earned'**
  String homeStatsSemantics(int streak, int words, int balance, int total);

  /// No description provided for @homeDailyReward.
  ///
  /// In en, this message translates to:
  /// **'Daily Reward'**
  String get homeDailyReward;

  /// No description provided for @homeDailyRewardTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Reward!'**
  String get homeDailyRewardTitle;

  /// No description provided for @homeDayNumber.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String homeDayNumber(int day);

  /// No description provided for @homeDayShort.
  ///
  /// In en, this message translates to:
  /// **'D{day}'**
  String homeDayShort(int day);

  /// No description provided for @homeYouEarnedStars.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You earned 1 star.} other{You earned {count} stars.}}'**
  String homeYouEarnedStars(int count);

  /// No description provided for @homeComeBackTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for more!'**
  String get homeComeBackTomorrow;

  /// No description provided for @homeCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get homeCollect;

  /// No description provided for @homeCollectStar.
  ///
  /// In en, this message translates to:
  /// **'Collect! 🌟'**
  String get homeCollectStar;

  /// No description provided for @homeDailyChallengeChip.
  ///
  /// In en, this message translates to:
  /// **'🏆 Daily Challenge'**
  String get homeDailyChallengeChip;

  /// No description provided for @homeDayStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day streak} other{{count} day streak}}'**
  String homeDayStreak(int count);

  /// No description provided for @homeOpenDailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'View full daily challenge with calendar and stats'**
  String get homeOpenDailyChallenge;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get homeViewAll;

  /// No description provided for @homeWhatInFilipino.
  ///
  /// In en, this message translates to:
  /// **'What is this in Filipino?'**
  String get homeWhatInFilipino;

  /// No description provided for @homeCorrectBonus.
  ///
  /// In en, this message translates to:
  /// **'Correct! +2 bonus stars ⭐'**
  String get homeCorrectBonus;

  /// No description provided for @homeAnswerIs.
  ///
  /// In en, this message translates to:
  /// **'The answer is: {word}'**
  String homeAnswerIs(String word);

  /// No description provided for @homeChallengeComplete.
  ///
  /// In en, this message translates to:
  /// **'Challenge Complete! ✨'**
  String get homeChallengeComplete;

  /// No description provided for @homeAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'The answer was: {word}'**
  String homeAnswerWas(String word);

  /// No description provided for @homeLevelSemantics.
  ///
  /// In en, this message translates to:
  /// **'Player Profile. Level {level} {title}, {xp} XP total, {next}. Opens your stats, rewards and achievements.'**
  String homeLevelSemantics(int level, String title, int xp, String next);

  /// No description provided for @homeXpToLevel.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP to level {level} {title}'**
  String homeXpToLevel(int xp, int level, String title);

  /// No description provided for @homeMaxLevel.
  ///
  /// In en, this message translates to:
  /// **'max level reached'**
  String get homeMaxLevel;

  /// No description provided for @childGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String childGreeting(String name);

  /// No description provided for @childFriend.
  ///
  /// In en, this message translates to:
  /// **'Friend'**
  String get childFriend;

  /// No description provided for @childWhatToDo.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do today?'**
  String get childWhatToDo;

  /// No description provided for @childMyFeelings.
  ///
  /// In en, this message translates to:
  /// **'My Feelings'**
  String get childMyFeelings;

  /// No description provided for @childSignDictionary.
  ///
  /// In en, this message translates to:
  /// **'Sign Dictionary'**
  String get childSignDictionary;

  /// No description provided for @childPracticeWords.
  ///
  /// In en, this message translates to:
  /// **'Practice Words'**
  String get childPracticeWords;

  /// No description provided for @childMyProgress.
  ///
  /// In en, this message translates to:
  /// **'My Progress'**
  String get childMyProgress;

  /// No description provided for @childExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore & Create'**
  String get childExplore;

  /// No description provided for @childAdventureMap.
  ///
  /// In en, this message translates to:
  /// **'Adventure Map'**
  String get childAdventureMap;

  /// No description provided for @childPracticeWithMe.
  ///
  /// In en, this message translates to:
  /// **'Practice With Me'**
  String get childPracticeWithMe;

  /// No description provided for @childBuddy.
  ///
  /// In en, this message translates to:
  /// **'Buddy'**
  String get childBuddy;

  /// No description provided for @childFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get childFriends;

  /// No description provided for @childRewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards & Feelings'**
  String get childRewards;

  /// No description provided for @childPlayerCard.
  ///
  /// In en, this message translates to:
  /// **'My Player Card'**
  String get childPlayerCard;

  /// No description provided for @childStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get childStickers;

  /// No description provided for @childSwitchProfile.
  ///
  /// In en, this message translates to:
  /// **'Switch profile'**
  String get childSwitchProfile;

  /// No description provided for @childStatsSemantics.
  ///
  /// In en, this message translates to:
  /// **'My day: {streak} day streak, {words} words learned, {stars} stars earned'**
  String childStatsSemantics(int streak, int words, int stars);

  /// No description provided for @eduRecentStudents.
  ///
  /// In en, this message translates to:
  /// **'Recent Students'**
  String get eduRecentStudents;

  /// No description provided for @eduStudentStats.
  ///
  /// In en, this message translates to:
  /// **'{words} words  •  🔥 {streak} streak  •  ⭐ {stars}'**
  String eduStudentStats(int words, int streak, int stars);

  /// No description provided for @eduDeckSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category} deck, {count} cards'**
  String eduDeckSemantics(String category, int count);

  /// No description provided for @eduDeckCards.
  ///
  /// In en, this message translates to:
  /// **'{count} cards'**
  String eduDeckCards(int count);

  /// No description provided for @catCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category} flashcards, {count} words, {percent} percent progress'**
  String catCardSemantics(String category, int count, int percent);

  /// No description provided for @catCardWords.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String catCardWords(int count);

  /// No description provided for @playerFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerFallbackName;

  /// No description provided for @playerModeNote.
  ///
  /// In en, this message translates to:
  /// **'You’re in Player mode. Your fun stays on this device.'**
  String get playerModeNote;

  /// No description provided for @playerStartLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get playerStartLearning;

  /// No description provided for @playerBrowseFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Browse flashcards'**
  String get playerBrowseFlashcards;

  /// No description provided for @playerSaveStars.
  ///
  /// In en, this message translates to:
  /// **'Save your stars across devices'**
  String get playerSaveStars;

  /// No description provided for @playerSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Join a class or home group to back up your progress and learn with others.'**
  String get playerSaveBody;

  /// No description provided for @playerJoinClass.
  ///
  /// In en, this message translates to:
  /// **'Join class'**
  String get playerJoinClass;

  /// No description provided for @playerJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join group'**
  String get playerJoinGroup;

  /// No description provided for @levelSemantics.
  ///
  /// In en, this message translates to:
  /// **'Level {level} {title}, {xp} XP total, {next}'**
  String levelSemantics(int level, String title, int xp, String next);

  /// No description provided for @levelXpToShort.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP to Lv.{level} {title}'**
  String levelXpToShort(int xp, int level, String title);

  /// No description provided for @levelUpTitle.
  ///
  /// In en, this message translates to:
  /// **'LEVEL UP!'**
  String get levelUpTitle;

  /// No description provided for @levelReached.
  ///
  /// In en, this message translates to:
  /// **'You’ve reached Level {level}!'**
  String levelReached(int level);

  /// No description provided for @levelTapAnywhere.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to continue'**
  String get levelTapAnywhere;

  /// No description provided for @deckBrowseTemplates.
  ///
  /// In en, this message translates to:
  /// **'Browse templates'**
  String get deckBrowseTemplates;

  /// No description provided for @deckSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category} deck. {count} cards. {percent} percent complete.'**
  String deckSemantics(String category, int count, int percent);

  /// No description provided for @deckChipSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label} custom flashcards'**
  String deckChipSemantics(String label);

  /// No description provided for @viewerNofM.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}.'**
  String viewerNofM(int index, int total);

  /// No description provided for @viewerDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete “{word}”? This cannot be undone.'**
  String viewerDeleteConfirm(String word);

  /// No description provided for @viewerShowMe.
  ///
  /// In en, this message translates to:
  /// **'Show Me'**
  String get viewerShowMe;

  /// No description provided for @viewerExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get viewerExamples;

  /// No description provided for @viewerWriteNote.
  ///
  /// In en, this message translates to:
  /// **'Write a note about this word'**
  String get viewerWriteNote;

  /// No description provided for @viewerPauseAuto.
  ///
  /// In en, this message translates to:
  /// **'Pause auto-play'**
  String get viewerPauseAuto;

  /// No description provided for @viewerStartAuto.
  ///
  /// In en, this message translates to:
  /// **'Start auto-play'**
  String get viewerStartAuto;

  /// No description provided for @viewerFlippedSemantics.
  ///
  /// In en, this message translates to:
  /// **'{english} in Filipino is {filipino}. Tap to flip back.'**
  String viewerFlippedSemantics(String english, String filipino);

  /// No description provided for @viewerFrontSemantics.
  ///
  /// In en, this message translates to:
  /// **'{english}, {category} category. Tap to see details.'**
  String viewerFrontSemantics(String english, String category);

  /// No description provided for @viewerButton.
  ///
  /// In en, this message translates to:
  /// **'{label} button'**
  String viewerButton(String label);

  /// No description provided for @viewerGazeStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting gaze…'**
  String get viewerGazeStarting;

  /// No description provided for @viewerGazeLook.
  ///
  /// In en, this message translates to:
  /// **'Look at the screen'**
  String get viewerGazeLook;

  /// No description provided for @viewerGazeChoose.
  ///
  /// In en, this message translates to:
  /// **'Look ◀ ▶ to choose · blink to open'**
  String get viewerGazeChoose;

  /// No description provided for @progMasterySemantics.
  ///
  /// In en, this message translates to:
  /// **'Overall mastery: {percent} percent. {mastered} out of {total} words learned.'**
  String progMasterySemantics(int percent, int mastered, int total);

  /// No description provided for @progStarsEarned.
  ///
  /// In en, this message translates to:
  /// **'{count} stars earned'**
  String progStarsEarned(int count);

  /// No description provided for @progStarsCollected.
  ///
  /// In en, this message translates to:
  /// **'⭐ {count} stars collected!'**
  String progStarsCollected(int count);

  /// No description provided for @progAchievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{title} achievement, unlocked'**
  String progAchievementUnlocked(String title);

  /// No description provided for @progAchievementLocked.
  ///
  /// In en, this message translates to:
  /// **'{title} achievement, locked'**
  String progAchievementLocked(String title);

  /// No description provided for @progJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get progJustNow;

  /// No description provided for @progYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get progYesterday;

  /// No description provided for @progGameSemantics.
  ///
  /// In en, this message translates to:
  /// **'{game}: {score} of {total}, {percent} percent, {stars} stars, {when}'**
  String progGameSemantics(
    String game,
    int score,
    int total,
    int percent,
    int stars,
    String when,
  );

  /// No description provided for @progCategoryRowSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category} category: {mastered} of {total} words mastered, {percent} percent'**
  String progCategoryRowSemantics(
    String category,
    int mastered,
    int total,
    int percent,
  );

  /// No description provided for @dcExplain.
  ///
  /// In en, this message translates to:
  /// **'“{english}” is “{filipino}” in Filipino.'**
  String dcExplain(String english, String filipino);

  /// No description provided for @dcTitle.
  ///
  /// In en, this message translates to:
  /// **'🎯 Daily Mission'**
  String get dcTitle;

  /// No description provided for @dcChip.
  ///
  /// In en, this message translates to:
  /// **'✨ Daily Mission'**
  String get dcChip;

  /// No description provided for @dcNoWords.
  ///
  /// In en, this message translates to:
  /// **'No words available for today’s mission yet.'**
  String get dcNoWords;

  /// No description provided for @dcWordNofM.
  ///
  /// In en, this message translates to:
  /// **'Word {index} of {total}'**
  String dcWordNofM(int index, int total);

  /// No description provided for @dcListen.
  ///
  /// In en, this message translates to:
  /// **'Listen to English pronunciation'**
  String get dcListen;

  /// No description provided for @dcFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish Mission'**
  String get dcFinish;

  /// No description provided for @dcNextWord.
  ///
  /// In en, this message translates to:
  /// **'Next Word'**
  String get dcNextWord;

  /// No description provided for @dcCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct! +1 star ⭐'**
  String get dcCorrect;

  /// No description provided for @dcNotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite!'**
  String get dcNotQuite;

  /// No description provided for @dcPerfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect mission! 🎉'**
  String get dcPerfect;

  /// No description provided for @dcComplete.
  ///
  /// In en, this message translates to:
  /// **'Mission complete! ✨'**
  String get dcComplete;

  /// No description provided for @dcYouGot.
  ///
  /// In en, this message translates to:
  /// **'You got {correct} of {total} correct.'**
  String dcYouGot(int correct, int total);

  /// No description provided for @dcYouGotStars.
  ///
  /// In en, this message translates to:
  /// **'You got {correct} of {total} correct and earned {stars} ⭐.'**
  String dcYouGotStars(int correct, int total, int stars);

  /// No description provided for @dcComeBack.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for a new mission'**
  String get dcComeBack;

  /// No description provided for @dcTodayDone.
  ///
  /// In en, this message translates to:
  /// **'Today’s mission completed! ✨'**
  String get dcTodayDone;

  /// No description provided for @dcFiftySemantics.
  ///
  /// In en, this message translates to:
  /// **'Fifty-fifty hint, removes two wrong answers, {remaining} left'**
  String dcFiftySemantics(int remaining);

  /// No description provided for @dcStreakStart.
  ///
  /// In en, this message translates to:
  /// **'Start your streak today!'**
  String get dcStreakStart;

  /// No description provided for @dcStreakGoing.
  ///
  /// In en, this message translates to:
  /// **'{streak} day streak — keep going!'**
  String dcStreakGoing(int streak);

  /// No description provided for @dcStreakAmazing.
  ///
  /// In en, this message translates to:
  /// **'{streak} day streak — amazing!'**
  String dcStreakAmazing(int streak);

  /// No description provided for @dcStreakFire.
  ///
  /// In en, this message translates to:
  /// **'{streak} day streak — on fire!'**
  String dcStreakFire(int streak);

  /// No description provided for @dcStreakLegend.
  ///
  /// In en, this message translates to:
  /// **'{streak} day streak — legendary!'**
  String dcStreakLegend(int streak);

  /// No description provided for @dcStreakHint.
  ///
  /// In en, this message translates to:
  /// **'Complete the daily mission to extend your streak'**
  String get dcStreakHint;

  /// No description provided for @dcRemovedByHint.
  ///
  /// In en, this message translates to:
  /// **'{text}, removed by hint'**
  String dcRemovedByHint(String text);

  /// No description provided for @dcPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get dcPrevMonth;

  /// No description provided for @dcNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get dcNextMonth;

  /// No description provided for @dcCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get dcCurrentStreak;

  /// No description provided for @dcDaysCompleted.
  ///
  /// In en, this message translates to:
  /// **'Days Completed'**
  String get dcDaysCompleted;

  /// No description provided for @dcStarsEarned.
  ///
  /// In en, this message translates to:
  /// **'Stars Earned'**
  String get dcStarsEarned;

  /// No description provided for @dcBadgesEarned.
  ///
  /// In en, this message translates to:
  /// **'Badges Earned'**
  String get dcBadgesEarned;

  /// No description provided for @dcBadge3Day.
  ///
  /// In en, this message translates to:
  /// **'3-Day Streak'**
  String get dcBadge3Day;

  /// No description provided for @dcBadgeWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly Warrior'**
  String get dcBadgeWeekly;

  /// No description provided for @dcBadgeMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly Master'**
  String get dcBadgeMonthly;

  /// No description provided for @dcBadge10.
  ///
  /// In en, this message translates to:
  /// **'10 Days Done'**
  String get dcBadge10;

  /// No description provided for @dcBadge50.
  ///
  /// In en, this message translates to:
  /// **'50 Days Done'**
  String get dcBadge50;

  /// No description provided for @dcBadge100.
  ///
  /// In en, this message translates to:
  /// **'Century Club'**
  String get dcBadge100;

  /// No description provided for @fslOfflineSigns.
  ///
  /// In en, this message translates to:
  /// **'Offline signs'**
  String get fslOfflineSigns;

  /// No description provided for @fslHasSign.
  ///
  /// In en, this message translates to:
  /// **'Has sign'**
  String get fslHasSign;

  /// No description provided for @fslMySigns.
  ///
  /// In en, this message translates to:
  /// **'My Signs · {count}'**
  String fslMySigns(int count);

  /// No description provided for @fslICanSign.
  ///
  /// In en, this message translates to:
  /// **'I can sign · {count}'**
  String fslICanSign(int count);

  /// No description provided for @fslWordCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 word} other{{count} words}}'**
  String fslWordCount(int count);

  /// No description provided for @fslWatchedOf.
  ///
  /// In en, this message translates to:
  /// **'{watched} of {total} signs watched'**
  String fslWatchedOf(int watched, int total);

  /// No description provided for @fslWatchSemantics.
  ///
  /// In en, this message translates to:
  /// **'{english}, {filipino}. Watch the sign.'**
  String fslWatchSemantics(String english, String filipino);

  /// No description provided for @fslWatchedSemantics.
  ///
  /// In en, this message translates to:
  /// **'{english}, {filipino}. Already watched. Watch the sign.'**
  String fslWatchedSemantics(String english, String filipino);

  /// No description provided for @fslNoVideoSemantics.
  ///
  /// In en, this message translates to:
  /// **'{english}, {filipino}. No sign video yet.'**
  String fslNoVideoSemantics(String english, String filipino);

  /// No description provided for @fslRemoveMySigns.
  ///
  /// In en, this message translates to:
  /// **'Remove {word} from My Signs'**
  String fslRemoveMySigns(String word);

  /// No description provided for @fslAddMySigns.
  ///
  /// In en, this message translates to:
  /// **'Add {word} to My Signs'**
  String fslAddMySigns(String word);

  /// No description provided for @lpAdventureMap.
  ///
  /// In en, this message translates to:
  /// **'Adventure Map 🗺️'**
  String get lpAdventureMap;

  /// No description provided for @lpPillDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get lpPillDone;

  /// No description provided for @lpPillStart.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get lpPillStart;

  /// No description provided for @lpPillEnter.
  ///
  /// In en, this message translates to:
  /// **'ENTER'**
  String get lpPillEnter;

  /// No description provided for @lpPillReplay.
  ///
  /// In en, this message translates to:
  /// **'REPLAY'**
  String get lpPillReplay;

  /// No description provided for @lpWorldMastered.
  ///
  /// In en, this message translates to:
  /// **'You mastered the whole world!'**
  String get lpWorldMastered;

  /// No description provided for @lpWorldExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore every region to become a champion'**
  String get lpWorldExplore;

  /// No description provided for @lpTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Paths'**
  String get lpTitle;

  /// No description provided for @lpMapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Adventure map'**
  String get lpMapTooltip;

  /// No description provided for @lpJourney.
  ///
  /// In en, this message translates to:
  /// **'Your Learning Journey 🗺️'**
  String get lpJourney;

  /// No description provided for @lpIntro.
  ///
  /// In en, this message translates to:
  /// **'Complete each path to unlock the next one. Master all 12 categories to become a vocabulary champion!'**
  String get lpIntro;

  /// No description provided for @lpPathsCompleted.
  ///
  /// In en, this message translates to:
  /// **'{done} / {total} paths completed'**
  String lpPathsCompleted(int done, int total);

  /// No description provided for @lpTrailTooltip.
  ///
  /// In en, this message translates to:
  /// **'Adventure trail'**
  String get lpTrailTooltip;

  /// No description provided for @lpMastered.
  ///
  /// In en, this message translates to:
  /// **'Path Mastered!'**
  String get lpMastered;

  /// No description provided for @lpCompletedAll.
  ///
  /// In en, this message translates to:
  /// **'You’ve completed all steps in {path}!'**
  String lpCompletedAll(String path);

  /// No description provided for @lpVocabulary.
  ///
  /// In en, this message translates to:
  /// **'{category} vocabulary'**
  String lpVocabulary(String category);

  /// No description provided for @lpRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get lpRetry;

  /// No description provided for @lpStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get lpStart;

  /// No description provided for @lpPrevFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete the previous step first'**
  String get lpPrevFirst;

  /// No description provided for @lpAdventureDone.
  ///
  /// In en, this message translates to:
  /// **'Adventure complete!'**
  String get lpAdventureDone;

  /// No description provided for @lpClimb.
  ///
  /// In en, this message translates to:
  /// **'Climb the trail to master every step'**
  String get lpClimb;

  /// No description provided for @lpCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{path} learning path. {done} of {total} steps completed.'**
  String lpCardSemantics(String path, int done, int total);

  /// No description provided for @lpCardLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked. Complete the previous path to unlock.'**
  String get lpCardLocked;

  /// No description provided for @lpNodeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get lpNodeCompleted;

  /// No description provided for @lpNodeCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get lpNodeCurrent;

  /// No description provided for @lpNodeAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get lpNodeAvailable;

  /// No description provided for @lpNodeLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lpNodeLocked;

  /// No description provided for @srEnglishWord.
  ///
  /// In en, this message translates to:
  /// **'English word: {word}'**
  String srEnglishWord(String word);

  /// No description provided for @srFilipinoTranslation.
  ///
  /// In en, this message translates to:
  /// **'Filipino translation: {word}'**
  String srFilipinoTranslation(String word);

  /// No description provided for @srGreat.
  ///
  /// In en, this message translates to:
  /// **'Great recall! Keep it up!'**
  String get srGreat;

  /// No description provided for @srKeepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep practicing — you’ll get there!'**
  String get srKeepPracticing;

  /// No description provided for @hwPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get hwPractice;

  /// No description provided for @hwStruggling.
  ///
  /// In en, this message translates to:
  /// **'Struggling'**
  String get hwStruggling;

  /// No description provided for @hwAttempted.
  ///
  /// In en, this message translates to:
  /// **'Attempted'**
  String get hwAttempted;

  /// No description provided for @hwEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No hard words!'**
  String get hwEmptyTitle;

  /// No description provided for @hwEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'You’re doing great! Keep playing games and words you struggle with will appear here.'**
  String get hwEmptyBody;

  /// No description provided for @hwCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{english}, {filipino}. Accuracy: {percent} percent. {correct} correct out of {total} attempts.'**
  String hwCardSemantics(
    String english,
    String filipino,
    int percent,
    int correct,
    int total,
  );

  /// No description provided for @joinClassTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a Class'**
  String get joinClassTitle;

  /// No description provided for @joinClassIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the code your teacher gave you.'**
  String get joinClassIntro;

  /// No description provided for @joinClassCode.
  ///
  /// In en, this message translates to:
  /// **'Class code'**
  String get joinClassCode;

  /// No description provided for @joinCodeLength.
  ///
  /// In en, this message translates to:
  /// **'Code must be 6 characters'**
  String get joinCodeLength;

  /// No description provided for @joinChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get joinChecking;

  /// No description provided for @joinGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Join Home Group'**
  String get joinGroupTitle;

  /// No description provided for @joinGroupIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the code your parent or guardian shared.'**
  String get joinGroupIntro;

  /// No description provided for @joinGroupCode.
  ///
  /// In en, this message translates to:
  /// **'Home-group code'**
  String get joinGroupCode;

  /// No description provided for @joinGroupTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: ask your parent to check their internet connection, or try again in a moment.'**
  String get joinGroupTip;

  /// No description provided for @scTitle.
  ///
  /// In en, this message translates to:
  /// **'Streak Calendar'**
  String get scTitle;

  /// No description provided for @scBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best Streak'**
  String get scBestStreak;

  /// No description provided for @scThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get scThisMonth;

  /// No description provided for @scTotalActive.
  ///
  /// In en, this message translates to:
  /// **'Total Active'**
  String get scTotalActive;

  /// No description provided for @scDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String scDays(int count);

  /// No description provided for @scMilestones.
  ///
  /// In en, this message translates to:
  /// **'Streak Milestones'**
  String get scMilestones;

  /// No description provided for @calDaySemantics.
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String calDaySemantics(int day);

  /// No description provided for @calStudied.
  ///
  /// In en, this message translates to:
  /// **', studied'**
  String get calStudied;

  /// No description provided for @calToday.
  ///
  /// In en, this message translates to:
  /// **', today'**
  String get calToday;

  /// No description provided for @calM3.
  ///
  /// In en, this message translates to:
  /// **'3 Days'**
  String get calM3;

  /// No description provided for @calW1.
  ///
  /// In en, this message translates to:
  /// **'1 Week'**
  String get calW1;

  /// No description provided for @calW2.
  ///
  /// In en, this message translates to:
  /// **'2 Weeks'**
  String get calW2;

  /// No description provided for @calMo1.
  ///
  /// In en, this message translates to:
  /// **'1 Month'**
  String get calMo1;

  /// No description provided for @calMo2.
  ///
  /// In en, this message translates to:
  /// **'2 Months'**
  String get calMo2;

  /// No description provided for @calD100.
  ///
  /// In en, this message translates to:
  /// **'100 Days'**
  String get calD100;

  /// No description provided for @calMilestoneAchieved.
  ///
  /// In en, this message translates to:
  /// **'{label} streak milestone, achieved'**
  String calMilestoneAchieved(String label);

  /// No description provided for @calMilestoneNotYet.
  ///
  /// In en, this message translates to:
  /// **'{label} streak milestone, not yet achieved'**
  String calMilestoneNotYet(String label);

  /// No description provided for @sdToMilestone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day to {milestone}-day milestone} other{{count} days to {milestone}-day milestone}}'**
  String sdToMilestone(int count, int milestone);

  /// No description provided for @sdBest.
  ///
  /// In en, this message translates to:
  /// **'Best: {days} days'**
  String sdBest(int days);

  /// No description provided for @sdTierStarting.
  ///
  /// In en, this message translates to:
  /// **'Just Starting'**
  String get sdTierStarting;

  /// No description provided for @sdTierBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building Up'**
  String get sdTierBuilding;

  /// No description provided for @sdTierFire.
  ///
  /// In en, this message translates to:
  /// **'On Fire!'**
  String get sdTierFire;

  /// No description provided for @sdTierBlazing.
  ///
  /// In en, this message translates to:
  /// **'Blazing'**
  String get sdTierBlazing;

  /// No description provided for @sdTierChampion.
  ///
  /// In en, this message translates to:
  /// **'Streak Champion'**
  String get sdTierChampion;

  /// No description provided for @certCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} Mastery'**
  String certCategoryTitle(String category);

  /// No description provided for @certWordsLearned.
  ///
  /// In en, this message translates to:
  /// **'{learned}/{total} words learned'**
  String certWordsLearned(int learned, int total);

  /// No description provided for @certStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'{days}-Day Streak'**
  String certStreakTitle(int days);

  /// No description provided for @certStreakSub.
  ///
  /// In en, this message translates to:
  /// **'Consistent study dedication'**
  String get certStreakSub;

  /// No description provided for @certExcellence.
  ///
  /// In en, this message translates to:
  /// **'Learning Excellence'**
  String get certExcellence;

  /// No description provided for @certWordsStars.
  ///
  /// In en, this message translates to:
  /// **'{words} words, {stars} stars'**
  String certWordsStars(int words, int stars);

  /// No description provided for @certTitle.
  ///
  /// In en, this message translates to:
  /// **'My Certificates'**
  String get certTitle;

  /// No description provided for @certEmpty.
  ///
  /// In en, this message translates to:
  /// **'No certificates yet'**
  String get certEmpty;

  /// No description provided for @certEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Keep learning to earn certificates!\nMaster a category (80%+), build a 7-day streak,\nor learn 50+ words.'**
  String get certEmptyHint;

  /// No description provided for @certSemantics.
  ///
  /// In en, this message translates to:
  /// **'Certificate: {title}. {subtitle}. Tap to preview and share.'**
  String certSemantics(String title, String subtitle);

  /// No description provided for @certFileName.
  ///
  /// In en, this message translates to:
  /// **'Certificate - {title}'**
  String certFileName(String title);

  /// No description provided for @certFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate certificate: {error}'**
  String certFailed(String error);

  /// No description provided for @huntMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String huntMore(int count);

  /// No description provided for @goalsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Goals'**
  String get goalsTitle;

  /// No description provided for @goalsActive.
  ///
  /// In en, this message translates to:
  /// **'Active Goals'**
  String get goalsActive;

  /// No description provided for @goalsNone.
  ///
  /// In en, this message translates to:
  /// **'No goals yet'**
  String get goalsNone;

  /// No description provided for @goalsNoneHint.
  ///
  /// In en, this message translates to:
  /// **'Set a learning goal to stay motivated!'**
  String get goalsNoneHint;

  /// No description provided for @goalsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String goalsCompleted(int count);

  /// No description provided for @goalsExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired ({count})'**
  String goalsExpired(int count);

  /// No description provided for @goalsNew.
  ///
  /// In en, this message translates to:
  /// **'New Goal'**
  String get goalsNew;

  /// No description provided for @goalsTracker.
  ///
  /// In en, this message translates to:
  /// **'Goal Tracker'**
  String get goalsTracker;

  /// No description provided for @goalsSummary.
  ///
  /// In en, this message translates to:
  /// **'{active} active · {completed} completed'**
  String goalsSummary(int active, int completed);

  /// No description provided for @goalsTypeWords.
  ///
  /// In en, this message translates to:
  /// **'Words Learned'**
  String get goalsTypeWords;

  /// No description provided for @goalsTypeGames.
  ///
  /// In en, this message translates to:
  /// **'Games Completed'**
  String get goalsTypeGames;

  /// No description provided for @goalsTypeMastery.
  ///
  /// In en, this message translates to:
  /// **'Category Mastery'**
  String get goalsTypeMastery;

  /// No description provided for @goalsTypeStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak Days'**
  String get goalsTypeStreak;

  /// No description provided for @goalsTypeStars.
  ///
  /// In en, this message translates to:
  /// **'Stars Earned'**
  String get goalsTypeStars;

  /// No description provided for @goalsExpiredShort.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get goalsExpiredShort;

  /// No description provided for @goalsDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get goalsDueToday;

  /// No description provided for @goalsDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get goalsDueTomorrow;

  /// No description provided for @goalsDueIn.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String goalsDueIn(int days);

  /// No description provided for @goalsACategory.
  ///
  /// In en, this message translates to:
  /// **'a category'**
  String get goalsACategory;

  /// No description provided for @goalsLearnN.
  ///
  /// In en, this message translates to:
  /// **'Learn {n} words'**
  String goalsLearnN(int n);

  /// No description provided for @goalsCompleteN.
  ///
  /// In en, this message translates to:
  /// **'Complete {n} games'**
  String goalsCompleteN(int n);

  /// No description provided for @goalsMasteryN.
  ///
  /// In en, this message translates to:
  /// **'Reach {n}% mastery in {category}'**
  String goalsMasteryN(int n, String category);

  /// No description provided for @goalsStreakN.
  ///
  /// In en, this message translates to:
  /// **'Maintain a {n}-day streak'**
  String goalsStreakN(int n);

  /// No description provided for @goalsStarsN.
  ///
  /// In en, this message translates to:
  /// **'Earn {n} stars'**
  String goalsStarsN(int n);

  /// No description provided for @goalsSetNew.
  ///
  /// In en, this message translates to:
  /// **'Set a New Goal'**
  String get goalsSetNew;

  /// No description provided for @goalsWhat.
  ///
  /// In en, this message translates to:
  /// **'What do you want to achieve?'**
  String get goalsWhat;

  /// No description provided for @goalsWhichCategory.
  ///
  /// In en, this message translates to:
  /// **'Which category?'**
  String get goalsWhichCategory;

  /// No description provided for @goalsTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get goalsTarget;

  /// No description provided for @goalsDeadline.
  ///
  /// In en, this message translates to:
  /// **'Set a deadline'**
  String get goalsDeadline;

  /// No description provided for @goalsDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String goalsDaysShort(int days);

  /// No description provided for @goalsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Goal'**
  String get goalsCreate;

  /// No description provided for @lgNoProfile.
  ///
  /// In en, this message translates to:
  /// **'No Profile Selected'**
  String get lgNoProfile;

  /// No description provided for @lgNoProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Select a profile to view learning gain data.'**
  String get lgNoProfileBody;

  /// No description provided for @lgGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get lgGoBack;

  /// No description provided for @lgEducatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning gains belong to your learners'**
  String get lgEducatorTitle;

  /// No description provided for @lgEducatorBody.
  ///
  /// In en, this message translates to:
  /// **'You assign the pre-test and post-test; the gain is theirs. Open Assessment Tracking to see who has sat which half.'**
  String get lgEducatorBody;

  /// No description provided for @lgOpenTracking.
  ///
  /// In en, this message translates to:
  /// **'Open tracking'**
  String get lgOpenTracking;

  /// No description provided for @lgTakeTest.
  ///
  /// In en, this message translates to:
  /// **'Take Test'**
  String get lgTakeTest;

  /// No description provided for @lgNoData.
  ///
  /// In en, this message translates to:
  /// **'No Learning Data Yet'**
  String get lgNoData;

  /// No description provided for @lgNoDataBody.
  ///
  /// In en, this message translates to:
  /// **'Take a Pre-Test first to establish your baseline, then take a Post-Test after learning to see your improvement!'**
  String get lgNoDataBody;

  /// No description provided for @lgTakePre.
  ///
  /// In en, this message translates to:
  /// **'Take Pre-Test'**
  String get lgTakePre;

  /// No description provided for @lgReadyPost.
  ///
  /// In en, this message translates to:
  /// **'Ready for your Post-Test?'**
  String get lgReadyPost;

  /// No description provided for @lgReadyPostBody.
  ///
  /// In en, this message translates to:
  /// **'You’ve completed your Pre-Test! Take the Post-Test to see how much you’ve learned.'**
  String get lgReadyPostBody;

  /// No description provided for @lgTakePost.
  ///
  /// In en, this message translates to:
  /// **'Take Post-Test'**
  String get lgTakePost;

  /// No description provided for @lgAverageScores.
  ///
  /// In en, this message translates to:
  /// **'Average Scores'**
  String get lgAverageScores;

  /// No description provided for @lgRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent Assessments'**
  String get lgRecent;

  /// No description provided for @lgTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String lgTotal(int count);

  /// No description provided for @lgFocusOn.
  ///
  /// In en, this message translates to:
  /// **'Focus on {category}'**
  String lgFocusOn(String category);

  /// No description provided for @lgFocusBody.
  ///
  /// In en, this message translates to:
  /// **'Your weakest category at {percent}%. Try reviewing flashcards and playing games in this category.'**
  String lgFocusBody(int percent);

  /// No description provided for @lgPracticeMore.
  ///
  /// In en, this message translates to:
  /// **'Practice More'**
  String get lgPracticeMore;

  /// No description provided for @lgPracticeMoreBody.
  ///
  /// In en, this message translates to:
  /// **'Try reviewing flashcards and playing games before retaking the post-test.'**
  String get lgPracticeMoreBody;

  /// No description provided for @lgExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent Performance!'**
  String get lgExcellent;

  /// No description provided for @lgExcellentBody.
  ///
  /// In en, this message translates to:
  /// **'You’re doing amazing! Try harder difficulty levels to keep challenging yourself.'**
  String get lgExcellentBody;

  /// No description provided for @lgBestAt.
  ///
  /// In en, this message translates to:
  /// **'Best at {category}'**
  String lgBestAt(String category);

  /// No description provided for @lgBestBody.
  ///
  /// In en, this message translates to:
  /// **'Your strongest category at {percent}%! Great job!'**
  String lgBestBody(int percent);

  /// No description provided for @lgMostImproved.
  ///
  /// In en, this message translates to:
  /// **'Most Improved: {category}'**
  String lgMostImproved(String category);

  /// No description provided for @lgImprovedBy.
  ///
  /// In en, this message translates to:
  /// **'Improved by {percent}% — keep it up!'**
  String lgImprovedBy(int percent);

  /// No description provided for @lgRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get lgRecommendations;

  /// No description provided for @lgNoCategoryData.
  ///
  /// In en, this message translates to:
  /// **'No category data available'**
  String get lgNoCategoryData;

  /// No description provided for @lgScoreByCategory.
  ///
  /// In en, this message translates to:
  /// **'Score by Category'**
  String get lgScoreByCategory;

  /// No description provided for @lgPreShort.
  ///
  /// In en, this message translates to:
  /// **'Pre'**
  String get lgPreShort;

  /// No description provided for @lgPostShort.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get lgPostShort;

  /// No description provided for @lgGreatImprovement.
  ///
  /// In en, this message translates to:
  /// **'Great Improvement!'**
  String get lgGreatImprovement;

  /// No description provided for @lgKeepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep Practicing!'**
  String get lgKeepPracticing;

  /// No description provided for @lgCategoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get lgCategoryBreakdown;

  /// No description provided for @lgTrend.
  ///
  /// In en, this message translates to:
  /// **'Score Trend Over Time'**
  String get lgTrend;

  /// No description provided for @lgPreTests.
  ///
  /// In en, this message translates to:
  /// **'Pre-Tests'**
  String get lgPreTests;

  /// No description provided for @lgPostTests.
  ///
  /// In en, this message translates to:
  /// **'Post-Tests'**
  String get lgPostTests;

  /// No description provided for @scPortfolio.
  ///
  /// In en, this message translates to:
  /// **'My Portfolio'**
  String get scPortfolio;

  /// No description provided for @scSharePortfolio.
  ///
  /// In en, this message translates to:
  /// **'Share Portfolio'**
  String get scSharePortfolio;

  /// No description provided for @scAutoCurate.
  ///
  /// In en, this message translates to:
  /// **'Auto-curate portfolio'**
  String get scAutoCurate;

  /// No description provided for @scItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String scItems(int count);

  /// No description provided for @scAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get scAddNote;

  /// No description provided for @scAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 new item to your portfolio!} other{Added {count} new items to your portfolio!}}'**
  String scAdded(int count);

  /// No description provided for @scUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Portfolio is already up to date!'**
  String get scUpToDate;

  /// No description provided for @scRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from Portfolio?'**
  String get scRemoveTitle;

  /// No description provided for @scRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'Remove “{title}” from your showcase? You can always add it back later.'**
  String scRemoveBody(String title);

  /// No description provided for @scAddANote.
  ///
  /// In en, this message translates to:
  /// **'Add a Note'**
  String get scAddANote;

  /// No description provided for @scNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get scNoteTitle;

  /// No description provided for @scNoteTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., “My Favorite Game”'**
  String get scNoteTitleHint;

  /// No description provided for @scNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get scNote;

  /// No description provided for @scNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Write about your learning journey...'**
  String get scNoteHint;

  /// No description provided for @scAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get scAdd;

  /// No description provided for @scTypeAchievement.
  ///
  /// In en, this message translates to:
  /// **'Achievement'**
  String get scTypeAchievement;

  /// No description provided for @scTypeHighScore.
  ///
  /// In en, this message translates to:
  /// **'High Score'**
  String get scTypeHighScore;

  /// No description provided for @scTypeMastery.
  ///
  /// In en, this message translates to:
  /// **'Category Mastery'**
  String get scTypeMastery;

  /// No description provided for @scTypePath.
  ///
  /// In en, this message translates to:
  /// **'Learning Path'**
  String get scTypePath;

  /// No description provided for @scTypeStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak Milestone'**
  String get scTypeStreak;

  /// No description provided for @scTypeAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get scTypeAssessment;

  /// No description provided for @scTypeNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get scTypeNote;

  /// No description provided for @scPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned.'**
  String get scPinned;

  /// No description provided for @scUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get scUnpin;

  /// No description provided for @scPinTop.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get scPinTop;

  /// No description provided for @scRemoveFrom.
  ///
  /// In en, this message translates to:
  /// **'Remove from showcase'**
  String get scRemoveFrom;

  /// No description provided for @scShowcaseBest.
  ///
  /// In en, this message translates to:
  /// **'Showcase your best moments!'**
  String get scShowcaseBest;

  /// No description provided for @scStatItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get scStatItems;

  /// No description provided for @scStatPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get scStatPinned;

  /// No description provided for @scStatAwards.
  ///
  /// In en, this message translates to:
  /// **'Awards'**
  String get scStatAwards;

  /// No description provided for @scEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Portfolio is Empty'**
  String get scEmptyTitle;

  /// No description provided for @scEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Start by auto-curating your best moments or add items manually as you learn!'**
  String get scEmptyBody;

  /// No description provided for @scEmptyAction.
  ///
  /// In en, this message translates to:
  /// **'Auto-Curate My Portfolio'**
  String get scEmptyAction;

  /// No description provided for @scPdfTitle.
  ///
  /// In en, this message translates to:
  /// **'Portfolio Summary PDF'**
  String get scPdfTitle;

  /// No description provided for @scItemsFor.
  ///
  /// In en, this message translates to:
  /// **'{count} items • {name}'**
  String scItemsFor(int count, String name);

  /// No description provided for @scShareHint.
  ///
  /// In en, this message translates to:
  /// **'Share with your teacher or parent to show your progress!'**
  String get scShareHint;

  /// No description provided for @wodLearned.
  ///
  /// In en, this message translates to:
  /// **'Word learned! {emoji}'**
  String wodLearned(String emoji);

  /// No description provided for @tbPrev.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get tbPrev;

  /// No description provided for @tbSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak'**
  String get tbSpeak;

  /// No description provided for @tbAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tbAdd;

  /// No description provided for @tbTooLong.
  ///
  /// In en, this message translates to:
  /// **'That is as long as a sentence can be. Speak it or clear it.'**
  String get tbTooLong;

  /// No description provided for @tbUnpinned.
  ///
  /// In en, this message translates to:
  /// **'Phrase unpinned.'**
  String get tbUnpinned;

  /// No description provided for @tbSaved.
  ///
  /// In en, this message translates to:
  /// **'Phrase saved.'**
  String get tbSaved;

  /// No description provided for @tbChangeReason.
  ///
  /// In en, this message translates to:
  /// **'to change this board'**
  String get tbChangeReason;

  /// No description provided for @tbTitle.
  ///
  /// In en, this message translates to:
  /// **'Talk Board'**
  String get tbTitle;

  /// No description provided for @tbEditBoard.
  ///
  /// In en, this message translates to:
  /// **'Edit my board'**
  String get tbEditBoard;

  /// No description provided for @tbBuildBoard.
  ///
  /// In en, this message translates to:
  /// **'Build my board'**
  String get tbBuildBoard;

  /// No description provided for @tbToEnglish.
  ///
  /// In en, this message translates to:
  /// **'Switch to English'**
  String get tbToEnglish;

  /// No description provided for @tbToFilipino.
  ///
  /// In en, this message translates to:
  /// **'Switch to Filipino'**
  String get tbToFilipino;

  /// No description provided for @tbSavedPhrase.
  ///
  /// In en, this message translates to:
  /// **'Saved phrase: {phrase}. Tap to say it.'**
  String tbSavedPhrase(String phrase);

  /// No description provided for @tbRecentPhrase.
  ///
  /// In en, this message translates to:
  /// **'Recent phrase: {phrase}. Tap to say it.'**
  String tbRecentPhrase(String phrase);

  /// No description provided for @tbHint.
  ///
  /// In en, this message translates to:
  /// **'Tap tiles below to build a sentence'**
  String get tbHint;

  /// No description provided for @tbSpeakSentence.
  ///
  /// In en, this message translates to:
  /// **'Speak sentence'**
  String get tbSpeakSentence;

  /// No description provided for @tbUnsave.
  ///
  /// In en, this message translates to:
  /// **'Remove this sentence from saved phrases'**
  String get tbUnsave;

  /// No description provided for @tbSave.
  ///
  /// In en, this message translates to:
  /// **'Save this sentence'**
  String get tbSave;

  /// No description provided for @tbRemoveLast.
  ///
  /// In en, this message translates to:
  /// **'Remove last tile'**
  String get tbRemoveLast;

  /// No description provided for @tbClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all tiles'**
  String get tbClearAll;

  /// No description provided for @tbCategory.
  ///
  /// In en, this message translates to:
  /// **'{label} category'**
  String tbCategory(String label);

  /// No description provided for @tbTileSemantics.
  ///
  /// In en, this message translates to:
  /// **'{spoken}. Tap to add, long press to hear.'**
  String tbTileSemantics(String spoken);

  /// No description provided for @agTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait {time}.'**
  String agTooMany(String time);

  /// No description provided for @agEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the 4-digit PIN.'**
  String get agEnterPin;

  /// No description provided for @agPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'That PIN did not match. Ask your parent or teacher.'**
  String get agPinMismatch;

  /// No description provided for @agNewQuestion.
  ///
  /// In en, this message translates to:
  /// **'Not quite. Here is a new question.'**
  String get agNewQuestion;

  /// No description provided for @agMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String agMinutes(int n);

  /// No description provided for @agSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String agSeconds(int n);

  /// No description provided for @agTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask an adult'**
  String get agTitle;

  /// No description provided for @agPinNeeded.
  ///
  /// In en, this message translates to:
  /// **'A parent or teacher PIN is needed {reason}.'**
  String agPinNeeded(String reason);

  /// No description provided for @agAnswerThis.
  ///
  /// In en, this message translates to:
  /// **'Answer this {reason}.'**
  String agAnswerThis(String reason);

  /// No description provided for @agTimes.
  ///
  /// In en, this message translates to:
  /// **'What is {a} times {b}?'**
  String agTimes(int a, int b);

  /// No description provided for @agAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get agAnswer;

  /// No description provided for @agEndEarly.
  ///
  /// In en, this message translates to:
  /// **'to end {title} early'**
  String agEndEarly(String title);

  /// No description provided for @lbTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get lbTitle;

  /// No description provided for @lbNoRankings.
  ///
  /// In en, this message translates to:
  /// **'No rankings yet'**
  String get lbNoRankings;

  /// No description provided for @lbNoRankingsBody.
  ///
  /// In en, this message translates to:
  /// **'Complete activities and games to appear on the leaderboard!'**
  String get lbNoRankingsBody;

  /// No description provided for @lbHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden from members — enable in Leaderboard settings'**
  String get lbHidden;

  /// No description provided for @lbSeason.
  ///
  /// In en, this message translates to:
  /// **'Season active — ranking recent activity'**
  String get lbSeason;

  /// No description provided for @lbJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join to see the leaderboard'**
  String get lbJoinTitle;

  /// No description provided for @lbJoinChild.
  ///
  /// In en, this message translates to:
  /// **'Join your family home group to see how you rank with everyone!'**
  String get lbJoinChild;

  /// No description provided for @lbJoinStudent.
  ///
  /// In en, this message translates to:
  /// **'Join your class to see how you rank with your classmates!'**
  String get lbJoinStudent;

  /// No description provided for @lbJoinGroup.
  ///
  /// In en, this message translates to:
  /// **'Join a Home Group'**
  String get lbJoinGroup;

  /// No description provided for @lbNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard not enabled yet'**
  String get lbNotEnabled;

  /// No description provided for @lbNotEnabledBody.
  ///
  /// In en, this message translates to:
  /// **'Your teacher or parent hasn’t turned on the leaderboard for your group yet. Check back soon!'**
  String get lbNotEnabledBody;

  /// No description provided for @lbNoClasses.
  ///
  /// In en, this message translates to:
  /// **'No classes yet'**
  String get lbNoClasses;

  /// No description provided for @lbNoGroups.
  ///
  /// In en, this message translates to:
  /// **'No home groups yet'**
  String get lbNoGroups;

  /// No description provided for @lbNoClassesBody.
  ///
  /// In en, this message translates to:
  /// **'Create a class and invite students to start a leaderboard.'**
  String get lbNoClassesBody;

  /// No description provided for @lbNoGroupsBody.
  ///
  /// In en, this message translates to:
  /// **'Create a home group and invite your children to start a leaderboard.'**
  String get lbNoGroupsBody;

  /// No description provided for @lbManageClasses.
  ///
  /// In en, this message translates to:
  /// **'Manage Classes'**
  String get lbManageClasses;

  /// No description provided for @lbManageGroups.
  ///
  /// In en, this message translates to:
  /// **'Manage Home Groups'**
  String get lbManageGroups;

  /// No description provided for @lbError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load the leaderboard'**
  String get lbError;

  /// No description provided for @lbErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. Your last-known rankings show when you’re back online.'**
  String get lbErrorBody;

  /// No description provided for @lbSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get lbSort;

  /// No description provided for @lbPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get lbPeriod;

  /// No description provided for @lbYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get lbYou;

  /// No description provided for @lbSortStars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get lbSortStars;

  /// No description provided for @lbSortWords.
  ///
  /// In en, this message translates to:
  /// **'Words Learned'**
  String get lbSortWords;

  /// No description provided for @lbSortStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get lbSortStreak;

  /// No description provided for @lbSortOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get lbSortOverall;

  /// No description provided for @lbAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get lbAllTime;

  /// No description provided for @lbThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get lbThisWeek;

  /// No description provided for @lbThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get lbThisMonth;

  /// No description provided for @lbWords.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String lbWords(int count);

  /// No description provided for @lbDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String lbDays(int count);

  /// No description provided for @lbPts.
  ///
  /// In en, this message translates to:
  /// **'{count} pts'**
  String lbPts(int count);

  /// No description provided for @setProfileSemantics.
  ///
  /// In en, this message translates to:
  /// **'Profile: {name}, {role}. Tap switch to change profile.'**
  String setProfileSemantics(String name, String role);

  /// No description provided for @setNoProfile.
  ///
  /// In en, this message translates to:
  /// **'No profile'**
  String get setNoProfile;

  /// No description provided for @setUnknownRole.
  ///
  /// In en, this message translates to:
  /// **'unknown role'**
  String get setUnknownRole;

  /// No description provided for @dbExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export data as CSV spreadsheet'**
  String get dbExportCsv;

  /// No description provided for @dbExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export progress report as PDF'**
  String get dbExportPdf;

  /// No description provided for @dbExportResearch.
  ///
  /// In en, this message translates to:
  /// **'Export research data for thesis analysis'**
  String get dbExportResearch;

  /// No description provided for @dbBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get dbBadges;

  /// No description provided for @dbOverallMastery.
  ///
  /// In en, this message translates to:
  /// **'Overall Mastery'**
  String get dbOverallMastery;

  /// No description provided for @dbCategoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get dbCategoryBreakdown;

  /// No description provided for @dbInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights & Recommendations'**
  String get dbInsights;

  /// No description provided for @dbNoData.
  ///
  /// In en, this message translates to:
  /// **'No learning data yet. Once the student starts playing games and reviewing flashcards, insights will appear here.'**
  String get dbNoData;

  /// No description provided for @dbNeedsPractice.
  ///
  /// In en, this message translates to:
  /// **'Needs Practice'**
  String get dbNeedsPractice;

  /// No description provided for @dbFocusOn.
  ///
  /// In en, this message translates to:
  /// **'Focus on {category} flashcards and games.'**
  String dbFocusOn(String category);

  /// No description provided for @dbDoingGreat.
  ///
  /// In en, this message translates to:
  /// **'Doing Great'**
  String get dbDoingGreat;

  /// No description provided for @dbKeepItUp.
  ///
  /// In en, this message translates to:
  /// **'Keep it up! Consider trying harder difficulty levels.'**
  String get dbKeepItUp;

  /// No description provided for @dbEngagement.
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get dbEngagement;

  /// No description provided for @dbStreakActive.
  ///
  /// In en, this message translates to:
  /// **'{streak}-day learning streak active!'**
  String dbStreakActive(int streak);

  /// No description provided for @dbNoStreak.
  ///
  /// In en, this message translates to:
  /// **'No active streak. Try daily practice.'**
  String get dbNoStreak;

  /// No description provided for @dbConsistent.
  ///
  /// In en, this message translates to:
  /// **'Great consistency! The student is building a habit.'**
  String get dbConsistent;

  /// No description provided for @dbEncourage.
  ///
  /// In en, this message translates to:
  /// **'Encourage the student to play at least once a day.'**
  String get dbEncourage;

  /// No description provided for @dbStudyTime.
  ///
  /// In en, this message translates to:
  /// **'Study Time'**
  String get dbStudyTime;

  /// No description provided for @dbRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dbRecentActivity;

  /// No description provided for @dbNoGames.
  ///
  /// In en, this message translates to:
  /// **'No game activity yet. Encourage the student to play games!'**
  String get dbNoGames;

  /// No description provided for @dbStudentProgress.
  ///
  /// In en, this message translates to:
  /// **'Student Progress'**
  String get dbStudentProgress;

  /// No description provided for @dbMastery.
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get dbMastery;

  /// No description provided for @dbRecentAvg.
  ///
  /// In en, this message translates to:
  /// **'Recent Game Avg'**
  String get dbRecentAvg;

  /// No description provided for @dbDailyStreak.
  ///
  /// In en, this message translates to:
  /// **'Daily Challenge Streak'**
  String get dbDailyStreak;

  /// No description provided for @dbDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String dbDays(int count);

  /// No description provided for @dbTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get dbTotalTime;

  /// No description provided for @dbAvgSession.
  ///
  /// In en, this message translates to:
  /// **'Avg Session'**
  String get dbAvgSession;

  /// No description provided for @dbSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get dbSessions;

  /// No description provided for @dbLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get dbLast7Days;

  /// No description provided for @sfSearch.
  ///
  /// In en, this message translates to:
  /// **'Search students...'**
  String get sfSearch;

  /// No description provided for @sfGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get sfGrade;

  /// No description provided for @sfSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get sfSection;

  /// No description provided for @sfResults.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String sfResults(int count);

  /// No description provided for @sfClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get sfClearAll;

  /// No description provided for @sfTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get sfTags;

  /// No description provided for @sfTagsN.
  ///
  /// In en, this message translates to:
  /// **'Tags ({count})'**
  String sfTagsN(int count);

  /// No description provided for @sfKinder.
  ///
  /// In en, this message translates to:
  /// **'Kinder'**
  String get sfKinder;

  /// No description provided for @sfGradeN.
  ///
  /// In en, this message translates to:
  /// **'Grade {n}'**
  String sfGradeN(int n);

  /// No description provided for @sfHighSchool.
  ///
  /// In en, this message translates to:
  /// **'High School'**
  String get sfHighSchool;

  /// No description provided for @sfCollege.
  ///
  /// In en, this message translates to:
  /// **'College'**
  String get sfCollege;

  /// No description provided for @sfActAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get sfActAll;

  /// No description provided for @sfActToday.
  ///
  /// In en, this message translates to:
  /// **'Active Today'**
  String get sfActToday;

  /// No description provided for @sfActWeek.
  ///
  /// In en, this message translates to:
  /// **'Active This Week'**
  String get sfActWeek;

  /// No description provided for @sfActInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive 7+ Days'**
  String get sfActInactive;

  /// No description provided for @sfSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sfSortName;

  /// No description provided for @sfSortGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade Level'**
  String get sfSortGrade;

  /// No description provided for @sfSortWords.
  ///
  /// In en, this message translates to:
  /// **'Words Learned'**
  String get sfSortWords;

  /// No description provided for @sfSortStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get sfSortStreak;

  /// No description provided for @sfSortStars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get sfSortStars;

  /// No description provided for @sfSortLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last Active'**
  String get sfSortLastActive;

  /// No description provided for @sfSortAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get sfSortAccuracy;

  /// No description provided for @sfSortJoined.
  ///
  /// In en, this message translates to:
  /// **'Date Joined'**
  String get sfSortJoined;

  /// No description provided for @msClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get msClearFilters;

  /// No description provided for @msCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {words} words learned, {stars} stars, {streak} day streak'**
  String msCardSemantics(String name, int words, int stars, int streak);

  /// No description provided for @cdExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV report'**
  String get cdExportCsv;

  /// No description provided for @cdRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get cdRefresh;

  /// No description provided for @cdLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load dashboard:\n{error}'**
  String cdLoadError(String error);

  /// No description provided for @cdLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {time}'**
  String cdLastUpdated(String time);

  /// No description provided for @cdNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No student profiles found'**
  String get cdNoStudents;

  /// No description provided for @cdNoStudentsBody.
  ///
  /// In en, this message translates to:
  /// **'Create student profiles to see them here.\nEach student will appear with their progress.'**
  String get cdNoStudentsBody;

  /// No description provided for @splDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile?'**
  String get splDeleteTitle;

  /// No description provided for @splDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete “{name}”? This will permanently remove all progress data for this student.'**
  String splDeleteBody(String name);

  /// No description provided for @splDeleteEducator.
  ///
  /// In en, this message translates to:
  /// **' Any classes they own will no longer have a teacher managing them.'**
  String get splDeleteEducator;

  /// No description provided for @splDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String splDeleted(String name);

  /// No description provided for @splManageProfiles.
  ///
  /// In en, this message translates to:
  /// **'Manage Profiles'**
  String get splManageProfiles;

  /// No description provided for @splStudentProfiles.
  ///
  /// In en, this message translates to:
  /// **'Student Profiles'**
  String get splStudentProfiles;

  /// No description provided for @splImportExport.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get splImportExport;

  /// No description provided for @splLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load students:\n{error}'**
  String splLoadError(String error);

  /// No description provided for @splNoOthers.
  ///
  /// In en, this message translates to:
  /// **'No other profiles on this device'**
  String get splNoOthers;

  /// No description provided for @splNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No student profiles yet'**
  String get splNoStudents;

  /// No description provided for @splNoStudentsBody.
  ///
  /// In en, this message translates to:
  /// **'Students appear here after joining your class with a code.'**
  String get splNoStudentsBody;

  /// No description provided for @splShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share Class Code'**
  String get splShareCode;

  /// No description provided for @splAge.
  ///
  /// In en, this message translates to:
  /// **'{age} yrs old'**
  String splAge(int age);

  /// No description provided for @splNoAge.
  ///
  /// In en, this message translates to:
  /// **'No age or level set'**
  String get splNoAge;

  /// No description provided for @storyLocked.
  ///
  /// In en, this message translates to:
  /// **'{title} — locked'**
  String storyLocked(String title);

  /// No description provided for @storyTapToRead.
  ///
  /// In en, this message translates to:
  /// **'{title} — tap to read'**
  String storyTapToRead(String title);

  /// No description provided for @storyReadSuffix.
  ///
  /// In en, this message translates to:
  /// **', read'**
  String get storyReadSuffix;

  /// No description provided for @storyRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get storyRead;

  /// No description provided for @fiPictureClue.
  ///
  /// In en, this message translates to:
  /// **'Picture clue'**
  String get fiPictureClue;

  /// No description provided for @fiTapCartoon.
  ///
  /// In en, this message translates to:
  /// **'Tap to see the cartoon picture.'**
  String get fiTapCartoon;

  /// No description provided for @fiTapReal.
  ///
  /// In en, this message translates to:
  /// **'Tap to see the real picture.'**
  String get fiTapReal;

  /// No description provided for @fiRealOf.
  ///
  /// In en, this message translates to:
  /// **'Real picture of {word}.'**
  String fiRealOf(String word);

  /// No description provided for @fiRealLifeOf.
  ///
  /// In en, this message translates to:
  /// **'Real-life picture of {word}'**
  String fiRealLifeOf(String word);

  /// No description provided for @fiCartoonOf.
  ///
  /// In en, this message translates to:
  /// **'Cartoon picture of {word}'**
  String fiCartoonOf(String word);

  /// No description provided for @mascotBuddy.
  ///
  /// In en, this message translates to:
  /// **'Mascot buddy'**
  String get mascotBuddy;

  /// No description provided for @profileAgeYrs.
  ///
  /// In en, this message translates to:
  /// **'{age} yrs'**
  String profileAgeYrs(int age);

  /// No description provided for @scpScored.
  ///
  /// In en, this message translates to:
  /// **'Scored {score}/{total} and earned {stars} stars!'**
  String scpScored(int score, int total, int stars);

  /// No description provided for @scpMastered.
  ///
  /// In en, this message translates to:
  /// **'{category} Mastered!'**
  String scpMastered(String category);

  /// No description provided for @scpMasteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Achieved {percent}% mastery in {category}'**
  String scpMasteryDesc(int percent, String category);

  /// No description provided for @scpStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'{days}-Day Streak!'**
  String scpStreakTitle(int days);

  /// No description provided for @scpStreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Maintained a learning streak of {days} days in a row!'**
  String scpStreakDesc(int days);

  /// No description provided for @scpAssessDesc.
  ///
  /// In en, this message translates to:
  /// **'Scored {score}/{total} on {test}'**
  String scpAssessDesc(int score, int total, String test);

  /// No description provided for @lvlBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get lvlBeginner;

  /// No description provided for @lvlElementary.
  ///
  /// In en, this message translates to:
  /// **'Elementary'**
  String get lvlElementary;

  /// No description provided for @lvlIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get lvlIntermediate;

  /// No description provided for @lvlAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get lvlAdvanced;

  /// No description provided for @lvlBeginnerDesc.
  ///
  /// In en, this message translates to:
  /// **'Just starting out — simple words and short sessions.'**
  String get lvlBeginnerDesc;

  /// No description provided for @lvlElementaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Building vocabulary — slightly longer lessons.'**
  String get lvlElementaryDesc;

  /// No description provided for @lvlIntermediateDesc.
  ///
  /// In en, this message translates to:
  /// **'Comfortable with most lessons — full-length games.'**
  String get lvlIntermediateDesc;

  /// No description provided for @lvlAdvancedDesc.
  ///
  /// In en, this message translates to:
  /// **'Ready for harder challenges and complex stories.'**
  String get lvlAdvancedDesc;

  /// No description provided for @signNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get signNotSet;

  /// No description provided for @signLearning.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get signLearning;

  /// No description provided for @signCanSign.
  ///
  /// In en, this message translates to:
  /// **'I can sign this'**
  String get signCanSign;

  /// No description provided for @signUnreviewed.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get signUnreviewed;

  /// No description provided for @signConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get signConfirmed;

  /// No description provided for @signNeedsPractice.
  ///
  /// In en, this message translates to:
  /// **'Needs practice'**
  String get signNeedsPractice;

  /// No description provided for @lockSumBanner.
  ///
  /// In en, this message translates to:
  /// **'Advance warning banner'**
  String get lockSumBanner;

  /// No description provided for @lockSumChimes.
  ///
  /// In en, this message translates to:
  /// **'Alarm chime ×{count}'**
  String lockSumChimes(int count);

  /// No description provided for @lockSumOneChime.
  ///
  /// In en, this message translates to:
  /// **'One gentle alarm chime'**
  String get lockSumOneChime;

  /// No description provided for @lockSumSpokenTwice.
  ///
  /// In en, this message translates to:
  /// **'Spoken message (said twice)'**
  String get lockSumSpokenTwice;

  /// No description provided for @lockSumSpoken.
  ///
  /// In en, this message translates to:
  /// **'Spoken message'**
  String get lockSumSpoken;

  /// No description provided for @lockSumPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture of who to hand it to'**
  String get lockSumPicture;

  /// No description provided for @lockSumFslFirst.
  ///
  /// In en, this message translates to:
  /// **'FSL video first (tap to flip to the picture)'**
  String get lockSumFslFirst;

  /// No description provided for @lockSumFslBack.
  ///
  /// In en, this message translates to:
  /// **'FSL video on the back of the picture'**
  String get lockSumFslBack;

  /// No description provided for @lockSumAlarmFirst.
  ///
  /// In en, this message translates to:
  /// **'Alarm animation first (tap to flip to the picture)'**
  String get lockSumAlarmFirst;

  /// No description provided for @lockSumAlarmBack.
  ///
  /// In en, this message translates to:
  /// **'Alarm animation on the back of the picture (tap to flip)'**
  String get lockSumAlarmBack;

  /// No description provided for @lockSumVisual.
  ///
  /// In en, this message translates to:
  /// **'Pulsing visual alert'**
  String get lockSumVisual;

  /// No description provided for @lockSumVibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration cue'**
  String get lockSumVibration;

  /// No description provided for @lockSumReader.
  ///
  /// In en, this message translates to:
  /// **'Screen-reader announcement'**
  String get lockSumReader;

  /// No description provided for @lockSumSimple.
  ///
  /// In en, this message translates to:
  /// **'Short, simple wording'**
  String get lockSumSimple;

  /// No description provided for @lockSumSwitch.
  ///
  /// In en, this message translates to:
  /// **'Large “Switch account” button'**
  String get lockSumSwitch;

  /// No description provided for @lockWhyVisual.
  ///
  /// In en, this message translates to:
  /// **'Shorter day and frequent breaks — audio-led learning takes longer per item and reduces eye strain.'**
  String get lockWhyVisual;

  /// No description provided for @lockWhyHearing.
  ///
  /// In en, this message translates to:
  /// **'Standard session length; the hand-off is delivered as an FSL video and a large caption instead of speech.'**
  String get lockWhyHearing;

  /// No description provided for @lockWhyMotor.
  ///
  /// In en, this message translates to:
  /// **'Shorter day and frequent breaks — sustained tapping and holding is tiring. All lock buttons are extra large.'**
  String get lockWhyMotor;

  /// No description provided for @lockWhyCognitive.
  ///
  /// In en, this message translates to:
  /// **'Short, predictable sessions with a fixed daily window. The lock uses one chime and one short sentence.'**
  String get lockWhyCognitive;

  /// No description provided for @lockWhyMultiple.
  ///
  /// In en, this message translates to:
  /// **'The most supportive settings of every profile combined: short sessions, simple wording, the spoken message said twice, and large buttons.'**
  String get lockWhyMultiple;

  /// No description provided for @lockWhyNone.
  ///
  /// In en, this message translates to:
  /// **'Standard session length with an alarm and a spoken hand-off message.'**
  String get lockWhyNone;

  /// No description provided for @tlTitle.
  ///
  /// In en, this message translates to:
  /// **'Time limits'**
  String get tlTitle;

  /// No description provided for @tlTitleFor.
  ///
  /// In en, this message translates to:
  /// **'Time limits — {name}'**
  String tlTitleFor(String name);

  /// No description provided for @tlSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tlSave;

  /// No description provided for @tlLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load: {error}'**
  String tlLoadError(String error);

  /// No description provided for @tlDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily time limit'**
  String get tlDaily;

  /// No description provided for @tlMinPerDay.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min per day'**
  String tlMinPerDay(int minutes);

  /// No description provided for @tlNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get tlNoLimit;

  /// No description provided for @tlMinutesPerDay.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes per day'**
  String tlMinutesPerDay(int minutes);

  /// No description provided for @tlSchedule.
  ///
  /// In en, this message translates to:
  /// **'Allowed schedule'**
  String get tlSchedule;

  /// No description provided for @tlRestrict.
  ///
  /// In en, this message translates to:
  /// **'Restrict by time of day'**
  String get tlRestrict;

  /// No description provided for @tlAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get tlAnyTime;

  /// No description provided for @tlStart.
  ///
  /// In en, this message translates to:
  /// **'Allowed start'**
  String get tlStart;

  /// No description provided for @tlEnd.
  ///
  /// In en, this message translates to:
  /// **'Allowed end'**
  String get tlEnd;

  /// No description provided for @tlWhenUp.
  ///
  /// In en, this message translates to:
  /// **'When time is up'**
  String get tlWhenUp;

  /// No description provided for @tlWhenUpBody.
  ///
  /// In en, this message translates to:
  /// **'The child hears an alarm, then a message telling them who to hand the device to.'**
  String get tlWhenUpBody;

  /// No description provided for @tlWarn.
  ///
  /// In en, this message translates to:
  /// **'Warn before the lock'**
  String get tlWarn;

  /// No description provided for @tlWarnOn.
  ///
  /// In en, this message translates to:
  /// **'A banner {minutes} minutes before, so they can finish what they are doing.'**
  String tlWarnOn(int minutes);

  /// No description provided for @tlWarnOff.
  ///
  /// In en, this message translates to:
  /// **'The lock screen will be the first warning.'**
  String get tlWarnOff;

  /// No description provided for @tlNotice.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes of notice'**
  String tlNotice(int minutes);

  /// No description provided for @tlAlarm.
  ///
  /// In en, this message translates to:
  /// **'Play an alarm sound'**
  String get tlAlarm;

  /// No description provided for @tlAlarmBody.
  ///
  /// In en, this message translates to:
  /// **'Also alerts the adult in the room, so it stays on for learners who are deaf or hard of hearing.'**
  String get tlAlarmBody;

  /// No description provided for @tlSpeak.
  ///
  /// In en, this message translates to:
  /// **'Speak the message out loud'**
  String get tlSpeak;

  /// No description provided for @tlSpeakOn.
  ///
  /// In en, this message translates to:
  /// **'Spoken after the alarm.'**
  String get tlSpeakOn;

  /// No description provided for @tlSpeakOff.
  ///
  /// In en, this message translates to:
  /// **'This learner’s profile does not use speech — the message is shown as a large caption instead.'**
  String get tlSpeakOff;

  /// No description provided for @tlLockIntro.
  ///
  /// In en, this message translates to:
  /// **'When a limit is reached, the child sees a “Time’s up” lock screen that requires your PIN to dismiss. They keep all progress, and a “Switch account” button lets someone else use the device without unlocking this profile.'**
  String get tlLockIntro;

  /// No description provided for @tlApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied the recommended settings for {profile}. Tap Save to confirm.'**
  String tlApplied(String profile);

  /// No description provided for @tlSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String tlSaveError(String error);

  /// No description provided for @tlNotCached.
  ///
  /// In en, this message translates to:
  /// **'This learner’s profile isn’t cached on this device yet, so the accessibility-specific guidance is hidden. Every setting below still applies.'**
  String get tlNotCached;

  /// No description provided for @tlAtLock.
  ///
  /// In en, this message translates to:
  /// **'At lock time this learner gets:'**
  String get tlAtLock;

  /// No description provided for @tlUseRecommended.
  ///
  /// In en, this message translates to:
  /// **'Use recommended ({minutes} min/day)'**
  String tlUseRecommended(int minutes);

  /// No description provided for @tlCallYou.
  ///
  /// In en, this message translates to:
  /// **'What should the child call you?'**
  String get tlCallYou;

  /// No description provided for @tlCallHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Teacher Ana, Dad, Lola'**
  String get tlCallHint;

  /// No description provided for @tlBlankDefault.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the default.'**
  String get tlBlankDefault;

  /// No description provided for @tlBlankAvatar.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use “{honorific}”, taken from the avatar on your profile.'**
  String tlBlankAvatar(String honorific);

  /// No description provided for @tlWillHear.
  ///
  /// In en, this message translates to:
  /// **'The child will hear'**
  String get tlWillHear;

  /// No description provided for @tlFslUrl.
  ///
  /// In en, this message translates to:
  /// **'Sign-language (FSL) video URL'**
  String get tlFslUrl;

  /// No description provided for @tlFslBlank.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the built-in FSL clip for whoever the child hands the device to (Ma’am / Sir / Mommy / Daddy). Shown on the lock screen for learners who are deaf or hard of hearing; downloaded once, then plays offline.'**
  String get tlFslBlank;

  /// No description provided for @tlFslSet.
  ///
  /// In en, this message translates to:
  /// **'Shown on the lock screen for learners who are deaf or hard of hearing. The clip is downloaded once and then plays offline.'**
  String get tlFslSet;

  /// No description provided for @tlFslUnused.
  ///
  /// In en, this message translates to:
  /// **'This learner’s profile does not show the FSL video, so this is stored but unused unless their profile changes.'**
  String get tlFslUnused;

  /// No description provided for @tlNoClip.
  ///
  /// In en, this message translates to:
  /// **'No clip set. The lock screen will show the written message only until a URL is added here.'**
  String get tlNoClip;

  /// No description provided for @tlEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Schedule applies every day'**
  String get tlEveryDay;

  /// No description provided for @tlSelectedDays.
  ///
  /// In en, this message translates to:
  /// **'Schedule applies only on selected days'**
  String get tlSelectedDays;

  /// No description provided for @tuTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {time}.'**
  String tuTooMany(String time);

  /// No description provided for @tuActiveProfile.
  ///
  /// In en, this message translates to:
  /// **'Active profile: {name}'**
  String tuActiveProfile(String name);

  /// No description provided for @tuEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter a 4-digit PIN.'**
  String get tuEnterPin;

  /// No description provided for @tuWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. Ask your parent or teacher.'**
  String get tuWrongPin;

  /// No description provided for @tuUseRecovery.
  ///
  /// In en, this message translates to:
  /// **'Use recovery code'**
  String get tuUseRecovery;

  /// No description provided for @tuRecoveryBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the recovery code printed when this profile’s PIN was set. Codes are case-insensitive.'**
  String get tuRecoveryBody;

  /// No description provided for @tuRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get tuRecoveryCode;

  /// No description provided for @tuRecoveryMismatch.
  ///
  /// In en, this message translates to:
  /// **'Recovery code did not match.'**
  String get tuRecoveryMismatch;

  /// No description provided for @tuSignVideo.
  ///
  /// In en, this message translates to:
  /// **'sign-language video'**
  String get tuSignVideo;

  /// No description provided for @tuAlarm.
  ///
  /// In en, this message translates to:
  /// **'alarm'**
  String get tuAlarm;

  /// No description provided for @tuSignVideoTap.
  ///
  /// In en, this message translates to:
  /// **'Sign-language video. Tap to see the picture.'**
  String get tuSignVideoTap;

  /// No description provided for @tuAlarmTap.
  ///
  /// In en, this message translates to:
  /// **'Alarm clock animation. Tap to see the picture.'**
  String get tuAlarmTap;

  /// No description provided for @tuTapToSeeClip.
  ///
  /// In en, this message translates to:
  /// **'{caption} Tap to see the {clip}.'**
  String tuTapToSeeClip(String caption, String clip);

  /// No description provided for @tuTapPicture.
  ///
  /// In en, this message translates to:
  /// **'Tap to see the picture'**
  String get tuTapPicture;

  /// No description provided for @tuTapClip.
  ///
  /// In en, this message translates to:
  /// **'Tap to see the {clip}'**
  String tuTapClip(String clip);

  /// No description provided for @tuFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Watch in full screen'**
  String get tuFullScreen;

  /// No description provided for @tuEnterAdultPin.
  ///
  /// In en, this message translates to:
  /// **'Enter parent / teacher PIN to continue'**
  String get tuEnterAdultPin;

  /// No description provided for @tuForgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN? Use recovery code'**
  String get tuForgotPin;

  /// No description provided for @tuSwitchNote.
  ///
  /// In en, this message translates to:
  /// **'Switching accounts does not unlock this profile — it stays locked until an adult enters the PIN.'**
  String get tuSwitchNote;

  /// No description provided for @tuNoAdult.
  ///
  /// In en, this message translates to:
  /// **'No parent or teacher is linked to this device yet, so the lock cannot be dismissed here. Ask the device owner to sign in once.'**
  String get tuNoAdult;

  /// No description provided for @alNew.
  ///
  /// In en, this message translates to:
  /// **'New alarm'**
  String get alNew;

  /// No description provided for @alLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load: {error}'**
  String alLoadError(String error);

  /// No description provided for @alNone.
  ///
  /// In en, this message translates to:
  /// **'No alarms set yet.\nTap “New alarm” to create one.'**
  String get alNone;

  /// No description provided for @alEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get alEveryDay;

  /// No description provided for @alNotifyOnly.
  ///
  /// In en, this message translates to:
  /// **'Notify only'**
  String get alNotifyOnly;

  /// No description provided for @alLockScreen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen'**
  String get alLockScreen;

  /// No description provided for @alEndSession.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get alEndSession;

  /// No description provided for @alSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {error}'**
  String alSaveError(String error);

  /// No description provided for @alEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit alarm'**
  String get alEdit;

  /// No description provided for @alLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bedtime, Homework time'**
  String get alLabelHint;

  /// No description provided for @alTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get alTime;

  /// No description provided for @alRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat on'**
  String get alRepeat;

  /// No description provided for @alNoDays.
  ///
  /// In en, this message translates to:
  /// **'No days selected → fires every day'**
  String get alNoDays;

  /// No description provided for @alWhen.
  ///
  /// In en, this message translates to:
  /// **'When alarm fires'**
  String get alWhen;

  /// No description provided for @alLockPin.
  ///
  /// In en, this message translates to:
  /// **'Lock screen (parent PIN to unlock)'**
  String get alLockPin;

  /// No description provided for @alEndHome.
  ///
  /// In en, this message translates to:
  /// **'End session and return home'**
  String get alEndHome;

  /// No description provided for @scTitleCheck.
  ///
  /// In en, this message translates to:
  /// **'Sign Check'**
  String get scTitleCheck;

  /// No description provided for @scNoClaims.
  ///
  /// In en, this message translates to:
  /// **'{name} has not marked any signs yet. Claims appear here after they use “I can sign this” in the dictionary or finish a Sign It round.'**
  String scNoClaims(String name);

  /// No description provided for @scHowTo.
  ///
  /// In en, this message translates to:
  /// **'Watch the reference clip, ask {name} to sign it, then record what you saw. Confirming is what earns them the sign.'**
  String scHowTo(String name);

  /// No description provided for @scToCheck.
  ///
  /// In en, this message translates to:
  /// **'{count} to check'**
  String scToCheck(int count);

  /// No description provided for @scOnlyUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Only ones I haven’t checked'**
  String get scOnlyUnchecked;

  /// No description provided for @scNothingLeft.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to check. Nice work.'**
  String get scNothingLeft;

  /// No description provided for @scSaysCan.
  ///
  /// In en, this message translates to:
  /// **'Says: “I can sign this”'**
  String get scSaysCan;

  /// No description provided for @scSaysNotYet.
  ///
  /// In en, this message translates to:
  /// **'Says: “Not yet”'**
  String get scSaysNotYet;

  /// No description provided for @scWatchRef.
  ///
  /// In en, this message translates to:
  /// **'Watch the reference sign'**
  String get scWatchRef;

  /// No description provided for @scConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get scConfirm;

  /// No description provided for @cdsCustomize.
  ///
  /// In en, this message translates to:
  /// **'Customize progress'**
  String get cdsCustomize;

  /// No description provided for @cdsActiveToday.
  ///
  /// In en, this message translates to:
  /// **'Active today'**
  String get cdsActiveToday;

  /// No description provided for @cdsLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {when}'**
  String cdsLastActive(String when);

  /// No description provided for @cdsStreak.
  ///
  /// In en, this message translates to:
  /// **'{days} day streak'**
  String cdsStreak(int days);

  /// No description provided for @cdsRecentGames.
  ///
  /// In en, this message translates to:
  /// **'Recent Games'**
  String get cdsRecentGames;

  /// No description provided for @cdsSignCheck.
  ///
  /// In en, this message translates to:
  /// **'Sign Check · {count} to review'**
  String cdsSignCheck(int count);

  /// No description provided for @cdsDailyRoutine.
  ///
  /// In en, this message translates to:
  /// **'Daily Routine'**
  String get cdsDailyRoutine;

  /// No description provided for @cdsFullDashboard.
  ///
  /// In en, this message translates to:
  /// **'View Full Dashboard'**
  String get cdsFullDashboard;

  /// No description provided for @cdsToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get cdsToday;

  /// No description provided for @cdsYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get cdsYesterday;

  /// No description provided for @cdsDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String cdsDaysAgo(int count);

  /// No description provided for @cdsWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} weeks ago'**
  String cdsWeeksAgo(int count);

  /// No description provided for @cdsQuickStats.
  ///
  /// In en, this message translates to:
  /// **'Quick Stats'**
  String get cdsQuickStats;

  /// No description provided for @cdsOfTotal.
  ///
  /// In en, this message translates to:
  /// **'of {total} total'**
  String cdsOfTotal(int total);

  /// No description provided for @cdsAvailable.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get cdsAvailable;

  /// No description provided for @cdsSignsWatched.
  ///
  /// In en, this message translates to:
  /// **'Signs Watched'**
  String get cdsSignsWatched;

  /// No description provided for @cdsOfSigns.
  ///
  /// In en, this message translates to:
  /// **'of {total} signs'**
  String cdsOfSigns(int total);

  /// No description provided for @cdsFslClips.
  ///
  /// In en, this message translates to:
  /// **'FSL clips'**
  String get cdsFslClips;

  /// No description provided for @cdsGreat.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get cdsGreat;

  /// No description provided for @cdsGoodProgress.
  ///
  /// In en, this message translates to:
  /// **'Good progress'**
  String get cdsGoodProgress;

  /// No description provided for @cdsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get cdsCategories;

  /// No description provided for @cdsMasteredPct.
  ///
  /// In en, this message translates to:
  /// **'mastered (≥80%)'**
  String get cdsMasteredPct;

  /// No description provided for @cdsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get cdsThisWeek;

  /// No description provided for @cdsGamesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Games Played'**
  String get cdsGamesPlayed;

  /// No description provided for @cdsSessions.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String cdsSessions(int count);

  /// No description provided for @cdsHuntFinds.
  ///
  /// In en, this message translates to:
  /// **'Word Hunt Finds'**
  String get cdsHuntFinds;

  /// No description provided for @cdsHuntStreak.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String cdsHuntStreak(int days);

  /// No description provided for @cdsWithCamera.
  ///
  /// In en, this message translates to:
  /// **'with the camera'**
  String get cdsWithCamera;

  /// No description provided for @cdsStrengths.
  ///
  /// In en, this message translates to:
  /// **'Strengths & Areas to Improve'**
  String get cdsStrengths;

  /// No description provided for @cdsStrongest.
  ///
  /// In en, this message translates to:
  /// **'Strongest: {category}'**
  String cdsStrongest(String category);

  /// No description provided for @cdsPctMastery.
  ///
  /// In en, this message translates to:
  /// **'{percent}% mastery'**
  String cdsPctMastery(int percent);

  /// No description provided for @cdsNeedsWork.
  ///
  /// In en, this message translates to:
  /// **'Needs work: {category}'**
  String cdsNeedsWork(String category);

  /// No description provided for @cdsPctMasteryMore.
  ///
  /// In en, this message translates to:
  /// **'{percent}% mastery — encourage more practice here'**
  String cdsPctMasteryMore(int percent);

  /// No description provided for @cdsUnexplored.
  ///
  /// In en, this message translates to:
  /// **'{count} categories unexplored'**
  String cdsUnexplored(int count);

  /// No description provided for @cdsJustStarting.
  ///
  /// In en, this message translates to:
  /// **'Just getting started!'**
  String get cdsJustStarting;

  /// No description provided for @cdsEncourage.
  ///
  /// In en, this message translates to:
  /// **'Encourage {name} to try some flashcards or games.'**
  String cdsEncourage(String name);

  /// No description provided for @pcSaved.
  ///
  /// In en, this message translates to:
  /// **'Parental controls saved! ✅'**
  String get pcSaved;

  /// No description provided for @pcTitle.
  ///
  /// In en, this message translates to:
  /// **'Parental Controls'**
  String get pcTitle;

  /// No description provided for @pcIntro.
  ///
  /// In en, this message translates to:
  /// **'Set restrictions to manage how students use the app. These controls apply to all student profiles on this device.'**
  String get pcIntro;

  /// No description provided for @pcDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily Time Limit'**
  String get pcDaily;

  /// No description provided for @pcEnableLimit.
  ///
  /// In en, this message translates to:
  /// **'Enable Time Limit'**
  String get pcEnableLimit;

  /// No description provided for @pcMinutesPerDay.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes per day'**
  String pcMinutesPerDay(int minutes);

  /// No description provided for @pcNoRestriction.
  ///
  /// In en, this message translates to:
  /// **'No time restriction'**
  String get pcNoRestriction;

  /// No description provided for @pcMin.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String pcMin(int minutes);

  /// No description provided for @pc15.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get pc15;

  /// No description provided for @pc3h.
  ///
  /// In en, this message translates to:
  /// **'3 hours'**
  String get pc3h;

  /// No description provided for @pcSchedule.
  ///
  /// In en, this message translates to:
  /// **'Usage Schedule'**
  String get pcSchedule;

  /// No description provided for @pcEnableSchedule.
  ///
  /// In en, this message translates to:
  /// **'Enable Schedule'**
  String get pcEnableSchedule;

  /// No description provided for @pcAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed: {start} – {end}'**
  String pcAllowed(String start, String end);

  /// No description provided for @pcNoTimeOfDay.
  ///
  /// In en, this message translates to:
  /// **'No time-of-day restriction'**
  String get pcNoTimeOfDay;

  /// No description provided for @pcStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get pcStart;

  /// No description provided for @pcEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get pcEnd;

  /// No description provided for @pcFeatures.
  ///
  /// In en, this message translates to:
  /// **'Feature Restrictions'**
  String get pcFeatures;

  /// No description provided for @pcBlockShop.
  ///
  /// In en, this message translates to:
  /// **'Block Star Shop'**
  String get pcBlockShop;

  /// No description provided for @pcBlockShopSub.
  ///
  /// In en, this message translates to:
  /// **'Prevent students from spending stars'**
  String get pcBlockShopSub;

  /// No description provided for @pcBlockMulti.
  ///
  /// In en, this message translates to:
  /// **'Block Multiplayer'**
  String get pcBlockMulti;

  /// No description provided for @pcBlockMultiSub.
  ///
  /// In en, this message translates to:
  /// **'Disable multiplayer quiz mode'**
  String get pcBlockMultiSub;

  /// No description provided for @pcBlockMsg.
  ///
  /// In en, this message translates to:
  /// **'Block Messaging'**
  String get pcBlockMsg;

  /// No description provided for @pcBlockMsgSub.
  ///
  /// In en, this message translates to:
  /// **'Disable in-app messaging'**
  String get pcBlockMsgSub;

  /// No description provided for @pcBlockedGames.
  ///
  /// In en, this message translates to:
  /// **'Blocked Games'**
  String get pcBlockedGames;

  /// No description provided for @pcBlockedGamesSub.
  ///
  /// In en, this message translates to:
  /// **'Select games to hide from students'**
  String get pcBlockedGamesSub;

  /// No description provided for @pcBlockedCats.
  ///
  /// In en, this message translates to:
  /// **'Blocked Categories'**
  String get pcBlockedCats;

  /// No description provided for @pcBlockedCatsSub.
  ///
  /// In en, this message translates to:
  /// **'Select categories to hide from flashcards & games'**
  String get pcBlockedCatsSub;

  /// No description provided for @pcReset.
  ///
  /// In en, this message translates to:
  /// **'Reset All Controls'**
  String get pcReset;

  /// No description provided for @pcVeryShort.
  ///
  /// In en, this message translates to:
  /// **'Very Short'**
  String get pcVeryShort;

  /// No description provided for @pcShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get pcShort;

  /// No description provided for @pcModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get pcModerate;

  /// No description provided for @pcStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get pcStandard;

  /// No description provided for @pcExtended.
  ///
  /// In en, this message translates to:
  /// **'Extended'**
  String get pcExtended;

  /// No description provided for @lgcTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Gain'**
  String get lgcTitle;

  /// No description provided for @woStudyMinutes.
  ///
  /// In en, this message translates to:
  /// **'Study minutes'**
  String get woStudyMinutes;

  /// No description provided for @apAdaptive.
  ///
  /// In en, this message translates to:
  /// **'Adaptive Difficulty'**
  String get apAdaptive;

  /// No description provided for @apDyslexia.
  ///
  /// In en, this message translates to:
  /// **'Dyslexia-friendly'**
  String get apDyslexia;

  /// No description provided for @apFslVideos.
  ///
  /// In en, this message translates to:
  /// **'FSL Videos'**
  String get apFslVideos;

  /// No description provided for @apFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get apFontSize;

  /// No description provided for @apGaze.
  ///
  /// In en, this message translates to:
  /// **'Gaze Control'**
  String get apGaze;

  /// No description provided for @apHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High Contrast'**
  String get apHighContrast;

  /// No description provided for @apReducedMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduced Motion'**
  String get apReducedMotion;

  /// No description provided for @apSoundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get apSoundEffects;

  /// No description provided for @apTts.
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get apTts;

  /// No description provided for @apVoiceNav.
  ///
  /// In en, this message translates to:
  /// **'Voice Navigation'**
  String get apVoiceNav;

  /// No description provided for @apOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get apOn;

  /// No description provided for @apOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get apOff;

  /// No description provided for @apPrioritized.
  ///
  /// In en, this message translates to:
  /// **'Prioritized'**
  String get apPrioritized;

  /// No description provided for @apXl130.
  ///
  /// In en, this message translates to:
  /// **'Extra Large (130%)'**
  String get apXl130;

  /// No description provided for @apXl140.
  ///
  /// In en, this message translates to:
  /// **'Extra Large (140%)'**
  String get apXl140;

  /// No description provided for @apLarge120.
  ///
  /// In en, this message translates to:
  /// **'Large (120%)'**
  String get apLarge120;

  /// No description provided for @apHandsFree.
  ///
  /// In en, this message translates to:
  /// **'On (hands-free)'**
  String get apHandsFree;

  /// No description provided for @apSlow.
  ///
  /// In en, this message translates to:
  /// **'On (Slow)'**
  String get apSlow;

  /// No description provided for @apVerySlow.
  ///
  /// In en, this message translates to:
  /// **'On (Very Slow)'**
  String get apVerySlow;

  /// No description provided for @obWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}! 🎉'**
  String obWelcome(String name);

  /// No description provided for @obWelcomeLearner.
  ///
  /// In en, this message translates to:
  /// **'You’re all set up and ready to start learning! Let’s take a quick tour of everything you can do.'**
  String get obWelcomeLearner;

  /// No description provided for @obWelcomeTeacher.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready! Let’s show you the key features you’ll use to guide your students.'**
  String get obWelcomeTeacher;

  /// No description provided for @obWelcomeParent.
  ///
  /// In en, this message translates to:
  /// **'Your account is ready! Let’s show you the key features you’ll use to support your child’s learning.'**
  String get obWelcomeParent;

  /// No description provided for @obFlashTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn with Flashcards 📚'**
  String get obFlashTitle;

  /// No description provided for @obFlashLearner.
  ///
  /// In en, this message translates to:
  /// **'Browse vocabulary categories like Animals, Colors, Numbers, and more. Each card has pictures, Filipino Sign Language, and text-to-speech to help you learn.'**
  String get obFlashLearner;

  /// No description provided for @obFlashAdult.
  ///
  /// In en, this message translates to:
  /// **'Students learn vocabulary through interactive flashcards with pictures, FSL support, and text-to-speech across multiple categories.'**
  String get obFlashAdult;

  /// No description provided for @obGamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Play Fun Games 🎮'**
  String get obGamesTitle;

  /// No description provided for @obGamesLearner.
  ///
  /// In en, this message translates to:
  /// **'Practice what you’ve learned with Word Match, Spelling Bee, Memory Match, Jigsaw Puzzle, and more! Earn stars ⭐ for every game you play.'**
  String get obGamesLearner;

  /// No description provided for @obGamesAdult.
  ///
  /// In en, this message translates to:
  /// **'Students reinforce vocabulary through 10+ educational games with adjustable difficulty and category filters.'**
  String get obGamesAdult;

  /// No description provided for @obProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Track Your Progress ⭐'**
  String get obProgressTitle;

  /// No description provided for @obProgressLearner.
  ///
  /// In en, this message translates to:
  /// **'See your streak, stars, and words learned on your dashboard. Unlock achievement badges and spend stars in the Star Shop for cool avatars and themes!'**
  String get obProgressLearner;

  /// No description provided for @obProgressAdult.
  ///
  /// In en, this message translates to:
  /// **'Monitor learning progress with detailed dashboards showing mastery rates, streaks, category breakdowns, and exportable reports.'**
  String get obProgressAdult;

  /// No description provided for @obAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Made for Everyone ♿'**
  String get obAccessTitle;

  /// No description provided for @obAccessBody.
  ///
  /// In en, this message translates to:
  /// **'FlashLearn PWD is designed for learners with disabilities. Adjust text size, contrast, animations, and audio in Settings to match your needs. Presets are available for visual, hearing, motor, and cognitive accessibility.'**
  String get obAccessBody;

  /// No description provided for @obReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'You’re Ready! 🚀'**
  String get obReadyTitle;

  /// No description provided for @obReadyLearner.
  ///
  /// In en, this message translates to:
  /// **'Tap a category on the home screen to learn your first words, or jump into a game to start earning stars. Have fun!'**
  String get obReadyLearner;

  /// No description provided for @obReadyTeacher.
  ///
  /// In en, this message translates to:
  /// **'Explore the home screen to discover all available features. Use the dashboard to monitor student progress.'**
  String get obReadyTeacher;

  /// No description provided for @obReadyParent.
  ///
  /// In en, this message translates to:
  /// **'Explore the home screen to discover all available features. Sit with your child and learn together!'**
  String get obReadyParent;

  /// No description provided for @asOptimize.
  ///
  /// In en, this message translates to:
  /// **'We’ll optimize the app for your needs.\nSelect the option that best describes you:'**
  String get asOptimize;

  /// No description provided for @asNoSpecial.
  ///
  /// In en, this message translates to:
  /// **'No special settings needed!\nYou’re all set with the defaults.'**
  String get asNoSpecial;

  /// No description provided for @asDyslexiaSub.
  ///
  /// In en, this message translates to:
  /// **'Cream background, Lexend font, wider letter spacing — easier reading for everyone.'**
  String get asDyslexiaSub;

  /// No description provided for @asMotionSub.
  ///
  /// In en, this message translates to:
  /// **'Less animation, instant page transitions — good for motion sensitivity or older devices.'**
  String get asMotionSub;

  /// No description provided for @asChangeLater.
  ///
  /// In en, this message translates to:
  /// **'You can change these anytime in Settings ⚙️'**
  String get asChangeLater;

  /// No description provided for @asAllSet.
  ///
  /// In en, this message translates to:
  /// **'You’re All Set! 🎉'**
  String get asAllSet;

  /// No description provided for @asOptimizedFor.
  ///
  /// In en, this message translates to:
  /// **'Your app has been optimized for\n{type}.'**
  String asOptimizedFor(String type);

  /// No description provided for @asStandardReady.
  ///
  /// In en, this message translates to:
  /// **'Standard settings are ready to go.'**
  String get asStandardReady;

  /// No description provided for @asAdjustLater.
  ///
  /// In en, this message translates to:
  /// **'You can adjust all settings anytime\nfrom the Settings page.'**
  String get asAdjustLater;

  /// No description provided for @asSaveFinish.
  ///
  /// In en, this message translates to:
  /// **'Save & Finish'**
  String get asSaveFinish;

  /// No description provided for @asComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort tweaks you can try later'**
  String get asComfort;

  /// No description provided for @mrClass.
  ///
  /// In en, this message translates to:
  /// **'You’ve been removed from your class.'**
  String get mrClass;

  /// No description provided for @mrGroup.
  ///
  /// In en, this message translates to:
  /// **'You’ve been removed from your home group.'**
  String get mrGroup;

  /// No description provided for @mrFrom.
  ///
  /// In en, this message translates to:
  /// **'You’ve been removed from {name}.'**
  String mrFrom(String name);

  /// No description provided for @mrSafeClass.
  ///
  /// In en, this message translates to:
  /// **'Your progress is safe on this device. You can join a different class using a new code.'**
  String get mrSafeClass;

  /// No description provided for @mrSafeGroup.
  ///
  /// In en, this message translates to:
  /// **'Your progress is safe on this device. You can join a different home group using a new code.'**
  String get mrSafeGroup;

  /// No description provided for @mrReturning.
  ///
  /// In en, this message translates to:
  /// **'Returning to setup automatically…'**
  String get mrReturning;

  /// No description provided for @spdCategoryProgress.
  ///
  /// In en, this message translates to:
  /// **'Category Progress'**
  String get spdCategoryProgress;

  /// No description provided for @spdRecentScores.
  ///
  /// In en, this message translates to:
  /// **'Recent Game Scores'**
  String get spdRecentScores;

  /// No description provided for @spdDetails.
  ///
  /// In en, this message translates to:
  /// **'Profile Details'**
  String get spdDetails;

  /// No description provided for @spdPinProtected.
  ///
  /// In en, this message translates to:
  /// **'PIN Protected'**
  String get spdPinProtected;

  /// No description provided for @spdMastered.
  ///
  /// In en, this message translates to:
  /// **'{mastered} of {total} categories mastered'**
  String spdMastered(int mastered, int total);

  /// No description provided for @spdBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth Date'**
  String get spdBirthDate;

  /// No description provided for @spdEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get spdEditProfile;

  /// No description provided for @psAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add New Profile'**
  String get psAddNew;

  /// No description provided for @psPinLength.
  ///
  /// In en, this message translates to:
  /// **'PIN must be exactly 4 digits'**
  String get psPinLength;

  /// No description provided for @epEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get epEnterName;

  /// No description provided for @epPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get epPinMismatch;

  /// No description provided for @epUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated! ✅'**
  String get epUpdated;

  /// No description provided for @epApplyPresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply Accessibility Presets?'**
  String get epApplyPresetsTitle;

  /// No description provided for @epApplyPresetsBody.
  ///
  /// In en, this message translates to:
  /// **'Your disability type changed to “{type}”. Would you like to auto-configure accessibility settings?'**
  String epApplyPresetsBody(String type);

  /// No description provided for @epKeepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep Current'**
  String get epKeepCurrent;

  /// No description provided for @epApplyPresets.
  ///
  /// In en, this message translates to:
  /// **'Apply Presets'**
  String get epApplyPresets;

  /// No description provided for @epNoProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Please select a profile to edit.'**
  String get epNoProfileBody;

  /// No description provided for @epTapAvatar.
  ///
  /// In en, this message translates to:
  /// **'Tap below to change avatar'**
  String get epTapAvatar;

  /// No description provided for @epAvatarSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name} avatar'**
  String epAvatarSemantics(String name);

  /// No description provided for @epSelectedSuffix.
  ///
  /// In en, this message translates to:
  /// **', selected'**
  String get epSelectedSuffix;

  /// No description provided for @epPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium Avatars'**
  String get epPremium;

  /// No description provided for @epEarnStars.
  ///
  /// In en, this message translates to:
  /// **'Earn stars in games to unlock special avatars!'**
  String get epEarnStars;

  /// No description provided for @epCosts.
  ///
  /// In en, this message translates to:
  /// **'{emoji} {name} costs {cost} ⭐ — visit the Star Shop!'**
  String epCosts(String emoji, String name, int cost);

  /// No description provided for @epPremiumSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name} premium avatar'**
  String epPremiumSemantics(String name);

  /// No description provided for @epOwnedSuffix.
  ///
  /// In en, this message translates to:
  /// **', owned'**
  String get epOwnedSuffix;

  /// No description provided for @epLockedSuffix.
  ///
  /// In en, this message translates to:
  /// **', locked, {cost} stars'**
  String epLockedSuffix(int cost);

  /// No description provided for @epName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get epName;

  /// No description provided for @epEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get epEnterYourName;

  /// No description provided for @epLearningLevel.
  ///
  /// In en, this message translates to:
  /// **'Learning Level'**
  String get epLearningLevel;

  /// No description provided for @epSetByTeacher.
  ///
  /// In en, this message translates to:
  /// **'Set by your teacher'**
  String get epSetByTeacher;

  /// No description provided for @epGradeLevel.
  ///
  /// In en, this message translates to:
  /// **'Grade Level'**
  String get epGradeLevel;

  /// No description provided for @epSelectGrade.
  ///
  /// In en, this message translates to:
  /// **'Select grade level'**
  String get epSelectGrade;

  /// No description provided for @epNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get epNotSet;

  /// No description provided for @epSection.
  ///
  /// In en, this message translates to:
  /// **'Section / Class'**
  String get epSection;

  /// No description provided for @epSectionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Section A, Rose'**
  String get epSectionHint;

  /// No description provided for @epAge.
  ///
  /// In en, this message translates to:
  /// **'(Age: {age})'**
  String epAge(int age);

  /// No description provided for @epTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get epTags;

  /// No description provided for @epTagsHelp.
  ///
  /// In en, this message translates to:
  /// **'Add custom labels to organize students'**
  String get epTagsHelp;

  /// No description provided for @epAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add a tag...'**
  String get epAddTag;

  /// No description provided for @epInterests.
  ///
  /// In en, this message translates to:
  /// **'Learning Interests'**
  String get epInterests;

  /// No description provided for @epInterestsHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick favourite topics to personalise lessons'**
  String get epInterestsHelp;

  /// No description provided for @epAccessProfile.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Profile'**
  String get epAccessProfile;

  /// No description provided for @epAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'Changing this will offer to auto-configure accessibility settings'**
  String get epAccessHelp;

  /// No description provided for @epPinProtection.
  ///
  /// In en, this message translates to:
  /// **'PIN Protection'**
  String get epPinProtection;

  /// No description provided for @epIsProtected.
  ///
  /// In en, this message translates to:
  /// **'This profile is PIN-protected'**
  String get epIsProtected;

  /// No description provided for @epAddPin.
  ///
  /// In en, this message translates to:
  /// **'Add a 4-digit PIN to protect this profile'**
  String get epAddPin;

  /// No description provided for @epRemovePin.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get epRemovePin;

  /// No description provided for @epPinRemovedOnSave.
  ///
  /// In en, this message translates to:
  /// **'PIN will be removed when you save'**
  String get epPinRemovedOnSave;

  /// No description provided for @epEnablePin.
  ///
  /// In en, this message translates to:
  /// **'Enable PIN lock'**
  String get epEnablePin;

  /// No description provided for @epEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter 4-digit PIN'**
  String get epEnterPin;

  /// No description provided for @epConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get epConfirmPin;

  /// No description provided for @epRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get epRole;

  /// No description provided for @epCannotChange.
  ///
  /// In en, this message translates to:
  /// **'Cannot be changed'**
  String get epCannotChange;

  /// No description provided for @setVoiceTour.
  ///
  /// In en, this message translates to:
  /// **'Voice Guide & Tour'**
  String get setVoiceTour;

  /// No description provided for @setVoiceTourSub.
  ///
  /// In en, this message translates to:
  /// **'Hear how each screen works'**
  String get setVoiceTourSub;

  /// No description provided for @setTutorialsReset.
  ///
  /// In en, this message translates to:
  /// **'Tutorials will appear again on each screen!'**
  String get setTutorialsReset;

  /// No description provided for @setPinRemoved.
  ///
  /// In en, this message translates to:
  /// **'PIN removed'**
  String get setPinRemoved;

  /// No description provided for @setPinSet.
  ///
  /// In en, this message translates to:
  /// **'PIN set successfully!'**
  String get setPinSet;

  /// No description provided for @setEnterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get setEnterPin;

  /// No description provided for @setNoDataLeaves.
  ///
  /// In en, this message translates to:
  /// **'No data leaves this device'**
  String get setNoDataLeaves;

  /// No description provided for @brTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get brTitle;

  /// No description provided for @brKeepSafe.
  ///
  /// In en, this message translates to:
  /// **'Keep Your Data Safe'**
  String get brKeepSafe;

  /// No description provided for @brIntro.
  ///
  /// In en, this message translates to:
  /// **'Back up all profiles, progress, achievements, shop purchases, settings, and custom flashcards. Restore on any device.'**
  String get brIntro;

  /// No description provided for @brLastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {when}'**
  String brLastBackup(String when);

  /// No description provided for @brCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get brCreate;

  /// No description provided for @brCreateSub.
  ///
  /// In en, this message translates to:
  /// **'Export all app data as a .flashlearn file'**
  String get brCreateSub;

  /// No description provided for @brCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get brCreating;

  /// No description provided for @brBackUpNow.
  ///
  /// In en, this message translates to:
  /// **'Back Up Now'**
  String get brBackUpNow;

  /// No description provided for @brRestoreFrom.
  ///
  /// In en, this message translates to:
  /// **'Restore from Backup'**
  String get brRestoreFrom;

  /// No description provided for @brRestoreSub.
  ///
  /// In en, this message translates to:
  /// **'Import a .flashlearn file to restore all data'**
  String get brRestoreSub;

  /// No description provided for @brRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get brRestoring;

  /// No description provided for @brRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get brRestore;

  /// No description provided for @brIncluded.
  ///
  /// In en, this message translates to:
  /// **'WHAT’S INCLUDED'**
  String get brIncluded;

  /// No description provided for @brProfiles.
  ///
  /// In en, this message translates to:
  /// **'All student profiles'**
  String get brProfiles;

  /// No description provided for @brProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress & achievements'**
  String get brProgress;

  /// No description provided for @brStars.
  ///
  /// In en, this message translates to:
  /// **'Stars & shop purchases'**
  String get brStars;

  /// No description provided for @brCustomCards.
  ///
  /// In en, this message translates to:
  /// **'Custom flashcards'**
  String get brCustomCards;

  /// No description provided for @brSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings & accessibility'**
  String get brSettings;

  /// No description provided for @brAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Session analytics'**
  String get brAnalytics;

  /// No description provided for @brSpaced.
  ///
  /// In en, this message translates to:
  /// **'Spaced repetition data'**
  String get brSpaced;

  /// No description provided for @brWarning.
  ///
  /// In en, this message translates to:
  /// **'Restoring a backup will replace all current data. Consider creating a backup first before restoring.'**
  String get brWarning;

  /// No description provided for @brCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created successfully!'**
  String get brCreated;

  /// No description provided for @brCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create backup.'**
  String get brCreateFailed;

  /// No description provided for @brRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup?'**
  String get brRestoreTitle;

  /// No description provided for @brRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace ALL current data with the backup data. This action cannot be undone.\n\nMake sure to create a backup of your current data first.'**
  String get brRestoreBody;

  /// No description provided for @ieExported.
  ///
  /// In en, this message translates to:
  /// **'{name} exported successfully'**
  String ieExported(String name);

  /// No description provided for @ieExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String ieExportFailed(String error);

  /// No description provided for @ieImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String ieImportFailed(String error);

  /// No description provided for @ieImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Student Profile'**
  String get ieImportTitle;

  /// No description provided for @ieImportSub.
  ///
  /// In en, this message translates to:
  /// **'Restore a student profile from a JSON file exported by another device.'**
  String get ieImportSub;

  /// No description provided for @ieImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get ieImporting;

  /// No description provided for @ieChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get ieChooseFile;

  /// No description provided for @ieExportStudent.
  ///
  /// In en, this message translates to:
  /// **'Export a Student'**
  String get ieExportStudent;

  /// No description provided for @ieExportSub.
  ///
  /// In en, this message translates to:
  /// **'Tap a student below to export their profile, progress, and achievements as a JSON file.'**
  String get ieExportSub;

  /// No description provided for @ieNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No student profiles to export'**
  String get ieNoStudents;

  /// No description provided for @ieExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get ieExport;

  /// No description provided for @baEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an email'**
  String get baEnterEmail;

  /// No description provided for @baValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get baValidEmail;

  /// No description provided for @baPwLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get baPwLength;

  /// No description provided for @baPwMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get baPwMismatch;

  /// No description provided for @baEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'That email already has an account. Choose “I already have an account” instead.'**
  String get baEmailInUse;

  /// No description provided for @baWeakPw.
  ///
  /// In en, this message translates to:
  /// **'That password is too easy to guess. Use 8+ characters.'**
  String get baWeakPw;

  /// No description provided for @baBadEmail.
  ///
  /// In en, this message translates to:
  /// **'That doesn’t look like a valid email address.'**
  String get baBadEmail;

  /// No description provided for @baWrongCreds.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get baWrongCreds;

  /// No description provided for @baDisabled.
  ///
  /// In en, this message translates to:
  /// **'That account has been disabled.'**
  String get baDisabled;

  /// No description provided for @baOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Try again when you’re online.'**
  String get baOffline;

  /// No description provided for @baTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait a minute and try again.'**
  String get baTooMany;

  /// No description provided for @baLinkedElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This device is already linked to a different account.'**
  String get baLinkedElsewhere;

  /// No description provided for @baSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed ({code}).'**
  String baSignInFailed(String code);

  /// No description provided for @baLinked.
  ///
  /// In en, this message translates to:
  /// **'Account linked! Your data is now backed up to {email}.'**
  String baLinked(String email);

  /// No description provided for @baSignedInNone.
  ///
  /// In en, this message translates to:
  /// **'Signed in. No backup data was found for this account.'**
  String get baSignedInNone;

  /// No description provided for @baSignedInRestored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Signed in. Restored 1 profile from the cloud.} other{Signed in. Restored {count} profiles from the cloud.}}'**
  String baSignedInRestored(int count);

  /// No description provided for @baEnterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your email above before requesting a reset.'**
  String get baEnterEmailFirst;

  /// No description provided for @baResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}.'**
  String baResetSent(String email);

  /// No description provided for @baSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of linked account?'**
  String get baSignOutTitle;

  /// No description provided for @baSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'The app will keep working offline, but new cloud writes will use a fresh anonymous session. Your local profiles stay on this device — they are not deleted.'**
  String get baSignOutBody;

  /// No description provided for @baSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get baSignOut;

  /// No description provided for @baSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get baSignedOut;

  /// No description provided for @baTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Link Account'**
  String get baTitle;

  /// No description provided for @baActive.
  ///
  /// In en, this message translates to:
  /// **'Backup is active'**
  String get baActive;

  /// No description provided for @baNone.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get baNone;

  /// No description provided for @baLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'Linked to {email}. Sign in with this email on a new device to restore your profiles and progress.'**
  String baLinkedTo(String email);

  /// No description provided for @baUnknownEmail.
  ///
  /// In en, this message translates to:
  /// **'(unknown email)'**
  String get baUnknownEmail;

  /// No description provided for @baLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored on this device only. Link an email below so you can recover everything if the device is lost or reset.'**
  String get baLocalOnly;

  /// No description provided for @baSignInRestore.
  ///
  /// In en, this message translates to:
  /// **'Sign in to restore'**
  String get baSignInRestore;

  /// No description provided for @baCreateBackup.
  ///
  /// In en, this message translates to:
  /// **'Create a backup'**
  String get baCreateBackup;

  /// No description provided for @baUseOther.
  ///
  /// In en, this message translates to:
  /// **'Use the email and password you set on your other device.'**
  String get baUseOther;

  /// No description provided for @baPickCreds.
  ///
  /// In en, this message translates to:
  /// **'Pick an email and password to back up this device. No verification email required.'**
  String get baPickCreds;

  /// No description provided for @baEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get baEmail;

  /// No description provided for @baPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get baPassword;

  /// No description provided for @baHidePw.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get baHidePw;

  /// No description provided for @baShowPw.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get baShowPw;

  /// No description provided for @baConfirmPw.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get baConfirmPw;

  /// No description provided for @baSignInRestoreBtn.
  ///
  /// In en, this message translates to:
  /// **'Sign in & restore'**
  String get baSignInRestoreBtn;

  /// No description provided for @baLinkDevice.
  ///
  /// In en, this message translates to:
  /// **'Link this device'**
  String get baLinkDevice;

  /// No description provided for @baCreateOne.
  ///
  /// In en, this message translates to:
  /// **'Don’t have an account yet? Create one'**
  String get baCreateOne;

  /// No description provided for @baHaveOne.
  ///
  /// In en, this message translates to:
  /// **'I already have an account — sign in'**
  String get baHaveOne;

  /// No description provided for @baForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password? Send reset email'**
  String get baForgot;

  /// No description provided for @baSendReset.
  ///
  /// In en, this message translates to:
  /// **'Send password reset email'**
  String get baSendReset;

  /// No description provided for @baSignOutLinked.
  ///
  /// In en, this message translates to:
  /// **'Sign out of linked account'**
  String get baSignOutLinked;

  /// No description provided for @rcNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t find a profile for that code. Double-check each letter and try again.'**
  String get rcNotFound;

  /// No description provided for @rcAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This recovery code has already been used. Generate a new one from the original device, or contact your teacher.'**
  String get rcAlreadyUsed;

  /// No description provided for @rcInvalid.
  ///
  /// In en, this message translates to:
  /// **'That code doesn’t look right. Check for letters that look similar (e.g. zero / O).'**
  String get rcInvalid;

  /// No description provided for @rcDenied.
  ///
  /// In en, this message translates to:
  /// **'The cloud refused this request. Ask your teacher to check the app’s cloud setup.'**
  String get rcDenied;

  /// No description provided for @rcCollision.
  ///
  /// In en, this message translates to:
  /// **'Could not make a unique code. Please try again.'**
  String get rcCollision;

  /// No description provided for @rcNetwork.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the cloud. Check the internet connection and try again.'**
  String get rcNetwork;

  /// No description provided for @rcUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get rcUnknown;

  /// No description provided for @rcWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}!'**
  String rcWelcomeBack(String name);

  /// No description provided for @rcRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while restoring your profile: {error}'**
  String rcRestoreFailed(String error);

  /// No description provided for @rcTitle.
  ///
  /// In en, this message translates to:
  /// **'Recover Profile'**
  String get rcTitle;

  /// No description provided for @rcFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Letters only, any case. Dashes are optional.'**
  String get rcFormatHint;

  /// No description provided for @rcRestoreMine.
  ///
  /// In en, this message translates to:
  /// **'Restore my profile'**
  String get rcRestoreMine;

  /// No description provided for @rcNoCloud.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync is not connected on this device. Connect to the internet to recover a profile.'**
  String get rcNoCloud;

  /// No description provided for @rcLookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up code…'**
  String get rcLookingUp;

  /// No description provided for @rcVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get rcVerifying;

  /// No description provided for @rcRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring profile…'**
  String get rcRestoring;

  /// No description provided for @rcLoadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Loading progress…'**
  String get rcLoadingProgress;

  /// No description provided for @rcDone.
  ///
  /// In en, this message translates to:
  /// **'Done!'**
  String get rcDone;

  /// No description provided for @rcWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get rcWelcome;

  /// No description provided for @rcIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter the recovery code you saved from your previous device to restore your profile and progress here.'**
  String get rcIntro;

  /// No description provided for @rcEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter your recovery code'**
  String get rcEnterCode;

  /// No description provided for @rcCodeFormat.
  ///
  /// In en, this message translates to:
  /// **'Codes are 10 letters/numbers (with optional dashes)'**
  String get rcCodeFormat;

  /// No description provided for @rcCreated.
  ///
  /// In en, this message translates to:
  /// **'Recovery code created. Save it somewhere safe.'**
  String get rcCreated;

  /// No description provided for @rcBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Recovery'**
  String get rcBackupTitle;

  /// No description provided for @rcSelectProfile.
  ///
  /// In en, this message translates to:
  /// **'Select a profile first to view its recovery code.'**
  String get rcSelectProfile;

  /// No description provided for @rcExplain.
  ///
  /// In en, this message translates to:
  /// **'A recovery code lets {name} restore their profile and progress on a new device if this one is lost or replaced.'**
  String rcExplain(String name);

  /// No description provided for @rcNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No recovery code yet'**
  String get rcNoneYet;

  /// No description provided for @rcGenerateNow.
  ///
  /// In en, this message translates to:
  /// **'Generate a one-time code now. Write it down or take a photo — you’ll need it to restore this profile on another device.'**
  String get rcGenerateNow;

  /// No description provided for @rcGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get rcGenerating;

  /// No description provided for @rcGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate recovery code'**
  String get rcGenerate;

  /// No description provided for @rcCodeCreated.
  ///
  /// In en, this message translates to:
  /// **'Code created!'**
  String get rcCodeCreated;

  /// No description provided for @rcYourCode.
  ///
  /// In en, this message translates to:
  /// **'Your recovery code'**
  String get rcYourCode;

  /// No description provided for @rcCopied.
  ///
  /// In en, this message translates to:
  /// **'Recovery code copied to clipboard'**
  String get rcCopied;

  /// No description provided for @rcCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get rcCopy;

  /// No description provided for @rcSaveWarning.
  ///
  /// In en, this message translates to:
  /// **'Save this code somewhere safe. If you lose it AND lose access to this device, the profile cannot be recovered.'**
  String get rcSaveWarning;

  /// No description provided for @rcRegenerating.
  ///
  /// In en, this message translates to:
  /// **'Regenerating…'**
  String get rcRegenerating;

  /// No description provided for @rcNewCode.
  ///
  /// In en, this message translates to:
  /// **'Generate a new code'**
  String get rcNewCode;

  /// No description provided for @rcRevokes.
  ///
  /// In en, this message translates to:
  /// **'Regenerating revokes the previous code.'**
  String get rcRevokes;

  /// No description provided for @jcNoClass.
  ///
  /// In en, this message translates to:
  /// **'No class found with that code. Check the code with your teacher.'**
  String get jcNoClass;

  /// No description provided for @jcNoGroup.
  ///
  /// In en, this message translates to:
  /// **'No home group found with that code. Check the code with your parent.'**
  String get jcNoGroup;

  /// No description provided for @jcNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t check the code. Make sure the tablet is online, then try again.'**
  String get jcNetwork;

  /// No description provided for @jcUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while joining. Please try again.'**
  String get jcUnknown;

  /// No description provided for @csxAuthTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud sign-in not ready'**
  String get csxAuthTitle;

  /// No description provided for @csxAuthBody.
  ///
  /// In en, this message translates to:
  /// **'The app couldn’t sign in anonymously, so Firestore is rejecting writes. Common fixes:\n\n1) Firebase Console → Authentication → Sign-in method → enable Anonymous.\n2) Deploy the security rules: `firebase deploy --only firestore:rules`.\n3) Connect the device to the internet for one launch so the sign-in can complete.'**
  String get csxAuthBody;

  /// No description provided for @csxLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile locked to another device'**
  String get csxLockedTitle;

  /// No description provided for @csxLockedBody.
  ///
  /// In en, this message translates to:
  /// **'This profile was created on a different device (or before the app was reinstalled). Tap “Reset for this device” to claim it for this anonymous sign-in, or sign in on the original device.'**
  String get csxLockedBody;

  /// No description provided for @csxSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud setup incomplete'**
  String get csxSetupTitle;

  /// No description provided for @csxSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Firestore rejected the request. Run through these steps once, then try again:\n\n1) Firebase Console → Authentication → Sign-in method → enable Anonymous.\n2) From the project root: `firebase deploy --only firestore:rules`.\n3) Pull the device online for at least one launch.'**
  String get csxSetupBody;

  /// No description provided for @csxOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get csxOffline;

  /// No description provided for @csxOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'You’re seeing your last saved data. New changes will sync when this device is back online.'**
  String get csxOfflineBody;

  /// No description provided for @csxWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get csxWrong;

  /// No description provided for @csxWrongBody.
  ///
  /// In en, this message translates to:
  /// **'Try again. If this keeps happening, expand the details below and share them with support.'**
  String get csxWrongBody;

  /// No description provided for @csxDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get csxDetails;

  /// No description provided for @csxRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying…'**
  String get csxRetrying;

  /// No description provided for @csxReset.
  ///
  /// In en, this message translates to:
  /// **'Profile reset for this device.'**
  String get csxReset;

  /// No description provided for @csxResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String csxResetFailed(String error);

  /// No description provided for @csxResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset for this device'**
  String get csxResetButton;

  /// No description provided for @ssCloudSync.
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get ssCloudSync;

  /// No description provided for @ssNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get ssNotConfigured;

  /// No description provided for @ssIssue.
  ///
  /// In en, this message translates to:
  /// **'Sync Issue'**
  String get ssIssue;

  /// No description provided for @ssFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'{count} failed — tap to retry'**
  String ssFailedRetry(int count);

  /// No description provided for @ssPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Sync'**
  String get ssPending;

  /// No description provided for @ssAllUploaded.
  ///
  /// In en, this message translates to:
  /// **'All data uploaded'**
  String get ssAllUploaded;

  /// No description provided for @ssFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync Failed'**
  String get ssFailed;

  /// No description provided for @ssTapRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get ssTapRetry;

  /// No description provided for @ssWhenOnline.
  ///
  /// In en, this message translates to:
  /// **'Will sync when online'**
  String get ssWhenOnline;

  /// No description provided for @ssTapSync.
  ///
  /// In en, this message translates to:
  /// **'Tap to sync now'**
  String get ssTapSync;

  /// No description provided for @crbOff.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync OFF — local-only mode.'**
  String get crbOff;

  /// No description provided for @crbBody.
  ///
  /// In en, this message translates to:
  /// **'Codes you create here can’t be joined from other devices. {reason}'**
  String crbBody(String reason);

  /// No description provided for @ssUploadingN.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Uploading 1 change} other{Uploading {count} changes}}'**
  String ssUploadingN(int count);

  /// No description provided for @ssUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading data'**
  String get ssUploading;

  /// No description provided for @ssJustNow.
  ///
  /// In en, this message translates to:
  /// **'Synced just now'**
  String get ssJustNow;

  /// No description provided for @ssMinutes.
  ///
  /// In en, this message translates to:
  /// **'Synced {count}m ago'**
  String ssMinutes(int count);

  /// No description provided for @ssHours.
  ///
  /// In en, this message translates to:
  /// **'Synced {count}h ago'**
  String ssHours(int count);

  /// No description provided for @ssDays.
  ///
  /// In en, this message translates to:
  /// **'Synced {count}d ago'**
  String ssDays(int count);

  /// No description provided for @vgTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice-Guided Mode'**
  String get vgTitle;

  /// No description provided for @vgEnabled.
  ///
  /// In en, this message translates to:
  /// **'Voice navigation is now enabled.'**
  String get vgEnabled;

  /// No description provided for @vgSpeed.
  ///
  /// In en, this message translates to:
  /// **'Voice Speed'**
  String get vgSpeed;

  /// No description provided for @vgSlow.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get vgSlow;

  /// No description provided for @vgFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get vgFast;

  /// No description provided for @vgLanguage.
  ///
  /// In en, this message translates to:
  /// **'Voice Language'**
  String get vgLanguage;

  /// No description provided for @vgSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking...'**
  String get vgSpeaking;

  /// No description provided for @vgTest.
  ///
  /// In en, this message translates to:
  /// **'Test Voice'**
  String get vgTest;

  /// No description provided for @vgTour.
  ///
  /// In en, this message translates to:
  /// **'Guided Tour'**
  String get vgTour;

  /// No description provided for @vgTourIntro.
  ///
  /// In en, this message translates to:
  /// **'Take a step-by-step tour of the entire app with voice narration for each screen.'**
  String get vgTourIntro;

  /// No description provided for @vgStartTour.
  ///
  /// In en, this message translates to:
  /// **'Start Tour'**
  String get vgStartTour;

  /// No description provided for @vgPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get vgPrevious;

  /// No description provided for @vgFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish Tour'**
  String get vgFinish;

  /// No description provided for @vgQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick Screen Announcements'**
  String get vgQuick;

  /// No description provided for @vgQuickIntro.
  ///
  /// In en, this message translates to:
  /// **'Tap any button below to hear a description of that screen.'**
  String get vgQuickIntro;

  /// No description provided for @vgVerySlow.
  ///
  /// In en, this message translates to:
  /// **'Very Slow'**
  String get vgVerySlow;

  /// No description provided for @vgNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get vgNormal;

  /// No description provided for @vgVeryFast.
  ///
  /// In en, this message translates to:
  /// **'Very Fast'**
  String get vgVeryFast;

  /// No description provided for @vgTourDone.
  ///
  /// In en, this message translates to:
  /// **'Guided tour complete. You’re all set!'**
  String get vgTourDone;

  /// No description provided for @vgNav.
  ///
  /// In en, this message translates to:
  /// **'Voice Navigation'**
  String get vgNav;

  /// No description provided for @vgActive.
  ///
  /// In en, this message translates to:
  /// **'Active — Screen changes and buttons are announced'**
  String get vgActive;

  /// No description provided for @vgTapEnable.
  ///
  /// In en, this message translates to:
  /// **'Tap the switch to enable voice announcements'**
  String get vgTapEnable;

  /// No description provided for @vgChipHome.
  ///
  /// In en, this message translates to:
  /// **'🏠 Home'**
  String get vgChipHome;

  /// No description provided for @vgChipCards.
  ///
  /// In en, this message translates to:
  /// **'📚 Flashcards'**
  String get vgChipCards;

  /// No description provided for @vgChipGames.
  ///
  /// In en, this message translates to:
  /// **'🎮 Games'**
  String get vgChipGames;

  /// No description provided for @vgChipProgress.
  ///
  /// In en, this message translates to:
  /// **'📊 Progress'**
  String get vgChipProgress;

  /// No description provided for @vgChipStories.
  ///
  /// In en, this message translates to:
  /// **'📖 Stories'**
  String get vgChipStories;

  /// No description provided for @vgChipShop.
  ///
  /// In en, this message translates to:
  /// **'⭐ Shop'**
  String get vgChipShop;

  /// No description provided for @vgChipSettings.
  ///
  /// In en, this message translates to:
  /// **'⚙️ Settings'**
  String get vgChipSettings;

  /// No description provided for @gpTitle.
  ///
  /// In en, this message translates to:
  /// **'🎮  Game Controller'**
  String get gpTitle;

  /// No description provided for @gpPractise.
  ///
  /// In en, this message translates to:
  /// **'Practise the controller'**
  String get gpPractise;

  /// No description provided for @gpPractiseButtons.
  ///
  /// In en, this message translates to:
  /// **'Practise the buttons'**
  String get gpPractiseButtons;

  /// No description provided for @gpPractiseHelp.
  ///
  /// In en, this message translates to:
  /// **'Press anything and hear what it does. Nothing in the app moves while practising.'**
  String get gpPractiseHelp;

  /// No description provided for @gpEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable controller'**
  String get gpEnable;

  /// No description provided for @gpEnabledOn.
  ///
  /// In en, this message translates to:
  /// **'A paired controller can drive the app'**
  String get gpEnabledOn;

  /// No description provided for @gpEnabledOff.
  ///
  /// In en, this message translates to:
  /// **'Off — touch only'**
  String get gpEnabledOff;

  /// No description provided for @gpSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get gpSpeech;

  /// No description provided for @gpSay.
  ///
  /// In en, this message translates to:
  /// **'Say what is happening'**
  String get gpSay;

  /// No description provided for @gpSayHelp.
  ///
  /// In en, this message translates to:
  /// **'Announces each section, each item and every question. Leave this on for a learner who cannot see the screen.'**
  String get gpSayHelp;

  /// No description provided for @gpSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speech speed'**
  String get gpSpeed;

  /// No description provided for @gpSpeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Experienced listeners often want this faster than it starts. It sets the speaking speed for the whole app, so stories and vocabulary read at the same pace.'**
  String get gpSpeedHelp;

  /// No description provided for @gpReadItem.
  ///
  /// In en, this message translates to:
  /// **'Read each item'**
  String get gpReadItem;

  /// No description provided for @gpReadItemHelp.
  ///
  /// In en, this message translates to:
  /// **'Says the name and position — “Games, 3 of 8” — as the cursor lands on it.'**
  String get gpReadItemHelp;

  /// No description provided for @gpMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving between sections'**
  String get gpMoving;

  /// No description provided for @gpAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask before switching'**
  String get gpAsk;

  /// No description provided for @gpAskHelp.
  ///
  /// In en, this message translates to:
  /// **'Left and right ask “Do you want to go to the Cards section?” — A for yes, B for no. Turn off to switch straight away.'**
  String get gpAskHelp;

  /// No description provided for @gpComfort.
  ///
  /// In en, this message translates to:
  /// **'Comfort'**
  String get gpComfort;

  /// No description provided for @gpVibrate.
  ///
  /// In en, this message translates to:
  /// **'Vibrate on each press'**
  String get gpVibrate;

  /// No description provided for @gpVibrateHelp.
  ///
  /// In en, this message translates to:
  /// **'A silent confirmation that the press registered, even while a previous sentence is still finishing.'**
  String get gpVibrateHelp;

  /// No description provided for @gpDedupe.
  ///
  /// In en, this message translates to:
  /// **'Ignore repeat presses within'**
  String get gpDedupe;

  /// No description provided for @gpMs.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String gpMs(int ms);

  /// No description provided for @gpDedupeHelp.
  ///
  /// In en, this message translates to:
  /// **'Raise this for a learner whose grip produces extra presses. Lower it if deliberate quick presses are being missed.'**
  String get gpDedupeHelp;

  /// No description provided for @gpHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to keep moving'**
  String get gpHold;

  /// No description provided for @gpHoldHelp.
  ///
  /// In en, this message translates to:
  /// **'Holding up or down keeps stepping through items, instead of one press per step. Opening, going back and switching section never repeat.'**
  String get gpHoldHelp;

  /// No description provided for @gpWait.
  ///
  /// In en, this message translates to:
  /// **'Wait before repeating'**
  String get gpWait;

  /// No description provided for @gpWaitHelp.
  ///
  /// In en, this message translates to:
  /// **'Long enough that an ordinary press never starts a repeat.'**
  String get gpWaitHelp;

  /// No description provided for @gpRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat every'**
  String get gpRepeat;

  /// No description provided for @gpRepeatHelp.
  ///
  /// In en, this message translates to:
  /// **'Slow enough that each item is still announced in full.'**
  String get gpRepeatHelp;

  /// No description provided for @gpSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap A and B'**
  String get gpSwap;

  /// No description provided for @gpSwapHelp.
  ///
  /// In en, this message translates to:
  /// **'Only if “yes” and “no” come out backwards — some controllers label the bottom button B rather than A.'**
  String get gpSwapHelp;

  /// No description provided for @gpGuide.
  ///
  /// In en, this message translates to:
  /// **'Button guide'**
  String get gpGuide;

  /// No description provided for @gpGuideHelp.
  ///
  /// In en, this message translates to:
  /// **'The learner can hear this list at any time by pressing Select.'**
  String get gpGuideHelp;

  /// No description provided for @gpVerySlow.
  ///
  /// In en, this message translates to:
  /// **'Very slow'**
  String get gpVerySlow;

  /// No description provided for @gpVeryFast.
  ///
  /// In en, this message translates to:
  /// **'Very fast'**
  String get gpVeryFast;

  /// No description provided for @gpConnectedTo.
  ///
  /// In en, this message translates to:
  /// **'Controller connected: {name}'**
  String gpConnectedTo(String name);

  /// No description provided for @gpNoController.
  ///
  /// In en, this message translates to:
  /// **'No controller connected'**
  String get gpNoController;

  /// No description provided for @gpConnected.
  ///
  /// In en, this message translates to:
  /// **'Controller connected'**
  String get gpConnected;

  /// No description provided for @gpNone.
  ///
  /// In en, this message translates to:
  /// **'No controller'**
  String get gpNone;

  /// No description provided for @gpPair.
  ///
  /// In en, this message translates to:
  /// **'Pair one in Android Settings → Bluetooth, then come back here.'**
  String get gpPair;

  /// No description provided for @gppTitle.
  ///
  /// In en, this message translates to:
  /// **'🎮  Practice'**
  String get gppTitle;

  /// No description provided for @gppNoController.
  ///
  /// In en, this message translates to:
  /// **'No controller connected. Switch it on and it will start responding here.'**
  String get gppNoController;

  /// No description provided for @gppPressAny.
  ///
  /// In en, this message translates to:
  /// **'Press any button on the controller'**
  String get gppPressAny;

  /// No description provided for @gppPressAnyShort.
  ///
  /// In en, this message translates to:
  /// **'Press any button'**
  String get gppPressAnyShort;

  /// No description provided for @gppWillTell.
  ///
  /// In en, this message translates to:
  /// **'I will tell you what it does. Nothing else will happen.'**
  String get gppWillTell;

  /// No description provided for @gppTried.
  ///
  /// In en, this message translates to:
  /// **'Tried {tried} of {total}'**
  String gppTried(int tried, int total);

  /// No description provided for @gppStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get gppStartOver;

  /// No description provided for @gppLeave.
  ///
  /// In en, this message translates to:
  /// **'Press L1 twice to leave.'**
  String get gppLeave;

  /// No description provided for @hfReasonSign.
  ///
  /// In en, this message translates to:
  /// **'This activity records you signing, so it needs the camera to itself. Head control will pause while it is open.'**
  String get hfReasonSign;

  /// No description provided for @hfVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'You can still say “go back” to leave at any time.'**
  String get hfVoiceHint;

  /// No description provided for @hfUsesCamera.
  ///
  /// In en, this message translates to:
  /// **'{activity} uses the camera'**
  String hfUsesCamera(String activity);

  /// No description provided for @hfNoVoice.
  ///
  /// In en, this message translates to:
  /// **'To leave, use the Back button at the top — or turn on Voice commands in Settings → Accessibility → Gaze Control first, so you can say “go back”.'**
  String get hfNoVoice;

  /// No description provided for @hfNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get hfNotNow;

  /// No description provided for @hfOpenAnyway.
  ///
  /// In en, this message translates to:
  /// **'Open anyway'**
  String get hfOpenAnyway;

  /// No description provided for @hfHuntVoice.
  ///
  /// In en, this message translates to:
  /// **'You can say “take a photo” to shoot, a word’s name to open it, and “go back” to leave.'**
  String get hfHuntVoice;

  /// No description provided for @gzPrevious.
  ///
  /// In en, this message translates to:
  /// **'⬅  Previous'**
  String get gzPrevious;

  /// No description provided for @gzNext.
  ///
  /// In en, this message translates to:
  /// **'Next  ➡'**
  String get gzNext;

  /// No description provided for @gzHear.
  ///
  /// In en, this message translates to:
  /// **'🔊  Hear Word'**
  String get gzHear;

  /// No description provided for @gzFlip.
  ///
  /// In en, this message translates to:
  /// **'🔄  Flip Card'**
  String get gzFlip;

  /// No description provided for @gzSelect.
  ///
  /// In en, this message translates to:
  /// **'✓  Select (blink)'**
  String get gzSelect;

  /// No description provided for @gzPreview.
  ///
  /// In en, this message translates to:
  /// **'👁️  Gaze Control (Preview)'**
  String get gzPreview;

  /// No description provided for @gzHearWord.
  ///
  /// In en, this message translates to:
  /// **'Hear Word'**
  String get gzHearWord;

  /// No description provided for @gzFlipCard.
  ///
  /// In en, this message translates to:
  /// **'Flip Card'**
  String get gzFlipCard;

  /// No description provided for @gzLook.
  ///
  /// In en, this message translates to:
  /// **'😊  Look at the screen'**
  String get gzLook;

  /// No description provided for @gzNoCamera.
  ///
  /// In en, this message translates to:
  /// **'Gaze Control needs a front camera, which this device doesn’t have.'**
  String get gzNoCamera;

  /// No description provided for @gzPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera access is needed to track your head. Enable it in Settings, then try again.'**
  String get gzPermission;

  /// No description provided for @gzCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'The camera couldn’t start. Please try again.'**
  String get gzCameraFailed;

  /// No description provided for @gzTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get gzTryAgain;

  /// No description provided for @gzBlink.
  ///
  /// In en, this message translates to:
  /// **'😉  Blink to choose'**
  String get gzBlink;

  /// No description provided for @gzStatusNoCamera.
  ///
  /// In en, this message translates to:
  /// **'Gaze: no front camera'**
  String get gzStatusNoCamera;

  /// No description provided for @gzStatusPermission.
  ///
  /// In en, this message translates to:
  /// **'Gaze: camera permission needed'**
  String get gzStatusPermission;

  /// No description provided for @gzUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Gaze unavailable'**
  String get gzUnavailable;

  /// No description provided for @gzsTitle.
  ///
  /// In en, this message translates to:
  /// **'👁️  Gaze Control'**
  String get gzsTitle;

  /// No description provided for @gzsEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Gaze Control'**
  String get gzsEnable;

  /// No description provided for @gzsOn.
  ///
  /// In en, this message translates to:
  /// **'Head movements & blinks can drive the app'**
  String get gzsOn;

  /// No description provided for @gzsTryNow.
  ///
  /// In en, this message translates to:
  /// **'Try gaze control now'**
  String get gzsTryNow;

  /// No description provided for @gzsTryIt.
  ///
  /// In en, this message translates to:
  /// **'Try it now'**
  String get gzsTryIt;

  /// No description provided for @gzsHandsFree.
  ///
  /// In en, this message translates to:
  /// **'Hands-free navigation'**
  String get gzsHandsFree;

  /// No description provided for @gzsNavOnly.
  ///
  /// In en, this message translates to:
  /// **'Bottom nav only'**
  String get gzsNavOnly;

  /// No description provided for @gzsNavOnlySub.
  ///
  /// In en, this message translates to:
  /// **'The head D-pad moves the highlight across the bottom tabs. Blink (or look up) to open.'**
  String get gzsNavOnlySub;

  /// No description provided for @gzsNavTiles.
  ///
  /// In en, this message translates to:
  /// **'Bottom nav + feature tiles'**
  String get gzsNavTiles;

  /// No description provided for @gzsNavTilesSub.
  ///
  /// In en, this message translates to:
  /// **'Also reach the feature tiles on Home, Cards, Games, Stories & Progress: look ◀ ▶ across a row, ▲ ▼ between rows, and blink to open.'**
  String get gzsNavTilesSub;

  /// No description provided for @gzsVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get gzsVoice;

  /// No description provided for @gzsVoiceCommands.
  ///
  /// In en, this message translates to:
  /// **'Voice commands'**
  String get gzsVoiceCommands;

  /// No description provided for @gzsVoiceSub.
  ///
  /// In en, this message translates to:
  /// **'Say “left”, “right”, “up”, “down” to move the highlight, “select” to open it — or a button’s name (“next”, “flip”, “games”), “scroll down”, “go back”.'**
  String get gzsVoiceSub;

  /// No description provided for @gzsTuning.
  ///
  /// In en, this message translates to:
  /// **'Tuning'**
  String get gzsTuning;

  /// No description provided for @gzsSensitivity.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity'**
  String get gzsSensitivity;

  /// No description provided for @gzsSensitivityHelp.
  ///
  /// In en, this message translates to:
  /// **'Higher = a smaller head movement selects.'**
  String get gzsSensitivityHelp;

  /// No description provided for @gzsHold.
  ///
  /// In en, this message translates to:
  /// **'Hold time'**
  String get gzsHold;

  /// No description provided for @gzsSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String gzsSeconds(String seconds);

  /// No description provided for @gzsHoldHelp.
  ///
  /// In en, this message translates to:
  /// **'How long to look at a button before it activates.'**
  String get gzsHoldHelp;

  /// No description provided for @gzsBlink.
  ///
  /// In en, this message translates to:
  /// **'Blink to confirm'**
  String get gzsBlink;

  /// No description provided for @gzsBlinkSub.
  ///
  /// In en, this message translates to:
  /// **'A long, deliberate blink acts as “select”'**
  String get gzsBlinkSub;

  /// No description provided for @gzsScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning (no head movement)'**
  String get gzsScanning;

  /// No description provided for @gzsScanMode.
  ///
  /// In en, this message translates to:
  /// **'Scanning mode'**
  String get gzsScanMode;

  /// No description provided for @gzsScanSub.
  ///
  /// In en, this message translates to:
  /// **'Buttons highlight one by one — blink to pick. For learners who can’t move their head.'**
  String get gzsScanSub;

  /// No description provided for @gzsScanSpeed.
  ///
  /// In en, this message translates to:
  /// **'Scan speed'**
  String get gzsScanSpeed;

  /// No description provided for @gzsScanHelp.
  ///
  /// In en, this message translates to:
  /// **'How long each button stays highlighted before moving on.'**
  String get gzsScanHelp;

  /// No description provided for @gzsCalibration.
  ///
  /// In en, this message translates to:
  /// **'Device calibration'**
  String get gzsCalibration;

  /// No description provided for @gzsMirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror left / right'**
  String get gzsMirror;

  /// No description provided for @gzsMirrorSub.
  ///
  /// In en, this message translates to:
  /// **'Turn off if Left and Right feel swapped'**
  String get gzsMirrorSub;

  /// No description provided for @gzsInvert.
  ///
  /// In en, this message translates to:
  /// **'Invert up / down'**
  String get gzsInvert;

  /// No description provided for @gzsInvertSub.
  ///
  /// In en, this message translates to:
  /// **'Turn on if Up and Down feel swapped'**
  String get gzsInvertSub;

  /// No description provided for @gzsLowest.
  ///
  /// In en, this message translates to:
  /// **'Lowest'**
  String get gzsLowest;

  /// No description provided for @gzsLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get gzsLow;

  /// No description provided for @gzsBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get gzsBalanced;

  /// No description provided for @gzsHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get gzsHigh;

  /// No description provided for @gzsHighest.
  ///
  /// In en, this message translates to:
  /// **'Highest'**
  String get gzsHighest;

  /// No description provided for @gzsIntro.
  ///
  /// In en, this message translates to:
  /// **'Control the app hands-free. Move your head toward a button and hold briefly to choose it, or blink to confirm. Everything runs on this device — no internet needed.'**
  String get gzsIntro;

  /// No description provided for @gzsScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose how far the hands-free D-pad reaches. Either way it stays off until “Enable Gaze Control” is on, and touch always works.'**
  String get gzsScopeHint;

  /// No description provided for @gzsCalibrationHint.
  ///
  /// In en, this message translates to:
  /// **'These fix a device where the directions feel reversed. Tap “Try it now” above, and if a movement picks the wrong side, toggle the matching switch.'**
  String get gzsCalibrationHint;

  /// No description provided for @lsNoProfile.
  ///
  /// In en, this message translates to:
  /// **'No profile selected'**
  String get lsNoProfile;

  /// No description provided for @lsLiveSession.
  ///
  /// In en, this message translates to:
  /// **'Live Session'**
  String get lsLiveSession;

  /// No description provided for @lsJoinClass.
  ///
  /// In en, this message translates to:
  /// **'Join the Class'**
  String get lsJoinClass;

  /// No description provided for @lsHostTitle.
  ///
  /// In en, this message translates to:
  /// **'Host live games & quizzes from TV Cast'**
  String get lsHostTitle;

  /// No description provided for @lsHostBody.
  ///
  /// In en, this message translates to:
  /// **'Open TV Cast, start casting, then choose “Live Activity” to build questions, set star scoring, and see raised hands and the scoreboard on the TV.'**
  String get lsHostBody;

  /// No description provided for @lsOpenCast.
  ///
  /// In en, this message translates to:
  /// **'Open TV Cast'**
  String get lsOpenCast;

  /// No description provided for @lsJoinFirst.
  ///
  /// In en, this message translates to:
  /// **'Join a class first'**
  String get lsJoinFirst;

  /// No description provided for @lsChildJoin.
  ///
  /// In en, this message translates to:
  /// **'Ask your parent for the home-group code, then join from Settings to take part in live activities.'**
  String get lsChildJoin;

  /// No description provided for @lsStudentJoin.
  ///
  /// In en, this message translates to:
  /// **'You are not in a classroom yet. Tap “Join a class” to take part in live activities.'**
  String get lsStudentJoin;

  /// No description provided for @lsConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet'**
  String get lsConnect;

  /// No description provided for @lsConnectBody.
  ///
  /// In en, this message translates to:
  /// **'Live activities need a connection so you can join your class in real time. Connect to Wi-Fi or mobile data and reopen this screen.'**
  String get lsConnectBody;

  /// No description provided for @lsNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No live activity yet. Your teacher will start one soon.'**
  String get lsNoActivity;

  /// No description provided for @lsGetReady.
  ///
  /// In en, this message translates to:
  /// **'Get ready! Waiting for the next question…'**
  String get lsGetReady;

  /// No description provided for @lsHandRaised.
  ///
  /// In en, this message translates to:
  /// **'Hand raised. Your teacher can see your name.'**
  String get lsHandRaised;

  /// No description provided for @lsHandLowered.
  ///
  /// In en, this message translates to:
  /// **'Hand lowered.'**
  String get lsHandLowered;

  /// No description provided for @lsCorrectStars.
  ///
  /// In en, this message translates to:
  /// **'Correct! You earned {count} stars.'**
  String lsCorrectStars(int count);

  /// No description provided for @lsCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get lsCorrect;

  /// No description provided for @lsGoodTry.
  ///
  /// In en, this message translates to:
  /// **'Good try. Wait for the next question.'**
  String get lsGoodTry;

  /// No description provided for @lsFirstCorrect.
  ///
  /// In en, this message translates to:
  /// **'First correct answer! Bonus {count} stars.'**
  String lsFirstCorrect(int count);

  /// No description provided for @lsGotIt.
  ///
  /// In en, this message translates to:
  /// **'I got it! ✋'**
  String get lsGotIt;

  /// No description provided for @lsNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get lsNotYet;

  /// No description provided for @lsGotItShort.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get lsGotItShort;

  /// No description provided for @lsQuestionNofM.
  ///
  /// In en, this message translates to:
  /// **'Question {number} of {total}'**
  String lsQuestionNofM(int number, int total);

  /// No description provided for @lsWatchSign.
  ///
  /// In en, this message translates to:
  /// **'Watch the sign on the TV, then choose the matching word.'**
  String get lsWatchSign;

  /// No description provided for @lsWhichPicture.
  ///
  /// In en, this message translates to:
  /// **'Which word matches the picture?'**
  String get lsWhichPicture;

  /// No description provided for @lsCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **', correct answer'**
  String get lsCorrectAnswer;

  /// No description provided for @lsYourWrong.
  ///
  /// In en, this message translates to:
  /// **', your answer, incorrect'**
  String get lsYourWrong;

  /// No description provided for @lsCorrectStarsEmoji.
  ///
  /// In en, this message translates to:
  /// **'Correct! You earned {count} ⭐'**
  String lsCorrectStarsEmoji(int count);

  /// No description provided for @lsCorrectEmoji.
  ///
  /// In en, this message translates to:
  /// **'Correct! 🎉'**
  String get lsCorrectEmoji;

  /// No description provided for @lsKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Good try! Keep going 💪'**
  String get lsKeepGoing;

  /// No description provided for @lsLowerYourHand.
  ///
  /// In en, this message translates to:
  /// **'Lower your hand'**
  String get lsLowerYourHand;

  /// No description provided for @lsRaiseForHelp.
  ///
  /// In en, this message translates to:
  /// **'Raise your hand to ask your teacher for help'**
  String get lsRaiseForHelp;

  /// No description provided for @lsLowerHand.
  ///
  /// In en, this message translates to:
  /// **'Lower hand'**
  String get lsLowerHand;

  /// No description provided for @lsRaiseHand.
  ///
  /// In en, this message translates to:
  /// **'Raise hand'**
  String get lsRaiseHand;

  /// No description provided for @mpTaken.
  ///
  /// In en, this message translates to:
  /// **'This game already has another player.'**
  String get mpTaken;

  /// No description provided for @mpNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'Online play needs an internet connection.'**
  String get mpNeedsInternet;

  /// No description provided for @mpWarming.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is still warming up. Try again in a moment.'**
  String get mpWarming;

  /// No description provided for @mpSlow.
  ///
  /// In en, this message translates to:
  /// **'Network is slow. Check your connection and try again.'**
  String get mpSlow;

  /// No description provided for @mpDenied.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach the game service. If this keeps happening, ask your teacher to redeploy the app rules.'**
  String get mpDenied;

  /// No description provided for @mpStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t start the game. Try again in a moment.'**
  String get mpStartFailed;

  /// No description provided for @mpStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get mpStart;

  /// No description provided for @mpChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get mpChoose;

  /// No description provided for @mpDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get mpDone;

  /// No description provided for @mpNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Not enough words to play yet — add a few flashcards first!'**
  String get mpNotEnough;

  /// No description provided for @mpNoProfile.
  ///
  /// In en, this message translates to:
  /// **'No active profile.'**
  String get mpNoProfile;

  /// No description provided for @mpPlayWith.
  ///
  /// In en, this message translates to:
  /// **'Play with {name}'**
  String mpPlayWith(String name);

  /// No description provided for @mqTitle.
  ///
  /// In en, this message translates to:
  /// **'Multiplayer Quiz'**
  String get mqTitle;

  /// No description provided for @mqStart.
  ///
  /// In en, this message translates to:
  /// **'Start Battle!'**
  String get mqStart;

  /// No description provided for @mqTurn.
  ///
  /// In en, this message translates to:
  /// **'{name}’s Turn!'**
  String mqTurn(String name);

  /// No description provided for @mqRound.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}'**
  String mqRound(int round, int total);

  /// No description provided for @mqTapStart.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere to start!'**
  String get mqTapStart;

  /// No description provided for @mqDraw.
  ///
  /// In en, this message translates to:
  /// **'It’s a Draw!'**
  String get mqDraw;

  /// No description provided for @mqNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Not enough flashcards to play!'**
  String get mqNotEnough;

  /// No description provided for @mqBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best Streak'**
  String get mqBestStreak;

  /// No description provided for @mpWhichWord.
  ///
  /// In en, this message translates to:
  /// **'Which word is this?'**
  String get mpWhichWord;

  /// No description provided for @mqWhatInEnglish.
  ///
  /// In en, this message translates to:
  /// **'What is this in English?'**
  String get mqWhatInEnglish;

  /// No description provided for @siRound.
  ///
  /// In en, this message translates to:
  /// **'Round {round} of {total}.'**
  String siRound(int round, int total);

  /// No description provided for @siSignThis.
  ///
  /// In en, this message translates to:
  /// **'Sign this word: {english}, {filipino}.'**
  String siSignThis(String english, String filipino);

  /// No description provided for @siTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign It!'**
  String get siTitle;

  /// No description provided for @siSelfAssessed.
  ///
  /// In en, this message translates to:
  /// **'Self-assessed signs'**
  String get siSelfAssessed;

  /// No description provided for @siWatchAgain.
  ///
  /// In en, this message translates to:
  /// **'Watch the sign again'**
  String get siWatchAgain;

  /// No description provided for @siGotIt.
  ///
  /// In en, this message translates to:
  /// **'I got it'**
  String get siGotIt;

  /// No description provided for @siGotItBang.
  ///
  /// In en, this message translates to:
  /// **'I got it!'**
  String get siGotItBang;

  /// No description provided for @siTitleRound.
  ///
  /// In en, this message translates to:
  /// **'Sign It!  •  {round}/{total}'**
  String siTitleRound(int round, int total);

  /// No description provided for @siWatchThen.
  ///
  /// In en, this message translates to:
  /// **'Watch, then sign it back!'**
  String get siWatchThen;

  /// No description provided for @siYourTake.
  ///
  /// In en, this message translates to:
  /// **'Your take'**
  String get siYourTake;

  /// No description provided for @siYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get siYou;

  /// No description provided for @siNoPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera permission off.\nYou can still watch and practise!'**
  String get siNoPermission;

  /// No description provided for @siNoCamera.
  ///
  /// In en, this message translates to:
  /// **'No camera found.\nJust watch and practise the sign!'**
  String get siNoCamera;

  /// No description provided for @siCameraOff.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable.\nJust watch and practise the sign!'**
  String get siCameraOff;

  /// No description provided for @fvNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'The sign for “{word}” needs the internet to load the first time. Connect and try again — after that it works offline.'**
  String fvNeedsInternet(String word);

  /// No description provided for @fvNoVideo.
  ///
  /// In en, this message translates to:
  /// **'No FSL video available yet for “{word}”.'**
  String fvNoVideo(String word);

  /// No description provided for @fvCanYou.
  ///
  /// In en, this message translates to:
  /// **'Can you sign this?'**
  String get fvCanYou;

  /// No description provided for @fvTeacherConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Your teacher confirmed this sign'**
  String get fvTeacherConfirmed;

  /// No description provided for @fvKeepPractising.
  ///
  /// In en, this message translates to:
  /// **'Your teacher says keep practising this one'**
  String get fvKeepPractising;

  /// No description provided for @fpLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load video'**
  String get fpLoadFailed;

  /// No description provided for @fpClose.
  ///
  /// In en, this message translates to:
  /// **'Close fullscreen video'**
  String get fpClose;

  /// No description provided for @fpHideCaptions.
  ///
  /// In en, this message translates to:
  /// **'Hide captions'**
  String get fpHideCaptions;

  /// No description provided for @fpShowCaptions.
  ///
  /// In en, this message translates to:
  /// **'Show captions'**
  String get fpShowCaptions;

  /// No description provided for @fpSpeedSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback speed settings'**
  String get fpSpeedSettings;

  /// No description provided for @fpPause.
  ///
  /// In en, this message translates to:
  /// **'Pause video'**
  String get fpPause;

  /// No description provided for @fpPlay.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get fpPlay;

  /// No description provided for @fpSetSpeed.
  ///
  /// In en, this message translates to:
  /// **'Set speed to {speed}x'**
  String fpSetSpeed(String speed);

  /// No description provided for @fpReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay from beginning'**
  String get fpReplay;

  /// No description provided for @fpPauseShort.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get fpPauseShort;

  /// No description provided for @fpPlayShort.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get fpPlayShort;

  /// No description provided for @fpProgress.
  ///
  /// In en, this message translates to:
  /// **'Video progress'**
  String get fpProgress;

  /// No description provided for @opByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get opByCategory;

  /// No description provided for @opTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline Signs'**
  String get opTitle;

  /// No description provided for @opIntro.
  ///
  /// In en, this message translates to:
  /// **'Save sign videos to this device so they play without internet.'**
  String get opIntro;

  /// No description provided for @opSavedOf.
  ///
  /// In en, this message translates to:
  /// **'{ready} of {total} signs saved'**
  String opSavedOf(int ready, int total);

  /// No description provided for @opUsing.
  ///
  /// In en, this message translates to:
  /// **'Using {size} on this device'**
  String opUsing(String size);

  /// No description provided for @opNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get opNothing;

  /// No description provided for @opSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving “{label}”… {done} of {total}'**
  String opSaving(String label, int done, int total);

  /// No description provided for @opStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get opStop;

  /// No description provided for @opAllSaved.
  ///
  /// In en, this message translates to:
  /// **'All signs saved'**
  String get opAllSaved;

  /// No description provided for @opSaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save all {count}'**
  String opSaveAll(int count);

  /// No description provided for @opFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} couldn’t be saved — check the connection and try again. Those words still work online.'**
  String opFailed(int count);

  /// No description provided for @opNoSigns.
  ///
  /// In en, this message translates to:
  /// **'No signs recorded yet'**
  String get opNoSigns;

  /// No description provided for @opCatSaved.
  ///
  /// In en, this message translates to:
  /// **'{ready} of {total} saved'**
  String opCatSaved(int ready, int total);

  /// No description provided for @opSaveCat.
  ///
  /// In en, this message translates to:
  /// **'Save {category} offline'**
  String opSaveCat(String category);

  /// No description provided for @opRemoveCat.
  ///
  /// In en, this message translates to:
  /// **'Remove {category} downloads'**
  String opRemoveCat(String category);

  /// No description provided for @feSoon.
  ///
  /// In en, this message translates to:
  /// **'FSL videos coming soon'**
  String get feSoon;

  /// No description provided for @feRecording.
  ///
  /// In en, this message translates to:
  /// **'We’re still recording sign-language videos for these categories. Practice with the flashcards in the meantime!'**
  String get feRecording;

  /// No description provided for @feReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to practice now:'**
  String get feReady;

  /// No description provided for @feChooseAnother.
  ///
  /// In en, this message translates to:
  /// **'Choose another category'**
  String get feChooseAnother;

  /// No description provided for @siStopRec.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get siStopRec;

  /// No description provided for @siRecordMe.
  ///
  /// In en, this message translates to:
  /// **'Record myself signing'**
  String get siRecordMe;

  /// No description provided for @siSignThisLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign this word: {english}, {filipino}'**
  String siSignThisLabel(String english, String filipino);

  /// No description provided for @siReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get siReference;

  /// No description provided for @siRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get siRecord;

  /// No description provided for @aqOptions.
  ///
  /// In en, this message translates to:
  /// **'Accessibility options'**
  String get aqOptions;

  /// No description provided for @aqIntro.
  ///
  /// In en, this message translates to:
  /// **'Make the app easier to see, hear, and use.'**
  String get aqIntro;

  /// No description provided for @aqTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get aqTextSize;

  /// No description provided for @aqHcSub.
  ///
  /// In en, this message translates to:
  /// **'Bolder colors and outlines'**
  String get aqHcSub;

  /// No description provided for @aqEasyRead.
  ///
  /// In en, this message translates to:
  /// **'Easy-Read Font'**
  String get aqEasyRead;

  /// No description provided for @aqEasyReadSub.
  ///
  /// In en, this message translates to:
  /// **'Friendlier spacing for reading'**
  String get aqEasyReadSub;

  /// No description provided for @aqReadAloud.
  ///
  /// In en, this message translates to:
  /// **'Read Aloud'**
  String get aqReadAloud;

  /// No description provided for @aqReadAloudSub.
  ///
  /// In en, this message translates to:
  /// **'Speak words and buttons'**
  String get aqReadAloudSub;

  /// No description provided for @aqReduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce Motion'**
  String get aqReduceMotion;

  /// No description provided for @aqReduceMotionSub.
  ///
  /// In en, this message translates to:
  /// **'Calmer, simpler animations'**
  String get aqReduceMotionSub;

  /// No description provided for @aqTextSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Text size {label}'**
  String aqTextSizeLabel(String label);

  /// No description provided for @btTitle.
  ///
  /// In en, this message translates to:
  /// **'Take a Break'**
  String get btTitle;

  /// No description provided for @btBack.
  ///
  /// In en, this message translates to:
  /// **'Back to lesson'**
  String get btBack;

  /// No description provided for @btPick.
  ///
  /// In en, this message translates to:
  /// **'Pick what feels good. You can go back to your lesson anytime.'**
  String get btPick;

  /// No description provided for @btCalmer.
  ///
  /// In en, this message translates to:
  /// **'Feeling calmer?'**
  String get btCalmer;

  /// No description provided for @btStay.
  ///
  /// In en, this message translates to:
  /// **'Stay a little longer'**
  String get btStay;

  /// No description provided for @btHowFeel.
  ///
  /// In en, this message translates to:
  /// **'How are you feeling?'**
  String get btHowFeel;

  /// No description provided for @btBreathe.
  ///
  /// In en, this message translates to:
  /// **'Breathe'**
  String get btBreathe;

  /// No description provided for @btBubbles.
  ///
  /// In en, this message translates to:
  /// **'Pop Bubbles'**
  String get btBubbles;

  /// No description provided for @btBreatheSub.
  ///
  /// In en, this message translates to:
  /// **'Slow, calming breaths'**
  String get btBreatheSub;

  /// No description provided for @btBubblesSub.
  ///
  /// In en, this message translates to:
  /// **'Gently pop the bubbles'**
  String get btBubblesSub;

  /// No description provided for @sqSeeScore.
  ///
  /// In en, this message translates to:
  /// **'See my score'**
  String get sqSeeScore;

  /// No description provided for @sqNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get sqNextQuestion;

  /// No description provided for @sqListenEn.
  ///
  /// In en, this message translates to:
  /// **'Listen to this choice in English'**
  String get sqListenEn;

  /// No description provided for @sqListenTl.
  ///
  /// In en, this message translates to:
  /// **'Listen to this choice in Tagalog'**
  String get sqListenTl;

  /// No description provided for @sqSeeResults.
  ///
  /// In en, this message translates to:
  /// **'See Results'**
  String get sqSeeResults;

  /// No description provided for @sqNextQuestionCap.
  ///
  /// In en, this message translates to:
  /// **'Next Question'**
  String get sqNextQuestionCap;

  /// No description provided for @sqNotQuite.
  ///
  /// In en, this message translates to:
  /// **'Not quite. {answer}.'**
  String sqNotQuite(String answer);

  /// No description provided for @sqQuestionNofM.
  ///
  /// In en, this message translates to:
  /// **'Question {number} of {total}'**
  String sqQuestionNofM(int number, int total);

  /// No description provided for @srNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get srNextPage;

  /// No description provided for @srReadPage.
  ///
  /// In en, this message translates to:
  /// **'Read this page aloud'**
  String get srReadPage;

  /// No description provided for @srGoQuiz.
  ///
  /// In en, this message translates to:
  /// **'Go to the quiz'**
  String get srGoQuiz;

  /// No description provided for @srPageNofM.
  ///
  /// In en, this message translates to:
  /// **'Page {number} of {total}'**
  String srPageNofM(int number, int total);

  /// No description provided for @abCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Assessment'**
  String get abCreate;

  /// No description provided for @abDetails.
  ///
  /// In en, this message translates to:
  /// **'Assessment Details'**
  String get abDetails;

  /// No description provided for @abTitleField.
  ///
  /// In en, this message translates to:
  /// **'Assessment Title'**
  String get abTitleField;

  /// No description provided for @abTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get abTitleRequired;

  /// No description provided for @abDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get abDescription;

  /// No description provided for @abDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get abDifficulty;

  /// No description provided for @abTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'Time Limit'**
  String get abTimeLimit;

  /// No description provided for @abMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String abMinutes(int minutes);

  /// No description provided for @abQuestionsCount.
  ///
  /// In en, this message translates to:
  /// **'Questions ({count})'**
  String abQuestionsCount(int count);

  /// No description provided for @abNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No Questions Yet'**
  String get abNoQuestions;

  /// No description provided for @abNoQuestionsBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first question to build the assessment.'**
  String get abNoQuestionsBody;

  /// No description provided for @abAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add First Question'**
  String get abAddFirst;

  /// No description provided for @abAddQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add Question'**
  String get abAddQuestion;

  /// No description provided for @abNeedOne.
  ///
  /// In en, this message translates to:
  /// **'Add at least one question'**
  String get abNeedOne;

  /// No description provided for @abCustomDesc.
  ///
  /// In en, this message translates to:
  /// **'Custom teacher assessment'**
  String get abCustomDesc;

  /// No description provided for @abSaved.
  ///
  /// In en, this message translates to:
  /// **'Assessment “{title}” saved!'**
  String abSaved(String title);

  /// No description provided for @abDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard Assessment?'**
  String get abDiscardTitle;

  /// No description provided for @abDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved questions. Are you sure you want to go back?'**
  String get abDiscardBody;

  /// No description provided for @abKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get abKeepEditing;

  /// No description provided for @abDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get abDiscard;

  /// No description provided for @abAnswer.
  ///
  /// In en, this message translates to:
  /// **'Answer: {answer}'**
  String abAnswer(String answer);

  /// No description provided for @abChoices.
  ///
  /// In en, this message translates to:
  /// **'Choices: {choices}'**
  String abChoices(String choices);

  /// No description provided for @abEditQuestion.
  ///
  /// In en, this message translates to:
  /// **'Edit Question'**
  String get abEditQuestion;

  /// No description provided for @abQuestionType.
  ///
  /// In en, this message translates to:
  /// **'Question Type'**
  String get abQuestionType;

  /// No description provided for @abQuestionText.
  ///
  /// In en, this message translates to:
  /// **'Question Text *'**
  String get abQuestionText;

  /// No description provided for @abCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct Answer *'**
  String get abCorrectAnswer;

  /// No description provided for @abChoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choices'**
  String get abChoicesTitle;

  /// No description provided for @abChoiceN.
  ///
  /// In en, this message translates to:
  /// **'Choice {letter}'**
  String abChoiceN(String letter);

  /// No description provided for @abAddChoice.
  ///
  /// In en, this message translates to:
  /// **'Add Choice'**
  String get abAddChoice;

  /// No description provided for @abCategory.
  ///
  /// In en, this message translates to:
  /// **'Category (optional)'**
  String get abCategory;

  /// No description provided for @abHint.
  ///
  /// In en, this message translates to:
  /// **'Hint (optional)'**
  String get abHint;

  /// No description provided for @abUpdateQuestion.
  ///
  /// In en, this message translates to:
  /// **'Update Question'**
  String get abUpdateQuestion;

  /// No description provided for @abTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Question text and answer are required'**
  String get abTextRequired;

  /// No description provided for @abAnswerInChoices.
  ///
  /// In en, this message translates to:
  /// **'Correct answer must match one of the choices'**
  String get abAnswerInChoices;

  /// No description provided for @qbTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz Builder'**
  String get qbTitle;

  /// No description provided for @qbMyQuiz.
  ///
  /// In en, this message translates to:
  /// **'My Quiz'**
  String get qbMyQuiz;

  /// No description provided for @qbQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz Title'**
  String get qbQuizTitle;

  /// No description provided for @qbQuestionTypes.
  ///
  /// In en, this message translates to:
  /// **'Question Types'**
  String get qbQuestionTypes;

  /// No description provided for @qbTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'Time Limit (optional)'**
  String get qbTimeLimit;

  /// No description provided for @qbNoLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get qbNoLimit;

  /// No description provided for @qbSelectWords.
  ///
  /// In en, this message translates to:
  /// **'Select Words ({count} selected)'**
  String qbSelectWords(int count);

  /// No description provided for @qbSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get qbSelectAll;

  /// No description provided for @qbDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get qbDeselectAll;

  /// No description provided for @qbAtLeast3.
  ///
  /// In en, this message translates to:
  /// **'Select at least 3 words to create a quiz'**
  String get qbAtLeast3;

  /// No description provided for @qbSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved Quizzes'**
  String get qbSaved;

  /// No description provided for @qbSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} words • {difficulty} • {formats}'**
  String qbSummary(int count, String difficulty, String formats);

  /// No description provided for @qbStart.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get qbStart;

  /// No description provided for @qbDuplicate.
  ///
  /// In en, this message translates to:
  /// **'You already have a quiz called “{title}”. Give this one a different name.'**
  String qbDuplicate(String title);

  /// No description provided for @qbSavedOne.
  ///
  /// In en, this message translates to:
  /// **'Quiz “{title}” saved!'**
  String qbSavedOne(String title);

  /// No description provided for @qbNoCards.
  ///
  /// In en, this message translates to:
  /// **'No valid cards found for this quiz'**
  String get qbNoCards;

  /// No description provided for @qbDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Quiz?'**
  String get qbDeleteTitle;

  /// No description provided for @qbDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String qbDeleteBody(String title);

  /// No description provided for @bbMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum {count} tiles reached'**
  String bbMax(int count);

  /// No description provided for @bbAlready.
  ///
  /// In en, this message translates to:
  /// **'Tile already added'**
  String get bbAlready;

  /// No description provided for @bbAdded.
  ///
  /// In en, this message translates to:
  /// **'“{label}” added to the board'**
  String bbAdded(String label);

  /// No description provided for @bbNeedName.
  ///
  /// In en, this message translates to:
  /// **'Please give the board a name'**
  String get bbNeedName;

  /// No description provided for @bbCleared.
  ///
  /// In en, this message translates to:
  /// **'Board cleared — the tab is hidden on Talk Board'**
  String get bbCleared;

  /// No description provided for @bbSaved.
  ///
  /// In en, this message translates to:
  /// **'“{name}” saved with {count, plural, =1{1 tile} other{{count} tiles}}'**
  String bbSaved(String name, int count);

  /// No description provided for @bbDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get bbDiscardTitle;

  /// No description provided for @bbDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'This board has changes that have not been saved yet.'**
  String get bbDiscardBody;

  /// No description provided for @bbKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get bbKeepEditing;

  /// No description provided for @bbMyBoard.
  ///
  /// In en, this message translates to:
  /// **'My Board'**
  String get bbMyBoard;

  /// No description provided for @bbDoneEditing.
  ///
  /// In en, this message translates to:
  /// **'Done editing'**
  String get bbDoneEditing;

  /// No description provided for @bbReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder/remove tiles'**
  String get bbReorder;

  /// No description provided for @bbPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview with speech'**
  String get bbPreview;

  /// No description provided for @bbNameField.
  ///
  /// In en, this message translates to:
  /// **'Board name (shown as the tab)'**
  String get bbNameField;

  /// No description provided for @bbTapBelow.
  ///
  /// In en, this message translates to:
  /// **'Tap tiles below, or make your own word'**
  String get bbTapBelow;

  /// No description provided for @bbMyWord.
  ///
  /// In en, this message translates to:
  /// **'{word} · my word'**
  String bbMyWord(String word);

  /// No description provided for @bbRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove {label}'**
  String bbRemove(String label);

  /// No description provided for @bbCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / {max} tiles'**
  String bbCount(int count, int max);

  /// No description provided for @bbClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get bbClearAll;

  /// No description provided for @bbMakeWord.
  ///
  /// In en, this message translates to:
  /// **'Make my own word'**
  String get bbMakeWord;

  /// No description provided for @bbAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'already added'**
  String get bbAlreadyAdded;

  /// No description provided for @bbTapToAdd.
  ///
  /// In en, this message translates to:
  /// **'tap to add'**
  String get bbTapToAdd;

  /// No description provided for @bbSaveBoard.
  ///
  /// In en, this message translates to:
  /// **'Save Board'**
  String get bbSaveBoard;

  /// No description provided for @bbEditWord.
  ///
  /// In en, this message translates to:
  /// **'Edit word'**
  String get bbEditWord;

  /// No description provided for @bbWordEn.
  ///
  /// In en, this message translates to:
  /// **'Word (English)'**
  String get bbWordEn;

  /// No description provided for @bbWordEnHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ate Maria'**
  String get bbWordEnHint;

  /// No description provided for @bbWordFil.
  ///
  /// In en, this message translates to:
  /// **'Word (Filipino) — optional'**
  String get bbWordFil;

  /// No description provided for @bbWordFilHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to reuse the English word'**
  String get bbWordFilHint;

  /// No description provided for @bbPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get bbPicture;

  /// No description provided for @bbPictureN.
  ///
  /// In en, this message translates to:
  /// **'Picture {number}'**
  String bbPictureN(int number);

  /// No description provided for @cfUpdated.
  ///
  /// In en, this message translates to:
  /// **'Flashcard updated! ✏️'**
  String get cfUpdated;

  /// No description provided for @cfCreated.
  ///
  /// In en, this message translates to:
  /// **'Flashcard created! 🎉'**
  String get cfCreated;

  /// No description provided for @cfEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Flashcard'**
  String get cfEditTitle;

  /// No description provided for @cfCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Flashcard'**
  String get cfCreateTitle;

  /// No description provided for @cfCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get cfCategory;

  /// No description provided for @cfWordFil.
  ///
  /// In en, this message translates to:
  /// **'Word (Filipino)'**
  String get cfWordFil;

  /// No description provided for @cfHintEn.
  ///
  /// In en, this message translates to:
  /// **'e.g. Butterfly'**
  String get cfHintEn;

  /// No description provided for @cfHintFil.
  ///
  /// In en, this message translates to:
  /// **'e.g. Paru-paro'**
  String get cfHintFil;

  /// No description provided for @cfEnterWord.
  ///
  /// In en, this message translates to:
  /// **'Enter a word'**
  String get cfEnterWord;

  /// No description provided for @cfEnterTranslation.
  ///
  /// In en, this message translates to:
  /// **'Enter a translation'**
  String get cfEnterTranslation;

  /// No description provided for @cfExample.
  ///
  /// In en, this message translates to:
  /// **'Example Sentence (optional)'**
  String get cfExample;

  /// No description provided for @cfExampleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. The butterfly is colorful.'**
  String get cfExampleHint;

  /// No description provided for @cfUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Flashcard'**
  String get cfUpdate;

  /// No description provided for @cfYourWord.
  ///
  /// In en, this message translates to:
  /// **'Your Word'**
  String get cfYourWord;

  /// No description provided for @cfNoSpeech.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition not available on this device.'**
  String get cfNoSpeech;

  /// No description provided for @cfVoiceReady.
  ///
  /// In en, this message translates to:
  /// **'Voice Ready'**
  String get cfVoiceReady;

  /// No description provided for @cfImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get cfImage;

  /// No description provided for @cfTapImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to add an image'**
  String get cfTapImage;

  /// No description provided for @cfListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get cfListening;

  /// No description provided for @cfDictate.
  ///
  /// In en, this message translates to:
  /// **'Dictate'**
  String get cfDictate;

  /// No description provided for @dtAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {count} cards from {name}'**
  String dtAdded(int count, String name);

  /// No description provided for @dtFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not add template'**
  String get dtFailed;

  /// No description provided for @dtTitle.
  ///
  /// In en, this message translates to:
  /// **'Deck Templates'**
  String get dtTitle;

  /// No description provided for @dtHeading.
  ///
  /// In en, this message translates to:
  /// **'Pre-built decks for quick setup'**
  String get dtHeading;

  /// No description provided for @dtIntro.
  ///
  /// In en, this message translates to:
  /// **'Tap “Use this deck” to copy these bilingual cards into your custom deck.'**
  String get dtIntro;

  /// No description provided for @dtCards.
  ///
  /// In en, this message translates to:
  /// **'{count} cards'**
  String dtCards(int count);

  /// No description provided for @dtPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get dtPreview;

  /// No description provided for @dtUseDeck.
  ///
  /// In en, this message translates to:
  /// **'Use deck'**
  String get dtUseDeck;

  /// No description provided for @dtAdding.
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get dtAdding;

  /// No description provided for @dtUseThis.
  ///
  /// In en, this message translates to:
  /// **'Use this deck ({count} cards)'**
  String dtUseThis(int count);

  /// No description provided for @awWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What does “PWD” mean?'**
  String get awWhatTitle;

  /// No description provided for @awWhatBody.
  ///
  /// In en, this message translates to:
  /// **'PWD stands for Persons with Disabilities — people who have a long-term physical, sensory, cognitive, or learning condition. Disability is a natural part of human diversity. Use person-first language: say “a person with a disability,” not “a disabled person.” Every learner deserves the same respect and the same chance to learn.'**
  String get awWhatBody;

  /// No description provided for @awKindsTitle.
  ///
  /// In en, this message translates to:
  /// **'Common kinds of disability'**
  String get awKindsTitle;

  /// No description provided for @awRespectTitle.
  ///
  /// In en, this message translates to:
  /// **'Interacting respectfully'**
  String get awRespectTitle;

  /// No description provided for @awRespect1.
  ///
  /// In en, this message translates to:
  /// **'Speak directly to the person, not to their companion or interpreter.'**
  String get awRespect1;

  /// No description provided for @awRespect2.
  ///
  /// In en, this message translates to:
  /// **'Ask before you help — don’t assume someone needs it.'**
  String get awRespect2;

  /// No description provided for @awRespect3.
  ///
  /// In en, this message translates to:
  /// **'Be patient and give people time to respond.'**
  String get awRespect3;

  /// No description provided for @awRespect4.
  ///
  /// In en, this message translates to:
  /// **'Keep language simple and clear; avoid labels and pity.'**
  String get awRespect4;

  /// No description provided for @awRespect5.
  ///
  /// In en, this message translates to:
  /// **'A wheelchair, cane, or guide is personal space — don’t touch it without permission.'**
  String get awRespect5;

  /// No description provided for @awCommTitle.
  ///
  /// In en, this message translates to:
  /// **'Communicating accessibly'**
  String get awCommTitle;

  /// No description provided for @awCommBody.
  ///
  /// In en, this message translates to:
  /// **'Many Deaf and hard-of-hearing Filipinos communicate through Filipino Sign Language (FSL) — a complete language with its own grammar. Captions, plain text, pictures, and sign-language video all make information reach more people. This app teaches vocabulary alongside FSL clips so signing learners are included from the start.'**
  String get awCommBody;

  /// No description provided for @awHelpsTitle.
  ///
  /// In en, this message translates to:
  /// **'How FlashLearn PWD helps'**
  String get awHelpsTitle;

  /// No description provided for @awHelps1.
  ///
  /// In en, this message translates to:
  /// **'High-contrast and dyslexia-friendly themes for easier reading.'**
  String get awHelps1;

  /// No description provided for @awHelps2.
  ///
  /// In en, this message translates to:
  /// **'Adjustable font size, reduced motion, and text-to-speech.'**
  String get awHelps2;

  /// No description provided for @awHelps3.
  ///
  /// In en, this message translates to:
  /// **'Filipino Sign Language videos in flashcards and stories.'**
  String get awHelps3;

  /// No description provided for @awHelps4.
  ///
  /// In en, this message translates to:
  /// **'Hands-free gaze control — move your head or blink to select.'**
  String get awHelps4;

  /// No description provided for @wrOverview.
  ///
  /// In en, this message translates to:
  /// **'Weekly Overview'**
  String get wrOverview;

  /// No description provided for @wrDailyTime.
  ///
  /// In en, this message translates to:
  /// **'Daily Study Time'**
  String get wrDailyTime;

  /// No description provided for @wrCategoryMastery.
  ///
  /// In en, this message translates to:
  /// **'Category Mastery'**
  String get wrCategoryMastery;

  /// No description provided for @wrRecentScores.
  ///
  /// In en, this message translates to:
  /// **'Recent Game Scores'**
  String get wrRecentScores;

  /// No description provided for @wrInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights & Recommendations'**
  String get wrInsights;

  /// No description provided for @wrTrend.
  ///
  /// In en, this message translates to:
  /// **'Week-over-Week Trend'**
  String get wrTrend;

  /// No description provided for @wrFamilyTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Progress Report'**
  String get wrFamilyTitle;

  /// No description provided for @wrGeneratedOn.
  ///
  /// In en, this message translates to:
  /// **'Generated on {date}'**
  String wrGeneratedOn(String date);

  /// No description provided for @wrWeeklyTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Progress Report'**
  String get wrWeeklyTitle;

  /// No description provided for @wrDayStreak.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get wrDayStreak;

  /// No description provided for @wrFooter.
  ///
  /// In en, this message translates to:
  /// **'Generated by FlashLearn PWD - Page {page} of {pages}'**
  String wrFooter(int page, int pages);

  /// No description provided for @wrTotalStars.
  ///
  /// In en, this message translates to:
  /// **'Total Stars'**
  String get wrTotalStars;

  /// No description provided for @wrWordsLearned.
  ///
  /// In en, this message translates to:
  /// **'Words Learned'**
  String get wrWordsLearned;

  /// No description provided for @wrGamesPlayed.
  ///
  /// In en, this message translates to:
  /// **'Games Played'**
  String get wrGamesPlayed;

  /// No description provided for @wrStudyTime.
  ///
  /// In en, this message translates to:
  /// **'Study Time'**
  String get wrStudyTime;

  /// No description provided for @wrStars.
  ///
  /// In en, this message translates to:
  /// **'{count} stars'**
  String wrStars(int count);

  /// No description provided for @wrWords.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wrWords(int count);

  /// No description provided for @wrGames.
  ///
  /// In en, this message translates to:
  /// **'{count} games'**
  String wrGames(int count);

  /// No description provided for @wrMinutesThisWeek.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m this week'**
  String wrMinutesThisWeek(int minutes);

  /// No description provided for @wrAccuracyPct.
  ///
  /// In en, this message translates to:
  /// **'{percent}% accuracy'**
  String wrAccuracyPct(String percent);

  /// No description provided for @wrDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get wrDate;

  /// No description provided for @wrMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get wrMinutes;

  /// No description provided for @wrVisual.
  ///
  /// In en, this message translates to:
  /// **'Visual'**
  String get wrVisual;

  /// No description provided for @wrCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get wrCategory;

  /// No description provided for @wrProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get wrProgress;

  /// No description provided for @wrMasteryBar.
  ///
  /// In en, this message translates to:
  /// **'Mastery Bar'**
  String get wrMasteryBar;

  /// No description provided for @wrNoScores.
  ///
  /// In en, this message translates to:
  /// **'No recent game scores this week.'**
  String get wrNoScores;

  /// No description provided for @wrGame.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get wrGame;

  /// No description provided for @wrScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get wrScore;

  /// No description provided for @wrStarsCol.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get wrStarsCol;

  /// No description provided for @wrDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get wrDuration;

  /// No description provided for @wrStrongest.
  ///
  /// In en, this message translates to:
  /// **'Strongest area: {category}'**
  String wrStrongest(String category);

  /// No description provided for @wrStrongestSub.
  ///
  /// In en, this message translates to:
  /// **'Keep up the excellent work in this category!'**
  String get wrStrongestSub;

  /// No description provided for @wrWeakest.
  ///
  /// In en, this message translates to:
  /// **'Needs practice: {category}'**
  String wrWeakest(String category);

  /// No description provided for @wrWeakestSub.
  ///
  /// In en, this message translates to:
  /// **'Focus on this category for improvement.'**
  String get wrWeakestSub;

  /// No description provided for @wrUnexplored.
  ///
  /// In en, this message translates to:
  /// **'Not yet explored: {categories}'**
  String wrUnexplored(String categories);

  /// No description provided for @wrUnexploredSub.
  ///
  /// In en, this message translates to:
  /// **'Try introducing these categories this week.'**
  String get wrUnexploredSub;

  /// No description provided for @wrAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy: {percent}%'**
  String wrAccuracy(String percent);

  /// No description provided for @wrAccuracyHigh.
  ///
  /// In en, this message translates to:
  /// **'Outstanding accuracy! Consider increasing difficulty.'**
  String get wrAccuracyHigh;

  /// No description provided for @wrAccuracyLow.
  ///
  /// In en, this message translates to:
  /// **'Extra review sessions may help improve scores.'**
  String get wrAccuracyLow;

  /// No description provided for @wrLowSessions.
  ///
  /// In en, this message translates to:
  /// **'Low session count: {count} sessions this month'**
  String wrLowSessions(int count);

  /// No description provided for @wrLowSessionsSub.
  ///
  /// In en, this message translates to:
  /// **'Try to have at least 3-4 learning sessions per week.'**
  String get wrLowSessionsSub;

  /// No description provided for @wrMastered.
  ///
  /// In en, this message translates to:
  /// **'{count} categories mastered (>=80%)'**
  String wrMastered(int count);

  /// No description provided for @wrMasteredSub.
  ///
  /// In en, this message translates to:
  /// **'Great progress! {count} more to go.'**
  String wrMasteredSub(int count);

  /// No description provided for @wrStartLearning.
  ///
  /// In en, this message translates to:
  /// **'Start learning to see personalized insights!'**
  String get wrStartLearning;

  /// No description provided for @wrTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Study time increased compared to last week!'**
  String get wrTimeUp;

  /// No description provided for @wrTimeDown.
  ///
  /// In en, this message translates to:
  /// **'Study time decreased compared to last week.'**
  String get wrTimeDown;

  /// No description provided for @wrThisLast.
  ///
  /// In en, this message translates to:
  /// **'This week: {thisWeek}min | Last week: {lastWeek}min'**
  String wrThisLast(int thisWeek, int lastWeek);

  /// No description provided for @wrsTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly Reports'**
  String get wrsTitle;

  /// No description provided for @wrsFamily.
  ///
  /// In en, this message translates to:
  /// **'Family Report'**
  String get wrsFamily;

  /// No description provided for @wrsNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No student profiles found'**
  String get wrsNoStudents;

  /// No description provided for @wrsNoStudentsBody.
  ///
  /// In en, this message translates to:
  /// **'Create a student profile to generate reports.'**
  String get wrsNoStudentsBody;

  /// No description provided for @wrsHeading.
  ///
  /// In en, this message translates to:
  /// **'Progress Reports'**
  String get wrsHeading;

  /// No description provided for @wrsIntro.
  ///
  /// In en, this message translates to:
  /// **'Generate professional PDF reports showing weekly stats, category mastery, game scores, and personalized insights.'**
  String get wrsIntro;

  /// No description provided for @wrsSelectChild.
  ///
  /// In en, this message translates to:
  /// **'Select a child to generate report'**
  String get wrsSelectChild;

  /// No description provided for @wrsSubject.
  ///
  /// In en, this message translates to:
  /// **'Weekly Progress Report — {name}'**
  String wrsSubject(String name);

  /// No description provided for @wrsFailedGenerate.
  ///
  /// In en, this message translates to:
  /// **'Could not make the report. Please try again.'**
  String get wrsFailedGenerate;

  /// No description provided for @wrsFailedPreview.
  ///
  /// In en, this message translates to:
  /// **'Could not show the report. Please try again.'**
  String get wrsFailedPreview;

  /// No description provided for @wrsPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Preview — {name}'**
  String wrsPreviewTitle(String name);

  /// No description provided for @wrsSharePdf.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get wrsSharePdf;

  /// No description provided for @wrsNoPreview.
  ///
  /// In en, this message translates to:
  /// **'On-screen preview isn’t available on this device.'**
  String get wrsNoPreview;

  /// No description provided for @wrsNoPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'The report was generated successfully — tap below to open, save, or send it as a PDF.'**
  String get wrsNoPreviewBody;

  /// No description provided for @wrsStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String wrsStreakDays(int count);

  /// No description provided for @prTitle.
  ///
  /// In en, this message translates to:
  /// **'Student Progress Report'**
  String get prTitle;

  /// No description provided for @prWordsLearned.
  ///
  /// In en, this message translates to:
  /// **'Words Learned'**
  String get prWordsLearned;

  /// No description provided for @prOfTotal.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String prOfTotal(int total);

  /// No description provided for @prStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String prStreakDays(int count);

  /// No description provided for @prCategoryBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get prCategoryBreakdown;

  /// No description provided for @prLearningAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Learning Analysis'**
  String get prLearningAnalysis;

  /// No description provided for @prTotalAttempts.
  ///
  /// In en, this message translates to:
  /// **'Total Attempts'**
  String get prTotalAttempts;

  /// No description provided for @prStruggling.
  ///
  /// In en, this message translates to:
  /// **'Struggling Words'**
  String get prStruggling;

  /// No description provided for @prOverallAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Overall Accuracy'**
  String get prOverallAccuracy;

  /// No description provided for @prNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get prNotAvailable;

  /// No description provided for @prNeedPractice.
  ///
  /// In en, this message translates to:
  /// **'Words Needing Practice'**
  String get prNeedPractice;

  /// No description provided for @prWordEn.
  ///
  /// In en, this message translates to:
  /// **'Word (EN)'**
  String get prWordEn;

  /// No description provided for @prWordFil.
  ///
  /// In en, this message translates to:
  /// **'Word (FIL)'**
  String get prWordFil;

  /// No description provided for @prAttempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get prAttempts;

  /// No description provided for @prRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Game Activity'**
  String get prRecentActivity;

  /// No description provided for @prPercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get prPercentage;

  /// No description provided for @prTagline.
  ///
  /// In en, this message translates to:
  /// **'Interactive Vocabulary Learning'**
  String get prTagline;

  /// No description provided for @prFooter.
  ///
  /// In en, this message translates to:
  /// **'FlashLearn PWD - Thesis Capstone Project'**
  String get prFooter;

  /// No description provided for @prPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}'**
  String prPageOf(int page, int pages);

  /// No description provided for @prFocusOn.
  ///
  /// In en, this message translates to:
  /// **'Focus on {category}'**
  String prFocusOn(String category);

  /// No description provided for @prFocusOnBody.
  ///
  /// In en, this message translates to:
  /// **'This category has the lowest progress at {percent}%. Encourage the student to use flashcards and play games in this category.'**
  String prFocusOnBody(int percent);

  /// No description provided for @prSmartReview.
  ///
  /// In en, this message translates to:
  /// **'Use Smart Review'**
  String get prSmartReview;

  /// No description provided for @prSmartReviewBody.
  ///
  /// In en, this message translates to:
  /// **'There are {count} words the student struggles with. The Smart Review feature uses spaced repetition to prioritize them.'**
  String prSmartReviewBody(int count);

  /// No description provided for @prHabit.
  ///
  /// In en, this message translates to:
  /// **'Build Daily Habit'**
  String get prHabit;

  /// No description provided for @prHabitBody.
  ///
  /// In en, this message translates to:
  /// **'The current streak is {count, plural, =1{1 day} other{{count} days}}. Encourage daily practice to build consistency.'**
  String prHabitBody(int count);

  /// No description provided for @prConsistency.
  ///
  /// In en, this message translates to:
  /// **'Great Consistency!'**
  String get prConsistency;

  /// No description provided for @prConsistencyBody.
  ///
  /// In en, this message translates to:
  /// **'The student has a {count}-day streak. Positive reinforcement will help maintain this habit.'**
  String prConsistencyBody(int count);

  /// No description provided for @prHarder.
  ///
  /// In en, this message translates to:
  /// **'Try Harder Difficulty'**
  String get prHarder;

  /// No description provided for @prHarderBody.
  ///
  /// In en, this message translates to:
  /// **'{category} progress is at {percent}%. Consider increasing the game difficulty for extra challenge.'**
  String prHarderBody(String category, int percent);

  /// No description provided for @erLast7.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get erLast7;

  /// No description provided for @erLast30.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get erLast30;

  /// No description provided for @erLast90.
  ///
  /// In en, this message translates to:
  /// **'Last 90 days'**
  String get erLast90;

  /// No description provided for @erPickClass.
  ///
  /// In en, this message translates to:
  /// **'Pick a classroom first.'**
  String get erPickClass;

  /// No description provided for @erShareText.
  ///
  /// In en, this message translates to:
  /// **'Progress report — {classroom} ({range})'**
  String erShareText(String classroom, String range);

  /// No description provided for @erShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Progress report — {classroom}'**
  String erShareSubject(String classroom);

  /// No description provided for @erFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Please try again.'**
  String get erFailed;

  /// No description provided for @erTitleShort.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get erTitleShort;

  /// No description provided for @erSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in as a teacher to export reports.'**
  String get erSignIn;

  /// No description provided for @erTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Progress Report'**
  String get erTitle;

  /// No description provided for @erLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load classrooms. Please try again.'**
  String get erLoadFailed;

  /// No description provided for @erNoClasses.
  ///
  /// In en, this message translates to:
  /// **'You don’t have any classrooms yet. Create a classroom first to export progress reports.'**
  String get erNoClasses;

  /// No description provided for @erHeading.
  ///
  /// In en, this message translates to:
  /// **'Progress Report (CSV)'**
  String get erHeading;

  /// No description provided for @erIntro.
  ///
  /// In en, this message translates to:
  /// **'Generate a spreadsheet of every student’s progress in the selected window. Use it for IEPs, parent updates, or classroom records.'**
  String get erIntro;

  /// No description provided for @erClassroom.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get erClassroom;

  /// No description provided for @erDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get erDateRange;

  /// No description provided for @erBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building CSV…'**
  String get erBuilding;

  /// No description provided for @erExport.
  ///
  /// In en, this message translates to:
  /// **'Export & share CSV'**
  String get erExport;

  /// No description provided for @erShareNote.
  ///
  /// In en, this message translates to:
  /// **'The file will open the device share sheet so you can email it, save it to Drive, or upload it to your school portal.'**
  String get erShareNote;

  /// No description provided for @cePdfTitle.
  ///
  /// In en, this message translates to:
  /// **'CERTIFICATE OF ACHIEVEMENT'**
  String get cePdfTitle;

  /// No description provided for @cePdfPresented.
  ///
  /// In en, this message translates to:
  /// **'This certificate is proudly presented to'**
  String get cePdfPresented;

  /// No description provided for @cePdfFor.
  ///
  /// In en, this message translates to:
  /// **'For {achievement}'**
  String cePdfFor(String achievement);

  /// No description provided for @cePdfDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String cePdfDate(String date);

  /// No description provided for @ceTypeAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment Completion'**
  String get ceTypeAssessment;

  /// No description provided for @ceTypeStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak Milestone'**
  String get ceTypeStreak;

  /// No description provided for @ceTypeOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall Progress'**
  String get ceTypeOverall;

  /// No description provided for @ceCatTitle.
  ///
  /// In en, this message translates to:
  /// **'{category} Category Mastery'**
  String ceCatTitle(String category);

  /// No description provided for @ceCatDetail.
  ///
  /// In en, this message translates to:
  /// **'Successfully learned {learned} out of {total} words in the {category} vocabulary category.'**
  String ceCatDetail(int learned, int total, String category);

  /// No description provided for @ceStreakTitle.
  ///
  /// In en, this message translates to:
  /// **'{days}-Day Learning Streak'**
  String ceStreakTitle(int days);

  /// No description provided for @ceStreakDetail.
  ///
  /// In en, this message translates to:
  /// **'Demonstrated outstanding dedication by maintaining a {days}-day consecutive study streak.'**
  String ceStreakDetail(int days);

  /// No description provided for @ceOverallDetail.
  ///
  /// In en, this message translates to:
  /// **'Learned {words} words, earned {stars} stars, and maintained a {days}-day streak.'**
  String ceOverallDetail(int words, int stars, int days);

  /// No description provided for @wsTracing.
  ///
  /// In en, this message translates to:
  /// **'Word Tracing'**
  String get wsTracing;

  /// No description provided for @wsMatching.
  ///
  /// In en, this message translates to:
  /// **'Picture Matching'**
  String get wsMatching;

  /// No description provided for @wsMatchingHeader.
  ///
  /// In en, this message translates to:
  /// **'Picture/Word Matching'**
  String get wsMatchingHeader;

  /// No description provided for @wsFill.
  ///
  /// In en, this message translates to:
  /// **'Fill in the Blank'**
  String get wsFill;

  /// No description provided for @wsSearch.
  ///
  /// In en, this message translates to:
  /// **'Word Search'**
  String get wsSearch;

  /// No description provided for @wsTracingDesc.
  ///
  /// In en, this message translates to:
  /// **'Trace English and Filipino words with dotted letters'**
  String get wsTracingDesc;

  /// No description provided for @wsMatchingDesc.
  ///
  /// In en, this message translates to:
  /// **'Draw lines to match words with their translations'**
  String get wsMatchingDesc;

  /// No description provided for @wsFillDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete sentences with the correct vocabulary word'**
  String get wsFillDesc;

  /// No description provided for @wsSearchDesc.
  ///
  /// In en, this message translates to:
  /// **'Find hidden vocabulary words in a letter grid'**
  String get wsSearchDesc;

  /// No description provided for @wsTraceInstr.
  ///
  /// In en, this message translates to:
  /// **'Trace each word carefully. Practice writing both English and Filipino!'**
  String get wsTraceInstr;

  /// No description provided for @wsEnglishColon.
  ///
  /// In en, this message translates to:
  /// **'English: '**
  String get wsEnglishColon;

  /// No description provided for @wsFilipinoColon.
  ///
  /// In en, this message translates to:
  /// **'Filipino: '**
  String get wsFilipinoColon;

  /// No description provided for @wsMatchInstr.
  ///
  /// In en, this message translates to:
  /// **'Draw a line from each English word on the left to its Filipino translation on the right.'**
  String get wsMatchInstr;

  /// No description provided for @wsEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get wsEnglish;

  /// No description provided for @wsFilipino.
  ///
  /// In en, this message translates to:
  /// **'Filipino'**
  String get wsFilipino;

  /// No description provided for @wsAnswers.
  ///
  /// In en, this message translates to:
  /// **'Answers: _______________________________________________'**
  String get wsAnswers;

  /// No description provided for @wsFillInstr.
  ///
  /// In en, this message translates to:
  /// **'Fill in each blank with the correct word from the word bank below.'**
  String get wsFillInstr;

  /// No description provided for @wsWordBank.
  ///
  /// In en, this message translates to:
  /// **'Word Bank:'**
  String get wsWordBank;

  /// No description provided for @wsSearchInstr.
  ///
  /// In en, this message translates to:
  /// **'Find and circle all the hidden words in the grid below!'**
  String get wsSearchInstr;

  /// No description provided for @wsMeta.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}  •  Difficulty: {difficulty}'**
  String wsMeta(String category, String difficulty);

  /// No description provided for @wsName.
  ///
  /// In en, this message translates to:
  /// **'Name: ____________________'**
  String get wsName;

  /// No description provided for @wsDate.
  ///
  /// In en, this message translates to:
  /// **'Date: ____________________'**
  String get wsDate;

  /// No description provided for @wsFooter.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pages}  •  Generated by FlashLearn PWD'**
  String wsFooter(int page, int pages);

  /// No description provided for @wscTitle.
  ///
  /// In en, this message translates to:
  /// **'Printable Worksheets'**
  String get wscTitle;

  /// No description provided for @wscIntro.
  ///
  /// In en, this message translates to:
  /// **'Create practice worksheets your students can print and use offline!'**
  String get wscIntro;

  /// No description provided for @wscType.
  ///
  /// In en, this message translates to:
  /// **'Worksheet Type'**
  String get wscType;

  /// No description provided for @wscGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get wscGenerating;

  /// No description provided for @wscPreviewPrint.
  ///
  /// In en, this message translates to:
  /// **'Preview & Print'**
  String get wscPreviewPrint;

  /// No description provided for @wscWords.
  ///
  /// In en, this message translates to:
  /// **'{count} words'**
  String wscWords(int count);

  /// No description provided for @pfTitle.
  ///
  /// In en, this message translates to:
  /// **'{name}’s Learning Portfolio'**
  String pfTitle(String name);

  /// No description provided for @pfOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get pfOverview;

  /// No description provided for @pfDayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day Streak'**
  String get pfDayStreak;

  /// No description provided for @pfItems.
  ///
  /// In en, this message translates to:
  /// **'Portfolio Items'**
  String get pfItems;

  /// No description provided for @pfPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned Highlights'**
  String get pfPinned;

  /// No description provided for @pfAllItems.
  ///
  /// In en, this message translates to:
  /// **'All Portfolio Items'**
  String get pfAllItems;

  /// No description provided for @pfType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get pfType;

  /// No description provided for @pfItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get pfItemTitle;

  /// No description provided for @pfDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get pfDescription;

  /// No description provided for @pfSummaryByType.
  ///
  /// In en, this message translates to:
  /// **'Summary by Type'**
  String get pfSummaryByType;

  /// No description provided for @sdDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get sdDetails;

  /// No description provided for @sdEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get sdEarned;

  /// No description provided for @sdYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get sdYes;

  /// No description provided for @sdNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get sdNo;

  /// No description provided for @sdPersonalNote.
  ///
  /// In en, this message translates to:
  /// **'Personal Note'**
  String get sdPersonalNote;

  /// No description provided for @bpSemantics.
  ///
  /// In en, this message translates to:
  /// **'Pop the bubbles. This is just for fun — there is no score.'**
  String get bpSemantics;

  /// No description provided for @crbReconnected.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync reconnected.'**
  String get crbReconnected;

  /// No description provided for @lwDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get lwDismiss;

  /// No description provided for @egSemantics.
  ///
  /// In en, this message translates to:
  /// **'See example photos of {word}'**
  String egSemantics(String word);

  /// No description provided for @smSemantics.
  ///
  /// In en, this message translates to:
  /// **'Show me {word}'**
  String smSemantics(String word);

  /// No description provided for @siReRecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get siReRecord;

  /// No description provided for @mqPlayerN.
  ///
  /// In en, this message translates to:
  /// **'Player {number}'**
  String mqPlayerN(int number);

  /// No description provided for @mqRematch.
  ///
  /// In en, this message translates to:
  /// **'Rematch!'**
  String get mqRematch;

  /// No description provided for @mpRematch.
  ///
  /// In en, this message translates to:
  /// **'Rematch'**
  String get mpRematch;

  /// No description provided for @gzTarget.
  ///
  /// In en, this message translates to:
  /// **'Gaze target: {label}'**
  String gzTarget(String label);

  /// No description provided for @frRequests.
  ///
  /// In en, this message translates to:
  /// **'Friend requests'**
  String get frRequests;

  /// No description provided for @alMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get alMarkRead;

  /// No description provided for @exSaved.
  ///
  /// In en, this message translates to:
  /// **'Experiment settings saved!'**
  String get exSaved;

  /// No description provided for @exGroup.
  ///
  /// In en, this message translates to:
  /// **'{label} group'**
  String exGroup(String label);

  /// No description provided for @alDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{label}”?'**
  String alDeleteTitle(String label);

  /// No description provided for @alLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get alLabel;

  /// No description provided for @alEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get alEnabled;

  /// No description provided for @tlEnforce.
  ///
  /// In en, this message translates to:
  /// **'Enforce a daily limit'**
  String get tlEnforce;

  /// No description provided for @tlSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get tlSaved;

  /// No description provided for @pcSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save parental controls. Please try again.'**
  String get pcSaveFailed;

  /// No description provided for @tuVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get tuVerify;

  /// No description provided for @tuSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get tuSwitchAccount;

  /// No description provided for @woAvgPer.
  ///
  /// In en, this message translates to:
  /// **'Avg/{noun}'**
  String woAvgPer(String noun);

  /// No description provided for @aaSelectProfile.
  ///
  /// In en, this message translates to:
  /// **'Select a profile to view adaptive analytics.'**
  String get aaSelectProfile;

  /// No description provided for @daSelectProfile.
  ///
  /// In en, this message translates to:
  /// **'Select a profile to view detailed analytics.'**
  String get daSelectProfile;

  /// No description provided for @lcTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard Settings'**
  String get lcTitle;

  /// No description provided for @lcVisibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get lcVisibility;

  /// No description provided for @lcShow.
  ///
  /// In en, this message translates to:
  /// **'Show leaderboard to members'**
  String get lcShow;

  /// No description provided for @lcRankBy.
  ///
  /// In en, this message translates to:
  /// **'Rank by'**
  String get lcRankBy;

  /// No description provided for @lcPeriod.
  ///
  /// In en, this message translates to:
  /// **'Time period'**
  String get lcPeriod;

  /// No description provided for @lcNewSeason.
  ///
  /// In en, this message translates to:
  /// **'Start new season'**
  String get lcNewSeason;

  /// No description provided for @lcClearSeason.
  ///
  /// In en, this message translates to:
  /// **'Clear season'**
  String get lcClearSeason;

  /// No description provided for @lcHide.
  ///
  /// In en, this message translates to:
  /// **'Hide members'**
  String get lcHide;

  /// No description provided for @lcNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members have joined yet.'**
  String get lcNoMembers;

  /// No description provided for @ptAccuracyTrend.
  ///
  /// In en, this message translates to:
  /// **'Accuracy Trend 📊'**
  String get ptAccuracyTrend;

  /// No description provided for @ptpTitle.
  ///
  /// In en, this message translates to:
  /// **'Customize Progress'**
  String get ptpTitle;

  /// No description provided for @ptpIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick a look and a layout for the Progress page'**
  String get ptpIntro;

  /// No description provided for @ptpTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get ptpTheme;

  /// No description provided for @ptpLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get ptpLayout;

  /// No description provided for @sqQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz: {title}'**
  String sqQuizTitle(String title);

  /// No description provided for @sqEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get sqEnglish;

  /// No description provided for @sqTagalog.
  ///
  /// In en, this message translates to:
  /// **'Tagalog'**
  String get sqTagalog;

  /// No description provided for @srPrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get srPrevPage;

  /// No description provided for @scmpKeyMetrics.
  ///
  /// In en, this message translates to:
  /// **'Key Metrics'**
  String get scmpKeyMetrics;

  /// No description provided for @taAvgAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Avg Accuracy'**
  String get taAvgAccuracy;

  /// No description provided for @nfIllustration.
  ///
  /// In en, this message translates to:
  /// **'Lost page illustration'**
  String get nfIllustration;

  /// No description provided for @nfTitle.
  ///
  /// In en, this message translates to:
  /// **'Oops! Page not found'**
  String get nfTitle;

  /// No description provided for @nfBody.
  ///
  /// In en, this message translates to:
  /// **'It looks like this page has wandered off.\nLet’s get you back on track!'**
  String get nfBody;

  /// No description provided for @nfGoHomeSem.
  ///
  /// In en, this message translates to:
  /// **'Go back to home screen'**
  String get nfGoHomeSem;

  /// No description provided for @nfGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get nfGoHome;

  /// No description provided for @nfGoBackSem.
  ///
  /// In en, this message translates to:
  /// **'Go back to previous page'**
  String get nfGoBackSem;

  /// No description provided for @ciOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get ciOnline;

  /// No description provided for @ciOffline.
  ///
  /// In en, this message translates to:
  /// **'No internet — your work is saved locally'**
  String get ciOffline;

  /// No description provided for @spdCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get spdCreated;

  /// No description provided for @ssSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get ssSyncing;

  /// No description provided for @ssSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced!'**
  String get ssSynced;

  /// No description provided for @splashLogo.
  ///
  /// In en, this message translates to:
  /// **'FlashLearn logo'**
  String get splashLogo;

  /// No description provided for @ctDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get ctDark;

  /// No description provided for @ctLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get ctLight;

  /// No description provided for @ctClassroom.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get ctClassroom;

  /// No description provided for @ctPlayful.
  ///
  /// In en, this message translates to:
  /// **'Playful'**
  String get ctPlayful;

  /// No description provided for @ctCalm.
  ///
  /// In en, this message translates to:
  /// **'Calm / Focus'**
  String get ctCalm;

  /// No description provided for @ctSeasonal.
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get ctSeasonal;

  /// No description provided for @ctHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get ctHighContrast;

  /// No description provided for @ctDyslexia.
  ///
  /// In en, this message translates to:
  /// **'Dyslexia-friendly'**
  String get ctDyslexia;

  /// No description provided for @ctDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'High-legibility dark — the classic look.'**
  String get ctDarkDesc;

  /// No description provided for @ctLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Bright and clean for well-lit rooms.'**
  String get ctLightDesc;

  /// No description provided for @ctClassroomDesc.
  ///
  /// In en, this message translates to:
  /// **'Crisp and neutral — maximum readability.'**
  String get ctClassroomDesc;

  /// No description provided for @ctPlayfulDesc.
  ///
  /// In en, this message translates to:
  /// **'Vibrant and rounded, with big emoji for kids.'**
  String get ctPlayfulDesc;

  /// No description provided for @ctCalmDesc.
  ///
  /// In en, this message translates to:
  /// **'Soft, low-stimulation, calm pacing (no animation).'**
  String get ctCalmDesc;

  /// No description provided for @ctSeasonalDesc.
  ///
  /// In en, this message translates to:
  /// **'Festive accents that follow the season.'**
  String get ctSeasonalDesc;

  /// No description provided for @ctHighContrastDesc.
  ///
  /// In en, this message translates to:
  /// **'Black/white/yellow for low vision.'**
  String get ctHighContrastDesc;

  /// No description provided for @ctDyslexiaDesc.
  ///
  /// In en, this message translates to:
  /// **'Lexend on cream, with looser spacing.'**
  String get ctDyslexiaDesc;

  /// No description provided for @ctSizeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get ctSizeNormal;

  /// No description provided for @ctSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get ctSizeLarge;

  /// No description provided for @ctSizeXl.
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get ctSizeXl;

  /// No description provided for @ctLangBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get ctLangBoth;

  /// No description provided for @ctLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get ctLeaderboard;

  /// No description provided for @ctClassWins.
  ///
  /// In en, this message translates to:
  /// **'Class wins'**
  String get ctClassWins;

  /// No description provided for @ctLeaderboardDesc.
  ///
  /// In en, this message translates to:
  /// **'Top 10 by stars, ranked.'**
  String get ctLeaderboardDesc;

  /// No description provided for @ctClassWinsDesc.
  ///
  /// In en, this message translates to:
  /// **'What the class did together, then everyone A–Z — no ranking.'**
  String get ctClassWinsDesc;

  /// No description provided for @tcWifiLost.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi disconnected — the TV can’t reach this cast. Reconnect to the same Wi-Fi to continue.'**
  String get tcWifiLost;

  /// No description provided for @tcNetChanged.
  ///
  /// In en, this message translates to:
  /// **'You’re on a different network now — the TV can’t reach this cast. Reconnect to the original Wi-Fi, or tap Restart for a new code.'**
  String get tcNetChanged;

  /// No description provided for @tcRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get tcRestart;

  /// No description provided for @tcNoWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi not detected. Connect to the same network as your TV.'**
  String get tcNoWifi;

  /// No description provided for @tcStopTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop casting?'**
  String get tcStopTitle;

  /// No description provided for @tcStopBody.
  ///
  /// In en, this message translates to:
  /// **'This ends the current cast and disconnects any TVs. You can start again anytime.'**
  String get tcStopBody;

  /// No description provided for @tcStopped.
  ///
  /// In en, this message translates to:
  /// **'Casting stopped'**
  String get tcStopped;

  /// No description provided for @tcTitle.
  ///
  /// In en, this message translates to:
  /// **'TV Cast'**
  String get tcTitle;

  /// No description provided for @tcTeacherBack.
  ///
  /// In en, this message translates to:
  /// **'Teacher is back (resume cast)'**
  String get tcTeacherBack;

  /// No description provided for @tcTeacherOut.
  ///
  /// In en, this message translates to:
  /// **'Show “Teacher is out” on TV'**
  String get tcTeacherOut;

  /// No description provided for @tcStopCasting.
  ///
  /// In en, this message translates to:
  /// **'Stop casting'**
  String get tcStopCasting;

  /// No description provided for @tcWhatToCast.
  ///
  /// In en, this message translates to:
  /// **'What to cast'**
  String get tcWhatToCast;

  /// No description provided for @tcSwitchesNow.
  ///
  /// In en, this message translates to:
  /// **'The TV switches the moment you tap.'**
  String get tcSwitchesNow;

  /// No description provided for @tcNowShowing.
  ///
  /// In en, this message translates to:
  /// **'Now showing on TV'**
  String get tcNowShowing;

  /// No description provided for @tcPacing.
  ///
  /// In en, this message translates to:
  /// **'Pacing'**
  String get tcPacing;

  /// No description provided for @tcPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get tcPlayback;

  /// No description provided for @tcStepLesson.
  ///
  /// In en, this message translates to:
  /// **'Step the lesson from here.'**
  String get tcStepLesson;

  /// No description provided for @tcReplayAudio.
  ///
  /// In en, this message translates to:
  /// **'Replay audio'**
  String get tcReplayAudio;

  /// No description provided for @tcDisplayStyle.
  ///
  /// In en, this message translates to:
  /// **'TV display style'**
  String get tcDisplayStyle;

  /// No description provided for @tcDisplayStyleSub.
  ///
  /// In en, this message translates to:
  /// **'How the lesson looks on the big screen.'**
  String get tcDisplayStyleSub;

  /// No description provided for @tcLessonTimer.
  ///
  /// In en, this message translates to:
  /// **'Lesson timer'**
  String get tcLessonTimer;

  /// No description provided for @tcReadability.
  ///
  /// In en, this message translates to:
  /// **'Readability on TV'**
  String get tcReadability;

  /// No description provided for @tcShowOnTv.
  ///
  /// In en, this message translates to:
  /// **'Show on TV'**
  String get tcShowOnTv;

  /// No description provided for @tcShowOnTvSub.
  ///
  /// In en, this message translates to:
  /// **'Optional name shown in the corner of the TV.'**
  String get tcShowOnTvSub;

  /// No description provided for @tcAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get tcAudio;

  /// No description provided for @tcFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get tcFullscreen;

  /// No description provided for @tcTvRemote.
  ///
  /// In en, this message translates to:
  /// **'TV remote'**
  String get tcTvRemote;

  /// No description provided for @tcAnyTv.
  ///
  /// In en, this message translates to:
  /// **'Cast to any TV'**
  String get tcAnyTv;

  /// No description provided for @tcAnyTvBody.
  ///
  /// In en, this message translates to:
  /// **'Works on any TV with a web browser — Samsung, LG, Sony, Fire TV, Chromecast with Google TV, smart projectors, or any laptop plugged into HDMI. You open the link in the TV’s own browser — this is not the same as mirroring or casting your tablet, so sound comes from the TV.'**
  String get tcAnyTvBody;

  /// No description provided for @tcStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get tcStarting;

  /// No description provided for @tcStart.
  ///
  /// In en, this message translates to:
  /// **'Start Casting'**
  String get tcStart;

  /// No description provided for @tcWaitingTv.
  ///
  /// In en, this message translates to:
  /// **'Waiting for TV to connect…'**
  String get tcWaitingTv;

  /// No description provided for @tcTeacherOutNote.
  ///
  /// In en, this message translates to:
  /// **'The TV is showing “The teacher is out”. Tap the walk icon to resume casting.'**
  String get tcTeacherOutNote;

  /// No description provided for @tcFlashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get tcFlashcards;

  /// No description provided for @tcFlashcardsSub.
  ///
  /// In en, this message translates to:
  /// **'Word, picture & photo'**
  String get tcFlashcardsSub;

  /// No description provided for @tcFsl.
  ///
  /// In en, this message translates to:
  /// **'FSL'**
  String get tcFsl;

  /// No description provided for @tcFslSub.
  ///
  /// In en, this message translates to:
  /// **'Sign-language clips'**
  String get tcFslSub;

  /// No description provided for @tcStories.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get tcStories;

  /// No description provided for @tcStoriesSub.
  ///
  /// In en, this message translates to:
  /// **'Read page by page'**
  String get tcStoriesSub;

  /// No description provided for @tcLiveActivity.
  ///
  /// In en, this message translates to:
  /// **'Live Activity'**
  String get tcLiveActivity;

  /// No description provided for @tcLiveActivitySub.
  ///
  /// In en, this message translates to:
  /// **'Quiz the whole room'**
  String get tcLiveActivitySub;

  /// No description provided for @tcProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get tcProgress;

  /// No description provided for @tcProgressSub.
  ///
  /// In en, this message translates to:
  /// **'Class wins & stars'**
  String get tcProgressSub;

  /// No description provided for @tcStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get tcStory;

  /// No description provided for @tcPickAbove.
  ///
  /// In en, this message translates to:
  /// **'Pick what to cast above. The TV will switch instantly.'**
  String get tcPickAbove;

  /// No description provided for @tcTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size on TV'**
  String get tcTextSize;

  /// No description provided for @tcTextSizeNote.
  ///
  /// In en, this message translates to:
  /// **'Makes the word, story line, sign caption and answer choices bigger — for learners reading from the back, or with low vision.'**
  String get tcTextSizeNote;

  /// No description provided for @tcLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language on TV'**
  String get tcLanguage;

  /// No description provided for @tcBothLangs.
  ///
  /// In en, this message translates to:
  /// **'The TV shows and speaks both languages.'**
  String get tcBothLangs;

  /// No description provided for @tcReadyOffline.
  ///
  /// In en, this message translates to:
  /// **'Ready to cast offline'**
  String get tcReadyOffline;

  /// No description provided for @tcPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare for casting'**
  String get tcPrepare;

  /// No description provided for @tcStopDownloading.
  ///
  /// In en, this message translates to:
  /// **'Stop downloading'**
  String get tcStopDownloading;

  /// No description provided for @tcCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get tcCheckAgain;

  /// No description provided for @tcFsOnNote.
  ///
  /// In en, this message translates to:
  /// **'The TV fills the whole screen and auto-resizes to fit any TV — Smart TV, Chromecast / Google TV, Fire TV, projector or HDMI laptop. On some TVs, press OK on the remote once to finish filling the screen.'**
  String get tcFsOnNote;

  /// No description provided for @tcFsOffNote.
  ///
  /// In en, this message translates to:
  /// **'The TV keeps the browser bars. Turn on to fill the whole screen.'**
  String get tcFsOffNote;

  /// No description provided for @tcFsOnTv.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen on TV'**
  String get tcFsOnTv;

  /// No description provided for @tcBigPicNa.
  ///
  /// In en, this message translates to:
  /// **'Works with Flashcards, FSL Videos and Stories. Pick one of those to use it — a live activity needs its answer choices on screen.'**
  String get tcBigPicNa;

  /// No description provided for @tcBigPicOn.
  ///
  /// In en, this message translates to:
  /// **'The picture, GIF or sign video fills the TV. The whole picture stays in view (never cropped) and the word stays underneath; the category badge and example sentence are hidden to make room.'**
  String get tcBigPicOn;

  /// No description provided for @tcBigPicOff.
  ///
  /// In en, this message translates to:
  /// **'The picture sits inside the card. Turn on to fill the TV with it — easier to see from the back of the room, or for a learner with low vision.'**
  String get tcBigPicOff;

  /// No description provided for @tcBigPic.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen picture & video'**
  String get tcBigPic;

  /// No description provided for @tcRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent casts'**
  String get tcRecent;

  /// No description provided for @tcClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get tcClear;

  /// No description provided for @tcClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cast history?'**
  String get tcClearTitle;

  /// No description provided for @tcClearBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the record of your past casts from this device. It does not affect any student data.'**
  String get tcClearBody;

  /// No description provided for @tcEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get tcEarlier;

  /// No description provided for @tcLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get tcLive;

  /// No description provided for @tcUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'<1 min'**
  String get tcUnderMinute;

  /// No description provided for @tcFslSigns.
  ///
  /// In en, this message translates to:
  /// **'FSL signs'**
  String get tcFslSigns;

  /// No description provided for @tcLessonCast.
  ///
  /// In en, this message translates to:
  /// **'Lesson cast'**
  String get tcLessonCast;

  /// No description provided for @tcTimerNote.
  ///
  /// In en, this message translates to:
  /// **'Show a countdown in the corner of the TV — for transitions, quiet reading, or “five more minutes”. The lesson keeps playing underneath it.'**
  String get tcTimerNote;

  /// No description provided for @tcResumeTimer.
  ///
  /// In en, this message translates to:
  /// **'Resume timer'**
  String get tcResumeTimer;

  /// No description provided for @tcPauseTimer.
  ///
  /// In en, this message translates to:
  /// **'Pause timer'**
  String get tcPauseTimer;

  /// No description provided for @tcClearTimer.
  ///
  /// In en, this message translates to:
  /// **'Clear timer'**
  String get tcClearTimer;

  /// No description provided for @tcTimesUpNote.
  ///
  /// In en, this message translates to:
  /// **'The TV is showing “Time’s up!”. Clear it, or start another.'**
  String get tcTimesUpNote;

  /// No description provided for @tcTimerShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing on the TV, over the lesson.'**
  String get tcTimerShowing;

  /// No description provided for @tcRemoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Control from the TV remote'**
  String get tcRemoteLabel;

  /// No description provided for @tcRemoteOn.
  ///
  /// In en, this message translates to:
  /// **'Press ◀ or ▶ on the TV remote to move between cards, signs or story pages, and play/pause to hold. Handy when you’re at the board and the tablet is on your desk. (OK still just turns on the TV’s sound.)'**
  String get tcRemoteOn;

  /// No description provided for @tcRemoteOff.
  ///
  /// In en, this message translates to:
  /// **'The TV remote can’t change the lesson. Turn on if you want to step through from the board — or leave off for a screen left unattended.'**
  String get tcRemoteOff;

  /// No description provided for @tcTrouble.
  ///
  /// In en, this message translates to:
  /// **'Having trouble?'**
  String get tcTrouble;

  /// No description provided for @tcTipSameWifi.
  ///
  /// In en, this message translates to:
  /// **'Both phone and TV must be on the SAME Wi-Fi network.'**
  String get tcTipSameWifi;

  /// No description provided for @tcTipApIsolation.
  ///
  /// In en, this message translates to:
  /// **'If you’re on a school or guest Wi-Fi, “AP isolation” may block phone-to-TV traffic. Try a regular home network.'**
  String get tcTipApIsolation;

  /// No description provided for @tcTipSamsung.
  ///
  /// In en, this message translates to:
  /// **'Samsung TV: open the “Internet” app, type the URL.'**
  String get tcTipSamsung;

  /// No description provided for @tcTipLg.
  ///
  /// In en, this message translates to:
  /// **'LG TV: open “Web Browser” from the home dashboard.'**
  String get tcTipLg;

  /// No description provided for @tcTipFire.
  ///
  /// In en, this message translates to:
  /// **'Fire TV: install Silk Browser (free), then open URL.'**
  String get tcTipFire;

  /// No description provided for @tcTipChromecast.
  ///
  /// In en, this message translates to:
  /// **'Chromecast with Google TV: open Chrome from the apps list, type the URL.'**
  String get tcTipChromecast;

  /// No description provided for @tcTipApple.
  ///
  /// In en, this message translates to:
  /// **'Apple TV: AirPlay-mirror a laptop browser showing the URL.'**
  String get tcTipApple;

  /// No description provided for @tcTipFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Not filling the whole TV? Make sure “Fullscreen on TV” is on above. On some TVs (e.g. Chromecast / Google TV) press OK on the remote once to finish filling the screen.'**
  String get tcTipFullscreen;

  /// No description provided for @tcTipLeave.
  ///
  /// In en, this message translates to:
  /// **'You can leave this screen — the cast keeps running. A “Casting to TV” bar stays at the bottom of the app so you can pause or skip from anywhere, and tapping it brings you back here.'**
  String get tcTipLeave;

  /// No description provided for @tcTipPrivate.
  ///
  /// In en, this message translates to:
  /// **'Only TVs that open your exact cast link (it ends in your cast code) can see the lesson. Starting a new cast makes a new code and retires the old link.'**
  String get tcTipPrivate;

  /// No description provided for @tcTipQuiet.
  ///
  /// In en, this message translates to:
  /// **'Too quiet? The app already speaks at maximum — raise the TV’s volume (or the phone’s, if sound plays from the phone).'**
  String get tcTipQuiet;

  /// No description provided for @tcNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ms. Cruz — Grade 2 (optional)'**
  String get tcNameHint;

  /// No description provided for @tcAutoAdvance.
  ///
  /// In en, this message translates to:
  /// **'Auto-advance'**
  String get tcAutoAdvance;

  /// No description provided for @tcTapOnlyOn.
  ///
  /// In en, this message translates to:
  /// **'The TV shows the emoji; use the Flip button to reveal the real photo (and flip back). Works on any TV.'**
  String get tcTapOnlyOn;

  /// No description provided for @tcTapOnlyOff.
  ///
  /// In en, this message translates to:
  /// **'The TV shows the emoji only — the photo is hidden.'**
  String get tcTapOnlyOff;

  /// No description provided for @tcTapOnly.
  ///
  /// In en, this message translates to:
  /// **'Tap Only'**
  String get tcTapOnly;

  /// No description provided for @tcShowEmoji.
  ///
  /// In en, this message translates to:
  /// **'Show emoji'**
  String get tcShowEmoji;

  /// No description provided for @tcFlipPhoto.
  ///
  /// In en, this message translates to:
  /// **'Flip to photo'**
  String get tcFlipPhoto;

  /// No description provided for @tcPhotoShowing.
  ///
  /// In en, this message translates to:
  /// **'The TV is showing the real photo. Tap to flip back to the emoji.'**
  String get tcPhotoShowing;

  /// No description provided for @tcHideClip.
  ///
  /// In en, this message translates to:
  /// **'Hide clip'**
  String get tcHideClip;

  /// No description provided for @tcShowMe.
  ///
  /// In en, this message translates to:
  /// **'Show Me'**
  String get tcShowMe;

  /// No description provided for @tcClipPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing the clip on the TV. Tap to go back to the card.'**
  String get tcClipPlaying;

  /// No description provided for @tcFlipAnim.
  ///
  /// In en, this message translates to:
  /// **'Tap to Flip Animation (Cartoon ↔ Picture)'**
  String get tcFlipAnim;

  /// No description provided for @tcPictureShowing.
  ///
  /// In en, this message translates to:
  /// **'The TV is showing the real picture. Tap to flip back to the cartoon.'**
  String get tcPictureShowing;

  /// No description provided for @tcCartoonShowing.
  ///
  /// In en, this message translates to:
  /// **'The TV is showing the cartoon. Tap to flip to the real picture on the TV.'**
  String get tcCartoonShowing;

  /// No description provided for @tcHideFsl.
  ///
  /// In en, this message translates to:
  /// **'Hide FSL'**
  String get tcHideFsl;

  /// No description provided for @tcWatchFsl.
  ///
  /// In en, this message translates to:
  /// **'Watch in FSL'**
  String get tcWatchFsl;

  /// No description provided for @tcFslPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing the sign-language video on the TV. Tap to go back to the story.'**
  String get tcFslPlaying;

  /// No description provided for @tcReadyToPlay.
  ///
  /// In en, this message translates to:
  /// **'Ready to play'**
  String get tcReadyToPlay;

  /// No description provided for @tcPreparingVideo.
  ///
  /// In en, this message translates to:
  /// **'Preparing video…'**
  String get tcPreparingVideo;

  /// No description provided for @tcTvSpeaks.
  ///
  /// In en, this message translates to:
  /// **'The TV speaks each word and story page (English + Filipino).'**
  String get tcTvSpeaks;

  /// No description provided for @tcPhoneReads.
  ///
  /// In en, this message translates to:
  /// **'This phone reads each word / story page aloud.'**
  String get tcPhoneReads;

  /// No description provided for @tcTurnOnTts.
  ///
  /// In en, this message translates to:
  /// **'Turn on Text-to-Speech in Settings to hear this.'**
  String get tcTurnOnTts;

  /// No description provided for @tcSpeakWords.
  ///
  /// In en, this message translates to:
  /// **'Speak words & narrate'**
  String get tcSpeakWords;

  /// No description provided for @tcPlaySoundOn.
  ///
  /// In en, this message translates to:
  /// **'Play sound on'**
  String get tcPlaySoundOn;

  /// No description provided for @tcThisPhone.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get tcThisPhone;

  /// No description provided for @tcPhoneSound.
  ///
  /// In en, this message translates to:
  /// **'Plays from this phone (or a phone-connected speaker).'**
  String get tcPhoneSound;

  /// No description provided for @tcTvVolume.
  ///
  /// In en, this message translates to:
  /// **'Words play at full volume on the TV — raise the TV’s own volume so every student, including those who need it louder, can hear clearly.'**
  String get tcTvVolume;

  /// No description provided for @tcPhoneVolume.
  ///
  /// In en, this message translates to:
  /// **'Words play at full volume — use this phone’s volume buttons to make them louder.'**
  String get tcPhoneVolume;

  /// No description provided for @tcVideoSound.
  ///
  /// In en, this message translates to:
  /// **'Play TV video sound'**
  String get tcVideoSound;

  /// No description provided for @tcVideoSoundNote.
  ///
  /// In en, this message translates to:
  /// **'Off by default so signs stay muted (Deaf-friendly). Turn on for signs that include a spoken voiceover. May not work on older TVs.'**
  String get tcVideoSoundNote;

  /// No description provided for @tcWaitingATv.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a TV to connect…'**
  String get tcWaitingATv;

  /// No description provided for @tcTvPlaying.
  ///
  /// In en, this message translates to:
  /// **'The TV is playing the sound.'**
  String get tcTvPlaying;

  /// No description provided for @tcPressOk.
  ///
  /// In en, this message translates to:
  /// **'Press OK on the TV remote once to turn on its sound.'**
  String get tcPressOk;

  /// No description provided for @tcTvCantSpeak.
  ///
  /// In en, this message translates to:
  /// **'This TV can’t speak words. Tap “This phone” to hear narration here instead.'**
  String get tcTvCantSpeak;

  /// No description provided for @tcTvGettingReady.
  ///
  /// In en, this message translates to:
  /// **'Getting the TV ready… if it stays silent, press OK on the TV remote once.'**
  String get tcTvGettingReady;

  /// No description provided for @tcLoadingSigns.
  ///
  /// In en, this message translates to:
  /// **'Loading signs…'**
  String get tcLoadingSigns;

  /// No description provided for @tcNoFsl.
  ///
  /// In en, this message translates to:
  /// **'No FSL videos in this category yet.'**
  String get tcNoFsl;

  /// No description provided for @tcTapSign.
  ///
  /// In en, this message translates to:
  /// **'Tap a sign to show it now'**
  String get tcTapSign;

  /// No description provided for @tcPickCategory.
  ///
  /// In en, this message translates to:
  /// **'Pick a category to start.'**
  String get tcPickCategory;

  /// No description provided for @tcNoWords.
  ///
  /// In en, this message translates to:
  /// **'No words in this category.'**
  String get tcNoWords;

  /// No description provided for @tcPickStory.
  ///
  /// In en, this message translates to:
  /// **'Pick a story.'**
  String get tcPickStory;

  /// No description provided for @tcFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished — the TV is showing “The End”. Back re-reads the last page.'**
  String get tcFinished;

  /// No description provided for @tcNoLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard — no student data yet.'**
  String get tcNoLeaderboard;

  /// No description provided for @tcLiveWaiting.
  ///
  /// In en, this message translates to:
  /// **'Live activity — waiting for a question.'**
  String get tcLiveWaiting;

  /// No description provided for @tcNothingCast.
  ///
  /// In en, this message translates to:
  /// **'Nothing is being cast.'**
  String get tcNothingCast;

  /// No description provided for @tcTimesUp.
  ///
  /// In en, this message translates to:
  /// **'Time’s up'**
  String get tcTimesUp;

  /// No description provided for @tcStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the cast. Please try again.'**
  String get tcStartFailed;

  /// No description provided for @tcReplayPage.
  ///
  /// In en, this message translates to:
  /// **'Hear the current page again on this phone.'**
  String get tcReplayPage;

  /// No description provided for @tcReplayWord.
  ///
  /// In en, this message translates to:
  /// **'Hear the current word again on this phone.'**
  String get tcReplayWord;

  /// No description provided for @tcViewers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 viewer connected} other{{count} viewers connected}}'**
  String tcViewers(int count);

  /// No description provided for @tcOneLang.
  ///
  /// In en, this message translates to:
  /// **'The TV shows and speaks {language} only — the other language is hidden, not removed, so you can switch back mid-lesson.'**
  String tcOneLang(String language);

  /// No description provided for @tcDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {done} of {total}'**
  String tcDownloading(int done, int total);

  /// No description provided for @tcDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download every sign, clip and picture in {target} now, so the TV never waits mid-lesson — and the cast keeps working if the Wi-Fi drops.'**
  String tcDownloadAll(String target);

  /// No description provided for @tcPrepareTarget.
  ///
  /// In en, this message translates to:
  /// **'Prepare {target}'**
  String tcPrepareTarget(String target);

  /// No description provided for @tcNothingToDownload.
  ///
  /// In en, this message translates to:
  /// **'Nothing to download for {target} — it casts from the app.'**
  String tcNothingToDownload(String target);

  /// No description provided for @tcSomeFailed.
  ///
  /// In en, this message translates to:
  /// **'{ready} of {total} ready. {failed} couldn’t be downloaded — those will load during the lesson if the network is up.'**
  String tcSomeFailed(int ready, int total, int failed);

  /// No description provided for @tcAllReady.
  ///
  /// In en, this message translates to:
  /// **'All {total} items are on this device. {target} will cast instantly, even with no internet.'**
  String tcAllReady(int total, String target);

  /// No description provided for @tcUpdatesItself.
  ///
  /// In en, this message translates to:
  /// **'{description} Updates by itself as your class works.'**
  String tcUpdatesItself(String description);

  /// No description provided for @tcOlderCasts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 older cast kept (90 days).} other{{count} older casts kept (90 days).}}'**
  String tcOlderCasts(int count);

  /// No description provided for @tcToday.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String tcToday(String time);

  /// No description provided for @tcYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String tcYesterday(String time);

  /// No description provided for @tcCards.
  ///
  /// In en, this message translates to:
  /// **'{count} cards'**
  String tcCards(int count);

  /// No description provided for @tcPages.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String tcPages(int count);

  /// No description provided for @tcQsAnswers.
  ///
  /// In en, this message translates to:
  /// **'{questions} Qs · {answers} answers'**
  String tcQsAnswers(int questions, int answers);

  /// No description provided for @tcSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count} sec'**
  String tcSeconds(int count);

  /// No description provided for @tcHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {minutes} min'**
  String tcHoursMinutes(int hours, int minutes);

  /// No description provided for @tcOfCasting.
  ///
  /// In en, this message translates to:
  /// **'{duration} of casting'**
  String tcOfCasting(String duration);

  /// No description provided for @tcCardsSigns.
  ///
  /// In en, this message translates to:
  /// **'{count} cards / signs shown'**
  String tcCardsSigns(int count);

  /// No description provided for @tcStoryPages.
  ///
  /// In en, this message translates to:
  /// **'{count} story pages'**
  String tcStoryPages(int count);

  /// No description provided for @tcLiveQs.
  ///
  /// In en, this message translates to:
  /// **'{questions} live questions · {answers} answers'**
  String tcLiveQs(int questions, int answers);

  /// No description provided for @tcTvsAtOnce.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 TV at once} other{{count} TVs at once}}'**
  String tcTvsAtOnce(int count);

  /// No description provided for @tcAdvanceOn.
  ///
  /// In en, this message translates to:
  /// **'Moves to the next {noun} on its own every few seconds.'**
  String tcAdvanceOn(String noun);

  /// No description provided for @tcAdvanceOff.
  ///
  /// In en, this message translates to:
  /// **'Stays on each {noun} until you tap Next.'**
  String tcAdvanceOff(String noun);

  /// No description provided for @tcNounPage.
  ///
  /// In en, this message translates to:
  /// **'page'**
  String get tcNounPage;

  /// No description provided for @tcNounSign.
  ///
  /// In en, this message translates to:
  /// **'sign'**
  String get tcNounSign;

  /// No description provided for @tcNounCard.
  ///
  /// In en, this message translates to:
  /// **'card'**
  String get tcNounCard;

  /// No description provided for @tcFlipWord.
  ///
  /// In en, this message translates to:
  /// **'Flip “{word}” on the TV to its real photo.'**
  String tcFlipWord(String word);

  /// No description provided for @tcPlayClip.
  ///
  /// In en, this message translates to:
  /// **'Play a short clip of “{word}” in motion on the TV.'**
  String tcPlayClip(String word);

  /// No description provided for @tcPlayPageFsl.
  ///
  /// In en, this message translates to:
  /// **'Play page {number} in Filipino Sign Language on the TV.'**
  String tcPlayPageFsl(int number);

  /// No description provided for @tcPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {number} / {total}'**
  String tcPageOf(int number, int total);

  /// No description provided for @tcLeaderboardTop.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Leaderboard — top 1 student.} other{Leaderboard — top {count} students.}}'**
  String tcLeaderboardTop(int count);

  /// No description provided for @tcLiveAnswered.
  ///
  /// In en, this message translates to:
  /// **'Live activity — {count} answered.'**
  String tcLiveAnswered(int count);

  /// No description provided for @tcpNotOnWifi.
  ///
  /// In en, this message translates to:
  /// **'This tablet is not on Wi-Fi. The TV and the tablet have to be on the same Wi-Fi network to cast — connect to Wi-Fi and try again.'**
  String get tcpNotOnWifi;

  /// No description provided for @tcpAway.
  ///
  /// In en, this message translates to:
  /// **'Showing “the teacher is out” — tap to resume.'**
  String get tcpAway;

  /// No description provided for @tcpNoTv.
  ///
  /// In en, this message translates to:
  /// **'No TV connected yet'**
  String get tcpNoTv;

  /// No description provided for @tcpWatching.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 TV watching} other{{count} TVs watching}}'**
  String tcpWatching(int count);

  /// No description provided for @tcpNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected'**
  String get tcpNothing;

  /// No description provided for @tcpCasting.
  ///
  /// In en, this message translates to:
  /// **'Casting to TV'**
  String get tcpCasting;

  /// No description provided for @tcpCastingCode.
  ///
  /// In en, this message translates to:
  /// **'Casting to TV · code {code}'**
  String tcpCastingCode(String code);

  /// No description provided for @cspSemantics.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Casting to TV. {mode}. 1 viewer connected.} other{Casting to TV. {mode}. {count} viewers connected.}}'**
  String cspSemantics(String mode, int count);

  /// No description provided for @cspTeacherOut.
  ///
  /// In en, this message translates to:
  /// **'Casting — teacher is out'**
  String get cspTeacherOut;

  /// No description provided for @cspWatching.
  ///
  /// In en, this message translates to:
  /// **'{mode} · {count} watching'**
  String cspWatching(String mode, int count);

  /// No description provided for @cspPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous on TV'**
  String get cspPrev;

  /// No description provided for @cspResume.
  ///
  /// In en, this message translates to:
  /// **'Resume cast'**
  String get cspResume;

  /// No description provided for @cspPause.
  ///
  /// In en, this message translates to:
  /// **'Pause cast'**
  String get cspPause;

  /// No description provided for @cspNext.
  ///
  /// In en, this message translates to:
  /// **'Next on TV'**
  String get cspNext;

  /// No description provided for @tqOpen.
  ///
  /// In en, this message translates to:
  /// **'Open this on your TV'**
  String get tqOpen;

  /// No description provided for @tqHow.
  ///
  /// In en, this message translates to:
  /// **'In the TV’s own web browser, scan the code or type this URL (don’t mirror or cast your tablet — that keeps the sound on the tablet):'**
  String get tqHow;

  /// No description provided for @tqCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied'**
  String get tqCopied;

  /// No description provided for @tqCode.
  ///
  /// In en, this message translates to:
  /// **'Cast code'**
  String get tqCode;

  /// No description provided for @tqCodeSemantics.
  ///
  /// In en, this message translates to:
  /// **'Cast code {code}'**
  String tqCodeSemantics(String code);

  /// No description provided for @tqPrivate.
  ///
  /// In en, this message translates to:
  /// **'Only TVs opening this exact link can see the cast. The code changes every time you start casting.'**
  String get tqPrivate;

  /// No description provided for @trPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get trPrevious;

  /// No description provided for @trPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get trPlay;

  /// No description provided for @trPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get trPause;

  /// No description provided for @tlpNeedsNet.
  ///
  /// In en, this message translates to:
  /// **'Live games & quizzes need an internet connection so learner devices can join in real time. Connect to Wi-Fi or mobile data (it stays on the free plan) and try again.'**
  String get tlpNeedsNet;

  /// No description provided for @tlpNoGroup.
  ///
  /// In en, this message translates to:
  /// **'Create a home group first (Manage Family), then your child can join the live activity from their own device.'**
  String get tlpNoGroup;

  /// No description provided for @tlpNoClass.
  ///
  /// In en, this message translates to:
  /// **'Create a classroom first (Manage Classes), then your students can join the live activity from their own devices.'**
  String get tlpNoClass;

  /// No description provided for @tlpStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a live activity'**
  String get tlpStartTitle;

  /// No description provided for @tlpStartBody.
  ///
  /// In en, this message translates to:
  /// **'Learners in the chosen class join from their own device, answer on screen, and earn stars. Their raised hands show on the TV.'**
  String get tlpStartBody;

  /// No description provided for @tlpHost.
  ///
  /// In en, this message translates to:
  /// **'Class / group to host'**
  String get tlpHost;

  /// No description provided for @tlpStartSem.
  ///
  /// In en, this message translates to:
  /// **'Start live activity session'**
  String get tlpStartSem;

  /// No description provided for @tlpStart.
  ///
  /// In en, this message translates to:
  /// **'Start live session'**
  String get tlpStart;

  /// No description provided for @tlpStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the live session. Check your connection.'**
  String get tlpStartFailed;

  /// No description provided for @tlpTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: the question, raised hands, and scoreboard all show on the TV. Learners answer on their own devices.'**
  String get tlpTip;

  /// No description provided for @tlpSent.
  ///
  /// In en, this message translates to:
  /// **'Question sent to learners & TV'**
  String get tlpSent;

  /// No description provided for @tlpRunning.
  ///
  /// In en, this message translates to:
  /// **'Live session running'**
  String get tlpRunning;

  /// No description provided for @tlpAnswered.
  ///
  /// In en, this message translates to:
  /// **'{count} answered the current question'**
  String tlpAnswered(int count);

  /// No description provided for @tlpEndSem.
  ///
  /// In en, this message translates to:
  /// **'End live session'**
  String get tlpEndSem;

  /// No description provided for @tlpEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get tlpEnd;

  /// No description provided for @tlpScoring.
  ///
  /// In en, this message translates to:
  /// **'Star scoring'**
  String get tlpScoring;

  /// No description provided for @tlpBase.
  ///
  /// In en, this message translates to:
  /// **'Base {stars}★'**
  String tlpBase(int stars);

  /// No description provided for @tlpSpeed.
  ///
  /// In en, this message translates to:
  /// **' • speed +{stars}'**
  String tlpSpeed(int stars);

  /// No description provided for @tlpFirst.
  ///
  /// In en, this message translates to:
  /// **' • first +{stars}'**
  String tlpFirst(int stars);

  /// No description provided for @tlpCap.
  ///
  /// In en, this message translates to:
  /// **' • cap {stars}'**
  String tlpCap(int stars);

  /// No description provided for @tlpPerCorrect.
  ///
  /// In en, this message translates to:
  /// **'Stars per correct answer'**
  String get tlpPerCorrect;

  /// No description provided for @tlpSpeedBonus.
  ///
  /// In en, this message translates to:
  /// **'Speed bonus (extra for fast answers)'**
  String get tlpSpeedBonus;

  /// No description provided for @tlpSpeedWindow.
  ///
  /// In en, this message translates to:
  /// **'Speed window (seconds)'**
  String get tlpSpeedWindow;

  /// No description provided for @tlpFirstBonus.
  ///
  /// In en, this message translates to:
  /// **'First-correct bonus'**
  String get tlpFirstBonus;

  /// No description provided for @tlpSessionCap.
  ///
  /// In en, this message translates to:
  /// **'Session star cap (0 = no cap)'**
  String get tlpSessionCap;

  /// No description provided for @tlpDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease {label}'**
  String tlpDecrease(String label);

  /// No description provided for @tlpIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase {label}'**
  String tlpIncrease(String label);

  /// No description provided for @tlpNoQuestion.
  ///
  /// In en, this message translates to:
  /// **'No question on screen. Build & push one below.'**
  String get tlpNoQuestion;

  /// No description provided for @tlpMc.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice: {prompt}'**
  String tlpMc(String prompt);

  /// No description provided for @tlpTf.
  ///
  /// In en, this message translates to:
  /// **'True or False: {prompt}'**
  String tlpTf(String prompt);

  /// No description provided for @tlpPictureN.
  ///
  /// In en, this message translates to:
  /// **'Picture choice ({count} options)'**
  String tlpPictureN(int count);

  /// No description provided for @tlpFslSelf.
  ///
  /// In en, this message translates to:
  /// **'FSL sign — self check'**
  String get tlpFslSelf;

  /// No description provided for @tlpFslN.
  ///
  /// In en, this message translates to:
  /// **'FSL sign ({count} options)'**
  String tlpFslN(int count);

  /// No description provided for @tlpFlashcard.
  ///
  /// In en, this message translates to:
  /// **'Flashcard'**
  String get tlpFlashcard;

  /// No description provided for @tlpHands.
  ///
  /// In en, this message translates to:
  /// **'Raised hands'**
  String get tlpHands;

  /// No description provided for @tlpHandsN.
  ///
  /// In en, this message translates to:
  /// **'Raised hands ({count})'**
  String tlpHandsN(int count);

  /// No description provided for @tlpNoHands.
  ///
  /// In en, this message translates to:
  /// **'No one is asking for help right now.'**
  String get tlpNoHands;

  /// No description provided for @tlpHandSem.
  ///
  /// In en, this message translates to:
  /// **'{name} raised their hand. Activate to clear.'**
  String tlpHandSem(String name);

  /// No description provided for @tlpHandled.
  ///
  /// In en, this message translates to:
  /// **'Mark handled'**
  String get tlpHandled;

  /// No description provided for @tlpSend.
  ///
  /// In en, this message translates to:
  /// **'Send a question'**
  String get tlpSend;

  /// No description provided for @tlpBuildPush.
  ///
  /// In en, this message translates to:
  /// **'Build & push question'**
  String get tlpBuildPush;

  /// No description provided for @tlpNewQuiz.
  ///
  /// In en, this message translates to:
  /// **'New quiz'**
  String get tlpNewQuiz;

  /// No description provided for @tlpSavedQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Saved quizzes'**
  String get tlpSavedQuizzes;

  /// No description provided for @tlpQuestionsN.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String tlpQuestionsN(int count);

  /// No description provided for @tlpRunQuiz.
  ///
  /// In en, this message translates to:
  /// **'Run this quiz'**
  String get tlpRunQuiz;

  /// No description provided for @tlpDeleteQuiz.
  ///
  /// In en, this message translates to:
  /// **'Delete quiz'**
  String get tlpDeleteQuiz;

  /// No description provided for @tlpRunningSet.
  ///
  /// In en, this message translates to:
  /// **'Running “{title}” — question {number} of {total}'**
  String tlpRunningSet(String title, int number, int total);

  /// No description provided for @tlpScoreboard.
  ///
  /// In en, this message translates to:
  /// **'Live scoreboard'**
  String get tlpScoreboard;

  /// No description provided for @tlpNoAnswers.
  ///
  /// In en, this message translates to:
  /// **'No answers yet.'**
  String get tlpNoAnswers;

  /// No description provided for @tlpNewQuestion.
  ///
  /// In en, this message translates to:
  /// **'New question'**
  String get tlpNewQuestion;

  /// No description provided for @tlpPushTv.
  ///
  /// In en, this message translates to:
  /// **'Push to TV'**
  String get tlpPushTv;

  /// No description provided for @tlpPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get tlpPicture;

  /// No description provided for @tlpMcLabel.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get tlpMcLabel;

  /// No description provided for @tlpTfLabel.
  ///
  /// In en, this message translates to:
  /// **'True / False'**
  String get tlpTfLabel;

  /// No description provided for @tlpFslSign.
  ///
  /// In en, this message translates to:
  /// **'FSL sign'**
  String get tlpFslSign;

  /// No description provided for @tlpQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get tlpQuestion;

  /// No description provided for @tlpOptionsHint.
  ///
  /// In en, this message translates to:
  /// **'Answer options (tap ✓ to mark the correct one)'**
  String get tlpOptionsHint;

  /// No description provided for @tlpMarkCorrect.
  ///
  /// In en, this message translates to:
  /// **'Mark option {number} correct'**
  String tlpMarkCorrect(int number);

  /// No description provided for @tlpOption.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String tlpOption(int number);

  /// No description provided for @tlpOptional.
  ///
  /// In en, this message translates to:
  /// **' (optional)'**
  String get tlpOptional;

  /// No description provided for @tlpStatement.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get tlpStatement;

  /// No description provided for @tlpTrue.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get tlpTrue;

  /// No description provided for @tlpFalse.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get tlpFalse;

  /// No description provided for @tlpAutoOptions.
  ///
  /// In en, this message translates to:
  /// **'Learners pick the matching word from 4 options (auto-generated).'**
  String get tlpAutoOptions;

  /// No description provided for @tlpSelfCheck.
  ///
  /// In en, this message translates to:
  /// **'Self-check (learner taps “I got it”)'**
  String get tlpSelfCheck;

  /// No description provided for @tlpSelfCheckNote.
  ///
  /// In en, this message translates to:
  /// **'No options — the learner judges their own sign.'**
  String get tlpSelfCheckNote;

  /// No description provided for @tlpPickOptions.
  ///
  /// In en, this message translates to:
  /// **'Learners pick the matching word from options.'**
  String get tlpPickOptions;

  /// No description provided for @tlpNeedOptions.
  ///
  /// In en, this message translates to:
  /// **'Add a question and at least two options, and mark the correct one.'**
  String get tlpNeedOptions;

  /// No description provided for @tlpNeedStatement.
  ///
  /// In en, this message translates to:
  /// **'Type a statement.'**
  String get tlpNeedStatement;

  /// No description provided for @tlpNeedCard.
  ///
  /// In en, this message translates to:
  /// **'Pick a flashcard first.'**
  String get tlpNeedCard;

  /// No description provided for @tlpUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported.'**
  String get tlpUnsupported;

  /// No description provided for @tlpQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz title'**
  String get tlpQuizTitle;

  /// No description provided for @tlpNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'No questions yet. Add your first below.'**
  String get tlpNoQuestions;

  /// No description provided for @tlpAddQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get tlpAddQuestion;

  /// No description provided for @tlpSaveQuiz.
  ///
  /// In en, this message translates to:
  /// **'Save quiz'**
  String get tlpSaveQuiz;

  /// No description provided for @tlpTfShort.
  ///
  /// In en, this message translates to:
  /// **'T/F: {prompt}'**
  String tlpTfShort(String prompt);

  /// No description provided for @tlpPictureChoice.
  ///
  /// In en, this message translates to:
  /// **'Picture choice'**
  String get tlpPictureChoice;

  /// No description provided for @tlpFslSelfShort.
  ///
  /// In en, this message translates to:
  /// **'FSL self-check'**
  String get tlpFslSelfShort;

  /// No description provided for @tlpNoFslCat.
  ///
  /// In en, this message translates to:
  /// **'No FSL signs in this category yet — try another.'**
  String get tlpNoFslCat;

  /// No description provided for @lrTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Time’s up for today'**
  String get lrTimeUp;

  /// No description provided for @lrUsed.
  ///
  /// In en, this message translates to:
  /// **'You’ve used {used} of {limit} minutes.'**
  String lrUsed(int used, int limit);

  /// No description provided for @lrOutsideHours.
  ///
  /// In en, this message translates to:
  /// **'Outside study hours'**
  String get lrOutsideHours;

  /// No description provided for @lrAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed: {start} – {end}.'**
  String lrAllowed(String start, String end);

  /// No description provided for @lrAlarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get lrAlarm;

  /// No description provided for @lrTakeBreak.
  ///
  /// In en, this message translates to:
  /// **'Time to take a break.'**
  String get lrTakeBreak;

  /// No description provided for @lrRoutineTime.
  ///
  /// In en, this message translates to:
  /// **'Routine time'**
  String get lrRoutineTime;

  /// No description provided for @lrFinishThis.
  ///
  /// In en, this message translates to:
  /// **'Finish this to carry on.'**
  String get lrFinishThis;

  /// No description provided for @nsDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'📚 Time to Learn!'**
  String get nsDailyTitle;

  /// No description provided for @nsDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Let’s practice some new words today!'**
  String get nsDailyBody;

  /// No description provided for @nsReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'🧠 Words Need Your Attention!'**
  String get nsReviewTitle;

  /// No description provided for @nsReviewBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You have 1 word to review. Let’s strengthen your memory!} other{You have {count} words to review. Let’s strengthen your memory!}}'**
  String nsReviewBody(int count);

  /// No description provided for @nsReviewNone.
  ///
  /// In en, this message translates to:
  /// **'Time to review your vocabulary and keep your streak going!'**
  String get nsReviewNone;

  /// No description provided for @asAlarm.
  ///
  /// In en, this message translates to:
  /// **'⏰ Alarm'**
  String get asAlarm;

  /// No description provided for @asMoment.
  ///
  /// In en, this message translates to:
  /// **'Time to take a moment.'**
  String get asMoment;

  /// No description provided for @asWrapUp.
  ///
  /// In en, this message translates to:
  /// **'Time to wrap up — tap to view.'**
  String get asWrapUp;

  /// No description provided for @asTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert Settings'**
  String get asTitle;

  /// No description provided for @asEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Alerts'**
  String get asEnable;

  /// No description provided for @asEnableSub.
  ///
  /// In en, this message translates to:
  /// **'Get notified about student activity'**
  String get asEnableSub;

  /// No description provided for @asThresholds.
  ///
  /// In en, this message translates to:
  /// **'Thresholds'**
  String get asThresholds;

  /// No description provided for @asAccuracyBelow.
  ///
  /// In en, this message translates to:
  /// **'Accuracy alert below'**
  String get asAccuracyBelow;

  /// No description provided for @asInactivityAfter.
  ///
  /// In en, this message translates to:
  /// **'Inactivity alert after'**
  String get asInactivityAfter;

  /// No description provided for @asDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String asDays(int count);

  /// No description provided for @asTypes.
  ///
  /// In en, this message translates to:
  /// **'Alert Types'**
  String get asTypes;

  /// No description provided for @asRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent Alerts ({count})'**
  String asRecent(int count);

  /// No description provided for @asNone.
  ///
  /// In en, this message translates to:
  /// **'No alerts yet'**
  String get asNone;

  /// No description provided for @asMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String asMinutesAgo(int count);

  /// No description provided for @asHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String asHoursAgo(int count);

  /// No description provided for @asDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String asDaysAgo(int count);

  /// No description provided for @atLowAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Low Accuracy'**
  String get atLowAccuracy;

  /// No description provided for @atStreakBroken.
  ///
  /// In en, this message translates to:
  /// **'Streak Broken'**
  String get atStreakBroken;

  /// No description provided for @atInactivity.
  ///
  /// In en, this message translates to:
  /// **'Inactivity'**
  String get atInactivity;

  /// No description provided for @atOverdue.
  ///
  /// In en, this message translates to:
  /// **'Assignment Overdue'**
  String get atOverdue;

  /// No description provided for @atAchievement.
  ///
  /// In en, this message translates to:
  /// **'Achievement Earned'**
  String get atAchievement;

  /// No description provided for @atAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment Completed'**
  String get atAssessment;

  /// No description provided for @amLowAccuracy.
  ///
  /// In en, this message translates to:
  /// **'{name}’s accuracy is {accuracy}% (below {threshold}% threshold)'**
  String amLowAccuracy(String name, String accuracy, String threshold);

  /// No description provided for @amInactive.
  ///
  /// In en, this message translates to:
  /// **'{name} has been inactive for {days} days'**
  String amInactive(String name, String days);

  /// No description provided for @amStreak.
  ///
  /// In en, this message translates to:
  /// **'{name}’s streak was broken'**
  String amStreak(String name);

  /// No description provided for @daTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed Analytics'**
  String get daTitle;

  /// No description provided for @daAvgSession.
  ///
  /// In en, this message translates to:
  /// **'Average Session'**
  String get daAvgSession;

  /// No description provided for @daMinutesPerSession.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes per session'**
  String daMinutesPerSession(String minutes);

  /// No description provided for @aaCategoryOverview.
  ///
  /// In en, this message translates to:
  /// **'Category Overview'**
  String get aaCategoryOverview;

  /// No description provided for @aaMastered.
  ///
  /// In en, this message translates to:
  /// **'{count} Mastered'**
  String aaMastered(int count);

  /// No description provided for @aaLearning.
  ///
  /// In en, this message translates to:
  /// **'{count} Learning'**
  String aaLearning(int count);

  /// No description provided for @aaNew.
  ///
  /// In en, this message translates to:
  /// **'{count} New'**
  String aaNew(int count);

  /// No description provided for @aaSessionInsights.
  ///
  /// In en, this message translates to:
  /// **'Session Insights'**
  String get aaSessionInsights;

  /// No description provided for @aaAvgSession.
  ///
  /// In en, this message translates to:
  /// **'Avg Session'**
  String get aaAvgSession;

  /// No description provided for @aaTotalSessions.
  ///
  /// In en, this message translates to:
  /// **'Total Sessions'**
  String get aaTotalSessions;

  /// No description provided for @ptTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} — Timeline'**
  String ptTitle(String name);

  /// No description provided for @ptAccuracySub.
  ///
  /// In en, this message translates to:
  /// **'Average daily accuracy — last 30 days'**
  String get ptAccuracySub;

  /// No description provided for @ptStudyTime.
  ///
  /// In en, this message translates to:
  /// **'Study Time ⏱️'**
  String get ptStudyTime;

  /// No description provided for @ptMinutesSub.
  ///
  /// In en, this message translates to:
  /// **'Minutes per day — last 30 days'**
  String get ptMinutesSub;

  /// No description provided for @ptAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'Avg: {minutes} min/day'**
  String ptAvgPerDay(int minutes);

  /// No description provided for @ptCategoryProgress.
  ///
  /// In en, this message translates to:
  /// **'Category Progress 📚'**
  String get ptCategoryProgress;

  /// No description provided for @ptNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet'**
  String get ptNotEnough;

  /// No description provided for @scmpSelect2.
  ///
  /// In en, this message translates to:
  /// **'Select at least 2 students to compare'**
  String get scmpSelect2;

  /// No description provided for @scmpSelect23.
  ///
  /// In en, this message translates to:
  /// **'Select 2–3 students above to compare'**
  String get scmpSelect23;

  /// No description provided for @scmpStreakDays.
  ///
  /// In en, this message translates to:
  /// **'Streak (days)'**
  String get scmpStreakDays;

  /// No description provided for @scmpStarsEarned.
  ///
  /// In en, this message translates to:
  /// **'Stars Earned'**
  String get scmpStarsEarned;

  /// No description provided for @scmpCategoryComparison.
  ///
  /// In en, this message translates to:
  /// **'Category Comparison'**
  String get scmpCategoryComparison;

  /// No description provided for @scmpStrengths.
  ///
  /// In en, this message translates to:
  /// **'Strengths & Weaknesses'**
  String get scmpStrengths;

  /// No description provided for @cmSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to manage classes.'**
  String get cmSignIn;

  /// No description provided for @mqRoundsPerPlayer.
  ///
  /// In en, this message translates to:
  /// **'Rounds per Player'**
  String get mqRoundsPerPlayer;

  /// No description provided for @gzFocusHint.
  ///
  /// In en, this message translates to:
  /// **'Look ◀ ▶ ▲ ▼ to move · blink to press'**
  String get gzFocusHint;

  /// No description provided for @spdSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get spdSupport;

  /// No description provided for @lgcPerCategory.
  ///
  /// In en, this message translates to:
  /// **'Per-Category Breakdown'**
  String get lgcPerCategory;

  /// No description provided for @rsTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get rsTimer;

  /// No description provided for @ebTitle.
  ///
  /// In en, this message translates to:
  /// **'Oops! Something went wrong'**
  String get ebTitle;

  /// No description provided for @ebBody.
  ///
  /// In en, this message translates to:
  /// **'This part of the app ran into a problem.\nTry going back or restarting the app.'**
  String get ebBody;

  /// No description provided for @gwAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get gwAuto;

  /// No description provided for @gwStarsOf.
  ///
  /// In en, this message translates to:
  /// **'{stars} out of {max} stars'**
  String gwStarsOf(int stars, int max);

  /// No description provided for @cdPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing Games'**
  String get cdPlaying;

  /// No description provided for @cdReviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing Flashcards'**
  String get cdReviewing;

  /// No description provided for @cdStudying.
  ///
  /// In en, this message translates to:
  /// **'Studying'**
  String get cdStudying;

  /// No description provided for @brRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored successfully!'**
  String get brRestored;

  /// No description provided for @brNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file selected.'**
  String get brNoFile;

  /// No description provided for @brCantRead.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file.'**
  String get brCantRead;

  /// No description provided for @brPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file picker. Please try again.'**
  String get brPickFailed;

  /// No description provided for @brCorrupt.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file. The file may be corrupted.'**
  String get brCorrupt;

  /// No description provided for @brBadFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup format. Could not read the data.'**
  String get brBadFormat;

  /// No description provided for @brNewer.
  ///
  /// In en, this message translates to:
  /// **'This backup was made with a newer version of FlashLearn PWD. Please update the app first.'**
  String get brNewer;

  /// No description provided for @brNoData.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup structure. No data found.'**
  String get brNoData;

  /// No description provided for @brRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the backup. Please try again.'**
  String get brRestoreFailed;

  /// No description provided for @csxNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync isn’t connected'**
  String get csxNotConnected;

  /// No description provided for @csxNotConnectedBody.
  ///
  /// In en, this message translates to:
  /// **'Restart the app. If it still isn’t connected, check this device’s internet.'**
  String get csxNotConnectedBody;

  /// No description provided for @ieImported.
  ///
  /// In en, this message translates to:
  /// **'Successfully imported “{name}”'**
  String ieImported(String name);

  /// No description provided for @ieNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get ieNoFile;

  /// No description provided for @ieCantRead.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file'**
  String get ieCantRead;

  /// No description provided for @ieBadFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid file format'**
  String get ieBadFormat;

  /// No description provided for @ieNotProfile.
  ///
  /// In en, this message translates to:
  /// **'This file does not contain a valid student profile'**
  String get ieNotProfile;

  /// No description provided for @ieExists.
  ///
  /// In en, this message translates to:
  /// **'A profile with this ID already exists. Delete it first or export from a different device.'**
  String get ieExists;

  /// No description provided for @ieReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the file. Please try again.'**
  String get ieReadFailed;

  /// No description provided for @ehNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get ehNetwork;

  /// No description provided for @ehFormat.
  ///
  /// In en, this message translates to:
  /// **'Data format error. Some data may be corrupted.'**
  String get ehFormat;

  /// No description provided for @ehTimeout.
  ///
  /// In en, this message translates to:
  /// **'Operation timed out. Please try again.'**
  String get ehTimeout;

  /// No description provided for @ehGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. The app will continue working.'**
  String get ehGeneric;

  /// No description provided for @dwsUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{badge} unlocked!'**
  String dwsUnlocked(String badge);

  /// No description provided for @assessMediaPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get assessMediaPhoto;

  /// No description provided for @assessMediaGif.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get assessMediaGif;

  /// No description provided for @assessMediaVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get assessMediaVideo;

  /// No description provided for @assessMediaAudio.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get assessMediaAudio;

  /// No description provided for @assessMediaSign.
  ///
  /// In en, this message translates to:
  /// **'FSL video'**
  String get assessMediaSign;

  /// No description provided for @assessMediaSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Pictures, video & sign language'**
  String get assessMediaSectionTitle;

  /// No description provided for @assessMediaSectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional. Each learner meets these in the way that suits them — a Deaf learner sees the FSL video first, a learner with low vision hears the sound and the description.'**
  String get assessMediaSectionHelp;

  /// No description provided for @assessMediaAdd.
  ///
  /// In en, this message translates to:
  /// **'Add {kind}'**
  String assessMediaAdd(String kind);

  /// No description provided for @assessMediaFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose from this device'**
  String get assessMediaFromDevice;

  /// No description provided for @assessMediaOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On this tablet only — learners on another device won\'t see it.'**
  String get assessMediaOnDevice;

  /// No description provided for @assessMediaPasteLink.
  ///
  /// In en, this message translates to:
  /// **'Or paste a link'**
  String get assessMediaPasteLink;

  /// No description provided for @assessMediaLinkHint.
  ///
  /// In en, this message translates to:
  /// **'https://… (a direct link to the file)'**
  String get assessMediaLinkHint;

  /// No description provided for @assessMediaUseLink.
  ///
  /// In en, this message translates to:
  /// **'Use this link'**
  String get assessMediaUseLink;

  /// No description provided for @assessMediaLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'Paste a link that starts with https://'**
  String get assessMediaLinkInvalid;

  /// No description provided for @assessMediaLinkReaches.
  ///
  /// In en, this message translates to:
  /// **'A link reaches every device.'**
  String get assessMediaLinkReaches;

  /// No description provided for @assessMediaPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get assessMediaPreview;

  /// No description provided for @assessMediaReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get assessMediaReplace;

  /// No description provided for @assessMediaRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get assessMediaRemove;

  /// No description provided for @assessMediaTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is too big. Choose one under {size} MB.'**
  String assessMediaTooLarge(int size);

  /// No description provided for @assessMediaPickFailed.
  ///
  /// In en, this message translates to:
  /// **'That file could not be added. Try another one.'**
  String get assessMediaPickFailed;

  /// No description provided for @assessMediaDescribe.
  ///
  /// In en, this message translates to:
  /// **'Describe it in words'**
  String get assessMediaDescribe;

  /// No description provided for @assessMediaDescribeHelp.
  ///
  /// In en, this message translates to:
  /// **'Read aloud to learners who can\'t see it, and shown as a caption to learners who can\'t hear it.'**
  String get assessMediaDescribeHelp;

  /// No description provided for @assessMediaDescribeHelpQuestion.
  ///
  /// In en, this message translates to:
  /// **'Read aloud to learners who can\'t see it, and shown as a caption to learners who can\'t hear it. Don\'t give the answer away.'**
  String get assessMediaDescribeHelpQuestion;

  /// No description provided for @assessMediaSignHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown to learners who sign. To ask about a sign itself, put the clip under Video so every learner sees it.'**
  String get assessMediaSignHelp;

  /// No description provided for @assessMediaTipFor.
  ///
  /// In en, this message translates to:
  /// **'For {names}: {advice}'**
  String assessMediaTipFor(String names, String advice);

  /// No description provided for @assessMediaTipHearing.
  ///
  /// In en, this message translates to:
  /// **'add an FSL video, and put any sound into words.'**
  String get assessMediaTipHearing;

  /// No description provided for @assessMediaTipVisual.
  ///
  /// In en, this message translates to:
  /// **'add a sound, and describe pictures in words — they will be read aloud.'**
  String get assessMediaTipVisual;

  /// No description provided for @assessMediaTipCognitive.
  ///
  /// In en, this message translates to:
  /// **'one clear photo works best — they see one thing at a time.'**
  String get assessMediaTipCognitive;

  /// No description provided for @assessMediaTipMotor.
  ///
  /// In en, this message translates to:
  /// **'videos play by themselves, so no small buttons are needed.'**
  String get assessMediaTipMotor;

  /// No description provided for @assessMediaTipMultiple.
  ///
  /// In en, this message translates to:
  /// **'add an FSL video and a photo, and describe them in words.'**
  String get assessMediaTipMultiple;

  /// No description provided for @assessMediaTipWordsOnly.
  ///
  /// In en, this message translates to:
  /// **'put everything into words — it is shown as a caption.'**
  String get assessMediaTipWordsOnly;

  /// No description provided for @assessMediaSignHeading.
  ///
  /// In en, this message translates to:
  /// **'Sign language'**
  String get assessMediaSignHeading;

  /// No description provided for @assessMediaFilmedInFsl.
  ///
  /// In en, this message translates to:
  /// **'Filmed in FSL'**
  String get assessMediaFilmedInFsl;

  /// No description provided for @assessMediaCaption.
  ///
  /// In en, this message translates to:
  /// **'What it shows or says'**
  String get assessMediaCaption;

  /// No description provided for @assessMediaReadAloud.
  ///
  /// In en, this message translates to:
  /// **'Read it to me'**
  String get assessMediaReadAloud;

  /// No description provided for @assessMediaShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more ({count})'**
  String assessMediaShowMore(int count);

  /// No description provided for @assessMediaTapToEnlarge.
  ///
  /// In en, this message translates to:
  /// **'Tap to see it bigger'**
  String get assessMediaTapToEnlarge;

  /// No description provided for @assessMediaPlayAnimation.
  ///
  /// In en, this message translates to:
  /// **'Play the moving picture'**
  String get assessMediaPlayAnimation;

  /// No description provided for @assessMediaStopAnimation.
  ///
  /// In en, this message translates to:
  /// **'Stop the moving picture'**
  String get assessMediaStopAnimation;

  /// No description provided for @assessMediaPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get assessMediaPlay;

  /// No description provided for @assessMediaPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get assessMediaPause;

  /// No description provided for @assessMediaReplay.
  ///
  /// In en, this message translates to:
  /// **'Watch again'**
  String get assessMediaReplay;

  /// No description provided for @assessMediaClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get assessMediaClose;

  /// No description provided for @assessMediaOnOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'This {kind} is saved on your teacher\'s tablet, so it can\'t show here.'**
  String assessMediaOnOtherDevice(String kind);

  /// No description provided for @assessMediaCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'This {kind} could not be loaded. Try again when you are online.'**
  String assessMediaCouldNotLoad(String kind);

  /// No description provided for @assessMediaPreparing.
  ///
  /// In en, this message translates to:
  /// **'Getting the pictures and videos ready…'**
  String get assessMediaPreparing;

  /// No description provided for @assessMediaMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Some pictures or videos aren\'t on this tablet'**
  String get assessMediaMissingTitle;

  /// No description provided for @assessMediaMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Connect to Wi‑Fi and try again, or start without them. The test has not started.'**
  String get assessMediaMissingBody;

  /// No description provided for @assessMediaStartAnyway.
  ///
  /// In en, this message translates to:
  /// **'Start without them'**
  String get assessMediaStartAnyway;

  /// No description provided for @assessInstructionsMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Pictures, video or sign language for the instructions'**
  String get assessInstructionsMediaTitle;

  /// No description provided for @assessBriefingTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get assessBriefingTitle;

  /// No description provided for @assessBriefingStart.
  ///
  /// In en, this message translates to:
  /// **'Start the test'**
  String get assessBriefingStart;

  /// No description provided for @assessBriefingLater.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get assessBriefingLater;

  /// No description provided for @assessFeedbackFor.
  ///
  /// In en, this message translates to:
  /// **'Feedback for {name}'**
  String assessFeedbackFor(String name);

  /// No description provided for @assessFeedbackOn.
  ///
  /// In en, this message translates to:
  /// **'Feedback on {title}'**
  String assessFeedbackOn(String title);

  /// No description provided for @assessFeedbackFromEducator.
  ///
  /// In en, this message translates to:
  /// **'From your teacher or parent'**
  String get assessFeedbackFromEducator;

  /// No description provided for @assessFeedbackNote.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get assessFeedbackNote;

  /// No description provided for @assessFeedbackNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What went well, and what to practise next'**
  String get assessFeedbackNoteHint;

  /// No description provided for @assessFeedbackSave.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get assessFeedbackSave;

  /// No description provided for @assessFeedbackRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove feedback'**
  String get assessFeedbackRemove;

  /// No description provided for @assessFeedbackEmpty.
  ///
  /// In en, this message translates to:
  /// **'Write a note or add a picture, video or sound first.'**
  String get assessFeedbackEmpty;

  /// No description provided for @assessFeedbackNotFinished.
  ///
  /// In en, this message translates to:
  /// **'Not finished yet'**
  String get assessFeedbackNotFinished;

  /// No description provided for @assessFeedbackScore.
  ///
  /// In en, this message translates to:
  /// **'Score: {percent}%'**
  String assessFeedbackScore(int percent);

  /// No description provided for @assessFeedbackForYou.
  ///
  /// In en, this message translates to:
  /// **'Feedback for You'**
  String get assessFeedbackForYou;

  /// No description provided for @assessFeedbackAdd.
  ///
  /// In en, this message translates to:
  /// **'Add feedback for {name}'**
  String assessFeedbackAdd(String name);

  /// No description provided for @assessFeedbackEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit feedback for {name}'**
  String assessFeedbackEdit(String name);

  /// No description provided for @assessFeedbackSaved.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent to {name}.'**
  String assessFeedbackSaved(String name);

  /// No description provided for @assessFeedbackRemoved.
  ///
  /// In en, this message translates to:
  /// **'Feedback removed.'**
  String get assessFeedbackRemoved;

  /// No description provided for @assessFeedbackLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Feedback saved on this device — not sent yet. It will reach {name} when syncing is working.'**
  String assessFeedbackLocalOnly(String name);

  /// No description provided for @assessFeedbackNotOwner.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device only. This profile was restored on another device, so that one now handles syncing — the feedback was not sent.'**
  String get assessFeedbackNotOwner;

  /// No description provided for @assessFeedbackTapToOpen.
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get assessFeedbackTapToOpen;

  /// No description provided for @assessFeedbackHas.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent'**
  String get assessFeedbackHas;

  /// No description provided for @assessMediaShared.
  ///
  /// In en, this message translates to:
  /// **'Shared — reaches every device.'**
  String get assessMediaShared;

  /// No description provided for @assessMediaNotShared.
  ///
  /// In en, this message translates to:
  /// **'On this tablet only — not shared yet.'**
  String get assessMediaNotShared;

  /// No description provided for @assessMediaSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing… {percent}%'**
  String assessMediaSharing(int percent);

  /// No description provided for @assessMediaShareNow.
  ///
  /// In en, this message translates to:
  /// **'Share now'**
  String get assessMediaShareNow;

  /// No description provided for @assessMediaFromDeviceShared.
  ///
  /// In en, this message translates to:
  /// **'It is shared with every device (files up to {size} MB).'**
  String assessMediaFromDeviceShared(int size);

  /// No description provided for @assessMediaShareTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Over {size} MB — this file stays on this tablet only.'**
  String assessMediaShareTooLarge(int size);

  /// No description provided for @assessMediaShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t share it right now. It is saved on this tablet and will be shared when you are online.'**
  String get assessMediaShareFailed;

  /// No description provided for @assessMediaShareNotOwner.
  ///
  /// In en, this message translates to:
  /// **'This profile is now managed from another device, so files can’t be shared from this one.'**
  String get assessMediaShareNotOwner;
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
