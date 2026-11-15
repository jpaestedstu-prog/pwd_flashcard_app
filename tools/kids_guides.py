"""The "For children" guides on website/guides.html — written for this website, in short,
simple sentences, for a child to read with a grown-up.

The app's own twelve guides come from lib/features/help/models/guides.dart, word for word.
These do not: the app has no guide written for children. Every step here was checked
against the app (1.4.6) — the Child home (lib/features/home/screens/child_home_screen.dart),
the join and set-up screens, the tab bar, the strings in lib/l10n/app_*.arb — and the names
in quotes are the ones the app shows, in English and in Filipino. Where a line repeats one of
the app's own guides, it uses that guide's words.

Each guide has the same shape as the app's guides (title, summary, sections of lines,
numbered where they are steps), so tools/guides_page_build.py renders it the same way, with
"Read aloud". `pics` are pictures of the app's Child screens (integration_test/
site_pictures_test.dart, offline, sample child "Mia"), made by tools/site_pictures_build.py.
"""


def T(en, fil):
    return {"en": en, "fil": fil}


def L(en, fil, label=None):
    return {"label": label, "text": T(en, fil)}


def S(heading, lines, numbered=False):
    return {"heading": heading, "lines": lines, "numbered": numbered}


def P(src, alt, caption):
    """A picture: src under website/, alt text and caption as (en, fil)."""
    return {"src": src, "alt": T(*alt), "caption": T(*caption)}


# Who these guides are for, on the "Find your guide" panel.
NOTE = T("Simple guides with pictures, for children to read with a parent or teacher. "
         "Tap a guide to open it.",
         "Mga simpleng gabay na may larawan, para basahin ng bata kasama ang magulang o guro. "
         "I-tap ang gabay para buksan.")

# Website look per guide: emoji and tile tone (site.css .tone-*).
LOOK = {
    "kids-start": ("👋", "orange"),
    "kids-words": ("🔤", "purple"),
    "kids-games": ("🎮", "pink"),
    "kids-stories": ("📖", "indigo"),
    "kids-talk": ("💬", "teal"),
    "kids-day": ("🗓️", "green"),
    "kids-buddy": ("🧸", "gold"),
    "kids-rewards": ("⭐", "magenta"),
    "kids-rest": ("😴", "blue"),
    "kids-safe": ("🛡️", "red"),
    "kids-grownups": ("🤝", "indigo"),
}

