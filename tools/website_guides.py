"""The guides on website/guides.html that are written for the website, and the two audience
categories every guide on that page belongs to.

Help & Guides has two categories, by who is reading:
  * For Students and Children — the learners;
  * For Teachers and Parents — the adults beside them.
They are only a way to sort the guides; nothing here is a feature of the app.

Most guides are the app's own (lib/features/help/models/guides.dart, word for word). The few
below add pictures and plain words for things the app's guides do not cover, and never repeat
a line of them: a Child profile's start and Home, the Talk Board, My Day and feelings, the
buddy, rewards, staying safe, and — for the adults — supervision and safe use. Every line was
checked against the app (1.4.6): the Student and Child homes
(lib/features/home/screens/home_screen.dart, child_home_screen.dart), the join and set-up
screens, the tab bar, and the strings in lib/l10n/app_*.arb. Names in quotes are the ones the
app shows. Where a student's and a child's Home name the same thing differently, both names
are given.

Each guide has the app's shape (title, summary, sections of lines, numbered where they are
steps), so tools/guides_page_build.py renders it the same way, with "Read aloud". `pics` are
pictures of the app's own screens (integration_test/site_pictures_test.dart, offline, sample
child "Mia"), made by tools/site_pictures_build.py; a section's pictures sit beside it.
"""


def T(en, fil):
    return {"en": en, "fil": fil}


def L(en, fil, label=None):
    return {"label": label, "text": T(en, fil)}


def S(heading, lines, numbered=False, pics=None):
    return {"heading": heading, "lines": lines, "numbered": numbered, "pics": pics or []}


def P(src, alt, caption):
    """A picture: src under website/, alt text and caption as (en, fil)."""
    return {"src": src, "alt": T(*alt), "caption": T(*caption)}


# ── The two audience categories (every guide on the page, app and website) ───────────────
# key, emoji, tone (site.css .tone-*), title, description, [(subgroup label, [guide ids])]
CATEGORIES = [
    ("learners", "🎒", "purple",
     T("For Students and Children", "Para sa Mag-aaral at mga Bata"),
     T("Simple steps for learners: how to start, learn and play, and use the app in the way that suits you.",
       "Mga simpleng hakbang para sa mag-aaral: paano magsimula, matuto at maglaro, at gamitin ang app sa paraang bagay sa iyo."),
     [(T("Start here", "Dito magsimula"), ["students", "children", "stay-safe"]),
      (T("Learn and play", "Matuto at maglaro"), ["talk-board", "my-day", "buddy", "rewards"]),
      (T("Use the app your way", "Gamitin ang app sa paraan mo"),
       ["accessibility", "gaze", "voice", "controller", "keyboard", "screenReader"])]),
    ("educators", "🧑‍🏫", "teal",
     T("For Teachers and Parents", "Para sa Guro at Magulang"),
     T("Set up the app, guide and support each learner, and use the tools for adults.",
       "I-set up ang app, gabayan at suportahan ang bawat mag-aaral, at gamitin ang mga tool para sa nakatatanda."),
     [(T("Set up and guide", "Mag-set up at gumabay"), ["teachers", "parents", "timeBreaks", "supervision"]),
      (T("Tools and feedback", "Mga tool at feedback"), ["tvCast", "feedback"])]),
]

# Website look per guide: emoji and tile tone (site.css .tone-*).
LOOK = {
    "children": ("🧒", "orange"),
    "stay-safe": ("🛡️", "red"),
    "talk-board": ("💬", "teal"),
    "my-day": ("🗓️", "green"),
    "buddy": ("🧸", "gold"),
    "rewards": ("⭐", "magenta"),
    "supervision": ("🤝", "indigo"),
}

