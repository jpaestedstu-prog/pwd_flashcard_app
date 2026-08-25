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
  String get mastery => 'Kabihasaan';

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
  String get games => 'Mga Laro';

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
  String get titles => 'Mga Titulo';

  @override
  String get sounds => 'Mga Tunog';

  @override
  String get effects => 'Mga Epekto';

  @override
  String get themeOverriddenByContrast =>
      'Naka-on ang High Contrast, kaya hindi magbabago ang mga kulay mula sa temang ito hangga\'t hindi mo ito i-off.';

  @override
  String get themeOverriddenByDyslexia =>
      'Naka-on ang Dyslexia-friendly, kaya hindi magbabago ang mga kulay mula sa temang ito hangga\'t hindi mo ito i-off.';

  @override
  String get effectPlaysGently =>
      'Naka-on ang Reduced Motion, kaya marahan itong ipapakita.';

  @override
  String get recommendedForYou => 'Inirerekomenda para sa iyo';

  @override
  String get goodToKnow => 'Dapat mong malaman';

  @override
  String itemNotReady(String name) {
    return 'Hindi pa handa ang $name.';
  }

  @override
  String starsRefunded(int count) {
    return '⭐ Naibalik ang $count bituin — may binili kang hindi pa handa, kaya isinauli namin ito.';
  }

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

  @override
  String get wordHuntMyFinds => 'Mga Nahanap Ko';

  @override
  String get wordHuntCollectionTitle => '🎒 Mga Nahanap Ko';

  @override
  String wordHuntFoundOf(int found, int total) {
    return '$found sa $total salita ang nahanap';
  }

  @override
  String wordHuntStarsToday(int earned, int cap) {
    return '$earned sa $cap bituin ngayong araw';
  }

  @override
  String get wordHuntCollectionEmpty =>
      'Wala ka pang nahahanap na salita. Itutok ang camera sa isang bagay sa paligid mo!';

  @override
  String get wordHuntStartHunting => 'Simulan ang paghahanap';

  @override
  String get wordHuntStillToFind => 'Hahanapin pa';

  @override
  String get wordHuntFound => 'Nahanap';

  @override
  String get wordHuntTargets => 'Subukang hanapin:';

  @override
  String get wordHuntNewBadge => 'BAGO';

  @override
  String get wordHuntAllFound =>
      'Nahanap mo na lahat ng salitang kilala ng camera. Ang galing! 🏆';

  @override
  String wordHuntSpokenFound(int count, String words) {
    return 'May nahanap akong $count salita: $words';
  }

  @override
  String get wordHuntSayTakePhoto => 'Sabihin ang \"kuha\"';

  @override
  String wordHuntFoundTarget(String words) {
    return 'Nahanap mo! Nasa listahan mo ang $words.';
  }

  @override
  String wordHuntFoundTargets(String words) {
    return 'Nahanap mo! Nasa listahan mo ang $words.';
  }

  @override
  String wordHuntStreakDays(int days) {
    return '$days araw na sunod-sunod na paghahanap';
  }

  @override
  String wordHuntFindsToday(int count) {
    return '$count ang nahanap ngayong araw';
  }

  @override
  String wordHuntNextBadge(int remaining, String badge) {
    return '$remaining pa para sa $badge';
  }

  @override
  String get wordHuntCameraBusyReason =>
      'Itinuturo ng aktibidad na ito ang camera sa paligid mo, kaya kailangan nitong sarilinin ang camera. Titigil muna ang head control habang bukas ito.';

  @override
  String get customizeProgress => 'I-customize ang progreso';

  @override
  String get customize => 'I-customize';

  @override
  String get signs => 'Mga Senyas';

  @override
  String bestStreak(int days) {
    return 'pinakamahusay $days';
  }

  @override
  String starsLeftToSpend(int count) {
    return '$count natitira';
  }

  @override
  String get streakCalendar => 'Kalendaryo ng Sunod-sunod';

  @override
  String get certificates => 'Mga Sertipiko';

  @override
  String get advancedAnalytics => 'Mga Natuklasan sa Pagkatuto';

  @override
  String get firstBadgePrompt =>
      'Magpatuloy sa pag-aaral para makuha ang iyong unang badge!';

  @override
  String badgesEarned(int earned, int total) {
    return '$earned sa $total ang nakuha';
  }

  @override
  String get reading => 'Pagbasa';

  @override
  String get storiesRead => 'Nabasang kuwento';

  @override
  String get perfectQuizzes => '3-bituing pagsusulit';

  @override
  String get signLanguage => 'Wikang Senyas';

  @override
  String get signsWatched => 'Napanood';

  @override
  String get signsCanMake => 'Kaya kong isenyas';

  @override
  String get signsConfirmed => 'Kinumpirma ng guro';

  @override
  String get daysActive => 'Araw na aktibo';

  @override
  String get minutesStudied => 'Minuto';

  @override
  String get newWords => 'Bagong salita';

  @override
  String get weeklyEmpty =>
      'Wala pa ngayong linggo — maglaro o magbasa ng kuwento at lalabas ito dito.';

  @override
  String get hearMyProgress => 'Pakinggan ang aking progreso';

  @override
  String get studyMinutes => 'Minuto ng Pag-aaral';

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
    return 'Ikaw ay nasa antas $level, $title. Natutunan mo na ang $words na salita at nakakuha ng $stars bituin. Ang iyong streak ay $streak araw, at ang pinakamahusay mo ay $best araw. Naglaro ka na ng $games laro.';
  }

  @override
  String spokenWeekSummary(int days, int games, int stars) {
    return 'Ngayong linggo ay aktibo ka sa $days araw, naglaro ng $games laro at nakakuha ng $stars bituin.';
  }

  @override
  String get chartLess => 'Kaunti';

  @override
  String get chartMore => 'Marami';

  @override
  String get chartDifficultyHistory => 'Kasaysayan ng Antas ng Hirap';

  @override
  String get chartReviewHeatmap => 'Mapa ng Aktibidad sa Pagbabalik-aral';

  @override
  String get chartStarsEarnedVsSpent => 'Nakuha kumpara sa nagastos';

  @override
  String get chartStarsAvailable => 'Magagamit';

  @override
  String get chartStarsSpent => 'Nagastos';

  @override
  String get catShortAnimals => 'Hayop';

  @override
  String get catShortColors => 'Kulay';

  @override
  String get catShortNumbers => 'Bilang';

  @override
  String get catShortBody => 'Katawan';

  @override
  String get catShortFood => 'Pagkain';

  @override
  String get catShortFamily => 'Pamilya';

  @override
  String get catShortClothing => 'Damit';

  @override
  String get catShortWeather => 'Panahon';

  @override
  String get catShortClassroom => 'Klase';

  @override
  String get catShortTransport => 'Biyahe';

  @override
  String get catShortEmotions => 'Damdamin';

  @override
  String get catShortDays => 'Araw';

  @override
  String get catShortActions => 'Kilos';

  @override
  String get gameShortMatch => 'Tugma';

  @override
  String get gameShortSpell => 'Spelling';

  @override
  String get gameShortQuiz => 'Quiz';

  @override
  String get gameShortMemory => 'Memory';

  @override
  String get gameShortDrag => 'Drag';

  @override
  String get gameShortPronun => 'Bigkas';

  @override
  String get gameShortSentence => 'Sentence';

  @override
  String get gameShortStory => 'Kwento';

  @override
  String get gameShortTrace => 'Sulat';

  @override
  String get gameShortFsl => 'FSL';

  @override
  String get gameShortJigsaw => 'Palaisipan';

  @override
  String get gameShortPicWord => 'Larawan';

  @override
  String get gameShortYesNo => 'Oo/Hindi';

  @override
  String get gameShortOdd => 'Kaiba';

  @override
  String get gameShortLetter => 'Letra';

  @override
  String get chartActivityMapTitle => 'Mapa ng Aktibidad 📅';

  @override
  String get chartActivityMapSubtitle =>
      'Araw-araw na pag-aaral — huling 8 linggo';

  @override
  String get chartCategoryMasteryTitle => 'Saklaw ng Kategorya 🎯';

  @override
  String get chartDifficultyHigh => 'Mataas (≥80%)';

  @override
  String get chartDifficultyMedium => 'Katamtaman (50-80%)';

  @override
  String get chartDifficultyLow => 'Mababa (<50%)';

  @override
  String get chartNoGameScores => 'Wala pang iskor sa laro. Maglaro muna! 🎮';

  @override
  String get chartGamePerformanceTitle => 'Pagganap sa Laro 🎮';

  @override
  String get chartGamePerformanceSubtitle =>
      'Karaniwang iskor (%) bawat uri ng laro';

  @override
  String get chartWordsLearnedTitle => 'Natutunang Salita 📈';

  @override
  String get chartWordsLearnedSubtitle => 'Kabuuang salita — huling 30 araw';

  @override
  String get chartStarsOverviewTitle => 'Buod ng Mga Bituin ⭐';

  @override
  String get chartNoStars => 'Wala pang bituin. Magpatuloy sa pag-aaral! ✨';

  @override
  String get chartStudyTimeTitle => 'Oras ng Pag-aaral ⏱️';

  @override
  String get chartStudyTimeSubtitle =>
      'Minuto ng pag-aaral bawat araw (huling 7 araw)';

  @override
  String get chartMinutesShort => 'min';

  @override
  String get chartCategoryMasterySubtitle =>
      'Ang iyong progreso sa lahat ng kategorya ng bokabularyo';

  @override
  String get chartDifficultySubtitle =>
      'Kung paano nagbabago ang iyong katumpakan sa paglipas ng panahon';

  @override
  String get chartDifficultyEmpty =>
      'Maglaro muna upang makita ang\nkasaysayan ng antas ng hirap!';

  @override
  String get gameTipDifficulty =>
      '💡 Tip: Subukan ang iba\'t ibang antas ng hirap!';

  @override
  String get gameTipDaily =>
      '🔥 Ang paglalaro araw-araw ay nagpapatibay ng memorya!';

  @override
  String get gameTipReview =>
      '🌟 Balikan ang mga salitang namali para mas mabilis matuto!';

  @override
  String get gameTipStartEasy =>
      '🎯 Magsimula sa Madali, tapos taasan kapag handa na!';

  @override
  String get gameTipVariety =>
      '🧩 Bawat laro ay may sariling paraan ng pagtuturo — subukan lahat!';

  @override
  String get gameTipTimed => '⏱️ Mainam ang timed mode para sa bilis!';

  @override
  String get playTogether => 'Maglaro Nang Sabay';

  @override
  String get playTogetherSubtitle =>
      'Makipagkarera sa kaibigan — para lang sa saya!';

  @override
  String get playTogetherSemantics =>
      'Maglaro Nang Sabay. Makipagkarera sa kaibigan online o sa device na ito, para lang sa saya.';

  @override
  String gamesPickedForYou(int count) {
    return '$count larong pinili para sa iyo';
  }

  @override
  String get badgeNew => 'BAGO';

  @override
  String get notPlayedYet => 'Hindi pa nalalaro.';

  @override
  String yourBestStars(int best) {
    return 'Pinakamataas mo: $best sa 3 bituin.';
  }

  @override
  String playGameSemantics(String game, String description) {
    return 'Laruin ang $game. $description';
  }

  @override
  String get chooseYourDifficulty => 'Piliin ang antas ng hirap';

  @override
  String get beatTheClock => 'Talunin ang Orasan ⏱️';

  @override
  String get beatTheClockSubtitle => '60 segundo para matapos!';

  @override
  String get lastPlayed => 'Huling nilaro';

  @override
  String get startWithAllCategories => 'Simulan sa Lahat ng Kategorya';

  @override
  String get startWithOneCategory => 'Simulan sa 1 Kategorya';

  @override
  String startWithCategories(int count) {
    return 'Simulan sa $count Kategorya';
  }

  @override
  String get comingSoon => 'Malapit nang dumating';

  @override
  String gameReviewTitle(String game) {
    return 'Balik-aral sa $game';
  }

  @override
  String reviewCorrectCount(int count) {
    return '$count tama';
  }

  @override
  String reviewWrongCount(int count) {
    return '$count mali';
  }

  @override
  String get yourAnswerLabel => 'Sagot mo: ';

  @override
  String get paused => 'Naka-pause';

  @override
  String get resumeGame => 'Ituloy';

  @override
  String get iNeedABreak => 'Kailangan Ko ng Pahinga';

  @override
  String get restartGame => 'Ulitin';

  @override
  String get restartGameTitle => 'Ulitin ang larong ito?';

  @override
  String get restartGameBody =>
      'Mawawala ang kasalukuyang progreso mo sa round na ito.';

  @override
  String get quitToGames => 'Bumalik sa Mga Laro';

  @override
  String get pauseLabel => 'I-pause';

  @override
  String get resultAmazing => 'Napakahusay! 🌟';

  @override
  String get resultAmazingHint =>
      'Superstar ka! Subukan ang mas mahirap na antas!';

  @override
  String get resultGreat => 'Magaling! 🎉';

  @override
  String get resultGreatHint => 'Ang galing mo! Ituloy mo lang!';

  @override
  String get resultGood => 'Magandang Pagsubok! 👍';

  @override
  String get resultGoodHint => 'Natututo ka! Balikan ang mga salitang namali.';

  @override
  String get resultKeepPracticing => 'Magpatuloy sa Pagsasanay! 💪';

  @override
  String get resultKeepPracticingHint =>
      'Bawat pagsubok ay nagpapalakas sa iyo! Subukan muli!';

  @override
  String get fslPracticeHeading => 'Pagsasanay sa Filipino Sign Language';

  @override
  String get fslSignToWord => 'Senyas → Salita';

  @override
  String get fslSignToWordSubtitle =>
      'Manood ng video ng senyas, tapos piliin ang tamang salita.';

  @override
  String get fslWordToSign => 'Salita → Senyas';

  @override
  String get fslWordToSignSubtitle =>
      'Tingnan ang salita, tapos piliin kung aling video ang tamang senyas.';

  @override
  String get fslSignIt => 'Isenyas Mo!';

  @override
  String get fslSignItSubtitle =>
      'Panoorin ang senyas, gayahin ito sa camera, tapos suriin ang sarili.';

  @override
  String get fslSignItSubtitleGaze =>
      'Panoorin ang senyas, gayahin ito sa camera, tapos suriin ang sarili. Gumagamit ng kamay — huminto muna ang head control dito.';

  @override
  String get fslVideosComingSoon =>
      'Dinadagdag pa ang mga video ng FSL. Subukan muna ang FSL Diksyunaryo.';

  @override
  String get resumeBadge => 'NAKA-PAUSE';

  @override
  String get resumeTitle => 'Ituloy kung saan ka huminto?';

  @override
  String resumeBody(int round, int total) {
    return 'Huminto ka sa round $round sa $total.';
  }

  @override
  String get resumeContinue => 'Ituloy';

  @override
  String get resumeStartOver => 'Magsimula Muli';

  @override
  String resumeRoundProgress(int round, int total) {
    return 'Round $round sa $total';
  }

  @override
  String get notEnoughWords => 'Kulang ang mga salita';

  @override
  String notEnoughWordsBody(String game) {
    return 'Pumili pa ng kategorya para maglaro ng $game.';
  }

  @override
  String get backToGames => 'Bumalik sa Mga Laro';

  @override
  String get fslPracticeIntro =>
      'Manood ng mga video ng senyas at subukin ang iyong kaalaman.\nPumili ng mode sa ibaba!';

  @override
  String starsEarnedChip(int count) {
    return '+$count ⭐ nakuha';
  }

  @override
  String gameResultsSemantics(int score, int total, int rating, int stars) {
    return 'Resulta ng laro: $score sa $total, marka $rating sa 3 bituin, $stars bituing nakuha';
  }

  @override
  String get jigsawPuzzle => 'Palaisipang Jigsaw';

  @override
  String get pictureWord => 'Larawan-Salita';

  @override
  String get yesOrNo => 'Oo o Hindi';

  @override
  String get oddOneOut => 'Ang Naiiba';

  @override
  String get firstLetter => 'Unang Letra';

  @override
  String get gameDescWordMatch => 'Itugma ang larawan sa tamang salita!';

  @override
  String get gameDescSpellingBee =>
      'Ayusin ang mga letra para mabaybay ang salita!';

  @override
  String get gameDescMemoryMatch => 'Hanapin ang magkatugmang pares ng card!';

  @override
  String get gameDescDragAndDrop =>
      'Hilahin ang bawat salita sa katugmang larawan!';

  @override
  String get gameDescFlashcardQuiz =>
      'I-swipe pakanan kung alam mo, pakaliwa para matuto!';

  @override
  String get gameDescPronunciation => 'Makinig at piliin ang tamang salita!';

  @override
  String get gameDescSentenceBuilder =>
      'Punan ang nawawalang salita sa pangungusap!';

  @override
  String get gameDescStoryQuiz =>
      'Magbasa ng kuwento at sagutin ang mga tanong!';

  @override
  String get gameDescTracing => 'Bakatin ang mga letra ng bawat salita!';

  @override
  String get gameDescFslPractice => 'Matuto ng Filipino Sign Language!';

  @override
  String get gameDescJigsawPuzzle => 'Buuin ang palaisipang larawan!';

  @override
  String get gameDescPictureWord =>
      'Itugma ang larawan sa salita sa pakikinig!';

  @override
  String get gameDescYesOrNo =>
      'Tama ba ang salitang ito? Pindutin ang Oo o Hindi!';

  @override
  String get gameDescOddOneOut => 'Pindutin ang salitang hindi kabilang!';

  @override
  String get gameDescFirstLetter =>
      'Piliin ang letrang pinagsimulan ng salita!';

  @override
  String get difficultyDescEasy =>
      'Kaunting tanong, maraming pahiwatig — mainam sa nagsisimula!';

  @override
  String get difficultyDescMedium =>
      'Balanseng hamon — ang karaniwang karanasan';

  @override
  String get difficultyDescHard =>
      'Maraming tanong, kaunting pahiwatig — subukin ang galing mo!';

  @override
  String get suggestStarting =>
      'Nagsisimula ka pa lang! Magsisimula tayo sa madaling tanong.';

  @override
  String suggestScopeGame(String game, int percent) {
    return 'Sa $game, ang huli mong katumpakan ay $percent%.';
  }

  @override
  String suggestScopeRecent(int percent) {
    return 'Sa mga huli mong laro, ang katumpakan mo ay $percent%.';
  }

  @override
  String suggestScopeLifetime(int percent) {
    return 'Ang katumpakan mo ay $percent%.';
  }

  @override
  String get suggestTierEasy =>
      'Magsanay tayo sa mas madaling tanong para lumakas ang loob mo!';

  @override
  String get suggestTierMedium =>
      'Isang balanseng hamon para patuloy kang umunlad!';

  @override
  String get suggestTierHard =>
      'Ang galing mo — panahon na para sa tunay na hamon!';

  @override
  String gameRoundHeader(String game, int current, int total) {
    return '$game  •  $current/$total';
  }

  @override
  String get findPictureFor => 'Hanapin ang larawan ng:';

  @override
  String get whichWordMatches => 'Aling salita ang tugma?';

  @override
  String get whichDoesNotBelong => 'Alin ang hindi kabilang?';

  @override
  String get startsWithWhichLetter => 'ay nagsisimula sa aling letra?';

  @override
  String get isThisPrompt => 'Ito ba ay…';

  @override
  String get hearIt => 'Pakinggan';

  @override
  String heardTryAgain(String spoken) {
    return 'Narinig: \"$spoken\" — subukan muli!';
  }

  @override
  String cameraWordsFound(int count) {
    return '📷 Nakahanap ka na ng $count salita gamit ang camera!';
  }

  @override
  String oddOneOutHint(int count, String category) {
    return '$count ay $category';
  }

  @override
  String get allPiecesPlaced => 'Kumpleto na ang mga piraso! 🎉';

  @override
  String get jigsawHowTo => 'Pindutin ang piraso, tapos pindutin ang puwang';

  @override
  String movesUsed(int count) {
    return 'Galaw: $count';
  }

  @override
  String knownCount(int count) {
    return '$count alam';
  }

  @override
  String stillLearningCount(int count) {
    return '$count pinag-aaralan pa';
  }

  @override
  String answerChoiceSemantics(String answer) {
    return 'Pagpipiliang sagot: $answer';
  }

  @override
  String answerSemantics(String answer) {
    return 'Sagot: $answer';
  }

  @override
  String get correctAnswerSuffix => ', tamang sagot';

  @override
  String get wrongAnswerSuffix => ', maling sagot';

  @override
  String questionEnglishFor(String word) {
    return 'Tanong: Ano ang salitang Ingles para sa $word?';
  }

  @override
  String findPictureForSemantics(String word) {
    return 'Hanapin ang larawan ng: $word';
  }

  @override
  String pictureOfSemantics(String word) {
    return 'Larawan ng $word';
  }

  @override
  String whichWordMatchesSemantics(String word) {
    return 'Aling salita ang tugma sa larawang ito? $word';
  }

  @override
  String firstLetterQuestion(String word) {
    return 'Tanong: sa aling letra nagsisimula ang salitang $word?';
  }

  @override
  String yesNoQuestion(String pictureWord, String english, String filipino) {
    return 'Tanong: ang larawang ito ba ng $pictureWord ay ang salitang $english, $filipino? Sagutin ng Oo o Hindi.';
  }

  @override
  String flashcardSemantics(String english, String filipino, String category) {
    return 'Flashcard: $english, $filipino, kategoryang $category. I-swipe pakanan para sa Alam Ko, pakaliwa para sa Pinag-aaralan Pa';
  }

  @override
  String flashcardProgressSemantics(
    int current,
    int total,
    int known,
    int learning,
  ) {
    return 'Card $current sa $total, $known alam, $learning pinag-aaralan pa';
  }

  @override
  String draggableWordSemantics(String word) {
    return 'Salitang mahihila: $word, hilahin sa katugmang salitang Filipino';
  }

  @override
  String dropTargetMatched(String filipino, String english) {
    return 'Tugma: ang $filipino ay $english';
  }

  @override
  String dropTargetEmpty(String filipino) {
    return 'Puwang: $filipino, wala pang katugma';
  }

  @override
  String slotFilled(int position, String letter) {
    return 'Puwang $position: $letter, pindutin para tanggalin';
  }

  @override
  String slotEmpty(int position) {
    return 'Puwang $position: walang laman';
  }

  @override
  String letterAlreadyUsed(String letter) {
    return 'Letrang $letter, nagamit na';
  }

  @override
  String letterTapToPlace(String letter) {
    return 'Letrang $letter, pindutin para ilagay';
  }

  @override
  String get playSoundEnglish =>
      'Patugtugin: pindutin para marinig ang salitang Ingles';

  @override
  String get playSoundFilipino =>
      'Patugtugin: pindutin para marinig ang salitang Filipino';

  @override
  String roundScoreSemantics(int current, int total, int score) {
    return 'Round $current sa $total, marka $score';
  }

  @override
  String spelledSoFar(String letters) {
    return 'Sagot: $letters';
  }

  @override
  String get wordComplete => 'kumpleto na ang salita';

  @override
  String oddOneOutQuestion(String words) {
    return 'Tanong: aling salita ang hindi kabilang? Ang mga salita ay $words.';
  }

  @override
  String oddOneOutHintSpoken(int count, String category) {
    return ' $count sa kanila ay $category.';
  }

  @override
  String get fslWatchAndChoose =>
      'Panoorin ang video ng senyas at piliin ang tamang salita';

  @override
  String get fslWhatWordIsThisSign => 'Anong salita ang senyas na ito?';

  @override
  String get fslWhichSignMeans => 'Aling senyas ang nangangahulugang…';

  @override
  String videoChoice(int index) {
    return 'Pagpipiliang video $index';
  }

  @override
  String dropTargetHolding(String filipino, String word) {
    return 'Puwang: $filipino, naglalaman ng $word (mali)';
  }

  @override
  String dropTargetEmptyHint(String filipino) {
    return 'Puwang: $filipino, walang laman, ilagay dito ang katugmang Ingles';
  }

  @override
  String memoryCardMatched(String word) {
    return 'Natugmang card: $word';
  }

  @override
  String memoryCardShowing(String word) {
    return 'Card na nagpapakita ng: $word';
  }

  @override
  String get memoryCardFaceDown =>
      'Nakatiklop na card, pindutin para baliktarin';

  @override
  String get breakButton => 'Pahinga';

  @override
  String get iNeedABreakTooltip => 'Kailangan ko ng pahinga';

  @override
  String get replayVideo => 'I-replay';

  @override
  String get showMe => 'Ipakita';

  @override
  String get answerYes => 'Oo';

  @override
  String get answerNo => 'Hindi';

  @override
  String jigsawPuzzleProgress(int current, int total) {
    return 'Palaisipan $current sa $total';
  }

  @override
  String jigsawCompleteFor(String word) {
    return 'Buuin ang palaisipan para sa: $word';
  }

  @override
  String jigsawPieceSemantics(int row, int column) {
    return 'Piraso sa hanay $row, hilera $column, pindutin para ilagay';
  }

  @override
  String memoryProgressSemantics(int matched, int total, int moves) {
    return 'Natugma ang $matched sa $total pares sa $moves galaw';
  }

  @override
  String jigsawPiecePlaced(int row, int column) {
    return 'Piraso sa hanay $row, hilera $column, tamang nailagay';
  }

  @override
  String get gazePrev => 'Nakaraan';

  @override
  String get gazeNext => 'Susunod';

  @override
  String get gazeChoose => 'Piliin';

  @override
  String get gazeFlip => 'Baliktarin';

  @override
  String get gazePlace => 'Ilagay';

  @override
  String get gazeUndo => 'Bawiin';

  @override
  String showMeTitle(String word) {
    return 'Ipakita — $word';
  }

  @override
  String get collabLearnTogether => 'Matuto nang magkasama!';

  @override
  String get collabTeamTagline =>
      'Isang koponan kayo — magkasama kayong nagpupuntos.';

  @override
  String get collabPlayer2NameLabel => 'Pangalan ng Player 2:';

  @override
  String get collabPlayer2NameSemantics => 'Pangalan ng Player 2';

  @override
  String get collabPlayer2NameHint => 'I-type ang pangalan...';

  @override
  String get collabChooseActivity => 'Pumili ng Activity';

  @override
  String get collabEnterPlayer2Name => 'Maglagay ng pangalan ng Player 2';

  @override
  String get collabNoWords => 'Walang salitang magagamit ngayon';

  @override
  String get collabHearAgain => 'Pakinggan ulit';

  @override
  String get collabWordRelay => 'Word Relay';

  @override
  String get collabPictureGuess => 'Hulaan ang Larawan';

  @override
  String get collabSignChallenge => 'Sign Challenge';

  @override
  String get collabStoryBuilder => 'Story Builder';

  @override
  String get collabWordRelayDesc => 'Mag-spell ng salita nang isa-isang letra';

  @override
  String get collabPictureGuessDesc =>
      'Isang manlalaro ang mag-describe, ang isa ang huhula';

  @override
  String get collabSignChallengeDesc =>
      'I-sign ang salita, tapos hulaan ang sign ng kapareha mo';

  @override
  String get collabStoryBuilderDesc =>
      'Gumawa ng kwento nang magkasama, isang pangungusap bawat isa';

  @override
  String get collabTeam => 'Koponan';

  @override
  String collabPromptDescribe(String name, String partner) {
    return '$name, ipakita ang salita kay $partner';
  }

  @override
  String collabPromptNextLetter(String name) {
    return '$name, ano ang susunod na letra?';
  }

  @override
  String collabPromptAddSentence(String name) {
    return '$name, idagdag ang susunod na pangungusap';
  }

  @override
  String collabPromptGuess(String name) {
    return '$name, hulaan ang salita';
  }

  @override
  String collabAnswerWas(String word) {
    return 'Ang sagot ay $word';
  }

  @override
  String get collabHintClue => 'Magsulat ng pahiwatig...';

  @override
  String get collabHintLetter => 'Isang letra...';

  @override
  String get collabHintSentence => 'Idagdag ang susunod na pangungusap...';

  @override
  String get collabHintGuess => 'Hulaan ang salita...';

  @override
  String get collabWordToSpell => 'Salitang i-spell:';

  @override
  String get collabWordToDescribe => 'Salitang i-describe:';

  @override
  String get collabSignToShow => 'Sign na ipakita:';

  @override
  String get collabWhatIsTheWord => 'Anong salita?';

  @override
  String get collabClueLabel => 'Pahiwatig:';

  @override
  String get collabBuildStoryTogether => 'Buuin ang kwento nang magkasama!';

  @override
  String get collabStartTheStory => 'Magsimula ng kwento!';

  @override
  String get collabWatchTheSign => 'Panoorin ang sign';

  @override
  String collabPhraseBig(String word) {
    return 'Malaki ang $word.';
  }

  @override
  String collabPhraseISee(String word) {
    return 'May nakita akong $word.';
  }

  @override
  String collabPhraseHappy(String word) {
    return 'Masaya ang $word.';
  }

  @override
  String collabPhraseWeLike(String word) {
    return 'Gusto namin ang $word.';
  }

  @override
  String get collabGreatTeamwork => 'Magaling kayong dalawa!';

  @override
  String collabPointsTogether(int score, int total) {
    return '$score sa $total puntos na magkasama';
  }

  @override
  String get collabSubmitAnswer => 'Isumite';

  @override
  String collabSetUpForYou(String list) {
    return 'Inayos para sa iyo: $list.';
  }

  @override
  String get collabAdaptTapToAnswer => 'pindutan lang';

  @override
  String get collabAdaptReadAloud => 'may boses';

  @override
  String get collabAdaptBiggerButtons => 'malalaking pindutan';

  @override
  String get collabAdaptShorter => 'mas maikli';

  @override
  String get collabLeaveTitle => 'Aalis na ba sa activity na ito?';

  @override
  String get collabLeaveBody =>
      'Nakatago ang inyong progreso — maaari kayong magpatuloy mamaya.';

  @override
  String get collabLeaveConfirm => 'Umalis';

  @override
  String get collabKeepPlaying => 'Magpatuloy';

  @override
  String collabClueCategory(String category) {
    return 'Kategorya: $category';
  }

  @override
  String collabClueFirstLetter(String letter) {
    return 'Nagsisimula ito sa $letter.';
  }

  @override
  String collabClueLength(int count) {
    return 'May $count na letra ito.';
  }

  @override
  String collabPassSpoken(String name) {
    return 'O ipakita — ipasa kay $name';
  }
}
