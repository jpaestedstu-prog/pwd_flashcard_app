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
  String get accessibility => 'Aksesibilidad';

  @override
  String get audio => 'Audio';

  @override
  String get about => 'Tungkol';

  @override
  String get highContrastMode => 'Mataas na Contrast';

  @override
  String get darkMode => 'Madilim na Mode';

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
  String get soundPackNeedsSound =>
      'Naka-off ang Sound Effects, kaya hindi maririnig ang pack na ito hangga’t hindi mo ito bubuksan.';

  @override
  String get recommendedForYou => 'Inirerekomenda para sa iyo';

  @override
  String get seeIt => 'Tingnan';

  @override
  String get hearIt => 'Pakinggan';

  @override
  String previewOf(String name) {
    return 'Silip sa $name';
  }

  @override
  String starsToGo(int count) {
    return '$count pang bituin ang kailangan';
  }

  @override
  String get keepEarning => 'Ipagpatuloy ang pagkolekta';

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
      'Buburahin nito ang bawat profile sa tablet na ito — mga mag-aaral, guro at magulang — kasama ang lahat ng progreso at setting nila. Hindi na ito maibabalik. Hindi nabubura ang mga kopya online: para matanggal din ang mga record online ng isang profile, burahin muna ito sa Manage Profiles.';

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
  String get version => 'Bersyon 1.2.3 • Thesis Capstone Project';

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
  String get classroomMode => 'Mode ng Silid-Aralan';

  @override
  String get monitorStudents => 'I-monitor ang lahat ng mag-aaral sa real time';

  @override
  String get classroomView => 'Silid-Aralan';

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
  String get voiceNavigation => 'Paggabay sa Pamamagitan ng Boses';

  @override
  String get voiceNavigationDesc => 'I-announce ang mga screen nang malakas';

  @override
  String get adaptiveDifficulty => 'Adaptive na Antas ng Hirap';

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
  String get accessibilitySetup => 'Pag-setup ng Aksesibilidad';

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
  String get importLabel => 'I-import';

  @override
  String get exportLabel => 'I-export';

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
    return 'Sigurado ka bang gusto mong tanggalin ang “$name”? Hindi na ito maibabalik.';
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
    return 'Wala pang FSL video para sa “$word”.';
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
  String get leaderboard => 'Talaan ng mga Nangunguna 🏆';

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
  String get groupClassroom => 'Silid-Aralan';

  @override
  String get groupClassroomDesc =>
      'Learning environment na pinamamahalaan ng guro.';

  @override
  String get groupFamily => 'Pangkat ng Pamilya';

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
  String get pwdAwarenessTitle => 'Kamalayan sa PWD';

  @override
  String get pwdAwarenessSubtitle =>
      'Pag-unawa at paggalang sa mga Taong May Kapansanan';

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
  String get wordHuntFlashcards => 'Mga Flashcard';

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
  String get wordHuntSayTakePhoto => 'Sabihin ang “kuha”';

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
  String get gameShortMemory => 'Memorya';

  @override
  String get gameShortDrag => 'I-drag';

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
  String get resultAmazingHintNoLevels =>
      'Superstar ka! Tama ang lahat ng sagot mo!';

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
  String heardTryAgain(String spoken) {
    return 'Narinig: “$spoken” — subukan muli!';
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
  String get collabSignChallenge => 'Hamon sa Senyas';

  @override
  String get collabStoryBuilder => 'Pagbuo ng Kuwento';

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

  @override
  String get settingOn => 'Naka-on';

  @override
  String get settingOff => 'Naka-off';

  @override
  String get settingHighContrastDesc =>
      'Mas matingkad na kulay at mas makapal na border';

  @override
  String get settingDarkModeDesc => 'Mas magaan sa mata kapag madilim';

  @override
  String get settingDyslexiaDesc =>
      'Kulay-krema na background, Lexend na font, mas maluwag na pagitan ng letra';

  @override
  String get settingReducedMotionDesc => 'Bawasan ang mga animation';

  @override
  String get settingVoiceNavOnDesc =>
      'Binabasa nang malakas ang mga screen at button';

  @override
  String get settingVoiceNavOffDesc =>
      'Buksan para sa mga may kapansanan sa paningin';

  @override
  String get settingAdaptiveOnDesc =>
      'Awtomatikong nagmumungkahi ng antas batay sa progreso';

  @override
  String get settingAdaptiveOffDesc => 'Manu-mano lamang ang pagpili ng antas';

  @override
  String get settingGazeControlDesc =>
      'Walang-kamay: igalaw ang ulo o kumurap para pumili';

  @override
  String get settingGamepadDesc =>
      'Mag-navigate gamit ang Bluetooth gamepad, may binibigkas na gabay';

  @override
  String get settingFullscreenOnDesc =>
      'Nakatago ang nav bar at mga app bar — hanggang patayin mo ito';

  @override
  String get settingFullscreenOffDesc =>
      'Itago ang nav bar at mga app bar para sa klase o TV display';

  @override
  String get settingSlowMotionOnDesc =>
      'Kalahating bilis ang galaw ng mga laro at flashcard';

  @override
  String get settingSlowMotionOffDesc =>
      'Pabagalin ang galaw ng laro at mga flashcard';

  @override
  String get settingLearningAssistOnDesc =>
      'Nagpapakita ng “bakit” na pahiwatig at 50/50 na tulong sa pagsusulit';

  @override
  String get settingLearningAssistOffDesc =>
      'Payak na pagsusulit — walang pahiwatig o paliwanag';

  @override
  String get settingTtsDesc => 'Pakinggan ang mga salitang binibigkas';

  @override
  String get settingSoundEffectsDesc => 'Mga tunog at tugon ng laro';

  @override
  String get settingSttOnDesc => 'Nakabukas ang voice input sa mga laro';

  @override
  String get settingSttOffDesc =>
      'Pindutin para buksan ang voice input sa mga laro';

  @override
  String get settingCompanionOnDesc =>
      'Lumulutang na katuwang — pindutin anumang oras para sa tulong';

  @override
  String get settingCompanionOffDesc =>
      'Buksan ang iyong lumulutang na katuwang sa pag-aaral';

  @override
  String get settingVocabReviewDesc =>
      'Nagpapaalala na balikan ang mga mahihirap na salita';

  @override
  String get settingBackupRestoreDesc =>
      'I-save o ibalik ang lahat ng datos ng app';

  @override
  String get settingRecoveryCodeDesc =>
      'Ibalik ang profile na ito sa bagong device';

  @override
  String get settingCloudAccountDesc =>
      'Mag-sign in gamit ang email para maibalik sa kahit anong device';

  @override
  String get settingClassroomModeDesc =>
      'Bantayan ang lahat ng mag-aaral nang real-time';

  @override
  String get settingAccessibilitySetupDesc =>
      'Ulitin ang wizard ng aksesibilidad';

  @override
  String get settingManageProfilesDesc =>
      'Burahin ang mga profile na nakaimbak sa device na ito';

  @override
  String get settingChildControlsDesc =>
      'Magtakda ng limitasyon sa oras at nilalaman';

  @override
  String get settingReplayTutorialsDesc =>
      'Ipakita muli ang mga gabay sa lahat ng screen';

  @override
  String get settingPurposeDesc =>
      'Interaktibong app para sa pagpapalawak ng talasalitaan ng mga mag-aaral na PWD gamit ang mga flashcard, laro, at Filipino Sign Language.';

  @override
  String get settingResearchDataOnDesc =>
      'Nagpapadala ng anonymous na datos ng crash at paggamit sa pangkat ng pananaliksik';

  @override
  String get settingResearchDataOffDesc =>
      'Naka-off — walang ipinapadalang usage statistics o crash report';

  @override
  String settingDailyMissionDesc(int count) {
    return '$count salita bawat araw';
  }

  @override
  String get settingGazeControlTitle => 'Kontrol gamit ang Tingin (Preview)';

  @override
  String get settingGamepadTitle => 'Game Controller';

  @override
  String get settingSectionPresentation => 'Presentasyon';

  @override
  String get settingSectionLearningModes => 'Mga Mode ng Pagkatuto';

  @override
  String get settingSlowMotionTitle => 'Mabagal na Galaw';

  @override
  String get settingLearningAssistTitle => 'Tulong sa Pagkatuto';

  @override
  String get settingDailyMissionTitle => 'Dami ng Araw-araw na Misyon';

  @override
  String get settingCompanionTitle => 'AI Companion';

  @override
  String get settingVocabReviewTitle => 'Paalala sa Pagbabalik-aral';

  @override
  String get settingSectionMyDay => 'Ang Araw Ko';

  @override
  String get settingRoutineTitle => 'Routine';

  @override
  String get settingRoutineOnDesc =>
      'Lalabas ang Ang Araw Ko sa home mo — planuhin ang araw mo, hakbang-hakbang';

  @override
  String get settingRoutineOffDesc =>
      'Buksan ang Ang Araw Ko para planuhin ang araw mo, hakbang-hakbang';

  @override
  String get settingSectionData => 'Datos';

  @override
  String get settingBackupRestoreTitle => 'Backup at Restore';

  @override
  String get settingRecoveryCodeTitle => 'Cloud Recovery Code';

  @override
  String get settingCloudAccountTitle => 'Backup at Pag-link ng Account';

  @override
  String get settingAccessibilitySetupTitle =>
      'Ulitin ang Pag-setup ng Aksesibilidad';

  @override
  String get settingManageProfilesTitle => 'Pamahalaan ang mga Profile';

  @override
  String get settingChildControlsTitle => 'Kontrol ng Magulang';

  @override
  String get settingReplayTutorialsTitle => 'Ulitin ang mga Tutorial';

  @override
  String get settingPurposeTitle => 'Layunin';

  @override
  String get settingResearchDataTitle => 'Tumulong na mapabuti ang app';

  @override
  String get fontSizeSmall => 'Maliit';

  @override
  String get fontSizeNormal => 'Karaniwan';

  @override
  String get fontSizeLarge => 'Malaki';

  @override
  String get fontSizeExtraLarge => 'Napakalaki';

  @override
  String get speechSpeedVerySlow => 'Napakabagal';

  @override
  String get speechSpeedSlow => 'Mabagal';

  @override
  String get speechSpeedNormal => 'Karaniwan';

  @override
  String get speechSpeedFast => 'Mabilis';

  @override
  String speechSpeedSpoken(String label, int step, int stops) {
    return '$label, $step sa $stops';
  }

  @override
  String setFontSizeTo(String size) {
    return 'Itakda ang laki ng font sa $size';
  }

  @override
  String get changeLabel => 'Baguhin';

  @override
  String get changePinTitle => 'Baguhin ang PIN';

  @override
  String get setProfilePinTitle => 'Itakda ang PIN ng Profile';

  @override
  String get pinPrompt =>
      'Pumili ng 4-digit na PIN para protektahan ang iyong profile.';

  @override
  String get disabilityVisual => 'Kapansanan sa Paningin';

  @override
  String get disabilityHearing => 'Kapansanan sa Pandinig';

  @override
  String get disabilityMotor => 'Kapansanan sa Paggalaw';

  @override
  String get disabilityCognitive => 'Pag-iisip/Pagkatuto';

  @override
  String get disabilityMultiple => 'Maraming Kapansanan';

  @override
  String get disabilityNone => 'Walang Espesyal na Pangangailangan';

  @override
  String get disabilityCognitiveFull => 'Kapansanan sa Pag-iisip/Pagkatuto';

  @override
  String get disabilityVisualDesc =>
      'Hirap sa paningin, malabong mata, o color blindness';

  @override
  String get disabilityHearingDesc => 'Hirap sa pandinig o bingi';

  @override
  String get disabilityMotorDesc =>
      'Hirap sa maliliit na galaw ng kamay o sa paghawak';

  @override
  String get disabilityCognitiveDesc => 'Dyslexia, ADHD, o hirap sa pagkatuto';

  @override
  String get disabilityMultipleDesc =>
      'Pinagsamang mga pangangailangan sa aksesibilidad';

  @override
  String get disabilityNoneDesc =>
      'Karaniwang setting, walang espesyal na pagbabago';

  @override
  String get roleNameStudent => 'Mag-aaral';

  @override
  String get roleNameTeacher => 'Guro';

  @override
  String get roleNameParent => 'Magulang';

  @override
  String get roleNameChild => 'Bata';

  @override
  String get roleNamePlayer => 'Manlalaro';

  @override
  String dashboardTitleForPerson(String name) {
    return 'Dashboard ni $name';
  }

  @override
  String dashboardTitleForRole(String role) {
    return 'Dashboard ng $role';
  }

  @override
  String eduWelcome(String name) {
    return 'Kumusta, $name!';
  }

  @override
  String get eduSubtitleParent => 'Subaybayan ang pag-aaral ng iyong mga anak';

  @override
  String get eduSubtitleTeacher => 'Pamahalaan ang progreso ng iyong klase';

  @override
  String get eduQuickActions => 'Mabilisang Aksyon';

  @override
  String get eduMore => 'Higit Pa';

  @override
  String get eduContent => 'Nilalaman';

  @override
  String get eduAssessmentsProgress => 'Mga Pagsusulit at Progreso';

  @override
  String get eduResearch => 'Pananaliksik';

  @override
  String get eduNeedsHelp => 'Kailangan ng Tulong';

  @override
  String get eduInactive7d => 'Hindi aktibo 7 araw+';

  @override
  String get eduActiveToday => 'Aktibo Ngayon';

  @override
  String get eduReports => 'Mga Ulat';

  @override
  String get eduWeeklySummary => 'Lingguhang buod';

  @override
  String get eduParentalControlsTile => 'Kontrol ng Magulang';

  @override
  String get eduLimitsSafety => 'Limitasyon at kaligtasan';

  @override
  String get eduCards => 'Mga Kard';

  @override
  String get eduBrowseDecks => 'Tingnan ang mga deck';

  @override
  String get eduShareCode => 'Ibahagi ang Code';

  @override
  String get eduInviteChild => 'Imbitahan ang iyong anak';

  @override
  String get eduInviteStudents => 'Imbitahan ang mga estudyante';

  @override
  String get eduTvCast => 'TV Cast';

  @override
  String get eduMessages => 'Mga Mensahe';

  @override
  String get eduTeacherNotes => 'Tala ng Guro';

  @override
  String get eduParentNotes => 'Tala ng Magulang';

  @override
  String get eduAssessments => 'Mga Pagsusulit';

  @override
  String get eduAssignTasks => 'Magbigay ng Gawain';

  @override
  String get eduTrackProgress => 'Subaybayan ang Progreso';

  @override
  String get eduManageGroups => 'Pamahalaan ang mga Grupo';

  @override
  String get eduManageClasses => 'Pamahalaan ang mga Klase';

  @override
  String get eduRosterProgress => 'Talaan at progreso';

  @override
  String get eduAnalytics => 'Analytics';

  @override
  String get eduClassInsights => 'Pananaw sa klase';

  @override
  String get eduClassroomTile => 'Silid-aralan';

  @override
  String get eduLiveSession => 'Live na sesyon';

  @override
  String get eduWorksheets => 'Mga Worksheet';

  @override
  String get eduExperimentSetup => 'Setup ng Eksperimento';

  @override
  String get eduSusSurvey => 'SUS Survey';

  @override
  String get eduResearchExport => 'Pag-export ng Datos ng Pananaliksik';

  @override
  String get eduDashboardCtaSub =>
      'Detalyadong pananaw, alerto, at mga rekomendasyon';

  @override
  String get eduNoChildrenDesc =>
      'Gumawa ng home group, pagkatapos ibahagi ang code sa iyong anak para makasali.';

  @override
  String get eduNoStudentsDesc =>
      'Gumawa ng klase, pagkatapos ibahagi ang code sa iyong mga estudyante para makasali.';

  @override
  String get assessPreTest => 'Panimulang Pagsusulit';

  @override
  String get assessPostTest => 'Panghuling Pagsusulit';

  @override
  String get assessCategoryMastery => 'Kasanayan sa Kategorya';

  @override
  String get assessCustom => 'Sariling Pagsusulit';

  @override
  String get assessPreTestDesc => 'Sukatin ang alam mo bago mag-aral';

  @override
  String get assessPostTestDesc =>
      'Tingnan kung gaano ka na umunlad pagkatapos mag-aral';

  @override
  String get assessCategoryMasteryDesc =>
      'Subukan ang kasanayan mo sa isang kategorya';

  @override
  String get assessCustomDesc => 'Pagsusulit na gawa ng guro';

  @override
  String get formatMultipleChoice => 'Maraming Pagpipilian';

  @override
  String get formatFillInBlank => 'Punan ang Patlang';

  @override
  String get formatMatchPairs => 'Pagtambalin';

  @override
  String get formatTrueFalse => 'Tama o Mali';

  @override
  String get formatSignVideo => 'Panoorin ang Senyas';

  @override
  String get signQuestionPrompt => 'Panoorin ang senyas. Aling salita ito?';

  @override
  String get assessCenterTitle => 'Sentro ng Pagsusulit';

  @override
  String get assessCenterLearnerSub => 'Sukatin ang iyong pag-unlad';

  @override
  String get assessCenterEducatorSub =>
      'Gumawa, magtakda, at subaybayan ang mga pagsusulit';

  @override
  String get assessPrePostSection => 'Panimula at Panghuling Pagsusulit';

  @override
  String get assessPrePostLearnerBlurb =>
      'Kumuha ng panimulang pagsusulit bago mag-aral, at panghuli pagkatapos — makikita mo ang iyong pag-unlad!';

  @override
  String get assessPrePostEducatorBlurb =>
      'Ang mga mag-aaral ang kukuha nito. Itakda muna ang panimulang pagsusulit, saka ang panghuli pagkatapos ng mga aralin — lalabas dito ang pag-unlad.';

  @override
  String get assessMasterySection => 'Mga Pagsusulit sa Kategorya';

  @override
  String get assessMasteryBlurb =>
      'Subukan ang alam mo sa bawat kategorya ng bokabularyo';

  @override
  String get assessAssignedToYou => 'Itinakda Sa Iyo';

  @override
  String get assessRecentResults => 'Mga Huling Resulta';

  @override
  String get assessSeeAll => 'Tingnan Lahat';

  @override
  String get assessClassReport => 'Ulat ng Klase';

  @override
  String get assessYourAttempts => 'Ang Iyong mga Pagsubok';

  @override
  String get assessAttemptCounts => 'Ito ang Bibilangin';

  @override
  String get assessAttemptsOne => '1 pagsubok';

  @override
  String assessAttemptsMany(int count) {
    return '$count na pagsubok';
  }

  @override
  String get assessNoLearnersYet => 'Wala pang mag-aaral';

  @override
  String get assessNoLearnersDesc =>
      'Ibahagi ang code ng klase o home group, saka itakda ang panimulang pagsusulit.';

  @override
  String get assessNeedPreTestFirst => 'Tapusin muna ang panimulang pagsusulit';

  @override
  String get assessKeepStudying => 'Magpatuloy sa pag-aaral';

  @override
  String assessKeepStudyingFor(String what) {
    return 'Magpatuloy sa pag-aaral — $what';
  }

  @override
  String assessMoreDays(int count) {
    return '$count pang araw';
  }

  @override
  String get assessOneMoreDay => '1 pang araw';

  @override
  String assessMoreStudyDays(int count) {
    return '$count pang araw ng pag-aaral';
  }

  @override
  String get assessOneMoreStudyDay => '1 pang araw ng pag-aaral';

  @override
  String assessAndJoin(String a, String b) {
    return '$a at $b';
  }

  @override
  String get assessRetakeLocked =>
      'Tapos na — hilingin sa guro na buksan itong muli';

  @override
  String get assessReadyForPost => 'Handa na sa panghuling pagsusulit';

  @override
  String get assessPostAssigned => 'Nakatakda ang panghuling pagsusulit';

  @override
  String get assessPreOutstanding => 'Kulang pa ang panimulang pagsusulit';

  @override
  String assessPostIn(String wait) {
    return 'Tapos na ang panimula · iminumungkahing ibigay ang panghuli pagkalipas ng $wait';
  }

  @override
  String get assessPreFromEducator => 'Ibibigay ito ng iyong guro o magulang';

  @override
  String get assessPostFromEducator =>
      'Bubuksan ito ng iyong guro o magulang pagkatapos ng mga aralin';

  @override
  String get assessClipsPreparing => 'Inihahanda ang mga video ng senyas…';

  @override
  String get assessClipsMissingTitle =>
      'Kailangan ng internet ang mga video ng senyas';

  @override
  String get assessClipsMissingBody =>
      'May mga video ng sign language ang pagsusulit na ito na wala pa sa tablet. Kumonekta sa Wi‑Fi, saka subukang muli. Hindi pa nagsisimula ang pagsusulit.';

  @override
  String get assessClipsTryAgain => 'Subukang muli';

  @override
  String get assessClipsGoBack => 'Bumalik';

  @override
  String get eduClassReport => 'Ulat ng Klase';

  @override
  String get supportSectionTitle => 'Suporta sa Mag-aaral';

  @override
  String supportSectionBlurb(String category) {
    return 'Paano gumagana ang $category para sa mag-aaral na ito. Mababago ito anumang oras.';
  }

  @override
  String get supportGroupCommunication => 'Komunikasyon at wika';

  @override
  String get supportGroupCommunicationDesc =>
      'Paano tumatanggap ng wika ang mag-aaral. Pumili ng isa.';

  @override
  String get supportGroupHearingExtras => 'Suporta sa pandinig';

  @override
  String get supportGroupVisualAccess => 'Pagbasa ng screen';

  @override
  String get supportGroupVisualAccessDesc =>
      'Paano nakikita ng mag-aaral ang nasa screen. Pumili ng isa.';

  @override
  String get supportGroupVisualExtras => 'Suporta sa paningin';

  @override
  String get supportGroupInput => 'Paggamit ng app';

  @override
  String get supportGroupInputDesc =>
      'Paano gumagalaw ang mag-aaral sa app. Pumili ng isa.';

  @override
  String get supportGroupMotorExtras => 'Suporta sa paggalaw';

  @override
  String get supportGroupThinking => 'Suporta sa pagkatuto';

  @override
  String get supportGroupThinkingDesc =>
      'Paano dapat ibigay ang mga panuto. Pumili ng isa.';

  @override
  String get supportGroupCognitiveExtras => 'Suporta sa pag-unawa';

  @override
  String get supportGroupOther => 'Iba pang suporta';

  @override
  String get supportGroupOptional => 'Opsyonal na suporta';

  @override
  String get supportGroupExtrasDesc => 'Idagdag ang anumang nakakatulong.';

  @override
  String get supportGroupNoneDesc => 'Walang kinakailangan dito.';

  @override
  String get supportSignFsl => 'Filipino Sign Language (FSL)';

  @override
  String get supportSignFslDesc =>
      'Mga senyas na ginagamit sa mga paaralan ng Bingi sa Pilipinas. FSL ang mga video ng app.';

  @override
  String get supportSignAsl => 'American Sign Language (ASL)';

  @override
  String get supportSignAslDesc =>
      'Mga senyas na ginagamit sa mga Amerikanong Bingi.';

  @override
  String get supportSignSee => 'Signing Exact English (SEE)';

  @override
  String get supportSignSeeDesc =>
      'Mga senyas na sumusunod sa ayos ng salitang Ingles, isa-isa.';

  @override
  String get supportCuedSpeech => 'Cued Speech';

  @override
  String get supportCuedSpeechDesc =>
      'Mga hugis ng kamay malapit sa bibig para makita ang tunog ng salita.';

  @override
  String get supportOralLipReading => 'Pagsasalita at Pagbasa ng Labi';

  @override
  String get supportOralLipReadingDesc =>
      'Natututo sa pagmamasid ng bibig at sa natitirang pandinig.';

  @override
  String get supportWrittenCaptions => 'Nakasulat lang';

  @override
  String get supportWrittenCaptionsDesc =>
      'Nagbabasa sa halip na senyas. Itatago ang mga video ng senyas.';

  @override
  String get supportCaptionsAlwaysOn => 'Laging may caption';

  @override
  String get supportCaptionsAlwaysOnDesc =>
      'May teksto ang bawat video at kuwento. Nakatala sa profile para sa mga guro.';

  @override
  String get supportVisualAlerts => 'Kislap sa halip na tunog';

  @override
  String get supportVisualAlertsDesc =>
      'Kumikislap ang screen at may badge sa halip na tunog.';

  @override
  String get supportAudioFirst => 'Pakinggan muna (screen reader)';

  @override
  String get supportAudioFirstDesc =>
      'Binibigkas ang lahat; pangalawa lang ang screen.';

  @override
  String get supportLargePrint => 'Malaking titik';

  @override
  String get supportLargePrintDesc =>
      'Napakalaking titik, kaunting bagay bawat screen.';

  @override
  String get supportSpokenAnswerChoices =>
      'Basahin nang malakas ang mga pagpipilian';

  @override
  String get supportSpokenAnswerChoicesDesc =>
      'Binibigkas ang bawat pagpipilian bago pumili ang mag-aaral.';

  @override
  String get supportInputTouch => 'Pagpindot';

  @override
  String get supportInputTouchDesc => 'Pinipindot ang screen gaya ng dati.';

  @override
  String get supportInputGaze => 'Tingin ng mata (walang kamay)';

  @override
  String get supportInputGazeDesc =>
      'Ginagamit ang app sa pamamagitan ng tingin.';

  @override
  String get supportInputSwitch => 'Switch o gamepad';

  @override
  String get supportInputSwitchDesc =>
      'Gumagamit ng Bluetooth gamepad o switch sa halip na pagpindot.';

  @override
  String get supportSimplifiedLanguage => 'Simpleng salita';

  @override
  String get supportSimplifiedLanguageDesc =>
      'Maiikling pangungusap at pang-araw-araw na salita.';

  @override
  String get supportPicturePrompts => 'Suporta sa larawan';

  @override
  String get supportPicturePromptsDesc =>
      'May larawan ang bawat panuto. Nakatala sa profile para sa mga guro.';

  @override
  String get supportStepByStep => 'Isa-isang hakbang';

  @override
  String get supportStepByStepDesc =>
      'Isang panuto sa bawat pagkakataon, may malinaw na susunod.';

  @override
  String get supportRepeatInstructions => 'Ulitin ang mga panuto';

  @override
  String get supportRepeatInstructionsDesc =>
      'Maaaring ulitin ang panuto kahit ilang beses. Nakatala sa profile para sa mga guro.';

  @override
  String get supportFewerChoices => 'Mas kaunting pagpipilian';

  @override
  String get supportFewerChoicesDesc =>
      'Dalawang pagpipilian sa halip na apat.';

  @override
  String get supportExtendedTestTime => 'Dagdag na oras sa pagsusulit';

  @override
  String get supportExtendedTestTimeDesc =>
      'Kalahating dagdag na oras sa mga pagsusulit na may takdang oras.';

  @override
  String get reportForEducatorsTitle => 'Para sa mga guro at magulang';

  @override
  String get reportForEducatorsDesc =>
      'Binabasa ng ulat na ito ang buong klase. Nasa Sentro ng Pagsusulit ang sarili mong mga resulta.';

  @override
  String get reportCheckNewResults => 'Tingnan kung may bagong resulta';

  @override
  String get reportNoLearnersDesc =>
      'Ibahagi ang code ng klase o home group, saka itakda ang panimulang pagsusulit. Mapupuno ang ulat habang dumarating ang mga resulta.';

  @override
  String get reportAssignWork => 'Magtakda ng gawain';

  @override
  String get reportGainSection => 'Pag-unlad ayon sa accessibility';

  @override
  String get reportGainSectionDesc =>
      'Karaniwan ng mga mag-aaral na natapos ang dalawang pagsusulit. Hiwalay na binibilang ang may kulang pa.';

  @override
  String get reportGainNone =>
      'Wala pang mag-aaral na nakatapos ng dalawang pagsusulit, kaya wala pang maikukumpara. Itakda muna ang panimulang pagsusulit.';

  @override
  String get reportItemsSection => 'Pinakamahihirap na tanong';

  @override
  String get reportItemsSectionDesc =>
      'Lahat ng tanong na sinagot ng klase, simula sa pinakamahirap. Kapag “Hati ang klase” at mababa ang paghihiwalay, kadalasan ang pagkakasulat ang problema, hindi ang salita.';

  @override
  String get reportItemsNone =>
      'Wala pang naitalang sagot. Mapupuno ito habang tinatapos ng mga mag-aaral ang pagsusulit.';

  @override
  String get reportAttemptsSection => 'Mga Pagsubok';

  @override
  String get reportAttemptsSectionDesc =>
      'Ang pinakahuling pagsubok sa bawat pagsusulit ang ginagamit sa pagsukat ng pag-unlad.';

  @override
  String get reportMetricPre => 'Panimula';

  @override
  String get reportMetricPost => 'Panghuli';

  @override
  String get reportMetricGain => 'Pag-unlad';

  @override
  String get reportMetricNormalized => 'Normalisado';

  @override
  String get reportMetricMeasured => 'Nasukat';

  @override
  String get reportMetricWaiting => 'Naghihintay pa';

  @override
  String get reportMetricMedian => 'Panggitna';

  @override
  String get reportMetricSeparation => 'Paghihiwalay';

  @override
  String get reportMetricOftenAnswered => 'Madalas na sagot';

  @override
  String get reportAttemptNone => 'wala';

  @override
  String reportAttemptEarlier(int count) {
    return '(+$count nauna)';
  }

  @override
  String get reportDifficultyEasy => 'Madali para sa klase';

  @override
  String get reportDifficultyMost => 'Nakuha ng karamihan';

  @override
  String get reportDifficultySplit => 'Hati ang klase';

  @override
  String get reportDifficultyHard => 'Mahirap';

  @override
  String get reportDifficultyNobody => 'Halos walang nakakuha';

  @override
  String get reportNeedsReview =>
      'Hindi mas mahusay dito ang pinakamagagaling mong mag-aaral — suriin muli ang pagkakasulat.';

  @override
  String reportGainSemantics(
    String category,
    int count,
    int pre,
    int post,
    int gain,
  ) {
    return '$category. $count mag-aaral ang nasukat. Karaniwang panimula $pre porsiyento, panghuli $post porsiyento, pag-unlad $gain porsiyento.';
  }

  @override
  String reportGainNoneSemantics(String category, int count) {
    return '$category. Wala pang nakatapos ng dalawang pagsusulit. $count ang naghihintay.';
  }

  @override
  String reportItemCorrectSemantics(int correct, int attempts, int percent) {
    return '$correct sa $attempts ang tama, $percent porsiyento';
  }

  @override
  String reportItemWrongSemantics(String answer) {
    return 'Pinakamadalas na maling sagot, $answer';
  }

  @override
  String get reportItemReviewSemantics =>
      'Maaaring kailangang baguhin ang pagkakasulat nito';

  @override
  String get rxTitle => 'Pag-export ng Datos ng Pananaliksik';

  @override
  String get rxHeader => 'Export para sa Pananaliksik ng Tesis';

  @override
  String get rxIntro =>
      'Mag-export ng datos na walang pangalan para sa mga mag-aaral na may tsek sa ibaba. Napapalitan ng ID ang mga pangalan, at pareho ang ID sa bawat export, kaya maaaring pagsamahin ang mga file mula sa iba’t ibang device.';

  @override
  String get rxParticipants => 'Mga Kalahok';

  @override
  String get rxParticipantsHint =>
      'Ang mga mag-aaral lang na may tsek ang isasama sa export. Naka-tsek na ang iyong sariling mga klase at home group.';

  @override
  String rxSelectedCount(int selected, int total) {
    return '$selected sa $total ang napili';
  }

  @override
  String get rxTickAll => 'Lagyan lahat ng tsek';

  @override
  String get rxUntickAll => 'Alisin lahat ng tsek';

  @override
  String get rxYourGroups => 'Sa iyong mga klase at home group';

  @override
  String get rxOtherLearners => 'Iba pang mag-aaral sa tablet na ito';

  @override
  String get rxOtherLearnersHint =>
      'Wala sa iyong mga klase o home group — hindi kasama maliban kung lagyan mo ng tsek.';

  @override
  String get rxDataAvailable => 'Makukuhang Datos';

  @override
  String get rxLearners => 'Mga mag-aaral';

  @override
  String get rxGameScores => 'Mga iskor sa laro';

  @override
  String get rxSessions => 'Mga naitalang sesyon';

  @override
  String get rxAssessmentResults => 'Mga resulta ng pagsusulit';

  @override
  String get rxMoodEntries => 'Mga tala ng damdamin';

  @override
  String get rxGainReports => 'Mga ulat ng pag-unlad';

  @override
  String get rxFilesIncluded => 'Mga Kasamang File';

  @override
  String get rxFileStudentsOverview =>
      'Datos at kabuuang estadistika ng bawat mag-aaral';

  @override
  String get rxFileLearningCurves =>
      'Mga iskor sa laro sa paglipas ng panahon (para sa trend analysis)';

  @override
  String get rxFileSessionPatterns =>
      'Mga tala ng sesyon ayon sa araw ng linggo';

  @override
  String get rxFileCategoryMastery =>
      'Porsiyento ng kahusayan sa bawat kategorya ng bawat mag-aaral';

  @override
  String get rxFileWordAccuracy =>
      'Katumpakan sa bawat salita (spaced repetition)';

  @override
  String get rxFileAssessmentResults =>
      'Mga iskor sa panimula at panghuling pagsusulit at ang pag-unlad';

  @override
  String get rxFileMoodData => 'Mga tala ng damdamin kaugnay ng mga gawain';

  @override
  String get rxFileAdaptiveDifficulty =>
      'Mga pagbabago sa hirap at katumpakan sa paglipas ng panahon';

  @override
  String get rxFileSummaryStats =>
      'Buod ng mahahalagang bilang para sa mabilisang pagtingin';

  @override
  String rxExportButton(int count) {
    return 'I-export ang Datos ($count mag-aaral)';
  }

  @override
  String get rxGenerating => 'Ginagawa…';

  @override
  String get rxNobodyTicked =>
      'Lagyan ng tsek ang kahit isang mag-aaral para makapag-export.';

  @override
  String get rxNoLearners =>
      'Wala pang profile ng mag-aaral. Lalabas sila rito kapag sumali na sila sa iyong klase o home group.';

  @override
  String get rxExported => 'Matagumpay na na-export ang datos ng pananaliksik!';

  @override
  String rxExportFailed(String error) {
    return 'Hindi na-export: $error';
  }

  @override
  String qpFilipinoWordFor(String word) {
    return 'Ano ang salitang Filipino para sa “$word”?';
  }

  @override
  String qpEnglishWordFor(String word) {
    return 'Ano ang salitang Ingles para sa “$word”?';
  }

  @override
  String qpFillBlank(String word) {
    return 'Punan ang patlang: Ang salin sa Filipino ng “$word” ay _____.';
  }

  @override
  String qpTrueFalse(String english, String shown) {
    return 'Tama o Mali: Ang “$english” ay “$shown” sa Filipino.';
  }

  @override
  String qpInFilipinoIs(String english, String shown) {
    return 'Ang “$english” sa Filipino ay “$shown”';
  }

  @override
  String qpMatch(String word) {
    return 'Itugma: “$word” → ?';
  }

  @override
  String qpTypeFilipino(String word) {
    return 'Isulat ang salitang Filipino para sa “$word”:';
  }

  @override
  String qpTypeEnglish(String word) {
    return 'Isulat ang salitang Ingles para sa “$word”:';
  }

  @override
  String get qpTrue => 'Tama';

  @override
  String get qpFalse => 'Mali';

  @override
  String get testQuitTooltip => 'Ihinto ang pagsusulit';

  @override
  String get testQuitTitle => 'Ihinto ang Pagsusulit?';

  @override
  String get testQuitBody =>
      'Mawawala ang iyong mga sagot. Sigurado ka bang gusto mong huminto?';

  @override
  String get testQuitContinue => 'Magpatuloy';

  @override
  String get testQuitConfirm => 'Huminto';

  @override
  String testQuestionOf(int current, int total) {
    return 'Tanong $current sa $total';
  }

  @override
  String testProgressSemantics(int percent) {
    return 'Pag-usad: $percent porsiyento na ang tapos';
  }

  @override
  String get testShowHint => 'Ipakita ang Pahiwatig';

  @override
  String get testHideHint => 'Itago ang Pahiwatig';

  @override
  String get testFinish => 'Tapusin ang Pagsusulit';

  @override
  String get testNext => 'Susunod na Tanong';

  @override
  String get testTypeHere => 'Isulat dito ang iyong sagot...';

  @override
  String get testSubmit => 'Ipasa ang Sagot';

  @override
  String testHintAnswer(String answer) {
    return 'Tamang sagot: $answer';
  }

  @override
  String get testCorrect => 'Tama!';

  @override
  String get testNotQuite => 'Hindi pa tama';

  @override
  String testTheAnswerIs(String answer) {
    return 'Ang tamang sagot ay: $answer';
  }

  @override
  String testMinutesLeft(int minutes) {
    return '$minutes minuto na lang';
  }

  @override
  String testSecondsLeft(int seconds) {
    return '$seconds segundo na lang';
  }

  @override
  String get gradeExcellent => 'Napakahusay';

  @override
  String get gradeVeryGood => 'Lubhang Mabuti';

  @override
  String get gradeGood => 'Mabuti';

  @override
  String get gradeNeedsImprovement => 'Kailangan pang Pagbutihin';

  @override
  String get gradeKeepPracticing => 'Patuloy na Magsanay';

  @override
  String get supportShortLipReading => 'Pagbasa ng labi';

  @override
  String get supportShortWritten => 'Nakasulat';

  @override
  String get supportShortAudioFirst => 'Tunog muna';

  @override
  String get supportShortGaze => 'Tingin';

  @override
  String get supportShortTouch => 'Pindot';

  @override
  String sumComplete(String type) {
    return 'Tapos na ang $type!';
  }

  @override
  String get sumTime => 'Oras';

  @override
  String get sumCorrect => 'Tama';

  @override
  String get sumWrong => 'Mali';

  @override
  String get sumCategoryBreakdown => 'Iskor ayon sa Kategorya';

  @override
  String get sumQuestionReview => 'Pagsusuri ng mga Tanong';

  @override
  String get sumBackToHub => 'Bumalik sa Sentro';

  @override
  String get sumViewAnalytics => 'Tingnan ang Analytics';

  @override
  String sumCategorySemantics(String category, int percent) {
    return '$category: $percent porsiyento';
  }

  @override
  String get resTitle => 'Analytics ng Pagsusulit';

  @override
  String resCompletedCount(int count) {
    return '$count pagsusulit ang natapos';
  }

  @override
  String get resEmpty => 'Wala pang natatapos na pagsusulit';

  @override
  String get resTakeOne => 'Kumuha ng Pagsusulit';

  @override
  String get resTrend => 'Takbo ng Iskor sa Paglipas ng Panahon';

  @override
  String get resCategoryMastery => 'Kahusayan ayon sa Kategorya';

  @override
  String get resHistory => 'Kasaysayan ng mga Pagsusulit';

  @override
  String get resLearningGain => 'Pag-unlad sa Pagkatuto';

  @override
  String get resPerCategoryGains => 'Pag-unlad ayon sa Kategorya';

  @override
  String get resAvgScore => 'Karaniwang Iskor';

  @override
  String get resAssessments => 'Mga Pagsusulit';

  @override
  String get resTotalTime => 'Kabuuang Oras';

  @override
  String get resNeedTwo =>
      'Tapusin ang 2 o higit pang pagsusulit para makita ang takbo';

  @override
  String resHistoryLine(String date, int count, String duration) {
    return '$date • $count tanong • $duration';
  }

  @override
  String resAttemptSemantics(int percent, String date) {
    return '$percent porsiyento noong $date';
  }

  @override
  String get resAttemptCountsSemantics =>
      'Ito ang pagsusulit na ginagamit sa pagsukat ng iyong pag-unlad';

  @override
  String resSatWith(String supports) {
    return 'Kinuha nang may $supports';
  }

  @override
  String gainImproved(int pre, int post, int gain) {
    return 'Umangat ang iskor mula $pre% hanggang $post% (+$gain%)';
  }

  @override
  String gainSame(int pre) {
    return 'Nanatili ang iskor sa $pre%';
  }

  @override
  String gainChanged(int pre, int post, int gain) {
    return 'Nagbago ang iskor mula $pre% hanggang $post% ($gain%)';
  }

  @override
  String get hubResultsTooltip =>
      'Tingnan ang mga resulta at analytics ng pagsusulit';

  @override
  String get hubCreate => 'Gumawa';

  @override
  String get hubAssign => 'Magtakda';

  @override
  String get hubTrack => 'Subaybayan';

  @override
  String get hubQuizBuilder => 'Tagabuo ng Quiz';

  @override
  String get hubQuizBuilderDesc =>
      'Gumawa ng sariling quiz mula sa anumang flashcard';

  @override
  String get hubCustomAssessments => 'Sariling mga Pagsusulit';

  @override
  String get hubCreateCustomTooltip => 'Gumawa ng bagong sariling pagsusulit';

  @override
  String get hubNoCustom => 'Wala pang sariling pagsusulit';

  @override
  String get hubNoCustomHint =>
      'Pindutin ang + para gumawa ng isa para sa iyong mga mag-aaral';

  @override
  String get hubViewAllResults => 'Tingnan ang lahat ng resulta';

  @override
  String hubGainSemantics(String summary) {
    return 'Ulat ng pag-unlad. $summary';
  }

  @override
  String get hubGainTitle => 'Ulat ng Pag-unlad sa Pagkatuto';

  @override
  String hubCardLockedSemantics(String type, String reason) {
    return '$type. Nakakandado. $reason';
  }

  @override
  String hubCardDoneSemantics(String type, int percent) {
    return '$type. Tapos na. Huling iskor $percent porsiyento. Pindutin para ulitin.';
  }

  @override
  String hubCardNewSemantics(String type) {
    return '$type. Hindi pa nakukuha. Pindutin para magsimula.';
  }

  @override
  String hubBest(int percent) {
    return 'Pinakamataas: $percent%';
  }

  @override
  String get hubTapToStart => 'Pindutin para magsimula';

  @override
  String hubMasteryTriedSemantics(String category, int percent, int count) {
    return 'Pagsusulit sa kahusayan: $category. Pinakamataas na iskor: $percent porsiyento, $count pagkuha. Pindutin para magsimula.';
  }

  @override
  String hubMasteryNewSemantics(String category) {
    return 'Pagsusulit sa kahusayan: $category. Hindi pa nasusubukan. Pindutin para magsimula.';
  }

  @override
  String get hubNotTested => 'Hindi pa nasusubok';

  @override
  String hubQuestionCount(int count) {
    return '$count tanong';
  }

  @override
  String get hubOverdue => 'Lampas na sa takdang araw';

  @override
  String hubDue(String date) {
    return 'Takdang araw: $date';
  }

  @override
  String hubCustomTileSemantics(String title, String questions) {
    return '$title. $questions. Pindutin para sagutan.';
  }

  @override
  String get hubDeleteTitle => 'Burahin ang Pagsusulit?';

  @override
  String hubDeleteBody(String title) {
    return 'Sigurado ka bang buburahin ang “$title”? Hindi na ito maibabalik.';
  }

  @override
  String get hubCancel => 'Kanselahin';

  @override
  String get hubDelete => 'Burahin';

  @override
  String hubResultSemantics(
    String type,
    int percent,
    String grade,
    String date,
  ) {
    return '$type. Iskor: $percent porsiyento. $grade. Natapos noong $date.';
  }

  @override
  String get hubNoLearners => 'Wala pang mag-aaral';

  @override
  String get hubNoLearnersHint =>
      'Ibahagi ang code ng klase o home group, saka itakda ang panimulang pagsusulit.';

  @override
  String hubGain(String gain) {
    return 'Pag-unlad $gain';
  }

  @override
  String hubLearnerRowSemantics(String name, String status) {
    return '$name. $status. Pindutin para buksan ang kanilang profile.';
  }

  @override
  String get hubPre => 'Panimula';

  @override
  String get hubPost => 'Panghuli';

  @override
  String get bannerOverdue => 'Mga Gawaing Lampas na sa Takdang Araw';

  @override
  String get bannerPending => 'Mga Gawaing Naghihintay';

  @override
  String bannerSubtitle(int count) {
    return 'May $count pagsusulit kang dapat tapusin';
  }

  @override
  String bannerSemantics(int count) {
    return '$count pagsusulit ang nakatakda para sa iyo';
  }

  @override
  String get titleAllCategories => 'Lahat ng Kategorya';

  @override
  String titleMastery(String category) {
    return 'Pagsusulit sa Kahusayan: $category';
  }

  @override
  String get asgPreFirst =>
      'Magtakda muna ng panimulang pagsusulit — kagaya nito ang panghuli.';

  @override
  String get asgQuizEmpty =>
      'Wala nang natitirang card sa quiz na iyan na maitatanong.';

  @override
  String asgAssigned(int count) {
    return 'Naitakda ang pagsusulit sa $count mag-aaral!';
  }

  @override
  String asgLocalOnly(int count) {
    return 'Nai-save para sa $count mag-aaral sa device na ito — hindi pa naipapadala. Maa-upload ito kapag gumagana na ang pag-sync.';
  }

  @override
  String get asgNotOwner =>
      'Nai-save lang sa device na ito. Na-restore ang profile na ito sa ibang device, kaya iyon na ang nagsi-sync. I-restore ito rito para maipadala ang gawain sa iyong mga mag-aaral.';

  @override
  String get asgClassPre => 'Panimulang Pagsusulit ng Klase';

  @override
  String get asgClassPost => 'Panghuling Pagsusulit ng Klase';

  @override
  String get asgTitle => 'Magtakda ng Pagsusulit';

  @override
  String get asgStudyLabel => 'Panimula at panghuling pagsusulit ng pag-aaral';

  @override
  String get asgStudyCaption =>
      'Iisang tanong para sa lahat ng pipiliin mo. Itakda ang panghuli kapag tapos na ang panahon ng pag-aaral.';

  @override
  String get asgQuizzes => 'Mga Quiz';

  @override
  String get asgQuizzesCaption =>
      'Gumagawa ng bagong pagsusulit tuwing itatakda mo ito';

  @override
  String get asgSaved => 'Mga naka-save na pagsusulit';

  @override
  String get asgSavedCaption => 'Nakapirming hanay ng mga tanong';

  @override
  String asgSelectStudents(int selected, int total) {
    return 'Pumili ng Mag-aaral ($selected/$total)';
  }

  @override
  String get asgSelectAll => 'Piliin Lahat';

  @override
  String get asgDeselectAll => 'Alisin ang Pagpili';

  @override
  String get asgDeadline => 'Takdang araw (opsyonal)';

  @override
  String get asgSetDeadline => 'Magtakda ng Takdang Araw';

  @override
  String get asgRemoveDeadline => 'Alisin ang takdang araw';

  @override
  String get asgInstructions => 'Mga tagubilin (opsyonal)';

  @override
  String get asgInstructionsHint =>
      'Magdagdag ng tagubilin para sa mga mag-aaral...';

  @override
  String get asgAssigning => 'Itinatakda...';

  @override
  String get asgMadeFresh => 'bagong gawa tuwing itatakda';

  @override
  String get asgMirrors => 'kagaya ng panimulang kinuha ng bawat mag-aaral';

  @override
  String get asgNoChildren => 'Wala pang anak';

  @override
  String get asgNoStudents => 'Wala pang mag-aaral';

  @override
  String get asgShareHomeHint =>
      'Ibahagi ang code ng iyong home group para makasali ang iyong anak, saka magtakda ng gawain dito.';

  @override
  String get asgShareClassHint =>
      'Ibahagi ang code ng iyong klase para makasali ang mga mag-aaral, saka magtakda ng gawain dito.';

  @override
  String get asgShareGroupCode => 'Ibahagi ang Code ng Grupo';

  @override
  String get asgShareClassCode => 'Ibahagi ang Code ng Klase';

  @override
  String get trkTitle => 'Pagsubaybay sa mga Gawain';

  @override
  String get trkRefresh => 'Tingnan kung may bagong resulta';

  @override
  String get trkDeleteTitle => 'Burahin ang Gawain?';

  @override
  String get trkDeleteBody =>
      'Mabubura ang gawain. Mananatili ang mga resulta ng mga mag-aaral.';

  @override
  String get trkNotOwner =>
      'Dito lang ito naalis. Na-restore ang profile na ito sa ibang device, kaya iyon na ang nagsi-sync — nasa iyong mga mag-aaral pa rin ang gawaing ito.';

  @override
  String trkDue(String date) {
    return 'Takdang araw: $date';
  }

  @override
  String get trkEmpty => 'Wala pang gawain';

  @override
  String get trkEmptyHint =>
      'Magtakda ng pagsusulit sa mga mag-aaral at subaybayan dito ang kanilang pag-usad.';

  @override
  String gmScreenTitle(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Mga Home Group',
      'other': 'Pamahalaan ang mga Klase',
    });
    return '$_temp0';
  }

  @override
  String gmCreateHint(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'hal. Pamilya Santos',
      'other': 'hal. Ika-3 Baitang - Math',
    });
    return '$_temp0';
  }

  @override
  String gmShareBlurb(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Buksan ang app, gumawa ng profile ng anak, at ilagay ang code.',
      'other':
          'Buksan ang app, gumawa ng profile ng mag-aaral, at ilagay ang code.',
    });
    return '$_temp0';
  }

  @override
  String get gmRefresh => 'I-refresh';

  @override
  String gmNewGroup(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Bagong home group',
      'other': 'Bagong klase',
    });
    return '$_temp0';
  }

  @override
  String gmEmptyTitle(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Wala pang home group',
      'other': 'Wala pang klase',
    });
    return '$_temp0';
  }

  @override
  String gmEmptyBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Gumawa ng home group, saka ibahagi ang join code para makasali ang iyong mga anak mula sa sarili nilang device.',
      'other':
          'Gumawa ng klase, saka ibahagi ang join code para makasali ang iyong mga mag-aaral mula sa sarili nilang device.',
    });
    return '$_temp0';
  }

  @override
  String gmCreateGroup(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Gumawa ng home group',
      'other': 'Gumawa ng klase',
    });
    return '$_temp0';
  }

  @override
  String gmGroupName(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Pangalan ng home group',
      'other': 'Pangalan ng klase',
    });
    return '$_temp0';
  }

  @override
  String get gmCreate => 'Gumawa';

  @override
  String gmNameRequired(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Kailangan ang pangalan ng home group',
      'other': 'Kailangan ang pangalan ng klase',
    });
    return '$_temp0';
  }

  @override
  String gmCreated(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Nagawa ang home group.',
      'other': 'Nagawa ang klase.',
    });
    return '$_temp0';
  }

  @override
  String get gmOverview => 'Buod';

  @override
  String gmGroupCount(String audience, int count) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': '$count home group',
      'other': '$count klase',
    });
    return '$_temp0';
  }

  @override
  String gmMemberCount(String audience, int count) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': '$count anak',
      'other': '$count mag-aaral',
    });
    return '$_temp0';
  }

  @override
  String gmGroupsLabel(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'mga home group',
      'other': 'mga klase',
    });
    return '$_temp0';
  }

  @override
  String gmMembersLabel(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'mga anak',
      'other': 'mga mag-aaral',
    });
    return '$_temp0';
  }

  @override
  String get gmActive => 'aktibo';

  @override
  String get gmEnrolled => 'naka-enroll';

  @override
  String get gmNewestJoin => 'Pinakabagong sumali';

  @override
  String get gmNoJoins => 'wala pang sumasali';

  @override
  String get gmMostRecent => 'pinakabago';

  @override
  String get gmLoadingRoster => 'Nilo-load ang roster…';

  @override
  String gmGroupActions(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Mga aksyon sa home group',
      'other': 'Mga aksyon sa klase',
    });
    return '$_temp0';
  }

  @override
  String get gmRename => 'Palitan ang pangalan';

  @override
  String get gmAccessibility => 'Aksesibilidad';

  @override
  String get gmNewJoinCode => 'Bagong join code';

  @override
  String get gmLeaderboard => 'Leaderboard';

  @override
  String get gmLockRetakes => 'I-lock ang pag-ulit ng pagsusulit';

  @override
  String get gmAllowRetakes => 'Payagan ang pag-ulit ng pagsusulit';

  @override
  String gmDeleteGroup(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Burahin ang home group',
      'other': 'Burahin ang klase',
    });
    return '$_temp0';
  }

  @override
  String get gmHideRoster => 'Itago ang roster';

  @override
  String get gmShowRoster => 'Ipakita ang roster';

  @override
  String get gmCopyCode => 'Kopyahin ang code';

  @override
  String get gmShareCode => 'Ibahagi ang code';

  @override
  String gmRosterError(String error) {
    return 'Error sa roster: $error';
  }

  @override
  String gmNoMembers(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Wala pang anak na sumasali — ibahagi ang code sa itaas.',
      'other': 'Wala pang mag-aaral na sumasali — ibahagi ang code sa itaas.',
    });
    return '$_temp0';
  }

  @override
  String gmSelected(int count) {
    return '$count ang napili';
  }

  @override
  String gmRemoveCount(int count) {
    return 'Alisin ($count)';
  }

  @override
  String get gmLockTitle => 'I-lock ang pag-ulit ng pagsusulit?';

  @override
  String get gmAllowTitle => 'Payagan ang pag-ulit ng pagsusulit?';

  @override
  String gmLockBody(String name) {
    return 'Hindi na muling makakakuha ng panimula o panghuling pagsusulit ang mga mag-aaral sa “$name” kapag natapos na nila ito. Hindi apektado ang mga pagsusulit na itinatakda mo.';
  }

  @override
  String gmAllowBody(String name) {
    return 'Muling makakakuha ng panimula o panghuling pagsusulit ang mga mag-aaral sa “$name”. Ang pinakahuling pagkuha ang gagamitin sa pagsukat ng kanilang pag-unlad.';
  }

  @override
  String get gmLock => 'I-lock';

  @override
  String get gmAllow => 'Payagan';

  @override
  String get gmRetakesLocked => 'Naka-lock na ang pag-ulit ng pagsusulit.';

  @override
  String get gmRetakesAllowed => 'Pinapayagan na ang pag-ulit ng pagsusulit.';

  @override
  String gmCouldNotSave(String error) {
    return 'Hindi na-save: $error';
  }

  @override
  String gmCopied(String code) {
    return 'Nakopya ang $code';
  }

  @override
  String gmShareText(String name, String code, String blurb) {
    return 'Sumali sa “$name” sa FlashLearn PWD gamit ang code na $code. $blurb';
  }

  @override
  String get gmShareSubject => 'Join code ng FlashLearn PWD';

  @override
  String gmCouldNotShare(String error) {
    return 'Hindi maibahagi: $error';
  }

  @override
  String gmRenameGroup(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Palitan ang pangalan ng home group',
      'other': 'Palitan ang pangalan ng klase',
    });
    return '$_temp0';
  }

  @override
  String get gmSave => 'I-save';

  @override
  String gmRenamed(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Napalitan ang pangalan ng home group.',
      'other': 'Napalitan ang pangalan ng klase.',
    });
    return '$_temp0';
  }

  @override
  String gmAccessibilitySet(String type) {
    return 'Itinakda ang accessibility sa $type.';
  }

  @override
  String gmCouldNotUpdate(String error) {
    return 'Hindi na-update: $error';
  }

  @override
  String get gmResetTitle => 'I-reset ang join code?';

  @override
  String gmResetBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Gagawa ng bagong code. Mananatiling naka-enroll ang mga anak na nakasali na, pero hindi na gagana ang lumang code.',
      'other':
          'Gagawa ng bagong code. Mananatiling naka-enroll ang mga mag-aaral na nakasali na, pero hindi na gagana ang lumang code.',
    });
    return '$_temp0';
  }

  @override
  String get gmReset => 'I-reset';

  @override
  String get gmNewCodeGenerated => 'Nakagawa ng bagong code.';

  @override
  String gmCouldNotRegenerate(String error) {
    return 'Hindi makagawa ng bagong code: $error';
  }

  @override
  String gmDeleteTitle(String name) {
    return 'Burahin ang $name?';
  }

  @override
  String gmDeleteBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Maaalis sa pagka-enroll ang lahat ng anak. Mananatili ang kanilang profile at pag-unlad sa sarili nilang device.',
      'other':
          'Maaalis sa pagka-enroll ang lahat ng mag-aaral. Mananatili ang kanilang profile at pag-unlad sa sarili nilang device.',
    });
    return '$_temp0';
  }

  @override
  String gmCouldNotDelete(String error) {
    return 'Hindi mabura: $error';
  }

  @override
  String get gmRenameInRoster => 'Palitan ang pangalan sa roster';

  @override
  String gmDisplayNameIn(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Pangalang ipapakita sa home group na ito',
      'other': 'Pangalang ipapakita sa klaseng ito',
    });
    return '$_temp0';
  }

  @override
  String get gmDisplayNameRequired => 'Kailangan ang pangalang ipapakita';

  @override
  String gmRenameMemberNote(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Mapapalitan ang pangalan ng anak sa iyong roster at sa kanyang device.',
      'other':
          'Mapapalitan ang pangalan ng mag-aaral sa iyong roster at sa kanyang device.',
    });
    return '$_temp0';
  }

  @override
  String gmMemberRenamed(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Napalitan ang pangalan ng anak.',
      'other': 'Napalitan ang pangalan ng mag-aaral.',
    });
    return '$_temp0';
  }

  @override
  String gmUnlockedFor(String name, String duration) {
    return 'Na-unlock si $name nang $duration.';
  }

  @override
  String gmCouldNotUnlock(String error) {
    return 'Hindi ma-unlock: $error';
  }

  @override
  String gmRemoveTitle(String name) {
    return 'Alisin si $name?';
  }

  @override
  String gmRemoveBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Maaalis siya sa home group na ito. Mananatili ang kanyang profile at pag-unlad sa kanyang device.',
      'other':
          'Maaalis siya sa klaseng ito. Mananatili ang kanyang profile at pag-unlad sa kanyang device.',
    });
    return '$_temp0';
  }

  @override
  String get gmRemove => 'Alisin';

  @override
  String gmCouldNotRemove(String error) {
    return 'Hindi maalis: $error';
  }

  @override
  String gmRemoveManyTitle(String audience, int count) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Alisin ang $count anak?',
      'other': 'Alisin ang $count mag-aaral?',
    });
    return '$_temp0';
  }

  @override
  String gmRemoveManyBody(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent':
          'Mananatili ang kanilang profile at pag-unlad sa kanilang device; maaalis lang sila sa home group na ito.',
      'other':
          'Mananatili ang kanilang profile at pag-unlad sa kanilang device; maaalis lang sila sa klaseng ito.',
    });
    return '$_temp0';
  }

  @override
  String gmMemberActions(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Mga aksyon para sa anak',
      'other': 'Mga aksyon para sa mag-aaral',
    });
    return '$_temp0';
  }

  @override
  String get gmViewProgress => 'Tingnan ang pag-unlad';

  @override
  String get gmNotes => 'Mga tala';

  @override
  String get gmTimeLimits => 'Mga limitasyon sa oras';

  @override
  String get gmAlarms => 'Mga alarma';

  @override
  String get gmRoutine => 'Routine';

  @override
  String get gmUnlockScreen => 'I-unlock ang screen';

  @override
  String gmRemoveFrom(String audience) {
    String _temp0 = intl.Intl.selectLogic(audience, {
      'parent': 'Alisin sa home group',
      'other': 'Alisin sa klase',
    });
    return '$_temp0';
  }

  @override
  String gmJoined(String date, String ago) {
    return 'Sumali noong $date · $ago';
  }

  @override
  String gmUnlockTitle(String name) {
    return 'I-unlock si $name';
  }

  @override
  String get gmUnlockBody =>
      'Gaano katagal dapat nakapatay ang lock screen? Kusang magla-lock muli ang screen pagkatapos ng oras na ito.';

  @override
  String get gm15min => '15 min';

  @override
  String get gm30min => '30 min';

  @override
  String get gm1hour => '1 oras';

  @override
  String gmHours(int count) {
    return '$count oras';
  }

  @override
  String gmMinutes(int count) {
    return '$count minuto';
  }

  @override
  String get gmJustNow => 'ngayon lang';

  @override
  String gmMinutesAgo(int count) {
    return '$count min ang nakalipas';
  }

  @override
  String gmHoursAgo(int count) {
    return '$count oras ang nakalipas';
  }

  @override
  String gmDaysAgo(int count) {
    return '$count araw ang nakalipas';
  }

  @override
  String gmWeeksAgo(int count) {
    return '$count linggo ang nakalipas';
  }

  @override
  String get acpApplies =>
      'Para ito sa mga mag-aaral na sasali mula ngayon. Mananatili ang kasalukuyang setup ng mga naka-enroll na.';

  @override
  String get acpJoinersGet =>
      'Awtomatikong makukuha ng mga sasali gamit ang code na ito ang bersyong ito ng app — walang kailangang i-set up sa kanilang panig.';

  @override
  String get clipFailedSemantics =>
      'Hindi ma-load ang senyas na ito. Sumagot batay sa iyong nalalaman, o laktawan ang tanong.';

  @override
  String get clipSemantics =>
      'Isang video ng sign language. Kusa itong umuulit; i-double tap para ulitin.';

  @override
  String get clipReplay => 'Ulitin ang senyas';

  @override
  String get clipFailedTitle => 'Hindi na-load ang senyas na ito';

  @override
  String get clipFailedBody =>
      'Kumonekta sa internet at subukang muli, o sumagot batay sa iyong nalalaman.';

  @override
  String get navGoBack => 'Bumalik';

  @override
  String get offlineBanner => 'Offline ka — gumagana pa rin ang lahat!';

  @override
  String get homePlayerProfile => 'Aking Profile';

  @override
  String get homeMyDay => 'Ang Aking Araw';

  @override
  String get homeMoodCheckIn => 'Check-in ng Damdamin';

  @override
  String get homeDailyChallenge => 'Hamon ng Araw';

  @override
  String get homeAssignments => 'Mga Takdang Gawain';

  @override
  String get homePlayAndLearn => 'Maglaro at Matuto';

  @override
  String get homeGamesSub => 'Maglaro at matuto';

  @override
  String get homeWordsSub => 'Mga flashcard';

  @override
  String get homeStories => 'Mga Kwento';

  @override
  String get homeStoriesSub => 'Magbasa at sumagot';

  @override
  String get homeFslSub => 'Wikang senyas';

  @override
  String homeToPractice(int count) {
    return '$count na sasanayin';
  }

  @override
  String get homeReviewSub => 'Balikan ang mga salita';

  @override
  String get homeProgressSub => 'Ang iyong paglalakbay';

  @override
  String get homeLearningStudy => 'Pagkatuto at Pag-aaral';

  @override
  String get homeLearningPaths => 'Mga Landas ng Pagkatuto';

  @override
  String get homeGuidedPractice => 'Gabay na Pagsasanay';

  @override
  String get homeHardWords => 'Mahihirap na Salita';

  @override
  String get homeWhatToStudy => 'Ano ang Pag-aaralan';

  @override
  String get homeAssessmentProgress => 'Pagsusulit at Progreso';

  @override
  String get homeLearningGains => 'Pag-unlad sa Pagkatuto';

  @override
  String get homeMyPortfolio => 'Aking Portfolio';

  @override
  String get homeMyGoals => 'Aking mga Layunin';

  @override
  String get homeHowWasIt => 'Kumusta ito?';

  @override
  String get homeCommunication => 'Komunikasyon at Wika';

  @override
  String get homeFslDictionary => 'Diksyunaryo ng FSL';

  @override
  String get homeSocial => 'Pakikisalamuha at Pagtutulungan';

  @override
  String get homeJoinAClass => 'Sumali sa klase';

  @override
  String get homeJoinTheClass => 'Sumali sa klase ngayon';

  @override
  String get homeLiveClassBody =>
      'Sagutin ang mga live na tanong para sa bituin, at magtaas ng kamay kung kailangan mo ng tulong.';

  @override
  String get homeLiveClassSemantics =>
      'Sumali sa live na gawain ng klase at magtaas ng kamay.';

  @override
  String get homeHaveClassCode => 'May class code ka ba?';

  @override
  String get homeJoinClassBody =>
      'Sumali sa klase para ma-save ang iyong progreso at masubaybayan ka ng iyong guro.';

  @override
  String get homeJoinClassSemantics =>
      'May class code ka ba? Sumali sa klase para ma-save ang iyong progreso.';

  @override
  String get homePeerCollab => 'Magtulungan';

  @override
  String get homeMyNotes => 'Aking mga Tala';

  @override
  String get homeWellbeing => 'Sarili at Kapakanan';

  @override
  String get homeStickerAlbum => 'Album ng Sticker';

  @override
  String get homeMyNotebook => 'Aking Kuwaderno';

  @override
  String homeStatsSemantics(int streak, int words, int balance, int total) {
    return 'Mga numero: $streak araw na sunod-sunod, $words salitang natutunan, $balance bituing magagastos mula sa $total na naipon';
  }

  @override
  String get homeDailyReward => 'Gantimpala sa Araw';

  @override
  String get homeDailyRewardTitle => 'Gantimpala sa Araw!';

  @override
  String homeDayNumber(int day) {
    return 'Araw $day';
  }

  @override
  String homeDayShort(int day) {
    return 'A$day';
  }

  @override
  String homeYouEarnedStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nakakuha ka ng $count bituin.',
      one: 'Nakakuha ka ng 1 bituin.',
    );
    return '$_temp0';
  }

  @override
  String get homeComeBackTomorrow => 'Bumalik ka bukas para sa higit pa!';

  @override
  String get homeCollect => 'Kunin';

  @override
  String get homeCollectStar => 'Kunin! 🌟';

  @override
  String get homeDailyChallengeChip => '🏆 Hamon ng Araw';

  @override
  String homeDayStreak(int count) {
    return '$count araw na sunod-sunod';
  }

  @override
  String get homeOpenDailyChallenge =>
      'Buksan ang buong hamon ng araw, kasama ang kalendaryo at mga numero';

  @override
  String get homeViewAll => 'Tingnan Lahat';

  @override
  String get homeWhatInFilipino => 'Ano ito sa Filipino?';

  @override
  String get homeCorrectBonus => 'Tama! +2 dagdag na bituin ⭐';

  @override
  String homeAnswerIs(String word) {
    return 'Ang sagot ay: $word';
  }

  @override
  String get homeChallengeComplete => 'Tapos na ang Hamon! ✨';

  @override
  String homeAnswerWas(String word) {
    return 'Ang sagot ay: $word';
  }

  @override
  String homeLevelSemantics(int level, String title, int xp, String next) {
    return 'Aking Profile. Level $level $title, $xp XP lahat, $next. Binubuksan ang iyong mga numero, gantimpala at nakamit.';
  }

  @override
  String homeXpToLevel(int xp, int level, String title) {
    return '$xp XP pa bago mag-level $level $title';
  }

  @override
  String get homeMaxLevel => 'naabot na ang pinakamataas na level';

  @override
  String childGreeting(String name) {
    return 'Kumusta, $name!';
  }

  @override
  String get childFriend => 'Kaibigan';

  @override
  String get childWhatToDo => 'Ano ang gusto mong gawin ngayon?';

  @override
  String get childMyFeelings => 'Aking Damdamin';

  @override
  String get childSignDictionary => 'Diksyunaryo ng Senyas';

  @override
  String get childPracticeWords => 'Sanayin ang mga Salita';

  @override
  String get childMyProgress => 'Aking Progreso';

  @override
  String get childExplore => 'Tuklasin at Lumikha';

  @override
  String get childAdventureMap => 'Mapa ng Pakikipagsapalaran';

  @override
  String get childPracticeWithMe => 'Magsanay Kasama Ko';

  @override
  String get childBuddy => 'Kaibigan';

  @override
  String get childFriends => 'Mga Kaibigan';

  @override
  String get childRewards => 'Gantimpala at Damdamin';

  @override
  String get childPlayerCard => 'Aking Kard ng Manlalaro';

  @override
  String get childStickers => 'Mga Sticker';

  @override
  String get childSwitchProfile => 'Palitan ang profile';

  @override
  String childStatsSemantics(int streak, int words, int stars) {
    return 'Ang araw ko: $streak araw na sunod-sunod, $words salitang natutunan, $stars bituing naipon';
  }

  @override
  String get eduRecentStudents => 'Mga Kamakailang Mag-aaral';

  @override
  String eduStudentStats(int words, int streak, int stars) {
    return '$words salita  •  🔥 $streak sunod-sunod  •  ⭐ $stars';
  }

  @override
  String eduDeckSemantics(String category, int count) {
    return 'Deck ng $category, $count kard';
  }

  @override
  String eduDeckCards(int count) {
    return '$count kard';
  }

  @override
  String catCardSemantics(String category, int count, int percent) {
    return 'Mga flashcard ng $category, $count salita, $percent porsiyentong progreso';
  }

  @override
  String catCardWords(int count) {
    return '$count salita';
  }

  @override
  String get playerFallbackName => 'Manlalaro';

  @override
  String get playerModeNote =>
      'Nasa Player mode ka. Sa device na ito lang naka-save ang iyong laro.';

  @override
  String get playerStartLearning => 'Magsimulang Matuto';

  @override
  String get playerBrowseFlashcards => 'Tingnan ang mga flashcard';

  @override
  String get playerSaveStars => 'I-save ang iyong mga bituin sa ibang device';

  @override
  String get playerSaveBody =>
      'Sumali sa klase o home group para ma-back up ang iyong progreso at matuto kasama ang iba.';

  @override
  String get playerJoinClass => 'Sumali sa klase';

  @override
  String get playerJoinGroup => 'Sumali sa grupo';

  @override
  String levelSemantics(int level, String title, int xp, String next) {
    return 'Level $level $title, $xp XP lahat, $next';
  }

  @override
  String levelXpToShort(int xp, int level, String title) {
    return '$xp XP pa bago mag-Lv.$level $title';
  }

  @override
  String get levelUpTitle => 'TUMAAS ANG LEVEL!';

  @override
  String levelReached(int level) {
    return 'Naabot mo na ang Level $level!';
  }

  @override
  String get levelTapAnywhere => 'Pindutin kahit saan para magpatuloy';

  @override
  String get deckBrowseTemplates => 'Tingnan ang mga template';

  @override
  String deckSemantics(String category, int count, int percent) {
    return 'Deck ng $category. $count kard. $percent porsiyentong tapos.';
  }

  @override
  String deckChipSemantics(String label) {
    return '$label: sariling mga flashcard';
  }

  @override
  String viewerNofM(int index, int total) {
    return '$index sa $total.';
  }

  @override
  String viewerDeleteConfirm(String word) {
    return 'Sigurado ka bang buburahin ang “$word”? Hindi na ito maibabalik.';
  }

  @override
  String get viewerShowMe => 'Ipakita';

  @override
  String get viewerExamples => 'Mga Halimbawa';

  @override
  String get viewerWriteNote => 'Sumulat ng tala tungkol sa salitang ito';

  @override
  String get viewerPauseAuto => 'Ihinto ang auto-play';

  @override
  String get viewerStartAuto => 'Simulan ang auto-play';

  @override
  String viewerFlippedSemantics(String english, String filipino) {
    return 'Ang $english sa Filipino ay $filipino. Pindutin para ibalik.';
  }

  @override
  String viewerFrontSemantics(String english, String category) {
    return '$english, kategoryang $category. Pindutin para makita ang detalye.';
  }

  @override
  String viewerButton(String label) {
    return 'Button na $label';
  }

  @override
  String get viewerGazeStarting => 'Sinisimulan ang gaze…';

  @override
  String get viewerGazeLook => 'Tumingin sa screen';

  @override
  String get viewerGazeChoose =>
      'Tumingin ◀ ▶ para pumili · kumurap para buksan';

  @override
  String progMasterySemantics(int percent, int mastered, int total) {
    return 'Kabuuang kahusayan: $percent porsiyento. $mastered sa $total salita ang natutunan.';
  }

  @override
  String progStarsEarned(int count) {
    return '$count bituing naipon';
  }

  @override
  String progStarsCollected(int count) {
    return '⭐ $count bituin ang naipon!';
  }

  @override
  String progAchievementUnlocked(String title) {
    return 'Badge na $title, nakuha na';
  }

  @override
  String progAchievementLocked(String title) {
    return 'Badge na $title, hindi pa nakukuha';
  }

  @override
  String get progJustNow => 'Ngayon lang';

  @override
  String get progYesterday => 'Kahapon';

  @override
  String progGameSemantics(
    String game,
    int score,
    int total,
    int percent,
    int stars,
    String when,
  ) {
    return '$game: $score sa $total, $percent porsiyento, $stars bituin, $when';
  }

  @override
  String progCategoryRowSemantics(
    String category,
    int mastered,
    int total,
    int percent,
  ) {
    return 'Kategoryang $category: $mastered sa $total salita ang bihasa na, $percent porsiyento';
  }

  @override
  String dcExplain(String english, String filipino) {
    return 'Ang “$english” ay “$filipino” sa Filipino.';
  }

  @override
  String get dcTitle => '🎯 Misyon Ngayong Araw';

  @override
  String get dcChip => '✨ Misyon Ngayong Araw';

  @override
  String get dcNoWords => 'Wala pang salita para sa misyon ngayong araw.';

  @override
  String dcWordNofM(int index, int total) {
    return 'Salita $index sa $total';
  }

  @override
  String get dcListen => 'Pakinggan ang bigkas sa Ingles';

  @override
  String get dcFinish => 'Tapusin ang Misyon';

  @override
  String get dcNextWord => 'Susunod na Salita';

  @override
  String get dcCorrect => 'Tama! +1 bituin ⭐';

  @override
  String get dcNotQuite => 'Hindi pa tama!';

  @override
  String get dcPerfect => 'Perpektong misyon! 🎉';

  @override
  String get dcComplete => 'Tapos na ang misyon! ✨';

  @override
  String dcYouGot(int correct, int total) {
    return 'Tama ang $correct sa $total.';
  }

  @override
  String dcYouGotStars(int correct, int total, int stars) {
    return 'Tama ang $correct sa $total at nakakuha ka ng $stars ⭐.';
  }

  @override
  String get dcComeBack => 'Bumalik ka bukas para sa bagong misyon';

  @override
  String get dcTodayDone => 'Tapos na ang misyon ngayong araw! ✨';

  @override
  String dcFiftySemantics(int remaining) {
    return 'Pahiwatig na fifty-fifty, nag-aalis ng dalawang maling sagot, $remaining pa ang natitira';
  }

  @override
  String get dcStreakStart => 'Simulan ang iyong sunod-sunod ngayon!';

  @override
  String dcStreakGoing(int streak) {
    return '$streak araw na sunod-sunod — tuloy lang!';
  }

  @override
  String dcStreakAmazing(int streak) {
    return '$streak araw na sunod-sunod — ang galing!';
  }

  @override
  String dcStreakFire(int streak) {
    return '$streak araw na sunod-sunod — nag-aapoy ka!';
  }

  @override
  String dcStreakLegend(int streak) {
    return '$streak araw na sunod-sunod — alamat ka!';
  }

  @override
  String get dcStreakHint =>
      'Tapusin ang misyon ngayong araw para humaba ang iyong sunod-sunod';

  @override
  String dcRemovedByHint(String text) {
    return '$text, inalis ng pahiwatig';
  }

  @override
  String get dcPrevMonth => 'Nakaraang buwan';

  @override
  String get dcNextMonth => 'Susunod na buwan';

  @override
  String get dcCurrentStreak => 'Kasalukuyang Sunod-sunod';

  @override
  String get dcDaysCompleted => 'Mga Araw na Natapos';

  @override
  String get dcStarsEarned => 'Mga Bituing Naipon';

  @override
  String get dcBadgesEarned => 'Mga Badge na Nakuha';

  @override
  String get dcBadge3Day => '3 Araw na Sunod-sunod';

  @override
  String get dcBadgeWeekly => 'Mandirigma ng Linggo';

  @override
  String get dcBadgeMonthly => 'Maestro ng Buwan';

  @override
  String get dcBadge10 => '10 Araw na Tapos';

  @override
  String get dcBadge50 => '50 Araw na Tapos';

  @override
  String get dcBadge100 => 'Sandaang Araw';

  @override
  String get fslOfflineSigns => 'Mga senyas na offline';

  @override
  String get fslHasSign => 'May senyas';

  @override
  String fslMySigns(int count) {
    return 'Aking mga Senyas · $count';
  }

  @override
  String fslICanSign(int count) {
    return 'Kaya kong isenyas · $count';
  }

  @override
  String fslWordCount(int count) {
    return '$count salita';
  }

  @override
  String fslWatchedOf(int watched, int total) {
    return '$watched sa $total senyas ang napanood';
  }

  @override
  String fslWatchSemantics(String english, String filipino) {
    return '$english, $filipino. Panoorin ang senyas.';
  }

  @override
  String fslWatchedSemantics(String english, String filipino) {
    return '$english, $filipino. Napanood mo na. Panoorin ang senyas.';
  }

  @override
  String fslNoVideoSemantics(String english, String filipino) {
    return '$english, $filipino. Wala pang video ng senyas.';
  }

  @override
  String fslRemoveMySigns(String word) {
    return 'Alisin ang $word sa Aking mga Senyas';
  }

  @override
  String fslAddMySigns(String word) {
    return 'Idagdag ang $word sa Aking mga Senyas';
  }

  @override
  String get lpAdventureMap => 'Mapa ng Pakikipagsapalaran 🗺️';

  @override
  String get lpPillDone => 'TAPOS';

  @override
  String get lpPillStart => 'SIMULAN';

  @override
  String get lpPillEnter => 'PASOK';

  @override
  String get lpPillReplay => 'ULITIN';

  @override
  String get lpWorldMastered => 'Na-master mo ang buong mundo!';

  @override
  String get lpWorldExplore => 'Tuklasin ang bawat rehiyon para maging kampeon';

  @override
  String get lpTitle => 'Mga Landas ng Pagkatuto';

  @override
  String get lpMapTooltip => 'Mapa ng pakikipagsapalaran';

  @override
  String get lpJourney => 'Ang Iyong Paglalakbay sa Pagkatuto 🗺️';

  @override
  String get lpIntro =>
      'Tapusin ang bawat landas para mabuksan ang susunod. I-master ang lahat ng 12 kategorya para maging kampeon ng bokabularyo!';

  @override
  String lpPathsCompleted(int done, int total) {
    return '$done / $total landas ang natapos';
  }

  @override
  String get lpTrailTooltip => 'Daan ng pakikipagsapalaran';

  @override
  String get lpMastered => 'Na-master ang Landas!';

  @override
  String lpCompletedAll(String path) {
    return 'Natapos mo ang lahat ng hakbang sa $path!';
  }

  @override
  String lpVocabulary(String category) {
    return 'Bokabularyo sa $category';
  }

  @override
  String get lpRetry => 'Ulitin';

  @override
  String get lpStart => 'Simulan';

  @override
  String get lpPrevFirst => 'Tapusin muna ang naunang hakbang';

  @override
  String get lpAdventureDone => 'Tapos na ang pakikipagsapalaran!';

  @override
  String get lpClimb => 'Akyatin ang daan para ma-master ang bawat hakbang';

  @override
  String lpCardSemantics(String path, int done, int total) {
    return 'Landas ng pagkatuto na $path. $done sa $total hakbang ang tapos.';
  }

  @override
  String get lpCardLocked =>
      'Nakakandado. Tapusin ang naunang landas para mabuksan.';

  @override
  String get lpNodeCompleted => 'Tapos na';

  @override
  String get lpNodeCurrent => 'Kasalukuyan';

  @override
  String get lpNodeAvailable => 'Bukas na';

  @override
  String get lpNodeLocked => 'Nakakandado';

  @override
  String srEnglishWord(String word) {
    return 'Salitang Ingles: $word';
  }

  @override
  String srFilipinoTranslation(String word) {
    return 'Salin sa Filipino: $word';
  }

  @override
  String get srGreat => 'Ang galing mong makaalala! Ituloy mo lang!';

  @override
  String get srKeepPracticing => 'Magsanay pa — kaya mo iyan!';

  @override
  String get hwPractice => 'Magsanay';

  @override
  String get hwStruggling => 'Nahihirapan';

  @override
  String get hwAttempted => 'Sinubukan';

  @override
  String get hwEmptyTitle => 'Walang mahirap na salita!';

  @override
  String get hwEmptyBody =>
      'Ang galing mo! Magpatuloy sa paglalaro, at lalabas dito ang mga salitang nahihirapan ka.';

  @override
  String hwCardSemantics(
    String english,
    String filipino,
    int percent,
    int correct,
    int total,
  ) {
    return '$english, $filipino. Katumpakan: $percent porsiyento. $correct tama sa $total subok.';
  }

  @override
  String get joinClassTitle => 'Sumali sa Klase';

  @override
  String get joinClassIntro => 'Ilagay ang code na ibinigay ng iyong guro.';

  @override
  String get joinClassCode => 'Code ng klase';

  @override
  String get joinCodeLength => 'Dapat 6 na character ang code';

  @override
  String get joinChecking => 'Sinusuri…';

  @override
  String get joinGroupTitle => 'Sumali sa Home Group';

  @override
  String get joinGroupIntro =>
      'Ilagay ang code na ibinahagi ng iyong magulang o tagapag-alaga.';

  @override
  String get joinGroupCode => 'Code ng home group';

  @override
  String get joinGroupTip =>
      'Tip: hilingin sa iyong magulang na suriin ang kanilang internet, o subukan ulit maya-maya.';

  @override
  String get scTitle => 'Kalendaryo ng Streak';

  @override
  String get scBestStreak => 'Pinakamahabang Streak';

  @override
  String get scThisMonth => 'Ngayong Buwan';

  @override
  String get scTotalActive => 'Kabuuang Aktibo';

  @override
  String scDays(int count) {
    return '$count araw';
  }

  @override
  String get scMilestones => 'Mga Yugto ng Streak';

  @override
  String calDaySemantics(int day) {
    return 'Araw $day';
  }

  @override
  String get calStudied => ', nag-aral';

  @override
  String get calToday => ', ngayon';

  @override
  String get calM3 => '3 Araw';

  @override
  String get calW1 => '1 Linggo';

  @override
  String get calW2 => '2 Linggo';

  @override
  String get calMo1 => '1 Buwan';

  @override
  String get calMo2 => '2 Buwan';

  @override
  String get calD100 => '100 Araw';

  @override
  String calMilestoneAchieved(String label) {
    return 'Yugto ng streak na $label, naabot na';
  }

  @override
  String calMilestoneNotYet(String label) {
    return 'Yugto ng streak na $label, hindi pa naaabot';
  }

  @override
  String sdToMilestone(int count, int milestone) {
    return '$count araw pa bago ang $milestone araw';
  }

  @override
  String sdBest(int days) {
    return 'Pinakamahaba: $days araw';
  }

  @override
  String get sdTierStarting => 'Nagsisimula Pa Lang';

  @override
  String get sdTierBuilding => 'Lumalakas';

  @override
  String get sdTierFire => 'Nag-aapoy!';

  @override
  String get sdTierBlazing => 'Naglalagablab';

  @override
  String get sdTierChampion => 'Kampeon ng Streak';

  @override
  String certCategoryTitle(String category) {
    return 'Kahusayan sa $category';
  }

  @override
  String certWordsLearned(int learned, int total) {
    return '$learned/$total salitang natutunan';
  }

  @override
  String certStreakTitle(int days) {
    return '$days Araw na Streak';
  }

  @override
  String get certStreakSub => 'Tuloy-tuloy na pag-aaral';

  @override
  String get certExcellence => 'Kahusayan sa Pagkatuto';

  @override
  String certWordsStars(int words, int stars) {
    return '$words salita, $stars bituin';
  }

  @override
  String get certTitle => 'Aking mga Sertipiko';

  @override
  String get certEmpty => 'Wala pang sertipiko';

  @override
  String get certEmptyHint =>
      'Magpatuloy sa pag-aaral para makakuha ng sertipiko!\nI-master ang isang kategorya (80%+), gumawa ng 7 araw na streak,\no matuto ng 50+ salita.';

  @override
  String certSemantics(String title, String subtitle) {
    return 'Sertipiko: $title. $subtitle. Pindutin para makita at maibahagi.';
  }

  @override
  String certFileName(String title) {
    return 'Sertipiko - $title';
  }

  @override
  String certFailed(String error) {
    return 'Hindi nagawa ang sertipiko: $error';
  }

  @override
  String huntMore(int count) {
    return '+$count pa';
  }

  @override
  String get goalsTitle => 'Aking mga Layunin';

  @override
  String get goalsActive => 'Mga Aktibong Layunin';

  @override
  String get goalsNone => 'Wala pang layunin';

  @override
  String get goalsNoneHint =>
      'Magtakda ng layunin sa pag-aaral para manatiling masigla!';

  @override
  String goalsCompleted(int count) {
    return 'Natapos ($count)';
  }

  @override
  String goalsExpired(int count) {
    return 'Lumipas na ($count)';
  }

  @override
  String get goalsNew => 'Bagong Layunin';

  @override
  String get goalsTracker => 'Tagasubaybay ng Layunin';

  @override
  String goalsSummary(int active, int completed) {
    return '$active aktibo · $completed tapos';
  }

  @override
  String get goalsTypeWords => 'Mga Salitang Natutunan';

  @override
  String get goalsTypeGames => 'Mga Larong Natapos';

  @override
  String get goalsTypeMastery => 'Kahusayan sa Kategorya';

  @override
  String get goalsTypeStreak => 'Mga Araw ng Streak';

  @override
  String get goalsTypeStars => 'Mga Bituing Naipon';

  @override
  String get goalsExpiredShort => 'Lumipas na';

  @override
  String get goalsDueToday => 'Hanggang ngayong araw';

  @override
  String get goalsDueTomorrow => 'Hanggang bukas';

  @override
  String goalsDueIn(int days) {
    return 'Hanggang $days araw pa';
  }

  @override
  String get goalsACategory => 'isang kategorya';

  @override
  String goalsLearnN(int n) {
    return 'Matuto ng $n salita';
  }

  @override
  String goalsCompleteN(int n) {
    return 'Tapusin ang $n laro';
  }

  @override
  String goalsMasteryN(int n, String category) {
    return 'Umabot sa $n% na kahusayan sa $category';
  }

  @override
  String goalsStreakN(int n) {
    return 'Panatilihin ang $n araw na streak';
  }

  @override
  String goalsStarsN(int n) {
    return 'Mag-ipon ng $n bituin';
  }

  @override
  String get goalsSetNew => 'Magtakda ng Bagong Layunin';

  @override
  String get goalsWhat => 'Ano ang gusto mong makamit?';

  @override
  String get goalsWhichCategory => 'Aling kategorya?';

  @override
  String get goalsTarget => 'Target';

  @override
  String get goalsDeadline => 'Magtakda ng takdang araw';

  @override
  String goalsDaysShort(int days) {
    return '${days}a';
  }

  @override
  String get goalsCreate => 'Gumawa ng Layunin';

  @override
  String get lgNoProfile => 'Walang Napiling Profile';

  @override
  String get lgNoProfileBody =>
      'Pumili ng profile para makita ang datos ng pag-unlad.';

  @override
  String get lgGoBack => 'Bumalik';

  @override
  String get lgEducatorTitle =>
      'Sa iyong mga mag-aaral ang pag-unlad sa pagkatuto';

  @override
  String get lgEducatorBody =>
      'Ikaw ang nagtatakda ng panimula at panghuling pagsusulit; sa kanila ang pag-unlad. Buksan ang Pagsubaybay sa Pagsusulit para makita kung sino na ang kumuha ng alin.';

  @override
  String get lgOpenTracking => 'Buksan ang pagsubaybay';

  @override
  String get lgTakeTest => 'Kumuha ng Pagsusulit';

  @override
  String get lgNoData => 'Wala Pang Datos ng Pagkatuto';

  @override
  String get lgNoDataBody =>
      'Kunin muna ang Panimulang Pagsusulit para malaman kung saan ka nagsisimula, saka kunin ang Panghuling Pagsusulit pagkatapos mag-aral para makita ang iyong pag-unlad!';

  @override
  String get lgTakePre => 'Kunin ang Panimulang Pagsusulit';

  @override
  String get lgReadyPost => 'Handa ka na ba sa Panghuling Pagsusulit?';

  @override
  String get lgReadyPostBody =>
      'Tapos mo na ang Panimulang Pagsusulit! Kunin ang Panghuling Pagsusulit para makita kung gaano karami ang natutunan mo.';

  @override
  String get lgTakePost => 'Kunin ang Panghuling Pagsusulit';

  @override
  String get lgAverageScores => 'Karaniwang Iskor';

  @override
  String get lgRecent => 'Mga Kamakailang Pagsusulit';

  @override
  String lgTotal(int count) {
    return '$count lahat';
  }

  @override
  String lgFocusOn(String category) {
    return 'Pagtuunan ang $category';
  }

  @override
  String lgFocusBody(int percent) {
    return 'Ito ang pinakamahina mong kategorya, $percent%. Balikan ang mga flashcard at maglaro ng mga laro sa kategoryang ito.';
  }

  @override
  String get lgPracticeMore => 'Magsanay Pa';

  @override
  String get lgPracticeMoreBody =>
      'Balikan ang mga flashcard at maglaro bago ulitin ang panghuling pagsusulit.';

  @override
  String get lgExcellent => 'Napakahusay!';

  @override
  String get lgExcellentBody =>
      'Ang galing mo! Subukan ang mas mahirap na antas para patuloy na hamunin ang sarili.';

  @override
  String lgBestAt(String category) {
    return 'Pinakamahusay sa $category';
  }

  @override
  String lgBestBody(int percent) {
    return 'Ito ang pinakamalakas mong kategorya, $percent%! Magaling!';
  }

  @override
  String lgMostImproved(String category) {
    return 'Pinakamalaking Pag-unlad: $category';
  }

  @override
  String lgImprovedBy(int percent) {
    return 'Umunlad nang $percent% — ituloy mo lang!';
  }

  @override
  String get lgRecommendations => 'Mga Mungkahi';

  @override
  String get lgNoCategoryData => 'Walang datos ng kategorya';

  @override
  String get lgScoreByCategory => 'Iskor ayon sa Kategorya';

  @override
  String get lgPreShort => 'Bago';

  @override
  String get lgPostShort => 'Pagkatapos';

  @override
  String get lgGreatImprovement => 'Malaking Pag-unlad!';

  @override
  String get lgKeepPracticing => 'Magsanay Pa!';

  @override
  String get lgCategoryBreakdown => 'Hati ayon sa Kategorya';

  @override
  String get lgTrend => 'Takbo ng Iskor sa Paglipas ng Panahon';

  @override
  String get lgPreTests => 'Mga Panimulang Pagsusulit';

  @override
  String get lgPostTests => 'Mga Panghuling Pagsusulit';

  @override
  String get scPortfolio => 'Aking Portfolio';

  @override
  String get scSharePortfolio => 'Ibahagi ang Portfolio';

  @override
  String get scAutoCurate => 'Kusang punan ang portfolio';

  @override
  String scItems(int count) {
    return '$count item';
  }

  @override
  String get scAddNote => 'Magdagdag ng Tala';

  @override
  String scAdded(int count) {
    return 'Nadagdag ang $count bagong item sa iyong portfolio!';
  }

  @override
  String get scUpToDate => 'Napapanahon na ang portfolio!';

  @override
  String get scRemoveTitle => 'Alisin sa Portfolio?';

  @override
  String scRemoveBody(String title) {
    return 'Alisin ang “$title” sa iyong showcase? Maaari mo itong ibalik anumang oras.';
  }

  @override
  String get scAddANote => 'Magdagdag ng Tala';

  @override
  String get scNoteTitle => 'Pamagat';

  @override
  String get scNoteTitleHint => 'hal., “Ang Paborito Kong Laro”';

  @override
  String get scNote => 'Tala';

  @override
  String get scNoteHint => 'Isulat ang tungkol sa iyong pag-aaral...';

  @override
  String get scAdd => 'Idagdag';

  @override
  String get scTypeAchievement => 'Tagumpay';

  @override
  String get scTypeHighScore => 'Mataas na Iskor';

  @override
  String get scTypeMastery => 'Kahusayan sa Kategorya';

  @override
  String get scTypePath => 'Landas ng Pagkatuto';

  @override
  String get scTypeStreak => 'Yugto ng Streak';

  @override
  String get scTypeAssessment => 'Pagsusulit';

  @override
  String get scTypeNote => 'Tala';

  @override
  String get scPinned => 'Naka-pin.';

  @override
  String get scUnpin => 'Alisin sa itaas';

  @override
  String get scPinTop => 'Ilagay sa itaas';

  @override
  String get scRemoveFrom => 'Alisin sa showcase';

  @override
  String get scShowcaseBest => 'Ipakita ang iyong pinakamagagandang sandali!';

  @override
  String get scStatItems => 'Mga Item';

  @override
  String get scStatPinned => 'Naka-pin';

  @override
  String get scStatAwards => 'Mga Gantimpala';

  @override
  String get scEmptyTitle => 'Wala Pang Laman ang Iyong Portfolio';

  @override
  String get scEmptyBody =>
      'Magsimula sa kusang pagpuno ng iyong pinakamagagandang sandali, o magdagdag ng item habang natututo!';

  @override
  String get scEmptyAction => 'Kusang Punan ang Aking Portfolio';

  @override
  String get scPdfTitle => 'PDF ng Buod ng Portfolio';

  @override
  String scItemsFor(int count, String name) {
    return '$count item • $name';
  }

  @override
  String get scShareHint =>
      'Ibahagi sa iyong guro o magulang para makita ang iyong progreso!';

  @override
  String wodLearned(String emoji) {
    return 'Natutunan ang salita! $emoji';
  }

  @override
  String get tbPrev => 'Bago';

  @override
  String get tbSpeak => 'Sabihin';

  @override
  String get tbAdd => 'Idagdag';

  @override
  String get tbTooLong =>
      'Iyan na ang pinakamahabang pangungusap. Sabihin ito o burahin.';

  @override
  String get tbUnpinned => 'Inalis ang naka-save na parirala.';

  @override
  String get tbSaved => 'Na-save ang parirala.';

  @override
  String get tbChangeReason => 'para baguhin ang board na ito';

  @override
  String get tbTitle => 'Talk Board';

  @override
  String get tbEditBoard => 'Baguhin ang aking board';

  @override
  String get tbBuildBoard => 'Gumawa ng aking board';

  @override
  String get tbToEnglish => 'Lumipat sa Ingles';

  @override
  String get tbToFilipino => 'Lumipat sa Filipino';

  @override
  String tbSavedPhrase(String phrase) {
    return 'Naka-save na parirala: $phrase. Pindutin para sabihin.';
  }

  @override
  String tbRecentPhrase(String phrase) {
    return 'Kamakailang parirala: $phrase. Pindutin para sabihin.';
  }

  @override
  String get tbHint =>
      'Pindutin ang mga tile sa ibaba para bumuo ng pangungusap';

  @override
  String get tbSpeakSentence => 'Sabihin ang pangungusap';

  @override
  String get tbUnsave => 'Alisin ang pangungusap na ito sa mga naka-save';

  @override
  String get tbSave => 'I-save ang pangungusap na ito';

  @override
  String get tbRemoveLast => 'Alisin ang huling tile';

  @override
  String get tbClearAll => 'Burahin lahat ng tile';

  @override
  String tbCategory(String label) {
    return 'Kategoryang $label';
  }

  @override
  String tbTileSemantics(String spoken) {
    return '$spoken. Pindutin para idagdag, pindutin nang matagal para marinig.';
  }

  @override
  String agTooMany(String time) {
    return 'Masyadong maraming subok. Maghintay ng $time.';
  }

  @override
  String get agEnterPin => 'Ilagay ang 4-digit na PIN.';

  @override
  String get agPinMismatch =>
      'Hindi tugma ang PIN. Magtanong sa iyong magulang o guro.';

  @override
  String get agNewQuestion => 'Hindi pa tama. Heto ang bagong tanong.';

  @override
  String agMinutes(int n) {
    return '$n minuto';
  }

  @override
  String agSeconds(int n) {
    return '$n segundo';
  }

  @override
  String get agTitle => 'Magtanong sa nakatatanda';

  @override
  String agPinNeeded(String reason) {
    return 'Kailangan ang PIN ng magulang o guro $reason.';
  }

  @override
  String agAnswerThis(String reason) {
    return 'Sagutin ito $reason.';
  }

  @override
  String agTimes(int a, int b) {
    return 'Ilan ang $a beses $b?';
  }

  @override
  String get agAnswer => 'Sagot';

  @override
  String agEndEarly(String title) {
    return 'para tapusin nang maaga ang $title';
  }

  @override
  String get lbTitle => 'Leaderboard';

  @override
  String get lbNoRankings => 'Wala pang ranggo';

  @override
  String get lbNoRankingsBody =>
      'Tapusin ang mga gawain at laro para mapasama sa leaderboard!';

  @override
  String get lbHidden =>
      'Nakatago sa mga miyembro — buksan sa mga setting ng Leaderboard';

  @override
  String get lbSeason => 'Aktibo ang season — niraranggo ang mga bagong gawain';

  @override
  String get lbJoinTitle => 'Sumali para makita ang leaderboard';

  @override
  String get lbJoinChild =>
      'Sumali sa home group ng iyong pamilya para makita ang iyong ranggo!';

  @override
  String get lbJoinStudent =>
      'Sumali sa iyong klase para makita ang iyong ranggo kasama ang mga kaklase!';

  @override
  String get lbJoinGroup => 'Sumali sa Home Group';

  @override
  String get lbNotEnabled => 'Hindi pa bukas ang leaderboard';

  @override
  String get lbNotEnabledBody =>
      'Hindi pa binubuksan ng iyong guro o magulang ang leaderboard para sa iyong grupo. Bumalik ka maya-maya!';

  @override
  String get lbNoClasses => 'Wala pang klase';

  @override
  String get lbNoGroups => 'Wala pang home group';

  @override
  String get lbNoClassesBody =>
      'Gumawa ng klase at mag-imbita ng mga mag-aaral para magsimula ng leaderboard.';

  @override
  String get lbNoGroupsBody =>
      'Gumawa ng home group at imbitahin ang iyong mga anak para magsimula ng leaderboard.';

  @override
  String get lbManageClasses => 'Pamahalaan ang mga Klase';

  @override
  String get lbManageGroups => 'Pamahalaan ang mga Home Group';

  @override
  String get lbError => 'Hindi ma-load ang leaderboard';

  @override
  String get lbErrorBody =>
      'Suriin ang iyong koneksyon at subukan ulit. Lalabas ang huling ranggo kapag online ka na ulit.';

  @override
  String get lbSort => 'Ayusin';

  @override
  String get lbPeriod => 'Panahon';

  @override
  String get lbYou => 'Ikaw';

  @override
  String get lbSortStars => 'Mga Bituin';

  @override
  String get lbSortWords => 'Mga Salitang Natutunan';

  @override
  String get lbSortStreak => 'Sunod-sunod';

  @override
  String get lbSortOverall => 'Kabuuan';

  @override
  String get lbAllTime => 'Lahat ng Panahon';

  @override
  String get lbThisWeek => 'Ngayong Linggo';

  @override
  String get lbThisMonth => 'Ngayong Buwan';

  @override
  String lbWords(int count) {
    return '$count salita';
  }

  @override
  String lbDays(int count) {
    return '$count araw';
  }

  @override
  String lbPts(int count) {
    return '$count puntos';
  }

  @override
  String setProfileSemantics(String name, String role) {
    return 'Profile: $name, $role. Pindutin ang palitan para magpalit ng profile.';
  }

  @override
  String get setNoProfile => 'Walang profile';

  @override
  String get setUnknownRole => 'hindi alam na tungkulin';

  @override
  String get dbExportCsv => 'I-export ang datos bilang CSV spreadsheet';

  @override
  String get dbExportPdf => 'I-export ang ulat ng progreso bilang PDF';

  @override
  String get dbExportResearch =>
      'I-export ang datos ng pananaliksik para sa pagsusuri ng tesis';

  @override
  String get dbBadges => 'Mga Badge';

  @override
  String get dbOverallMastery => 'Kabuuang Kahusayan';

  @override
  String get dbCategoryBreakdown => 'Hati ayon sa Kategorya';

  @override
  String get dbInsights => 'Mga Obserbasyon at Mungkahi';

  @override
  String get dbNoData =>
      'Wala pang datos ng pagkatuto. Kapag nagsimula nang maglaro at magbalik-aral ng flashcard ang mag-aaral, lalabas dito ang mga obserbasyon.';

  @override
  String get dbNeedsPractice => 'Kailangan ng Pagsasanay';

  @override
  String dbFocusOn(String category) {
    return 'Pagtuunan ang mga flashcard at laro sa $category.';
  }

  @override
  String get dbDoingGreat => 'Magaling';

  @override
  String get dbKeepItUp => 'Ituloy lang! Subukan ang mas mahirap na antas.';

  @override
  String get dbEngagement => 'Pakikilahok';

  @override
  String dbStreakActive(int streak) {
    return 'Aktibo ang $streak araw na streak sa pag-aaral!';
  }

  @override
  String get dbNoStreak =>
      'Walang aktibong streak. Subukan ang araw-araw na pagsasanay.';

  @override
  String get dbConsistent =>
      'Magaling ang pagiging tuloy-tuloy! Nabubuo na ang ugali ng mag-aaral.';

  @override
  String get dbEncourage =>
      'Hikayatin ang mag-aaral na maglaro kahit isang beses sa isang araw.';

  @override
  String get dbStudyTime => 'Oras ng Pag-aaral';

  @override
  String get dbRecentActivity => 'Mga Kamakailang Gawain';

  @override
  String get dbNoGames =>
      'Wala pang nilarong laro. Hikayatin ang mag-aaral na maglaro!';

  @override
  String get dbStudentProgress => 'Progreso ng Mag-aaral';

  @override
  String get dbMastery => 'Kahusayan';

  @override
  String get dbRecentAvg => 'Karaniwan sa Mga Huling Laro';

  @override
  String get dbDailyStreak => 'Streak sa Hamon ng Araw';

  @override
  String dbDays(int count) {
    return '$count araw';
  }

  @override
  String get dbTotalTime => 'Kabuuang Oras';

  @override
  String get dbAvgSession => 'Karaniwang Sesyon';

  @override
  String get dbSessions => 'Mga Sesyon';

  @override
  String get dbLast7Days => 'Nakaraang 7 Araw';

  @override
  String get sfSearch => 'Maghanap ng mag-aaral...';

  @override
  String get sfGrade => 'Baitang';

  @override
  String get sfSection => 'Seksyon';

  @override
  String sfResults(int count) {
    return '$count resulta';
  }

  @override
  String get sfClearAll => 'Burahin lahat';

  @override
  String get sfTags => 'Mga Tag';

  @override
  String sfTagsN(int count) {
    return 'Mga Tag ($count)';
  }

  @override
  String get sfKinder => 'Kinder';

  @override
  String sfGradeN(int n) {
    return 'Baitang $n';
  }

  @override
  String get sfHighSchool => 'Hayskul';

  @override
  String get sfCollege => 'Kolehiyo';

  @override
  String get sfActAll => 'Lahat';

  @override
  String get sfActToday => 'Aktibo Ngayon';

  @override
  String get sfActWeek => 'Aktibo Ngayong Linggo';

  @override
  String get sfActInactive => 'Hindi Aktibo 7+ Araw';

  @override
  String get sfSortName => 'Pangalan';

  @override
  String get sfSortGrade => 'Baitang';

  @override
  String get sfSortWords => 'Mga Salitang Natutunan';

  @override
  String get sfSortStreak => 'Sunod-sunod';

  @override
  String get sfSortStars => 'Mga Bituin';

  @override
  String get sfSortLastActive => 'Huling Aktibo';

  @override
  String get sfSortAccuracy => 'Katumpakan';

  @override
  String get sfSortJoined => 'Petsa ng Pagsali';

  @override
  String get msClearFilters => 'Burahin ang mga filter';

  @override
  String msCardSemantics(String name, int words, int stars, int streak) {
    return '$name, $words salitang natutunan, $stars bituin, $streak araw na streak';
  }

  @override
  String get cdExportCsv => 'I-export ang ulat na CSV';

  @override
  String get cdRefresh => 'I-refresh';

  @override
  String cdLoadError(String error) {
    return 'Hindi ma-load ang dashboard:\n$error';
  }

  @override
  String cdLastUpdated(String time) {
    return 'Huling na-update: $time';
  }

  @override
  String get cdNoStudents => 'Walang nakitang profile ng mag-aaral';

  @override
  String get cdNoStudentsBody =>
      'Gumawa ng profile ng mag-aaral para makita sila rito.\nLalabas ang bawat mag-aaral kasama ang kanilang progreso.';

  @override
  String get splDeleteTitle => 'Burahin ang Profile?';

  @override
  String splDeleteBody(String name) {
    return 'Sigurado ka bang buburahin ang “$name”? Permanenteng mawawala ang lahat ng datos ng progreso ng mag-aaral na ito.';
  }

  @override
  String get splDeleteEducator =>
      ' Mawawalan ng gurong namamahala ang mga klaseng hawak nila.';

  @override
  String splDeleted(String name) {
    return 'Nabura si $name';
  }

  @override
  String get splManageProfiles => 'Pamahalaan ang mga Profile';

  @override
  String get splStudentProfiles => 'Mga Profile ng Mag-aaral';

  @override
  String get splImportExport => 'I-import / I-export';

  @override
  String splLoadError(String error) {
    return 'Hindi ma-load ang mga mag-aaral:\n$error';
  }

  @override
  String get splNoOthers => 'Walang ibang profile sa device na ito';

  @override
  String get splNoStudents => 'Wala pang profile ng mag-aaral';

  @override
  String get splNoStudentsBody =>
      'Lalabas dito ang mga mag-aaral kapag sumali na sila sa iyong klase gamit ang code.';

  @override
  String get splShareCode => 'Ibahagi ang Code ng Klase';

  @override
  String splAge(int age) {
    return '$age taong gulang';
  }

  @override
  String get splNoAge => 'Walang nakatakdang edad o antas';

  @override
  String storyLocked(String title) {
    return '$title — nakakandado';
  }

  @override
  String storyTapToRead(String title) {
    return '$title — pindutin para basahin';
  }

  @override
  String get storyReadSuffix => ', nabasa na';

  @override
  String get storyRead => 'Nabasa';

  @override
  String get fiPictureClue => 'Pahiwatig na larawan';

  @override
  String get fiTapCartoon => 'Pindutin para makita ang drowing.';

  @override
  String get fiTapReal => 'Pindutin para makita ang totoong larawan.';

  @override
  String fiRealOf(String word) {
    return 'Totoong larawan ng $word.';
  }

  @override
  String fiRealLifeOf(String word) {
    return 'Totoong larawan ng $word';
  }

  @override
  String fiCartoonOf(String word) {
    return 'Drowing ng $word';
  }

  @override
  String get mascotBuddy => 'Kaibigang maskot';

  @override
  String profileAgeYrs(int age) {
    return '$age taon';
  }

  @override
  String scpScored(int score, int total, int stars) {
    return 'Nakakuha ng $score/$total at $stars bituin!';
  }

  @override
  String scpMastered(String category) {
    return 'Na-master ang $category!';
  }

  @override
  String scpMasteryDesc(int percent, String category) {
    return 'Umabot sa $percent% na kahusayan sa $category';
  }

  @override
  String scpStreakTitle(int days) {
    return '$days Araw na Streak!';
  }

  @override
  String scpStreakDesc(int days) {
    return 'Nag-aral nang $days araw na sunod-sunod!';
  }

  @override
  String scpAssessDesc(int score, int total, String test) {
    return 'Nakakuha ng $score/$total sa $test';
  }

  @override
  String get lvlBeginner => 'Baguhan';

  @override
  String get lvlElementary => 'Elementarya';

  @override
  String get lvlIntermediate => 'Katamtaman';

  @override
  String get lvlAdvanced => 'Mataas';

  @override
  String get lvlBeginnerDesc =>
      'Nagsisimula pa lang — madadaling salita at maiikling sesyon.';

  @override
  String get lvlElementaryDesc =>
      'Nagpaparami ng bokabularyo — medyo mas mahahabang aralin.';

  @override
  String get lvlIntermediateDesc =>
      'Kaya na ang karamihan sa mga aralin — buong haba ng mga laro.';

  @override
  String get lvlAdvancedDesc =>
      'Handa na sa mas mahihirap na hamon at mas komplikadong kwento.';

  @override
  String get signNotSet => 'Hindi pa nakatakda';

  @override
  String get signLearning => 'Natututo pa';

  @override
  String get signCanSign => 'Kaya kong isenyas ito';

  @override
  String get signUnreviewed => 'Hindi pa nasusuri';

  @override
  String get signConfirmed => 'Kumpirmado';

  @override
  String get signNeedsPractice => 'Kailangan pang sanayin';

  @override
  String get lockSumBanner => 'Paunang babala sa itaas';

  @override
  String lockSumChimes(int count) {
    return 'Tunog ng alarma ×$count';
  }

  @override
  String get lockSumOneChime => 'Isang mahinang tunog ng alarma';

  @override
  String get lockSumSpokenTwice => 'Binibigkas na mensahe (dalawang beses)';

  @override
  String get lockSumSpoken => 'Binibigkas na mensahe';

  @override
  String get lockSumPicture => 'Larawan ng pagbibigyan ng device';

  @override
  String get lockSumFslFirst =>
      'Video ng FSL muna (pindutin para lumipat sa larawan)';

  @override
  String get lockSumFslBack => 'Video ng FSL sa likod ng larawan';

  @override
  String get lockSumAlarmFirst =>
      'Animation ng alarma muna (pindutin para lumipat sa larawan)';

  @override
  String get lockSumAlarmBack =>
      'Animation ng alarma sa likod ng larawan (pindutin para ibaligtad)';

  @override
  String get lockSumVisual => 'Kumikislap na babala sa screen';

  @override
  String get lockSumVibration => 'Pag-vibrate';

  @override
  String get lockSumReader => 'Anunsyo ng screen reader';

  @override
  String get lockSumSimple => 'Maikli at simpleng pananalita';

  @override
  String get lockSumSwitch => 'Malaking button na “Palitan ang account”';

  @override
  String get lockWhyVisual =>
      'Mas maikling araw at madalas na pahinga — mas matagal ang bawat aralin kapag nakikinig, at nababawasan ang pagod ng mata.';

  @override
  String get lockWhyHearing =>
      'Karaniwang haba ng sesyon; ang pagbibigay ng device ay ipinapakita bilang video ng FSL at malaking caption sa halip na salita.';

  @override
  String get lockWhyMotor =>
      'Mas maikling araw at madalas na pahinga — nakakapagod ang tuloy-tuloy na pagpindot at paghawak. Napakalaki ng lahat ng button sa lock.';

  @override
  String get lockWhyCognitive =>
      'Maiikli at inaasahang sesyon sa takdang oras araw-araw. Isang tunog at isang maikling pangungusap lang ang lock.';

  @override
  String get lockWhyMultiple =>
      'Pinagsamang pinakamatulunging setting ng bawat profile: maiikling sesyon, simpleng pananalita, dalawang beses na binibigkas na mensahe, at malalaking button.';

  @override
  String get lockWhyNone =>
      'Karaniwang haba ng sesyon na may alarma at binibigkas na mensahe sa pagbibigay ng device.';

  @override
  String get tlTitle => 'Mga limitasyon sa oras';

  @override
  String tlTitleFor(String name) {
    return 'Mga limitasyon sa oras — $name';
  }

  @override
  String get tlSave => 'I-save';

  @override
  String tlLoadError(String error) {
    return 'Hindi ma-load: $error';
  }

  @override
  String get tlDaily => 'Limitasyon sa oras araw-araw';

  @override
  String tlMinPerDay(int minutes) {
    return '$minutes min bawat araw';
  }

  @override
  String get tlNoLimit => 'Walang limitasyon';

  @override
  String tlMinutesPerDay(int minutes) {
    return '$minutes minuto bawat araw';
  }

  @override
  String get tlSchedule => 'Pinapayagang oras';

  @override
  String get tlRestrict => 'Limitahan ayon sa oras ng araw';

  @override
  String get tlAnyTime => 'Kahit anong oras';

  @override
  String get tlStart => 'Simula ng pinapayagang oras';

  @override
  String get tlEnd => 'Katapusan ng pinapayagang oras';

  @override
  String get tlWhenUp => 'Kapag tapos na ang oras';

  @override
  String get tlWhenUpBody =>
      'Makakarinig ang bata ng alarma, saka ng mensaheng nagsasabi kung kanino ibibigay ang device.';

  @override
  String get tlWarn => 'Magbabala bago mag-lock';

  @override
  String tlWarnOn(int minutes) {
    return 'Isang banner $minutes minuto bago nito, para matapos nila ang ginagawa.';
  }

  @override
  String get tlWarnOff => 'Ang lock screen ang magiging unang babala.';

  @override
  String tlNotice(int minutes) {
    return '$minutes minutong paunawa';
  }

  @override
  String get tlAlarm => 'Magpatunog ng alarma';

  @override
  String get tlAlarmBody =>
      'Inaalerto rin nito ang nakatatanda sa silid, kaya nananatili itong bukas para sa mga mag-aaral na bingi o mahina ang pandinig.';

  @override
  String get tlSpeak => 'Bigkasin nang malakas ang mensahe';

  @override
  String get tlSpeakOn => 'Binibigkas pagkatapos ng alarma.';

  @override
  String get tlSpeakOff =>
      'Hindi gumagamit ng pananalita ang profile ng mag-aaral na ito — ipinapakita ang mensahe bilang malaking caption.';

  @override
  String get tlLockIntro =>
      'Kapag naabot ang limitasyon, makikita ng bata ang lock screen na “Tapos na ang Oras” na kailangan ng iyong PIN para maalis. Hindi mawawala ang kanilang progreso, at may button na “Palitan ang account” para magamit ng iba ang device nang hindi binubuksan ang profile na ito.';

  @override
  String tlApplied(String profile) {
    return 'Nailapat ang inirerekomendang setting para sa $profile. Pindutin ang I-save para kumpirmahin.';
  }

  @override
  String tlSaveError(String error) {
    return 'Hindi ma-save: $error';
  }

  @override
  String get tlNotCached =>
      'Wala pang kopya ng profile ng mag-aaral na ito sa device na ito, kaya nakatago ang gabay para sa kanilang aksesibilidad. Umiiral pa rin ang lahat ng setting sa ibaba.';

  @override
  String get tlAtLock =>
      'Sa oras ng lock, makakatanggap ang mag-aaral na ito ng:';

  @override
  String tlUseRecommended(int minutes) {
    return 'Gamitin ang inirerekomenda ($minutes min/araw)';
  }

  @override
  String get tlCallYou => 'Ano ang itatawag sa iyo ng bata?';

  @override
  String get tlCallHint => 'hal. Teacher Ana, Tatay, Lola';

  @override
  String get tlBlankDefault => 'Iwanang blangko para gamitin ang default.';

  @override
  String tlBlankAvatar(String honorific) {
    return 'Iwanang blangko para gamitin ang “$honorific”, na kinuha sa avatar ng iyong profile.';
  }

  @override
  String get tlWillHear => 'Maririnig ng bata';

  @override
  String get tlFslUrl => 'URL ng video ng senyas (FSL)';

  @override
  String get tlFslBlank =>
      'Iwanang blangko para gamitin ang nakalagay nang FSL clip para sa pagbibigyan ng device (Ma’am / Sir / Mommy / Daddy). Ipinapakita sa lock screen para sa mga mag-aaral na bingi o mahina ang pandinig; isang beses dina-download, saka tumutugtog kahit offline.';

  @override
  String get tlFslSet =>
      'Ipinapakita sa lock screen para sa mga mag-aaral na bingi o mahina ang pandinig. Isang beses dina-download ang clip, saka tumutugtog kahit offline.';

  @override
  String get tlFslUnused =>
      'Hindi ipinapakita ng profile ng mag-aaral na ito ang video ng FSL, kaya naka-save ito pero hindi ginagamit hangga’t hindi nagbabago ang kanilang profile.';

  @override
  String get tlNoClip =>
      'Walang nakatakdang clip. Ang nakasulat na mensahe lang ang ipapakita ng lock screen hanggang may maidagdag na URL dito.';

  @override
  String get tlEveryDay => 'Umiiral ang iskedyul araw-araw';

  @override
  String get tlSelectedDays => 'Umiiral lang ang iskedyul sa mga napiling araw';

  @override
  String tuTooMany(String time) {
    return 'Masyadong maraming subok. Subukan ulit sa loob ng $time.';
  }

  @override
  String tuActiveProfile(String name) {
    return 'Aktibong profile: $name';
  }

  @override
  String get tuEnterPin => 'Maglagay ng 4-digit na PIN.';

  @override
  String get tuWrongPin => 'Mali ang PIN. Magtanong sa iyong magulang o guro.';

  @override
  String get tuUseRecovery => 'Gamitin ang recovery code';

  @override
  String get tuRecoveryBody =>
      'Ilagay ang recovery code na lumabas nang itakda ang PIN ng profile na ito. Hindi mahalaga kung malaki o maliit ang titik.';

  @override
  String get tuRecoveryCode => 'Recovery code';

  @override
  String get tuRecoveryMismatch => 'Hindi tugma ang recovery code.';

  @override
  String get tuSignVideo => 'video ng senyas';

  @override
  String get tuAlarm => 'alarma';

  @override
  String get tuSignVideoTap =>
      'Video ng senyas. Pindutin para makita ang larawan.';

  @override
  String get tuAlarmTap =>
      'Animation ng alarm clock. Pindutin para makita ang larawan.';

  @override
  String tuTapToSeeClip(String caption, String clip) {
    return '$caption Pindutin para makita ang $clip.';
  }

  @override
  String get tuTapPicture => 'Pindutin para makita ang larawan';

  @override
  String tuTapClip(String clip) {
    return 'Pindutin para makita ang $clip';
  }

  @override
  String get tuFullScreen => 'Panoorin nang buong screen';

  @override
  String get tuEnterAdultPin =>
      'Ilagay ang PIN ng magulang / guro para magpatuloy';

  @override
  String get tuForgotPin => 'Nakalimutan ang PIN? Gamitin ang recovery code';

  @override
  String get tuSwitchNote =>
      'Hindi nabubuksan ang profile na ito kapag nagpalit ng account — nananatili itong naka-lock hanggang maglagay ng PIN ang isang nakatatanda.';

  @override
  String get tuNoAdult =>
      'Wala pang magulang o guro na naka-link sa device na ito, kaya hindi maaalis dito ang lock. Hilingin sa may-ari ng device na mag-sign in kahit isang beses.';

  @override
  String get alNew => 'Bagong alarma';

  @override
  String alLoadError(String error) {
    return 'Hindi ma-load: $error';
  }

  @override
  String get alNone =>
      'Wala pang nakatakdang alarma.\nPindutin ang “Bagong alarma” para gumawa.';

  @override
  String get alEveryDay => 'Araw-araw';

  @override
  String get alNotifyOnly => 'Abiso lang';

  @override
  String get alLockScreen => 'I-lock ang screen';

  @override
  String get alEndSession => 'Tapusin ang sesyon';

  @override
  String alSaveError(String error) {
    return 'Hindi ma-save: $error';
  }

  @override
  String get alEdit => 'Baguhin ang alarma';

  @override
  String get alLabelHint => 'hal. Oras ng tulog, Oras ng takdang-aralin';

  @override
  String get alTime => 'Oras';

  @override
  String get alRepeat => 'Ulitin tuwing';

  @override
  String get alNoDays => 'Walang napiling araw → tutunog araw-araw';

  @override
  String get alWhen => 'Kapag tumunog ang alarma';

  @override
  String get alLockPin => 'I-lock ang screen (PIN ng magulang para mabuksan)';

  @override
  String get alEndHome => 'Tapusin ang sesyon at bumalik sa Home';

  @override
  String get scTitleCheck => 'Pagsusuri ng Senyas';

  @override
  String scNoClaims(String name) {
    return 'Wala pang minarkahang senyas si $name. Lalabas dito ang mga ito kapag ginamit nila ang “Kaya kong isenyas ito” sa diksyunaryo o natapos ang isang round ng Sign It.';
  }

  @override
  String scHowTo(String name) {
    return 'Panoorin ang halimbawang clip, hilingin kay $name na isenyas ito, saka itala ang nakita mo. Kapag kinumpirma mo, makukuha nila ang senyas.';
  }

  @override
  String scToCheck(int count) {
    return '$count susuriin';
  }

  @override
  String get scOnlyUnchecked => 'Ang mga hindi ko pa nasusuri lang';

  @override
  String get scNothingLeft => 'Wala nang susuriin. Magaling.';

  @override
  String get scSaysCan => 'Sabi: “Kaya kong isenyas ito”';

  @override
  String get scSaysNotYet => 'Sabi: “Hindi pa”';

  @override
  String get scWatchRef => 'Panoorin ang halimbawang senyas';

  @override
  String get scConfirm => 'Kumpirmahin';

  @override
  String get cdsCustomize => 'I-customize ang progreso';

  @override
  String get cdsActiveToday => 'Aktibo ngayon';

  @override
  String cdsLastActive(String when) {
    return 'Huling aktibo $when';
  }

  @override
  String cdsStreak(int days) {
    return '$days araw na streak';
  }

  @override
  String get cdsRecentGames => 'Mga Kamakailang Laro';

  @override
  String cdsSignCheck(int count) {
    return 'Pagsusuri ng Senyas · $count susuriin';
  }

  @override
  String get cdsDailyRoutine => 'Pang-araw-araw na Gawain';

  @override
  String get cdsFullDashboard => 'Tingnan ang Buong Dashboard';

  @override
  String get cdsToday => 'ngayon';

  @override
  String get cdsYesterday => 'kahapon';

  @override
  String cdsDaysAgo(int count) {
    return '$count araw ang nakalipas';
  }

  @override
  String cdsWeeksAgo(int count) {
    return '$count linggo ang nakalipas';
  }

  @override
  String get cdsQuickStats => 'Mabilisang Numero';

  @override
  String cdsOfTotal(int total) {
    return 'sa $total lahat';
  }

  @override
  String get cdsAvailable => 'magagamit';

  @override
  String get cdsSignsWatched => 'Mga Senyas na Napanood';

  @override
  String cdsOfSigns(int total) {
    return 'sa $total senyas';
  }

  @override
  String get cdsFslClips => 'Mga clip ng FSL';

  @override
  String get cdsGreat => 'Magaling!';

  @override
  String get cdsGoodProgress => 'Magandang progreso';

  @override
  String get cdsCategories => 'Mga Kategorya';

  @override
  String get cdsMasteredPct => 'na-master (≥80%)';

  @override
  String get cdsThisWeek => 'ngayong linggo';

  @override
  String get cdsGamesPlayed => 'Mga Nilarong Laro';

  @override
  String cdsSessions(int count) {
    return '$count sesyon';
  }

  @override
  String get cdsHuntFinds => 'Mga Nahanap sa Word Hunt';

  @override
  String cdsHuntStreak(int days) {
    return '$days araw na streak';
  }

  @override
  String get cdsWithCamera => 'gamit ang camera';

  @override
  String get cdsStrengths => 'Mga Kalakasan at Dapat Pagbutihin';

  @override
  String cdsStrongest(String category) {
    return 'Pinakamalakas: $category';
  }

  @override
  String cdsPctMastery(int percent) {
    return '$percent% kahusayan';
  }

  @override
  String cdsNeedsWork(String category) {
    return 'Kailangang pagbutihin: $category';
  }

  @override
  String cdsPctMasteryMore(int percent) {
    return '$percent% kahusayan — hikayatin ang mas maraming pagsasanay dito';
  }

  @override
  String cdsUnexplored(int count) {
    return '$count kategoryang hindi pa nasusubukan';
  }

  @override
  String get cdsJustStarting => 'Nagsisimula pa lang!';

  @override
  String cdsEncourage(String name) {
    return 'Hikayatin si $name na subukan ang ilang flashcard o laro.';
  }

  @override
  String get pcSaved => 'Na-save ang parental controls! ✅';

  @override
  String get pcTitle => 'Kontrol ng Magulang';

  @override
  String get pcIntro =>
      'Magtakda ng mga limitasyon sa paggamit ng app ng mga mag-aaral. Umiiral ang mga ito sa lahat ng profile ng mag-aaral sa device na ito.';

  @override
  String get pcDaily => 'Limitasyon sa Oras Araw-araw';

  @override
  String get pcEnableLimit => 'Buksan ang Limitasyon sa Oras';

  @override
  String pcMinutesPerDay(int minutes) {
    return '$minutes minuto bawat araw';
  }

  @override
  String get pcNoRestriction => 'Walang limitasyon sa oras';

  @override
  String pcMin(int minutes) {
    return '$minutes min';
  }

  @override
  String get pc15 => '15 min';

  @override
  String get pc3h => '3 oras';

  @override
  String get pcSchedule => 'Iskedyul ng Paggamit';

  @override
  String get pcEnableSchedule => 'Buksan ang Iskedyul';

  @override
  String pcAllowed(String start, String end) {
    return 'Pinapayagan: $start – $end';
  }

  @override
  String get pcNoTimeOfDay => 'Walang limitasyon sa oras ng araw';

  @override
  String get pcStart => 'Simula';

  @override
  String get pcEnd => 'Katapusan';

  @override
  String get pcFeatures => 'Mga Limitasyon sa Feature';

  @override
  String get pcBlockShop => 'Harangin ang Tindahan ng Bituin';

  @override
  String get pcBlockShopSub =>
      'Pigilan ang mga mag-aaral na gumastos ng bituin';

  @override
  String get pcBlockMulti => 'Harangin ang Multiplayer';

  @override
  String get pcBlockMultiSub => 'Isara ang multiplayer quiz';

  @override
  String get pcBlockMsg => 'Harangin ang Pagmemensahe';

  @override
  String get pcBlockMsgSub => 'Isara ang pagmemensahe sa app';

  @override
  String get pcBlockedGames => 'Mga Hinarangang Laro';

  @override
  String get pcBlockedGamesSub =>
      'Pumili ng mga larong itatago sa mga mag-aaral';

  @override
  String get pcBlockedCats => 'Mga Hinarangang Kategorya';

  @override
  String get pcBlockedCatsSub =>
      'Pumili ng mga kategoryang itatago sa flashcard at laro';

  @override
  String get pcReset => 'I-reset Lahat ng Kontrol';

  @override
  String get pcVeryShort => 'Napakaikli';

  @override
  String get pcShort => 'Maikli';

  @override
  String get pcModerate => 'Katamtaman';

  @override
  String get pcStandard => 'Karaniwan';

  @override
  String get pcExtended => 'Mahaba';

  @override
  String get lgcTitle => 'Pag-unlad sa Pagkatuto';

  @override
  String get woStudyMinutes => 'Minuto ng pag-aaral';

  @override
  String get apAdaptive => 'Umaangkop na Hirap';

  @override
  String get apDyslexia => 'Para sa may dyslexia';

  @override
  String get apFslVideos => 'Mga Video ng FSL';

  @override
  String get apFontSize => 'Laki ng Letra';

  @override
  String get apGaze => 'Kontrol gamit ang Tingin';

  @override
  String get apHighContrast => 'Mataas na Contrast';

  @override
  String get apReducedMotion => 'Bawas na Galaw';

  @override
  String get apSoundEffects => 'Mga Sound Effect';

  @override
  String get apTts => 'Text-to-Speech';

  @override
  String get apVoiceNav => 'Paggabay gamit ang Boses';

  @override
  String get apOn => 'Bukas';

  @override
  String get apOff => 'Sarado';

  @override
  String get apPrioritized => 'Inuuna';

  @override
  String get apXl130 => 'Napakalaki (130%)';

  @override
  String get apXl140 => 'Napakalaki (140%)';

  @override
  String get apLarge120 => 'Malaki (120%)';

  @override
  String get apHandsFree => 'Bukas (walang kamay)';

  @override
  String get apSlow => 'Bukas (Mabagal)';

  @override
  String get apVerySlow => 'Bukas (Napakabagal)';

  @override
  String obWelcome(String name) {
    return 'Maligayang pagdating, $name! 🎉';
  }

  @override
  String get obWelcomeLearner =>
      'Handa ka nang magsimulang matuto! Tara, libutin natin sandali ang lahat ng puwede mong gawin.';

  @override
  String get obWelcomeTeacher =>
      'Handa na ang iyong account! Ipapakita namin ang mahahalagang feature na gagamitin mo sa paggabay sa iyong mga mag-aaral.';

  @override
  String get obWelcomeParent =>
      'Handa na ang iyong account! Ipapakita namin ang mahahalagang feature na gagamitin mo sa pagsuporta sa pag-aaral ng iyong anak.';

  @override
  String get obFlashTitle => 'Matuto gamit ang mga Flashcard 📚';

  @override
  String get obFlashLearner =>
      'Tingnan ang mga kategorya ng salita tulad ng Mga Hayop, Mga Kulay, Mga Numero, at iba pa. May larawan, Filipino Sign Language, at pagbasa nang malakas ang bawat kard para matulungan kang matuto.';

  @override
  String get obFlashAdult =>
      'Natututo ng bokabularyo ang mga mag-aaral gamit ang interactive na flashcard na may larawan, FSL, at pagbasa nang malakas sa iba’t ibang kategorya.';

  @override
  String get obGamesTitle => 'Maglaro ng Masasayang Laro 🎮';

  @override
  String get obGamesLearner =>
      'Sanayin ang natutunan mo gamit ang Word Match, Spelling Bee, Memory Match, Jigsaw Puzzle, at iba pa! Makakuha ng bituin ⭐ sa bawat larong lalaruin mo.';

  @override
  String get obGamesAdult =>
      'Pinatitibay ng mga mag-aaral ang bokabularyo sa 10+ larong pang-edukasyon na may naaayos na hirap at filter ng kategorya.';

  @override
  String get obProgressTitle => 'Subaybayan ang Iyong Progreso ⭐';

  @override
  String get obProgressLearner =>
      'Tingnan ang iyong streak, mga bituin, at mga salitang natutunan. Magbukas ng mga badge at gastusin ang bituin sa Tindahan ng Bituin para sa mga avatar at tema!';

  @override
  String get obProgressAdult =>
      'Subaybayan ang progreso sa pagkatuto gamit ang mga dashboard na nagpapakita ng kahusayan, streak, hati ayon sa kategorya, at mga ulat na mai-export.';

  @override
  String get obAccessTitle => 'Para sa Lahat ♿';

  @override
  String get obAccessBody =>
      'Ginawa ang FlashLearn PWD para sa mga mag-aaral na may kapansanan. Iayos ang laki ng letra, contrast, animation, at audio sa Mga Setting ayon sa pangangailangan. May mga nakahandang setting para sa paningin, pandinig, paggalaw, at pag-iisip.';

  @override
  String get obReadyTitle => 'Handa Ka Na! 🚀';

  @override
  String get obReadyLearner =>
      'Pindutin ang isang kategorya sa Home para matutunan ang iyong mga unang salita, o maglaro para magsimulang mag-ipon ng bituin. Magsaya!';

  @override
  String get obReadyTeacher =>
      'Libutin ang Home para makita ang lahat ng feature. Gamitin ang dashboard para subaybayan ang progreso ng mga mag-aaral.';

  @override
  String get obReadyParent =>
      'Libutin ang Home para makita ang lahat ng feature. Samahan ang iyong anak at mag-aral nang magkasama!';

  @override
  String get asOptimize =>
      'Iaangkop namin ang app sa iyong pangangailangan.\nPiliin ang pinakaangkop na naglalarawan sa iyo:';

  @override
  String get asNoSpecial =>
      'Walang kailangang espesyal na setting!\nHanda ka na sa mga default.';

  @override
  String get asDyslexiaSub =>
      'Kulay-krema na background, font na Lexend, at mas malapad na pagitan ng letra — mas madaling basahin ng lahat.';

  @override
  String get asMotionSub =>
      'Mas kaunting animation at mabilis na paglipat ng pahina — mabuti para sa sensitibo sa galaw o lumang device.';

  @override
  String get asChangeLater =>
      'Mababago mo ang mga ito anumang oras sa Mga Setting ⚙️';

  @override
  String get asAllSet => 'Handa Ka Na! 🎉';

  @override
  String asOptimizedFor(String type) {
    return 'Naiangkop na ang iyong app para sa\n$type.';
  }

  @override
  String get asStandardReady => 'Handa na ang mga karaniwang setting.';

  @override
  String get asAdjustLater =>
      'Mababago mo ang lahat ng setting anumang oras\nsa pahina ng Mga Setting.';

  @override
  String get asSaveFinish => 'I-save at Tapusin';

  @override
  String get asComfort => 'Mga pagbabagong puwede mong subukan mamaya';

  @override
  String get mrClass => 'Inalis ka sa iyong klase.';

  @override
  String get mrGroup => 'Inalis ka sa iyong home group.';

  @override
  String mrFrom(String name) {
    return 'Inalis ka sa $name.';
  }

  @override
  String get mrSafeClass =>
      'Ligtas ang iyong progreso sa device na ito. Maaari kang sumali sa ibang klase gamit ang bagong code.';

  @override
  String get mrSafeGroup =>
      'Ligtas ang iyong progreso sa device na ito. Maaari kang sumali sa ibang home group gamit ang bagong code.';

  @override
  String get mrReturning => 'Awtomatikong babalik sa setup…';

  @override
  String get spdCategoryProgress => 'Progreso ayon sa Kategorya';

  @override
  String get spdRecentScores => 'Mga Kamakailang Iskor sa Laro';

  @override
  String get spdDetails => 'Mga Detalye ng Profile';

  @override
  String get spdPinProtected => 'May PIN';

  @override
  String spdMastered(int mastered, int total) {
    return '$mastered sa $total kategorya ang na-master';
  }

  @override
  String get spdBirthDate => 'Petsa ng Kapanganakan';

  @override
  String get spdEditProfile => 'I-edit ang Profile';

  @override
  String get psAddNew => 'Magdagdag ng Bagong Profile';

  @override
  String get psPinLength => 'Dapat eksaktong 4 na digit ang PIN';

  @override
  String get epEnterName => 'Maglagay ng pangalan';

  @override
  String get epPinMismatch => 'Hindi magkatugma ang mga PIN';

  @override
  String get epUpdated => 'Na-update ang profile! ✅';

  @override
  String get epApplyPresetsTitle => 'Ilapat ang mga Setting sa Aksesibilidad?';

  @override
  String epApplyPresetsBody(String type) {
    return 'Pinalitan ang uri ng kapansanan sa “$type”. Gusto mo bang awtomatikong iayos ang mga setting sa aksesibilidad?';
  }

  @override
  String get epKeepCurrent => 'Panatilihin';

  @override
  String get epApplyPresets => 'Ilapat';

  @override
  String get epNoProfileBody => 'Pumili ng profile na ie-edit.';

  @override
  String get epTapAvatar => 'Pindutin sa ibaba para palitan ang avatar';

  @override
  String epAvatarSemantics(String name) {
    return 'Avatar na $name';
  }

  @override
  String get epSelectedSuffix => ', napili';

  @override
  String get epPremium => 'Mga Espesyal na Avatar';

  @override
  String get epEarnStars =>
      'Mag-ipon ng bituin sa mga laro para mabuksan ang mga espesyal na avatar!';

  @override
  String epCosts(String emoji, String name, int cost) {
    return '$emoji $name ay $cost ⭐ — pumunta sa Tindahan ng Bituin!';
  }

  @override
  String epPremiumSemantics(String name) {
    return 'Espesyal na avatar na $name';
  }

  @override
  String get epOwnedSuffix => ', pag-aari mo na';

  @override
  String epLockedSuffix(int cost) {
    return ', nakakandado, $cost bituin';
  }

  @override
  String get epName => 'Pangalan';

  @override
  String get epEnterYourName => 'Ilagay ang iyong pangalan';

  @override
  String get epLearningLevel => 'Antas ng Pagkatuto';

  @override
  String get epSetByTeacher => 'Itinakda ng iyong guro';

  @override
  String get epGradeLevel => 'Baitang';

  @override
  String get epSelectGrade => 'Pumili ng baitang';

  @override
  String get epNotSet => 'Hindi nakatakda';

  @override
  String get epSection => 'Seksyon / Klase';

  @override
  String get epSectionHint => 'hal., Seksyon A, Rosas';

  @override
  String epAge(int age) {
    return '(Edad: $age)';
  }

  @override
  String get epTags => 'Mga Tag';

  @override
  String get epTagsHelp =>
      'Magdagdag ng sariling label para maiayos ang mga mag-aaral';

  @override
  String get epAddTag => 'Magdagdag ng tag...';

  @override
  String get epInterests => 'Mga Interes sa Pag-aaral';

  @override
  String get epInterestsHelp =>
      'Pumili ng mga paboritong paksa para iangkop ang mga aralin';

  @override
  String get epAccessProfile => 'Profile ng Aksesibilidad';

  @override
  String get epAccessHelp =>
      'Kapag binago ito, iaalok na awtomatikong iayos ang mga setting sa aksesibilidad';

  @override
  String get epPinProtection => 'Proteksyon ng PIN';

  @override
  String get epIsProtected => 'May PIN ang profile na ito';

  @override
  String get epAddPin =>
      'Maglagay ng 4-digit na PIN para protektahan ang profile na ito';

  @override
  String get epRemovePin => 'Alisin ang PIN';

  @override
  String get epPinRemovedOnSave => 'Aalisin ang PIN kapag nag-save ka';

  @override
  String get epEnablePin => 'Buksan ang PIN lock';

  @override
  String get epEnterPin => 'Ilagay ang 4-digit na PIN';

  @override
  String get epConfirmPin => 'Kumpirmahin ang PIN';

  @override
  String get epRole => 'Tungkulin';

  @override
  String get epCannotChange => 'Hindi mababago';

  @override
  String get setVoiceTour => 'Gabay sa Boses at Paglilibot';

  @override
  String get setVoiceTourSub =>
      'Pakinggan kung paano gumagana ang bawat screen';

  @override
  String get setTutorialsReset =>
      'Lalabas ulit ang mga tutorial sa bawat screen!';

  @override
  String get setPinRemoved => 'Inalis ang PIN';

  @override
  String get setPinSet => 'Naitakda ang PIN!';

  @override
  String get setEnterPin => 'Ilagay ang PIN';

  @override
  String get setNoDataLeaves =>
      'Walang ipinapadalang usage statistics o crash report';

  @override
  String get brTitle => 'Backup at Pagbalik';

  @override
  String get brKeepSafe => 'Panatilihing Ligtas ang Iyong Datos';

  @override
  String get brIntro =>
      'I-back up ang lahat ng profile, progreso, nakamit, biniling item, setting, at sariling flashcard. Maibabalik ito sa kahit anong device.';

  @override
  String brLastBackup(String when) {
    return 'Huling backup: $when';
  }

  @override
  String get brCreate => 'Gumawa ng Backup';

  @override
  String get brCreateSub =>
      'I-export ang lahat ng datos ng app bilang .flashlearn na file';

  @override
  String get brCreating => 'Ginagawa…';

  @override
  String get brBackUpNow => 'I-back Up Ngayon';

  @override
  String get brRestoreFrom => 'Ibalik mula sa Backup';

  @override
  String get brRestoreSub =>
      'Mag-import ng .flashlearn na file para maibalik ang lahat ng datos';

  @override
  String get brRestoring => 'Ibinabalik…';

  @override
  String get brRestore => 'Ibalik';

  @override
  String get brIncluded => 'KASAMA RITO';

  @override
  String get brProfiles => 'Lahat ng profile ng mag-aaral';

  @override
  String get brProgress => 'Progreso at mga nakamit';

  @override
  String get brStars => 'Mga bituin at biniling item';

  @override
  String get brCustomCards => 'Mga sariling flashcard';

  @override
  String get brSettings => 'Mga setting ng app at aksesibilidad';

  @override
  String get brAnalytics => 'Datos ng mga sesyon';

  @override
  String get brSpaced => 'Datos ng spaced repetition';

  @override
  String get brWarning =>
      'Papalitan ng pagbabalik ng backup ang lahat ng kasalukuyang datos. Gumawa muna ng backup bago magbalik.';

  @override
  String get brCreated => 'Nagawa ang backup!';

  @override
  String get brCreateFailed => 'Hindi nagawa ang backup.';

  @override
  String get brRestoreTitle => 'Ibalik ang Backup?';

  @override
  String get brRestoreBody =>
      'Papalitan nito ang LAHAT ng kasalukuyang datos ng laman ng backup. Hindi na ito maibabalik.\n\nSiguraduhing may backup ka muna ng kasalukuyang datos.';

  @override
  String ieExported(String name) {
    return 'Na-export si $name';
  }

  @override
  String ieExportFailed(String error) {
    return 'Hindi na-export: $error';
  }

  @override
  String ieImportFailed(String error) {
    return 'Hindi na-import: $error';
  }

  @override
  String get ieImportTitle => 'Mag-import ng Profile ng Mag-aaral';

  @override
  String get ieImportSub =>
      'Ibalik ang profile ng mag-aaral mula sa JSON file na na-export ng ibang device.';

  @override
  String get ieImporting => 'Ini-import…';

  @override
  String get ieChooseFile => 'Pumili ng File';

  @override
  String get ieExportStudent => 'Mag-export ng Mag-aaral';

  @override
  String get ieExportSub =>
      'Pindutin ang isang mag-aaral sa ibaba para i-export ang kanilang profile, progreso, at mga nakamit bilang JSON file.';

  @override
  String get ieNoStudents => 'Walang profile ng mag-aaral na mai-export';

  @override
  String get ieExport => 'I-export';

  @override
  String get baEnterEmail => 'Maglagay ng email';

  @override
  String get baValidEmail => 'Maglagay ng tamang email address';

  @override
  String get baPwLength => 'Dapat hindi bababa sa 8 character ang password';

  @override
  String get baPwMismatch => 'Hindi magkatugma ang mga password';

  @override
  String get baEmailInUse =>
      'May account na ang email na iyan. Piliin na lang ang “May account na ako”.';

  @override
  String get baWeakPw =>
      'Masyadong madaling hulaan ang password na iyan. Gumamit ng 8+ character.';

  @override
  String get baBadEmail => 'Mukhang hindi tamang email address iyan.';

  @override
  String get baWrongCreds => 'Mali ang email o password.';

  @override
  String get baDisabled => 'Naka-disable ang account na iyan.';

  @override
  String get baOffline => 'Walang internet. Subukan ulit kapag online ka na.';

  @override
  String get baTooMany =>
      'Masyadong maraming subok. Maghintay ng isang minuto at subukan ulit.';

  @override
  String get baLinkedElsewhere =>
      'Naka-link na ang device na ito sa ibang account.';

  @override
  String baSignInFailed(String code) {
    return 'Hindi nakapag-sign in ($code).';
  }

  @override
  String baLinked(String email) {
    return 'Na-link ang account! Naka-back up na ang iyong datos sa $email.';
  }

  @override
  String get baSignedInNone =>
      'Naka-sign in na. Walang nakitang backup para sa account na ito.';

  @override
  String baSignedInRestored(int count) {
    return 'Naka-sign in na. Naibalik ang $count profile mula sa cloud.';
  }

  @override
  String get baEnterEmailFirst =>
      'Ilagay muna ang iyong email sa itaas bago humiling ng reset.';

  @override
  String baResetSent(String email) {
    return 'Naipadala ang email para sa pag-reset ng password sa $email.';
  }

  @override
  String get baSignOutTitle => 'Mag-sign out sa naka-link na account?';

  @override
  String get baSignOutBody =>
      'Gagana pa rin ang app kahit offline, pero gagamit ng bagong anonymous na sesyon ang mga bagong isusulat sa cloud. Mananatili sa device na ito ang iyong mga profile — hindi sila mabubura.';

  @override
  String get baSignOut => 'Mag-sign out';

  @override
  String get baSignedOut => 'Naka-sign out na.';

  @override
  String get baTitle => 'Backup at Pag-link ng Account';

  @override
  String get baActive => 'Aktibo ang backup';

  @override
  String get baNone => 'Wala pang backup';

  @override
  String baLinkedTo(String email) {
    return 'Naka-link sa $email. Mag-sign in gamit ang email na ito sa bagong device para maibalik ang iyong mga profile at progreso.';
  }

  @override
  String get baUnknownEmail => '(hindi alam na email)';

  @override
  String get baLocalOnly =>
      'Sa device na ito lang naka-save ang iyong datos. Mag-link ng email sa ibaba para maibalik ang lahat kung mawala o ma-reset ang device.';

  @override
  String get baSignInRestore => 'Mag-sign in para maibalik';

  @override
  String get baCreateBackup => 'Gumawa ng backup';

  @override
  String get baUseOther =>
      'Gamitin ang email at password na itinakda mo sa iyong ibang device.';

  @override
  String get baPickCreds =>
      'Pumili ng email at password para i-back up ang device na ito. Hindi kailangan ng email para sa beripikasyon.';

  @override
  String get baEmail => 'Email';

  @override
  String get baPassword => 'Password';

  @override
  String get baHidePw => 'Itago ang password';

  @override
  String get baShowPw => 'Ipakita ang password';

  @override
  String get baConfirmPw => 'Kumpirmahin ang password';

  @override
  String get baSignInRestoreBtn => 'Mag-sign in at ibalik';

  @override
  String get baLinkDevice => 'I-link ang device na ito';

  @override
  String get baCreateOne => 'Wala ka pang account? Gumawa ng isa';

  @override
  String get baHaveOne => 'May account na ako — mag-sign in';

  @override
  String get baForgot =>
      'Nakalimutan ang password? Magpadala ng email para sa reset';

  @override
  String get baSendReset => 'Magpadala ng email para sa pag-reset ng password';

  @override
  String get baSignOutLinked => 'Mag-sign out sa naka-link na account';

  @override
  String get rcNotFound =>
      'Walang nakitang profile para sa code na iyan. Suriing mabuti ang bawat letra at subukan ulit.';

  @override
  String get rcAlreadyUsed =>
      'Nagamit na ang recovery code na ito. Gumawa ng bago mula sa orihinal na device, o makipag-ugnayan sa iyong guro.';

  @override
  String get rcInvalid =>
      'Mukhang mali ang code. Suriin ang mga letrang magkamukha (hal. zero / O).';

  @override
  String get rcDenied =>
      'Tinanggihan ng cloud ang kahilingang ito. Hilingin sa iyong guro na suriin ang cloud setup ng app.';

  @override
  String get rcCollision => 'Hindi nakagawa ng natatanging code. Subukan ulit.';

  @override
  String get rcNetwork =>
      'Hindi maabot ang cloud. Suriin ang koneksyon sa internet at subukan ulit.';

  @override
  String get rcUnknown => 'May nangyaring mali. Subukan ulit.';

  @override
  String rcWelcomeBack(String name) {
    return 'Maligayang pagbabalik, $name!';
  }

  @override
  String rcRestoreFailed(String error) {
    return 'May nangyaring mali habang ibinabalik ang iyong profile: $error';
  }

  @override
  String get rcTitle => 'Ibalik ang Profile';

  @override
  String get rcFormatHint =>
      'Mga letra lang, malaki man o maliit. Hindi kailangan ang gitling.';

  @override
  String get rcRestoreMine => 'Ibalik ang aking profile';

  @override
  String get rcNoCloud =>
      'Hindi nakakonekta sa cloud ang device na ito. Kumonekta sa internet para maibalik ang profile.';

  @override
  String get rcLookingUp => 'Hinahanap ang code…';

  @override
  String get rcVerifying => 'Sinusuri…';

  @override
  String get rcRestoring => 'Ibinabalik ang profile…';

  @override
  String get rcLoadingProgress => 'Nilo-load ang progreso…';

  @override
  String get rcDone => 'Tapos na!';

  @override
  String get rcWelcome => 'Maligayang pagbabalik!';

  @override
  String get rcIntro =>
      'Ilagay ang recovery code na itinabi mo mula sa dati mong device para maibalik dito ang iyong profile at progreso.';

  @override
  String get rcEnterCode => 'Ilagay ang iyong recovery code';

  @override
  String get rcCodeFormat => '10 letra/numero ang code (puwedeng may gitling)';

  @override
  String get rcCreated =>
      'Nagawa ang recovery code. Itabi ito sa ligtas na lugar.';

  @override
  String get rcBackupTitle => 'Backup at Pagbawi';

  @override
  String get rcSelectProfile =>
      'Pumili muna ng profile para makita ang recovery code nito.';

  @override
  String rcExplain(String name) {
    return 'Sa recovery code, maibabalik ni $name ang kanyang profile at progreso sa bagong device kung mawala o mapalitan ang device na ito.';
  }

  @override
  String get rcNoneYet => 'Wala pang recovery code';

  @override
  String get rcGenerateNow =>
      'Gumawa ng code na minsan lang magagamit. Isulat ito o kunan ng litrato — kakailanganin mo ito para maibalik ang profile na ito sa ibang device.';

  @override
  String get rcGenerating => 'Ginagawa…';

  @override
  String get rcGenerate => 'Gumawa ng recovery code';

  @override
  String get rcCodeCreated => 'Nagawa ang code!';

  @override
  String get rcYourCode => 'Ang iyong recovery code';

  @override
  String get rcCopied => 'Nakopya ang recovery code';

  @override
  String get rcCopy => 'Kopyahin';

  @override
  String get rcSaveWarning =>
      'Itabi ang code na ito sa ligtas na lugar. Kapag nawala ito AT hindi mo na magamit ang device na ito, hindi na maibabalik ang profile.';

  @override
  String get rcRegenerating => 'Gumagawa ng bago…';

  @override
  String get rcNewCode => 'Gumawa ng bagong code';

  @override
  String get rcRevokes =>
      'Kapag gumawa ng bago, hindi na magagamit ang dating code.';

  @override
  String get jcNoClass =>
      'Walang klaseng may ganyang code. Suriin ang code kasama ang iyong guro.';

  @override
  String get jcNoGroup =>
      'Walang home group na may ganyang code. Suriin ang code kasama ang iyong magulang.';

  @override
  String get jcNetwork =>
      'Hindi masuri ang code. Siguraduhing online ang tablet, saka subukan ulit.';

  @override
  String get jcUnknown => 'May nangyaring mali habang sumasali. Subukan ulit.';

  @override
  String get csxAuthTitle => 'Hindi pa handa ang pag-sign in sa cloud';

  @override
  String get csxAuthBody =>
      'Hindi nakapag-sign in nang anonymous ang app, kaya tinatanggihan ng Firestore ang pagsusulat. Mga karaniwang solusyon:\n\n1) Firebase Console → Authentication → Sign-in method → buksan ang Anonymous.\n2) I-deploy ang security rules: `firebase deploy --only firestore:rules`.\n3) Ikonekta ang device sa internet sa isang pagbukas para matapos ang pag-sign in.';

  @override
  String get csxLockedTitle => 'Nakakandado ang profile sa ibang device';

  @override
  String get csxLockedBody =>
      'Ginawa ang profile na ito sa ibang device (o bago muling na-install ang app). Pindutin ang “I-reset para sa device na ito” para makuha ito rito, o mag-sign in sa orihinal na device.';

  @override
  String get csxSetupTitle => 'Hindi kumpleto ang cloud setup';

  @override
  String get csxSetupBody =>
      'Tinanggihan ng Firestore ang kahilingan. Gawin minsan ang mga hakbang na ito, saka subukan ulit:\n\n1) Firebase Console → Authentication → Sign-in method → buksan ang Anonymous.\n2) Mula sa project root: `firebase deploy --only firestore:rules`.\n3) Ikonekta ang device sa internet sa kahit isang pagbukas.';

  @override
  String get csxOffline => 'Offline';

  @override
  String get csxOfflineBody =>
      'Ang huling na-save na datos ang nakikita mo. Magsi-sync ang mga bagong pagbabago kapag online na ulit ang device.';

  @override
  String get csxWrong => 'May nangyaring mali';

  @override
  String get csxWrongBody =>
      'Subukan ulit. Kung patuloy itong nangyayari, buksan ang mga detalye sa ibaba at ibahagi sa suporta.';

  @override
  String get csxDetails => 'Mga Detalye';

  @override
  String get csxRetrying => 'Sinusubukan ulit…';

  @override
  String get csxReset => 'Na-reset ang profile para sa device na ito.';

  @override
  String csxResetFailed(String error) {
    return 'Hindi na-reset: $error';
  }

  @override
  String get csxResetButton => 'I-reset para sa device na ito';

  @override
  String get ssCloudSync => 'Cloud Sync';

  @override
  String get ssNotConfigured => 'Hindi naka-set up';

  @override
  String get ssIssue => 'Problema sa Sync';

  @override
  String ssFailedRetry(int count) {
    return '$count ang hindi naipadala — pindutin para subukan ulit';
  }

  @override
  String get ssPending => 'Naghihintay ng Sync';

  @override
  String get ssAllUploaded => 'Naipadala na ang lahat ng datos';

  @override
  String get ssFailed => 'Hindi Nag-sync';

  @override
  String get ssTapRetry => 'Pindutin para subukan ulit';

  @override
  String get ssWhenOnline => 'Magsi-sync kapag online na';

  @override
  String get ssTapSync => 'Pindutin para mag-sync ngayon';

  @override
  String get crbOff => 'NAKASARA ang cloud sync — sa device lang.';

  @override
  String crbBody(String reason) {
    return 'Hindi masasalihan mula sa ibang device ang mga code na gagawin mo rito. $reason';
  }

  @override
  String ssUploadingN(int count) {
    return 'Ipinapadala ang $count pagbabago';
  }

  @override
  String get ssUploading => 'Ipinapadala ang datos';

  @override
  String get ssJustNow => 'Nag-sync ngayon lang';

  @override
  String ssMinutes(int count) {
    return 'Nag-sync $count min ang nakalipas';
  }

  @override
  String ssHours(int count) {
    return 'Nag-sync $count oras ang nakalipas';
  }

  @override
  String ssDays(int count) {
    return 'Nag-sync $count araw ang nakalipas';
  }

  @override
  String get vgTitle => 'Mode na Ginagabayan ng Boses';

  @override
  String get vgEnabled => 'Bukas na ang paggabay gamit ang boses.';

  @override
  String get vgSpeed => 'Bilis ng Boses';

  @override
  String get vgSlow => 'Mabagal';

  @override
  String get vgFast => 'Mabilis';

  @override
  String get vgLanguage => 'Wika ng Boses';

  @override
  String get vgSpeaking => 'Nagsasalita...';

  @override
  String get vgTest => 'Subukan ang Boses';

  @override
  String get vgTour => 'Gabay na Paglilibot';

  @override
  String get vgTourIntro =>
      'Libutin nang hakbang-hakbang ang buong app, na may boses na nagpapaliwanag sa bawat screen.';

  @override
  String get vgStartTour => 'Simulan ang Paglilibot';

  @override
  String get vgPrevious => 'Nakaraan';

  @override
  String get vgFinish => 'Tapusin ang Paglilibot';

  @override
  String get vgQuick => 'Mabilisang Anunsyo ng Screen';

  @override
  String get vgQuickIntro =>
      'Pindutin ang kahit anong button sa ibaba para marinig ang paglalarawan ng screen na iyon.';

  @override
  String get vgVerySlow => 'Napakabagal';

  @override
  String get vgNormal => 'Karaniwan';

  @override
  String get vgVeryFast => 'Napakabilis';

  @override
  String get vgTourDone => 'Tapos na ang paglilibot. Handa ka na!';

  @override
  String get vgNav => 'Paggabay gamit ang Boses';

  @override
  String get vgActive => 'Bukas — Ina-anunsyo ang mga screen at button';

  @override
  String get vgTapEnable =>
      'Pindutin ang switch para buksan ang mga anunsyo gamit ang boses';

  @override
  String get vgChipHome => '🏠 Home';

  @override
  String get vgChipCards => '📚 Mga Flashcard';

  @override
  String get vgChipGames => '🎮 Mga Laro';

  @override
  String get vgChipProgress => '📊 Progreso';

  @override
  String get vgChipStories => '📖 Mga Kwento';

  @override
  String get vgChipShop => '⭐ Tindahan';

  @override
  String get vgChipSettings => '⚙️ Mga Setting';

  @override
  String get gpTitle => '🎮  Game Controller';

  @override
  String get gpPractise => 'Sanayin ang controller';

  @override
  String get gpPractiseButtons => 'Sanayin ang mga button';

  @override
  String get gpPractiseHelp =>
      'Pumindot ng kahit ano at pakinggan kung ano ang ginagawa nito. Walang gagalaw sa app habang nagsasanay.';

  @override
  String get gpEnable => 'Buksan ang controller';

  @override
  String get gpEnabledOn => 'Magagamit ng naka-pair na controller ang app';

  @override
  String get gpEnabledOff => 'Sarado — pindot lang sa screen';

  @override
  String get gpSpeech => 'Pananalita';

  @override
  String get gpSay => 'Sabihin ang nangyayari';

  @override
  String get gpSayHelp =>
      'Inaanunsyo ang bawat section, item at tanong. Iwanang bukas ito para sa mag-aaral na hindi nakakakita ng screen.';

  @override
  String get gpSpeed => 'Bilis ng pananalita';

  @override
  String get gpSpeedHelp =>
      'Kadalasang gusto ng sanay nang tagapakinig na mas mabilis ito. Itinatakda nito ang bilis ng pagsasalita sa buong app, kaya pareho ang bilis ng pagbasa sa mga kwento at salita.';

  @override
  String get gpReadItem => 'Basahin ang bawat item';

  @override
  String get gpReadItemHelp =>
      'Sinasabi ang pangalan at puwesto — “Mga Laro, 3 sa 8” — pagdating ng cursor dito.';

  @override
  String get gpMoving => 'Paglipat sa mga section';

  @override
  String get gpAsk => 'Magtanong bago lumipat';

  @override
  String get gpAskHelp =>
      'Nagtatanong ang kaliwa at kanan ng “Gusto mo bang pumunta sa section ng Mga Kard?” — A para sa oo, B para sa hindi. Isara para lumipat agad.';

  @override
  String get gpComfort => 'Ginhawa';

  @override
  String get gpVibrate => 'Mag-vibrate sa bawat pindot';

  @override
  String get gpVibrateHelp =>
      'Tahimik na kumpirmasyon na natanggap ang pindot, kahit hindi pa tapos ang naunang pangungusap.';

  @override
  String get gpDedupe => 'Huwag pansinin ang umuulit na pindot sa loob ng';

  @override
  String gpMs(int ms) {
    return '$ms ms';
  }

  @override
  String get gpDedupeHelp =>
      'Taasan ito para sa mag-aaral na napapadobleng pumindot. Babaan kung hindi napapansin ang sinasadyang mabibilis na pindot.';

  @override
  String get gpHold => 'Pindutin nang matagal para tuloy-tuloy';

  @override
  String get gpHoldHelp =>
      'Kapag pinindot nang matagal ang taas o baba, tuloy-tuloy ang paglipat sa mga item sa halip na isang pindot bawat hakbang. Hindi umuulit ang pagbukas, pagbalik at paglipat ng section.';

  @override
  String get gpWait => 'Maghintay bago umulit';

  @override
  String get gpWaitHelp =>
      'Sapat ang haba para hindi magsimula ng pag-ulit ang karaniwang pindot.';

  @override
  String get gpRepeat => 'Umulit tuwing';

  @override
  String get gpRepeatHelp =>
      'Sapat ang bagal para mabasa pa nang buo ang bawat item.';

  @override
  String get gpSwap => 'Pagpalitin ang A at B';

  @override
  String get gpSwapHelp =>
      'Kung baligtad lang ang “oo” at “hindi” — may mga controller na B ang tawag sa ibabang button sa halip na A.';

  @override
  String get gpGuide => 'Gabay sa mga button';

  @override
  String get gpGuideHelp =>
      'Maririnig ng mag-aaral ang listahang ito anumang oras sa pagpindot ng Select.';

  @override
  String get gpVerySlow => 'Napakabagal';

  @override
  String get gpVeryFast => 'Napakabilis';

  @override
  String gpConnectedTo(String name) {
    return 'Nakakonekta ang controller: $name';
  }

  @override
  String get gpNoController => 'Walang nakakonektang controller';

  @override
  String get gpConnected => 'Nakakonekta ang controller';

  @override
  String get gpNone => 'Walang controller';

  @override
  String get gpPair =>
      'Mag-pair ng isa sa Android Settings → Bluetooth, saka bumalik dito.';

  @override
  String get gppTitle => '🎮  Pagsasanay';

  @override
  String get gppNoController =>
      'Walang nakakonektang controller. Buksan ito at magsisimula itong tumugon dito.';

  @override
  String get gppPressAny => 'Pumindot ng kahit anong button sa controller';

  @override
  String get gppPressAnyShort => 'Pumindot ng kahit anong button';

  @override
  String get gppWillTell =>
      'Sasabihin ko kung ano ang ginagawa nito. Wala nang ibang mangyayari.';

  @override
  String gppTried(int tried, int total) {
    return 'Nasubukan ang $tried sa $total';
  }

  @override
  String get gppStartOver => 'Magsimula ulit';

  @override
  String get gppLeave => 'Pindutin ang L1 nang dalawang beses para umalis.';

  @override
  String get hfReasonSign =>
      'Nire-record ng gawaing ito ang iyong pagsenyas, kaya kailangan nito ang camera. Titigil muna ang kontrol gamit ang ulo habang bukas ito.';

  @override
  String get hfVoiceHint =>
      'Maaari mo pa ring sabihin ang “isara” para umalis anumang oras.';

  @override
  String hfUsesCamera(String activity) {
    return 'Gumagamit ng camera ang $activity';
  }

  @override
  String get hfNoVoice =>
      'Para umalis, gamitin ang button na Bumalik sa itaas — o buksan muna ang mga voice command sa Mga Setting → Aksesibilidad → Gaze Control, para masabi mo ang “isara”.';

  @override
  String get hfNotNow => 'Hindi muna';

  @override
  String get hfOpenAnyway => 'Buksan pa rin';

  @override
  String get hfHuntVoice =>
      'Maaari mong sabihin ang “take a photo” para kumuha ng litrato, ang pangalan ng salita para buksan ito, at “isara” para umalis.';

  @override
  String get gzPrevious => '⬅  Nakaraan';

  @override
  String get gzNext => 'Susunod  ➡';

  @override
  String get gzHear => '🔊  Pakinggan ang Salita';

  @override
  String get gzFlip => '🔄  Baligtarin ang Kard';

  @override
  String get gzSelect => '✓  Piliin (kumurap)';

  @override
  String get gzPreview => '👁️  Kontrol gamit ang Tingin (Preview)';

  @override
  String get gzHearWord => 'Pakinggan ang Salita';

  @override
  String get gzFlipCard => 'Baligtarin ang Kard';

  @override
  String get gzLook => '😊  Tumingin sa screen';

  @override
  String get gzNoCamera =>
      'Kailangan ng Gaze Control ng camera sa harap, na wala sa device na ito.';

  @override
  String get gzPermission =>
      'Kailangan ng pahintulot sa camera para masundan ang iyong ulo. Buksan ito sa Settings, saka subukan ulit.';

  @override
  String get gzCameraFailed => 'Hindi nagbukas ang camera. Subukan ulit.';

  @override
  String get gzTryAgain => 'Subukan Ulit';

  @override
  String get gzBlink => '😉  Kumurap para pumili';

  @override
  String get gzStatusNoCamera => 'Gaze: walang camera sa harap';

  @override
  String get gzStatusPermission => 'Gaze: kailangan ng pahintulot sa camera';

  @override
  String get gzUnavailable => 'Hindi magamit ang Gaze';

  @override
  String get gzsTitle => '👁️  Kontrol gamit ang Tingin';

  @override
  String get gzsEnable => 'Buksan ang Gaze Control';

  @override
  String get gzsOn => 'Magagamit ang app gamit ang galaw ng ulo at pagkurap';

  @override
  String get gzsTryNow => 'Subukan ngayon ang gaze control';

  @override
  String get gzsTryIt => 'Subukan ngayon';

  @override
  String get gzsHandsFree => 'Paggalaw nang walang kamay';

  @override
  String get gzsNavOnly => 'Mga tab sa ibaba lang';

  @override
  String get gzsNavOnlySub =>
      'Inililipat ng head D-pad ang highlight sa mga tab sa ibaba. Kumurap (o tumingala) para buksan.';

  @override
  String get gzsNavTiles => 'Mga tab sa ibaba + mga tile';

  @override
  String get gzsNavTilesSub =>
      'Maaabot din ang mga tile sa Home, Mga Kard, Mga Laro, Mga Kwento at Progreso: tumingin ◀ ▶ sa isang hanay, ▲ ▼ sa pagitan ng mga hanay, at kumurap para buksan.';

  @override
  String get gzsVoice => 'Boses';

  @override
  String get gzsVoiceCommands => 'Mga voice command';

  @override
  String get gzsVoiceSub =>
      'Sabihin ang “kaliwa”, “kanan”, “taas”, “baba” para ilipat ang highlight, “piliin” para buksan — o ang pangalan ng button (“susunod”), “isara” para bumalik.';

  @override
  String get gzsTuning => 'Pag-aayos';

  @override
  String get gzsSensitivity => 'Pagkasensitibo';

  @override
  String get gzsSensitivityHelp =>
      'Mas mataas = mas maliit na galaw ng ulo ang pumipili.';

  @override
  String get gzsHold => 'Tagal ng pagtingin';

  @override
  String gzsSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String get gzsHoldHelp => 'Gaano katagal titingin sa button bago ito gumana.';

  @override
  String get gzsBlink => 'Kumurap para kumpirmahin';

  @override
  String get gzsBlinkSub =>
      'Ang mahaba at sinadyang pagkurap ay parang “piliin”';

  @override
  String get gzsScanning => 'Pag-scan (walang galaw ng ulo)';

  @override
  String get gzsScanMode => 'Mode ng pag-scan';

  @override
  String get gzsScanSub =>
      'Isa-isang naiilawan ang mga button — kumurap para pumili. Para sa mga mag-aaral na hindi maigalaw ang ulo.';

  @override
  String get gzsScanSpeed => 'Bilis ng pag-scan';

  @override
  String get gzsScanHelp =>
      'Gaano katagal naiilawan ang bawat button bago lumipat.';

  @override
  String get gzsCalibration => 'Pag-calibrate ng device';

  @override
  String get gzsMirror => 'Baligtarin ang kaliwa / kanan';

  @override
  String get gzsMirrorSub => 'Isara kung parang baligtad ang Kaliwa at Kanan';

  @override
  String get gzsInvert => 'Baligtarin ang taas / baba';

  @override
  String get gzsInvertSub => 'Buksan kung parang baligtad ang Taas at Baba';

  @override
  String get gzsLowest => 'Pinakamababa';

  @override
  String get gzsLow => 'Mababa';

  @override
  String get gzsBalanced => 'Katamtaman';

  @override
  String get gzsHigh => 'Mataas';

  @override
  String get gzsHighest => 'Pinakamataas';

  @override
  String get gzsIntro =>
      'Gamitin ang app nang walang kamay. Igalaw ang ulo patungo sa isang button at hintayin sandali para piliin ito, o kumurap para kumpirmahin. Sa device na ito tumatakbo ang lahat — hindi kailangan ng internet.';

  @override
  String get gzsScopeHint =>
      'Piliin kung hanggang saan aabot ang D-pad na walang kamay. Alinman dito, sarado ito hangga’t hindi bukas ang “Buksan ang Gaze Control”, at laging gumagana ang pindot sa screen.';

  @override
  String get gzsCalibrationHint =>
      'Inaayos nito ang device na parang baligtad ang direksyon. Pindutin ang “Subukan ngayon” sa itaas, at kung maling panig ang napipili ng galaw, palitan ang katugmang switch.';

  @override
  String get lsNoProfile => 'Walang napiling profile';

  @override
  String get lsLiveSession => 'Live na Sesyon';

  @override
  String get lsJoinClass => 'Sumali sa Klase';

  @override
  String get lsHostTitle =>
      'Magpatakbo ng live na laro at quiz mula sa TV Cast';

  @override
  String get lsHostBody =>
      'Buksan ang TV Cast, magsimulang mag-cast, saka piliin ang “Live Activity” para gumawa ng mga tanong, magtakda ng puntos na bituin, at makita sa TV ang nakataas na kamay at ang scoreboard.';

  @override
  String get lsOpenCast => 'Buksan ang TV Cast';

  @override
  String get lsJoinFirst => 'Sumali muna sa klase';

  @override
  String get lsChildJoin =>
      'Hingin sa iyong magulang ang code ng home group, saka sumali mula sa Mga Setting para makasali sa mga live na gawain.';

  @override
  String get lsStudentJoin =>
      'Wala ka pa sa isang klase. Pindutin ang “Sumali sa klase” para makasali sa mga live na gawain.';

  @override
  String get lsConnect => 'Kumonekta sa internet';

  @override
  String get lsConnectBody =>
      'Kailangan ng koneksyon ang mga live na gawain para makasali ka sa klase nang sabay-sabay. Kumonekta sa Wi-Fi o mobile data at buksan ulit ang screen na ito.';

  @override
  String get lsNoActivity =>
      'Wala pang live na gawain. Magsisimula ang iyong guro sa lalong madaling panahon.';

  @override
  String get lsGetReady => 'Maghanda! Hinihintay ang susunod na tanong…';

  @override
  String get lsHandRaised =>
      'Nakataas ang kamay. Nakikita ng iyong guro ang pangalan mo.';

  @override
  String get lsHandLowered => 'Ibinaba ang kamay.';

  @override
  String lsCorrectStars(int count) {
    return 'Tama! Nakakuha ka ng $count bituin.';
  }

  @override
  String get lsCorrect => 'Tama!';

  @override
  String get lsGoodTry =>
      'Magaling ang pagsubok. Hintayin ang susunod na tanong.';

  @override
  String lsFirstCorrect(int count) {
    return 'Unang tamang sagot! Dagdag na $count bituin.';
  }

  @override
  String get lsGotIt => 'Nakuha ko! ✋';

  @override
  String get lsNotYet => 'Hindi pa';

  @override
  String get lsGotItShort => 'Nakuha ko!';

  @override
  String lsQuestionNofM(int number, int total) {
    return 'Tanong $number sa $total';
  }

  @override
  String get lsWatchSign =>
      'Panoorin ang senyas sa TV, saka piliin ang katugmang salita.';

  @override
  String get lsWhichPicture => 'Aling salita ang tugma sa larawan?';

  @override
  String get lsCorrectAnswer => ', tamang sagot';

  @override
  String get lsYourWrong => ', sagot mo, mali';

  @override
  String lsCorrectStarsEmoji(int count) {
    return 'Tama! Nakakuha ka ng $count ⭐';
  }

  @override
  String get lsCorrectEmoji => 'Tama! 🎉';

  @override
  String get lsKeepGoing => 'Magaling ang pagsubok! Tuloy lang 💪';

  @override
  String get lsLowerYourHand => 'Ibaba ang iyong kamay';

  @override
  String get lsRaiseForHelp =>
      'Itaas ang iyong kamay para humingi ng tulong sa guro';

  @override
  String get lsLowerHand => 'Ibaba ang kamay';

  @override
  String get lsRaiseHand => 'Itaas ang kamay';

  @override
  String get mpTaken => 'May iba nang kalaro sa larong ito.';

  @override
  String get mpNeedsInternet => 'Kailangan ng internet para maglaro online.';

  @override
  String get mpWarming =>
      'Naghahanda pa ang pag-sign in. Subukan ulit maya-maya.';

  @override
  String get mpSlow =>
      'Mabagal ang internet. Suriin ang koneksyon at subukan ulit.';

  @override
  String get mpDenied =>
      'Hindi maabot ang serbisyo ng laro. Kung patuloy itong nangyayari, hilingin sa iyong guro na i-deploy ulit ang mga patakaran ng app.';

  @override
  String get mpStartFailed =>
      'Hindi nasimulan ang laro. Subukan ulit maya-maya.';

  @override
  String get mpStart => 'Simulan';

  @override
  String get mpChoose => 'Piliin';

  @override
  String get mpDone => 'Tapos';

  @override
  String get mpNotEnough =>
      'Kulang pa ang mga salita para maglaro — magdagdag muna ng ilang flashcard!';

  @override
  String get mpNoProfile => 'Walang aktibong profile.';

  @override
  String mpPlayWith(String name) {
    return 'Makipaglaro kay $name';
  }

  @override
  String get mqTitle => 'Multiplayer Quiz';

  @override
  String get mqStart => 'Simulan ang Laban!';

  @override
  String mqTurn(String name) {
    return 'Turno ni $name!';
  }

  @override
  String mqRound(int round, int total) {
    return 'Round $round sa $total';
  }

  @override
  String get mqTapStart => 'Pindutin kahit saan para magsimula!';

  @override
  String get mqDraw => 'Tabla!';

  @override
  String get mqNotEnough => 'Kulang ang mga flashcard para maglaro!';

  @override
  String get mqBestStreak => 'Pinakamahabang Streak';

  @override
  String get mpWhichWord => 'Anong salita ito?';

  @override
  String get mqWhatInEnglish => 'Ano ito sa Ingles?';

  @override
  String siRound(int round, int total) {
    return 'Round $round sa $total.';
  }

  @override
  String siSignThis(String english, String filipino) {
    return 'Isenyas ang salitang ito: $english, $filipino.';
  }

  @override
  String get siTitle => 'Isenyas Mo!';

  @override
  String get siSelfAssessed => 'Mga senyas na sariling-tasa';

  @override
  String get siWatchAgain => 'Panoorin ulit ang senyas';

  @override
  String get siGotIt => 'Nakuha ko';

  @override
  String get siGotItBang => 'Nakuha ko!';

  @override
  String siTitleRound(int round, int total) {
    return 'Isenyas Mo!  •  $round/$total';
  }

  @override
  String get siWatchThen => 'Panoorin, saka isenyas pabalik!';

  @override
  String get siYourTake => 'Ang iyong bersyon';

  @override
  String get siYou => 'Ikaw';

  @override
  String get siNoPermission =>
      'Walang pahintulot sa camera.\nMaaari ka pa ring manood at magsanay!';

  @override
  String get siNoCamera =>
      'Walang nakitang camera.\nManood at sanayin lang ang senyas!';

  @override
  String get siCameraOff =>
      'Hindi magamit ang camera.\nManood at sanayin lang ang senyas!';

  @override
  String fvNeedsInternet(String word) {
    return 'Kailangan ng internet para ma-load ang senyas para sa “$word” sa unang pagkakataon. Kumonekta at subukan ulit — pagkatapos noon, gagana na ito kahit offline.';
  }

  @override
  String fvNoVideo(String word) {
    return 'Wala pang video ng FSL para sa “$word”.';
  }

  @override
  String get fvCanYou => 'Kaya mo bang isenyas ito?';

  @override
  String get fvTeacherConfirmed => 'Kinumpirma ng iyong guro ang senyas na ito';

  @override
  String get fvKeepPractising => 'Sabi ng iyong guro, sanayin pa ito';

  @override
  String get fpLoadFailed => 'Hindi ma-load ang video';

  @override
  String get fpClose => 'Isara ang video';

  @override
  String get fpHideCaptions => 'Itago ang caption';

  @override
  String get fpShowCaptions => 'Ipakita ang caption';

  @override
  String get fpSpeedSettings => 'Setting ng bilis ng video';

  @override
  String get fpPause => 'I-pause ang video';

  @override
  String get fpPlay => 'I-play ang video';

  @override
  String fpSetSpeed(String speed) {
    return 'Itakda ang bilis sa ${speed}x';
  }

  @override
  String get fpReplay => 'Ulitin mula sa simula';

  @override
  String get fpPauseShort => 'I-pause';

  @override
  String get fpPlayShort => 'I-play';

  @override
  String get fpProgress => 'Progreso ng video';

  @override
  String get opByCategory => 'Ayon sa kategorya';

  @override
  String get opTitle => 'Mga Senyas na Offline';

  @override
  String get opIntro =>
      'I-save ang mga video ng senyas sa device na ito para tumugtog kahit walang internet.';

  @override
  String opSavedOf(int ready, int total) {
    return '$ready sa $total senyas ang naka-save';
  }

  @override
  String opUsing(String size) {
    return 'Gumagamit ng $size sa device na ito';
  }

  @override
  String get opNothing => 'Wala pang naka-save';

  @override
  String opSaving(String label, int done, int total) {
    return 'Sine-save ang “$label”… $done sa $total';
  }

  @override
  String get opStop => 'Itigil';

  @override
  String get opAllSaved => 'Naka-save na lahat ng senyas';

  @override
  String opSaveAll(int count) {
    return 'I-save lahat ng $count';
  }

  @override
  String opFailed(int count) {
    return '$count ang hindi na-save — suriin ang koneksyon at subukan ulit. Gumagana pa rin online ang mga salitang iyon.';
  }

  @override
  String get opNoSigns => 'Wala pang naka-record na senyas';

  @override
  String opCatSaved(int ready, int total) {
    return '$ready sa $total ang naka-save';
  }

  @override
  String opSaveCat(String category) {
    return 'I-save ang $category para sa offline';
  }

  @override
  String opRemoveCat(String category) {
    return 'Alisin ang mga na-download sa $category';
  }

  @override
  String get feSoon => 'Malapit nang dumating ang mga video ng FSL';

  @override
  String get feRecording =>
      'Nire-record pa namin ang mga video ng senyas para sa mga kategoryang ito. Magsanay muna gamit ang mga flashcard!';

  @override
  String get feReady => 'Handa nang sanayin ngayon:';

  @override
  String get feChooseAnother => 'Pumili ng ibang kategorya';

  @override
  String get siStopRec => 'Itigil ang pag-record';

  @override
  String get siRecordMe => 'I-record ang sarili kong pagsenyas';

  @override
  String siSignThisLabel(String english, String filipino) {
    return 'Isenyas ang salitang ito: $english, $filipino';
  }

  @override
  String get siReference => 'Halimbawa';

  @override
  String get siRecord => 'I-record';

  @override
  String get aqOptions => 'Mga opsyon sa aksesibilidad';

  @override
  String get aqIntro =>
      'Gawing mas madaling makita, marinig, at gamitin ang app.';

  @override
  String get aqTextSize => 'Laki ng Letra';

  @override
  String get aqHcSub => 'Mas matingkad na kulay at gilid';

  @override
  String get aqEasyRead => 'Madaling Basahing Font';

  @override
  String get aqEasyReadSub => 'Mas maluwag na pagitan para sa pagbasa';

  @override
  String get aqReadAloud => 'Basahin nang Malakas';

  @override
  String get aqReadAloudSub => 'Bigkasin ang mga salita at button';

  @override
  String get aqReduceMotion => 'Bawasan ang Galaw';

  @override
  String get aqReduceMotionSub => 'Mas kalmado at simpleng animation';

  @override
  String aqTextSizeLabel(String label) {
    return 'Laki ng letra $label';
  }

  @override
  String get btTitle => 'Magpahinga Muna';

  @override
  String get btBack => 'Bumalik sa aralin';

  @override
  String get btPick =>
      'Piliin ang gusto mo. Maaari kang bumalik sa aralin anumang oras.';

  @override
  String get btCalmer => 'Mas kalmado ka na ba?';

  @override
  String get btStay => 'Manatili pa nang kaunti';

  @override
  String get btHowFeel => 'Kumusta ang pakiramdam mo?';

  @override
  String get btBreathe => 'Huminga';

  @override
  String get btBubbles => 'Pumutok ng Bula';

  @override
  String get btBreatheSub => 'Mabagal at nakakakalmang paghinga';

  @override
  String get btBubblesSub => 'Dahan-dahang putukin ang mga bula';

  @override
  String get sqSeeScore => 'Tingnan ang iskor ko';

  @override
  String get sqNextQuestion => 'Susunod na tanong';

  @override
  String get sqListenEn => 'Pakinggan ang sagot na ito sa Ingles';

  @override
  String get sqListenTl => 'Pakinggan ang sagot na ito sa Tagalog';

  @override
  String get sqSeeResults => 'Tingnan ang Resulta';

  @override
  String get sqNextQuestionCap => 'Susunod na Tanong';

  @override
  String sqNotQuite(String answer) {
    return 'Hindi pa tama. $answer.';
  }

  @override
  String sqQuestionNofM(int number, int total) {
    return 'Tanong $number sa $total';
  }

  @override
  String get srNextPage => 'Susunod na pahina';

  @override
  String get srReadPage => 'Basahin nang malakas ang pahinang ito';

  @override
  String get srGoQuiz => 'Pumunta sa pagsusulit';

  @override
  String srPageNofM(int number, int total) {
    return 'Pahina $number sa $total';
  }

  @override
  String get abCreate => 'Gumawa ng Pagsusulit';

  @override
  String get abDetails => 'Mga Detalye ng Pagsusulit';

  @override
  String get abTitleField => 'Pamagat ng Pagsusulit';

  @override
  String get abTitleRequired => 'Kailangan ang pamagat';

  @override
  String get abDescription => 'Paglalarawan (opsyonal)';

  @override
  String get abDifficulty => 'Hirap';

  @override
  String get abTimeLimit => 'Limitasyon sa Oras';

  @override
  String abMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String abQuestionsCount(int count) {
    return 'Mga Tanong ($count)';
  }

  @override
  String get abNoQuestions => 'Wala Pang Tanong';

  @override
  String get abNoQuestionsBody =>
      'Idagdag ang unang tanong para mabuo ang pagsusulit.';

  @override
  String get abAddFirst => 'Idagdag ang Unang Tanong';

  @override
  String get abAddQuestion => 'Magdagdag ng Tanong';

  @override
  String get abNeedOne => 'Magdagdag ng kahit isang tanong';

  @override
  String get abCustomDesc => 'Sariling pagsusulit ng guro';

  @override
  String abSaved(String title) {
    return 'Na-save ang pagsusulit na “$title”!';
  }

  @override
  String get abDiscardTitle => 'Itapon ang Pagsusulit?';

  @override
  String get abDiscardBody =>
      'May mga tanong kang hindi pa na-save. Sigurado ka bang babalik ka?';

  @override
  String get abKeepEditing => 'Ituloy ang Pag-edit';

  @override
  String get abDiscard => 'Itapon';

  @override
  String abAnswer(String answer) {
    return 'Sagot: $answer';
  }

  @override
  String abChoices(String choices) {
    return 'Mga pagpipilian: $choices';
  }

  @override
  String get abEditQuestion => 'Baguhin ang Tanong';

  @override
  String get abQuestionType => 'Uri ng Tanong';

  @override
  String get abQuestionText => 'Teksto ng Tanong *';

  @override
  String get abCorrectAnswer => 'Tamang Sagot *';

  @override
  String get abChoicesTitle => 'Mga Pagpipilian';

  @override
  String abChoiceN(String letter) {
    return 'Pagpipilian $letter';
  }

  @override
  String get abAddChoice => 'Magdagdag ng Pagpipilian';

  @override
  String get abCategory => 'Kategorya (opsyonal)';

  @override
  String get abHint => 'Pahiwatig (opsyonal)';

  @override
  String get abUpdateQuestion => 'I-update ang Tanong';

  @override
  String get abTextRequired => 'Kailangan ang teksto ng tanong at ang sagot';

  @override
  String get abAnswerInChoices =>
      'Dapat tumugma ang tamang sagot sa isa sa mga pagpipilian';

  @override
  String get qbTitle => 'Gumawa ng Quiz';

  @override
  String get qbMyQuiz => 'Aking Quiz';

  @override
  String get qbQuizTitle => 'Pamagat ng Quiz';

  @override
  String get qbQuestionTypes => 'Mga Uri ng Tanong';

  @override
  String get qbTimeLimit => 'Limitasyon sa Oras (opsyonal)';

  @override
  String get qbNoLimit => 'Walang limitasyon';

  @override
  String qbSelectWords(int count) {
    return 'Pumili ng mga Salita ($count ang napili)';
  }

  @override
  String get qbSelectAll => 'Piliin Lahat';

  @override
  String get qbDeselectAll => 'Alisin ang Pagpili';

  @override
  String get qbAtLeast3 => 'Pumili ng kahit 3 salita para makagawa ng quiz';

  @override
  String get qbSaved => 'Mga Naka-save na Quiz';

  @override
  String qbSummary(int count, String difficulty, String formats) {
    return '$count salita • $difficulty • $formats';
  }

  @override
  String get qbStart => 'Simulan ang Quiz';

  @override
  String qbDuplicate(String title) {
    return 'May quiz ka nang tinatawag na “$title”. Bigyan ng ibang pangalan ang isang ito.';
  }

  @override
  String qbSavedOne(String title) {
    return 'Na-save ang quiz na “$title”!';
  }

  @override
  String get qbNoCards => 'Walang wastong card para sa quiz na ito';

  @override
  String get qbDeleteTitle => 'Burahin ang Quiz?';

  @override
  String qbDeleteBody(String title) {
    return 'Burahin ang “$title”?';
  }

  @override
  String bbMax(int count) {
    return 'Naabot na ang pinakamarami: $count tile';
  }

  @override
  String get bbAlready => 'Naidagdag na ang tile';

  @override
  String bbAdded(String label) {
    return 'Naidagdag ang “$label” sa board';
  }

  @override
  String get bbNeedName => 'Pakibigyan ng pangalan ang board';

  @override
  String get bbCleared =>
      'Nalinis ang board — nakatago na ang tab sa Talk Board';

  @override
  String bbSaved(String name, int count) {
    return 'Na-save ang “$name” na may $count tile';
  }

  @override
  String get bbDiscardTitle => 'Itapon ang mga pagbabago?';

  @override
  String get bbDiscardBody =>
      'May mga pagbabago sa board na ito na hindi pa na-save.';

  @override
  String get bbKeepEditing => 'Ituloy ang pag-edit';

  @override
  String get bbMyBoard => 'Aking Board';

  @override
  String get bbDoneEditing => 'Tapos na ang pag-edit';

  @override
  String get bbReorder => 'Ayusin/alisin ang mga tile';

  @override
  String get bbPreview => 'Silipin nang may boses';

  @override
  String get bbNameField => 'Pangalan ng board (makikita bilang tab)';

  @override
  String get bbTapBelow =>
      'I-tap ang mga tile sa ibaba, o gumawa ng sariling salita';

  @override
  String bbMyWord(String word) {
    return '$word · sarili kong salita';
  }

  @override
  String bbRemove(String label) {
    return 'Alisin ang $label';
  }

  @override
  String bbCount(int count, int max) {
    return '$count / $max tile';
  }

  @override
  String get bbClearAll => 'Burahin Lahat';

  @override
  String get bbMakeWord => 'Gumawa ng sariling salita';

  @override
  String get bbAlreadyAdded => 'naidagdag na';

  @override
  String get bbTapToAdd => 'i-tap para idagdag';

  @override
  String get bbSaveBoard => 'I-save ang Board';

  @override
  String get bbEditWord => 'Baguhin ang salita';

  @override
  String get bbWordEn => 'Salita (Ingles)';

  @override
  String get bbWordEnHint => 'hal. Ate Maria';

  @override
  String get bbWordFil => 'Salita (Filipino) — opsyonal';

  @override
  String get bbWordFilHint =>
      'Iwanang blangko para gamitin ang salitang Ingles';

  @override
  String get bbPicture => 'Larawan';

  @override
  String bbPictureN(int number) {
    return 'Larawan $number';
  }

  @override
  String get cfUpdated => 'Na-update ang flashcard! ✏️';

  @override
  String get cfCreated => 'Nagawa ang flashcard! 🎉';

  @override
  String get cfEditTitle => 'Baguhin ang Flashcard';

  @override
  String get cfCreateTitle => 'Gumawa ng Flashcard';

  @override
  String get cfCategory => 'Kategorya';

  @override
  String get cfWordFil => 'Salita (Filipino)';

  @override
  String get cfHintEn => 'hal. Butterfly';

  @override
  String get cfHintFil => 'hal. Paru-paro';

  @override
  String get cfEnterWord => 'Maglagay ng salita';

  @override
  String get cfEnterTranslation => 'Maglagay ng salin';

  @override
  String get cfExample => 'Halimbawang Pangungusap (opsyonal)';

  @override
  String get cfExampleHint => 'hal. The butterfly is colorful.';

  @override
  String get cfUpdate => 'I-update ang Flashcard';

  @override
  String get cfYourWord => 'Salita sa Ingles';

  @override
  String get cfNoSpeech =>
      'Hindi magagamit ang speech recognition sa device na ito.';

  @override
  String get cfVoiceReady => 'Handa ang Boses';

  @override
  String get cfImage => 'Larawan';

  @override
  String get cfTapImage => 'I-tap para magdagdag ng larawan';

  @override
  String get cfListening => 'Nakikinig…';

  @override
  String get cfDictate => 'Magdikta';

  @override
  String dtAdded(int count, String name) {
    return 'Naidagdag ang $count card mula sa $name';
  }

  @override
  String get dtFailed => 'Hindi maidagdag ang template';

  @override
  String get dtTitle => 'Mga Template ng Deck';

  @override
  String get dtHeading => 'Mga handang deck para sa mabilis na pag-setup';

  @override
  String get dtIntro =>
      'I-tap ang “Gamitin ang deck na ito” para kopyahin ang mga card na ito (Ingles at Filipino) sa sarili mong deck.';

  @override
  String dtCards(int count) {
    return '$count card';
  }

  @override
  String get dtPreview => 'Silipin';

  @override
  String get dtUseDeck => 'Gamitin';

  @override
  String get dtAdding => 'Idinadagdag…';

  @override
  String dtUseThis(int count) {
    return 'Gamitin ang deck na ito ($count card)';
  }

  @override
  String get awWhatTitle => 'Ano ang ibig sabihin ng “PWD”?';

  @override
  String get awWhatBody =>
      'Ang PWD ay nangangahulugang Persons with Disabilities (mga taong may kapansanan) — mga taong may pangmatagalang kondisyong pisikal, pandama, pang-isip, o sa pagkatuto. Ang kapansanan ay likas na bahagi ng pagkakaiba-iba ng tao. Unahin ang tao sa pananalita: sabihing “taong may kapansanan,” sa halip na tawagin siya ayon sa kanyang kapansanan. Bawat mag-aaral ay karapat-dapat sa parehong paggalang at parehong pagkakataong matuto.';

  @override
  String get awKindsTitle => 'Mga karaniwang uri ng kapansanan';

  @override
  String get awRespectTitle => 'Magalang na pakikitungo';

  @override
  String get awRespect1 =>
      'Kausapin nang direkta ang tao, hindi ang kasama o interpreter niya.';

  @override
  String get awRespect2 =>
      'Magtanong muna bago tumulong — huwag agad isiping kailangan niya ito.';

  @override
  String get awRespect3 =>
      'Maging matiyaga at bigyan ng oras ang tao na sumagot.';

  @override
  String get awRespect4 =>
      'Gumamit ng simple at malinaw na pananalita; iwasan ang pagtatatak at pagkaawa.';

  @override
  String get awRespect5 =>
      'Ang wheelchair, tungkod, o gabay ay personal na espasyo — huwag itong hawakan nang walang pahintulot.';

  @override
  String get awCommTitle => 'Madaling-maabot na pakikipag-usap';

  @override
  String get awCommBody =>
      'Maraming Pilipinong Bingi at mahina ang pandinig ang nakikipag-usap gamit ang Filipino Sign Language (FSL) — isang buong wika na may sariling balarila. Ang caption, simpleng teksto, larawan, at video ng senyas ay tumutulong para maabot ng impormasyon ang mas maraming tao. Itinuturo ng app na ito ang mga salita kasabay ng mga video ng FSL para kasama agad ang mga mag-aaral na sumesenyas.';

  @override
  String get awHelpsTitle => 'Paano tumutulong ang FlashLearn PWD';

  @override
  String get awHelps1 =>
      'Mga temang high-contrast at angkop sa dyslexia para mas madaling magbasa.';

  @override
  String get awHelps2 =>
      'Naaayos na laki ng letra, mas kaunting galaw, at text-to-speech.';

  @override
  String get awHelps3 =>
      'Mga video ng Filipino Sign Language sa mga flashcard at kuwento.';

  @override
  String get awHelps4 =>
      'Hands-free na kontrol gamit ang tingin — igalaw ang ulo o kumurap para pumili.';

  @override
  String get wrOverview => 'Buod ng Linggo';

  @override
  String get wrDailyTime => 'Oras ng Pag-aaral Bawat Araw';

  @override
  String get wrCategoryMastery => 'Kahusayan sa Kategorya';

  @override
  String get wrRecentScores => 'Mga Kamakailang Iskor sa Laro';

  @override
  String get wrInsights => 'Mga Obserbasyon at Rekomendasyon';

  @override
  String get wrTrend => 'Paghahambing sa Nakaraang Linggo';

  @override
  String get wrFamilyTitle => 'Ulat ng Progreso ng Pamilya';

  @override
  String wrGeneratedOn(String date) {
    return 'Ginawa noong $date';
  }

  @override
  String get wrWeeklyTitle => 'Lingguhang Ulat ng Progreso';

  @override
  String get wrDayStreak => 'sunod-sunod na araw';

  @override
  String wrFooter(int page, int pages) {
    return 'Ginawa ng FlashLearn PWD - Pahina $page sa $pages';
  }

  @override
  String get wrTotalStars => 'Kabuuang Bituin';

  @override
  String get wrWordsLearned => 'Mga Natutunang Salita';

  @override
  String get wrGamesPlayed => 'Mga Nalarong Laro';

  @override
  String get wrStudyTime => 'Oras ng Pag-aaral';

  @override
  String wrStars(int count) {
    return '$count bituin';
  }

  @override
  String wrWords(int count) {
    return '$count salita';
  }

  @override
  String wrGames(int count) {
    return '$count laro';
  }

  @override
  String wrMinutesThisWeek(int minutes) {
    return '${minutes}m ngayong linggo';
  }

  @override
  String wrAccuracyPct(String percent) {
    return '$percent% katumpakan';
  }

  @override
  String get wrDate => 'Petsa';

  @override
  String get wrMinutes => 'Minuto';

  @override
  String get wrVisual => 'Biswal';

  @override
  String get wrCategory => 'Kategorya';

  @override
  String get wrProgress => 'Progreso';

  @override
  String get wrMasteryBar => 'Bar ng Kahusayan';

  @override
  String get wrNoScores => 'Walang iskor sa laro ngayong linggo.';

  @override
  String get wrGame => 'Laro';

  @override
  String get wrScore => 'Iskor';

  @override
  String get wrStarsCol => 'Bituin';

  @override
  String get wrDuration => 'Tagal';

  @override
  String wrStrongest(String category) {
    return 'Pinakamalakas na bahagi: $category';
  }

  @override
  String get wrStrongestSub =>
      'Ipagpatuloy ang mahusay na gawa sa kategoryang ito!';

  @override
  String wrWeakest(String category) {
    return 'Kailangan pang sanayin: $category';
  }

  @override
  String get wrWeakestSub => 'Pagtuunan ang kategoryang ito para umunlad.';

  @override
  String wrUnexplored(String categories) {
    return 'Hindi pa nasusubukan: $categories';
  }

  @override
  String get wrUnexploredSub =>
      'Subukang ipakilala ang mga kategoryang ito ngayong linggo.';

  @override
  String wrAccuracy(String percent) {
    return 'Katumpakan: $percent%';
  }

  @override
  String get wrAccuracyHigh =>
      'Napakahusay na katumpakan! Isiping taasan ang hirap.';

  @override
  String get wrAccuracyLow =>
      'Makakatulong ang dagdag na pagbabalik-aral para tumaas ang iskor.';

  @override
  String wrLowSessions(int count) {
    return 'Kaunti ang sesyon: $count sesyon ngayong buwan';
  }

  @override
  String get wrLowSessionsSub =>
      'Subukang magkaroon ng 3-4 na sesyon ng pag-aaral bawat linggo.';

  @override
  String wrMastered(int count) {
    return '$count kategoryang kabisado na (>=80%)';
  }

  @override
  String wrMasteredSub(int count) {
    return 'Magaling! $count pa ang natitira.';
  }

  @override
  String get wrStartLearning =>
      'Magsimulang mag-aral para makita ang mga obserbasyon para sa iyo!';

  @override
  String get wrTimeUp =>
      'Tumaas ang oras ng pag-aaral kumpara noong nakaraang linggo!';

  @override
  String get wrTimeDown =>
      'Bumaba ang oras ng pag-aaral kumpara noong nakaraang linggo.';

  @override
  String wrThisLast(int thisWeek, int lastWeek) {
    return 'Ngayong linggo: ${thisWeek}min | Nakaraang linggo: ${lastWeek}min';
  }

  @override
  String get wrsTitle => 'Lingguhang Ulat';

  @override
  String get wrsFamily => 'Ulat ng Pamilya';

  @override
  String get wrsNoStudents => 'Walang nakitang profile ng mag-aaral';

  @override
  String get wrsNoStudentsBody =>
      'Gumawa ng profile ng mag-aaral para makagawa ng ulat.';

  @override
  String get wrsHeading => 'Mga Ulat ng Progreso';

  @override
  String get wrsIntro =>
      'Gumawa ng maayos na ulat na PDF na nagpapakita ng lingguhang datos, kahusayan sa kategorya, iskor sa laro, at mga obserbasyon para sa bawat bata.';

  @override
  String get wrsSelectChild => 'Pumili ng bata para makagawa ng ulat';

  @override
  String wrsSubject(String name) {
    return 'Lingguhang Ulat ng Progreso — $name';
  }

  @override
  String get wrsFailedGenerate => 'Hindi magawa ang ulat. Pakisubukan ulit.';

  @override
  String get wrsFailedPreview => 'Hindi maipakita ang ulat. Pakisubukan ulit.';

  @override
  String wrsPreviewTitle(String name) {
    return 'Silip sa Ulat — $name';
  }

  @override
  String get wrsSharePdf => 'Ibahagi ang PDF';

  @override
  String get wrsNoPreview =>
      'Hindi puwedeng silipin sa screen ng device na ito.';

  @override
  String get wrsNoPreviewBody =>
      'Nagawa na ang ulat — i-tap sa ibaba para buksan, i-save, o ipadala ito bilang PDF.';

  @override
  String wrsStreakDays(int count) {
    return '$count araw';
  }

  @override
  String get prTitle => 'Ulat ng Progreso ng Mag-aaral';

  @override
  String get prWordsLearned => 'Natutunang Salita';

  @override
  String prOfTotal(int total) {
    return 'sa $total';
  }

  @override
  String prStreakDays(int count) {
    return '$count araw';
  }

  @override
  String get prCategoryBreakdown => 'Hati Ayon sa Kategorya';

  @override
  String get prLearningAnalysis => 'Pagsusuri ng Pagkatuto';

  @override
  String get prTotalAttempts => 'Kabuuang Pagsubok';

  @override
  String get prStruggling => 'Mga Salitang Nahihirapan';

  @override
  String get prOverallAccuracy => 'Kabuuang Katumpakan';

  @override
  String get prNotAvailable => 'Wala pa';

  @override
  String get prNeedPractice => 'Mga Salitang Kailangang Sanayin';

  @override
  String get prWordEn => 'Salita (EN)';

  @override
  String get prWordFil => 'Salita (FIL)';

  @override
  String get prAttempts => 'Pagsubok';

  @override
  String get prRecentActivity => 'Mga Kamakailang Laro';

  @override
  String get prPercentage => 'Porsiyento';

  @override
  String get prTagline => 'Interaktibong Pag-aaral ng Bokabularyo';

  @override
  String get prFooter => 'FlashLearn PWD - Thesis Capstone Project';

  @override
  String prPageOf(int page, int pages) {
    return 'Pahina $page sa $pages';
  }

  @override
  String prFocusOn(String category) {
    return 'Pagtuunan ang $category';
  }

  @override
  String prFocusOnBody(int percent) {
    return 'Ito ang kategoryang may pinakamababang progreso, $percent%. Hikayatin ang mag-aaral na gumamit ng flashcard at maglaro sa kategoryang ito.';
  }

  @override
  String get prSmartReview => 'Gamitin ang Smart Review';

  @override
  String prSmartReviewBody(int count) {
    return 'May $count salitang nahihirapan ang mag-aaral. Inuuna ng Smart Review ang mga ito gamit ang spaced repetition.';
  }

  @override
  String get prHabit => 'Bumuo ng Araw-araw na Gawi';

  @override
  String prHabitBody(int count) {
    return 'Ang kasalukuyang sunod-sunod na araw ay $count. Hikayatin ang araw-araw na pagsasanay para maging tuloy-tuloy.';
  }

  @override
  String get prConsistency => 'Mahusay na Pagkakatuloy-tuloy!';

  @override
  String prConsistencyBody(int count) {
    return 'May $count sunod-sunod na araw ang mag-aaral. Makakatulong ang papuri para mapanatili ang gawing ito.';
  }

  @override
  String get prHarder => 'Subukan ang Mas Mahirap na Antas';

  @override
  String prHarderBody(String category, int percent) {
    return 'Nasa $percent% na ang progreso sa $category. Isiping taasan ang hirap ng laro para sa dagdag na hamon.';
  }

  @override
  String get erLast7 => 'Nakaraang 7 araw';

  @override
  String get erLast30 => 'Nakaraang 30 araw';

  @override
  String get erLast90 => 'Nakaraang 90 araw';

  @override
  String get erPickClass => 'Pumili muna ng klase.';

  @override
  String erShareText(String classroom, String range) {
    return 'Ulat ng progreso — $classroom ($range)';
  }

  @override
  String erShareSubject(String classroom) {
    return 'Ulat ng progreso — $classroom';
  }

  @override
  String get erFailed => 'Hindi na-export. Pakisubukan ulit.';

  @override
  String get erTitleShort => 'I-export ang Ulat';

  @override
  String get erSignIn => 'Mag-sign in bilang guro para mag-export ng ulat.';

  @override
  String get erTitle => 'I-export ang Ulat ng Progreso';

  @override
  String get erLoadFailed => 'Hindi ma-load ang mga klase. Pakisubukan ulit.';

  @override
  String get erNoClasses =>
      'Wala ka pang klase. Gumawa muna ng klase para makapag-export ng ulat ng progreso.';

  @override
  String get erHeading => 'Ulat ng Progreso (CSV)';

  @override
  String get erIntro =>
      'Gumawa ng spreadsheet ng progreso ng bawat mag-aaral sa napiling panahon. Gamitin ito para sa IEP, ulat sa magulang, o talaan ng klase.';

  @override
  String get erClassroom => 'Klase';

  @override
  String get erDateRange => 'Saklaw ng Petsa';

  @override
  String get erBuilding => 'Ginagawa ang CSV…';

  @override
  String get erExport => 'I-export at ibahagi ang CSV';

  @override
  String get erShareNote =>
      'Bubuksan ng file ang share sheet ng device para ma-email mo, ma-save sa Drive, o ma-upload sa portal ng paaralan.';

  @override
  String get cePdfTitle => 'SERTIPIKO NG PAGKILALA';

  @override
  String get cePdfPresented =>
      'Buong pagmamalaking iginagawad ang sertipikong ito kay';

  @override
  String cePdfFor(String achievement) {
    return 'Para sa $achievement';
  }

  @override
  String cePdfDate(String date) {
    return 'Petsa: $date';
  }

  @override
  String get ceTypeAssessment => 'Pagkumpleto ng Pagsusulit';

  @override
  String get ceTypeStreak => 'Tagumpay sa Sunod-sunod na Pag-aaral';

  @override
  String get ceTypeOverall => 'Pangkalahatang Progreso';

  @override
  String ceCatTitle(String category) {
    return 'Kahusayan sa Kategoryang $category';
  }

  @override
  String ceCatDetail(int learned, int total, String category) {
    return 'Matagumpay na natutunan ang $learned sa $total salita sa kategoryang $category.';
  }

  @override
  String ceStreakTitle(int days) {
    return '$days Araw na Sunod-sunod na Pag-aaral';
  }

  @override
  String ceStreakDetail(int days) {
    return 'Nagpakita ng natatanging sipag sa pag-aaral nang $days araw na sunod-sunod.';
  }

  @override
  String ceOverallDetail(int words, int stars, int days) {
    return 'Natuto ng $words salita, nakakuha ng $stars bituin, at nag-aral nang $days araw na sunod-sunod.';
  }

  @override
  String get wsTracing => 'Pagbakas ng Salita';

  @override
  String get wsMatching => 'Pagtutugma ng Larawan';

  @override
  String get wsMatchingHeader => 'Pagtutugma ng Larawan/Salita';

  @override
  String get wsFill => 'Punan ang Patlang';

  @override
  String get wsSearch => 'Paghahanap ng Salita';

  @override
  String get wsTracingDesc =>
      'Bakasin ang mga salitang Ingles at Filipino na may tuldok-tuldok na letra';

  @override
  String get wsMatchingDesc =>
      'Gumuhit ng linya para itugma ang mga salita sa kanilang salin';

  @override
  String get wsFillDesc =>
      'Kumpletuhin ang mga pangungusap gamit ang tamang salita';

  @override
  String get wsSearchDesc =>
      'Hanapin ang mga nakatagong salita sa kahon ng mga letra';

  @override
  String get wsTraceInstr =>
      'Bakasin nang maingat ang bawat salita. Sanayin ang pagsulat sa Ingles at Filipino!';

  @override
  String get wsEnglishColon => 'Ingles: ';

  @override
  String get wsFilipinoColon => 'Filipino: ';

  @override
  String get wsMatchInstr =>
      'Gumuhit ng linya mula sa bawat salitang Ingles sa kaliwa papunta sa salin nito sa Filipino sa kanan.';

  @override
  String get wsEnglish => 'Ingles';

  @override
  String get wsFilipino => 'Filipino';

  @override
  String get wsAnswers =>
      'Mga Sagot: ___________________________________________';

  @override
  String get wsFillInstr =>
      'Punan ang bawat patlang ng tamang salita mula sa listahan ng salita sa ibaba.';

  @override
  String get wsWordBank => 'Listahan ng Salita:';

  @override
  String get wsSearchInstr =>
      'Hanapin at bilugan ang lahat ng nakatagong salita sa kahon sa ibaba!';

  @override
  String wsMeta(String category, String difficulty) {
    return 'Kategorya: $category  •  Hirap: $difficulty';
  }

  @override
  String get wsName => 'Pangalan: ____________________';

  @override
  String get wsDate => 'Petsa: ____________________';

  @override
  String wsFooter(int page, int pages) {
    return 'Pahina $page sa $pages  •  Ginawa ng FlashLearn PWD';
  }

  @override
  String get wscTitle => 'Mga Worksheet na Maipi-print';

  @override
  String get wscIntro =>
      'Gumawa ng mga worksheet na maipi-print at magagamit ng mga mag-aaral kahit offline!';

  @override
  String get wscType => 'Uri ng Worksheet';

  @override
  String get wscGenerating => 'Ginagawa...';

  @override
  String get wscPreviewPrint => 'Silipin at I-print';

  @override
  String wscWords(int count) {
    return '$count salita';
  }

  @override
  String pfTitle(String name) {
    return 'Portfolio ng Pagkatuto ni $name';
  }

  @override
  String get pfOverview => 'Buod';

  @override
  String get pfDayStreak => 'Sunod-sunod na Araw';

  @override
  String get pfItems => 'Mga Laman ng Portfolio';

  @override
  String get pfPinned => 'Mga Naka-pin na Tampok';

  @override
  String get pfAllItems => 'Lahat ng Laman ng Portfolio';

  @override
  String get pfType => 'Uri';

  @override
  String get pfItemTitle => 'Pamagat';

  @override
  String get pfDescription => 'Paglalarawan';

  @override
  String get pfSummaryByType => 'Buod Ayon sa Uri';

  @override
  String get sdDetails => 'Mga Detalye';

  @override
  String get sdEarned => 'Nakuha';

  @override
  String get sdYes => 'Oo';

  @override
  String get sdNo => 'Hindi';

  @override
  String get sdPersonalNote => 'Sariling Tala';

  @override
  String get bpSemantics =>
      'Putukin ang mga bula. Para sa kasiyahan lang ito — walang iskor.';

  @override
  String get crbReconnected => 'Nakakonekta na ulit ang cloud sync.';

  @override
  String get lwDismiss => 'Isara';

  @override
  String egSemantics(String word) {
    return 'Tingnan ang mga halimbawang larawan ng $word';
  }

  @override
  String smSemantics(String word) {
    return 'Ipakita ang $word';
  }

  @override
  String get siReRecord => 'I-record ulit';

  @override
  String mqPlayerN(int number) {
    return 'Manlalaro $number';
  }

  @override
  String get mqRematch => 'Maglaro Ulit!';

  @override
  String get mpRematch => 'Maglaro ulit';

  @override
  String gzTarget(String label) {
    return 'Target ng tingin: $label';
  }

  @override
  String get frRequests => 'Mga hiling na makipagkaibigan';

  @override
  String get alMarkRead => 'Markahang nabasa na';

  @override
  String get exSaved => 'Na-save ang mga setting ng eksperimento!';

  @override
  String exGroup(String label) {
    return 'Grupong $label';
  }

  @override
  String alDeleteTitle(String label) {
    return 'Burahin ang “$label”?';
  }

  @override
  String get alLabel => 'Pangalan';

  @override
  String get alEnabled => 'Naka-on';

  @override
  String get alUnnamed => 'Alarma';

  @override
  String get tlEnforce => 'Ipatupad ang limitasyon bawat araw';

  @override
  String get tlSaved => 'Na-save.';

  @override
  String get pcSaveFailed =>
      'Hindi ma-save ang mga kontrol ng magulang. Pakisubukan ulit.';

  @override
  String get tuVerify => 'I-verify';

  @override
  String get tuSwitchAccount => 'Magpalit ng account';

  @override
  String woAvgPer(String noun) {
    return 'Avg/$noun';
  }

  @override
  String get aaSelectProfile =>
      'Pumili ng profile para makita ang adaptive analytics.';

  @override
  String get daSelectProfile =>
      'Pumili ng profile para makita ang detalyadong analytics.';

  @override
  String get lcTitle => 'Mga Setting ng Leaderboard';

  @override
  String get lcVisibility => 'Pagpapakita';

  @override
  String get lcShow => 'Ipakita ang leaderboard sa mga miyembro';

  @override
  String get lcRankBy => 'I-ranggo ayon sa';

  @override
  String get lcPeriod => 'Panahon';

  @override
  String get lcNewSeason => 'Magsimula ng bagong season';

  @override
  String get lcClearSeason => 'Burahin ang season';

  @override
  String get lcHide => 'Itago ang mga miyembro';

  @override
  String get lcNoMembers => 'Wala pang sumasaling miyembro.';

  @override
  String get ptAccuracyTrend => 'Takbo ng Katumpakan 📊';

  @override
  String get ptpTitle => 'Ayusin ang Progreso';

  @override
  String get ptpIntro => 'Pumili ng itsura at ayos para sa pahina ng Progreso';

  @override
  String get ptpTheme => 'Tema';

  @override
  String get ptpLayout => 'Ayos';

  @override
  String sqQuizTitle(String title) {
    return 'Pagsusulit: $title';
  }

  @override
  String get sqEnglish => 'Ingles';

  @override
  String get sqTagalog => 'Tagalog';

  @override
  String get srPrevPage => 'Nakaraang pahina';

  @override
  String get scmpKeyMetrics => 'Mahahalagang Sukatan';

  @override
  String get taAvgAccuracy => 'Avg na Katumpakan';

  @override
  String get nfIllustration => 'Larawan ng nawawalang pahina';

  @override
  String get nfTitle => 'Naku! Hindi makita ang pahina';

  @override
  String get nfBody =>
      'Mukhang naligaw ang pahinang ito.\nBumalik tayo sa tamang daan!';

  @override
  String get nfGoHomeSem => 'Bumalik sa home screen';

  @override
  String get nfGoHome => 'Pumunta sa Home';

  @override
  String get nfGoBackSem => 'Bumalik sa nakaraang pahina';

  @override
  String get ciOnline => 'Online';

  @override
  String get ciOffline => 'Walang internet — naka-save sa device ang gawa mo';

  @override
  String get spdCreated => 'Nagawa';

  @override
  String get ssSyncing => 'Sini-sync…';

  @override
  String get ssSynced => 'Na-sync na!';

  @override
  String get splashLogo => 'Logo ng FlashLearn';

  @override
  String get ctDark => 'Madilim';

  @override
  String get ctLight => 'Maliwanag';

  @override
  String get ctClassroom => 'Silid-aralan';

  @override
  String get ctPlayful => 'Masaya';

  @override
  String get ctCalm => 'Kalmado / Pokus';

  @override
  String get ctSeasonal => 'Pampanahon';

  @override
  String get ctHighContrast => 'High contrast';

  @override
  String get ctDyslexia => 'Angkop sa dyslexia';

  @override
  String get ctDarkDesc => 'Madilim at malinaw basahin — ang klasikong itsura.';

  @override
  String get ctLightDesc => 'Maliwanag at malinis para sa maliwanag na silid.';

  @override
  String get ctClassroomDesc => 'Malinaw at payak — pinakamadaling basahin.';

  @override
  String get ctPlayfulDesc =>
      'Makulay at bilugan, may malalaking emoji para sa mga bata.';

  @override
  String get ctCalmDesc =>
      'Malambot, kaunting pampasigla, mahinahong takbo (walang animation).';

  @override
  String get ctSeasonalDesc => 'Masasayang palamuti ayon sa panahon.';

  @override
  String get ctHighContrastDesc => 'Itim/puti/dilaw para sa malabong paningin.';

  @override
  String get ctDyslexiaDesc =>
      'Lexend sa kulay-krema, may mas maluwag na pagitan.';

  @override
  String get ctSizeNormal => 'Karaniwan';

  @override
  String get ctSizeLarge => 'Malaki';

  @override
  String get ctSizeXl => 'Napakalaki';

  @override
  String get ctLangBoth => 'Pareho';

  @override
  String get ctLeaderboard => 'Leaderboard';

  @override
  String get ctClassWins => 'Tagumpay ng klase';

  @override
  String get ctLeaderboardDesc => 'Nangungunang 10 ayon sa bituin, may ranggo.';

  @override
  String get ctClassWinsDesc =>
      'Ang nagawa ng buong klase, saka lahat mula A–Z — walang ranggo.';

  @override
  String get tcWifiLost =>
      'Nadiskonekta ang Wi-Fi — hindi maabot ng TV ang cast na ito. Kumonekta ulit sa parehong Wi-Fi para magpatuloy.';

  @override
  String get tcNetChanged =>
      'Iba na ang network mo — hindi maabot ng TV ang cast na ito. Kumonekta ulit sa dating Wi-Fi, o i-tap ang I-restart para sa bagong code.';

  @override
  String get tcRestart => 'I-restart';

  @override
  String get tcNoWifi =>
      'Walang nakitang Wi-Fi. Kumonekta sa parehong network ng TV mo.';

  @override
  String get tcStopTitle => 'Itigil ang pag-cast?';

  @override
  String get tcStopBody =>
      'Tatapusin nito ang kasalukuyang cast at ididiskonekta ang mga TV. Maaari kang magsimula ulit anumang oras.';

  @override
  String get tcStopped => 'Itinigil ang pag-cast';

  @override
  String get tcTitle => 'TV Cast';

  @override
  String get tcTeacherBack => 'Bumalik na ang guro (ituloy ang cast)';

  @override
  String get tcTeacherOut => 'Ipakita ang “Wala ang guro” sa TV';

  @override
  String get tcStopCasting => 'Itigil ang pag-cast';

  @override
  String get tcWhatToCast => 'Ano ang ika-cast';

  @override
  String get tcSwitchesNow => 'Agad nagpapalit ang TV pagka-tap mo.';

  @override
  String get tcNowShowing => 'Ipinapakita ngayon sa TV';

  @override
  String get tcPacing => 'Bilis';

  @override
  String get tcPlayback => 'Pag-play';

  @override
  String get tcStepLesson => 'Dito isulong ang aralin.';

  @override
  String get tcReplayAudio => 'Ulitin ang audio';

  @override
  String get tcDisplayStyle => 'Itsura sa TV';

  @override
  String get tcDisplayStyleSub =>
      'Kung paano makikita ang aralin sa malaking screen.';

  @override
  String get tcLessonTimer => 'Timer ng aralin';

  @override
  String get tcReadability => 'Pagkabasa sa TV';

  @override
  String get tcShowOnTv => 'Ipakita sa TV';

  @override
  String get tcShowOnTvSub => 'Opsyonal na pangalang makikita sa sulok ng TV.';

  @override
  String get tcAudio => 'Audio';

  @override
  String get tcFullscreen => 'Buong screen';

  @override
  String get tcTvRemote => 'Remote ng TV';

  @override
  String get tcAnyTv => 'Mag-cast sa kahit anong TV';

  @override
  String get tcAnyTvBody =>
      'Gumagana sa kahit anong TV na may web browser — Samsung, LG, Sony, Fire TV, Chromecast with Google TV, smart projector, o laptop na nakasaksak sa HDMI. Bubuksan mo ang link sa sariling browser ng TV — hindi ito katulad ng pag-mirror o pag-cast ng tablet, kaya sa TV manggagaling ang tunog.';

  @override
  String get tcStarting => 'Nagsisimula…';

  @override
  String get tcStart => 'Simulan ang Pag-cast';

  @override
  String get tcWaitingTv => 'Hinihintay kumonekta ang TV…';

  @override
  String get tcTeacherOutNote =>
      'Ipinapakita ng TV ang “Wala ang guro”. I-tap ang icon na naglalakad para ituloy ang pag-cast.';

  @override
  String get tcFlashcards => 'Mga Flashcard';

  @override
  String get tcFlashcardsSub => 'Salita, larawan at litrato';

  @override
  String get tcFsl => 'FSL';

  @override
  String get tcFslSub => 'Mga video ng senyas';

  @override
  String get tcStories => 'Mga Kuwento';

  @override
  String get tcStoriesSub => 'Basahin kada pahina';

  @override
  String get tcLiveActivity => 'Live na Gawain';

  @override
  String get tcLiveActivitySub => 'Pagsusulit para sa buong klase';

  @override
  String get tcProgress => 'Progreso';

  @override
  String get tcProgressSub => 'Tagumpay at bituin ng klase';

  @override
  String get tcStory => 'Kuwento';

  @override
  String get tcPickAbove =>
      'Pumili sa itaas ng ika-cast. Agad magpapalit ang TV.';

  @override
  String get tcTextSize => 'Laki ng letra sa TV';

  @override
  String get tcTextSizeNote =>
      'Pinalalaki ang salita, linya ng kuwento, caption ng senyas at mga pagpipilian — para sa mga nasa likod o may malabong paningin.';

  @override
  String get tcLanguage => 'Wika sa TV';

  @override
  String get tcBothLangs =>
      'Ipinapakita at binibigkas ng TV ang dalawang wika.';

  @override
  String get tcReadyOffline => 'Handa nang mag-cast kahit offline';

  @override
  String get tcPrepare => 'Ihanda para sa pag-cast';

  @override
  String get tcStopDownloading => 'Itigil ang pag-download';

  @override
  String get tcCheckAgain => 'Suriin ulit';

  @override
  String get tcFsOnNote =>
      'Pupunuin ng TV ang buong screen at kusang aangkop sa kahit anong TV — Smart TV, Chromecast / Google TV, Fire TV, projector o HDMI laptop. Sa ilang TV, pindutin nang isang beses ang OK sa remote para mapuno ang screen.';

  @override
  String get tcFsOffNote =>
      'Makikita pa ang mga bar ng browser sa TV. I-on para mapuno ang buong screen.';

  @override
  String get tcFsOnTv => 'Buong screen sa TV';

  @override
  String get tcBigPicNa =>
      'Gumagana sa Mga Flashcard, Video ng FSL at Mga Kuwento. Pumili ng isa sa mga iyon para magamit ito — kailangan ng live na gawain na makita ang mga pagpipilian.';

  @override
  String get tcBigPicOn =>
      'Pupunuin ng larawan, GIF o video ng senyas ang TV. Buo pa ring makikita ang larawan (hindi napuputol) at nasa ilalim ang salita; nakatago ang badge ng kategorya at halimbawang pangungusap para magkasya.';

  @override
  String get tcBigPicOff =>
      'Nasa loob ng card ang larawan. I-on para punuin nito ang TV — mas madaling makita mula sa likod ng silid, o para sa mag-aaral na may malabong paningin.';

  @override
  String get tcBigPic => 'Buong screen na larawan at video';

  @override
  String get tcRecent => 'Mga kamakailang cast';

  @override
  String get tcClear => 'Burahin';

  @override
  String get tcClearTitle => 'Burahin ang kasaysayan ng cast?';

  @override
  String get tcClearBody =>
      'Aalisin nito ang talaan ng mga nakaraang cast sa device na ito. Hindi nito gagalawin ang datos ng mga mag-aaral.';

  @override
  String get tcEarlier => 'Mas maaga';

  @override
  String get tcLive => 'Live';

  @override
  String get tcUnderMinute => '<1 min';

  @override
  String get tcFslSigns => 'Mga senyas ng FSL';

  @override
  String get tcLessonCast => 'Na-cast na aralin';

  @override
  String get tcTimerNote =>
      'Magpakita ng countdown sa sulok ng TV — para sa paglipat ng gawain, tahimik na pagbasa, o “limang minuto pa”. Tuloy pa rin ang aralin sa ilalim nito.';

  @override
  String get tcResumeTimer => 'Ituloy ang timer';

  @override
  String get tcPauseTimer => 'I-pause ang timer';

  @override
  String get tcClearTimer => 'Burahin ang timer';

  @override
  String get tcTimesUpNote =>
      'Ipinapakita ng TV ang “Tapos na ang oras!”. Burahin ito, o magsimula ng bago.';

  @override
  String get tcTimerShowing => 'Nakikita sa TV, sa ibabaw ng aralin.';

  @override
  String get tcRemoteLabel => 'Kontrolin gamit ang remote ng TV';

  @override
  String get tcRemoteOn =>
      'Pindutin ang ◀ o ▶ sa remote ng TV para lumipat sa mga card, senyas o pahina ng kuwento, at play/pause para huminto. Magagamit kapag nasa pisara ka at nasa mesa ang tablet. (Ang OK ay pambukas pa rin ng tunog ng TV.)';

  @override
  String get tcRemoteOff =>
      'Hindi mababago ng remote ng TV ang aralin. I-on kung gusto mong isulong mula sa pisara — o iwanang naka-off kung walang magbabantay sa screen.';

  @override
  String get tcTrouble => 'May problema?';

  @override
  String get tcTipSameWifi =>
      'Dapat nasa IISANG Wi-Fi network ang phone at TV.';

  @override
  String get tcTipApIsolation =>
      'Kung nasa Wi-Fi ka ng paaralan o pang-bisita, maaaring harangin ng “AP isolation” ang koneksyon ng phone sa TV. Subukan ang karaniwang network sa bahay.';

  @override
  String get tcTipSamsung =>
      'Samsung TV: buksan ang app na “Internet”, i-type ang URL.';

  @override
  String get tcTipLg =>
      'LG TV: buksan ang “Web Browser” mula sa home dashboard.';

  @override
  String get tcTipFire =>
      'Fire TV: i-install ang Silk Browser (libre), saka buksan ang URL.';

  @override
  String get tcTipChromecast =>
      'Chromecast with Google TV: buksan ang Chrome mula sa listahan ng app, i-type ang URL.';

  @override
  String get tcTipApple =>
      'Apple TV: i-AirPlay-mirror ang browser ng laptop na nagpapakita ng URL.';

  @override
  String get tcTipFullscreen =>
      'Hindi napupuno ang TV? Tiyaking naka-on ang “Buong screen sa TV” sa itaas. Sa ilang TV (hal. Chromecast / Google TV) pindutin nang isang beses ang OK sa remote para mapuno ang screen.';

  @override
  String get tcTipLeave =>
      'Maaari mong iwan ang screen na ito — tuloy ang cast. May bar na “Nagka-cast sa TV” sa ibaba ng app para makapag-pause o makalaktaw ka kahit saan, at ibabalik ka rito kapag na-tap.';

  @override
  String get tcTipPrivate =>
      'Ang mga TV lang na nagbukas ng eksaktong link ng cast mo (nagtatapos ito sa code ng cast) ang makakakita ng aralin. Bagong code ang gagawin ng bagong cast at hindi na gagana ang lumang link.';

  @override
  String get tcTipQuiet =>
      'Masyadong mahina? Pinakamalakas na ang boses ng app — lakasan ang volume ng TV (o ng phone, kung sa phone lumalabas ang tunog).';

  @override
  String get tcNameHint => 'hal. Gng. Cruz — Grade 2 (opsyonal)';

  @override
  String get tcAutoAdvance => 'Kusang pagsulong';

  @override
  String get tcTapOnlyOn =>
      'Emoji ang ipinapakita ng TV; gamitin ang button na Baligtarin para ipakita ang tunay na litrato (at ibalik). Gumagana sa kahit anong TV.';

  @override
  String get tcTapOnlyOff =>
      'Emoji lang ang ipinapakita ng TV — nakatago ang litrato.';

  @override
  String get tcTapOnly => 'Tap Lang';

  @override
  String get tcShowEmoji => 'Ipakita ang emoji';

  @override
  String get tcFlipPhoto => 'Baligtarin sa litrato';

  @override
  String get tcPhotoShowing =>
      'Ipinapakita ng TV ang tunay na litrato. I-tap para ibalik sa emoji.';

  @override
  String get tcHideClip => 'Itago ang clip';

  @override
  String get tcShowMe => 'Ipakita';

  @override
  String get tcClipPlaying =>
      'Tumutugtog ang clip sa TV. I-tap para bumalik sa card.';

  @override
  String get tcFlipAnim => 'I-tap para Baligtarin (Cartoon ↔ Larawan)';

  @override
  String get tcPictureShowing =>
      'Ipinapakita ng TV ang tunay na larawan. I-tap para ibalik sa cartoon.';

  @override
  String get tcCartoonShowing =>
      'Ipinapakita ng TV ang cartoon. I-tap para lumipat sa tunay na larawan sa TV.';

  @override
  String get tcHideFsl => 'Itago ang FSL';

  @override
  String get tcWatchFsl => 'Panoorin sa FSL';

  @override
  String get tcFslPlaying =>
      'Tumutugtog ang video ng senyas sa TV. I-tap para bumalik sa kuwento.';

  @override
  String get tcReadyToPlay => 'Handa nang i-play';

  @override
  String get tcPreparingVideo => 'Inihahanda ang video…';

  @override
  String get tcTvSpeaks =>
      'Binibigkas ng TV ang bawat salita at pahina ng kuwento (Ingles + Filipino).';

  @override
  String get tcPhoneReads =>
      'Binabasa nang malakas ng phone na ito ang bawat salita / pahina ng kuwento.';

  @override
  String get tcTurnOnTts =>
      'I-on ang Text-to-Speech sa Settings para marinig ito.';

  @override
  String get tcSpeakWords => 'Bigkasin ang salita at magsalaysay';

  @override
  String get tcPlaySoundOn => 'Patunugin sa';

  @override
  String get tcThisPhone => 'Phone na ito';

  @override
  String get tcPhoneSound =>
      'Tutunog mula sa phone na ito (o speaker na nakakonekta sa phone).';

  @override
  String get tcTvVolume =>
      'Pinakamalakas ang tunog ng mga salita sa TV — lakasan ang volume ng TV para marinig nang malinaw ng bawat mag-aaral, pati ang mga kailangang mas malakas.';

  @override
  String get tcPhoneVolume =>
      'Pinakamalakas ang tunog ng mga salita — gamitin ang volume button ng phone na ito para lakasan pa.';

  @override
  String get tcVideoSound => 'Patunugin ang video sa TV';

  @override
  String get tcVideoSoundNote =>
      'Naka-off sa simula para tahimik ang mga senyas (angkop sa Bingi). I-on para sa mga senyas na may boses. Maaaring hindi gumana sa lumang TV.';

  @override
  String get tcWaitingATv => 'Hinihintay kumonekta ang isang TV…';

  @override
  String get tcTvPlaying => 'Tumutunog ang TV.';

  @override
  String get tcPressOk =>
      'Pindutin nang isang beses ang OK sa remote ng TV para bumukas ang tunog nito.';

  @override
  String get tcTvCantSpeak =>
      'Hindi kayang bigkasin ng TV na ito ang mga salita. I-tap ang “Phone na ito” para dito marinig ang salaysay.';

  @override
  String get tcTvGettingReady =>
      'Inihahanda ang TV… kung tahimik pa rin, pindutin nang isang beses ang OK sa remote ng TV.';

  @override
  String get tcLoadingSigns => 'Nilo-load ang mga senyas…';

  @override
  String get tcNoFsl => 'Wala pang video ng FSL sa kategoryang ito.';

  @override
  String get tcTapSign => 'I-tap ang senyas para ipakita ngayon';

  @override
  String get tcPickCategory => 'Pumili ng kategorya para magsimula.';

  @override
  String get tcNoWords => 'Walang salita sa kategoryang ito.';

  @override
  String get tcPickStory => 'Pumili ng kuwento.';

  @override
  String get tcFinished =>
      'Tapos na — ipinapakita ng TV ang “Wakas”. Babasahin ulit ng Bumalik ang huling pahina.';

  @override
  String get tcNoLeaderboard => 'Leaderboard — wala pang datos ng mag-aaral.';

  @override
  String get tcLiveWaiting => 'Live na gawain — naghihintay ng tanong.';

  @override
  String get tcNothingCast => 'Walang kinaka-cast.';

  @override
  String get tcTimesUp => 'Tapos na ang oras';

  @override
  String get tcStartFailed => 'Hindi masimulan ang cast. Pakisubukan ulit.';

  @override
  String get tcReplayPage =>
      'Pakinggan ulit ang kasalukuyang pahina sa phone na ito.';

  @override
  String get tcReplayWord =>
      'Pakinggan ulit ang kasalukuyang salita sa phone na ito.';

  @override
  String tcViewers(int count) {
    return '$count na nanonood ang nakakonekta';
  }

  @override
  String tcOneLang(String language) {
    return '$language lang ang ipinapakita at binibigkas ng TV — nakatago lang ang isa pang wika, hindi inalis, kaya maibabalik mo ito sa gitna ng aralin.';
  }

  @override
  String tcDownloading(int done, int total) {
    return 'Dina-download ang $done sa $total';
  }

  @override
  String tcDownloadAll(String target) {
    return 'I-download na ang bawat senyas, clip at larawan sa $target, para hindi maghintay ang TV sa gitna ng aralin — at tuloy ang cast kahit mawala ang Wi-Fi.';
  }

  @override
  String tcPrepareTarget(String target) {
    return 'Ihanda ang $target';
  }

  @override
  String tcNothingToDownload(String target) {
    return 'Walang ida-download para sa $target — mula sa app ito ika-cast.';
  }

  @override
  String tcSomeFailed(int ready, int total, int failed) {
    return '$ready sa $total ang handa. $failed ang hindi na-download — ilo-load ang mga iyon sa aralin kung may network.';
  }

  @override
  String tcAllReady(int total, String target) {
    return 'Nasa device na ito ang lahat ng $total. Agad ika-cast ang $target, kahit walang internet.';
  }

  @override
  String tcUpdatesItself(String description) {
    return '$description Kusang nag-a-update habang gumagawa ang klase.';
  }

  @override
  String tcOlderCasts(int count) {
    return '$count lumang cast ang itinatago (90 araw).';
  }

  @override
  String tcToday(String time) {
    return 'Ngayon, $time';
  }

  @override
  String tcYesterday(String time) {
    return 'Kahapon, $time';
  }

  @override
  String tcCards(int count) {
    return '$count card';
  }

  @override
  String tcPages(int count) {
    return '$count pahina';
  }

  @override
  String tcQsAnswers(int questions, int answers) {
    return '$questions tanong · $answers sagot';
  }

  @override
  String tcSeconds(int count) {
    return '$count seg';
  }

  @override
  String tcHoursMinutes(int hours, int minutes) {
    return '$hours oras $minutes min';
  }

  @override
  String tcOfCasting(String duration) {
    return '$duration ng pag-cast';
  }

  @override
  String tcCardsSigns(int count) {
    return '$count card / senyas ang naipakita';
  }

  @override
  String tcStoryPages(int count) {
    return '$count pahina ng kuwento';
  }

  @override
  String tcLiveQs(int questions, int answers) {
    return '$questions live na tanong · $answers sagot';
  }

  @override
  String tcTvsAtOnce(int count) {
    return '$count TV nang sabay';
  }

  @override
  String tcAdvanceOn(String noun) {
    return 'Kusang lilipat sa susunod na $noun kada ilang segundo.';
  }

  @override
  String tcAdvanceOff(String noun) {
    return 'Mananatili sa bawat $noun hanggang i-tap mo ang Susunod.';
  }

  @override
  String get tcNounPage => 'pahina';

  @override
  String get tcNounSign => 'senyas';

  @override
  String get tcNounCard => 'card';

  @override
  String tcFlipWord(String word) {
    return 'Baligtarin ang “$word” sa TV para makita ang tunay na litrato.';
  }

  @override
  String tcPlayClip(String word) {
    return 'I-play sa TV ang maikling clip ng “$word” na gumagalaw.';
  }

  @override
  String tcPlayPageFsl(int number) {
    return 'I-play ang pahina $number sa Filipino Sign Language sa TV.';
  }

  @override
  String tcPageOf(int number, int total) {
    return 'Pahina $number / $total';
  }

  @override
  String tcLeaderboardTop(int count) {
    return 'Leaderboard — nangungunang $count mag-aaral.';
  }

  @override
  String tcLiveAnswered(int count) {
    return 'Live na gawain — $count ang sumagot.';
  }

  @override
  String get tcpNotOnWifi =>
      'Hindi naka-Wi-Fi ang tablet na ito. Kailangang nasa iisang Wi-Fi network ang TV at tablet para makapag-cast — kumonekta sa Wi-Fi at subukan ulit.';

  @override
  String get tcpAway => 'Ipinapakita ang “wala ang guro” — i-tap para ituloy.';

  @override
  String get tcpNoTv => 'Wala pang TV na nakakonekta';

  @override
  String tcpWatching(int count) {
    return '$count TV ang nanonood';
  }

  @override
  String get tcpNothing => 'Walang napili';

  @override
  String get tcpCasting => 'Nagka-cast sa TV';

  @override
  String tcpCastingCode(String code) {
    return 'Nagka-cast sa TV · code $code';
  }

  @override
  String cspSemantics(String mode, int count) {
    return 'Nagka-cast sa TV. $mode. $count na nanonood ang nakakonekta.';
  }

  @override
  String get cspTeacherOut => 'Nagka-cast — wala ang guro';

  @override
  String cspWatching(String mode, int count) {
    return '$mode · $count nanonood';
  }

  @override
  String get cspPrev => 'Nakaraan sa TV';

  @override
  String get cspResume => 'Ituloy ang cast';

  @override
  String get cspPause => 'I-pause ang cast';

  @override
  String get cspNext => 'Susunod sa TV';

  @override
  String get tqOpen => 'Buksan ito sa TV mo';

  @override
  String get tqHow =>
      'Sa sariling web browser ng TV, i-scan ang code o i-type ang URL na ito (huwag i-mirror o i-cast ang tablet — sa tablet mananatili ang tunog):';

  @override
  String get tqCopied => 'Nakopya ang URL';

  @override
  String get tqCode => 'Code ng cast';

  @override
  String tqCodeSemantics(String code) {
    return 'Code ng cast $code';
  }

  @override
  String get tqPrivate =>
      'Ang mga TV lang na nagbukas ng eksaktong link na ito ang makakakita ng cast. Nagbabago ang code tuwing magsisimula kang mag-cast.';

  @override
  String get trPrevious => 'Nakaraan';

  @override
  String get trPlay => 'I-play';

  @override
  String get trPause => 'I-pause';

  @override
  String get tlpNeedsNet =>
      'Kailangan ng internet ang mga live na laro at pagsusulit para makasali agad ang mga device ng mag-aaral. Kumonekta sa Wi-Fi o mobile data (libre pa rin ito) at subukan ulit.';

  @override
  String get tlpNoGroup =>
      'Gumawa muna ng home group (Pamahalaan ang Pamilya), saka makakasali ang anak mo sa live na gawain mula sa sarili niyang device.';

  @override
  String get tlpNoClass =>
      'Gumawa muna ng klase (Pamahalaan ang mga Klase), saka makakasali ang mga mag-aaral mo sa live na gawain mula sa sarili nilang device.';

  @override
  String get tlpStartTitle => 'Magsimula ng live na gawain';

  @override
  String get tlpStartBody =>
      'Sasali ang mga mag-aaral sa napiling klase mula sa sarili nilang device, sasagot sa screen, at makakakuha ng bituin. Makikita sa TV ang mga nagtataas ng kamay.';

  @override
  String get tlpHost => 'Klase / grupong magho-host';

  @override
  String get tlpStartSem => 'Simulan ang live na sesyon';

  @override
  String get tlpStart => 'Simulan ang live na sesyon';

  @override
  String get tlpStartFailed =>
      'Hindi masimulan ang live na sesyon. Suriin ang koneksyon mo.';

  @override
  String get tlpTip =>
      'Tip: makikita sa TV ang tanong, mga nagtaas ng kamay, at scoreboard. Sa sarili nilang device sasagot ang mga mag-aaral.';

  @override
  String get tlpSent => 'Naipadala ang tanong sa mga mag-aaral at TV';

  @override
  String get tlpRunning => 'Tumatakbo ang live na sesyon';

  @override
  String tlpAnswered(int count) {
    return '$count ang sumagot sa kasalukuyang tanong';
  }

  @override
  String get tlpEndSem => 'Tapusin ang live na sesyon';

  @override
  String get tlpEnd => 'Tapusin';

  @override
  String get tlpScoring => 'Pagbibigay ng bituin';

  @override
  String tlpBase(int stars) {
    return 'Batayan $stars★';
  }

  @override
  String tlpSpeed(int stars) {
    return ' • bilis +$stars';
  }

  @override
  String tlpFirst(int stars) {
    return ' • una +$stars';
  }

  @override
  String tlpCap(int stars) {
    return ' • hangganan $stars';
  }

  @override
  String get tlpPerCorrect => 'Bituin bawat tamang sagot';

  @override
  String get tlpSpeedBonus => 'Bonus sa bilis (dagdag sa mabibilis sumagot)';

  @override
  String get tlpSpeedWindow => 'Panahon ng bilis (segundo)';

  @override
  String get tlpFirstBonus => 'Bonus sa unang tamang sagot';

  @override
  String get tlpSessionCap =>
      'Hangganan ng bituin sa sesyon (0 = walang hangganan)';

  @override
  String tlpDecrease(String label) {
    return 'Bawasan ang $label';
  }

  @override
  String tlpIncrease(String label) {
    return 'Dagdagan ang $label';
  }

  @override
  String get tlpNoQuestion =>
      'Walang tanong sa screen. Gumawa at ipadala sa ibaba.';

  @override
  String tlpMc(String prompt) {
    return 'Pagpipilian: $prompt';
  }

  @override
  String tlpTf(String prompt) {
    return 'Tama o Mali: $prompt';
  }

  @override
  String tlpPictureN(int count) {
    return 'Pagpili ng larawan ($count pagpipilian)';
  }

  @override
  String get tlpFslSelf => 'Senyas ng FSL — sariling tasa';

  @override
  String tlpFslN(int count) {
    return 'Senyas ng FSL ($count pagpipilian)';
  }

  @override
  String get tlpFlashcard => 'Flashcard';

  @override
  String get tlpHands => 'Mga nagtaas ng kamay';

  @override
  String tlpHandsN(int count) {
    return 'Mga nagtaas ng kamay ($count)';
  }

  @override
  String get tlpNoHands => 'Walang humihingi ng tulong ngayon.';

  @override
  String tlpHandSem(String name) {
    return 'Nagtaas ng kamay si $name. I-activate para alisin.';
  }

  @override
  String get tlpHandled => 'Markahang naasikaso';

  @override
  String get tlpSend => 'Magpadala ng tanong';

  @override
  String get tlpBuildPush => 'Gumawa at ipadala ang tanong';

  @override
  String get tlpNewQuiz => 'Bagong quiz';

  @override
  String get tlpSavedQuizzes => 'Mga naka-save na quiz';

  @override
  String tlpQuestionsN(int count) {
    return '$count tanong';
  }

  @override
  String get tlpRunQuiz => 'Patakbuhin ang quiz na ito';

  @override
  String get tlpDeleteQuiz => 'Burahin ang quiz';

  @override
  String tlpRunningSet(String title, int number, int total) {
    return 'Tumatakbo ang “$title” — tanong $number sa $total';
  }

  @override
  String get tlpScoreboard => 'Live na scoreboard';

  @override
  String get tlpNoAnswers => 'Wala pang sagot.';

  @override
  String get tlpNewQuestion => 'Bagong tanong';

  @override
  String get tlpPushTv => 'Ipadala sa TV';

  @override
  String get tlpPicture => 'Larawan';

  @override
  String get tlpMcLabel => 'Pagpipilian';

  @override
  String get tlpTfLabel => 'Tama / Mali';

  @override
  String get tlpFslSign => 'Senyas ng FSL';

  @override
  String get tlpQuestion => 'Tanong';

  @override
  String get tlpOptionsHint =>
      'Mga pagpipilian (i-tap ang ✓ para markahan ang tama)';

  @override
  String tlpMarkCorrect(int number) {
    return 'Markahang tama ang pagpipilian $number';
  }

  @override
  String tlpOption(int number) {
    return 'Pagpipilian $number';
  }

  @override
  String get tlpOptional => ' (opsyonal)';

  @override
  String get tlpStatement => 'Pahayag';

  @override
  String get tlpTrue => 'Tama';

  @override
  String get tlpFalse => 'Mali';

  @override
  String get tlpAutoOptions =>
      'Pipiliin ng mga mag-aaral ang tugmang salita mula sa 4 na pagpipilian (kusang ginawa).';

  @override
  String get tlpSelfCheck =>
      'Sariling tasa (ita-tap ng mag-aaral ang “Nakuha ko”)';

  @override
  String get tlpSelfCheckNote =>
      'Walang pagpipilian — ang mag-aaral ang huhusga sa sarili niyang senyas.';

  @override
  String get tlpPickOptions =>
      'Pipiliin ng mga mag-aaral ang tugmang salita mula sa mga pagpipilian.';

  @override
  String get tlpNeedOptions =>
      'Maglagay ng tanong at kahit dalawang pagpipilian, at markahan ang tama.';

  @override
  String get tlpNeedStatement => 'Mag-type ng pahayag.';

  @override
  String get tlpNeedCard => 'Pumili muna ng flashcard.';

  @override
  String get tlpUnsupported => 'Hindi suportado.';

  @override
  String get tlpQuizTitle => 'Pamagat ng quiz';

  @override
  String get tlpNoQuestions => 'Wala pang tanong. Idagdag ang una sa ibaba.';

  @override
  String get tlpAddQuestion => 'Magdagdag ng tanong';

  @override
  String get tlpSaveQuiz => 'I-save ang quiz';

  @override
  String tlpTfShort(String prompt) {
    return 'T/M: $prompt';
  }

  @override
  String get tlpPictureChoice => 'Pagpili ng larawan';

  @override
  String get tlpFslSelfShort => 'Sariling tasa sa FSL';

  @override
  String get tlpNoFslCat =>
      'Wala pang senyas ng FSL sa kategoryang ito — subukan ang iba.';

  @override
  String get lrTimeUp => 'Tapos na ang oras para ngayong araw';

  @override
  String lrUsed(int used, int limit) {
    return 'Nagamit mo na ang $used sa $limit minuto.';
  }

  @override
  String get lrOutsideHours => 'Labas sa oras ng pag-aaral';

  @override
  String lrAllowed(String start, String end) {
    return 'Pinapayagan: $start – $end.';
  }

  @override
  String get lrAlarm => 'Alarma';

  @override
  String get lrTakeBreak => 'Oras na para magpahinga.';

  @override
  String get lrRoutineTime => 'Oras ng gawain';

  @override
  String get lrFinishThis => 'Tapusin muna ito para makapagpatuloy.';

  @override
  String get nsDailyTitle => '📚 Oras na para Matuto!';

  @override
  String get nsDailyBody => 'Magsanay tayo ng mga bagong salita ngayon!';

  @override
  String get nsReviewTitle => '🧠 May mga Salitang Kailangang Balikan!';

  @override
  String nsReviewBody(int count) {
    return 'May $count salita kang babalikan. Palakasin natin ang iyong memorya!';
  }

  @override
  String get nsReviewNone =>
      'Oras na para balikan ang mga salita at ituloy ang iyong sunod-sunod na araw!';

  @override
  String get asAlarm => '⏰ Alarma';

  @override
  String get asMoment => 'Oras na para huminto sandali.';

  @override
  String get asWrapUp => 'Oras na para tapusin — i-tap para makita.';

  @override
  String get asTitle => 'Mga Setting ng Alerto';

  @override
  String get asEnable => 'Buksan ang mga Alerto';

  @override
  String get asEnableSub => 'Maabisuhan tungkol sa gawain ng mga mag-aaral';

  @override
  String get asThresholds => 'Mga Hangganan';

  @override
  String get asAccuracyBelow => 'Alerto kapag mas mababa ang katumpakan sa';

  @override
  String get asInactivityAfter => 'Alerto kapag hindi aktibo nang';

  @override
  String asDays(int count) {
    return '$count araw';
  }

  @override
  String get asTypes => 'Mga Uri ng Alerto';

  @override
  String asRecent(int count) {
    return 'Mga Kamakailang Alerto ($count)';
  }

  @override
  String get asNone => 'Wala pang alerto';

  @override
  String asMinutesAgo(int count) {
    return '${count}m ang nakalipas';
  }

  @override
  String asHoursAgo(int count) {
    return '${count}h ang nakalipas';
  }

  @override
  String asDaysAgo(int count) {
    return '${count}d ang nakalipas';
  }

  @override
  String get atLowAccuracy => 'Mababang Katumpakan';

  @override
  String get atStreakBroken => 'Naputol ang Sunod-sunod';

  @override
  String get atInactivity => 'Hindi Aktibo';

  @override
  String get atOverdue => 'Lampas na sa Takdang Oras';

  @override
  String get atAchievement => 'May Nakuhang Parangal';

  @override
  String get atAssessment => 'Natapos ang Pagsusulit';

  @override
  String amLowAccuracy(String name, String accuracy, String threshold) {
    return '$accuracy% ang katumpakan ni $name (mas mababa sa hangganang $threshold%)';
  }

  @override
  String amInactive(String name, String days) {
    return 'Hindi naging aktibo si $name nang $days araw';
  }

  @override
  String amStreak(String name) {
    return 'Naputol ang sunod-sunod na araw ni $name';
  }

  @override
  String get daTitle => 'Detalyadong Analytics';

  @override
  String get daAvgSession => 'Karaniwang Sesyon';

  @override
  String daMinutesPerSession(String minutes) {
    return '$minutes minuto bawat sesyon';
  }

  @override
  String get aaCategoryOverview => 'Buod ng mga Kategorya';

  @override
  String aaMastered(int count) {
    return '$count Kabisado';
  }

  @override
  String aaLearning(int count) {
    return '$count Pinag-aaralan';
  }

  @override
  String aaNew(int count) {
    return '$count Bago';
  }

  @override
  String get aaSessionInsights => 'Tungkol sa mga Sesyon';

  @override
  String get aaAvgSession => 'Avg na Sesyon';

  @override
  String get aaTotalSessions => 'Kabuuang Sesyon';

  @override
  String ptTitle(String name) {
    return '$name — Timeline';
  }

  @override
  String get ptAccuracySub =>
      'Karaniwang katumpakan bawat araw — huling 30 araw';

  @override
  String get ptStudyTime => 'Oras ng Pag-aaral ⏱️';

  @override
  String get ptMinutesSub => 'Minuto bawat araw — huling 30 araw';

  @override
  String ptAvgPerDay(int minutes) {
    return 'Avg: $minutes min/araw';
  }

  @override
  String get ptCategoryProgress => 'Progreso sa Kategorya 📚';

  @override
  String get ptNotEnough => 'Kulang pa ang datos';

  @override
  String get scmpSelect2 => 'Pumili ng kahit 2 mag-aaral na paghahambingin';

  @override
  String get scmpSelect23 =>
      'Pumili ng 2–3 mag-aaral sa itaas na paghahambingin';

  @override
  String get scmpStreakDays => 'Sunod-sunod (araw)';

  @override
  String get scmpStarsEarned => 'Nakuhang Bituin';

  @override
  String get scmpCategoryComparison => 'Paghahambing ng Kategorya';

  @override
  String get scmpStrengths => 'Mga Kalakasan at Kahinaan';

  @override
  String get cmSignIn => 'Mag-sign in muna para mapamahalaan ang mga klase.';

  @override
  String get mqRoundsPerPlayer => 'Round bawat Manlalaro';

  @override
  String get gzFocusHint =>
      'Tumingin ◀ ▶ ▲ ▼ para gumalaw · kumurap para pumindot';

  @override
  String get spdSupport => 'Suporta';

  @override
  String get lgcPerCategory => 'Hati Ayon sa Kategorya';

  @override
  String get rsTimer => 'Timer';

  @override
  String get ebTitle => 'Naku! May nangyaring mali';

  @override
  String get ebBody =>
      'Nagkaproblema ang bahaging ito ng app.\nSubukang bumalik o i-restart ang app.';

  @override
  String get gwAuto => 'Auto';

  @override
  String gwStarsOf(int stars, int max) {
    return '$stars sa $max bituin';
  }

  @override
  String get cdPlaying => 'Naglalaro';

  @override
  String get cdReviewing => 'Nagbabalik-aral ng Flashcard';

  @override
  String get cdStudying => 'Nag-aaral';

  @override
  String get brRestored => 'Matagumpay na naibalik ang backup!';

  @override
  String get brNoFile => 'Walang napiling file.';

  @override
  String get brCantRead => 'Hindi mabasa ang file.';

  @override
  String get brPickFailed =>
      'Hindi mabuksan ang pagpili ng file. Pakisubukan ulit.';

  @override
  String get brCorrupt => 'Hindi wastong backup file. Maaaring sira ang file.';

  @override
  String get brBadFormat =>
      'Hindi wastong format ng backup. Hindi mabasa ang datos.';

  @override
  String get brNewer =>
      'Ginawa ang backup na ito sa mas bagong bersyon ng FlashLearn PWD. I-update muna ang app.';

  @override
  String get brNoData => 'Hindi wastong ayos ng backup. Walang nakitang datos.';

  @override
  String get brRestoreFailed => 'Hindi maibalik ang backup. Pakisubukan ulit.';

  @override
  String get csxNotConnected => 'Hindi nakakonekta ang cloud sync';

  @override
  String get csxNotConnectedBody =>
      'I-restart ang app. Kung hindi pa rin nakakonekta, suriin ang internet ng device na ito.';

  @override
  String ieImported(String name) {
    return 'Matagumpay na na-import ang “$name”';
  }

  @override
  String get ieNoFile => 'Walang napiling file';

  @override
  String get ieCantRead => 'Hindi mabasa ang file';

  @override
  String get ieBadFormat => 'Hindi wastong format ng file';

  @override
  String get ieNotProfile =>
      'Walang wastong profile ng mag-aaral sa file na ito';

  @override
  String get ieExists =>
      'May profile nang may ganitong ID. Burahin muna ito o mag-export mula sa ibang device.';

  @override
  String get ieReadFailed => 'Hindi mabasa ang file. Pakisubukan ulit.';

  @override
  String get ehNetwork => 'May problema sa network. Pakisuri ang koneksyon mo.';

  @override
  String get ehFormat =>
      'May mali sa format ng datos. Maaaring may sirang datos.';

  @override
  String get ehTimeout => 'Masyadong natagalan. Pakisubukan ulit.';

  @override
  String get ehGeneric => 'May nangyaring mali. Tuloy pa rin ang app.';

  @override
  String dwsUnlocked(String badge) {
    return 'Nabuksan ang $badge!';
  }

  @override
  String get assessMediaPhoto => 'Larawan';

  @override
  String get assessMediaGif => 'GIF na gumagalaw';

  @override
  String get assessMediaVideo => 'Bidyo';

  @override
  String get assessMediaAudio => 'Tunog';

  @override
  String get assessMediaSign => 'Bidyo sa FSL';

  @override
  String get assessMediaSectionTitle => 'Larawan, bidyo at senyas';

  @override
  String get assessMediaSectionHelp =>
      'Opsyonal. Makikita ito ng bawat mag-aaral sa paraang angkop sa kanya — unang makikita ng mag-aaral na Bingi ang bidyo sa FSL, at maririnig ng may mahinang paningin ang tunog at ang paglalarawan.';

  @override
  String assessMediaAdd(String kind) {
    return 'Magdagdag ng $kind';
  }

  @override
  String get assessMediaFromDevice => 'Pumili mula sa device na ito';

  @override
  String get assessMediaOnDevice =>
      'Nasa tablet na ito lang — hindi ito makikita ng mag-aaral sa ibang device.';

  @override
  String get assessMediaPasteLink => 'O mag-paste ng link';

  @override
  String get assessMediaLinkHint => 'https://… (direktang link sa file)';

  @override
  String get assessMediaUseLink => 'Gamitin ang link na ito';

  @override
  String get assessMediaLinkInvalid =>
      'Mag-paste ng link na nagsisimula sa https://';

  @override
  String get assessMediaLinkReaches => 'Makikita ang link sa bawat device.';

  @override
  String get assessMediaPreview => 'Silipin';

  @override
  String get assessMediaReplace => 'Palitan';

  @override
  String get assessMediaRemove => 'Alisin';

  @override
  String assessMediaTooLarge(int size) {
    return 'Masyadong malaki ang file na iyan. Pumili ng mas maliit sa $size MB.';
  }

  @override
  String get assessMediaPickFailed =>
      'Hindi maidagdag ang file na iyan. Subukan ang iba.';

  @override
  String get assessMediaDescribe => 'Ilarawan ito sa mga salita';

  @override
  String get assessMediaDescribeHelp =>
      'Babasahin nang malakas para sa hindi nakakakita, at ipapakita bilang caption para sa hindi nakakarinig.';

  @override
  String get assessMediaDescribeHelpQuestion =>
      'Babasahin nang malakas para sa hindi nakakakita, at ipapakita bilang caption para sa hindi nakakarinig. Huwag ibigay ang sagot.';

  @override
  String get assessMediaSignHelp =>
      'Ipinapakita sa mga mag-aaral na gumagamit ng senyas. Kung ang senyas mismo ang itatanong, ilagay ang clip sa Bidyo para makita ng lahat.';

  @override
  String assessMediaTipFor(String names, String advice) {
    return 'Para kay $names: $advice';
  }

  @override
  String get assessMediaTipHearing =>
      'magdagdag ng bidyo sa FSL, at isulat sa mga salita ang anumang tunog.';

  @override
  String get assessMediaTipVisual =>
      'magdagdag ng tunog, at ilarawan sa mga salita ang mga larawan — babasahin ito nang malakas.';

  @override
  String get assessMediaTipCognitive =>
      'pinakamainam ang isang malinaw na larawan — isa-isa ang nakikita nila.';

  @override
  String get assessMediaTipMotor =>
      'kusang nagpe-play ang mga bidyo, kaya walang maliliit na pindutang kailangan.';

  @override
  String get assessMediaTipMultiple =>
      'magdagdag ng bidyo sa FSL at larawan, at ilarawan ang mga ito sa mga salita.';

  @override
  String get assessMediaTipWordsOnly =>
      'isulat ang lahat sa mga salita — ipapakita ito bilang caption.';

  @override
  String get assessMediaSignHeading => 'Senyas';

  @override
  String get assessMediaFilmedInFsl => 'Kinunan sa FSL';

  @override
  String get assessMediaCaption => 'Ang ipinapakita o sinasabi nito';

  @override
  String get assessMediaReadAloud => 'Basahin mo sa akin';

  @override
  String assessMediaShowMore(int count) {
    return 'Ipakita pa ($count)';
  }

  @override
  String get assessMediaTapToEnlarge => 'Pindutin para lumaki';

  @override
  String get assessMediaPlayAnimation => 'I-play ang gumagalaw na larawan';

  @override
  String get assessMediaStopAnimation => 'Ihinto ang gumagalaw na larawan';

  @override
  String get assessMediaPlay => 'I-play';

  @override
  String get assessMediaPause => 'Ihinto sandali';

  @override
  String get assessMediaReplay => 'Panoorin ulit';

  @override
  String get assessMediaClose => 'Isara';

  @override
  String assessMediaOnOtherDevice(String kind) {
    return 'Nasa ibang tablet ang $kind na ito at hindi pa naibabahagi.';
  }

  @override
  String assessMediaCouldNotLoad(String kind) {
    return 'Hindi ma-load ang $kind na ito. Subukan muli kapag may internet.';
  }

  @override
  String get assessMediaPreparing => 'Inihahanda ang mga larawan at bidyo…';

  @override
  String get assessMediaMissingTitle =>
      'May mga larawan o bidyong wala pa sa tablet na ito';

  @override
  String get assessMediaMissingBody =>
      'Kumonekta sa Wi‑Fi at subukang muli, o magsimula nang wala ang mga ito. Hindi pa nagsisimula ang pagsusulit.';

  @override
  String get assessMediaStartAnyway => 'Magsimula nang wala ang mga ito';

  @override
  String get assessInstructionsMediaTitle =>
      'Larawan, bidyo o senyas para sa mga tagubilin';

  @override
  String get assessBriefingTitle => 'Bago ka magsimula';

  @override
  String get assessBriefingStart => 'Simulan ang pagsusulit';

  @override
  String get assessBriefingLater => 'Mamaya na lang';

  @override
  String assessFeedbackFor(String name) {
    return 'Puna para kay $name';
  }

  @override
  String assessFeedbackOn(String title) {
    return 'Puna sa $title';
  }

  @override
  String get assessFeedbackFromEducator => 'Mula sa iyong guro o magulang';

  @override
  String get assessFeedbackNote => 'Iyong tala';

  @override
  String get assessFeedbackNoteHint =>
      'Ano ang naging maganda, at ano ang susunod na sasanayin';

  @override
  String get assessFeedbackSave => 'Ipadala ang puna';

  @override
  String get assessFeedbackRemove => 'Alisin ang puna';

  @override
  String get assessFeedbackEmpty =>
      'Sumulat muna ng tala o magdagdag ng larawan, bidyo o tunog.';

  @override
  String get assessFeedbackNotFinished => 'Hindi pa tapos';

  @override
  String assessFeedbackScore(int percent) {
    return 'Iskor: $percent%';
  }

  @override
  String get assessFeedbackForYou => 'Puna para sa Iyo';

  @override
  String assessFeedbackAdd(String name) {
    return 'Magdagdag ng puna para kay $name';
  }

  @override
  String assessFeedbackEdit(String name) {
    return 'Baguhin ang puna para kay $name';
  }

  @override
  String assessFeedbackSaved(String name) {
    return 'Naipadala ang puna kay $name.';
  }

  @override
  String get assessFeedbackRemoved => 'Inalis ang puna.';

  @override
  String assessFeedbackLocalOnly(String name) {
    return 'Nai-save ang puna sa device na ito — hindi pa naipapadala. Makakarating ito kay $name kapag gumagana na ang pag-sync.';
  }

  @override
  String get assessFeedbackNotOwner =>
      'Nai-save lang sa device na ito. Na-restore ang profile na ito sa ibang device, kaya iyon na ang nagsi-sync — hindi naipadala ang puna.';

  @override
  String get assessFeedbackTapToOpen => 'Pindutin para buksan';

  @override
  String get assessFeedbackHas => 'May puna na';

  @override
  String get assessMediaShared => 'Naibahagi na — makikita sa bawat device.';

  @override
  String get assessMediaNotShared =>
      'Nasa tablet na ito lang — hindi pa naibabahagi.';

  @override
  String assessMediaSharing(int percent) {
    return 'Ibinabahagi… $percent%';
  }

  @override
  String get assessMediaShareNow => 'Ibahagi ngayon';

  @override
  String assessMediaFromDeviceShared(int size) {
    return 'Ibabahagi ito sa bawat device (mga file hanggang $size MB).';
  }

  @override
  String assessMediaShareTooLarge(int size) {
    return 'Lampas sa $size MB — mananatili lang ang file na ito sa tablet na ito.';
  }

  @override
  String get assessMediaShareFailed =>
      'Hindi ito maibahagi ngayon. Naka-save ito sa tablet na ito at ibabahagi kapag may internet na.';

  @override
  String get assessMediaShareNotOwner =>
      'Pinamamahalaan na ang profile na ito mula sa ibang device, kaya hindi makapagbahagi ng file mula rito.';

  @override
  String get captureRecordTitle => 'Mag-record ng bidyo';

  @override
  String get capturePhotoTitle => 'Kumuha ng larawan';

  @override
  String get captureStart => 'Simulan ang pag-record';

  @override
  String get captureStop => 'Ihinto';

  @override
  String get captureTakePhoto => 'Kunan';

  @override
  String get captureSwitchCamera => 'Palitan ang camera';

  @override
  String get captureUse => 'Gamitin ang bidyong ito';

  @override
  String get captureUsePhoto => 'Gamitin ang larawang ito';

  @override
  String get captureRetake => 'Mag-record ulit';

  @override
  String get captureRetakePhoto => 'Kumuha ulit';

  @override
  String get captureClose => 'Isara';

  @override
  String get captureRecordingNow => 'Nagre-record';

  @override
  String captureTimeLeft(int seconds) {
    return '$seconds segundo na lang';
  }

  @override
  String get captureGetReady => 'Maghanda…';

  @override
  String get captureStarted => 'Nagsimula ang pag-record';

  @override
  String get captureStopped => 'Huminto ang pag-record';

  @override
  String captureMaxLength(int seconds) {
    return 'Hanggang $seconds segundo';
  }

  @override
  String get captureNoCamera =>
      'Walang camera sa tablet na ito na magagamit ng app.';

  @override
  String get captureDenied =>
      'Nakapatay ang camera o mikropono para sa FlashLearn. Buksan ang mga ito sa settings ng tablet, saka subukang muli.';

  @override
  String get captureFailed => 'Hindi mabuksan ang camera. Subukang muli.';

  @override
  String get captureTryAgain => 'Subukang muli';

  @override
  String get captureRecordedHint =>
      'Handa na ang iyong bidyo. Gamitin ito, o mag-record ulit.';

  @override
  String get assessMediaRecordVideo => 'Mag-record gamit ang camera';

  @override
  String get assessMediaTakePhoto => 'Kumuha ng larawan gamit ang camera';

  @override
  String get assessMediaRecordSignTitle => 'Mag-record sa FSL';

  @override
  String get assessPictureChoicesHelp =>
      'Magdagdag ng larawan sa kahit anong pagpipilian. Mapipindot ng mga hindi pa nakakabasa ang larawan; maririnig pa rin ng may mahinang paningin ang mga salita.';

  @override
  String get assessPictureAnswers => 'Mga sagot na larawan';

  @override
  String assessChoicePictureAdd(String letter) {
    return 'Magdagdag ng larawan sa pagpipiliang $letter';
  }

  @override
  String assessChoicePicture(String letter) {
    return 'Larawan ng pagpipiliang $letter';
  }

  @override
  String get assessChoicePictureReplace => 'Palitan ang larawan';

  @override
  String get assessChoicePictureRemove => 'Alisin ang larawan';

  @override
  String get formatVideoResponse => 'Sagot sa Bidyo';

  @override
  String get assessVideoAnswerRecord => 'I-record ang iyong sagot';

  @override
  String get assessVideoAnswerHintSign => 'Isenyas ang iyong sagot sa camera.';

  @override
  String get assessVideoAnswerHintSay =>
      'Sabihin nang malakas ang iyong sagot sa camera.';

  @override
  String get assessVideoAnswerHintEither =>
      'Isenyas o sabihin ang iyong sagot sa camera.';

  @override
  String get assessVideoAnswerSaved =>
      'Nai-save ang sagot — panonoorin ito ng iyong guro o magulang.';

  @override
  String get assessVideoAnswerRedo => 'I-record muli';

  @override
  String get assessVideoAnswerSending =>
      'Ipinapadala ang iyong mga sagot na bidyo…';

  @override
  String assessToReview(int count) {
    return '$count sagot na susuriin';
  }

  @override
  String get assessSentForReview => 'Naipadala sa iyong guro o magulang';

  @override
  String get assessAllForReview =>
      'Panonoorin ng iyong guro o magulang ang iyong mga sagot at sasabihin kung paano ka nakagawa.';

  @override
  String get assessReviewTitle => 'Mga sagot na bidyo na susuriin';

  @override
  String get assessReviewCorrect => 'Tama';

  @override
  String get assessReviewNotYet => 'Hindi pa';

  @override
  String get assessReviewedCorrect => 'Minarkahang tama';

  @override
  String get assessReviewedNotYet => 'Hindi pa — subukan ulit';

  @override
  String get assessReviewWaiting => 'Hinihintay pang suriin';

  @override
  String get assessWhatToLookFor =>
      'Ano ang ipinapakita ng mahusay na sagot (ikaw lang ang makakakita nito)';

  @override
  String get assessYourVideoAnswer => 'Ang iyong sagot na bidyo';

  @override
  String assessReviewedScore(int correct, int total) {
    return '$correct sa $total ang tama';
  }

  @override
  String get portfolioTitle => 'Portpolyo';

  @override
  String get portfolioMine => 'Aking portpolyo';

  @override
  String get portfolioMineSub =>
      'Ang iyong mga pagsusulit, sagot sa video at puna';

  @override
  String portfolioOfSub(String name) {
    return 'Mga pagsusulit, sagot sa video at puna ni $name';
  }

  @override
  String get portfolioTestsTaken => 'Natapos na pagsusulit';

  @override
  String get portfolioAverage => 'Karaniwang iskor';

  @override
  String get portfolioVideoAnswers => 'Sagot sa video';

  @override
  String get portfolioFeedback => 'Mga puna';

  @override
  String get portfolioSoFar => 'Lahat ng nagawa';

  @override
  String get portfolioEmpty =>
      'Wala pang laman. Lalabas dito ang mga natapos na pagsusulit at puna.';

  @override
  String get portfolioWatchAnswers => 'Panoorin ang mga sagot sa video';

  @override
  String portfolioSupports(String list) {
    return 'Mga suporta: $list';
  }

  @override
  String get portfolioSharePdf => 'PDF para sa magulang';

  @override
  String get portfolioPdfTitle => 'Portpolyo ng Pag-aaral';

  @override
  String portfolioPdfLearner(String name) {
    return 'Mag-aaral: $name';
  }

  @override
  String portfolioPdfMade(String date) {
    return 'Ginawa noong $date';
  }

  @override
  String get portfolioPdfSummary => 'Buod';

  @override
  String get portfolioPdfTests => 'Mga Pagsusulit';

  @override
  String get portfolioPdfDate => 'Petsa';

  @override
  String get portfolioPdfTest => 'Pagsusulit';

  @override
  String get portfolioPdfScore => 'Iskor';

  @override
  String get portfolioPdfFeedback => 'Puna mula sa guro o magulang';

  @override
  String portfolioPdfInApp(String kinds) {
    return 'Kalakip din: $kinds. Buksan ang app para panoorin o pakinggan.';
  }

  @override
  String portfolioPdfSubject(String name) {
    return 'Portpolyo ng pag-aaral ni $name';
  }

  @override
  String get portfolioPdfFailed => 'Hindi magawa ang PDF. Pakisubukang muli.';

  @override
  String get portfolioPdfWaiting => 'Hinihintay pang suriin';

  @override
  String get assessEditTitle => 'I-edit ang Pagsusulit';

  @override
  String assessEditTooltip(String title) {
    return 'I-edit ang $title';
  }

  @override
  String assessDeleteTooltip(String title) {
    return 'Burahin ang $title';
  }

  @override
  String assessEditSaved(String title) {
    return 'Nai-save ang mga pagbabago sa “$title”';
  }

  @override
  String assessEditSavedSent(String title) {
    return 'Nai-save ang mga pagbabago sa “$title” at ipinadala sa mga tablet na binigyan nito';
  }

  @override
  String assessEditAlreadyTaken(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'May $count mag-aaral na nakasagot na nito. Mananatili ang kanilang iskor; ang mga pagbabago ay para sa susunod na pagsagot.',
      one:
          'May 1 mag-aaral na nakasagot na nito. Mananatili ang kanyang iskor; ang mga pagbabago ay para sa susunod na pagsagot.',
    );
    return '$_temp0';
  }

  @override
  String assessEditedOn(String date) {
    return 'Binago noong $date';
  }

  @override
  String get assessEditDiscardTitle => 'Itapon ang mga pagbabago?';

  @override
  String get assessEditDiscardBody =>
      'Mananatili ang naka-save na pagsusulit gaya ng dati.';

  @override
  String get assessEditNotFound =>
      'Hindi makita ang pagsusulit na iyon. Maaaring nabura na ito.';

  @override
  String assessMediaWouldNotPlay(String kind) {
    return 'Nandito na ang $kind pero ayaw mag-play sa tablet na ito.';
  }

  @override
  String get updateCheckTitle => 'Tingnan kung may update';

  @override
  String get updateCheckTap =>
      'I-tap para malaman kung may mas bagong bersyon sa website.';

  @override
  String get updateCheckChecking => 'Tinitingnan ang website…';

  @override
  String updateCheckLatest(String version) {
    return 'Pinakabagong bersyon na ang nasa tablet na ito ($version).';
  }

  @override
  String updateCheckAvailable(String version) {
    return 'Handa na ang bersyon $version — i-tap para makita kung paano mag-update.';
  }

  @override
  String get updateCheckUnknown =>
      'Hindi makapag-check ngayon. Kumonekta sa internet at i-tap para subukan ulit.';

  @override
  String get updateCardTitle => 'May bagong bersyon ng FlashLearn PWD';

  @override
  String updateCardBody(String version) {
    return 'Nasa website na ang bersyon $version. Kapag in-install ito sa ibabaw ng kasalukuyan, mananatili ang lahat ng profile sa tablet na ito.';
  }

  @override
  String get updateCardGet => 'Paano mag-update';

  @override
  String get updateCardLater => 'Mamaya na';

  @override
  String updateOpenFailed(String url) {
    return 'Buksan ang $url sa browser para makuha ang bagong bersyon.';
  }
}