GUIDES = [
    {
        "id": "kids-start",
        "title": T("Hello! Start here", "Kumusta! Dito magsimula"),
        "summary": T("Join your family in the app, and find your way around.",
                     "Sumali sa iyong pamilya sa app, at alamin ang daan."),
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
            ], numbered=True),
            S(T("Your Home", "Ang iyong Home"), [
                L("Home says hello to you by name.", "Binabati ka ng Home gamit ang iyong pangalan."),
                L("At the top are your Streak, Words and Stars.",
                  "Sa itaas ang iyong Sunod-sunod, Mga Salita at Mga Bituin."),
                L("Scroll down for big buttons: Play & Learn, Explore & Create, Friends, and Rewards & Feelings.",
                  "Mag-scroll pababa para sa malalaking button: Maglaro at Matuto, Tuklasin at Lumikha, Mga Kaibigan, at Gantimpala at Damdamin."),
                L("The tabs at the bottom are Home, Cards, Games, Stories and Progress.",
                  "Ang mga tab sa ibaba ay Home, Mga Kard, Mga Laro, Mga Kwento at Progreso."),
                L("Tap a tab to open it. The back arrow at the top takes you back.",
                  "I-tap ang tab para buksan. Ang back arrow sa itaas ay pabalik."),
            ]),
        ],
        "pics": [
            P("assets/kids/join.webp",
              ("The Join Home Group screen: “Enter the code your parent or guardian shared.”, a box for the home-group code, and a Join group button.",
               "Ang screen na Join Home Group: “Enter the code your parent or guardian shared.”, isang kahon para sa code, at button na Join group."),
              ("Type your parent’s code here.", "Dito i-type ang code ng iyong magulang.")),
            P("assets/kids/home.webp",
              ("A child’s Home: “Hi, Mia!”, the Streak, Words and Stars, the My Day and My Feelings cards, and the first big buttons of Play & Learn: Games, Cards, Stories and more.",
               "Ang Home ng bata: “Hi, Mia!”, ang Streak, Words at Stars, ang mga card na My Day at My Feelings, at ang unang malalaking button ng Play & Learn: Games, Cards, Stories at iba pa."),
              ("Your Home.", "Ang iyong Home.")),
        ],
        "more": [("how-to-use.html", T("The App Tour, with pictures and a short video",
                                      "Ang Tour ng App, may larawan at maikling video"))],
    },
    {
        "id": "kids-words",
        "title": T("Learn new words", "Matuto ng bagong salita"),
        "summary": T("Look, listen and see the sign on flashcards.",
                     "Tumingin, makinig at tingnan ang senyas sa flashcards."),
        "sections": [
            S(T("Use the cards", "Gamitin ang cards"), [
                L("Tap Cards.", "I-tap ang Mga Kard."),
                L("Choose a deck, like Animals.", "Pumili ng deck, gaya ng Animals."),
                L("Look at the picture and the word. Tap the card to flip it and see more.",
                  "Tingnan ang larawan at ang salita. I-tap ang card para baligtarin at makita ang iba pa."),
                L("Tap English or Filipino to hear the word.",
                  "I-tap ang English o Filipino para marinig ang salita."),
                L("Tap FSL to watch the sign.", "I-tap ang FSL para makita ang senyas."),
                L("Tap Next for the next card.", "I-tap ang Next para sa susunod na card."),
            ], numbered=True),
            S(T("More ways to practise", "Iba pang paraan ng pagsasanay"), [
                L("Go over the words you learned before.", "Balikan ang mga salitang natutunan mo na.",
                  T("Practice Words", "Sanayin ang mga Salita")),
                L("Practise the signs you have already seen.", "Sanayin ang mga senyas na nakita mo na.",
                  T("Sign Language", "Wikang Senyas")),
                L("Find a word and watch its sign.", "Hanapin ang salita at panoorin ang senyas nito.",
                  T("Sign Dictionary", "Diksyunaryo ng Senyas")),
                L("One word at a time: look, listen, say it, then type it.",
                  "Isang salita bawat beses: tingnan, pakinggan, sabihin, saka i-type.",
                  T("Practice With Me", "Magsanay Kasama Ko")),
            ]),
        ],
        "pics": [
            P("assets/kids/card.webp",
              ("A flashcard of a puppy with the word Dog and Aso, English and Filipino sound buttons, and FSL, Show Me, Flip and Next below.",
               "Flashcard ng tuta na may salitang Dog at Aso, mga button ng tunog na English at Filipino, at FSL, Show Me, Flip at Next sa ibaba."),
              ("A card: tap English or Filipino to hear it.", "Isang card: i-tap ang English o Filipino para marinig.")),
        ],
        "more": [("fsl-dictionary.html", T("The FSL Dictionary on this website", "Ang Diksyunaryo ng FSL sa website na ito"))],
    },
    {
        "id": "kids-games",
        "title": T("Play games", "Maglaro"),
        "summary": T("Play learning games, alone or with a friend.",
                     "Maglaro ng mga larong pampagkatuto, mag-isa o kasama ang kaibigan."),
        "sections": [
            S(T("Play a game", "Maglaro"), [
                L("Tap Games.", "I-tap ang Mga Laro."),
                L("Choose a game, like Word Match.", "Pumili ng laro, gaya ng Word Match."),
                L("Follow the picture and words on the screen.", "Sundin ang larawan at salita sa screen."),
                L("Do your best. You get stars as you play and learn.",
                  "Gawin ang makakaya mo. Nakakakuha ka ng bituin habang naglalaro at natututo."),
            ], numbered=True),
            S(T("Play with a friend", "Maglaro kasama ang kaibigan"), [
                L("Race a friend, just for fun.", "Makipagkarera sa kaibigan, para lang sa saya.",
                  T("Play Together", "Maglaro Nang Sabay")),
                L("You and a friend are one team. You score together.",
                  "Isang koponan kayo ng kaibigan mo. Magkasama kayong nagpupuntos.",
                  T("Peer Collab", "Magtulungan")),
                L("Finish each path to open the next one.", "Tapusin ang bawat landas para mabuksan ang susunod.",
                  T("Adventure Map", "Mapa ng Pakikipagsapalaran")),
            ]),
        ],
        "pics": [
            P("assets/kids/games.webp",
              ("The Games screen: a Play Together banner, a note that 10 games are picked for this child, and game cards such as Word Match, Spelling Bee and Memory Match.",
               "Ang screen ng Games: banner na Play Together, paalalang 10 laro ang pinili para sa batang ito, at mga card ng laro gaya ng Word Match, Spelling Bee at Memory Match."),
              ("Choose a game.", "Pumili ng laro.")),
        ],
        "more": [("games.html", T("Every game in the app", "Bawat laro sa app"))],
    },
    {
        "id": "kids-stories",
        "title": T("Read stories", "Magbasa ng kuwento"),
        "summary": T("Read short stories, hear them and answer questions.",
                     "Magbasa ng maiikling kuwento, pakinggan, at sagutin ang mga tanong."),
        "sections": [
            S(T("Read a story", "Magbasa ng kuwento"), [
                L("Tap Stories.", "I-tap ang Mga Kwento."),
                L("Choose a story.", "Pumili ng kuwento."),
                L("Read it. You can also hear it read aloud.",
                  "Basahin ito. Maaari mo rin itong marinig na binabasa."),
                L("Answer the questions at the end.", "Sagutin ang mga tanong sa dulo."),
            ], numbered=True),
            S(T("Good to know", "Magandang malaman"), [
                L("A story with a lock opens when you know more words.",
                  "Bubukas ang kuwentong may kandado kapag mas marami ka nang alam na salita."),
            ]),
        ],
        "pics": [
            P("assets/kids/stories.webp",
              ("The Stories screen with story cards, such as A Day at the Farm, and locked stories to open later.",
               "Ang screen ng Stories na may mga kuwento, gaya ng A Day at the Farm, at mga kuwentong naka-lock na bubukas mamaya."),
              ("Choose a story.", "Pumili ng kuwento.")),
        ],
    },
    {
        "id": "kids-talk",
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
            ], numbered=True),
        ],
        "pics": [
            P("assets/kids/talk.webp",
              ("The Talk Board: the sentence Hello, Good morning at the top, groups such as Greetings, Needs and Feelings, and picture tiles such as Hello, Goodbye, Thank you and Please.",
               "Ang Talk Board: ang pangungusap na Hello, Good morning sa itaas, mga grupo gaya ng Greetings, Needs at Feelings, at mga larawan gaya ng Hello, Goodbye, Thank you at Please."),
              ("Tap pictures to make a sentence.", "Pindutin ang mga larawan para bumuo ng pangungusap.")),
        ],
        "more": [("features.html#f-talkboard", T("The Talk Board in Features in Action", "Ang Talk Board sa Tingnan ang mga Feature"))],
    },
    {
        "id": "kids-day",
        "title": T("My Day and My Feelings", "Ang Aking Araw at Aking Damdamin"),
        "summary": T("See what comes next today, and say how you feel.",
                     "Tingnan ang susunod na gagawin ngayon, at sabihin ang nararamdaman mo."),
        "sections": [
            S(T("My Day", "Ang Aking Araw"), [
                L("My Day shows your day’s steps, like class, homework and rest.",
                  "Ipinapakita ng My Day ang mga gagawin mo, gaya ng klase, assignment at pahinga."),
                L("Each step has a picture and a time.", "May larawan at oras ang bawat hakbang."),
                L("Your parent or teacher sets up My Day for you. It shows here when they do.",
                  "Ang iyong magulang o guro ang gumagawa ng My Day para sa iyo. Lalabas ito rito kapag nagawa na nila."),
            ]),
            S(T("My Feelings", "Aking Damdamin"), [
                L("On Home, find My Feelings.", "Sa Home, hanapin ang Aking Damdamin."),
                L("Tap the face that shows how you feel.", "I-tap ang mukhang nagpapakita ng nararamdaman mo."),
                L("You can do it again later, any time.", "Maaari mo itong gawin ulit mamaya, kahit kailan."),
            ], numbered=True),
        ],
        "pics": [
            P("assets/kids/my-day.webp",
              ("My Day before it is set up: “No routine yet. Your teacher or parent can set up a daily routine for you. It will show up here once they do.”",
               "Ang My Day bago ito gawin: “No routine yet. Your teacher or parent can set up a daily routine for you. It will show up here once they do.”"),
              ("Your day shows here.", "Dito lalabas ang plano ng araw mo.")),
            P("assets/kids/feelings.webp",
              ("How Are You Feeling? with six faces to choose from: Happy, Excited, Okay, Tired, Sad and Frustrated.",
               "How Are You Feeling? na may anim na mukhang pagpipilian: Happy, Excited, Okay, Tired, Sad at Frustrated."),
              ("Tap a face.", "I-tap ang isang mukha.")),
        ],
    },
    {
        "id": "kids-buddy",
        "title": T("Your Buddy", "Ang iyong Kaibigan"),
        "summary": T("A friendly helper for learning and practising words.",
                     "Isang mabait na katulong sa pag-aaral at pagsasanay ng mga salita."),
        "sections": [
            S(T("Learn with Buddy", "Matuto kasama si Kaibigan"), [
                L("On Home, tap Buddy. Or tap the round teddy-bear button at the bottom of the screen.",
                  "Sa Home, i-tap ang Kaibigan. O i-tap ang bilog na button na may teddy bear sa ibaba ng screen."),
                L("Pick a topic you love, like Animals.", "Pumili ng paksang gusto mo, gaya ng Animals."),
                L("Tap Lesson, Quiz or Practice to learn with Buddy.",
                  "I-tap ang Aralin, Pagsusulit o Pagsasanay para matuto kasama si Kaibigan."),
                L("Tap Listen to hear what Buddy says. You can also type a question.",
                  "I-tap ang Pakinggan para marinig ang sinasabi ni Kaibigan. Maaari ka ring mag-type ng tanong."),
            ], numbered=True),
            S(T("Good to know", "Magandang malaman"), [
                L("Buddy uses short, simple words.", "Maiikli at simple ang mga salita ni Kaibigan."),
                L("When speech is on, Buddy reads its words out loud by itself.",
                  "Kapag naka-on ang speech, kusang binabasa ni Kaibigan nang malakas ang mga salita nito."),
            ]),
        ],
        "pics": [
            P("assets/kids/buddy.webp",
              ("Buddy greets Mia and asks which topic she loves. Above are the Lesson, Quiz and Practice buttons; below, topics such as Animals and Colors & Shapes, and a box to type a question.",
               "Binabati ni Kaibigan si Mia at itinatanong kung anong paksa ang gusto niya. Sa itaas ang mga button na Lesson, Quiz at Practice; sa ibaba, mga paksa gaya ng Animals at Colors & Shapes, at kahon para mag-type ng tanong."),
              ("Buddy says hello.", "Bumabati si Kaibigan.")),
        ],
    },
    {
        "id": "kids-rewards",
        "title": T("Stars, stickers and more", "Bituin, sticker at iba pa"),
        "summary": T("See what you have earned and how you are growing.",
                     "Tingnan ang mga nakuha mo at kung paano ka umuunlad."),
        "sections": [
            S(T("Rewards & Feelings", "Gantimpala at Damdamin"), [
                L("Your level, stars, streak and achievements.", "Ang iyong level, bituin, streak at mga nakamit.",
                  T("My Player Card", "Aking Kard ng Manlalaro")),
                L("The stickers you collect as you learn.", "Ang mga sticker na naiipon mo habang natututo.",
                  T("Stickers", "Mga Sticker")),
                L("Tap “How was it?” and answer with a face: Did you have fun? Was it easy? Do you want to use it again?",
                  "I-tap ang “Kumusta ito?” at sumagot gamit ang mukha: Nag-enjoy ka ba? Madali ba? Gusto mo bang gamitin ulit?"),
                L("Write your own notes.", "Isulat ang sarili mong mga tala.",
                  T("My Notebook", "Aking Kuwaderno")),
                L("The words you know and your stars.", "Ang mga salitang alam mo at ang iyong mga bituin.",
                  T("My Progress", "Aking Progreso")),
            ]),
        ],
        "pics": [
            P("assets/kids/rewards.webp",
              ("The bottom of a child’s Home: the Friends buttons (Play Together, Peer Collab, Messages, My Notes) and the Rewards & Feelings buttons (My Player Card, Stickers, How was it?, My Notebook).",
               "Ang ibaba ng Home ng bata: ang mga button ng Friends (Play Together, Peer Collab, Messages, My Notes) at ng Rewards & Feelings (My Player Card, Stickers, How was it?, My Notebook)."),
              ("Friends, and Rewards & Feelings.", "Mga Kaibigan, at Gantimpala at Damdamin.")),
            P("assets/kids/stickers.webp",
              ("The Sticker Album: sticker groups such as Animals, Stars & Sparkles and Badges, with stickers still to collect.",
               "Ang Sticker Album: mga grupo ng sticker gaya ng Animals, Stars & Sparkles at Badges, at mga sticker na makukuha pa."),
              ("Your stickers.", "Ang iyong mga sticker.")),
        ],
    },
    {
        "id": "kids-rest",
        "title": T("Rest and screen time", "Pahinga at oras sa screen"),
        "summary": T("Take breaks, and know what happens when your time is up.",
                     "Magpahinga, at alamin ang nangyayari kapag tapos na ang iyong oras."),
        "sections": [
            S(T("Take a break", "Magpahinga"), [
                L("Tired? Tap “I Need a Break” in a lesson or game. You come back to the same place after.",
                  "Pagod? I-tap ang “I Need a Break” sa aralin o laro. Babalik ka sa parehong lugar pagkatapos."),
                L("Your teacher or parent may set break reminders. When one appears, choose “Take a break” or “Keep learning”.",
                  "Maaaring maglagay ang guro o magulang ng paalala sa pahinga. Kapag lumabas ito, piliin ang “Magpahinga” o “Magpatuloy sa pag-aaral”."),
            ]),
            S(T("When your time is up", "Kapag tapos na ang oras"), [
                L("The tablet tells you: with a sound and words, or with a sign and a picture.",
                  "Sasabihin ito ng tablet: may tunog at salita, o may senyas at larawan."),
                L("Then it shows who to give the tablet to, like your parent or teacher.",
                  "Saka nito ipapakita kung kanino mo ibibigay ang tablet, gaya ng iyong magulang o guro."),
                L("If the screen is locked, ask your parent to unlock it.",
                  "Kapag naka-lock ang screen, hilingin sa magulang na i-unlock ito."),
            ]),
        ],
        "pics": [
            P("assets/features/break-learner.webp",
              ("The break reminder: Time for a short break, with the buttons Take a break and Keep learning.",
               "Ang paalala sa pahinga: Oras na para sa maikling pahinga, may mga button na Magpahinga at Magpatuloy sa pag-aaral."),
              ("A break reminder.", "Isang paalala sa pahinga.")),
        ],
    },
    {
        "id": "kids-safe",
        "title": T("Stay safe", "Manatiling ligtas"),
        "summary": T("Simple rules to keep you safe and happy.",
                     "Mga simpleng tuntunin para manatili kang ligtas at masaya."),
        "sections": [
            S(T("In the app", "Sa app"), [
                L("Keep your PIN a secret. Only you and your parent should know it.",
                  "Ilihim ang iyong PIN. Ikaw at ang iyong magulang lang ang dapat makaalam nito."),
                L("In Messages, you write to your parent, and to friends your parent said yes to.",
                  "Sa Mga Mensahe, sumusulat ka sa iyong magulang, at sa mga kaibigang pinayagan ng iyong magulang."),
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
        ],
        "pics": [],
        "more": [("privacy.html", T("Privacy & data: what the app keeps", "Privacy at datos: ano ang itinatago ng app"))],
    },
    {
        "id": "kids-grownups",
        "title": T("For parents and teachers", "Para sa magulang at guro"),
        "summary": T("Set up a child’s profile, and help them learn on their own.",
                     "I-set up ang profile ng bata, at tulungan siyang matuto nang mag-isa."),
        "sections": [
            S(T("Set up your child", "I-set up ang iyong anak"), [
                L("On your Parent profile’s Home, open Manage Groups and create a home group.",
                  "Sa Home ng iyong Parent profile, buksan ang Manage Groups at gumawa ng home group."),
                L("Use Invite your child to get the code.", "Gamitin ang Invite your child para makuha ang code."),
                L("On your child’s profile, choose “Child Profile (PWD)”, type the code, then add a name, picture and birthday.",
                  "Sa profile ng iyong anak, piliin ang “Profile ng Bata (PWD)”, i-type ang code, saka ilagay ang pangalan, larawan at kaarawan."),
            ], numbered=True),
            S(T("What you can do", "Ang maaari mong gawin"), [
                L("In Manage Groups, press ⋯ beside your child for View progress, Time limits, Alarms, Routine, Accessibility needs and Unlock screen.",
                  "Sa Manage Groups, pindutin ang ⋯ sa tabi ng anak para sa View progress, Time limits, Alarms, Routine, Accessibility needs at Unlock screen."),
                L("A friendship with your child starts only after you say yes.",
                  "Nagsisimula lang ang pakikipagkaibigan ng iyong anak kapag pumayag ka."),
                L("You can give your child work, the way a teacher does. It shows on their Home as Assignments.",
                  "Maaari kang magbigay ng gawain sa iyong anak, gaya ng ginagawa ng guro. Lalabas ito sa kanyang Home bilang Mga Takdang Gawain."),
            ]),
            S(T("Tips", "Mga tip"), [
                L("Sit with your child the first few times, and learn together.",
                  "Samahan ang iyong anak sa mga unang beses, at mag-aral nang magkasama."),
                L("Turn on only the help your child needs. Too many helpers at once can confuse.",
                  "I-on lang ang tulong na kailangan ng anak. Nakakalito ang sobrang dami nang sabay."),
                L("Use short sessions and break reminders. Praise effort, not only right answers.",
                  "Gumamit ng maikling sesyon at paalala sa pahinga. Purihin ang pagsisikap, hindi lang ang tamang sagot."),
            ]),
        ],
        "pics": [
            P("assets/features/time-limits.webp",
              ("Time limits for a learner, as a parent or teacher sets them.",
               "Ang time limits ng mag-aaral, gaya ng itinatakda ng magulang o guro."),
              ("Time limits.", "Time limits.")),
        ],
        "more": [("#g-parents", T("The app’s guide For parents", "Ang gabay ng app Para sa magulang")),
                 ("#g-timeBreaks", T("Time limits and breaks, step by step", "Time limits at pahinga, hakbang-hakbang")),
                 ("teachers-guide.html", T("The printable Teacher’s Guide (for parents too)",
                                           "Ang napi-print na Gabay ng Guro (para rin sa magulang)"))],
    },
]
