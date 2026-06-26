// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appTitle => 'FlashLearn PWD';

  @override
  String greeting(String name) {
    return 'Kamusta, $name! 👋';
  }

  @override
  String get readyToLearn =>
      'Handa ka na bang matuto ng mga bagong salita ngayon?';

  @override
  String get dayStreak => 'Araw na Sunod-sunod';

  @override
  String get words => 'Mga Salita';

  @override
  String get stars => 'Mga Bituin';

  @override
  String get vocabularyCategories => 'Mga Kategorya ng Bokabularyo';

  @override
  String get quickGames => 'Mabilisang Laro';

  @override
  String get settings => 'Mga Setting';

  @override
  String get profile => 'Profile';

  @override
  String get accessibility => 'Accessibility';

  @override
  String get audio => 'Audio';

  @override
  String get about => 'Tungkol';

  @override
  String get highContrastMode => 'Mataas na Contrast';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get fontSize => 'Laki ng Font';

  @override
  String get reducedMotion => 'Bawasan ang Galaw';

  @override
  String get dyslexiaMode => 'Pampabasa (Dyslexia)';

  @override
  String get textToSpeech => 'Text-to-Speech';

  @override
  String get speechSpeed => 'Bilis ng Pagsasalita';

  @override
  String get soundEffects => 'Mga Tunog';

  @override
  String get resetAllData => 'I-reset Lahat ng Data';

  @override
  String get cancel => 'Kanselahin';

  @override
  String get reset => 'I-reset';

  @override
  String get language => 'Wika';

  @override
  String get reminders => 'Mga Paalala';

  @override
  String get dailyReminder => 'Araw-araw na Paalala';

  @override
  String get reminderTime => 'Oras ng Paalala';

  @override
  String get notifications => 'Mga Notipikasyon';

  @override
  String get progress => 'Progreso';

  @override
  String get streak => 'Sunod-sunod';

  @override
  String get mastery => 'Kahusayan';

  @override
  String get categoryProgress => 'Progreso ng Kategorya';

  @override
  String get recentGames => 'Mga Kamakailang Laro';

  @override
  String get playGamePrompt => 'Maglaro para makita ang iyong mga marka dito!';

  @override
  String progressTitle(String name) {
    return 'Progreso ni $name';
  }

  @override
  String get games => 'Mga Laro 🎮';

  @override
  String get learnWhileHavingFun =>
      'Matuto ng mga bagong salita habang naglalaro!';

  @override
  String get chooseDifficulty => 'Pumili ng Kahirapan';

  @override
  String get chooseCategories => 'Pumili ng Kategorya';

  @override
  String get allCategories => 'Lahat ng Kategorya';

  @override
  String get easy => 'Madali';

  @override
  String get medium => 'Katamtaman';

  @override
  String get hard => 'Mahirap';

  @override
  String get startGame => 'Simulan ang Laro';

  @override
  String get correct => 'Tama!';

  @override
  String get tryAgain => 'Subukan Muli';

  @override
  String get gameComplete => 'Tapos na ang Laro!';

  @override
  String get playAgain => 'Maglaro Muli';

  @override
  String get exit => 'Lumabas';

  @override
  String get reviewAnswers => 'Suriin ang mga Sagot';

  @override
  String get score => 'Marka';

  @override
  String get hint => 'Pahiwatig';

  @override
  String hintsLeft(int count) {
    return 'Pahiwatig ($count natitira)';
  }

  @override
  String get fillInTheBlank => 'Punan ang patlang';

  @override
  String get spellTheWord => 'I-spell ang salitang Ingles';

  @override
  String get matchPictureToWord => 'Itugma ang larawan sa tamang salita!';

  @override
  String get sentenceBuilder => 'Sentence Builder';

  @override
  String get fillMissingWord => 'Punan ang nawawalang salita sa pangungusap!';

  @override
  String get starShop => 'Tindahan ng Bituin';

  @override
  String get avatars => 'Mga Avatar';

  @override
  String get themes => 'Mga Tema';

  @override
  String get borders => 'Mga Border';

  @override
  String get owned => 'Pag-aari';

  @override
  String get buy => 'Bilhin!';

  @override
  String buyItem(String name) {
    return 'Bilhin ang $name?';
  }

  @override
  String notEnoughStars(int count) {
    return 'Kulang ang mga bituin! Kailangan mo pa ng $count ⭐';
  }

  @override
  String get alreadyOwned => 'Pag-aari mo na ito!';

  @override
  String purchaseSuccess(String name) {
    return '🎉 Nakuha mo ang $name!';
  }

  @override
  String get studyTime => 'Oras ng Pag-aaral';

  @override
  String get totalTime => 'Kabuuang Oras';

  @override
  String get avgSession => 'Avg na Sesyon';

  @override
  String get sessions => 'Mga Sesyon';

  @override
  String get last7Days => 'Huling 7 Araw';

  @override
  String get dashboard => 'Dashboard';

  @override
  String teacherDashboard(String role) {
    return 'Dashboard ng $role';
  }

  @override
  String get overallMastery => 'Pangkalahatang Kahusayan';

  @override
  String get categoryBreakdown => 'Detalye ng Kategorya';

  @override
  String get insightsRecommendations => 'Mga Insight at Rekomendasyon';

  @override
  String get needsPractice => 'Kailangan ng Pagsasanay';

  @override
  String get doingGreat => 'Magaling!';

  @override
  String get engagement => 'Pakikilahok';

  @override
  String get recentActivity => 'Kamakailang Aktibidad';

  @override
  String get noActivityYet =>
      'Wala pang aktibidad sa laro. Hikayatin ang mag-aaral na maglaro!';

  @override
  String get exportPdfReport => 'I-export ang PDF Report';

  @override
  String get confirmResetTitle => 'I-reset ang Lahat ng Data?';

  @override
  String get confirmResetMessage =>
      'Tatanggalin nito ang lahat ng profile, progreso, at mga setting. Hindi na ito maibabalik.';

  @override
  String get dailyWordChallenge => 'Araw-araw na Hamon sa Salita';

  @override
  String get smartReview => 'Smart Review';

  @override
  String get viewAllStudents => 'Tingnan ang lahat ng mag-aaral';

  @override
  String get openDashboard => 'Buksan ang dashboard ng progreso';

  @override
  String get openSettings => 'Buksan ang mga setting';

  @override
  String get openShop => 'Buksan ang tindahan ng bituin';

  @override
  String get version => 'Bersyon 1.0.0 • Thesis Capstone Project';

  @override
  String get flashLearnPwd => 'FlashLearn PWD';

  @override
  String get animals => 'Mga Hayop';

  @override
  String get colorsAndShapes => 'Mga Kulay at Hugis';

  @override
  String get numbers => 'Mga Numero';

  @override
  String get bodyParts => 'Mga Bahagi ng Katawan';

  @override
  String get foodAndDrinks => 'Pagkain at Inumin';

  @override
  String get familyAndGreetings => 'Pamilya at Pagbati';

  @override
  String get wordMatch => 'Pagtutugma ng Salita';

  @override
  String get spellingBee => 'Spelling Bee';

  @override
  String get memoryMatch => 'Memory Match';

  @override
  String get dragAndDrop => 'I-drag at I-drop';

  @override
  String get flashcardQuiz => 'Flashcard Quiz';

  @override
  String get pronunciationPractice => 'Pagsasanay sa Pagbigkas';

  @override
  String get pickVocabulary => 'Pumili kung aling bokabularyo ang ipapraktis';

  @override
  String get badges => 'Mga Badge';

  @override
  String get keepItUp => 'Ituloy mo yan! Subukan ang mas mahirap na lebel.';

  @override
  String focusOn(String category) {
    return 'Mag-focus sa $category flashcards at mga laro.';
  }

  @override
  String streakActive(int count) {
    return '$count-araw na sunod-sunod na pag-aaral!';
  }

  @override
  String get noStreakMessage =>
      'Walang aktibong streak. Subukan ang araw-araw na pagsasanay.';

  @override
  String get greatConsistency =>
      'Magaling ang konsistensi! Nagtatayo ng gawi ang mag-aaral.';

  @override
  String get encourageDaily =>
      'Hikayatin ang mag-aaral na maglaro kahit isang beses sa isang araw.';

  @override
  String get stories => 'Mga Kwento 📖';

  @override
  String get readStoriesAndAnswer =>
      'Basahin ang mga kwento at sagutin ang mga tanong!';

  @override
  String get storyQuiz => 'Quiz sa Kwento';

  @override
  String get takeQuiz => 'Sulitin';

  @override
  String get nextQuestion => 'Susunod na Tanong';

  @override
  String get seeResults => 'Tingnan ang Resulta';

  @override
  String storySentences(int count) {
    return '$count pangungusap';
  }

  @override
  String storyQuestions(int count) {
    return '$count tanong';
  }

  @override
  String get locked => 'Naka-lock';

  @override
  String get tapToRead => 'I-tap para basahin';

  @override
  String get switchToFilipino => 'Palitan sa Filipino';

  @override
  String get switchToEnglish => 'Palitan sa Ingles';

  @override
  String get readAloud => 'Basahin nang malakas';

  @override
  String get backupAndRestore => 'Backup at Restore';

  @override
  String get saveOrRestoreData => 'I-save o i-restore ang lahat ng data';

  @override
  String get classroomMode => 'Classroom Mode';

  @override
  String get monitorStudents => 'I-monitor ang lahat ng mag-aaral sa real time';

  @override
  String get classroomView => 'Classroom View';

  @override
  String get refresh => 'I-refresh';

  @override
  String get active => 'Aktibo';

  @override
  String get idle => 'Hindi aktibo';

  @override
  String get students => 'Mga Mag-aaral';

  @override
  String get noStudentProfiles => 'Walang nahanap na profile ng mag-aaral';

  @override
  String get accuracy => 'Katumpakan';

  @override
  String get lastUpdated => 'Huling na-update';

  @override
  String get voiceNavigation => 'Voice-Guided Navigation';

  @override
  String get voiceNavigationDesc => 'I-announce ang mga screen nang malakas';

  @override
  String get adaptiveDifficulty => 'Adaptive na Kahirapan';

  @override
  String get adaptiveDifficultyDesc => 'Auto-suggest ng kahirapan sa laro';

  @override
  String get welcome => 'Maligayang Pagdating! 👋';

  @override
  String get whoAreYou => 'Sino ka?';

  @override
  String get whatsYourName => 'Ano ang pangalan mo?';

  @override
  String get enterYourName => 'Ilagay ang iyong pangalan...';

  @override
  String get chooseYourAvatar => 'Pumili ng avatar';

  @override
  String get letsGo => 'Tara Na!';

  @override
  String get iWantToLearn => 'Gusto kong matuto ng bagong mga salita!';

  @override
  String get iWantToHelp => 'Gusto kong tulungan ang mga mag-aaral';

  @override
  String get iWantToSupport => 'Gusto kong suportahan ang aking anak';

  @override
  String get welcomeBack => 'Maligayang Pagbabalik! 👋';

  @override
  String get chooseYourProfile => 'Pumili ng iyong profile';

  @override
  String get addNewProfile => 'Magdagdag ng Bagong Profile';

  @override
  String enterPin(String name) {
    return 'Ilagay ang PIN para kay $name';
  }

  @override
  String get wrongPin => 'Mali ang PIN. Subukan muli.';

  @override
  String get setPin => 'Itakda ang PIN';

  @override
  String get changePin => 'Palitan ang PIN';

  @override
  String get removePin => 'Alisin ang PIN';

  @override
  String get pinRemoved => 'Tinanggal ang PIN';

  @override
  String get pinSetSuccess => 'Matagumpay na naitakda ang PIN!';

  @override
  String get pinMustBe4Digits => 'Ang PIN ay dapat eksaktong 4 na digit';

  @override
  String get pinsDoNotMatch => 'Hindi magkatugma ang mga PIN';

  @override
  String get enterPinLabel => 'Ilagay ang PIN';

  @override
  String get confirmPinLabel => 'Kumpirmahin ang PIN';

  @override
  String get choosePin =>
      'Pumili ng 4-digit na PIN para protektahan ang iyong profile.';

  @override
  String get accessibilitySetup => 'Accessibility Setup';

  @override
  String get weWillOptimize =>
      'I-optimize namin ang app para sa iyong mga pangangailangan.\nPiliin ang opsyong pinakaangkop sa iyo:';

  @override
  String get continueButton => 'Magpatuloy';

  @override
  String get recommendedSettings => 'Mga Inirekomendang Setting';

  @override
  String get noSpecialSettings =>
      'Walang kailangan na espesyal na setting!\nHanda ka na sa mga default.';

  @override
  String weWillApplySettings(String type) {
    return 'Ilalapat namin ang mga setting para sa $type:';
  }

  @override
  String get changeInSettings =>
      'Maaari mong baguhin ito anumang oras sa Settings ⚙️';

  @override
  String get applyAndContinue => 'Ilapat at Magpatuloy';

  @override
  String get youreAllSet => 'Handa Ka Na! 🎉';

  @override
  String welcomeName(String name) {
    return 'Maligayang pagdating, $name!';
  }

  @override
  String appOptimizedFor(String type) {
    return 'Na-optimize na ang iyong app para sa\n$type';
  }

  @override
  String get standardSettings => 'Handa na ang mga standard na setting.';

  @override
  String get adjustAnytime =>
      'Maaari mong i-adjust ang lahat ng setting\nmula sa pahina ng Settings.';

  @override
  String get letsStartLearning => 'Simulan Na ang Pag-aaral!';

  @override
  String get skip => 'Laktawan';

  @override
  String get flashcardDecks => 'Mga Flashcard Deck';

  @override
  String get chooseCategory => 'Pumili ng kategorya para magsimulang matuto!';

  @override
  String get importLabel => 'Import';

  @override
  String get exportLabel => 'Export';

  @override
  String importedCards(int count) {
    return 'Na-import ang $count flashcard(s)!';
  }

  @override
  String get noDuplicates =>
      'Walang bagong card na ma-import (lahat duplicate o nakansela).';

  @override
  String get importFailed => 'Nabigo ang import — suriin ang format ng file.';

  @override
  String get createCard => 'Gumawa ng Card';

  @override
  String cards(int count) {
    return '$count card';
  }

  @override
  String get deleteFlashcard => 'Tanggalin ang Flashcard?';

  @override
  String deleteConfirm(String name) {
    return 'Sigurado ka bang gusto mong tanggalin si \"$name\"? Hindi na ito maibabalik.';
  }

  @override
  String get delete => 'Tanggalin';

  @override
  String get flashcardDeleted => 'Tinanggal ang flashcard';

  @override
  String get customCard => 'Custom na Card';

  @override
  String get edit => 'I-edit';

  @override
  String get previous => 'Nakaraan';

  @override
  String get next => 'Susunod';

  @override
  String get english => 'Ingles';

  @override
  String get filipino => 'Filipino';

  @override
  String get fsl => 'FSL';

  @override
  String get flip => 'I-flip';

  @override
  String get filipinoSignLanguage => 'Filipino Sign Language';

  @override
  String noFslVideo(String word) {
    return 'Wala pang FSL video para sa \"$word\".';
  }

  @override
  String get gotIt => 'Sige!';

  @override
  String get tapToSeeMore => 'I-tap para makita pa ✨';

  @override
  String get details => 'MGA DETALYE';

  @override
  String get example => 'Halimbawa';

  @override
  String get tapToFlipBack => 'I-tap para i-flip pabalik';

  @override
  String get speed => 'Bilis:';

  @override
  String get replay => 'I-replay';

  @override
  String get close => 'Isara';

  @override
  String get unableToLoadVideo => 'Hindi ma-load ang video';

  @override
  String get fslDictionary => 'FSL Dictionary 🤟';

  @override
  String get searchWords => 'Maghanap ng salita...';

  @override
  String get all => 'Lahat';

  @override
  String wordsCount(int count) {
    return '$count salita';
  }

  @override
  String videosWatched(int count) {
    return '$count video na napanood';
  }

  @override
  String get noWordsFound => 'Walang nahanap na salita';

  @override
  String get noWordsToReview => 'Walang salita para suriin!';

  @override
  String get playGamesFirst =>
      'Maglaro muna para magsimulang mag-ipon ng datos.';

  @override
  String get showAnswer => 'Ipakita ang Sagot';

  @override
  String get stillLearning => 'Nag-aaral Pa';

  @override
  String get iKnowIt => 'Alam Ko Na!';

  @override
  String get reviewComplete => 'Tapos na ang Review!';

  @override
  String get greatRecall => 'Magaling ang paggunita! Ituloy mo!';

  @override
  String get keepPracticing => 'Patuloy na magsanay — makakaya mo!';

  @override
  String get total => 'Kabuuan';

  @override
  String get reviewAgain => 'Suriin Muli';

  @override
  String get done => 'Tapos';

  @override
  String get dragInstruction =>
      'I-drag ang salitang Ingles sa tamang Filipino!';

  @override
  String get tracing => 'Pagsu-sulat';

  @override
  String traceWord(String word) {
    return 'Sulatin: $word';
  }

  @override
  String get clear => 'Burahin';

  @override
  String get check => 'Suriin';

  @override
  String get whatIsThisWord => 'Ano ang salitang ito?';

  @override
  String moves(int count) {
    return '$count galaw';
  }

  @override
  String matched(int current, int total) {
    return 'Tugma: $current / $total';
  }

  @override
  String get stillLearningSwipe => '← Nag-aaral\nPa';

  @override
  String get iKnowThisSwipe => 'Alam Ko\nIto! →';

  @override
  String get learning => 'Nag-aaral';

  @override
  String get iKnow => 'Alam Ko!';

  @override
  String get amazing => '🎉 Kahanga-hanga!';

  @override
  String get keepGoing => '💪 Ipagpatuloy!';

  @override
  String percentMastered(int percent) {
    return '$percent% na-master';
  }

  @override
  String get reviewWords => 'Suriin ang mga Salita';

  @override
  String get again => 'Ulitin';

  @override
  String get listenAndPick => 'Makinig at Pumili';

  @override
  String get listenEnglish => 'Makinig sa salitang Ingles';

  @override
  String get listenFilipino => 'Makinig sa salitang Filipino';

  @override
  String get pickFilipino => 'Piliin ang tamang Filipino!';

  @override
  String get pickEnglish => 'Piliin ang tamang Ingles!';

  @override
  String get tapSpeakerReplay => '🔊 I-tap ang speaker para i-replay';

  @override
  String get noWordsAvailable =>
      'Walang available na salita para sa kategoryang ito.';

  @override
  String get storyNotFound => 'Hindi Nahanap ang Kwento';

  @override
  String get storyNotFoundMsg => 'Hindi nahanap ang kwento.';

  @override
  String get goBack => 'Bumalik';

  @override
  String get back => 'Bumalik';

  @override
  String get quizNotFound => 'Hindi Nahanap ang Quiz';

  @override
  String questionOf(int current, int total) {
    return 'Tanong $current ng $total';
  }

  @override
  String get equipped => 'Naka-equip';

  @override
  String get tapToEquip => 'I-tap para i-equip';

  @override
  String starsAmount(int count) {
    return '$count bituin';
  }

  @override
  String get viewLeaderboard => 'Tingnan ang Leaderboard';

  @override
  String get detailedAnalytics => 'Detalyadong Analytics';

  @override
  String get starCollection => 'Koleksyon ng Bituin';

  @override
  String get achievements => 'Mga Achievement';

  @override
  String get days => 'araw';

  @override
  String get leaderboard => 'Leaderboard 🏆';

  @override
  String get noEntriesYet =>
      'Wala pang entry.\nMaglaro at matuto ng salita para umakyat sa ranggo!';

  @override
  String activeTotal(int active, int total) {
    return '$active aktibo / $total kabuuan';
  }

  @override
  String get createStudentMsg =>
      'Lalabas dito ang mga estudyante pagkatapos nilang sumali gamit ang class code.\nIbahagi ang code mula sa Manage Classes para imbitahan sila.';

  @override
  String get switchProfile => 'Palitan';

  @override
  String get clothing => 'Damit';

  @override
  String get weather => 'Panahon';

  @override
  String get classroom => 'Silid-aralan';

  @override
  String get transportation => 'Transportasyon';

  @override
  String get emotions => 'Mga Damdamin';

  @override
  String get daysAndTime => 'Mga Araw at Oras';

  @override
  String get speechToText => 'Speech-to-Text';

  @override
  String get fslPractice => 'Pagsasanay sa FSL';

  @override
  String get fslPracticeSubtitle => 'Matuto ng Filipino Sign Language!';

  @override
  String get signToWord => 'Senyas → Salita';

  @override
  String get wordToSign => 'Salita → Senyas';

  @override
  String get signToWordDesc =>
      'Panoorin ang video ng sign language, pagkatapos piliin ang tamang salita.';

  @override
  String get wordToSignDesc =>
      'Tingnan ang salita, pagkatapos piliin kung aling video ang tamang senyas.';

  @override
  String get whatSignIsThis => 'Anong salita ng senyas na ito?';

  @override
  String get whichSignMeans => 'Aling senyas ang ibig sabihin…';

  @override
  String get notEnoughFslVideos =>
      'Hindi sapat ang mga FSL video para sa napiling mga kategorya.';

  @override
  String get fslPracticeTitle => 'Pagsasanay sa Filipino Sign Language';

  @override
  String get fslPracticeDesc =>
      'Panoorin ang mga video ng sign language at subukan ang iyong kaalaman.\nPumili ng mode sa ibaba!';

  @override
  String get parentDashboard => 'Dashboard ng Magulang';

  @override
  String get familyOverview => 'Pangkalahatang-tanaw ng Pamilya';

  @override
  String get yourChildren => 'Ang Iyong mga Anak';

  @override
  String get thisWeek => 'Ngayong Linggo';

  @override
  String get recommendations => 'Mga Rekomendasyon';

  @override
  String get wordsLearned => 'Mga Salitang Natutunan';

  @override
  String get activeToday => 'Aktibo ngayon';

  @override
  String get lastActive => 'Huling aktibo';

  @override
  String get strengthsAndAreas => 'Mga Lakas at Lugar na Pagbutihin';

  @override
  String get createProfile => 'Gumawa ng Profile';

  @override
  String encouragePractice(Object name) {
    return 'Hikayatin si $name na mag-practice';
  }

  @override
  String get keepUpGreatWork => 'Ipagpatuloy ang magaling na trabaho!';

  @override
  String get learnWordsThrough => 'Matuto ng salita sa pamamagitan ng laro! ✨';

  @override
  String get gettingReady => 'Naghahanda...';

  @override
  String get fslFullscreen => 'Buong Screen';

  @override
  String get exitFullscreen => 'Lumabas sa Buong Screen';

  @override
  String get rotateForLandscape =>
      'I-rotate o mag-double-tap para sa landscape';

  @override
  String get hideCaptions => 'Itago ang mga caption';

  @override
  String get showCaptions => 'Ipakita ang mga caption';

  @override
  String get playbackSpeedSettings => 'Mga setting ng bilis ng playback';

  @override
  String get closeFullscreenVideo => 'Isara ang buong screen na video';

  @override
  String get replayFromBeginning => 'I-replay mula sa simula';

  @override
  String get switchToPortrait => 'Palitan sa portrait';

  @override
  String get switchToLandscape => 'Palitan sa landscape';

  @override
  String get videoProgress => 'Progreso ng video';

  @override
  String get pauseVideo => 'I-pause ang video';

  @override
  String get playVideo => 'I-play ang video';

  @override
  String setSpeedTo(String speed) {
    return 'Itakda ang bilis sa ${speed}x';
  }

  @override
  String pinLockedTryAgainIn(String duration) {
    return 'Sobrang dami nang subok. Subukan muli pagkatapos ng $duration.';
  }

  @override
  String get forgotPin => 'Nakalimutan ang PIN?';

  @override
  String get recoveryCodeTitle => 'I-save ang iyong recovery code';

  @override
  String get recoveryCodeSubtitle =>
      'Isulat ito. Kakailanganin mo ito kung makakalimutan mo ang PIN. Hindi na ito maipapakita muli.';

  @override
  String get recoveryCodeConfirm => 'Nai-save ko na';

  @override
  String get enterRecoveryCode => 'Ilagay ang recovery code';

  @override
  String get recoveryCodeWrong => 'Hindi tumugma ang code.';

  @override
  String get recoveryViaEducatorTitle => 'Magtanong sa guro o magulang';

  @override
  String recoveryViaEducatorPrompt(String name) {
    return 'Hayaang ilagay ng guro o magulang ang kanilang PIN upang i-reset ang PIN ni $name.';
  }

  @override
  String get recoveryNoEducator =>
      'Walang guro o magulang na profile sa device na ito. Magpadagdag sa isang nakatatanda, o tanggalin ang profile upang magsimula muli.';

  @override
  String get pinResetSuccess => 'Na-reset ang PIN. Gumawa ng bago.';

  @override
  String get pinChangedSuccess => 'Na-update ang PIN.';

  @override
  String get setNewPin => 'Gumawa ng bagong PIN';

  @override
  String get regenerateRecoveryCode => 'Bumuo muli ng recovery code';

  @override
  String get showRecoveryCode => 'Ipakita ang recovery code';

  @override
  String get setUpProfileTitle => 'I-set Up ang Profile';

  @override
  String get letsSetUpProfile => 'I-set up natin ang iyong profile';

  @override
  String get nameLabel => 'Pangalan';

  @override
  String get pleaseEnterName => 'Mangyaring maglagay ng pangalan';

  @override
  String get nameMinLength =>
      'Ang pangalan ay dapat hindi bababa sa 2 karakter';

  @override
  String get ageOrBirthDate => 'Edad / Petsa ng Kapanganakan';

  @override
  String get tapToSelectBirthDate =>
      'I-tap para pumili ng petsa ng kapanganakan';

  @override
  String get selectBirthDate => 'Pumili ng petsa ng kapanganakan';

  @override
  String get pleaseSelectBirthDate =>
      'Mangyaring pumili ng petsa ng kapanganakan';

  @override
  String yearsOld(int count) {
    return '$count taong gulang';
  }

  @override
  String suggestedLevel(String level) {
    return '✨ Iminumungkahing antas: $level';
  }

  @override
  String get pinProtection => 'Proteksyon ng PIN';

  @override
  String get pinProtectionDescription =>
      'Magdagdag ng 4-digit na PIN para protektahan ang profile na ito';

  @override
  String get enablePinLock => 'I-enable ang PIN lock';

  @override
  String get enterFourDigitPin => 'Maglagay ng 4-digit na PIN';

  @override
  String get pinDigitsOnly => 'Dapat puro numero lang ang PIN';

  @override
  String get iHaveRecoveryCode => 'May recovery code ako';

  @override
  String get saving => 'Sine-save…';

  @override
  String get rolePlayer => 'Manlalaro';

  @override
  String get rolePlayerGuest => 'Guest na Manlalaro';

  @override
  String get rolePlayerProgress => 'Manlalaro (may Progreso)';

  @override
  String get roleStudent => 'Profile ng Mag-aaral (PWD)';

  @override
  String get roleChild => 'Profile ng Bata (PWD)';

  @override
  String get roleTeacher => 'Profile ng Guro';

  @override
  String get roleParent => 'Profile ng Magulang/Tagapag-alaga';

  @override
  String get groupPlayerProfiles => 'Mga Player Profile';

  @override
  String get groupPlayerProfilesDesc =>
      'Para sa paglalaro at pag-aaral tungkol sa PWD awareness.';

  @override
  String get groupClassroom => 'Classroom';

  @override
  String get groupClassroomDesc =>
      'Learning environment na pinamamahalaan ng guro.';

  @override
  String get groupFamily => 'Family Group';

  @override
  String get groupFamilyDesc =>
      'Learning environment na pinamamahalaan ng magulang/tagapag-alaga.';

  @override
  String get rolePlayerTagline => 'Maglaro lang — walang itinatabing progreso';

  @override
  String get rolePlayerGuestTagline =>
      'Maglaro agad — mananatili sa device na ito, hindi naba-back up';

  @override
  String get rolePlayerProgressTagline =>
      'I-save ang iyong XP, streaks at badges at i-back up ang mga ito';

  @override
  String get roleStudentTagline => 'Sumali gamit ang class code';

  @override
  String get roleChildTagline => 'Sumali gamit ang home-group code';

  @override
  String get roleTeacherTagline => 'Gusto kong tumulong';

  @override
  String get roleParentTagline => 'Gusto kong sumuporta';

  @override
  String get roleSetupPlayer =>
      'Guest mode — itinatabi ang progreso sa device na ito lamang.';

  @override
  String get roleSetupPlayerGuest =>
      'Guest mode — malayang maglaro. Mananatili ang progreso sa device na ito at hindi naba-back up.';

  @override
  String get roleSetupPlayerProgress =>
      'Itinatabi ang iyong XP, streaks at badges. Maglagay ng PIN para ma-back up at mai-restore sa ibang device.';

  @override
  String get roleSetupTeacher =>
      'I-set up ang iyong profile para pamahalaan ang mga mag-aaral.';

  @override
  String get roleSetupParent =>
      'I-set up ang iyong profile para suportahan ang iyong anak.';

  @override
  String get pwdAwarenessEntry => 'Matuto tungkol sa PWD awareness';

  @override
  String get pwdAwarenessTitle => 'PWD Awareness';

  @override
  String get pwdAwarenessSubtitle =>
      'Pag-unawa at paggalang sa mga Persons with Disabilities';

  @override
  String youJoined(String name) {
    return 'Sumali ka sa $name.';
  }

  @override
  String get getStarted => 'Magsimula';

  @override
  String get welcomeSlide1Title => 'Matuto ng Filipino Sign Language';

  @override
  String get welcomeSlide1Body =>
      'Masayang flashcards, laro, at FSL videos para mapalawak ang bokabularyo araw-araw.';

  @override
  String get welcomeSlide2Title => 'Para sa bawat mag-aaral';

  @override
  String get welcomeSlide2Body =>
      'Mga mag-aaral, bata, guro, at magulang — bawat isa ay may angkop na setup.';

  @override
  String get welcomeSlide3Title => 'Accessible mula sa disenyo';

  @override
  String get welcomeSlide3Body =>
      'Mataas na contrast, pampabasa (dyslexia), text-to-speech, at reduced-motion na opsyon ay nakapaloob na.';

  @override
  String get splashLoadingResources => 'Niloload ang mga resource...';

  @override
  String get splashPreparingCards => 'Inihahanda ang iyong mga card...';

  @override
  String get splashAlmostReady => 'Halos handa na!';

  @override
  String get wordHuntTitle => 'Word Hunt';

  @override
  String get wordHuntPointCamera => 'Itutok ang camera sa isang bagay!';

  @override
  String get wordHuntTakePhoto => 'Kumuha ng litrato!';

  @override
  String get wordHuntFlipCamera => 'Baligtarin ang camera';

  @override
  String get wordHuntLooking => 'Tinitingnan ang iyong litrato…';

  @override
  String get wordHuntFoundWords =>
      'May nahanap akong mga salita — pumili ng isa!';

  @override
  String get wordHuntNoneFound =>
      'Walang nahanap na salita sa litrato. Lumapit pa at subukan muli!';

  @override
  String get wordHuntRetake => 'Bagong litrato';

  @override
  String get wordHuntNoCamera =>
      'Walang camera ang device na ito, kaya hindi magagamit ang Word Hunt.';

  @override
  String get wordHuntCameraDenied =>
      'Kailangan ng Word Hunt ang camera para mahanap ang mga bagay sa paligid mo. Paki-payagan ang camera.';

  @override
  String get wordHuntCameraError =>
      'Hindi masimulan ang camera. Pakisubukan muli.';

  @override
  String get wordHuntNewWord => 'May nahanap kang bagong salita! +1 ⭐';

  @override
  String get wordHuntGreatFind => 'May nahanap kang bagong salita! Galing!';

  @override
  String get wordHuntSpeakEnglish => 'Ingles';

  @override
  String get wordHuntSpeakFilipino => 'Filipino';

  @override
  String get wordHuntFlashcards => 'Flashcards';

  @override
  String get wordHuntMeaning => 'Kahulugan';
}