GUIDES = [
    {
        "id": "children",
        "title": T("For children", "Para sa mga bata"),
        "summary": T("Join your family in the app, and find your way around your Home.",
                     "Sumali sa iyong pamilya sa app, at alamin ang daan sa iyong Home."),
        "sections": [
            S(T("Join your family", "Sumali sa iyong pamilya"), [
                L("Ask your parent to help you.", "Magpatulong sa iyong magulang."),
                L("Choose “Child Profile (PWD)”.", "Piliin ang “Profile ng Bata (PWD)”."),
                L("Type the code your parent gives you. Press “Join group”.",
                  "I-type ang code na ibibigay ng iyong magulang. Pindutin ang “Sumali sa grupo”."),
                L("Type your name, pick a picture and add your birthday.",
                  "I-type ang iyong pangalan, pumili ng larawan at ilagay ang iyong kaarawan."),
                L("You can add a 4-number PIN. Only you and your parent should know it.",
                  "Maaari kang maglagay ng PIN na may 4 na numero. Ikaw at ang iyong magulang lang ang dapat makaalam nito."),
            ], numbered=True, pics=[
                P("assets/kids/join.webp",
                  ("The Join Home Group screen: “Enter the code your parent or guardian shared.”, a box for the home-group code, and a Join group button.",
                   "Ang screen na Join Home Group: “Enter the code your parent or guardian shared.”, isang kahon para sa code, at button na Join group."),
                  ("Type your parent’s code here.", "Dito i-type ang code ng iyong magulang.")),
            ]),
            S(T("Your Home", "Ang iyong Home"), [
                L("Home says hello to you by name.", "Binabati ka ng Home gamit ang iyong pangalan."),
                L("At the top are your Streak, Words and Stars.",
                  "Sa itaas ang iyong Sunod-sunod, Mga Salita at Mga Bituin."),
                L("Below are My Day and My Feelings, then four groups of big buttons.",
                  "Nasa ibaba ang “Ang Aking Araw” at “Aking Damdamin”, saka apat na grupo ng malalaking button."),
            ], pics=[
                P("assets/kids/home.webp",
                  ("A child’s Home: “Hi, Mia!”, the Streak, Words and Stars, the My Day and My Feelings cards, and the first big buttons of Play & Learn: Games, Cards, Stories and more.",
                   "Ang Home ng bata: “Hi, Mia!”, ang Streak, Words at Stars, ang mga card na My Day at My Feelings, at ang unang malalaking button ng Play & Learn: Games, Cards, Stories at iba pa."),
                  ("Your Home.", "Ang iyong Home.")),
            ]),
            S(T("The big buttons", "Ang malalaking button"), [
                L("Games, Cards, Stories, Practice Words and My Progress, and the sign buttons when signs are on.",
                  "Mga Laro, Mga Kard, Mga Kwento, Sanayin ang mga Salita at Aking Progreso, at ang mga button ng senyas kapag naka-on ang mga senyas.",
                  T("Play & Learn", "Maglaro at Matuto")),
                L("Adventure Map, Practice With Me, Word Hunt, Talk Board and Buddy.",
                  "Mapa ng Pakikipagsapalaran, Magsanay Kasama Ko, Word Hunt, Talk Board at Kaibigan.",
                  T("Explore & Create", "Tuklasin at Lumikha")),
                L("Play Together, Peer Collab, Messages and My Notes.",
                  "Maglaro Nang Sabay, Magtulungan, Mga Mensahe at Aking mga Tala.",
                  T("Friends", "Mga Kaibigan")),
                L("My Player Card, Stickers, How was it? and My Notebook.",
                  "Aking Kard ng Manlalaro, Mga Sticker, Kumusta ito? at Aking Kuwaderno.",
                  T("Rewards & Feelings", "Gantimpala at Damdamin")),
            ], pics=[
                P("assets/kids/rewards.webp",
                  ("The bottom of a child’s Home: the Friends buttons (Play Together, Peer Collab, Messages, My Notes) and the Rewards & Feelings buttons (My Player Card, Stickers, How was it?, My Notebook).",
                   "Ang ibaba ng Home ng bata: ang mga button ng Friends (Play Together, Peer Collab, Messages, My Notes) at ng Rewards & Feelings (My Player Card, Stickers, How was it?, My Notebook)."),
                  ("Friends, and Rewards & Feelings.", "Mga Kaibigan, at Gantimpala at Damdamin.")),
            ]),
            S(T("Good to know", "Magandang malaman"), [
                L("The tabs, cards, games and stories work the same for students and children: see the guide For students.",
                  "Pareho ang mga tab, cards, laro at kuwento para sa mag-aaral at bata: tingnan ang gabay na Para sa mag-aaral."),
                L("Your parent can see your progress and set your time on the tablet.",
                  "Nakikita ng iyong magulang ang iyong progreso at naitatakda niya ang iyong oras sa tablet."),
            ]),
        ],
        "more": [("#g-students", T("The guide For students", "Ang gabay na Para sa mag-aaral"))],
    },
    {
        "id": "stay-safe",
        "title": T("Stay safe", "Manatiling ligtas"),
        "summary": T("Simple rules to keep you safe and happy.",
                     "Mga simpleng tuntunin para manatili kang ligtas at masaya."),
        "sections": [
            S(T("In the app", "Sa app"), [
                L("Keep your PIN a secret. Only you and your parent or teacher should know it.",
                  "Ilihim ang iyong PIN. Ikaw at ang iyong magulang o guro lang ang dapat makaalam nito."),
                L("In Messages you write only to people you know in the app: your teacher or parent, and your friends. A child’s new friend needs a parent’s OK.",
                  "Sa Mga Mensahe, sumusulat ka lang sa mga kakilala mo sa app: ang iyong guro o magulang, at ang iyong mga kaibigan. Kailangan ng pahintulot ng magulang ang bagong kaibigan ng bata."),
                L("Never share your address, your school, a phone number or a password.",
                  "Huwag ibahagi ang iyong address, paaralan, numero ng telepono o password."),
                L("If something makes you feel sad, scared or confused, stop and tell your parent or teacher.",
                  "Kapag may nagpalungkot, nagpatakot o nagpalito sa iyo, huminto at sabihin sa iyong magulang o guro."),
            ]),
            S(T("Your body", "Ang iyong katawan"), [
                L("When your eyes feel tired, rest them. Stretch, or drink some water.",
                  "Kapag pagod na ang mga mata, ipahinga ang mga ito. Mag-unat, o uminom ng tubig."),
                L("Sit up and hold the tablet with both hands, not too close to your face.",
                  "Umupo nang tuwid at hawakan ang tablet ng dalawang kamay, hindi masyadong malapit sa mukha."),
                L("Word Hunt uses the camera. Ask a grown-up first, and point it at things, not at people.",
                  "Gumagamit ng camera ang Word Hunt. Magpaalam muna sa nakatatanda, at itutok ito sa mga bagay, hindi sa tao."),
            ]),
            S(T("When your time is up", "Kapag tapos na ang oras"), [
                L("The tablet tells you: with a sound and words, or with a sign and a picture.",
                  "Sasabihin ito ng tablet: may tunog at salita, o may senyas at larawan."),
                L("Then it shows who to give the tablet to, like your parent or teacher.",
                  "Saka nito ipapakita kung kanino mo ibibigay ang tablet, gaya ng iyong magulang o guro."),
                L("If the screen is locked, ask your parent or teacher to unlock it.",
                  "Kapag naka-lock ang screen, hilingin sa iyong magulang o guro na i-unlock ito."),
            ]),
        ],
        "more": [("privacy.html", T("Privacy & data: what the app keeps", "Privacy at datos: ano ang itinatago ng app"))],
    },
    {
        "id": "talk-board",
        "title": T("Talk with pictures", "Makipag-usap gamit ang larawan"),
        "summary": T("Use the Talk Board to say what you want or need.",
                     "Gamitin ang Talk Board para sabihin ang gusto o kailangan mo."),
        "sections": [
            S(T("Say it with the Talk Board", "Sabihin gamit ang Talk Board"), [
                L("On Home, tap Talk Board.", "Sa Home, i-tap ang Talk Board."),
                L("Choose a group, like Greetings, Needs or Feelings.",
                  "Pumili ng grupo, gaya ng Greetings, Needs o Feelings."),
                L("Tap pictures to build a sentence.", "Pindutin ang mga larawan para bumuo ng pangungusap."),
                L("Tap the green play button to hear it out loud.",
                  "I-tap ang berdeng play button para marinig ito nang malakas."),
            ], numbered=True, pics=[
                P("assets/kids/talk.webp",
                  ("The Talk Board: the sentence Hello, Good morning at the top, groups such as Greetings, Needs and Feelings, and picture tiles such as Hello, Goodbye, Thank you and Please.",
                   "Ang Talk Board: ang pangungusap na Hello, Good morning sa itaas, mga grupo gaya ng Greetings, Needs at Feelings, at mga larawan gaya ng Hello, Goodbye, Thank you at Please."),
                  ("Tap pictures to make a sentence.", "Pindutin ang mga larawan para bumuo ng pangungusap.")),
            ]),
        ],
        "more": [("features.html#f-talkboard", T("The Talk Board in Features in Action", "Ang Talk Board sa Tingnan ang mga Feature"))],
    },
    {
        "id": "my-day",
        "title": T("My Day and your feelings", "Ang My Day at ang iyong damdamin"),
        "summary": T("See what comes next today, and say how you feel.",
                     "Tingnan ang susunod na gagawin ngayon, at sabihin ang nararamdaman mo."),
        "sections": [
            S(T("My Day", "Ang Aking Araw"), [
                L("On Home, the My Day card shows what comes next.",
                  "Sa Home, ipinapakita ng card na My Day ang susunod na gagawin."),
                L("Each step has a picture and a time.", "May larawan at oras ang bawat hakbang."),
                L("Your teacher or parent sets up My Day for you. It shows here when they do.",
                  "Ang iyong guro o magulang ang gumagawa ng My Day para sa iyo. Lalabas ito rito kapag nagawa na nila."),
            ], pics=[
                P("assets/kids/my-day.webp",
                  ("My Day before it is set up: “No routine yet. Your teacher or parent can set up a daily routine for you. It will show up here once they do.”",
                   "Ang My Day bago ito gawin: “No routine yet. Your teacher or parent can set up a daily routine for you. It will show up here once they do.”"),
                  ("Your day shows here.", "Dito lalabas ang plano ng araw mo.")),
            ]),
            S(T("Say how you feel", "Sabihin ang nararamdaman mo"), [
                L("On Home, find Mood Check-In. On a child’s Home it is called My Feelings.",
                  "Sa Home, hanapin ang Mood Check-In. Sa Home ng bata, Aking Damdamin ang tawag dito."),
                L("Tap the face that shows how you feel.", "I-tap ang mukhang nagpapakita ng nararamdaman mo."),
                L("You can do it again later, any time.", "Maaari mo itong gawin ulit mamaya, kahit kailan."),
            ], numbered=True, pics=[
                P("assets/kids/feelings.webp",
                  ("How Are You Feeling? with six faces to choose from: Happy, Excited, Okay, Tired, Sad and Frustrated.",
                   "How Are You Feeling? na may anim na mukhang pagpipilian: Happy, Excited, Okay, Tired, Sad at Frustrated."),
                  ("Tap a face.", "I-tap ang isang mukha.")),
            ]),
        ],
    },
    {
        "id": "buddy",
        "title": T("Your buddy", "Ang iyong buddy"),
        "summary": T("A friendly helper for learning and practising words.",
                     "Isang mabait na katulong sa pag-aaral at pagsasanay ng mga salita."),
        "sections": [
            S(T("Learn with your buddy", "Matuto kasama ang iyong buddy"), [
                L("Tap the round buddy button at the bottom of the screen. On a child’s Home you can also tap Buddy.",
                  "I-tap ang bilog na buddy button sa ibaba ng screen. Sa Home ng bata, maaari ring i-tap ang Kaibigan."),
                L("If it asks, pick a topic you love, like Animals.",
                  "Kapag nagtanong ito, pumili ng paksang gusto mo, gaya ng Animals."),
                L("Tap Lesson, Quiz or Practice to learn together.",
                  "I-tap ang Aralin, Pagsusulit o Pagsasanay para matuto nang magkasama."),
                L("Tap Listen to hear what it says. You can also type a question.",
                  "I-tap ang Pakinggan para marinig ang sinasabi nito. Maaari ka ring mag-type ng tanong."),
            ], numbered=True, pics=[
                P("assets/kids/buddy.webp",
                  ("A child’s Buddy greets Mia and asks which topic she loves. Above are the Lesson, Quiz and Practice buttons; below, topics such as Animals and Colors & Shapes, and a box to type a question.",
                   "Binabati ni Kaibigan si Mia at itinatanong kung anong paksa ang gusto niya. Sa itaas ang mga button na Lesson, Quiz at Practice; sa ibaba, mga paksa gaya ng Animals at Colors & Shapes, at kahon para mag-type ng tanong."),
                  ("A child’s Buddy.", "Ang Kaibigan ng bata.")),
            ]),
            S(T("Good to know", "Magandang malaman"), [
                L("For students it is a robot, the AI Tutor. For children it is a teddy bear called Buddy.",
                  "Para sa mag-aaral, robot ito na tinatawag na AI Tutor. Para sa bata, teddy bear ito na tinatawag na Kaibigan."),
                L("A child’s Buddy uses short, simple words, and reads its words out loud when speech is on.",
                  "Maiikli at simple ang mga salita ng Kaibigan ng bata, at binabasa nito nang malakas ang mga salita kapag naka-on ang speech."),
            ]),
        ],
    },
    {
        "id": "rewards",
        "title": T("Stars and stickers", "Mga bituin at sticker"),
        "summary": T("See what you have earned and how you are growing.",
                     "Tingnan ang mga nakuha mo at kung paano ka umuunlad."),
        "sections": [
            S(T("What you have earned", "Ang mga nakuha mo"), [
                L("Your level, stars, streak and achievements. On a child’s Home it is My Player Card.",
                  "Ang iyong level, bituin, streak at mga nakamit. Sa Home ng bata, Aking Kard ng Manlalaro ito.",
                  T("Player Profile", "Player Profile")),
                L("The stickers you collect as you learn: Sticker Album. On a child’s Home: Stickers.",
                  "Ang mga sticker na naiipon mo habang natututo: Sticker Album. Sa Home ng bata: Mga Sticker.",
                  T("Stickers", "Mga sticker")),
                L("The words you know, your stars and your week, in the Progress tab.",
                  "Ang mga salitang alam mo, ang iyong mga bituin at ang iyong linggo, sa tab na Progreso.",
                  T("Progress", "Progreso")),
            ], pics=[
                P("assets/kids/stickers.webp",
                  ("The Sticker Album: sticker groups such as Animals, Stars & Sparkles and Badges, with stickers still to collect.",
                   "Ang Sticker Album: mga grupo ng sticker gaya ng Animals, Stars & Sparkles at Badges, at mga sticker na makukuha pa."),
                  ("Your stickers.", "Ang iyong mga sticker.")),
            ]),
            S(T("Tell and write", "Magsabi at magsulat"), [
                L("Tap “How was it?” and answer with a face: Did you have fun? Was it easy? Do you want to use it again?",
                  "I-tap ang “Kumusta ito?” at sumagot gamit ang mukha: Nag-enjoy ka ba? Madali ba? Gusto mo bang gamitin ulit?"),
                L("In My Notebook you can write your own notes.",
                  "Sa Aking Kuwaderno, maaari kang magsulat ng sarili mong mga tala."),
            ]),
        ],
    },
    {
        "id": "supervision",
        "title": T("Supervision and safe use", "Pagbabantay at ligtas na paggamit"),
        "summary": T("Help students and children learn well, and keep their use of the app safe and healthy.",
                     "Tulungan ang mga mag-aaral at bata na matuto nang mabuti, at panatilihing ligtas at malusog ang paggamit nila ng app."),
        "sections": [
            S(T("Before they start", "Bago sila magsimula"), [
                L("Connect them first: a student joins your class and a child joins your home group, each with its code. See For teachers or For parents.",
                  "Ikonekta muna sila: sumasali ang mag-aaral sa iyong klase at ang bata sa iyong home group, bawat isa gamit ang code nito. Tingnan ang Para sa guro o Para sa magulang."),
                L("Set their accessibility needs with them, so the app fits them from the first day.",
                  "Itakda kasama nila ang kanilang mga pangangailangan sa accessibility, para bagay sa kanila ang app mula sa unang araw."),
                L("Read Stay safe together. It is in For Students and Children.",
                  "Basahin ninyo nang magkasama ang Manatiling ligtas. Nasa Para sa Mag-aaral at mga Bata ito."),
            ]),
            S(T("While they learn", "Habang sila ay natututo"), [
                L("Sit with younger learners the first few times, and learn together.",
                  "Samahan ang mas batang mag-aaral sa mga unang beses, at mag-aral nang magkasama."),
                L("Look at their progress together, and talk about what they learned.",
                  "Tingnan nang magkasama ang kanilang progreso, at pag-usapan ang kanilang natutunan."),
            ]),
            S(T("Safe use", "Ligtas na paggamit"), [
                L("Learners message only their contacts. A child’s new friendship starts only after the parent says yes.",
                  "Ang mga kontak lang nila ang mapapadalhan ng mensahe ng mga mag-aaral. Nagsisimula lang ang bagong pakikipagkaibigan ng bata kapag pumayag ang magulang."),
                L("A learner’s report in Messages reaches their teacher or parent.",
                  "Nakakarating sa kanilang guro o magulang ang ulat ng mag-aaral sa Mga Mensahe."),
                L("Time limits, break reminders, alarms and routines: see Time limits, breaks and routines.",
                  "Time limits, paalala sa pahinga, alarma at routine: tingnan ang Time limits, breaks and routines."),
            ], pics=[
                P("assets/features/time-limits.webp",
                  ("Time limits for a learner, as a parent or teacher sets them.",
                   "Ang time limits ng mag-aaral, gaya ng itinatakda ng magulang o guro."),
                  ("Time limits.", "Time limits.")),
            ]),
        ],
        "more": [("#g-timeBreaks", T("Time limits, breaks and routines, step by step", "Time limits, pahinga at routine, hakbang-hakbang")),
                 ("privacy.html", T("Privacy & data: what the app keeps, and who sees it", "Privacy at datos: ano ang itinatago ng app, at sino ang nakakakita"))],
    },
]
