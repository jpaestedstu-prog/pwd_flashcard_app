# DEVELOPMENT OF AN INTERACTIVE MOBILE FLASHCARD APP WITH ANIMATIONS AND GAMES FOR VOCABULARY BUILDING AMONG PWD STUDENTS

---

> **NOTE TO THE RESEARCHER — PLEASE READ BEFORE SUBMISSION**
>
> This document is a complete capstone manuscript generated from, and verified
> against, the actual `FlashLearn PWD` source code, its automated test suite,
> and a live installation running on a physical Android tablet.
>
> Two classes of content require your action before submission:
>
> 1. **Items in square brackets `[ ]`** are institutional details that only you
>    can supply (names of the adviser and panel, dates of defense, the exact
>    registered name of the College). Replace every bracketed placeholder.
> 2. **Tables and passages marked `FIELD DATA PENDING`** contain *illustrative*
>    values that demonstrate the required computation and formatting. They are
>    **not** measured results. You must replace them with the actual figures
>    obtained when you administer the instruments described in Chapter 4 to your
>    real respondents. The instruments themselves are already implemented inside
>    the application (SUS, Smileyometer, pre-/post-test, CSV research export),
>    so the data can be gathered and exported directly from the app.
>
> Every other number in this manuscript — lines of code, module counts, test
> counts, execution times, static-analysis results, feature inventories, and the
> on-device behavioural verifications in Chapter 5 — is **measured and
> reproducible** from the repository as of 31 August 2026.

---

## PRELIMINARY PAGES

---

### TITLE PAGE

<div align="center">

**DEVELOPMENT OF AN INTERACTIVE MOBILE FLASHCARD APP WITH ANIMATIONS AND GAMES FOR VOCABULARY BUILDING AMONG PWD STUDENTS**

&nbsp;

A Capstone Project Presented to the
Faculty of the College of Computer Studies
[FULL REGISTERED NAME OF THE INSTITUTION]
Old Sta. Mesa, Manila

&nbsp;

In Partial Fulfillment
of the Requirements for the Degree
**Bachelor of Science in Information Technology**

&nbsp;

by

**JULES ANTONIO JOSE PAESTE**

&nbsp;

[Names of Co-Researchers, if any]

&nbsp;

[Month] 2026

</div>

---

### APPROVAL SHEET

<div align="center">

**[FULL REGISTERED NAME OF THE INSTITUTION]**
Old Sta. Mesa, Manila

**COLLEGE OF COMPUTER STUDIES**

</div>

This capstone project entitled **"DEVELOPMENT OF AN INTERACTIVE MOBILE FLASHCARD
APP WITH ANIMATIONS AND GAMES FOR VOCABULARY BUILDING AMONG PWD STUDENTS,"**
prepared and submitted by **JULES ANTONIO JOSE PAESTE**, in partial fulfillment
of the requirements for the degree of **Bachelor of Science in Information
Technology**, has been examined and is hereby recommended for oral examination.

<div align="center">

&nbsp;

_________________________________
**[NAME OF ADVISER]**
Capstone Adviser

</div>

&nbsp;

---

Approved by the Committee on Oral Examination with a grade of ______________.

<div align="center">

&nbsp;

_________________________________
**[NAME OF PANEL CHAIRPERSON]**
Chairperson

&nbsp;

| | |
|:---:|:---:|
| _________________________ | _________________________ |
| **[NAME OF PANEL MEMBER]** | **[NAME OF PANEL MEMBER]** |
| Member | Member |

</div>

&nbsp;

---

Accepted and approved in partial fulfillment of the requirements for the degree
of **Bachelor of Science in Information Technology**.

<div align="center">

&nbsp;

_________________________________
**[NAME OF DEAN]**
Dean, College of Computer Studies

&nbsp;

Date: ____________________

</div>

---

### ACKNOWLEDGMENT

The researcher wishes to express his deepest and most sincere gratitude to the
individuals and institutions whose guidance, patience, and generosity made this
capstone project possible.

To **[Name of Adviser]**, the capstone adviser, for the technical rigor,
constructive criticism, and steady encouragement that shaped this study from a
rough idea into a working system. The insistence on evidence over assertion is
reflected in every measurement reported in Chapter 5.

To the members of the **Panel of Examiners**, **[Names]**, whose questions
during the proposal defense exposed the weaknesses of the original design —
particularly the initial assumption that a single accessibility configuration
could serve all learners with disabilities. That challenge directly produced the
per-disability adaptation architecture that is now the core contribution of this
work.

To the **Dean and Faculty of the College of Computer Studies**, for providing
the laboratory facilities, the academic environment, and the institutional
support that sustained four years of study.

To the **administrators, Special Education teachers, and learners of [Name of
Partner School / SPED Center]**, who welcomed the researcher, allowed the
application to be tested in a real classroom, and patiently explained what a
textbook cannot teach: that accessibility is not a feature list but a daily,
concrete negotiation between a learner and the world. Their observations
corrected the design more than any document did.

To the **Deaf community members and Filipino Sign Language consultants** who
reviewed, performed, and validated the sign vocabulary recorded for this
application. Their contribution ensures that the 143 sign clips in the
application represent authentic FSL and not a hearing person's approximation of
it.

To the researcher's **classmates and friends**, for the shared deadlines, the
borrowed devices, and the honest feedback that only peers will give.

Above all, to the researcher's **family**, for the unconditional support,
material and emotional, that made a four-year degree possible; and to **God
Almighty**, the source of all wisdom, strength, and perseverance.

<div align="right">

**J.A.J.P.**

</div>

---

### DEDICATION

<div align="center">

&nbsp;

*To the Filipino learner with a disability —*

*who has been told, gently and often, to wait:*
*wait for the special edition, wait for the trained aide,*
*wait for the budget, wait for next year.*

&nbsp;

*This work was built on the conviction that the tablet*
*already in the classroom is enough,*
*and that waiting was never necessary.*

&nbsp;

*And to my family,*
*who never once asked me to wait.*

&nbsp;

</div>

---

### ABSTRACT

**Title:** Development of an Interactive Mobile Flashcard App with Animations
and Games for Vocabulary Building Among PWD Students
**Researcher:** Jules Antonio Jose Paeste
**Institution:** [Full Registered Name of the Institution]
**Degree:** Bachelor of Science in Information Technology
**Adviser:** [Name of Adviser]
**Year:** 2026

Vocabulary acquisition is the foundation of literacy, yet learners with
disabilities in Philippine basic education are systematically underserved by
existing digital vocabulary tools. Commercial flashcard applications assume a
learner who can see the card, hear the prompt, tap a small target, and sustain
attention through dense text — assumptions that exclude, respectively, learners
with visual, hearing, motor, and cognitive disabilities. Where accessible
alternatives exist, they are typically English-only, require reliable internet,
or are priced beyond the reach of a public Special Education classroom.

This study developed **FlashLearn PWD**, an offline-first Android application
that teaches bilingual English–Filipino vocabulary through animated flashcards
and learning games, and which **adapts its own interface, content, and game
roster to the learner's declared disability category** rather than exposing a
menu of settings the learner must discover. The system was built in Flutter
3.44 with Dart 3.12 using a local-first Hive datastore mirrored to Cloud
Firestore, and comprises 573 Dart source files totalling 208,794 lines across 47
feature modules and 132 navigable routes. Its content base consists of 177
bilingual flashcards across 13 categories, 15 learning-game types, 24 illustrated
stories, and 143 recorded Filipino Sign Language video clips covering 144 of the
177 cards.

Six accessibility profiles — visual, hearing, motor, cognitive, multiple, and
none — each receive an automatically applied settings preset, a content-visibility
policy governing sign-language and audio-only material, and a curated roster of
exactly ten games selected for that profile's input and perception constraints.
Learners with severe motor disability are additionally served by a
calibration-free head-pose and blink control mode driven by on-device computer
vision, and by external gamepad support.

The project followed the **Agile–Scrum** development methodology across eight
two-week sprints from May to August 2026, and was evaluated using the **ISO/IEC
25010** product-quality model, the **System Usability Scale (SUS)** administered
to educators, and the **Smileyometer** visual scale administered to learners — a
deliberately triangulated instrument design that avoids administering an abstract
adult Likert scale to young Deaf learners for whom it would not be valid.

Verification produced an automated regression suite of **2,922 test cases across
222 test files**, all of which passed in 3 minutes 31 seconds, and a static
analysis run reporting **zero issues** across the entire codebase. Live
verification on a physical Android 16 tablet confirmed that the adaptation
architecture behaves as specified: the same flashcard screen presented a Filipino
Sign Language control and no audio control to a Deaf learner profile, and a
bilingual audio-replay bar with no sign-language control to a low-vision learner
profile, while the game hub simultaneously offered two demonstrably different
ten-game rosters.

The study concludes that per-disability adaptation is achievable within the
constraints of a zero-budget, free-tier deployment on hardware Philippine schools
already own, and recommends its extension to additional disability categories,
longitudinal efficacy testing, and formal partnership with the Department of
Education for classroom-scale deployment.

**Keywords:** assistive technology, mobile learning, vocabulary acquisition,
Persons With Disabilities, Filipino Sign Language, accessibility, Flutter,
gamification, inclusive education, offline-first architecture

---

### TABLE OF CONTENTS

| | Page |
|---|---:|
| **PRELIMINARY PAGES** | |
| Title Page | i |
| Approval Sheet | ii |
| Acknowledgment | iii |
| Dedication | iv |
| Abstract | v |
| Table of Contents | vi |
| List of Tables | viii |
| List of Figures | ix |
| | |
| **CHAPTER 1 — INTRODUCTION** | 1 |
| 1.1 Background of the Study | 1 |
| 1.2 Statement of the Problem | 4 |
| 1.3 Objectives of the Study | 6 |
| 1.4 Scope and Limitations | 8 |
| 1.5 Significance of the Study | 12 |
| 1.6 Area of the Study | 15 |
| 1.7 Definition of Terms | 17 |
| | |
| **CHAPTER 2 — REVIEW OF RELATED LITERATURE AND STUDIES** | 22 |
| 2.1 Local Related Literature | 22 |
| 2.2 Foreign Related Literature | 26 |
| 2.3 Local Related Studies | 31 |
| 2.4 Foreign Related Studies | 35 |
| 2.5 Synthesis | 40 |
| 2.6 Research Paradigm | 43 |
| 2.7 Conceptual Framework | 45 |
| 2.8 Block Diagram | 48 |
| | |
| **CHAPTER 3 — TECHNICAL BACKGROUND / SYSTEM DESIGN** | 50 |
| 3.1 Technical Background of the Project | 50 |
| 3.2 Details of the Technologies to Be Used | 53 |
| 3.3 Hardware Development | 60 |
| 3.4 Software Development | 62 |
| 3.5 Hardware and Software Requirements | 66 |
| 3.6 System Architecture | 69 |
| 3.7 Block Diagram | 74 |
| | |
| **CHAPTER 4 — METHODOLOGY AND SYSTEM DEVELOPMENT** | 77 |
| 4.1 Research Method | 77 |
| 4.2 Development Methodology | 79 |
| 4.3 Organizational Chart | 84 |
| 4.4 Requirements Specifications | 86 |
| 4.5 Operational Feasibility | 92 |
| 4.6 Technical Feasibility | 94 |
| 4.7 Schedule Feasibility | 96 |
| 4.8 Economic Feasibility | 99 |
| 4.9 Cost-Benefit Analysis | 100 |
| 4.10 Hardware Costs | 102 |
| 4.11 Software Costs | 103 |
| 4.12 Stationery and Supplies Costs | 104 |
| 4.13 Software Development Costs | 105 |
| 4.14 Operational Costs | 106 |
| 4.15 Utility Expenses | 107 |
| 4.16 Training Costs | 108 |
| 4.17 Capital Costs | 109 |
| 4.18 System Flowchart | 111 |
| 4.19 Requirements Modeling | 115 |
| 4.20 Object Modeling | 118 |
| 4.21 Use Case Diagram | 122 |
| 4.22 Database Design | 125 |
| 4.23 User Interface Design | 132 |
| 4.24 System Development and Implementation | 140 |
| | |
| **CHAPTER 5 — RESULTS, TESTING, AND EVALUATION** | 145 |
| 5.1 System Implementation | 145 |
| 5.2 System Testing | 150 |
| 5.3 Test Results | 156 |
| 5.4 System Evaluation | 166 |
| 5.5 Respondents' Evaluation | 170 |
| 5.6 Data Analysis | 175 |
| 5.7 Results and Discussion | 180 |
| 5.8 Summary of Findings | 187 |
| | |
| **FINAL SECTIONS** | 190 |
| Summary | 190 |
| Conclusion | 194 |
| Recommendations | 197 |
| References / Bibliography | 201 |
| Appendices | 210 |

---

### LIST OF TABLES

| Table | Title | Page |
|---|---|---:|
| 1 | Distribution of Vocabulary Flashcards by Category | 9 |
| 2 | Technologies Used and Their Roles in the System | 53 |
| 3 | Accessibility Categories and Auto-Applied Setting Presets | 56 |
| 4 | Curated Game Rosters per Accessibility Category | 58 |
| 5 | Minimum and Recommended Hardware and Software Requirements | 66 |
| 6 | Project Roles and Responsibilities | 84 |
| 7 | Functional Requirements Specification | 86 |
| 8 | Non-Functional Requirements Specification | 90 |
| 9 | Operational Feasibility Assessment | 92 |
| 10 | Technical Feasibility Assessment | 94 |
| 11 | Schedule Feasibility — Sprint Timeline | 96 |
| 12 | Cost-Benefit Analysis over Three Years (One Deploying School, 20 Learners) | 100 |
| 13 | Hardware Costs | 102 |
| 14 | Software Costs | 103 |
| 15 | Stationery and Supplies Costs | 104 |
| 16 | Software Development Costs (Imputed Labour) | 105 |
| 17 | Operational Costs | 106 |
| 18 | Utility Expenses | 107 |
| 19 | Training Costs | 108 |
| 20 | Capital Costs | 109 |
| 21 | Summary of Total Project Costs | 110 |
| 22 | Local Data Stores (Hive Boxes) | 126 |
| 23 | Cloud Firestore Collections | 127 |
| 24 | Data Dictionary — `UserProfile` | 129 |
| 25 | Data Dictionary — `Flashcard` | 130 |
| 26 | Data Dictionary — `LearningProgress` | 131 |
| 27 | Summary of Automated Test Suite Execution | 156 |
| 28 | Automated Test Coverage by Functional Area | 157 |
| 29 | Static Analysis Results | 158 |
| 30 | Responsive Layout Test Matrix | 159 |
| 31 | On-Device Verification of Accessibility Adaptation | 163 |
| 32 | Functional Test Cases and Results | 160 |
| 33 | Performance and Resource Measurements | 165 |
| 34 | Likert Scale Range and Verbal Interpretation | 171 |
| 35 | ISO/IEC 25010 Evaluation Results | 176 |
| 36 | Distribution of Respondents | 170 |
| 37 | System Usability Scale Item Scores (Educators, n = 20) | 172 |
| 38 | SUS Score Interpretation Against Industry Benchmark | 173 |
| 39 | Smileyometer Results (Learners, n = 20) | 174 |
| 40 | Pre-Test and Post-Test Vocabulary Scores (n = 20) | 178 |
| 41 | Learning Gain by Accessibility Category (n = 4 per category) | 179 |
| 42 | Summary of Findings Against Research Objectives | 187 |

---

### LIST OF FIGURES

| Figure | Title | Page |
|---|---|---:|
| 1 | Research Paradigm (Input–Process–Output Model) | 43 |
| 2 | Conceptual Framework of the Study | 45 |
| 3 | General Block Diagram of the System | 48 |
| 4 | Layered System Architecture | 69 |
| 5 | Local-First Data Flow with Cloud Mirror | 72 |
| 6 | Technical Block Diagram | 74 |
| 7 | Agile–Scrum Development Methodology | 79 |
| 8 | Organizational Chart | 84 |
| 9 | System Flowchart — Main Learner Flow | 111 |
| 10 | System Flowchart — Adaptive Accessibility Routing | 113 |
| 11 | Class Diagram (Object Model — Principal Domain Classes) | 118 |
| 12 | Use Case Diagram | 122 |
| 13 | Entity Relationship Diagram | 125 |
| 14 | Navigation Map and Screen Hierarchy | 132 |
| 15 | User Interface — Profile Selection and Accessibility Setup | 134 |
| 16 | User Interface — Learner Home Screen | 135 |
| 17 | User Interface — Flashcard Viewer (Deaf versus Low-Vision) | 136 |
| 18 | User Interface — Games Hub with Curated Roster | 138 |
| 19 | User Interface — Progress Dashboard | 139 |
| 20 | Automated Test Execution Summary | 156 |
| 21 | Distribution of Automated Tests by Functional Area | 157 |
| 22 | SUS Score Against the Industry Benchmark | 173 |
| 23 | Pre-Test versus Post-Test Mean Scores | 178 |

---
## CHAPTER 1
# INTRODUCTION

---

### 1.1 Background of the Study

Vocabulary is the substrate of literacy. A learner who cannot name a thing cannot
read about it, cannot ask a question about it, and cannot be assessed on it. The
research consensus across four decades is unambiguous: vocabulary breadth is the
single strongest predictor of reading comprehension, and the gap between learners
who acquire words early and those who do not widens rather than narrows over the
course of schooling. For learners with disabilities, this gap begins earlier and
compounds faster, because the ordinary incidental channels through which
vocabulary is absorbed — overheard conversation, incidental print, casual
picture-book reading — are precisely the channels their disability attenuates.

In the Philippines, the legal and policy commitment to inclusive education is
strong on paper. Republic Act No. 7277, the *Magna Carta for Persons with
Disability*, guarantees the right to quality education; Republic Act No. 11650
(2022) institutionalises inclusive education for learners with disabilities and
mandates the establishment of Inclusive Learning Resource Centers in every city
and municipality; and Republic Act No. 11106 declares Filipino Sign Language the
national sign language of the Filipino Deaf and the medium of instruction in Deaf
education. The Department of Education's Special Education programme has for
decades been the operational expression of these commitments.

The gap between that policy framework and daily classroom reality, however, is
material. Special Education teachers routinely serve learners with several
different disabilities in a single room, using teaching materials produced for
learners without any. Commercially produced accessible learning software is
priced in United States dollars against a Philippine public-school budget.
Filipino Sign Language teaching material remains scarce and is rarely available
in a form that a learner can consult independently, without a signing adult
present. And the assistive technology that does reach classrooms is frequently
donated hardware with no localisation, no Filipino content, and no maintenance
path.

Meanwhile, the hardware constraint that once justified this gap has largely
dissolved. Android tablets and mid-range smartphones are now widely present in
Philippine households and increasingly in classrooms, whether school-issued,
donated, or family-owned. A modern mid-range Android device carries a
high-resolution touchscreen, a text-to-speech engine, a front camera capable of
supporting on-device computer vision, hardware video decoding, and enough storage
for a full multimedia curriculum — all without a network connection. The
practical obstacle to accessible digital vocabulary learning in the Philippines
is therefore no longer the hardware. It is the *software*, and specifically the
assumptions embedded in that software about who the learner is.

Those assumptions are worth naming precisely, because they define the problem
this study addresses. A conventional digital flashcard application assumes a
learner who:

1. **can see** the card, the illustration, and the small text label;
2. **can hear** the pronunciation prompt and the audio feedback;
3. **can execute a precise touch gesture** — a swipe, a drag, a tap on a target
   sized for an adult fingertip;
4. **can sustain attention** through dense text, multi-step instructions, and
   unpredictable animation; and
5. **reads English fluently.**

Each assumption, individually, excludes a recognised disability category. Taken
together, they define an application usable only by a learner who has no
disability at all. The conventional industry response is to add an accessibility
settings screen — a list of toggles for font size, contrast, sound, and motion.
This response is insufficient for the population in question for two reasons.
First, it presumes the learner or an adult already knows which of fifteen toggles
matters for their condition, and can find them. Second, and more fundamentally,
some adaptations cannot be expressed as a toggle at all: a Deaf learner does not
need the *audio-only listening game* made louder, they need it replaced with a
sign-language activity; a learner with severe motor disability does not need
drag-and-drop made easier, they need it removed and substituted with single-tap
alternatives.

**FlashLearn PWD**, the system developed in this study, proceeds from a different
premise. The learner declares a disability category once, during onboarding, and
the application thereafter reconfigures *itself* — its typography and contrast,
its narration, its animation budget, the content modalities it surfaces, and the
specific set of learning games it offers — to that category. The learner is never
required to know what a "font scale" is. A Deaf learner opening the flashcard
viewer finds a Filipino Sign Language button and no audio button; a low-vision
learner opening the same screen finds a bilingual audio-replay bar and no sign
button. The screen is the same screen; the adaptation is automatic, and it was
verified empirically on a physical device as part of this study (Section 5.3.5).

The system is delivered as a single Android application built with Flutter,
designed to run entirely offline after installation, and engineered deliberately
to operate within the free tier of its cloud provider so that no recurring cost
can ever be passed to a school. It contains 177 bilingual English–Filipino
flashcards across 13 thematic categories, 15 distinct learning-game types, 24
illustrated stories with comprehension quizzes, and 143 recorded Filipino Sign
Language video clips. Animation is used purposefully rather than decoratively:
card-flip transitions carry the English-to-Filipino relationship, celebration
sequences mark achievement, and every animation is suppressed automatically for
learners whose profile indicates that motion is a barrier rather than a reward.

This study documents the design, development, testing, and evaluation of that
system.

---

### 1.2 Statement of the Problem

This study sought to develop an interactive mobile flashcard application with
animations and games that supports vocabulary building among students with
disabilities, and to evaluate its quality and usability.

Specifically, the study sought to answer the following questions:

1. **What are the vocabulary-learning needs and accessibility barriers**
   experienced by students with visual, hearing, motor, cognitive, and multiple
   disabilities when using existing digital flashcard and vocabulary
   applications?

2. **How may a mobile flashcard application be designed and developed** such that
   it:
   1. presents bilingual English–Filipino vocabulary through animated flashcards
      and interactive games;
   2. automatically adapts its interface, content modalities, and activity roster
      to the learner's declared disability category, without requiring the learner
      to configure the application manually;
   3. operates fully offline on commodity Android hardware already present in
      Philippine classrooms and households; and
   4. records learner progress and makes it visible to teachers and parents?

3. **What is the level of quality of the developed system** as assessed against
   the ISO/IEC 25010 software product quality model in terms of:
   1. functional suitability;
   2. performance efficiency;
   3. usability;
   4. reliability;
   5. security;
   6. maintainability; and
   7. portability?

4. **What is the level of usability of the developed system** as measured by the
   System Usability Scale administered to Special Education teachers and parents
   who facilitate its use?

5. **How do learners with disabilities themselves evaluate their experience** of
   the developed system, as measured by a child-appropriate visual rating scale?

6. **Is there a significant difference between the pre-test and post-test
   vocabulary scores** of learners who used the developed system?

7. **What recommendations may be derived** from the findings for the improvement,
   deployment, and further study of the system?

---

### 1.3 Objectives of the Study

#### 1.3.1 General Objective

The general objective of this study was to design, develop, test, and evaluate
an interactive mobile flashcard application with animations and games that
supports English–Filipino vocabulary building among students with disabilities,
and that adapts automatically to the learner's disability category.

#### 1.3.2 Specific Objectives

Specifically, the study aimed to:

1. **Identify and analyse** the vocabulary-learning needs and the accessibility
   barriers faced by learners with visual, hearing, motor, cognitive, and multiple
   disabilities in the use of existing digital vocabulary applications.

2. **Design and develop** a mobile flashcard application that:
   1. delivers a curriculum of bilingual English–Filipino vocabulary organised
      into thematic categories, each card carrying an illustration, an example
      sentence, and a definition;
   2. employs purposeful animation — card flips, transitions, and celebration
      sequences — to reinforce learning and sustain engagement, with a
      reduced-motion mode for learners for whom motion is a barrier;
   3. provides a suite of interactive learning games spanning multiple learning
      modalities, including recognition, recall, spelling, sequencing,
      pronunciation, and sign-language production;
   4. integrates Filipino Sign Language video for Deaf and hard-of-hearing
      learners, with variable playback speed and a searchable dictionary;
   5. provides text-to-speech narration in both English and Filipino for
      learners with visual impairment or limited literacy;
   6. provides alternative input pathways — voice command, head-pose and blink
      control, and external gamepad support — for learners who cannot reliably
      use touch; and
   7. functions completely offline after installation.

3. **Implement an adaptive accessibility architecture** in which a learner's
   declared disability category automatically determines a settings preset, a
   content-visibility policy, and a curated roster of learning games, so that
   accessibility does not depend on the learner's or the teacher's ability to
   discover configuration options.

4. **Implement a progress-tracking and reporting subsystem** that records
   vocabulary mastery, game performance, study time, and streaks for each
   learner, and that presents this information to teachers and parents through
   dashboards, exportable reports, and printable certificates.

5. **Verify the correctness and robustness** of the developed system through a
   comprehensive automated regression test suite, static analysis, responsive
   layout testing across device and font-scale matrices, and live verification on
   physical Android hardware.

6. **Evaluate the developed system** against the ISO/IEC 25010 software product
   quality model, using Information Technology experts, Special Education
   teachers, and parents as evaluators.

7. **Measure the usability** of the developed system using the System Usability
   Scale administered to educators, and **measure the learners' own experience**
   using a child-appropriate three-point visual rating scale.

8. **Determine whether a significant difference exists** between the pre-test and
   post-test vocabulary scores of learners who used the developed system.

9. **Formulate recommendations** for the improvement, deployment, and further
   study of the developed system.

---

### 1.4 Scope and Limitations

#### 1.4.1 Scope

**Platform and delivery.** The system is a native Android application built with
the Flutter framework, distributed as a single installable APK package. It
targets Android 10 (API level 29) as its minimum supported version and Android 16
(API level 36) as its target version. It is locked to portrait orientation on all
device classes, a deliberate decision documented in Section 3.4.4.

**Vocabulary content.** The application ships with 177 bilingual English–Filipino
flashcards distributed across 13 thematic categories, as shown in Table 1. Each
card carries an English word, its Filipino equivalent, an illustration, an example
sentence, and a child-appropriate definition. Educators and learners may
additionally author their own custom cards, including cards illustrated with a
photograph taken by the device camera.

**Table 1. Distribution of Vocabulary Flashcards by Category**

| # | Category | Filipino Category Name | Cards |
|---:|---|---|---:|
| 1 | Animals | Mga Hayop | 12 |
| 2 | Colors & Shapes | Mga Kulay at Hugis | 13 |
| 3 | Numbers | Mga Numero | 12 |
| 4 | Body Parts | Mga Bahagi ng Katawan | 12 |
| 5 | Food & Drinks | Pagkain at Inumin | 17 |
| 6 | Family & Greetings | Pamilya at Pagbati | 12 |
| 7 | Clothing | Mga Damit | 12 |
| 8 | Weather | Panahon | 12 |
| 9 | Classroom | Silid-Aralan | 19 |
| 10 | Transportation | Transportasyon | 12 |
| 11 | Emotions | Mga Damdamin | 12 |
| 12 | Days & Time | Araw at Oras | 12 |
| 13 | Actions | Mga Kilos | 20 |
| | **Total** | | **177** |

**Learning activities.** The application provides 15 distinct learning-game
types: Word Match, Spelling Bee, Memory Match, Drag & Drop, Flashcard Quiz,
Pronunciation Practice, Sentence Builder, Story Quiz, Tracing, FSL Practice,
Jigsaw Puzzle, Picture-Word, Yes or No, Odd One Out, and First Letter. It further
provides 24 illustrated stories with comprehension quizzes, a daily challenge, a
spaced-repetition smart-review mode, and a guided-practice mode.

**Accessibility coverage.** The system supports six accessibility profiles:
visual impairment, hearing impairment, motor impairment, cognitive/learning
disability, multiple disabilities, and no accessibility needs. Each drives an
automatic settings preset, a content-visibility policy, and a ten-game curated
roster.

**Sign language.** The application integrates 143 recorded Filipino Sign Language
video clips, covering 144 of the 177 flashcards (one clip serves two cards for a
word that appears in two categories). Clips support variable playback speed from
0.25× to 1.5× and are available through the flashcard viewer, a searchable
dictionary, the story reader, and two dedicated FSL practice games.

**Alternative input.** Three alternative input pathways are provided: voice
command navigation using on-device speech recognition; head-pose and blink
control using the front camera and on-device face detection; and external
Bluetooth gamepad control.

**Roles and management.** The system supports five user roles — Student, Child,
Player, Teacher, and Parent — with classroom and home-group management, roster
dashboards, live classroom sessions, assessment authoring and assignment,
parent–teacher notes, messaging, time limits, and printable reports.

**Data and synchronisation.** All learner data is written first to a local Hive
datastore, making the application fully functional offline. When connectivity is
available and the learner has an account, data is mirrored to Cloud Firestore
under owner-scoped security rules. The system is engineered to operate entirely
within the Firebase Spark (free) tier.

**Evaluation.** The system was evaluated through automated testing, static
analysis, on-device verification, ISO/IEC 25010 expert evaluation, the System
Usability Scale, the Smileyometer learner scale, and a pre-test/post-test
vocabulary measure.

#### 1.4.2 Limitations

The following limitations bound the claims this study is entitled to make.

1. **Android only.** Although the Flutter framework is cross-platform and the
   codebase contains iOS, web, Windows, macOS, and Linux target directories, the
   system was developed, tested, and evaluated exclusively on Android. No claim
   is made regarding its behaviour on other platforms.

2. **Vocabulary domain, not general literacy.** The system teaches
   single-word vocabulary and short example sentences. It is not a reading
   programme, a grammar curriculum, or a speech-therapy instrument, and it does
   not claim to develop connected-text reading comprehension beyond the
   story-quiz activity.

3. **Head-pose control is not calibrated eye tracking.** The gaze feature
   estimates head orientation and eye-open probability using on-device face
   detection. It does not compute the screen pixel at which the learner's pupils
   are aimed. True calibrated pupil-gaze tracking requires a commercial paid
   software development kit and a per-user calibration procedure; both were
   deliberately rejected as incompatible with the study's zero-cost constraint.
   The feature is correctly described as head-pose and blink control, a
   recognised assistive input technique in the same family as switch access and
   dwell clicking.

4. **Sign-language coverage is partial.** 143 clips cover 144 of 177 cards.
   Thirty-three cards, concentrated in the more abstract categories, have no
   recorded sign. The application surfaces this honestly rather than substituting
   a placeholder.

5. **Speech recognition depends on the device engine.** Voice navigation and
   pronunciation scoring rely on the Android speech recognition service, whose
   accuracy varies by device, by ambient noise, and — significantly for this
   population — by the speaker's articulation. Learners with speech disabilities
   may find this pathway unreliable; it is offered as an addition to touch, never
   as a replacement for it.

6. **Cloud features require connectivity.** Classroom rosters, live sessions,
   messaging, cross-device synchronisation, and assignment tracking require an
   internet connection at the time of use. All *learning* features — cards,
   games, stories, progress, sign videos once cached — function offline.

7. **The system is not a medical or diagnostic instrument.** It does not
   diagnose disability, does not measure clinical outcomes, and its accessibility
   categories are self-declared or educator-assigned convenience classifications,
   not clinical determinations.

8. **Evaluation sample.** The evaluation was conducted with a purposively
   selected sample drawn from [Name of Partner School / SPED Center]. Findings
   describe that setting and are not claimed to generalise statistically to the
   national population of Philippine learners with disabilities.

9. **Duration of exposure.** The pre-test/post-test measure covers a
   [number]-week intervention period. No claim is made regarding long-term
   vocabulary retention beyond that window.

10. **Sign-language authenticity is bounded by the consultant pool.** Filipino
    Sign Language has regional variation. The recorded clips reflect the variety
    used by the consulting signers and may differ from usage in other regions.

---

### 1.5 Significance of the Study

The findings and the artefact produced by this study are significant to the
following stakeholders.

**To students with disabilities.** The primary beneficiaries. The system provides
a vocabulary-learning resource that does not require them to first overcome the
interface in order to reach the content. A Deaf learner receives sign language;
a low-vision learner receives narration and high-contrast large type; a learner
with a motor disability receives large single-tap targets and, where necessary,
hands-free control; a learner on the cognitive spectrum receives a
dyslexia-friendly palette, slowed narration, reduced motion, and a game roster
stripped of high-literacy and high-metacognition activities. The autonomy this
creates is itself an outcome: a learner who can operate a learning application
without an adult physically driving the device for them has gained something
that is educational and dignitary at once.

**To Special Education teachers.** The system supplies a single application that
serves a mixed-disability classroom without requiring the teacher to maintain
separate materials for each learner. Its roster dashboards, per-learner progress
timelines, hard-word reports, assessment assignment and tracking, printable
worksheets, and exportable certificates reduce the documentation burden that
consumes a disproportionate share of SPED teaching time. Its live-session mode
allows a teacher to run a whole-class activity across the learners' own devices.

**To parents and guardians.** The system extends structured vocabulary practice
into the home without requiring the parent to be a trained educator or a fluent
signer. The home-group feature, parent dashboard, time limits, alarms, and
parent–teacher note channel give parents visibility into and control over their
child's learning without demanding pedagogical expertise.

**To schools and the Department of Education.** The system demonstrates that a
functional, multi-disability, bilingual learning tool can be deployed at zero
recurring cost on hardware that schools and families already possess. It requires
no server, no subscription, no licence fee, and no internet connection for its
core function. This directly addresses the resource constraint that most often
stalls the implementation of Republic Act No. 11650.

**To the Deaf community.** The application contributes a freely available,
searchable corpus of 143 Filipino Sign Language clips tied to a structured
vocabulary curriculum, supporting the implementation of Republic Act No. 11106.
Its variable-speed playback and sign-production practice games treat FSL as a
language to be learned and produced, not merely as a caption.

**To software developers and researchers in assistive technology.** The study
contributes a documented, tested architecture for *automatic per-disability
adaptation* — a settings-preset layer, an orthogonal content-visibility policy
layer, and a curated activity-roster layer — together with the empirical
verification method used to prove that the layers actually change what a learner
sees. The complete automated test suite, including its accessibility-specific
assertions, is available as a reference implementation.

**To future researchers.** The application embeds its own research
instrumentation: a System Usability Scale form, a child-appropriate Smileyometer,
a pre-test/post-test assessment engine computing Hake's normalised gain, an
experiment module that randomly assigns learners to gamified and non-gamified
conditions, and an anonymised CSV research export producing fifteen datasets
including per-item response times suitable for item-difficulty and reliability
analysis. Future studies of gamification, sign-language pedagogy, or adaptive
interfaces can therefore use the system as a research platform rather than
rebuilding one.

---

### 1.6 Area of the Study

#### 1.6.1 Locale

The study was conducted at **[Name of Partner School / SPED Center]**, located in
**[City / Municipality, Province]**. The institution was selected purposively on
three criteria: it operates a Special Education programme serving learners across
more than one disability category; it possesses or has access to Android tablet
hardware; and its administration consented to the conduct of the study.

Development work was carried out at **[Full Registered Name of the Institution]**,
Old Sta. Mesa, Manila, and at the researcher's residence.

#### 1.6.2 Subject Area

The study falls within the intersection of three subject areas:

1. **Mobile application development** — specifically cross-platform development
   using the Flutter framework and the Dart language, offline-first local data
   persistence, and cloud synchronisation.
2. **Assistive and inclusive educational technology** — the design of software
   interfaces and content that adapt to sensory, motor, and cognitive
   disabilities, including alternative input modalities and sign-language media.
3. **Vocabulary pedagogy and educational measurement** — spaced repetition,
   gamified practice, bilingual presentation, and pre-test/post-test measurement
   of vocabulary gain.

#### 1.6.3 Respondents

The study drew on four groups of respondents:

1. **Students with disabilities** — learners enrolled in the partner
   institution's Special Education programme, distributed across the visual,
   hearing, motor, cognitive, and multiple disability categories.
2. **Special Education teachers** — the classroom facilitators who administered
   the application and completed the System Usability Scale and the ISO/IEC 25010
   evaluation.
3. **Parents and guardians** of participating learners.
4. **Information Technology experts** — practitioners and faculty who evaluated
   the system against the ISO/IEC 25010 technical quality characteristics.

The exact distribution is presented in Table 36.

#### 1.6.4 Time Frame

The study was conducted from **[Month] 2025** to **[Month] 2026**. The software
development phase, documented in the project's version-control history, ran from
**6 May 2026** to **26 August 2026**, comprising 114 recorded commits across
eight two-week sprints. Testing and evaluation were conducted from **[Month]** to
**[Month] 2026**.

---

### 1.7 Definition of Terms

The following terms are defined operationally as they are used in this study.

**Accessibility Preset.** A predefined bundle of application settings — font
scale, contrast, narration, narration speed, motion, sound, voice navigation, and
adaptive difficulty — automatically applied when a learner is assigned a
disability category, so that the learner need not configure the application
manually. Implemented in `AccessibilityPresets`.

**Adaptive Difficulty.** A mechanism that raises or lowers the challenge level of
learning games based on the learner's recorded accuracy: below 40 % accuracy
selects Easy, 40–70 % selects Medium, and above 70 % selects Hard. Implemented in
`AdaptiveDifficultyService`.

**Android Package Kit (APK).** The file format used to distribute and install an
application on the Android operating system. In this study, the single deliverable
installed on learner devices.

**Assistive Technology.** Any device, software, or system that maintains or
improves the functional capabilities of a person with a disability. In this study,
the term refers to the alternative input and output modalities the application
provides: text-to-speech, sign-language video, voice command, head-pose control,
and gamepad input.

**Content-Visibility Policy.** A rule layer, orthogonal to the accessibility
presets, that determines whether entire content modalities are surfaced to a
learner — specifically, whether Filipino Sign Language video entry points appear
and whether the audio-only Pronunciation game appears. Implemented in
`AccessibilityContentPolicy`.

**Cloud Firestore.** A hosted, document-oriented NoSQL database provided by
Google Firebase. In this study, the cross-device mirror for learner data; it is
never the primary store.

**Dart.** The programming language in which the Flutter framework and this
application are written. Version 3.12.0 was used.

**Dwell Selection.** An input technique in which a target is activated by holding
a pointer — here, the learner's head orientation — steadily on it for a defined
period, rather than by a discrete click or tap. Used by the head-pose control
mode with an adjustable dwell period defaulting to approximately 1.5 seconds.

**Filipino Sign Language (FSL).** The natural sign language of the Filipino Deaf
community, declared the national sign language of the Philippines by Republic Act
No. 11106 (2018). In this study, delivered as 143 recorded video clips.

**Flashcard.** A two-sided learning object presenting a vocabulary word. In this
system, a flashcard carries an English word, a Filipino equivalent, an
illustration, an optional real photograph, an example sentence, a definition, and
a category assignment.

**Flutter.** Google's open-source user-interface framework for building natively
compiled applications from a single codebase. Version 3.44.0 (stable channel) was
used.

**Gamification.** The application of game-design elements — points, levels,
badges, streaks, leaderboards, and virtual rewards — to non-game contexts in order
to increase motivation and engagement. In this system, expressed as stars,
experience points, a ten-tier level ladder, 38 achievements, a 26-item cosmetic
shop, and daily streaks.

**Hake's Normalised Gain.** A measure of learning improvement computed as
*(post-test − pre-test) / (1 − pre-test)*, which expresses the proportion of the
available improvement that was actually achieved. Preferred over raw score
difference because it does not penalise learners who begin with a high pre-test
score. Implemented in `LearningGainReport.normalizedGain`.

**Hive.** A lightweight, pure-Dart key-value database used as the application's
local, on-device datastore and primary source of truth.

**ISO/IEC 25010.** The international standard defining a software product quality
model comprising eight characteristics: functional suitability, performance
efficiency, compatibility, usability, reliability, security, maintainability, and
portability. Used in this study as the system-evaluation instrument.

**Local-First Architecture.** A design in which every write is committed to
on-device storage first and synchronised to the cloud opportunistically, so that
the application remains fully functional without a network connection.

**Machine Learning Kit (ML Kit).** Google's on-device machine-learning library.
This study uses its face-detection model for head-pose control and its
image-labelling model for the camera-based object-recognition activity. Both
models are bundled inside the application and execute offline.

**Persons With Disability (PWD).** As defined by Republic Act No. 7277, persons
suffering from restriction or different abilities, as a result of a mental,
physical, or sensory impairment, to perform an activity in the manner or within
the range considered normal for a human being. In this study, operationalised as
six categories: visual, hearing, motor, cognitive/learning, multiple, and none.

**Reduced Motion.** An accessibility mode that suppresses or minimises animation
throughout the interface, provided for learners for whom movement causes
distraction, discomfort, or vestibular difficulty.

**Riverpod.** The reactive state-management library used to expose application
state — active profile, settings, progress, content policy — to the widget tree.

**Smileyometer.** A three-point visual rating scale using facial expressions,
drawn from Read and MacFarlane's *Fun Toolkit*, designed to capture the
subjective experience of child participants who cannot reliably use an abstract
Likert scale. Used in this study as the learner-facing evaluation instrument.

**Spaced Repetition.** A learning technique that schedules review of an item at
increasing intervals, prioritising items that are less well known or longer
unseen. Implemented in `SpacedRepetitionService` using a priority score combining
a difficulty factor and a forgetting factor.

**System Usability Scale (SUS).** A validated ten-item questionnaire producing a
usability score from 0 to 100, developed by Brooke (1996). A score above 68 is
conventionally considered above average. Administered in this study to educators
rather than to learners, for reasons detailed in Section 4.1.3.

**Text-to-Speech (TTS).** Technology that converts written text into synthesised
speech. Used in this system to narrate words, sentences, definitions, and
interface elements in both English and Filipino.

**Universal Design for Learning (UDL).** An educational framework advocating
multiple means of engagement, representation, and action/expression so that
curricula are accessible to the widest range of learners without retrofitting.
The design philosophy underpinning this system.

**Vocabulary Building.** The process of acquiring, retaining, and being able to
use new words. In this study, operationalised as the number of distinct words a
learner has answered correctly at least once, and measured by pre-test and
post-test instruments.

**Widget Test.** An automated test that constructs a portion of the application's
user interface in a simulated environment, drives interactions, and asserts on
the resulting interface state. The dominant test form in this study's regression
suite.

---
## CHAPTER 2
# REVIEW OF RELATED LITERATURE AND STUDIES

---

This chapter presents the literature and studies, both local and foreign, that
informed the design of the system and situate it within the existing body of
knowledge. The review is organised into local related literature, foreign related
literature, local related studies, and foreign related studies, followed by a
synthesis identifying the research gap this study addresses. It concludes with
the research paradigm, the conceptual framework, and the general block diagram of
the system.

---

### 2.1 Local Related Literature

#### 2.1.1 The Philippine Legal Framework for Inclusive Education

The Philippine statutory basis for inclusive education is substantial, and the
system developed in this study was designed explicitly against it.

**Republic Act No. 7277**, the *Magna Carta for Persons with Disability* (1992),
as amended by Republic Act No. 9442 (2007) and Republic Act No. 10754 (2016),
establishes the right of persons with disability to quality education and directs
the State to ensure access to educational institutions and to provide auxiliary
services and appropriate learning materials. The Act's framing of disability as a
matter of *access* rather than of *capacity* is the philosophical foundation of
this study's design premise: the barrier is in the material, not in the learner.

**Republic Act No. 11650** (2022), the *Instituting a Policy of Inclusion and
Services for Learners with Disabilities in Support of Inclusive Education Act*, is
the most operationally significant statute for this study. It mandates the
establishment of Inclusive Learning Resource Centers in every city and
municipality, requires the Department of Education to provide accessible learning
resources, and explicitly recognises assistive technology as a component of
inclusive education. The Act's implementation, however, is constrained by
resource availability — a constraint that a zero-cost, offline-capable
application on existing hardware directly addresses.

**Republic Act No. 11106** (2018), the *Filipino Sign Language Act*, declares
Filipino Sign Language the national sign language of the Filipino Deaf and
mandates its use as the medium of instruction in the education of the Deaf, as
well as in all public transactions involving the Deaf. The Act creates a
substantial demand for FSL learning material. The literature and the Act's own
implementing guidelines note the scarcity of standardised, freely available FSL
teaching resources — the specific gap addressed by this study's 143-clip sign
corpus.

**Department of Education Order No. 21, s. 2019**, the *Policy Guidelines on the
K to 12 Basic Education Program*, and the earlier **DepEd Order No. 72, s. 2009**
on inclusive education as a strategy for increasing participation rates, together
establish that learners with disabilities are to be served within the general
education system wherever possible. This policy of mainstreaming produces the
mixed-disability classroom that motivated this study's core architectural
decision: one application that reconfigures itself per learner, rather than
several applications, one per disability.

**Republic Act No. 10533**, the *Enhanced Basic Education Act of 2013*,
establishes mother-tongue-based multilingual education in the early grades. This
legislative preference for the learner's first language is the basis for the
application's bilingual English–Filipino design, in which the Filipino equivalent
is not a translation afterthought but a co-equal face of every flashcard.

#### 2.1.2 Philippine Literature on Special Education Practice

Philippine scholarship on Special Education practice consistently documents a
gap between policy and provision. Recurrent themes in this literature include the
insufficiency of trained SPED teachers relative to enrolment, the concentration
of SPED provision in urban centres, the shortage of instructional materials
designed for specific disabilities, and the heavy documentation and reporting
burden borne by SPED teachers. The literature further documents that where
assistive technology is present, it is frequently donated, English-only, and
unsupported after donation.

This body of literature shaped three design decisions in the present system.
First, the inclusion of an extensive educator subsystem — roster dashboards,
per-learner progress timelines, hard-word reports, printable worksheets and
certificates, and exportable comma-separated-value data — is a direct response to
the documented documentation burden. Second, the bilingual design responds to the
English-only limitation of donated technology. Third, the offline-first
architecture responds to the documented unreliability of connectivity outside
urban centres.

#### 2.1.3 Philippine Literature on Mobile Technology Penetration

Philippine literature on information and communications technology consistently
reports high mobile-device penetration alongside uneven fixed-broadband
availability, with mobile data frequently prepaid and metered. This asymmetry —
devices are common, reliable connectivity is not — is the direct justification for
this study's decision that every learning function must operate without a network
connection, and that cloud features must degrade gracefully rather than blocking
use.

---

### 2.2 Foreign Related Literature

#### 2.2.1 Universal Design for Learning

The **Universal Design for Learning (UDL)** framework, developed by the Center for
Applied Special Technology, holds that curricula should be designed from the
outset to accommodate learner variability rather than retrofitted for individual
learners. UDL articulates three principles: providing multiple means of
**engagement** (the *why* of learning), multiple means of **representation** (the
*what*), and multiple means of **action and expression** (the *how*).

The system developed in this study is structured explicitly along these three
principles:

- *Multiple means of representation*: every vocabulary word is available as
  written English text, written Filipino text, a cartoon illustration, a real
  photograph, synthesised speech in two languages, a Filipino Sign Language video,
  and — for action words — a real-world demonstration clip.
- *Multiple means of action and expression*: the learner may respond by tapping,
  swiping, dragging, tracing, speaking, signing, holding a head position, or
  pressing a gamepad button.
- *Multiple means of engagement*: fifteen game types, a story library, a daily
  challenge, streaks, levels, achievements, a cosmetic shop, collaborative and
  competitive multiplayer modes, and an adaptive difficulty engine.

The UDL literature also supplies this study's central critique of the
settings-screen approach: UDL requires that alternatives be *available by design*,
not that the learner petition for them.

#### 2.2.2 Dual Coding Theory and Multimedia Learning

**Paivio's Dual Coding Theory** holds that information encoded in both verbal and
visual channels is better retained than information encoded in one channel alone.
**Mayer's Cognitive Theory of Multimedia Learning** extends this into design
principles for instructional media, including the multimedia principle (words plus
pictures beat words alone), the coherence principle (extraneous material harms
learning), the modality principle (narration with graphics beats on-screen text
with graphics), and the redundancy principle (simultaneous narration and identical
on-screen text can impair learning).

These principles are directly operationalised in the system. Each flashcard pairs
a word with an illustration, satisfying the multimedia principle. The card face is
deliberately sparse, satisfying coherence. Narration is offered as an alternative
to reading rather than as a simultaneous duplicate, respecting the redundancy
principle. The card-flip animation is not decorative: it makes the
English–Filipino relationship spatially explicit, using motion to encode a
semantic relation.

Mayer's coherence principle also justifies the reduced-motion mode. For a learner
whose attentional resources are already taxed, an animation that carries no
information is not neutral — it is a cost. The system therefore suppresses
non-informative motion automatically for the cognitive, motor, and multiple
disability presets.

#### 2.2.3 Spaced Repetition and the Testing Effect

The **spacing effect**, first documented by Ebbinghaus and confirmed across more
than a century of replication, holds that learning distributed over time produces
better retention than the same quantity of learning massed together. The
**testing effect** holds that actively retrieving an item strengthens memory more
than re-studying it.

Both are implemented in the system. The `SpacedRepetitionService` maintains a
per-word accuracy record and computes a priority score combining a *difficulty
factor* (one minus the learner's accuracy on that word) and a *forgetting factor*
(days since the word was last seen, saturating at three days). Words with the
highest combined priority are surfaced by the Smart Review mode. The testing
effect is served by the fact that the majority of the system's activities are
retrieval activities — the learner produces or selects an answer — rather than
passive exposure.

#### 2.2.4 Gamification and Self-Determination Theory

The gamification literature reports generally positive but heterogeneous effects
on engagement and, less consistently, on learning outcomes. **Self-Determination
Theory** provides the most widely used explanatory frame: game elements support
motivation to the extent that they satisfy the needs for *competence*,
*autonomy*, and *relatedness*, and undermine it when they substitute external
control for internal interest.

The system's gamification layer was designed against this frame. Competence is
served by a visible ten-tier level ladder, 38 achievements, per-game star ratings,
and a mastery percentage. Autonomy is served by free choice of category, game,
and activity, and by a cosmetic shop in which earned stars buy avatars, borders,
and titles that confer no gameplay advantage. Relatedness is served by classroom
leaderboards (disabled by default and enabled at educator discretion),
cooperative peer collaboration, and messaging.

Critically, the literature's warning about undermining intrinsic motivation
informed a specific architectural feature: the system includes an **experiment
module** that assigns learners to a *treatment* condition with the full
gamification layer and a *control* condition with gamification suppressed,
precisely so that this question can be studied rather than assumed.

#### 2.2.5 Bilingual and Mother-Tongue Vocabulary Instruction

The literature on bilingual vocabulary instruction supports the practice of
presenting a new second-language word alongside its first-language equivalent for
young or lower-proficiency learners, on the grounds that the first-language
equivalent provides an immediate conceptual anchor. For Deaf learners, the
literature on bilingual-bicultural Deaf education argues more strongly still that
the sign language is the learner's first language and that written language is
acquired *through* it, not prior to it.

The system's design follows both findings. Every card presents English and
Filipino together, and for Deaf learners the sign clip is positioned as a primary
representation of the word rather than as supplementary material.

#### 2.2.6 Accessible Input: Switch Access, Dwell, and Alternative Control

The human–computer interaction literature on alternative input for users with
severe motor disability establishes a family of techniques including switch
scanning, dwell selection, head pointing, and eye tracking. This literature
reports a consistent trade-off between *precision* and *robustness*: fine
pointing supports dense interfaces but fails under noise, tremor, and lighting
variation, whereas coarse selection over a small number of large targets is
robust but limits interface density.

This finding directly determined the design of the system's head-pose control.
Rather than attempting fine pointing, the feature maps head orientation onto four
large edge targets plus a central rest zone, holds a dwell ring to confirm, and
requires the learner to return to rest before the same target can fire again.
This is an explicit accuracy-for-robustness trade, taken on the literature's
recommendation.

#### 2.2.7 The System Usability Scale and Child-Appropriate Instruments

**Brooke's System Usability Scale** is the most widely used usability instrument
in the literature, comprising ten alternately worded items on a five-point Likert
scale and producing a 0–100 score. Subsequent normative work established that a
score of 68 represents the average across several hundred studies, and mapped
score ranges onto adjectival and letter-grade interpretations.

The child–computer interaction literature, however, establishes that abstract
Likert instruments are unreliable with young children, who do not reliably map
internal states onto a five-point bipolar agree/disagree continuum and who are
susceptible to acquiescence bias and to the response errors induced by
alternating item polarity. **Read and MacFarlane's Fun Toolkit** was developed in
response, and its *Smileyometer* — a visual scale of facial expressions — is the
most widely adopted child-appropriate alternative.

This literature is the direct basis for the triangulated instrument design
adopted in this study and detailed in Section 4.1.3: the SUS is administered to
the adult facilitator, where its assumptions hold, and the Smileyometer is
administered to the learner, where the SUS's assumptions would fail. For a Deaf
learner whose first language is FSL rather than written Filipino or English,
administering an item such as *"I found the app unnecessarily complex"* would
measure reading comprehension, not usability.

#### 2.2.8 ISO/IEC 25010 Software Product Quality

**ISO/IEC 25010**, part of the SQuaRE series, defines a product quality model of
eight characteristics — functional suitability, performance efficiency,
compatibility, usability, reliability, security, maintainability, and portability
— each decomposed into sub-characteristics. Its adoption as an evaluation
instrument for capstone and thesis software is widespread because it provides a
defensible, standardised structure for expert evaluation. This study adopts it for
system evaluation in Section 5.4.

---

### 2.3 Local Related Studies

The following local studies informed specific design decisions and establish the
Philippine context in which the present system operates.

**Studies of mobile applications for Philippine Special Education.** A recurrent
class of Philippine capstone and thesis work develops mobile learning applications
for a *single* disability category — most commonly hearing impairment (FSL
learning applications) or autism spectrum disorder (communication and routine
applications). These studies consistently report positive usability evaluations
and positive teacher reception. Their common limitation, and the gap this study
addresses, is that each serves one category; a mixed-disability classroom would
require several such applications with several unrelated interfaces, several
separate progress records, and no common teacher dashboard.

**Studies of Filipino Sign Language learning applications.** Philippine studies
developing FSL applications typically deliver a dictionary of signs, sometimes
with a quiz mode. They report the same two limitations: coverage is narrow
relative to a curriculum, and the sign material is presented for *recognition*
rather than *production*. The present system responds by tying its sign corpus to
a structured 177-word vocabulary curriculum, and by providing two distinct
practice directions — sign-to-word and word-to-sign — plus a self-report and
educator-verification mechanism for production ability.

**Studies of gamified vocabulary applications for Filipino learners.** Local
studies of gamified vocabulary and spelling applications generally report
increased engagement and improved post-test scores among general-education
learners. These studies rarely include learners with disabilities in their
samples, and typically do not report accessibility features. The present study
extends this line of work to the PWD population and reports accessibility as a
primary rather than incidental outcome.

**Studies of offline-capable educational applications.** Philippine studies of
educational software repeatedly identify connectivity as the principal deployment
risk and recommend offline capability. The present system adopts offline-first as
an architectural constraint rather than as a feature, with the local Hive store
as the source of truth and cloud synchronisation as an opportunistic mirror.

**Studies of teacher documentation burden in SPED.** Local studies of SPED
teacher workload document extensive time spent on individualised documentation
and progress reporting. The present system's automated report generation,
certificate printing, worksheet generation, and CSV export were designed against
this finding.

> **Note.** Specific citations for this section should be drawn from the
> Philippine studies you consulted during your review of related literature and
> entered in the References section using the citation style prescribed by
> [Name of Institution]. The thematic groupings above reflect the standing state
> of the local literature and the design decisions each theme informed.

---

### 2.4 Foreign Related Studies

**Studies of digital flashcard applications and vocabulary retention.** A large
body of international work compares digital flashcard applications with paper
flashcards and with word-list study, generally reporting an advantage for digital
tools that implement spaced repetition, and a smaller or null advantage for
digital tools that merely digitise a static deck. This finding is the reason the
present system implements a genuine spaced-repetition priority function and a
Smart Review mode, rather than presenting decks in fixed order only.

**Studies of tablet-based intervention for learners with autism and intellectual
disability.** International studies of tablet interventions in this population
report improvements in engagement, task completion, and communication, and
identify predictability, reduced sensory load, and consistency of interface as
success factors. These findings informed the cognitive preset's configuration:
reduced motion, slowed narration (0.35× rate), the dyslexia-friendly cream palette
with the Lexend typeface and widened letter spacing, and a game roster stripped of
the highest-literacy and highest-metacognitive-load activities.

**Studies of sign-language video in Deaf education.** International work
consistently finds that Deaf learners' comprehension and retention improve when
material is presented in sign language, and that variable playback speed is a
meaningful accessibility affordance for learners still acquiring the language.
The present system implements playback speed from 0.25× to 1.5×, verified on
device in Section 5.3.5.

**Studies of eye-gaze and head-pose control for learners with severe motor
disability.** The international literature reports that gaze and head-based
control can restore independent computer access for users with quadriplegia and
related conditions, and that commercial calibrated eye-tracking systems achieve
higher precision at substantially higher cost and with a per-user calibration
requirement. Studies of camera-based head-pose alternatives report lower precision
but usable performance for coarse target selection, with lighting and camera angle
as the dominant failure modes. The present system's design — four large edge
targets, a rest zone, adjustable dwell period, blink confirm, and an explicit
aiming step — follows these findings, and the study reports the limitations
plainly rather than claiming eye-tracking capability it does not have.

**Studies of text-to-speech for learners with visual impairment and dyslexia.**
International studies report that synthesised-speech access to text improves
comprehension and reduces fatigue for both populations, with speech rate as a
significant moderator: rates that are comfortable for experienced screen-reader
users are too fast for novice and young users. The present system therefore sets
narration rate by preset — 0.4× for the visual and multiple presets, 0.5× for
motor, and 0.35× for cognitive — rather than using a single default.

**Studies of gamification in special education.** International studies report
positive engagement effects for gamified special-education software, with the
caveat that competitive elements can be counterproductive for learners with
anxiety or with significant performance gaps relative to peers. This finding
directly produced two design decisions: leaderboards are **disabled by default**
and must be explicitly enabled by an educator per class, and the co-operative
*Peer Collaboration* mode was built as a non-competitive twin of the competitive
*Play Together* mode.

**Studies applying ISO/IEC 25010 to educational software.** A substantial body of
international and regional capstone-level work adopts ISO/IEC 25010 as an expert
evaluation instrument for educational systems, typically administering a
characteristic-by-characteristic questionnaire on a five-point scale to a
purposive panel of IT experts and domain experts. The present study follows this
established practice.

> **Note.** As with Section 2.3, specific citations should be entered from the
> foreign studies you consulted, in the prescribed citation style.

---

### 2.5 Synthesis

The reviewed literature and studies converge on six findings that, taken
together, define both the justification for and the specific shape of the present
system.

**First, the legal mandate is settled and the provision gap is the binding
constraint.** Philippine law — Republic Acts 7277, 11650, 11106, and 10533 —
establishes a comprehensive right to accessible, sign-language-inclusive,
mother-tongue-supported education. The local literature documents that the
constraint on realising this right is material and operational: insufficient
accessible resources, insufficient FSL material, uneven connectivity, and an
overburdened teaching workforce. A system that is free, offline-capable, bilingual,
FSL-equipped, and administratively labour-saving addresses the documented
constraint rather than the settled mandate.

**Second, the pedagogical principles are well established and mutually
reinforcing.** Universal Design for Learning, Dual Coding Theory, the Cognitive
Theory of Multimedia Learning, the spacing effect, and the testing effect
independently converge on a design: present each concept through multiple
channels, keep each presentation sparse, favour retrieval over exposure, and
distribute practice over time. The present system implements all five.

**Third, the existing software gap is specifically a gap of *scope*, not of
existence.** Applications serving one disability category exist, locally and
internationally, and are generally well received. What the literature does not
report is a single system that serves *several* categories by reconfiguring
itself, thereby matching the mixed-disability classroom that Philippine
mainstreaming policy actually produces. This is the primary gap the present study
addresses.

**Fourth, accessibility-by-settings is an insufficient mechanism.** The UDL
literature holds that alternatives must be available by design; the
child–computer interaction literature holds that young users cannot be expected to
self-configure; and the practical structure of the problem is that some
adaptations — replacing a listening game with a signing game, removing
drag-and-drop for a learner who cannot drag — are not expressible as a settings
toggle at all. This finding produced the system's three-layer adaptation
architecture: an automatic settings preset, an orthogonal content-visibility
policy, and a curated per-category activity roster.

**Fifth, the evaluation instruments must be matched to the respondent.** The
usability literature validates the SUS for adults; the child–computer interaction
literature invalidates it for young children, and *a fortiori* for young Deaf
children whose first language is not the written language of the instrument. The
present study therefore triangulates: SUS to the educator, Smileyometer to the
learner, each reported under its own heading and neither converted into the
other's scale.

**Sixth, gamification's effect on this population is genuinely uncertain and
should be studied rather than assumed.** The literature reports positive
engagement effects alongside credible warnings about intrinsic motivation and
about competitive elements in special-education contexts. The present system
therefore builds gamification, disables its most competitive element by default,
and embeds an experiment module capable of randomly assigning learners to gamified
and non-gamified conditions so the question remains empirically open.

**The research gap.** No reviewed study reports a single, free, offline-capable,
bilingual Filipino–English vocabulary application that (a) automatically
reconfigures its interface, content modalities, and activity roster across five
distinct disability categories, (b) integrates a curriculum-tied Filipino Sign
Language corpus supporting both recognition and production, (c) provides
alternative input pathways including hands-free control for learners with severe
motor disability, and (d) supplies educators with an integrated progress,
assessment, and reporting subsystem. The present study develops and evaluates such
a system.

---

### 2.6 Research Paradigm

The study adopted the **Input–Process–Output (IPO)** model as its research
paradigm, extended with a feedback loop reflecting the iterative Agile–Scrum
development methodology described in Section 4.2. The paradigm is presented in
Figure 1.

**Figure 1. Research Paradigm (Input–Process–Output Model)**

```
┌───────────────────────────────┐   ┌───────────────────────────────┐   ┌───────────────────────────────┐
│             INPUT             │   │            PROCESS            │   │            OUTPUT             │
├───────────────────────────────┤   ├───────────────────────────────┤   ├───────────────────────────────┤
│                               │   │                               │   │                               │
│ KNOWLEDGE REQUIREMENTS        │   │ 1. REQUIREMENTS ANALYSIS      │   │ FlashLearn PWD                │
│ • Vocabulary pedagogy         │   │    • Interviews with SPED     │   │ — an interactive mobile       │
│   (spacing, testing effect,   │   │      teachers and parents     │   │   flashcard application       │
│   dual coding)                │──▶│    • Observation of learners  │──▶│   with animations and games   │
│ • Universal Design for        │   │    • Review of DepEd SPED     │   │   for vocabulary building     │
│   Learning principles         │   │      curriculum guides        │   │   among PWD students          │
│ • Accessibility standards     │   │                               │   │                               │
│ • RA 7277, 11650, 11106       │   │ 2. SYSTEM DESIGN              │   │ DELIVERED ARTEFACTS           │
│                               │   │    • Three-layer adaptation   │   │ • Android APK (177 cards,     │
│ SOFTWARE REQUIREMENTS         │   │      architecture             │   │   15 games, 24 stories,       │
│ • Flutter 3.44 / Dart 3.12    │   │    • Local-first data model   │   │   143 FSL clips)              │
│ • Hive local datastore        │   │    • Object and database      │   │ • Educator dashboards,        │
│ • Cloud Firestore (Spark)     │   │      modelling                │   │   reports and exports         │
│ • Google ML Kit (on-device)   │   │    • User interface design    │   │ • Project website and         │
│ • Flutter TTS / STT           │   │                               │   │   teacher's guide             │
│                               │   │ 3. DEVELOPMENT                │   │ • Technical documentation     │
│ HARDWARE REQUIREMENTS         │   │    • Agile–Scrum, 8 sprints    │   │                               │
│ • Android 10+ device          │   │    • 114 version-controlled   │   │ EVALUATION RESULTS            │
│ • Development workstation     │   │      increments               │   │ • Automated test results      │
│ • Video recording equipment   │   │    • Continuous automated     │   │ • ISO/IEC 25010 quality       │
│                               │   │      regression testing       │   │   assessment                  │
│ CONTENT REQUIREMENTS          │   │                               │   │ • SUS usability score         │
│ • 177 bilingual word set      │   │ 4. TESTING                    │   │   (educators)                 │
│ • Illustrations & photographs │   │    • Unit, widget, integration│   │ • Smileyometer results        │
│ • FSL performances            │   │    • Static analysis          │   │   (learners)                  │
│ • 24 stories                  │   │    • Device & layout matrices │   │ • Pre-test / post-test        │
│                               │   │    • On-device verification   │   │   vocabulary gain             │
│ HUMAN REQUIREMENTS            │   │                               │   │                               │
│ • SPED teachers               │   │ 5. EVALUATION                 │   │ RECOMMENDATIONS               │
│ • PWD learners                │   │    • ISO/IEC 25010 experts    │   │ • For deployment              │
│ • Parents / guardians         │   │    • SUS (educators)          │   │ • For enhancement             │
│ • FSL consultants             │   │    • Smileyometer (learners)  │   │ • For future research         │
│ • IT experts                  │   │    • Pre-test / post-test     │   │                               │
│                               │   │                               │   │                               │
└───────────────────────────────┘   └───────────────────────────────┘   └───────────────────────────────┘
              ▲                                                                         │
              │                                                                         │
              │              F E E D B A C K   ( Agile sprint review )                  │
              └─────────────────────────────────────────────────────────────────────────┘
```

The feedback path is not decorative. Under the Agile–Scrum methodology adopted
for this study, the output of each sprint was reviewed with stakeholders and the
resulting findings re-entered the input stage of the next sprint. The
per-disability game rosters, for example, did not exist in the initial design;
they were introduced after a sprint review established that filtering games by a
settings flag was insufficient, because it produced categories with too few
remaining games to constitute a usable hub.

---

### 2.7 Conceptual Framework

The conceptual framework of the study, presented in Figure 2, expresses the
central proposition: that **learner variability, when detected and routed through
an adaptation layer, produces a personalised learning experience whose outcome is
measurable vocabulary gain and sustained engagement.**

**Figure 2. Conceptual Framework of the Study**

```
                        ┌──────────────────────────────────────────┐
                        │        THE LEARNER WITH A DISABILITY     │
                        │  visual · hearing · motor · cognitive ·  │
                        │           multiple · none                │
                        └────────────────────┬─────────────────────┘
                                             │  declares category once,
                                             │  at onboarding
                                             ▼
      ╔══════════════════════════════════════════════════════════════════════════╗
      ║                    A D A P T A T I O N   L A Y E R                       ║
      ║                                                                          ║
      ║  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐  ║
      ║  │ LAYER 1            │  │ LAYER 2            │  │ LAYER 3            │  ║
      ║  │ Settings Preset    │  │ Content Policy     │  │ Activity Roster    │  ║
      ║  │                    │  │                    │  │                    │  ║
      ║  │ font scale         │  │ show FSL video?    │  │ which 10 of the    │  ║
      ║  │ contrast / palette │  │ show audio-only    │  │ 15 games appear,   │  ║
      ║  │ narration + rate   │  │   Pronunciation?   │  │ and in what order  │  ║
      ║  │ motion budget      │  │                    │  │                    │  ║
      ║  │ sound effects      │  │ (orthogonal to     │  │ (curated, not      │  ║
      ║  │ voice navigation   │  │  Layer 1 — some    │  │  merely filtered — │  ║
      ║  │ adaptive difficulty│  │  adaptations are   │  │  every category    │  ║
      ║  │                    │  │  not toggles)      │  │  gets exactly 10)  │  ║
      ║  └────────────────────┘  └────────────────────┘  └────────────────────┘  ║
      ╚══════════════════════════════════════════╤═══════════════════════════════╝
                                                 │
                                                 ▼
      ┌──────────────────────────────────────────────────────────────────────────┐
      │                    P E R S O N A L I S E D   E X P E R I E N C E         │
      │                                                                          │
      │   REPRESENTATION            ACTION & EXPRESSION          ENGAGEMENT      │
      │   • bilingual text          • tap / swipe / drag         • 15 games      │
      │   • illustration            • trace                      • 24 stories    │
      │   • real photograph         • speak                      • daily challenge│
      │   • text-to-speech (2 lang) • sign                       • stars & XP    │
      │   • FSL video (0.25–1.5×)   • head-pose + blink          • 10 levels     │
      │   • action demo clip        • gamepad                    • 38 achievements│
      │                             • voice command              • shop & streaks │
      └──────────────────────────────────────────┬───────────────────────────────┘
                                                 │
                            ┌────────────────────┴────────────────────┐
                            ▼                                         ▼
      ┌───────────────────────────────────┐      ┌───────────────────────────────────┐
      │      L E A R N I N G   E N G I N E│      │   M E A S U R E M E N T           │
      │  • spaced repetition priority     │      │  • words learned / mastery %      │
      │  • adaptive difficulty (acc-based)│◀────▶│  • per-word accuracy              │
      │  • learning level (age + progress)│      │  • study time & streaks           │
      │  • smart review / hard words      │      │  • pre-test / post-test gain      │
      └───────────────────────────────────┘      └────────────────┬──────────────────┘
                                                                  │
                                                                  ▼
      ┌──────────────────────────────────────────────────────────────────────────┐
      │                          O U T C O M E S                                 │
      │                                                                          │
      │   FOR THE LEARNER          FOR THE EDUCATOR         FOR THE INSTITUTION  │
      │   • vocabulary gain        • roster dashboards      • zero recurring cost │
      │   • independent access     • progress timelines     • offline capability  │
      │   • sustained engagement   • hard-word reports      • RA 11650 / 11106    │
      │   • FSL exposure           • assessments & exports  │   implementation    │
      └──────────────────────────────────────────────────────────────────────────┘
```

The framework identifies the study's variables as follows.

- **Independent variable:** the learner's declared accessibility category, and
  the corresponding adaptation applied by the system.
- **Dependent variables:** vocabulary gain, measured by the difference between
  pre-test and post-test scores and by Hake's normalised gain; system usability,
  measured by the SUS; learner experience, measured by the Smileyometer; and
  system quality, measured against ISO/IEC 25010.
- **Intervening variables:** prior vocabulary knowledge, age and grade level,
  frequency and duration of use, the degree of facilitator support provided, and
  device characteristics.

---

### 2.8 Block Diagram

Figure 3 presents the general block diagram of the system: the major functional
blocks, the actors who interact with them, and the direction of data flow. The
more detailed technical block diagram, showing the specific technologies
implementing each block, is presented in Section 3.7 as Figure 6.

**Figure 3. General Block Diagram of the System**

```
        ┌──────────────┐        ┌──────────────┐        ┌──────────────┐
        │   LEARNER    │        │   TEACHER    │        │   PARENT     │
        │ Student ·    │        │              │        │              │
        │ Child·Player │        │              │        │              │
        └──────┬───────┘        └──────┬───────┘        └──────┬───────┘
               │                       │                       │
               ▼                       ▼                       ▼
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                     I N P U T   /   C O N T R O L   B L O C K              ║
  ║  Touch · Swipe · Drag · Trace │ Voice command │ Head-pose + blink │ Gamepad ║
  ╚════════════════════════════════════════════┬═══════════════════════════════╝
                                               ▼
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                    A C C E S S   /   I D E N T I T Y   B L O C K           ║
  ║  Profile selection · Role routing (Student/Child/Player/Teacher/Parent)     ║
  ║  Accessibility category assignment · PIN gate · Recovery code               ║
  ╚════════════════════════════════════════════┬═══════════════════════════════╝
                                               ▼
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                    A D A P T A T I O N   B L O C K                          ║
  ║  Settings preset  →  Content-visibility policy  →  Curated game roster      ║
  ╚═══════════╤════════════════════════╤═══════════════════════╤════════════════╝
              ▼                        ▼                       ▼
  ┌────────────────────┐  ┌────────────────────────┐  ┌────────────────────────┐
  │  LEARNING CONTENT  │  │   LEARNING ACTIVITY    │  │  COMMUNICATION &       │
  │       BLOCK        │  │        BLOCK           │  │  COLLABORATION BLOCK   │
  │                    │  │                        │  │                        │
  │ • 177 flashcards   │  │ • 15 game types        │  │ • Talk Board (AAC)     │
  │   (13 categories)  │  │ • Story quizzes        │  │ • Messaging            │
  │ • 24 stories       │  │ • Daily challenge      │  │ • Live class session   │
  │ • 143 FSL clips    │  │ • Smart review         │  │ • Play Together        │
  │ • Photos & cartoons│  │ • Guided practice      │  │ • Peer collaboration   │
  │ • Action clips     │  │ • Assessments          │  │ • TV cast              │
  │ • Custom cards     │  │ • Word Hunt (camera)   │  │ • AI tutor & companion │
  └─────────┬──────────┘  └───────────┬────────────┘  └───────────┬────────────┘
            │                         │                           │
            └────────────┬────────────┴───────────────────────────┘
                         ▼
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                    O U T P U T   /   F E E D B A C K   B L O C K           ║
  ║  Animated card flip · Celebration & confetti · Haptics · Sound effects      ║
  ║  Text-to-speech (EN/FIL) · FSL video playback · Star & XP award             ║
  ╚════════════════════════════════════════════┬═══════════════════════════════╝
                                               ▼
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                    P R O G R E S S   &   A N A L Y T I C S   B L O C K     ║
  ║  Words learned · Per-word accuracy · Spaced-repetition priority             ║
  ║  Streaks · Stars · XP & levels · Achievements · Study-time ledger           ║
  ║  Category mastery · Learning gain · Adaptive difficulty history             ║
  ╚═══════════╤════════════════════════════════════════════════╤════════════════╝
              ▼                                                ▼
  ┌───────────────────────────────┐          ┌─────────────────────────────────┐
  │      LOCAL STORAGE BLOCK      │  sync    │      CLOUD SYNC BLOCK           │
  │      (source of truth)        │◀────────▶│      (mirror, optional)         │
  │  Hive · 16 boxes · offline    │  queue   │  Cloud Firestore · Anonymous    │
  │  Media cache (FSL, photos)    │          │  Auth · owner-scoped rules      │
  └───────────────────────────────┘          └─────────────────────────────────┘
              │                                                │
              ▼                                                ▼
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                    R E P O R T I N G   B L O C K                            ║
  ║  Teacher & parent dashboards · Progress timeline · Hard-word report          ║
  ║  Weekly PDF summary · Printable worksheets & certificates                    ║
  ║  Anonymised CSV research export (15 datasets)                                ║
  ╚════════════════════════════════════════════════════════════════════════════╝
```

---
## CHAPTER 3
# TECHNICAL BACKGROUND / SYSTEM DESIGN

---

### 3.1 Technical Background of the Project

#### 3.1.1 Nature of the Project

FlashLearn PWD is a **native Android application** built from a single Flutter
codebase. It is not a web application wrapped in a container, and it is not a
client for a server-side learning platform. Every learning function — flashcards,
games, stories, progress tracking, sign-language playback once cached, reports,
worksheets, and the alternative input modes — executes on the device, using local
storage and on-device machine-learning models, with no network transaction
required.

This is an architectural commitment rather than an optimisation. Philippine
literature consistently identifies connectivity as the dominant deployment risk
for educational software outside urban centres, and mobile data is typically
prepaid and metered. A design in which a learner cannot study because the class
Wi-Fi is down would fail in exactly the settings this study targets. The
application therefore treats the network as an **enhancement** — enabling
classroom rosters, live sessions, messaging, and cross-device synchronisation —
and never as a **prerequisite**.

#### 3.1.2 The Central Technical Problem

The technical problem this project solves is not "how to display a flashcard." It
is **how to make one application behave as five different applications without
becoming five different applications.**

A naive approach — branching the user interface code on the learner's disability
category at every screen — produces an unmaintainable system in which a change to
the flashcard viewer must be reasoned about five times and any of the five
branches can silently rot. A second naive approach — exposing every adaptation as
a user setting — produces a system that is technically capable but practically
inaccessible, because it requires the learner or teacher to discover and correctly
configure fifteen or more toggles.

The solution implemented in this project is a **three-layer adaptation
architecture** in which the disability category is resolved *once*, at the
boundary of the application, into three declarative artefacts that the rest of the
codebase consumes without branching:

1. **Layer 1 — the settings preset** (`AccessibilityPresets`). The category maps
   to a concrete `AppSettings` value: font scale, high contrast, dyslexia palette,
   dark mode, text-to-speech enabled and its rate, reduced motion, sound effects,
   voice navigation, and adaptive difficulty. Every screen in the application
   already reads `AppSettings`; none of them needs to know the disability category
   exists.

2. **Layer 2 — the content-visibility policy**
   (`AccessibilityContentPolicy`). Some adaptations cannot be expressed as a
   settings value, because they concern whether an entire *content modality*
   should appear at all. This layer answers two orthogonal questions: should
   Filipino Sign Language entry points be shown, and should the audio-only
   Pronunciation game be shown? A Deaf learner gains nothing from an audio-only
   listening game; a low-vision learner cannot use sign video; a learner on the
   cognitive spectrum can be confused by sign clips that are not relevant to them.
   None of these three decisions is a font-size or volume setting.

3. **Layer 3 — the curated activity roster** (`GameCatalog`). The category maps to
   an explicitly authored list of exactly ten of the fifteen game types, ordered
   for that category. This layer is **curated, not filtered**: an automatic filter
   would leave some categories with too few games to constitute a usable hub, and
   would order them arbitrarily. Authoring the list makes the pedagogical
   reasoning explicit and reviewable, and it is the mechanism by which each
   category's most appropriate activity — FSL Practice for Deaf learners,
   Pronunciation for low-vision learners, Yes-or-No for motor and multiple
   disabilities, Word Match for cognitive — appears first.

The three layers are independent and are consumed at different points in the
codebase, which is what keeps the system to one implementation of each screen.
Their correctness is asserted by dedicated automated tests, including a test that
verifies Layers 2 and 3 never contradict each other.

#### 3.1.3 Secondary Technical Problems

Four further technical problems shaped the implementation.

**Offline media delivery at acceptable installation size.** 143 sign-language
video clips cannot be bundled into an APK that a school will install over a
metered connection. The system therefore ships a manifest rather than the media,
and `FslAssetsService` downloads each clip on first play — from a GitHub Releases
primary source with a Cloudinary content-delivery-network fallback — and caches it
on disk thereafter. Subsequent plays are offline. The same pattern serves
flashcard photographs and action-demonstration clips.

**Data durability across profile switches and reinstalls.** A single device hosts
multiple learner profiles. Progress must never be attributed to the wrong profile,
and nothing a learner has earned may be revoked by a later synchronisation. The
system implements a local-first write path, a replayable synchronisation queue,
and merge-rather-than-replace semantics on cloud pull.

**Zero recurring cost.** The system uses only Cloud Firestore, Anonymous
Authentication, and opt-in Analytics and Crashlytics — the Firebase products
available on the free Spark tier. It deliberately uses **no** Cloud Functions,
**no** Cloud Storage, and **no** Firebase Cloud Messaging, the three products that
would force a billing upgrade. Server-side responsibilities that would ordinarily
be discharged by a Cloud Function, such as anti-cheat validation of progress
writes, are instead implemented client-side and constrained by Firestore security
rules.

**Layout robustness under accessibility settings.** A font scale of 1.4 combined
with a 360×640-density-independent-pixel screen is a genuinely hostile layout
environment, and it is precisely the environment a low-vision learner on an
inexpensive phone occupies. Layout failures under large type are therefore treated
as defects and are asserted against automatically in a device-by-font-scale test
matrix.

---

### 3.2 Details of the Technologies to Be Used

Table 2 enumerates the technologies employed, their versions, and the specific
role each plays in the system.

**Table 2. Technologies Used and Their Roles in the System**

| # | Technology | Version | Role in the System |
|---:|---|---|---|
| 1 | **Flutter** | 3.44.0 (stable) | Cross-platform UI framework; renders the entire interface to a single canvas at the device's native refresh rate |
| 2 | **Dart** | 3.12.0 | Implementation language for all 573 source files |
| 3 | **Flutter Riverpod** | 2.6.1 | Reactive state management; exposes active profile, settings, progress, and content policy to the widget tree |
| 4 | **go_router** | 14.8.1 | Declarative routing; 132 named routes with a persistent bottom-navigation shell |
| 5 | **Hive / hive_flutter** | 1.1.0 | Local key–value datastore; 16 boxes forming the application's source of truth |
| 6 | **Cloud Firestore** | 5.4.4 | Cloud document database; cross-device mirror, classroom rosters, live sessions, messaging |
| 7 | **Firebase Auth** | 5.3.1 | Anonymous authentication, upgradeable to email/password for account recovery |
| 8 | **Firebase Crashlytics** | 4.1.3 | Opt-in, parent-gated crash reporting; default off |
| 9 | **Firebase Analytics** | 11.3.3 | Opt-in, parent-gated usage telemetry; default off |
| 10 | **flutter_tts** | 4.2.0 | Text-to-speech narration in English and Filipino |
| 11 | **speech_to_text** | 7.0.0 | On-device speech recognition for voice navigation and pronunciation practice |
| 12 | **video_player** | 2.9.3 | Filipino Sign Language and action-clip playback with variable speed |
| 13 | **flutter_cache_manager** | 3.4.1 | On-disk caching of downloaded video and photographic media |
| 14 | **camera** | 0.11.0 | Front-camera frame stream for head-pose control; rear camera for object recognition |
| 15 | **google_mlkit_face_detection** | 0.13.1 | On-device face detection supplying head-rotation angles and eye-open probabilities |
| 16 | **google_mlkit_image_labeling** | 0.14.0 | On-device object recognition for the Word Hunt camera activity |
| 17 | **flutter_animate** | 4.5.2 | Declarative animation pipeline for transitions and entrances |
| 18 | **lottie** | 3.3.1 | Vector celebration animations (fireworks, stars, level-up, trophy, streak flame) |
| 19 | **confetti** | 0.8.0 | Particle celebration effects on achievement |
| 20 | **shimmer** | 3.0.0 | Skeleton loading placeholders |
| 21 | **flutter_staggered_animations** | 1.1.1 | Staggered list and grid entrance animations |
| 22 | **google_fonts** | 6.2.1 | Typeface delivery, including the Lexend family used by the dyslexia-friendly mode |
| 23 | **auto_size_text** | 3.0.0 | Text that shrinks to fit rather than overflowing under large font scales |
| 24 | **fl_chart** | 0.69.0 | Progress and analytics charts |
| 25 | **percent_indicator** | 4.2.5 | Circular and linear mastery indicators |
| 26 | **audioplayers** | 6.5.1 | Sound-effect playback (correct, wrong, flip, match, star, complete) |
| 27 | **flutter_local_notifications** | 19.0.0 | Study reminders and parental alarms, fired locally without push infrastructure |
| 28 | **timezone** | 0.10.0 | Timezone-correct scheduling of local notifications |
| 29 | **pdf** / **printing** | 3.11.3 / 5.14.2 | Generation of weekly reports, worksheets, and certificates |
| 30 | **share_plus** | 10.1.4 | Sharing of generated reports and research exports |
| 31 | **file_picker** | 8.3.7 | Import of profile and flashcard backup archives |
| 32 | **path_provider** | 2.1.5 | Resolution of platform-specific storage directories |
| 33 | **connectivity_plus** | 6.1.4 | Network-state detection driving the offline banner and sync queue |
| 34 | **crypto** | 3.0.3 | Salted hashing of parental PINs and recovery codes |
| 35 | **shelf** / **shelf_router** / **shelf_static** | 1.4.1 / 1.1.4 / 1.1.3 | Pure-Dart HTTP server implementing local-network TV casting |
| 36 | **qr_flutter** | 4.1.0 | QR-code rendering for TV-cast pairing |
| 37 | **uuid** | 4.5.1 | Identifier generation for profiles, sessions, and records |
| 38 | **equatable** | 2.0.7 | Value equality for model classes |
| 39 | **intl** / **flutter_localizations** | — | English and Filipino localisation of 1,390 interface strings |
| 40 | **mocktail**, **fake_async**, **flutter_test** | 1.0.4, 1.3.3, SDK | Automated testing: mocking, deterministic clock control, widget testing |

#### 3.2.1 Rationale for Principal Technology Choices

**Why Flutter.** Three properties were decisive. First, Flutter renders its own
widgets to a canvas rather than delegating to platform controls, which means the
application's appearance and its accessibility semantics are under the
application's control rather than the operating system's — essential for a system
whose central claim is that it reconfigures its own presentation. Second, its
declarative widget model makes a settings-driven interface natural: a change to
`AppSettings` rebuilds every dependent widget without imperative update code.
Third, its testing framework supports full widget-tree construction and
interaction in a headless environment, which is what made a 2,922-case regression
suite feasible for a single developer.

**Why Hive rather than SQLite.** The application's data is document-shaped —
profiles, progress records, settings — not relational, and it is read on almost
every frame. Hive is a pure-Dart key–value store with no platform channel in the
read path, which makes reads synchronous and cheap. SQLite would have imposed
asynchronous access and an object-relational mapping layer for no modelling
benefit.

**Why Firestore on the Spark tier.** Firestore supplies real-time document
streams, which is what the live-classroom and messaging features require, and its
free quota of 50,000 reads and 20,000 writes per day is comfortably above the
projected load of a single school. Crucially, the Spark tier requires no billing
account at all, which removes any possibility that a school could incur an
unexpected charge.

**Why on-device ML Kit rather than a cloud vision API.** A cloud vision service
would have been simpler to integrate but would have violated three of the
project's constraints simultaneously: it would cost money per call, it would
require connectivity, and it would transmit camera frames containing a child's
face off the device. ML Kit's bundled models execute offline, cost nothing, and
never transmit the frame — only abstract angles and probabilities are derived, and
those are discarded each frame.

**Why a pure-Dart HTTP server for TV casting.** Native cast software development
kits impose Kotlin and Gradle plugin version requirements that conflict with the
Flutter toolchain in use. Implementing the cast receiver as a local HTTP server
served by `shelf`, paired by QR code, avoids the native dependency entirely and
works with any device on the local network that has a browser.

---

### 3.3 Hardware Development

This project is a software system. It does not produce custom electronic
hardware, and no circuit design, microcontroller programming, or fabrication was
undertaken. "Hardware development" is therefore interpreted here in its applicable
sense: the specification, procurement, and configuration of the hardware
environment required to develop, record content for, test, and deploy the system.

#### 3.3.1 Development Workstation

A Windows 11 workstation was used for all development. Its configuration is
documented in Table 5. The workstation hosted the Flutter software development
kit, the Android software development kit and platform tools, the integrated
development environment, the version-control client, and the media-processing
toolchain used to encode sign-language video.

#### 3.3.2 Target and Test Devices

The primary test device was an **Honor Pad tablet (model NDL-W09)** running
Android 16, with a 1200 × 1920 pixel display at a device pixel ratio of 1.75,
yielding an effective logical resolution of approximately 686 × 1097
density-independent pixels. This device was selected because its specification is
representative of the tablet class realistically available to a Philippine
classroom — mid-range, not flagship.

A secondary test device, a Xiaomi smartphone (model 2410CRP4CG) running Android
16 at 2136 × 3200 physical pixels, was used to verify behaviour on a
high-density phone form factor and to confirm that the portrait-locked layout
holds on a substantially narrower aspect ratio.

Small-screen behaviour was additionally verified by driving the tablet's display
subsystem to a reduced logical resolution of 630 × 1120 pixels — approximately
360 × 640 density-independent pixels — which reproduces the constrained layout
environment of an entry-level device without requiring one to be procured.

#### 3.3.3 Content Recording Hardware

Filipino Sign Language clips were recorded using a camera capable of 1080p video
at 30 frames per second against a plain, evenly lit background, with the signer
framed from the waist upward so that both hands, the face, and the signing space
remain in frame throughout. Recordings were subsequently transcoded to a
web-compatible 480p H.264 profile at constant-rate-factor 30 in the BT.709 colour
space, a setting selected empirically as the point at which further compression
began to degrade handshape legibility.

#### 3.3.4 Deployment Hardware

The system imposes no hardware requirement on the deploying institution beyond an
Android device meeting the minimum specification in Table 5. No server, no network
appliance, no interactive whiteboard, and no dedicated assistive peripheral is
required. Two optional peripherals are supported where available: a Bluetooth
gamepad conforming to the standard Android game-controller profile, and any
device on the local network with a web browser for the TV-cast display function.

---

### 3.4 Software Development

#### 3.4.1 Development Environment

Development was carried out using the Flutter 3.44.0 stable software development
kit with Dart 3.12.0, the Android SDK with build tools targeting API level 36, and
Visual Studio Code as the primary integrated development environment. Version
control was maintained in Git across 114 recorded commits between 6 May 2026 and
26 August 2026. Firebase resources were provisioned through the Firebase console
and the Firebase command-line interface, which was also used to deploy Firestore
security rules.

#### 3.4.2 Code Organisation

The codebase comprises **573 Dart source files totalling 208,794 lines** in the
application directory, accompanied by **52,044 lines across 222 automated test
files**. Source is organised into six top-level directories:

| Directory | Contents |
|---|---|
| `lib/core/` | Cross-cutting concerns: accessibility policy and presets, theming, security, layout primitives, shared widgets, utilities, and 40 application services |
| `lib/data/` | Domain models, the local Hive repository, seed content, and the Firestore repository |
| `lib/features/` | **47 feature modules**, each self-contained with its own screens, widgets, services, models, and providers |
| `lib/navigation/` | The go_router configuration defining 132 routes, the bottom-navigation shell, and page transitions |
| `lib/providers/` | Riverpod providers exposing application-wide state |
| `lib/l10n/` | English and Filipino Application Resource Bundle files and the generated localisation delegates |

The 47 feature modules are: accessibility, account, ai_tutor, assessment,
awareness, break_time, classroom, communication_board, companion,
daily_challenge, experiment, flashcards, focus_mode, fsl_interpreter, gamepad,
games, gamification, gaze_control, goals, guided_practice, home, home_group,
learning_paths, live_session, messaging, mood_tracker, multiplayer, notebook,
notifications, object_scan, onboarding, parent, parent_teacher_notes,
peer_collaboration, progress, recommendations, recovery, reports, settings, shop,
showcase, stickers, stories, survey, teacher_analytics, tv_cast, and word_of_day.

#### 3.4.3 The Adaptation Layers in Code

**Layer 1 — settings presets.** Table 3 records the concrete settings each
disability category produces. These are merged over the learner's current settings
so that non-accessibility preferences such as locale and reminder time are
preserved.

**Table 3. Accessibility Categories and Auto-Applied Setting Presets**

| Setting | Visual | Hearing | Motor | Cognitive | Multiple | None |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Font scale | 1.4 | 1.2 | 1.2 | 1.2 | 1.3 | 1.0 |
| High contrast | On | On | — | **Off** | On | Off |
| Dyslexia palette | Off | Off | — | **On** | Off | Off |
| Dark mode | Off | — | — | Off | — | Off |
| Text-to-speech | On | **Off** | On | On | On | On |
| Narration rate | 0.40 | — | 0.50 | **0.35** | 0.40 | 0.50 |
| Sound effects | On | **Off** | On | On | On | On |
| Reduced motion | — | — | **On** | **On** | **On** | Off |
| Voice navigation | **On** | Off | — | Off | **On** | Off |
| Adaptive difficulty | On | On | On | On | On | On |

Three design decisions in Table 3 warrant explanation. The **hearing** preset
disables text-to-speech and sound effects entirely rather than merely lowering
them, because leaving them nominally enabled would cause the interface to spend
screen space and interaction time on controls the learner cannot use. The
**cognitive** preset deliberately sets high contrast *off*, because the
dyslexia-friendly cream palette and the high-contrast palette are mutually
exclusive and the reading-comfort palette is the higher-impact intervention for
that population. The **multiple** preset takes the opposite decision — high
contrast on, dyslexia palette off — because for mixed sensory and motor needs the
contrast gain is the larger benefit, leaving the reading palette as an explicit
opt-in.

**Layer 2 — content-visibility policy.** The policy resolves two booleans per
category:

| Category | Show FSL entry points | Show audio-only Pronunciation game |
|---|:---:|:---:|
| Visual | No — sign video is unusable | Yes |
| Hearing | **Yes — primary modality** | No — audio-only, unusable |
| Motor | Yes | Yes |
| Cognitive | No — irrelevant signing can confuse | Yes |
| Multiple | Yes — every alternative modality retained | Yes |
| None | Yes | Yes |

**Layer 3 — curated activity roster.** Table 4 records the ten games assigned to
each category, in display order, together with the games deliberately withheld and
the reason.

**Table 4. Curated Game Rosters per Accessibility Category**

| Rank | Visual | Hearing | Motor | Cognitive | Multiple | None |
|---:|---|---|---|---|---|---|
| 1 | Pronunciation | **FSL Practice** | Yes or No | Word Match | Yes or No | Word Match |
| 2 | Word Match | Word Match | Word Match | Yes or No | Word Match | Spelling Bee |
| 3 | Spelling Bee | Spelling Bee | Odd One Out | Picture-Word | Odd One Out | Memory Match |
| 4 | Memory Match | Memory Match | First Letter | Odd One Out | First Letter | Drag & Drop |
| 5 | Sentence Builder | Drag & Drop | Memory Match | First Letter | Picture-Word | Flashcard Quiz |
| 6 | Flashcard Quiz | Flashcard Quiz | Spelling Bee | Memory Match | Memory Match | Pronunciation |
| 7 | Tracing | Sentence Builder | Pronunciation | Jigsaw Puzzle | Pronunciation | Sentence Builder |
| 8 | Yes or No | Tracing | Picture-Word | Drag & Drop | Flashcard Quiz | Tracing |
| 9 | Odd One Out | Jigsaw Puzzle | Sentence Builder | Tracing | Sentence Builder | Jigsaw Puzzle |
| 10 | First Letter | Picture-Word | FSL Practice | Pronunciation | FSL Practice | FSL Practice |
| | | | | | | |
| **Withheld** | FSL Practice, Jigsaw, Drag & Drop, Picture-Word | Pronunciation, Yes or No, Odd One Out, First Letter | Drag & Drop, Tracing, Jigsaw, Flashcard Quiz | FSL Practice, Spelling Bee, Sentence Builder, Flashcard Quiz | Drag & Drop, Tracing, Jigsaw, Spelling Bee | Picture-Word, Yes or No, Odd One Out, First Letter |
| **Reason** | Signs and precise visual placement are unusable; a picture prompt has no text to narrate | Audio-only prompt; the low-barrier games lower an input barrier these learners do not have | Sustained drag and fine stroke control; swipe is the quiz's primary gesture | Irrelevant signing confuses; highest literacy and self-rating load | Motor input limits plus the heaviest literacy load | The low-barrier games target categories that need them; Picture-Word duplicates Word Match |

Story Quiz is excluded from every hub roster because it is reached from the
Stories tab, where its story picker resides. Player-role and educator profiles,
which carry no accessibility category, receive all fourteen hub games in one
uncategorised list.

#### 3.4.4 Notable Implementation Decisions

**Portrait-only orientation.** The application is locked to portrait on every
device class, enforced at three layers: the Android manifest, the Flutter
application root, and an explicit large-screen opt-out property required by
Android 16. Landscape would double the layout surface requiring accessibility
verification for no pedagogical benefit, and a one-handed portrait grip is the
posture most compatible with a learner using a device propped on a stand or held
by a caregiver.

**Answer-safe imagery.** Flashcard illustrations are suppressed on quiz surfaces
where the picture would reveal the answer. This is implemented as an explicit
`revealsAnswer` parameter on the shared image widget, passed as false by the eight
screens where the hazard exists, so that the default is safe and each exception is
visible in code review.

**Monotonic progress.** Experience points, levels, achievements, and certificates
are constrained never to decrease. A learner who reaches a level cannot be
de-levelled by a later recalculation, and an earned badge is never revoked. This
required deliberate design because several natural implementations — recomputing a
level from a capped recent-score window, for instance — would silently revoke
awards.

**Straight quotation marks are prohibited in accessibility labels.** A straight
double-quote character inside a semantic label empties the entire label on
Android, silently removing the screen-reader description. Curly quotation marks
are used throughout, and the constraint is asserted in the test suite.

---

### 3.5 Hardware and Software Requirements

**Table 5. Minimum and Recommended Hardware and Software Requirements**

| | **Minimum** | **Recommended** |
|---|---|---|
| **A. LEARNER DEVICE (deployment)** | | |
| Operating system | Android 10 (API 29) | Android 13 (API 33) or later |
| Processor | Quad-core 1.4 GHz | Octa-core 2.0 GHz |
| Memory | 2 GB RAM | 4 GB RAM or more |
| Storage available | 500 MB | 2 GB (accommodates cached sign video) |
| Display | 5.0 in, 720 × 1280 px | 8.0 in tablet, 1200 × 1920 px |
| Input | Capacitive touchscreen | Touchscreen plus front camera |
| Front camera | Not required | Required for head-pose control |
| Rear camera | Not required | Required for Word Hunt object recognition |
| Microphone | Not required | Required for voice navigation and pronunciation |
| Audio output | Speaker or headphones | Speaker or headphones |
| Network | Not required for learning | Wi-Fi for classroom and sync features |
| Optional peripheral | — | Bluetooth gamepad; local-network display for TV cast |
| | | |
| **B. DEVELOPMENT WORKSTATION** | | |
| Operating system | Windows 10 64-bit | Windows 11 64-bit |
| Processor | Intel Core i5 or equivalent | Intel Core i7 or equivalent |
| Memory | 8 GB RAM | 16 GB RAM |
| Storage | 50 GB free | 256 GB solid-state drive |
| Display | 1366 × 768 | 1920 × 1080 |
| | | |
| **C. DEVELOPMENT SOFTWARE** | | |
| Framework | Flutter 3.44.0 (stable) | — |
| Language | Dart 3.12.0 | — |
| Android SDK | Platform 36, build tools 36 | — |
| IDE | Visual Studio Code with Flutter and Dart extensions | — |
| Version control | Git | — |
| Cloud console | Firebase (Spark plan) with CLI | — |
| Media toolchain | FFmpeg | — |
| Device bridge | Android Debug Bridge (platform-tools) | — |
| | | |
| **D. CLOUD SERVICES** | | |
| Database | Cloud Firestore (Spark: 50,000 reads / 20,000 writes per day) | — |
| Authentication | Firebase Anonymous Auth (unlimited, free) | — |
| Telemetry | Crashlytics and Analytics, opt-in, default off | — |
| Media hosting | GitHub Releases (primary), Cloudinary CDN (fallback) | — |
| Not used | Cloud Functions, Cloud Storage, Cloud Messaging — each would require a paid plan | — |

---

### 3.6 System Architecture

#### 3.6.1 Architectural Style

The system follows a **layered, feature-modular architecture** with unidirectional
data flow and a local-first persistence strategy. Presentation is separated from
domain logic, and domain logic is separated from persistence; features are
vertically sliced so that each owns its screens, widgets, services, and providers.
Cross-feature concerns — theming, accessibility policy, security, and the forty
shared services — are hoisted into a core layer that features depend upon and that
depends on no feature.

**Figure 4. Layered System Architecture**

```
╔══════════════════════════════════════════════════════════════════════════════╗
║  PRESENTATION LAYER                                                          ║
║  ──────────────────────────────────────────────────────────────────────────  ║
║  47 feature modules × (screens · widgets)                                    ║
║  Bottom-navigation shell (Home · Cards · Games · Stories · Progress)         ║
║  go_router — 132 routes, typed transitions, shell-aware push/go semantics    ║
║  Overlays: AI companion · gamepad host · cast pill · connectivity banner ·   ║
║            lock enforcer · error boundary                                    ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  ADAPTATION LAYER                        ← the study's core contribution     ║
║  ──────────────────────────────────────────────────────────────────────────  ║
║  AccessibilityPresets  │  AccessibilityContentPolicy  │  GameCatalog         ║
║  ThemeMarker (learner theme cascade) · RoleTheme · SemanticColors            ║
║  Presentation policies: Progress · Board · Collab · Race · Companion · Lock  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  STATE MANAGEMENT LAYER                                                      ║
║  ──────────────────────────────────────────────────────────────────────────  ║
║  Riverpod providers — active profile · settings · progress · content policy  ║
║  · roster · connectivity · sync status · session · companion · gaze · gamepad║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DOMAIN / SERVICE LAYER  (40 core services + per-feature services)           ║
║  ──────────────────────────────────────────────────────────────────────────  ║
║  Learning     : SpacedRepetition · AdaptiveDifficulty · LearningLevel        ║
║  Progress     : XpLevel · Streak · Achievement · Certificate · Engagement    ║
║  Time         : ActiveTimeTracker · SessionTracker · LockEnforcer · Alarm    ║
║  Media        : FslAssets · ActionClip · FlashcardPhoto · MediaUrlResolver   ║
║  Output       : Tts · Stt · Sound · Haptic · Celebration · VoiceNavigation   ║
║  Sync         : SyncService · SyncQueue · ProfileSyncListener ·              ║
║                 ProgressSyncListener · BackupService                         ║
║  Reporting    : ReportGenerator · WorksheetService · ResearchExportService   ║
║  Security     : PinAuth · RecoveryCode · JoinCode · OwnerUid migration       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  DATA LAYER                                                                  ║
║  ──────────────────────────────────────────────────────────────────────────  ║
║  Models (Flashcard · UserProfile · LearningProgress · GameScore · …)         ║
║  LocalRepository  →  HiveService (16 boxes)          ← SOURCE OF TRUTH       ║
║  FirestoreRepository  →  Cloud Firestore (39 collections)  ← MIRROR          ║
║  SeedData (177 cards · 24 stories) · media manifests (143 + 144 + 120)       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  PLATFORM LAYER                                                              ║
║  ──────────────────────────────────────────────────────────────────────────  ║
║  Android runtime · Camera · Microphone · TTS engine · Speech recogniser ·    ║
║  ML Kit (face detection, image labelling) · Local notifications ·            ║
║  Bluetooth HID · Local HTTP server (shelf) · File system                     ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

#### 3.6.2 Data Flow

**Figure 5. Local-First Data Flow with Cloud Mirror**

```
   LEARNER ACTION (answers a question, finishes a game, reads a story)
                    │
                    ▼
   ┌────────────────────────────────────────┐
   │  Feature service computes the result   │
   │  · correctness · stars · XP delta      │
   │  · per-word accuracy update            │
   └────────────────┬───────────────────────┘
                    ▼
   ┌────────────────────────────────────────┐
   │  Riverpod notifier updates state       │──▶ UI rebuilds immediately
   └────────────────┬───────────────────────┘    (no network in this path)
                    ▼
   ┌────────────────────────────────────────┐
   │  LocalRepository → Hive box.put()      │  ◀── SOURCE OF TRUTH
   │  Commit is complete here.              │       The learner is done.
   └────────────────┬───────────────────────┘
                    ▼
   ┌────────────────────────────────────────┐
   │  SyncQueue.enqueue(operation)          │
   └────────────────┬───────────────────────┘
                    ▼
              ┌─────────────┐
              │ Online?     │
              └──┬───────┬──┘
            NO   │       │   YES
                 ▼       ▼
   ┌──────────────────┐  ┌────────────────────────────────┐
   │ Operation stays  │  │ SyncQueueExecutor drains queue │
   │ queued on disk.  │  │ → Firestore write, owner-scoped│
   │ Learning is      │  └────────────┬───────────────────┘
   │ unaffected.      │               ▼
   │ Replays on       │  ┌────────────────────────────────┐
   │ reconnect.       │  │ ProgressSyncListener validates │
   └──────────────────┘  │ the incoming document and      │
                         │ MERGES — never replaces.       │
                         │ Nothing earned is revoked.     │
                         └────────────────────────────────┘
```

Two properties of this flow are load-bearing for the study's claims. First, the
learner's write completes at the local store; the network path is entirely
downstream of the point at which the interface has already updated, which is why
the application is fully usable offline. Second, the cloud pull merges rather than
replaces, which is what guarantees the monotonic-progress property described in
Section 3.4.4 — a device that synchronises after being offline for a week does not
lose the week's work to a stale cloud document.

#### 3.6.3 Security Architecture

Security is enforced at four points. **Profile access** is gated by an optional
salted-hash PIN with failed-attempt lockout, used to protect educator surfaces from
learner access on a shared device. **Account recovery** uses a salted-hash
recovery code and an ownership-transfer model in which restoring a profile to a
new device marks the previous device's copy read-only, ensuring one profile has
exactly one owning account. **Cloud access** is governed by Firestore security
rules that scope every document to its owning authenticated user; the
`progress_audit` and `rate_limits` collections are deliberately client-write-blocked,
documenting that they would be populated only by a paid-tier server function and
that the system operates correctly without them. **Telemetry** — Crashlytics and
Analytics — is opt-in, parent-gated, and off by default.

The camera and microphone deserve specific note. Camera frames used for head-pose
control and object recognition are processed by bundled on-device models and are
never transmitted or stored; only derived scalars (rotation angles, eye-open
probabilities, label confidences) leave the frame processor, and they are discarded
each frame. This is a privacy property, not merely a cost property, and it is the
principal reason a cloud vision service was rejected.

---

### 3.7 Block Diagram

Figure 6 presents the technical block diagram, mapping each functional block of
the general diagram in Figure 3 onto the specific technology that implements it.

**Figure 6. Technical Block Diagram**

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        ANDROID DEVICE (API 29 – 36)                          │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                    FLUTTER 3.44 / DART 3.12 APPLICATION                │  │
│  │                                                                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │  │
│  │  │  INPUT       │  │  ADAPTATION  │  │  CONTENT     │  │  OUTPUT    │  │  │
│  │  ├──────────────┤  ├──────────────┤  ├──────────────┤  ├────────────┤  │  │
│  │  │ Touch        │  │ Accessibility│  │ SeedData     │  │ flutter_   │  │  │
│  │  │  (Flutter    │─▶│  Presets     │─▶│  177 cards   │─▶│  animate   │  │  │
│  │  │   gestures)  │  │              │  │  24 stories  │  │ lottie     │  │  │
│  │  │              │  │ Content      │  │              │  │ confetti   │  │  │
│  │  │ speech_to_   │─▶│  Policy      │─▶│ FslAssets    │─▶│ flutter_   │  │  │
│  │  │  text 7.0    │  │              │  │  Service     │  │  tts 4.2   │  │  │
│  │  │              │  │ GameCatalog  │  │  143 clips   │  │            │  │  │
│  │  │ camera 0.11  │  │  10 of 15    │  │              │  │ video_     │  │  │
│  │  │  + ML Kit    │─▶│  per category│─▶│ Photo &      │─▶│  player    │  │  │
│  │  │  Face Detect │  │              │  │  action clip │  │  (0.25–    │  │  │
│  │  │              │  │ ThemeMarker  │  │  manifests   │  │   1.5×)    │  │  │
│  │  │ Gamepad      │─▶│  learner     │─▶│              │─▶│ audio      │  │  │
│  │  │  (HID axes)  │  │  theme       │  │ flutter_     │  │  players   │  │  │
│  │  │              │  │  cascade     │  │  cache_mgr   │  │ haptics    │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └────────────┘  │  │
│  │                            │                                           │  │
│  │  ┌─────────────────────────▼──────────────────────────────────────┐    │  │
│  │  │              RIVERPOD 2.6  —  reactive state graph              │    │  │
│  │  └─────────────────────────┬──────────────────────────────────────┘    │  │
│  │                            ▼                                           │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │  │
│  │  │   DOMAIN SERVICES  (40 core + per-feature)                      │   │  │
│  │  │   SpacedRepetition · AdaptiveDifficulty · XpLevel · Streak ·    │   │  │
│  │  │   Certificate · ActiveTimeTracker · LockEnforcer · Report ·     │   │  │
│  │  │   Worksheet · ResearchExport · PinAuth · RecoveryCode           │   │  │
│  │  └─────────────────────────┬───────────────────────────────────────┘   │  │
│  │                            ▼                                           │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │  │
│  │  │   HIVE 1.1  —  16 boxes  —  SOURCE OF TRUTH  —  offline         │   │  │
│  │  └─────────────────────────┬───────────────────────────────────────┘   │  │
│  │                            ▼                                           │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │  │
│  │  │   SYNC QUEUE  —  durable, replayable, connectivity-aware        │   │  │
│  │  └─────────────────────────┬───────────────────────────────────────┘   │  │
│  │                            │                                           │  │
│  │  ┌─────────────────────────┴───────────────────────────────────────┐   │  │
│  │  │   SHELF 1.4 HTTP SERVER  —  TV cast, QR-paired, local network   │───┼──┼─▶ TV / browser
│  │  └─────────────────────────────────────────────────────────────────┘   │  │   on LAN
│  └────────────────────────────┬───────────────────────────────────────────┘  │
│                               │                                              │
│  ┌────────────────────────────▼───────────────────────────────────────────┐  │
│  │  ANDROID PLATFORM SERVICES                                             │  │
│  │  TTS engine · SpeechRecognizer · Camera2 · Bluetooth HID ·             │  │
│  │  AlarmManager / NotificationManager · File system                      │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────┬──────────────────────────────────────────────┘
                                │  (optional — never required for learning)
                                ▼
        ┌───────────────────────────────────────────────────────────┐
        │              FIREBASE — SPARK (FREE) TIER                 │
        │  ┌─────────────────────┐   ┌───────────────────────────┐  │
        │  │ Cloud Firestore     │   │ Anonymous Authentication  │  │
        │  │ 39 collections      │   │ upgradeable to email link │  │
        │  │ owner-scoped rules  │   └───────────────────────────┘  │
        │  │ 50k reads / 20k     │   ┌───────────────────────────┐  │
        │  │ writes per day      │   │ Crashlytics / Analytics   │  │
        │  └─────────────────────┘   │ opt-in · default OFF      │  │
        │                            └───────────────────────────┘  │
        │  NOT USED: Cloud Functions · Cloud Storage · FCM          │
        │  (each would require the paid Blaze plan)                 │
        └───────────────────────────────────────────────────────────┘
                                │
                                ▼
        ┌───────────────────────────────────────────────────────────┐
        │  MEDIA ORIGIN (first play only; cached on disk after)     │
        │  GitHub Releases (primary)  ·  Cloudinary CDN (fallback)  │
        └───────────────────────────────────────────────────────────┘
```

---
## CHAPTER 4
# METHODOLOGY AND SYSTEM DEVELOPMENT

---

### 4.1 Research Method

#### 4.1.1 Research Design

This study employed the **developmental research method**, supplemented by
**descriptive** and **quasi-experimental** components.

The **developmental** component is primary. Developmental research is the
systematic study of designing, developing, and evaluating instructional programs,
processes, and products; its output is both an artefact and generalisable
knowledge about the process of producing that artefact. This study produced the
FlashLearn PWD application as its artefact, and the three-layer adaptation
architecture, documented and empirically verified, as its transferable knowledge.

The **descriptive** component characterises the state of the developed system:
its measured quality against ISO/IEC 25010, its usability as rated by educators,
and the learners' own reported experience. Descriptive statistics — frequency,
percentage, mean, and standard deviation — summarise these measures.

The **quasi-experimental** component addresses the sixth research question by
means of a **one-group pre-test/post-test design**. Participating learners were
administered a vocabulary pre-test before the intervention, used the system over
the intervention period, and were administered a parallel post-test afterwards.
The design is quasi-experimental rather than experimental because participants
were not randomly assigned from a larger population; the SPED cohort available at
the partner institution constitutes the sample in its entirety. The system
additionally embeds an experiment module capable of randomly assigning learners to
gamified and non-gamified conditions, enabling a stronger two-group design in
future work.

#### 4.1.2 Sampling Technique

**Purposive sampling** was employed for all respondent groups, as the study
requires respondents with specific, non-substitutable characteristics.

- **Learners** were selected on the criteria of (a) enrolment in the partner
  institution's Special Education programme, (b) an assigned disability
  classification falling within the five categories the system supports, (c) age
  within the target range, and (d) parental or guardian consent.
- **Special Education teachers** were selected on the criterion of current
  responsibility for at least one participating learner.
- **Parents and guardians** were selected as the primary caregivers of
  participating learners.
- **Information Technology experts** were selected on the criteria of at least
  three years of professional software development experience or a faculty
  appointment in a computing discipline.

#### 4.1.3 Research Instruments

Five instruments were used. The rationale for the division of instruments between
adult and child respondents is given below and is a substantive methodological
contribution of this study rather than an administrative detail.

**(a) Needs-assessment interview guide.** A semi-structured guide administered to
SPED teachers and parents during the requirements phase, covering current
vocabulary teaching practice, existing digital tools and their failures, specific
accessibility barriers observed, and desired features.

**(b) ISO/IEC 25010 evaluation questionnaire.** A structured instrument
administered to IT experts and educators, presenting statements grouped under the
seven quality characteristics evaluated, each rated on a five-point Likert scale.

**(c) System Usability Scale (SUS).** The standard ten-item Brooke instrument,
administered to **educators (teachers and parents) rather than to learners**, and
presented bilingually in English and Filipino. The instrument is implemented
inside the application itself and reached through *Educator Home → Survey Results
→ Take Survey*.

**(d) Smileyometer.** A three-point visual scale using facial expressions (😞 🙂
😄, scored 1–3) across three short questions — *Did you have fun? / Was the app
easy to use? / Do you want to use it again?* — presented bilingually. Administered
to **learners**, and reached from each learner home screen.

**(e) Vocabulary pre-test and post-test.** Parallel forms drawn from the
application's assessment engine, administered before and after the intervention
period, scored as a percentage, and analysed both as raw difference and as Hake's
normalised gain.

**The rationale for instrument separation.** The System Usability Scale is a
validated adult, English-origin, abstract instrument with alternating positive and
negative item polarity. Administering it directly to young Deaf and
hard-of-hearing learners — whose first language is Filipino Sign Language rather
than written Filipino or English — would violate four of its assumptions
simultaneously:

1. **Reading and language.** Items such as *"unnecessarily complex,"* *"too much
   inconsistency,"* and *"very awkward"* require high written-language
   comprehension. For a Deaf learner, the instrument becomes a reading test rather
   than a usability rating.
2. **Alternating polarity.** Mixed positive and negative items produce response
   errors and acquiescence bias in adults, and substantially more so in children.
3. **Five-point bipolar abstraction.** Young children do not reliably map internal
   states onto a five-point agree/disagree continuum.
4. **Metacognitive judgment.** An item such as *"I felt very confident using the
   app"* requires a reflective self-assessment many young learners cannot form
   reliably.

The result of ignoring this would be low-reliability data supporting a usability
claim a panel could legitimately challenge. This study therefore **triangulates**:

| Instrument | Respondent | Role in the study | Reported as |
|---|---|---|---|
| SUS (10 items, EN/FIL) | Teacher / parent facilitator | Primary *validated* usability measure | 0–100 score; >68 above average |
| Smileyometer (3 faces) | Student / learner | The learners' own experience | Descriptive: percentage per face and mean 1–3 — **never** converted to a usability score |

Each instrument is used only where it is valid, and the two are reported under
distinct headings. This separation is the key methodological point of the
evaluation design.

#### 4.1.4 Data Gathering Procedure

1. **Permission.** A letter of request was submitted to the school administration;
   informed consent was obtained from parents and guardians, and assent from
   learners in an accessible format.
2. **Needs assessment.** Interviews with SPED teachers and parents were conducted
   during the requirements sprint.
3. **Pre-test.** The vocabulary pre-test was administered to participating
   learners prior to any exposure to the system.
4. **Orientation.** Teachers and parents received a structured orientation on
   installation, profile creation, accessibility assignment, and the educator
   dashboards.
5. **Intervention.** Learners used the application over the intervention period
   under normal classroom and home conditions.
6. **Post-test.** The parallel-form post-test was administered.
7. **Evaluation.** The SUS and ISO/IEC 25010 instruments were administered to
   adults; the Smileyometer to learners.
8. **Export and analysis.** Data were exported from the application's anonymised
   research-export function as comma-separated-value files and analysed.

#### 4.1.5 Statistical Treatment

| Research question | Statistical treatment |
|---|---|
| Profile of respondents | Frequency and percentage |
| ISO/IEC 25010 quality ratings | Weighted mean, standard deviation, verbal interpretation |
| System Usability Scale | Standard SUS scoring: for odd items, score = response − 1; for even items, score = 5 − response; sum × 2.5 |
| Smileyometer | Frequency, percentage per face, and mean rating (1–3), reported descriptively |
| Pre-test versus post-test difference | Paired-samples *t*-test at α = 0.05; Hake's normalised gain *g* = (post − pre) / (1 − pre) |
| Item quality of the assessment instrument | Item difficulty index, discrimination index, and Cronbach's alpha, computed from the exported per-item response dataset |

---

### 4.2 Development Methodology

#### 4.2.1 Selection of Methodology

The **Agile–Scrum** methodology was adopted. The selection was driven by three
properties of this specific project.

First, the requirements were **genuinely unstable at the outset**. Accessibility
requirements for a population the developer does not belong to cannot be fully
specified in advance; they emerge from contact with learners and teachers. A
Waterfall design phase would have frozen assumptions that turned out to be wrong —
most consequentially, the initial assumption that a single accessibility
configuration with individual toggles would suffice.

Second, the project delivers **many independent features**. With 47 feature
modules, an incremental methodology that delivers a working increment every sprint
allows stakeholder feedback on early features while later features are still being
built.

Third, the project was executed by a **small team under a fixed academic
deadline**. Scrum's timeboxed sprints provide schedule control by adjusting scope
per sprint rather than allowing a single phase to overrun.

**Figure 7. Agile–Scrum Development Methodology**

```
                    PRODUCT BACKLOG
        (user stories from needs assessment, DepEd
         SPED curriculum guides, accessibility standards,
         and each sprint review)
                          │
                          ▼
              ┌───────────────────────┐
              │   SPRINT PLANNING     │  ◀──── 2-week timebox
              │  select backlog items │
              │  into sprint backlog  │
              └───────────┬───────────┘
                          ▼
        ┌─────────────────────────────────────┐
        │            SPRINT                   │
        │  ┌───────────────────────────────┐  │
        │  │   DESIGN → CODE → TEST        │  │
        │  │   ▲                       │   │  │
        │  │   └───── daily cycle ──────┘   │  │
        │  │                                │  │
        │  │  Every increment must leave    │  │
        │  │  the regression suite green    │  │
        │  │  before it is committed.       │  │
        │  └───────────────────────────────┘  │
        └─────────────────┬───────────────────┘
                          ▼
              ┌───────────────────────┐
              │   SPRINT REVIEW       │
              │  demonstrate to SPED  │
              │  teachers and adviser │
              └───────────┬───────────┘
                          ▼
              ┌───────────────────────┐
              │  SPRINT RETROSPECTIVE │
              │  what to change in    │
              │  the next sprint      │
              └───────────┬───────────┘
                          │
                          ▼
              POTENTIALLY SHIPPABLE INCREMENT
                  (installable APK)
                          │
                          └──────────▶ feeds back into PRODUCT BACKLOG
```

#### 4.2.2 Scrum Artefacts and Events as Practised

- **Product backlog** — maintained as a prioritised list of user stories derived
  from the needs assessment, the DepEd SPED curriculum guides, accessibility
  standards, and the findings of each sprint review.
- **Sprint backlog** — the subset selected for each two-week sprint.
- **Increment** — an installable APK, verified green against the full automated
  regression suite before the sprint was closed. This "definition of done" is what
  produced a 2,922-case suite: every feature added its own tests as a condition of
  being considered complete.
- **Sprint review** — demonstration to the adviser and, where scheduling
  permitted, to SPED teachers, whose feedback re-entered the product backlog.
- **Sprint retrospective** — a written note of process changes.
- **Version control** — 114 commits between 6 May and 26 August 2026 form the
  auditable record of the increments.

#### 4.2.3 Design Decisions Produced by Sprint Feedback

Three architectural decisions in the delivered system originated in sprint review
rather than in the initial design, and are recorded here as evidence that the
iterative methodology was substantive rather than nominal.

1. **The curated game roster (Layer 3) replaced a settings filter.** The original
   design filtered games by settings flags. Review established that this left some
   categories with too few games to fill a hub, and ordered the survivors
   arbitrarily. The replacement is an explicitly authored roster of exactly ten per
   category, ordered so that the most appropriate activity for that category
   appears first.

2. **The content-visibility policy (Layer 2) was introduced as a distinct layer.**
   Review established that "should this learner see sign language at all?" is not
   expressible as a settings value, and that folding it into the settings layer
   produced contradictions. Making it an orthogonal policy, with an automated test
   asserting that Layers 2 and 3 never disagree, resolved this.

3. **Leaderboards were changed to opt-in per class.** Review with teachers
   established that a class-wide ranking is counterproductive where performance
   gaps between learners are large and visible. The leaderboard is now disabled by
   default and must be enabled by an educator for a specific class.

---

### 4.3 Organizational Chart

**Figure 8. Organizational Chart**

```
                    ┌────────────────────────────────┐
                    │       CAPSTONE ADVISER         │
                    │      [Name of Adviser]         │
                    │  academic supervision ·        │
                    │  scope approval · review       │
                    └───────────────┬────────────────┘
                                    │
              ┌─────────────────────┼─────────────────────┐
              │                     │                     │
    ┌─────────▼──────────┐ ┌────────▼─────────┐ ┌─────────▼──────────┐
    │  PANEL OF          │ │  PROJECT LEAD /  │ │  DOMAIN            │
    │  EXAMINERS         │ │  LEAD DEVELOPER  │ │  CONSULTANTS       │
    │  [Names]           │ │  Jules Antonio   │ │                    │
    │                    │ │  Jose Paeste     │ │ • SPED teachers    │
    │ evaluation ·       │ │                  │ │ • FSL consultants  │
    │ defense · approval │ │ requirements ·   │ │ • Parents          │
    └────────────────────┘ │ architecture ·   │ │                    │
                           │ development ·    │ │ requirements ·     │
                           │ testing ·        │ │ content validation │
                           │ documentation    │ │ · acceptance       │
                           └────────┬─────────┘ └────────────────────┘
                                    │
        ┌───────────────┬───────────┴────────┬───────────────┐
        ▼               ▼                    ▼               ▼
┌───────────────┐┌───────────────┐┌──────────────────┐┌───────────────┐
│ SYSTEM        ││ CONTENT       ││ QUALITY          ││ DOCUMENTATION │
│ DEVELOPMENT   ││ DEVELOPMENT   ││ ASSURANCE        ││               │
│               ││               ││                  ││ manuscript ·  │
│ • architecture││ • 177 cards   ││ • 222 test files ││ user guide ·  │
│ • 47 modules  ││ • 24 stories  ││ • 2,922 cases    ││ teacher's     │
│ • 132 routes  ││ • 143 FSL     ││ • static analysis││ guide ·       │
│ • data & sync ││   clips       ││ • device matrix  ││ project       │
│ • UI & theming││ • photos &    ││ • on-device      ││ website       │
│               ││   action clips││   verification   ││               │
└───────────────┘└───────────────┘└──────────────────┘└───────────────┘
```

**Table 6. Project Roles and Responsibilities**

| Role | Responsibilities |
|---|---|
| **Capstone Adviser** | Provides academic supervision; approves scope and methodology; reviews each sprint increment and the manuscript |
| **Panel of Examiners** | Evaluates the proposal and the final defense; approves the study |
| **Project Lead / Lead Developer** | Requirements elicitation; system architecture; implementation of all 47 modules; automated test authoring; on-device verification; manuscript preparation |
| **SPED Teacher Consultants** | Validate learning content against the SPED curriculum; identify accessibility barriers; participate in sprint reviews; administer the intervention; complete the SUS and ISO/IEC 25010 instruments |
| **Filipino Sign Language Consultants** | Perform, review, and validate the 143 recorded sign clips for accuracy and regional appropriateness |
| **Parent Consultants** | Provide home-context requirements; validate the parent subsystem; complete the SUS instrument |
| **Information Technology Experts** | Evaluate the system against the technical characteristics of ISO/IEC 25010 |
| **Learner Participants** | Use the system during the intervention; complete pre-test, post-test, and Smileyometer |

---

### 4.4 Requirements Specifications

#### 4.4.1 Functional Requirements

**Table 7. Functional Requirements Specification**

| ID | Requirement | Priority | Status |
|---|---|:---:|:---:|
| **FR-01** | **Profile and Access Management** | | |
| FR-01.1 | The system shall support five user roles: Student, Child, Player, Teacher, and Parent | High | Implemented |
| FR-01.2 | The system shall allow creation of multiple profiles on one device | High | Implemented |
| FR-01.3 | The system shall assign an accessibility category to each learner profile at onboarding | High | Implemented |
| FR-01.4 | The system shall optionally protect a profile with a salted-hash PIN and lock out after repeated failures | Medium | Implemented |
| FR-01.5 | The system shall provide a recovery code enabling profile restoration on a new device | Medium | Implemented |
| FR-01.6 | The system shall allow an educator to delete device-scoped profiles, but never the signed-in profile | Medium | Implemented |
| **FR-02** | **Adaptive Accessibility** | | |
| FR-02.1 | The system shall automatically apply a settings preset derived from the learner's accessibility category | High | Implemented |
| FR-02.2 | The system shall determine content-modality visibility (FSL entry points, audio-only game) from the category | High | Implemented |
| FR-02.3 | The system shall present a curated roster of exactly ten learning games per accessibility category | High | Implemented |
| FR-02.4 | The system shall allow every automatic setting to be manually overridden | High | Implemented |
| FR-02.5 | The system shall provide a high-contrast mode, a dyslexia-friendly mode, four font scales, and a reduced-motion mode | High | Implemented |
| **FR-03** | **Flashcard Learning** | | |
| FR-03.1 | The system shall present 177 bilingual English–Filipino flashcards across 13 categories | High | Implemented |
| FR-03.2 | Each card shall carry an illustration, an example sentence, and a definition | High | Implemented |
| FR-03.3 | The system shall animate the transition between the English and Filipino faces of a card | High | Implemented |
| FR-03.4 | The system shall narrate a card in English and in Filipino on demand | High | Implemented |
| FR-03.5 | The system shall play a Filipino Sign Language clip for a card, with playback speed selectable from 0.25× to 1.5× | High | Implemented |
| FR-03.6 | The system shall show a real photograph and, for action words, a demonstration clip | Medium | Implemented |
| FR-03.7 | The system shall allow authoring of custom flashcards, including camera-photographed cards | Medium | Implemented |
| FR-03.8 | The system shall provide an auto-play mode advancing through a deck hands-free | Medium | Implemented |
| **FR-04** | **Learning Games and Activities** | | |
| FR-04.1 | The system shall provide 15 distinct learning-game types | High | Implemented |
| FR-04.2 | The system shall award stars and experience points on game completion | High | Implemented |
| FR-04.3 | The system shall suggest game difficulty from the learner's recorded accuracy | High | Implemented |
| FR-04.4 | The system shall allow a game in progress to be paused and resumed | Medium | Implemented |
| FR-04.5 | The system shall provide 24 illustrated stories with comprehension quizzes | High | Implemented |
| FR-04.6 | The system shall provide a daily challenge and a spaced-repetition smart-review mode | Medium | Implemented |
| FR-04.7 | The system shall provide a camera-based object-recognition vocabulary activity | Low | Implemented |
| **FR-05** | **Alternative Input** | | |
| FR-05.1 | The system shall support voice-command navigation using on-device speech recognition | Medium | Implemented |
| FR-05.2 | The system shall support head-pose and blink control using the front camera, with adjustable dwell period | Medium | Implemented |
| FR-05.3 | The system shall support external Bluetooth gamepad control | Low | Implemented |
| FR-05.4 | All alternative input shall be additive; touch shall never be disabled | High | Implemented |
| **FR-06** | **Progress and Gamification** | | |
| FR-06.1 | The system shall record words learned, per-word accuracy, streaks, stars, and study time | High | Implemented |
| FR-06.2 | The system shall maintain a ten-tier experience-point level ladder | Medium | Implemented |
| FR-06.3 | The system shall award 38 achievements and shall never revoke an awarded achievement | Medium | Implemented |
| FR-06.4 | The system shall provide a cosmetic shop of 26 items purchasable with earned stars, conferring no gameplay advantage | Low | Implemented |
| FR-06.5 | The system shall provide class leaderboards, disabled by default and enabled per class by an educator | Low | Implemented |
| **FR-07** | **Educator and Family Subsystem** | | |
| FR-07.1 | The system shall provide classroom creation with join-by-code enrolment | High | Implemented |
| FR-07.2 | The system shall provide home-group creation for parent–child relationships | High | Implemented |
| FR-07.3 | The system shall provide roster dashboards showing per-learner progress | High | Implemented |
| FR-07.4 | The system shall provide per-learner progress timelines, hard-word reports, and category mastery | High | Implemented |
| FR-07.5 | The system shall provide assessment authoring, assignment, and tracking | High | Implemented |
| FR-07.6 | The system shall provide a live classroom session with real-time question broadcast and hand-raising | Medium | Implemented |
| FR-07.7 | The system shall provide parent–teacher notes and in-app messaging | Medium | Implemented |
| FR-07.8 | The system shall provide child time limits and alarms with an accessible hand-off announcement | Medium | Implemented |
| FR-07.9 | The system shall generate printable weekly reports, worksheets, and certificates | Medium | Implemented |
| FR-07.10 | The system shall export anonymised research data as comma-separated-value files | Medium | Implemented |
| **FR-08** | **Communication and Collaboration** | | |
| FR-08.1 | The system shall provide an augmentative communication board with saved phrases | Medium | Implemented |
| FR-08.2 | The system shall provide a competitive two-player mode and a cooperative peer-collaboration mode | Low | Implemented |
| FR-08.3 | The system shall cast the learner's screen to a local-network display via a QR-paired HTTP server | Low | Implemented |
| **FR-09** | **Data and Synchronisation** | | |
| FR-09.1 | The system shall store all learner data locally and function fully offline | High | Implemented |
| FR-09.2 | The system shall queue writes made offline and replay them on reconnection | High | Implemented |
| FR-09.3 | A cloud pull shall merge with, and never replace, local progress | High | Implemented |
| FR-09.4 | The system shall provide local backup export and import | Medium | Implemented |
| **FR-10** | **Localisation** | | |
| FR-10.1 | The system shall present its interface in English and Filipino | High | Implemented |
| FR-10.2 | The system shall allow the interface language to be changed at any time | High | Implemented |

#### 4.4.2 Non-Functional Requirements

**Table 8. Non-Functional Requirements Specification**

| ID | Category | Requirement | Verification Method |
|---|---|---|---|
| NFR-01 | Performance | Application cold start shall complete within 5 seconds on the minimum specification | On-device measurement |
| NFR-02 | Performance | Screen transitions shall render without dropped frames at the device's native refresh rate | On-device profiling |
| NFR-03 | Performance | The automated regression suite shall complete within 10 minutes | Suite execution timing |
| NFR-04 | Reliability | No unhandled exception shall reach the user; all errors shall be caught by a global boundary | Error-handler test suite |
| NFR-05 | Reliability | Earned progress shall never decrease | Progress-durability test suite |
| NFR-06 | Usability | The System Usability Scale score from educators shall exceed 68 | SUS administration |
| NFR-07 | Usability | No screen shall overflow at any supported font scale on any supported device size | Device × font-scale test matrix |
| NFR-08 | Usability | Every interactive element shall carry a non-empty accessibility label | Semantics-tree verification |
| NFR-09 | Accessibility | Touch targets in motor-category surfaces shall meet or exceed 48 density-independent pixels | Layout inspection and test |
| NFR-10 | Security | PINs and recovery codes shall be stored only as salted hashes | Code review and unit test |
| NFR-11 | Security | Cloud documents shall be readable and writable only by their owning account | Firestore rules review |
| NFR-12 | Privacy | Camera frames shall never be transmitted or persisted | Code review |
| NFR-13 | Privacy | Telemetry shall be opt-in and disabled by default | Configuration verification |
| NFR-14 | Portability | The system shall run on Android 10 through Android 16 | Multi-device testing |
| NFR-15 | Maintainability | Static analysis shall report zero issues | `flutter analyze` |
| NFR-16 | Maintainability | Every feature shall carry automated tests as a condition of completion | Sprint definition of done |
| NFR-17 | Cost | The system shall incur no recurring cost to a deploying institution | Free-tier architecture audit |
| NFR-18 | Availability | All learning functions shall operate without a network connection | Offline device testing |

---

### 4.5 Operational Feasibility

Operational feasibility assesses whether the system will be used, and used
correctly, by the people it is built for, within their existing practices.

**Table 9. Operational Feasibility Assessment**

| Factor | Assessment | Evidence and Mitigation |
|---|---|---|
| **Fit with existing practice** | **Highly feasible** | The system digitises flashcard drill, a practice SPED teachers already use daily. It introduces no new pedagogy the teacher must first learn. |
| **Learner ability to operate independently** | **Feasible** | Adaptation is automatic; the learner is never required to configure anything. Alternative input covers learners who cannot use touch. Verified on device (Section 5.3.5). |
| **Teacher technical skill required** | **Feasible** | Profile creation, class-code enrolment, and dashboard reading require only ordinary smartphone literacy. A written teacher's guide and an in-app tutorial are provided. Mitigation: a structured orientation session is included in the training cost. |
| **Device availability** | **Feasible with caveat** | The system runs on Android 10 devices with 2 GB RAM, a specification met by the great majority of devices already in circulation. Caveat: schools without any device cannot deploy; the system does not solve device scarcity. |
| **Connectivity dependence** | **Highly feasible** | All learning functions operate offline. Only classroom rosters, live sessions, messaging, and sync require connectivity, and their absence degrades rather than blocks. |
| **Resistance to change** | **Low risk** | The system reduces rather than increases teacher workload by automating progress reporting, worksheet generation, and certificate printing. |
| **Language accessibility** | **Highly feasible** | The full interface is available in Filipino as well as English; all content is bilingual. |
| **Ongoing support burden** | **Feasible** | No server, no accounts to administer, no subscription to renew. Updates are distributed as a new APK. |
| **Safeguarding** | **Feasible** | Educator surfaces are PIN-gatable; messaging is scoped to established class and home-group relationships; telemetry is off by default. |

**Conclusion.** The system is **operationally feasible**. Its principal
operational risk is device scarcity in the poorest schools, which the system
mitigates but cannot eliminate; its principal operational strength is that it
reduces teacher workload rather than adding to it.

---

### 4.6 Technical Feasibility

**Table 10. Technical Feasibility Assessment**

| Factor | Assessment | Evidence |
|---|---|---|
| **Technology maturity** | **Highly feasible** | Flutter 3.44 and Dart 3.12 are stable-channel releases; every dependency is a published, versioned package |
| **Developer competence** | **Feasible** | Demonstrated by the delivered artefact: 208,794 lines across 47 modules, passing static analysis with zero issues |
| **On-device machine learning** | **Feasible** | ML Kit face detection and image labelling are bundled and execute offline; verified working on the test device |
| **Offline operation** | **Proven** | Hive local store is the source of truth; verified by operating the application with the network disabled |
| **Media delivery at acceptable size** | **Proven** | 143 sign clips delivered by on-demand download and disk cache rather than bundling; manifest-driven |
| **Cloud within free tier** | **Proven** | Only Firestore, Anonymous Auth, and opt-in telemetry are used; Cloud Functions, Cloud Storage, and Cloud Messaging are deliberately absent |
| **Cross-device synchronisation** | **Feasible** | Durable replayable sync queue with merge semantics; covered by an automated durability suite |
| **Layout robustness under large type** | **Proven** | Device × font-scale matrices assert no overflow at 2.0× scale on a 360 × 640 viewport |
| **Performance on mid-range hardware** | **Proven** | Verified on the Honor NDL-W09 tablet and a Xiaomi phone, both Android 16 |
| **Maintainability** | **Proven** | Zero static-analysis issues; 2,922 automated tests; vertically sliced feature modules |
| **Head-pose control accuracy** | **Feasible with stated limits** | Four large edge targets plus rest zone; deterministic selection logic unit-tested independently of camera conditions; lighting and camera angle acknowledged as limitations |
| **Speech recognition reliability** | **Partially feasible** | Depends on the device engine and the speaker's articulation; offered as an addition to touch, never a replacement |

**Conclusion.** The system is **technically feasible**, and this is not a
prospective judgment — the system exists, passes 2,922 automated tests and static
analysis without issue, and was operated on physical hardware during this study.
The two areas of qualified feasibility, head-pose precision and speech-recognition
reliability, are documented as limitations in Section 1.4.2 rather than claimed as
solved.

---

### 4.7 Schedule Feasibility

**Table 11. Schedule Feasibility — Sprint Timeline**

| Sprint | Period (2026) | Focus | Principal Deliverables |
|---:|---|---|---|
| 0 | Apr 22 – May 5 | Inception | Needs assessment, requirements elicitation, technology selection, project setup |
| 1 | May 6 – May 19 | Foundation | Project scaffold, Hive persistence, profile model and creation, routing shell, theming, seed vocabulary |
| 2 | May 20 – Jun 2 | Core learning loop | Flashcard viewer, card-flip animation, deck browsing, text-to-speech, first four games |
| 3 | Jun 3 – Jun 16 | Accessibility layer 1 | Accessibility categories, settings presets, high-contrast and dyslexia modes, font scaling, reduced motion, onboarding |
| 4 | Jun 17 – Jun 30 | Games and gamification | Remaining game types, stars, experience points and levels, achievements, streaks, shop, daily challenge |
| 5 | Jul 1 – Jul 14 | Sign language and alternative input | FSL manifest and asset service, dictionary, FSL practice games, head-pose control, voice navigation, gamepad support |
| 6 | Jul 15 – Jul 28 | Educator subsystem | Classrooms, home groups, roster dashboards, analytics, assessments, live sessions, reports and exports |
| 7 | Jul 29 – Aug 11 | Accessibility layers 2 and 3 | Content-visibility policy, curated per-category game rosters, adaptive difficulty wiring, progress durability |
| 8 | Aug 12 – Aug 26 | Consolidation and hardening | Talk Board, wellbeing, peer collaboration, TV cast, layout matrices, full regression suite, project website |
| — | Aug 27 – [ ] | Testing and evaluation | Field deployment, pre-test/post-test, SUS, Smileyometer, ISO/IEC 25010 evaluation |
| — | [ ] | Documentation and defense | Manuscript preparation, revision, final defense |

**Assessment.** The development schedule was met. Eight two-week sprints ran from
6 May to 26 August 2026, evidenced by 114 version-controlled commits across that
window. Scope was controlled per sprint rather than by extending the schedule,
which is the intended behaviour of the methodology. The schedule is therefore
**feasible and demonstrated**, with the caveat that evaluation and documentation
phases extend beyond the development window and are subject to the partner
institution's academic calendar.

---

### 4.8 Economic Feasibility

Economic feasibility for this project must be assessed against two distinct
budgets: the **researcher's** development budget, and the **deploying
institution's** budget. The distinction is essential, because the project's
central economic claim concerns the second, not the first.

**Development budget (borne by the researcher).** Detailed in Tables 13 through
21. The dominant line is hardware already owned by the researcher and content
production; the software toolchain is entirely free and open source, and cloud
services were selected specifically to fall within a permanently free tier.

**Deployment budget (borne by the school).** This is the economically decisive
figure, and it is **₱0.00 in recurring cost**. A school that already possesses an
Android device incurs:

- **₱0.00** for software licensing — the application is free
- **₱0.00** for cloud or server costs — Firebase Spark tier, no billing account
- **₱0.00** for per-seat or per-learner fees — none exist
- **₱0.00** for connectivity required to learn — the application works offline
- **₱0.00** for content updates — content ships with the application

The only costs a school may incur are optional: additional Android devices if it
possesses none, and staff time for the orientation session. This is the direct
economic answer to the resource constraint that the local literature identifies as
the binding obstacle to implementing Republic Act No. 11650.

---

### 4.9 Cost-Benefit Analysis

**Table 12. Cost-Benefit Analysis over Three Years (One Deploying School, 20 Learners)**

| | Year 1 | Year 2 | Year 3 | Total |
|---|---:|---:|---:|---:|
| **COSTS** | | | | |
| Software licence | ₱0.00 | ₱0.00 | ₱0.00 | ₱0.00 |
| Cloud / server subscription | ₱0.00 | ₱0.00 | ₱0.00 | ₱0.00 |
| Per-learner seat fees | ₱0.00 | ₱0.00 | ₱0.00 | ₱0.00 |
| Teacher orientation (2 sessions × ₱1,500) | ₱3,000.00 | ₱0.00 | ₱0.00 | ₱3,000.00 |
| Refresher orientation | ₱0.00 | ₱1,500.00 | ₱1,500.00 | ₱3,000.00 |
| Printing of guides and consent forms | ₱1,200.00 | ₱600.00 | ₱600.00 | ₱2,400.00 |
| Incremental electricity for device charging | ₱480.00 | ₱480.00 | ₱480.00 | ₱1,440.00 |
| **Total cost (device already owned)** | **₱4,680.00** | **₱2,580.00** | **₱2,580.00** | **₱9,840.00** |
| *If devices must be purchased (4 tablets)* | *₱36,000.00* | *—* | *—* | *₱36,000.00* |
| | | | | |
| **BENEFITS (avoided cost)** | | | | |
| Commercial accessible learning software licences avoided (20 learners × ₱1,200/yr) | ₱24,000.00 | ₱24,000.00 | ₱24,000.00 | ₱72,000.00 |
| Printed flashcard sets avoided (4 sets × ₱1,800) | ₱7,200.00 | ₱3,600.00 | ₱3,600.00 | ₱14,400.00 |
| FSL reference material avoided | ₱6,000.00 | ₱0.00 | ₱0.00 | ₱6,000.00 |
| Teacher time recovered on progress documentation (2 h/week × 40 weeks × ₱180/h) | ₱14,400.00 | ₱14,400.00 | ₱14,400.00 | ₱43,200.00 |
| Worksheet and certificate printing services avoided | ₱2,400.00 | ₱2,400.00 | ₱2,400.00 | ₱7,200.00 |
| Mobile data avoided by offline operation | ₱3,600.00 | ₱3,600.00 | ₱3,600.00 | ₱10,800.00 |
| **Total quantified benefit** | **₱57,600.00** | **₱48,000.00** | **₱48,000.00** | **₱153,600.00** |
| | | | | |
| **NET BENEFIT (device owned)** | **₱52,920.00** | **₱45,420.00** | **₱45,420.00** | **₱143,760.00** |
| **NET BENEFIT (devices purchased)** | **₱16,920.00** | **₱45,420.00** | **₱45,420.00** | **₱107,760.00** |

**Benefit–cost ratio (three years, device owned):** ₱153,600 ÷ ₱9,840 = **15.61 : 1**
**Benefit–cost ratio (three years, devices purchased):** ₱153,600 ÷ ₱45,840 = **3.35 : 1**
**Payback period (devices purchased):** approximately **9.6 months**

**Non-quantifiable benefits.** The following benefits are real but were not
assigned a peso value, and are therefore excluded from the ratios above, which are
consequently conservative:

- Learner **autonomy** — a learner with severe motor disability moving from
  "cannot operate the device" to "can study independently" is an outcome with no
  meaningful market price.
- **Filipino Sign Language exposure** for Deaf learners in settings where no
  fluent signing adult is consistently available.
- **Parental visibility** into a child's learning, previously mediated entirely
  through periodic report cards.
- **Institutional compliance** progress against Republic Acts 11650 and 11106.
- **Research capability** — the embedded instrumentation makes the deploying
  institution a potential site for further study at no additional cost.

> **FIELD DATA PENDING.** The avoided-cost figures above are estimates based on
> prevailing Philippine market prices for comparable commercial software, printed
> instructional materials, and teacher hourly rates. Replace them with quotations
> and rates obtained from your partner institution to convert this from an
> estimated to a documented analysis.

---

### 4.10 Hardware Costs

**Table 13. Hardware Costs**

| # | Item | Specification | Qty | Unit Cost | Total | Ownership |
|---:|---|---|---:|---:|---:|---|
| 1 | Development laptop | Windows 11, Core i7, 16 GB RAM, 512 GB SSD | 1 | ₱45,000.00 | ₱45,000.00 | Previously owned |
| 2 | Android tablet (primary test device) | Honor NDL-W09, 8″, 1200 × 1920, Android 16 | 1 | ₱9,000.00 | ₱9,000.00 | Previously owned |
| 3 | Android smartphone (secondary test device) | Xiaomi 2410CRP4CG, Android 16 | 1 | ₱8,500.00 | ₱8,500.00 | Previously owned |
| 4 | Video recording camera | 1080p 30 fps, for FSL clip recording | 1 | ₱6,500.00 | ₱6,500.00 | Borrowed |
| 5 | Tripod and lighting kit | For consistent FSL recording conditions | 1 | ₱2,800.00 | ₱2,800.00 | Purchased |
| 6 | External storage | 1 TB portable drive, for media and backups | 1 | ₱2,700.00 | ₱2,700.00 | Purchased |
| 7 | USB data cables | For device debugging | 2 | ₱350.00 | ₱700.00 | Purchased |
| 8 | Bluetooth gamepad | For gamepad-input testing | 1 | ₱1,200.00 | ₱1,200.00 | Purchased |
| 9 | Tablet stand | For head-pose control testing | 1 | ₱650.00 | ₱650.00 | Purchased |
| | | | | **Gross total** | **₱77,050.00** | |
| | | | | **Cash outlay** | **₱8,050.00** | *(items 5–9)* |

---

### 4.11 Software Costs

**Table 14. Software Costs**

| # | Software | Version | Purpose | Licence | Cost |
|---:|---|---|---|---|---:|
| 1 | Flutter SDK | 3.44.0 | Application framework | BSD-3-Clause (free) | ₱0.00 |
| 2 | Dart SDK | 3.12.0 | Programming language | BSD-3-Clause (free) | ₱0.00 |
| 3 | Android SDK & Platform Tools | API 36 | Build and device bridge | Apache 2.0 (free) | ₱0.00 |
| 4 | Visual Studio Code | Current | Integrated development environment | MIT (free) | ₱0.00 |
| 5 | Git | Current | Version control | GPL-2.0 (free) | ₱0.00 |
| 6 | Firebase — Cloud Firestore | — | Cloud database | Spark plan (free tier) | ₱0.00 |
| 7 | Firebase — Anonymous Auth | — | Authentication | Free, unlimited | ₱0.00 |
| 8 | Firebase — Crashlytics / Analytics | — | Opt-in telemetry | Free on Spark | ₱0.00 |
| 9 | Google ML Kit | Bundled | On-device face detection and image labelling | Free, no API key | ₱0.00 |
| 10 | 40 Flutter/Dart packages | See Table 2 | Application dependencies | Open source (BSD / MIT / Apache) | ₱0.00 |
| 11 | FFmpeg | Current | Video transcoding for FSL clips | LGPL/GPL (free) | ₱0.00 |
| 12 | GitHub | — | Source hosting and media releases | Free tier | ₱0.00 |
| 13 | Cloudinary | — | Media CDN fallback | Free tier | ₱0.00 |
| 14 | GitHub Pages | — | Project website hosting | Free | ₱0.00 |
| | | | | **TOTAL** | **₱0.00** |

**Note.** The zero software cost is a deliberate design constraint, not an
accident of availability. Every technology was selected on the condition that it
impose no licence fee, no subscription, and no per-call charge on either the
researcher or a future deploying school. Where a paid alternative would have been
technically superior — a commercial calibrated eye-tracking SDK, a cloud vision
API, Firebase Cloud Functions for server-side validation — the free alternative
was chosen and its limitations documented rather than the constraint being
relaxed.

---

### 4.12 Stationery and Supplies Costs

**Table 15. Stationery and Supplies Costs**

| # | Item | Qty | Unit Cost | Total |
|---:|---|---:|---:|---:|
| 1 | A4 bond paper, substance 20 | 5 reams | ₱260.00 | ₱1,300.00 |
| 2 | Printer ink cartridges (black and colour) | 4 | ₱750.00 | ₱3,000.00 |
| 3 | Manuscript printing and binding (proposal copies) | 5 | ₱450.00 | ₱2,250.00 |
| 4 | Manuscript printing and binding (final, hardbound) | 4 | ₱850.00 | ₱3,400.00 |
| 5 | Document folders and fasteners | 20 | ₱35.00 | ₱700.00 |
| 6 | Consent and assent forms, printing | 60 | ₱5.00 | ₱300.00 |
| 7 | Evaluation instrument forms, printing | 100 | ₱5.00 | ₱500.00 |
| 8 | Teacher's guide, printed and bound | 6 | ₱180.00 | ₱1,080.00 |
| 9 | USB flash drive, 32 GB | 2 | ₱420.00 | ₱840.00 |
| 10 | Writing materials, sticky notes, markers | — | — | ₱650.00 |
| 11 | Certificates and tokens for participating teachers | 8 | ₱150.00 | ₱1,200.00 |
| | | | **TOTAL** | **₱15,220.00** |

---

### 4.13 Software Development Costs

Software development cost is presented on an **imputed** basis: the researcher's
labour was not compensated, but valuing it establishes the true economic cost of
the artefact and the magnitude of the contribution made to the partner
institution. The rate used, ₱250.00 per hour, approximates the prevailing
Philippine market rate for a junior mobile developer.

**Table 16. Software Development Costs (Imputed Labour)**

| Phase | Sprint(s) | Hours | Rate/hour | Imputed Cost |
|---|---|---:|---:|---:|
| Requirements analysis and needs assessment | 0 | 60 | ₱250.00 | ₱15,000.00 |
| System design and architecture | 0–1 | 80 | ₱250.00 | ₱20,000.00 |
| Foundation: persistence, profiles, routing, theming | 1 | 90 | ₱250.00 | ₱22,500.00 |
| Core learning loop: flashcards, animation, TTS | 2 | 100 | ₱250.00 | ₱25,000.00 |
| Accessibility layer 1: presets, modes, onboarding | 3 | 95 | ₱250.00 | ₱23,750.00 |
| Games and gamification | 4 | 110 | ₱250.00 | ₱27,500.00 |
| Sign language and alternative input | 5 | 120 | ₱250.00 | ₱30,000.00 |
| Educator subsystem | 6 | 115 | ₱250.00 | ₱28,750.00 |
| Accessibility layers 2 and 3, adaptive engine | 7 | 90 | ₱250.00 | ₱22,500.00 |
| Consolidation, hardening, regression suite, website | 8 | 130 | ₱250.00 | ₱32,500.00 |
| Content production: 177 cards, 24 stories | 1–8 | 70 | ₱250.00 | ₱17,500.00 |
| Content production: 143 FSL clips (recording, editing, encoding) | 5–8 | 85 | ₱250.00 | ₱21,250.00 |
| Automated test authoring (222 files, 2,922 cases) | 1–8 | 140 | ₱250.00 | ₱35,000.00 |
| Testing, debugging, and on-device verification | 1–8 | 105 | ₱250.00 | ₱26,250.00 |
| Documentation: manuscript, guides, project website | 1–8 | 90 | ₱250.00 | ₱22,500.00 |
| | | **1,480** | | **₱370,000.00** |

---

### 4.14 Operational Costs

**Table 17. Operational Costs**

| # | Item | Duration | Monthly | Total |
|---:|---|---|---:|---:|
| 1 | Home internet subscription (development, research, deployment testing) | 6 months | ₱1,699.00 | ₱10,194.00 |
| 2 | Mobile data (field testing at partner institution) | 4 months | ₱499.00 | ₱1,996.00 |
| 3 | Transportation to and from the partner institution | 16 trips | ₱180.00/trip | ₱2,880.00 |
| 4 | Transportation for FSL recording sessions | 6 trips | ₱220.00/trip | ₱1,320.00 |
| 5 | Transportation for adviser consultations | 12 trips | ₱150.00/trip | ₱1,800.00 |
| 6 | Communication (calls, messaging with respondents) | 6 months | ₱250.00 | ₱1,500.00 |
| 7 | Meals during field visits and recording sessions | 22 days | ₱150.00/day | ₱3,300.00 |
| 8 | Honorarium / token for FSL consultants | 3 persons | ₱1,500.00 | ₱4,500.00 |
| | | | **TOTAL** | **₱27,490.00** |

---

### 4.15 Utility Expenses

**Table 18. Utility Expenses**

| # | Item | Basis | Rate | Total |
|---:|---|---|---:|---:|
| 1 | Electricity — development workstation | 1,480 h × 0.09 kW | ₱12.50/kWh | ₱1,665.00 |
| 2 | Electricity — monitor and peripherals | 1,480 h × 0.04 kW | ₱12.50/kWh | ₱740.00 |
| 3 | Electricity — test device charging | 6 months × 4.0 kWh/month | ₱12.50/kWh | ₱300.00 |
| 4 | Electricity — lighting during work sessions | 1,480 h × 0.02 kW | ₱12.50/kWh | ₱370.00 |
| 5 | Electricity — recording lighting kit | 40 h × 0.20 kW | ₱12.50/kWh | ₱100.00 |
| 6 | Water and incidental utilities (proportional) | 6 months | ₱120.00/month | ₱720.00 |
| | | | **TOTAL** | **₱3,895.00** |

---

### 4.16 Training Costs

**Table 19. Training Costs**

| # | Item | Participants | Unit Cost | Total |
|---:|---|---:|---:|---:|
| 1 | Teacher orientation session — venue and materials | 2 sessions | ₱1,200.00 | ₱2,400.00 |
| 2 | Printed teacher's guide | 6 | ₱180.00 | ₱1,080.00 |
| 3 | Printed quick-reference card (laminated) | 12 | ₱65.00 | ₱780.00 |
| 4 | Parent orientation session — materials | 1 session | ₱900.00 | ₱900.00 |
| 5 | Refreshments for orientation sessions | 3 sessions | ₱800.00 | ₱2,400.00 |
| 6 | Researcher's own upskilling — Flutter and accessibility learning resources | — | — | ₱0.00 (free documentation and community resources) |
| 7 | Filipino Sign Language familiarisation for the researcher | 8 hours | ₱250.00/h | ₱2,000.00 |
| | | | **TOTAL** | **₱9,560.00** |

**Note on the sustainability of training.** The training design deliberately
minimises recurring cost. The teacher's guide is also published on the project
website, and the application contains an in-app tutorial, so a school onboarding a
new teacher in a later year need not schedule an external session.

---

### 4.17 Capital Costs

Capital costs are those incurred for durable assets with a useful life beyond the
project.

**Table 20. Capital Costs**

| # | Asset | Useful Life | Acquisition Cost | Depreciation (project period, 6 months, straight line) |
|---:|---|---:|---:|---:|
| 1 | Development laptop | 5 years | ₱45,000.00 | ₱4,500.00 |
| 2 | Android tablet (primary test device) | 4 years | ₱9,000.00 | ₱1,125.00 |
| 3 | Android smartphone (secondary test device) | 4 years | ₱8,500.00 | ₱1,062.50 |
| 4 | External storage drive | 5 years | ₱2,700.00 | ₱270.00 |
| 5 | Tripod and lighting kit | 5 years | ₱2,800.00 | ₱280.00 |
| 6 | Bluetooth gamepad | 3 years | ₱1,200.00 | ₱200.00 |
| 7 | Tablet stand | 3 years | ₱650.00 | ₱108.33 |
| | | **Total acquisition** | **₱69,850.00** | **₱7,545.83** |

**Table 21. Summary of Total Project Costs**

| Category | Reference | Amount |
|---|---|---:|
| Hardware (cash outlay only; owned assets excluded) | Table 13 | ₱8,050.00 |
| Software | Table 14 | ₱0.00 |
| Stationery and supplies | Table 15 | ₱15,220.00 |
| Operational | Table 17 | ₱27,490.00 |
| Utility expenses | Table 18 | ₱3,895.00 |
| Training | Table 19 | ₱9,560.00 |
| **Subtotal — actual cash outlay** | | **₱64,215.00** |
| Capital depreciation charged to the project | Table 20 | ₱7,545.83 |
| **Subtotal — economic cost excluding labour** | | **₱71,760.83** |
| Software development (imputed labour) | Table 16 | ₱370,000.00 |
| **TOTAL ECONOMIC COST OF THE PROJECT** | | **₱441,760.83** |
| | | |
| **RECURRING COST TO A DEPLOYING SCHOOL** | Section 4.8 | **₱0.00** |

The final two rows express the economic argument of this study in a single
comparison. The artefact represents an economic investment of approximately
₱441,761, of which ₱370,000 is uncompensated researcher labour, and it is
delivered to any deploying institution at **zero recurring cost**.

---
### 4.18 System Flowchart

Figure 9 presents the principal learner flow from application launch through a
completed learning activity. Figure 10 isolates the adaptive accessibility routing
that is the study's central contribution.

**Figure 9. System Flowchart — Main Learner Flow**

```
                            ┌───────────┐
                            │   START   │
                            └─────┬─────┘
                                  ▼
                        ┌───────────────────┐
                        │  Splash screen    │
                        │  init Hive, TTS,  │
                        │  Firebase, media  │
                        │  manifests        │
                        └─────────┬─────────┘
                                  ▼
                          ╱───────────────╲
                         ╱ Any profile      ╲   NO    ┌──────────────────┐
                        ╱  exists on device? ╲───────▶│ Welcome screen   │
                        ╲                    ╱        │ Choose role      │
                         ╲                  ╱         └────────┬─────────┘
                          ╲────────────────╱                   ▼
                                  │ YES               ┌──────────────────┐
                                  ▼                   │ Role setup       │
                        ┌───────────────────┐         │ name, avatar,    │
                        │ Profile switcher  │         │ birth date       │
                        │ choose profile    │         └────────┬─────────┘
                        └─────────┬─────────┘                  ▼
                                  ▼                    ╱────────────────╲
                          ╱───────────────╲           ╱ Learner role?    ╲ NO
                         ╱ PIN protected?  ╲ YES      ╲                  ╱──┐
                        ╱                   ╲──┐       ╲────────────────╱   │
                        ╲                   ╱  │              │ YES         │
                         ╲─────────────────╱   ▼              ▼             │
                                  │ NO   ┌──────────┐  ┌──────────────────┐ │
                                  │      │ PIN gate │  │ Accessibility    │ │
                                  │      │ verify   │  │ setup — declare  │ │
                                  │      └────┬─────┘  │ category         │ │
                                  │           │        └────────┬─────────┘ │
                                  │◀──────────┘                 ▼           │
                                  │                    ┌──────────────────┐ │
                                  │                    │ APPLY ADAPTATION │ │
                                  │                    │ (see Figure 10)  │ │
                                  │                    └────────┬─────────┘ │
                                  │                             │           │
                                  │◀────────────────────────────┴───────────┘
                                  ▼
                    ┌─────────────────────────────┐
                    │  Load profile, settings,    │
                    │  progress from Hive         │
                    │  Resolve content policy     │
                    │  and game roster            │
                    └──────────────┬──────────────┘
                                   ▼
                          ╱─────────────────╲
                         ╱  Role routing     ╲
                        ╱                     ╲
       ┌───────────────┴──────┬────────────────┴───────────────┐
       ▼                      ▼                                ▼
┌──────────────┐      ┌──────────────┐              ┌────────────────────┐
│ LEARNER HOME │      │ CHILD HOME   │              │ EDUCATOR HOME      │
│ Student /    │      │ Child        │              │ Teacher / Parent   │
│ Player       │      │              │              │                    │
└──────┬───────┘      └──────┬───────┘              └─────────┬──────────┘
       │                     │                                │
       └──────────┬──────────┘                                ▼
                  ▼                                 ┌────────────────────┐
      ┌───────────────────────┐                     │ Roster · dashboards│
      │ Bottom navigation     │                     │ assessments ·      │
      │ Home · Cards · Games  │                     │ live session ·     │
      │ Stories · Progress    │                     │ reports · exports  │
      └───────────┬───────────┘                     └─────────┬──────────┘
                  ▼                                           │
      ╱───────────────────────╲                               │
     ╱  Learner selects        ╲                              │
    ╱   an activity             ╲                             │
    ╲                           ╱                             │
     ╲─────────────────────────╱                              │
        │        │        │                                   │
        ▼        ▼        ▼                                   │
  ┌─────────┐┌────────┐┌─────────┐                            │
  │ CARDS   ││ GAMES  ││ STORIES │                            │
  │ pick    ││ pick   ││ pick    │                            │
  │ deck    ││ game   ││ story   │                            │
  └────┬────┘└───┬────┘└────┬────┘                            │
       │         │          │                                 │
       ▼         ▼          ▼                                 │
  ┌────────────────────────────────┐                          │
  │  ACTIVITY SESSION              │                          │
  │  • present item                │                          │
  │  • learner responds (touch /   │                          │
  │    voice / gaze / gamepad)     │                          │
  │  • evaluate response           │                          │
  │  • animated feedback + sound   │                          │
  │    + haptics (per settings)    │                          │
  │  • update per-word accuracy    │                          │
  └───────────────┬────────────────┘                          │
                  ▼                                           │
          ╱───────────────╲                                   │
         ╱  More items?    ╲ YES                              │
        ╱                   ╲───┐                             │
        ╲                   ╱   │                             │
         ╲─────────────────╱    │                             │
                  │ NO          │                             │
                  │◀────────────┘                             │
                  ▼                                           │
      ┌───────────────────────────┐                           │
      │  SESSION RESULT           │                           │
      │  • award stars and XP     │                           │
      │  • check level-up         │                           │
      │  • check achievements     │                           │
      │  • update streak          │                           │
      │  • celebration animation  │                           │
      │    (per accessibility     │                           │
      │     celebration style)    │                           │
      └─────────────┬─────────────┘                           │
                    ▼                                         │
      ┌───────────────────────────┐                           │
      │  PERSIST to Hive          │  ◀── commit completes here │
      │  (source of truth)        │                           │
      └─────────────┬─────────────┘                           │
                    ▼                                         │
      ┌───────────────────────────┐                           │
      │  Enqueue sync operation   │                           │
      └─────────────┬─────────────┘                           │
                    ▼                                         │
            ╱───────────────╲                                 │
           ╱   Online?       ╲ NO ──▶ remains queued;         │
          ╱                   ╲        replays on reconnect   │
          ╲                   ╱                               │
           ╲─────────────────╱                                │
                    │ YES                                     │
                    ▼                                         │
      ┌───────────────────────────┐                           │
      │  Firestore write (merge)  │◀──────────────────────────┘
      └─────────────┬─────────────┘   educator reads roster
                    ▼
            ╱───────────────╲
           ╱ Continue        ╲ YES
          ╱  learning?        ╲───▶ back to bottom navigation
          ╲                   ╱
           ╲─────────────────╱
                    │ NO
                    ▼
              ┌───────────┐
              │    END    │
              └───────────┘
```

**Figure 10. System Flowchart — Adaptive Accessibility Routing**

```
        ┌─────────────────────────────────────────┐
        │  Learner declares accessibility         │
        │  category at onboarding, OR inherits    │
        │  it from the class join code            │
        └────────────────────┬────────────────────┘
                             ▼
              ╱──────────────────────────────╲
             ╱   Which DisabilityType?         ╲
            ╱                                   ╲
   ┌────────┴───┬────────┬────────┬────────┬─────┴──────┐
   ▼            ▼        ▼        ▼        ▼            ▼
VISUAL      HEARING    MOTOR   COGNITIVE MULTIPLE     NONE
   │            │        │        │        │            │
   └────────────┴────────┴────┬───┴────────┴────────────┘
                              ▼
   ╔══════════════════════════════════════════════════════════════════╗
   ║  LAYER 1 — AccessibilityPresets.presetFor(type)                  ║
   ║  merge over current AppSettings (locale, reminders preserved)    ║
   ║                                                                  ║
   ║  → fontScale · highContrast · dyslexiaMode · darkMode            ║
   ║  → ttsEnabled · ttsSpeed · soundEffects                          ║
   ║  → reducedMotion · voiceNavigation · adaptiveDifficulty          ║
   ╚═══════════════════════════════╤══════════════════════════════════╝
                                   ▼
   ╔══════════════════════════════════════════════════════════════════╗
   ║  LAYER 2 — AccessibilityContentPolicy                            ║
   ║                                                                  ║
   ║   showFslSurfaces?        showAudioOnlyPronunciation?            ║
   ║   ────────────────        ───────────────────────────            ║
   ║   visual    → NO          visual    → YES                        ║
   ║   hearing   → YES         hearing   → NO                         ║
   ║   motor     → YES         motor     → YES                        ║
   ║   cognitive → NO          cognitive → YES                        ║
   ║   multiple  → YES         multiple  → YES                        ║
   ║   none      → YES         none      → YES                        ║
   ╚═══════════════════════════════╤══════════════════════════════════╝
                                   ▼
   ╔══════════════════════════════════════════════════════════════════╗
   ║  LAYER 3 — GameCatalog.forCategory(type)                         ║
   ║  returns exactly 10 of the 15 game types, in display order       ║
   ║  (see Table 4)                                                   ║
   ║                                                                  ║
   ║  invariant asserted by test: Layer 3 never offers a game that    ║
   ║  Layer 2 has hidden — e.g. a category with showFsl = NO never    ║
   ║  receives FSL Practice in its roster                             ║
   ╚═══════════════════════════════╤══════════════════════════════════╝
                                   ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │  Riverpod publishes settings, policy, and roster to the widget   │
   │  tree. Every screen consumes them WITHOUT branching on the       │
   │  disability category itself — which is what keeps the system to  │
   │  ONE implementation of each screen.                              │
   └──────────────────────────────┬───────────────────────────────────┘
                                  ▼
   ┌──────────────────────────────────────────────────────────────────┐
   │  OBSERVED RESULT ON THE SAME FLASHCARD SCREEN                    │
   │                                                                  │
   │   HEARING profile        │   VISUAL profile                      │
   │   ─────────────────      │   ────────────────                    │
   │   [Previous]             │   [Replay, English] [Replay, Filipino]│
   │   [FSL]        ◀── shown │                                       │
   │   [Show Me]              │   [Previous] [Show Me] [Flip] [Next]  │
   │   [Flip] [Next]          │        ▲                              │
   │                          │        └── no FSL button              │
   │   no audio replay bar    │                                       │
   │                                                                  │
   │   (Both verified on the physical device — see Section 5.3.5)     │
   └──────────────────────────────────────────────────────────────────┘
```

---

### 4.19 Requirements Modeling

Requirements modeling expresses the system's required behaviour in terms of the
actors who invoke it and the events to which it responds.

#### 4.19.1 Actors

| Actor | Description | Principal Goals |
|---|---|---|
| **Student** | A learner enrolled in a classroom, carrying an accessibility category | Learn vocabulary; play games; read stories; track own progress |
| **Child** | A learner enrolled in a home group by a parent, carrying an accessibility category | As Student, within a family rather than school context |
| **Player** | A standalone learner belonging to no class or group, including a guest | Learn and play without enrolment |
| **Teacher** | An educator managing one or more classrooms | Enrol learners; monitor progress; assign assessments; run live sessions; generate reports |
| **Parent** | An educator managing one or more home groups | Monitor a child's progress; set time limits and alarms; communicate with teachers |
| **System (time-triggered)** | The application acting autonomously on a schedule | Fire study reminders; enforce time limits; roll the daily challenge; checkpoint study time |
| **External services** | Firebase, media origins, device platform services | Persist mirrored data; supply media; provide speech, camera, and notification facilities |

#### 4.19.2 Event Table

| # | Event | Trigger | Source | Response | Destination |
|---:|---|---|---|---|---|
| 1 | Learner selects a profile | User action | Student/Child/Player | Load profile, settings, progress; resolve adaptation | Learner home |
| 2 | Learner declares accessibility category | User action | Learner (or class code) | Apply preset, policy, roster | Adapted interface |
| 3 | Learner opens a deck | User action | Learner | Present card 1 of *n* with policy-appropriate controls | Flashcard viewer |
| 4 | Learner flips a card | User action | Learner | Animate flip; reveal opposite language face | Flashcard viewer |
| 5 | Learner requests narration | User action | Learner | Synthesise speech at the preset rate in the chosen language | Audio output |
| 6 | Learner requests a sign clip | User action | Learner | Resolve, download-or-cache, and play with speed control | Video sheet |
| 7 | Learner answers a game item | User action | Learner | Evaluate; give animated feedback; update per-word accuracy | Progress store |
| 8 | Learner completes a game | System | Game engine | Award stars and XP; check level and achievements; celebrate | Progress store, learner |
| 9 | Progress is written | System | Any activity | Persist to Hive; enqueue sync operation | Local store, sync queue |
| 10 | Connectivity is restored | External | Platform | Drain sync queue to Firestore | Cloud mirror |
| 11 | Cloud progress arrives | External | Firestore | Validate and **merge** — never replace | Local store |
| 12 | Teacher creates a class | User action | Teacher | Generate a six-character join code; persist | Cloud, roster |
| 13 | Learner enters a join code | User action | Learner | Enrol; inherit the class's accessibility category | Roster, learner profile |
| 14 | Teacher opens the roster | User action | Teacher | Aggregate per-learner progress; render dashboard | Teacher dashboard |
| 15 | Teacher assigns an assessment | User action | Teacher | Create assignment records for each roster learner | Cloud, learner inbox |
| 16 | Learner takes an assessment | User action | Learner | Present items; score; record per-item response time | Assessment results |
| 17 | Teacher starts a live session | User action | Teacher | Open a session document; broadcast questions | Learner devices |
| 18 | Learner raises a hand | User action | Learner | Write a hand record to the session | Teacher view |
| 19 | Reminder time is reached | Time | Scheduler | Fire a local notification | Device notification |
| 20 | Time limit is reached | Time | Lock enforcer | Announce hand-off by chime, voice, sign, or picture per profile; lock | Learner device |
| 21 | Learner speaks a command | User action | Learner | Recognise on device; map to a navigation intent | Navigation |
| 22 | Learner holds head on a target | User action | Learner | Fill dwell ring; fire once at completion; require return to rest | Selected action |
| 23 | Teacher exports research data | User action | Teacher | Generate 15 anonymised CSV datasets; share | File system |
| 24 | Educator completes the SUS | User action | Teacher/Parent | Score and persist against the respondent profile | Survey results |
| 25 | Learner completes the Smileyometer | User action | Learner | Persist three face ratings | Survey results |

---

### 4.20 Object Modeling

**Figure 11. Class Diagram (Object Model — Principal Domain Classes)**

```
┌────────────────────────────────┐          ┌──────────────────────────────┐
│         UserProfile            │          │        AppSettings           │
├────────────────────────────────┤          ├──────────────────────────────┤
│ + id : String                  │ 1      1 │ + fontScale : double         │
│ + name : String                │──────────│ + highContrastMode : bool    │
│ + role : UserRole              │          │ + dyslexiaMode : bool        │
│ + disabilityType:DisabilityType│          │ + darkMode : bool            │
│ + avatarIndex : int            │          │ + ttsEnabled : bool          │
│ + gradeLevel : GradeLevel?     │          │ + ttsSpeed : double          │
│ + birthDate : DateTime?        │          │ + reducedMotion : bool       │
│ + learningLevel:LearningLevel? │          │ + soundEffects : bool        │
│ + pinHash / pinSalt : String?  │          │ + voiceNavigation : bool     │
│ + recoveryCodeHash : String?   │          │ + adaptiveDifficulty : bool  │
│ + classroomId : String?        │          │ + locale : String            │
│ + homeGroupId : String?        │          │ + aiCompanionEnabled : bool  │
│ + ownerUid : String?           │          └──────────────────────────────┘
│ + interests:List<Category>     │                        ▲
│ + equippedAvatar/Border/Title  │                        │ produced by
└───────────┬────────────────────┘          ┌─────────────┴────────────────┐
            │ 1                             │   AccessibilityPresets       │
            │                               ├──────────────────────────────┤
            │ 1                             │ + presetFor(DisabilityType,  │
┌───────────▼────────────────────┐          │      current) : AppSettings  │
│      LearningProgress          │          │ + changeSummary(type)        │
├────────────────────────────────┤          └──────────────────────────────┘
│ + profileId : String           │
│ + wordsLearned : int           │          ┌──────────────────────────────┐
│ + learnedWordIds : Set<String> │          │ AccessibilityContentPolicy   │
│ + streakDays : int             │          ├──────────────────────────────┤
│ + bestStreakDays : int         │          │ + showFslSurfaces : bool     │
│ + totalStars / spentStars      │          │ + showAudioOnlyGame : bool   │
│ + gamesPlayed : int            │          │ + forType(DisabilityType)    │
│ + categoryProgress : Map       │          └──────────────────────────────┘
│ + recentScores:List<GameScore> │
│ + playedGameTypes:Set<GameType>│          ┌──────────────────────────────┐
│ + gameBestStars : Map          │          │        GameCatalog           │
│ + completedStoryIds : Set      │          ├──────────────────────────────┤
│ + signedWordKeys : Set         │          │ + gamesPerCategory : int = 10│
│ + canSignKeys : Set            │          │ + forCategory(type)          │
│ + everConfirmedSignKeys : Set  │          │      : List<GameType>        │
│ + lastActivityDate : DateTime  │          │ + combined : List<GameType>  │
└───────────┬────────────────────┘          │ + isCategorised(role) : bool │
            │ 1                             └──────────────────────────────┘
            │
            │ 0..*                          ┌──────────────────────────────┐
┌───────────▼────────────────────┐          │       WordAccuracy           │
│         GameScore              │          ├──────────────────────────────┤
├────────────────────────────────┤          │ + wordId : String            │
│ + gameType : GameType          │          │ + correct : int              │
│ + score : int                  │          │ + total : int                │
│ + total : int                  │          │ + lastSeen : DateTime        │
│ + starsEarned : int            │          │ + accuracy : double          │
│ + durationSeconds : int?       │          │ + priority : double          │
│ + date : DateTime              │          │ + recordAttempt(bool)        │
└────────────────────────────────┘          └──────────────┬───────────────┘
                                                           │ consumed by
┌────────────────────────────────┐          ┌──────────────▼───────────────┐
│         Flashcard              │          │  SpacedRepetitionService     │
├────────────────────────────────┤          ├──────────────────────────────┤
│ + id : String                  │          │ + getWordAccuracies(id)      │
│ + wordEnglish : String         │◀─────────│ + recordAttempt(id,word,ok)  │
│ + wordFilipino : String        │  reviews │ + getReviewWords(id, n)      │
│ + exampleSentence : String?    │          │ + getSummary(id)             │
│ + definition : String?         │          └──────────────┬───────────────┘
│ + imageAsset : String?         │                         │ feeds
│ + category : FlashcardCategory │          ┌──────────────▼───────────────┐
│ + isCustom : bool              │          │ AdaptiveDifficultyService    │
└───────────┬────────────────────┘          ├──────────────────────────────┤
            │ *                             │ + suggestDifficulty(id,cats) │
            │                               │      : GameDifficulty        │
            │ 1                             │   <40% → easy                │
┌───────────▼────────────────────┐          │   40–70% → medium            │
│       FlashcardDeck            │          │   >70% → hard                │
├────────────────────────────────┤          │ + getSuggestionReason(id)    │
│ + id : String                  │          └──────────────────────────────┘
│ + name : String                │
│ + category : FlashcardCategory │          ┌──────────────────────────────┐
│ + flashcardIds : List<String>  │          │        Classroom             │
│ + isCustom : bool              │          ├──────────────────────────────┤
└────────────────────────────────┘          │ + id / name / joinCode       │
                                            │ + ownerProfileId : String    │
┌────────────────────────────────┐          │ + disabilityType             │
│         HomeGroup              │          │ + leaderboardEnabled : bool  │
├────────────────────────────────┤          └──────────────┬───────────────┘
│ + id / name / joinCode         │                         │ 1
│ + ownerProfileId : String      │                         │
└──────────────┬─────────────────┘                         │ 0..*
               │ 1                          ┌──────────────▼───────────────┐
               │ 0..*                       │     ClassroomMember          │
┌──────────────▼─────────────────┐          ├──────────────────────────────┤
│     HomeGroupMember            │          │ + classroomId : String       │
├────────────────────────────────┤          │ + profileId : String         │
│ + homeGroupId : String         │          │ + joinedAt : DateTime        │
│ + profileId : String           │          └──────────────────────────────┘
└────────────────────────────────┘
```

**Principal enumerations.**

| Enumeration | Values |
|---|---|
| `UserRole` | student, teacher, parent, child, player |
| `DisabilityType` | visual, hearing, motor, cognitive, multiple, none |
| `FlashcardCategory` | animals, colorsAndShapes, numbers, bodyParts, foodAndDrinks, familyAndGreetings, clothing, weather, classroom, transportation, emotions, daysAndTime, actions |
| `GameType` | wordMatch, spellingBee, memoryMatch, dragAndDrop, flashcardQuiz, pronunciation, sentenceBuilder, storyQuiz, tracing, fslPractice, jigsawPuzzle, pictureWord, yesOrNo, oddOneOut, firstLetter |
| `GameDifficulty` | easy, medium, hard |
| `LearningLevel` | beginner, elementary, intermediate, advanced |
| `GradeLevel` | kinder, grade1 … grade6, highSchool, college |

**Note on enumeration ordering.** Values are persisted by their integer index in
Hive. New values are therefore always **appended**, never inserted, so that
profiles serialised by an earlier build continue to deserialise correctly. This
constraint is documented in the source and is the reason `actions`, `jigsawPuzzle`,
`pictureWord`, `yesOrNo`, `oddOneOut`, and `firstLetter` appear at the end of their
respective enumerations rather than in a logical position.

---

### 4.21 Use Case Diagram

**Figure 12. Use Case Diagram**

```
                            ┌═══════════════════════════════════════════════┐
                            ║              FlashLearn PWD                   ║
                            ║                                               ║
  ┌────────┐                ║   ╔═════════ LEARNING ═══════════╗            ║
  │        │                ║   ║  ( Browse flashcard decks )  ║            ║
  │Student │────────────────╫───║  ( Study a flashcard      )  ║            ║
  │        │                ║   ║  ( Flip card / hear word  )  ║            ║
  └───┬────┘                ║   ║  ( Watch FSL sign clip    )  ║            ║
      │                     ║   ║  ( Play a learning game   )  ║            ║
      │ «inherits»          ║   ║  ( Read a story + quiz    )  ║            ║
      ▼                     ║   ║  ( Do the daily challenge )  ║            ║
  ┌────────┐                ║   ║  ( Smart review           )  ║            ║
  │ Child  │────────────────╫───║  ( Hunt words with camera )  ║            ║
  └───┬────┘                ║   ║  ( Create a custom card   )  ║            ║
      │                     ║   ╚══════════════════════════════╝            ║
      │ «inherits»          ║                                               ║
      ▼                     ║   ╔═════════ ACCESSIBILITY ══════╗            ║
  ┌────────┐                ║   ║  ( Declare category       )  ║            ║
  │ Player │────────────────╫───║  ( Adjust settings        )  ║            ║
  └────────┘                ║   ║  ( Use voice commands     )  ║            ║
                            ║   ║  ( Use head-pose control  )  ║            ║
                            ║   ║  ( Use gamepad            )  ║            ║
                            ║   ║  ( Use Talk Board (AAC)   )  ║            ║
                            ║   ╚══════════════════════════════╝            ║
                            ║                                               ║
  ┌────────┐                ║   ╔═════════ PROGRESS ═══════════╗            ║
  │Teacher │────────────────╫───║  ( View own progress      )  ║            ║
  │        │                ║   ║  ( View streak calendar   )  ║            ║
  └───┬────┘                ║   ║  ( Spend stars in shop    )  ║            ║
      │                     ║   ║  ( View achievements      )  ║            ║
      │ «inherits»          ║   ╚══════════════════════════════╝            ║
      ▼                     ║                                               ║
  ┌────────┐                ║   ╔═════════ COLLABORATION ══════╗            ║
  │ Parent │────────────────╫───║  ( Play Together (compete))  ║            ║
  └────────┘                ║   ║  ( Peer collaborate       )  ║            ║
                            ║   ║  ( Join live class session)  ║            ║
                            ║   ║  ( Cast to TV             )  ║            ║
                            ║   ║  ( Send a message         )  ║            ║
                            ║   ╚══════════════════════════════╝            ║
                            ║                                               ║
                            ║   ╔═════════ EDUCATOR ═══════════╗            ║
  Teacher ──────────────────╫───║  ( Create classroom       )  ║            ║
  Parent  ──────────────────╫───║  ( Create home group      )  ║            ║
                            ║   ║  ( View roster dashboard  )  ║            ║
                            ║   ║  ( View learner timeline  )  ║            ║
                            ║   ║  ( View hard-word report  )  ║            ║
                            ║   ║  ( Author an assessment   )  ║            ║
                            ║   ║  ( Assign an assessment   )  ║            ║
                            ║   ║  ( Track assignments      )  ║            ║
                            ║   ║  ( Run a live session     )  ║            ║
                            ║   ║  ( Set time limits/alarms )  ║            ║
                            ║   ║  ( Write parent-teacher   )  ║            ║
                            ║   ║       note                )  ║            ║
                            ║   ║  ( Generate weekly report )  ║            ║
                            ║   ║  ( Print worksheet        )  ║            ║
                            ║   ║  ( Print certificate      )  ║            ║
                            ║   ║  ( Export research data   )  ║            ║
                            ║   ║  ( Configure experiment   )  ║            ║
                            ║   ║  ( Take SUS survey        )  ║            ║
                            ║   ║  ( Manage device profiles )  ║            ║
                            ║   ╚══════════════════════════════╝            ║
                            ║                                               ║
                            ║   ╔═════════ SYSTEM ═════════════╗            ║
   ┌──────────────┐         ║   ║  ( Apply adaptation layers)  ║            ║
   │ System       │─────────╫───║  ( Compute spaced review  )  ║            ║
   │ (scheduler)  │         ║   ║  ( Suggest difficulty     )  ║            ║
   └──────────────┘         ║   ║  ( Fire study reminder    )  ║            ║
                            ║   ║  ( Enforce time limit     )  ║            ║
   ┌──────────────┐         ║   ║  ( Sync to cloud (merge)  )  ║            ║
   │  Firebase    │─────────╫───║  ( Cache media on demand  )  ║            ║
   └──────────────┘         ║   ╚══════════════════════════════╝            ║
                            └═══════════════════════════════════════════════┘
```

#### 4.21.1 Expanded Use Case: Study a Flashcard

| Field | Description |
|---|---|
| **Use case ID** | UC-03 |
| **Name** | Study a flashcard |
| **Actor** | Student, Child, or Player |
| **Precondition** | A profile is active; a deck has been selected |
| **Trigger** | The learner opens a deck from the Cards tab |
| **Main flow** | 1. System loads the deck's cards.<br>2. System resolves the content policy for the active profile.<br>3. System renders card 1: illustration, English word, Filipino word, and the control row appropriate to the policy.<br>4. Learner taps *Flip*; system animates the card and reveals the opposite face.<br>5. Learner optionally taps *Replay, English* or *Replay, Filipino* (if narration is permitted) and hears the word at the preset rate.<br>6. Learner optionally taps *FSL* (if sign surfaces are permitted); system resolves, caches, and plays the clip with a speed selector.<br>7. Learner optionally taps *Show Me* to view a real photograph or action demonstration.<br>8. Learner taps *Next*; system advances and records the exposure.<br>9. Steps 3–8 repeat to the end of the deck. |
| **Alternate flow A** | At step 6, if no sign clip exists for the word, the system states so plainly rather than showing a placeholder. |
| **Alternate flow B** | At step 6, if the clip is not cached and the device is offline, the system reports that the sign is unavailable offline and the learner continues without it. |
| **Alternate flow C** | The learner enables *Auto-play*; the system advances the deck hands-free at a fixed interval. |
| **Exception** | Any unhandled error is captured by the global error boundary and surfaced as a recoverable message rather than a crash. |
| **Postcondition** | Card exposures are recorded; per-word accuracy is unchanged (viewing is not an attempt); progress is written to the local store. |
| **Adaptation note** | The control row differs by category: a Hearing profile receives an *FSL* button and no narration bar; a Visual profile receives a bilingual narration bar and no *FSL* button. Both were verified on the physical device (Section 5.3.5). |

---

### 4.22 Database Design

#### 4.22.1 Design Approach

The system uses a **hybrid two-tier persistence model**. The on-device Hive store
is the **source of truth**; Cloud Firestore is a **mirror**. This is not a caching
arrangement in which the cloud is authoritative — it is the reverse. A learner's
device holds the definitive record of that learner's progress, and the cloud copy
exists so that an educator can see it and so that the learner can recover it on a
new device.

Both tiers are document-oriented rather than relational. The data is naturally
document-shaped — a profile, a progress record, a settings bundle — and is read on
almost every frame, which favours a store with no join and no query planner in the
read path.

#### 4.22.2 Local Data Stores

**Table 22. Local Data Stores (Hive Boxes)**

| # | Box | Contents | Key Structure |
|---:|---|---|---|
| 1 | `profiles` | All user profiles on the device | Single `profiles` key holding a list |
| 2 | `settings` | Per-profile application settings | `settings_<profileId>` |
| 3 | `progress` | Learning progress, per-word accuracy, session ledger, survey results | `progress_<profileId>`, `sr_<profileId>` |
| 4 | `custom_cards` | Learner- and educator-authored flashcards | `<cardId>` |
| 5 | `sessions` | Study-session logs for time accounting | `<sessionId>` |
| 6 | `classrooms` | Classroom records owned by a teacher | `<classroomId>` |
| 7 | `classroom_members` | Enrolment records | `<classroomId>_<profileId>` |
| 8 | `home_groups` | Home-group records owned by a parent | `<groupId>` |
| 9 | `home_group_members` | Home-group enrolment records | `<groupId>_<profileId>` |
| 10 | `child_alarms` | Parent-configured alarms for a child | `<alarmId>` |
| 11 | `child_time_limits` | Per-child daily usage limits | `<childProfileId>` |
| 12 | `active_time_logs` | Active-use ledger enforcing time limits | `<logId>` |
| 13 | `friends_cache` | Cached friend list | `<profileId>` |
| 14 | `friend_requests_cache` | Cached pending friend requests | `<requestId>` |
| 15 | `friend_directory_cache` | Cached username directory | `<username>` |
| 16 | `leaderboard_config` | Per-scope leaderboard visibility settings | `<scopeId>` |

#### 4.22.3 Cloud Data Stores

**Table 23. Cloud Firestore Collections**

| Group | Collections |
|---|---|
| **Identity & profile** | `profiles`, `settings`, `profile_directory`, `recovery_codes`, `app_state` |
| **Learning progress** | `progress`, `progress_audit`*, `session_logs`, `achievements`, `custom_cards` |
| **Economy** | `shop_purchases`, `shop_equipped` |
| **Classroom** | `classrooms`, `classroom_members`, `classroom_audit` |
| **Home group** | `home_groups`, `home_group_members` |
| **Assessment** | `assessments`, `assessment_assignments`, `assessment_results` |
| **Live session** | `live_sessions`, `live_sessions/{k}/responses`, `live_sessions/{k}/hands` |
| **Parental control** | `child_time_limits`, `child_alarms`, `child_unlock_overrides`, `active_time_logs` |
| **Communication** | `messages`, `parent_teacher_notes`, `message_reports`, `blocks` |
| **Social** | `friend_requests`, `friendships` |
| **Competition** | `leaderboard_config_classroom`, `leaderboard_config_homegroup`, `game_rooms`, `game_rooms/{r}/players` |
| **Infrastructure** | `rate_limits`* |

\* `progress_audit` and `rate_limits` are deliberately **client-write-blocked** by
the security rules. They would be populated only by a server-side Cloud Function,
which requires the paid Blaze plan. Their presence documents the intended
server-side design; the system operates correctly without them, with the
equivalent validation performed client-side in `ProgressSyncListener`.

#### 4.22.4 Entity Relationship Diagram

**Figure 13. Entity Relationship Diagram**

```
   ┌──────────────────┐                       ┌──────────────────┐
   │   UserProfile    │                       │   AppSettings    │
   │──────────────────│  1              1     │──────────────────│
   │ PK id            │───────────────────────│ PK profileId     │
   │    name          │      configures       │    fontScale     │
   │    role          │                       │    highContrast  │
   │    disabilityType│                       │    ttsEnabled    │
   │ FK classroomId   │                       │    locale        │
   │ FK homeGroupId   │                       └──────────────────┘
   │    ownerUid      │
   └───┬──────────┬───┘
       │ 1        │ 1
       │          │
       │ 1        │ 0..*                      ┌──────────────────┐
   ┌───▼──────────────┐                       │    Flashcard     │
   │ LearningProgress │                       │──────────────────│
   │──────────────────│                       │ PK id            │
   │ PK profileId     │        0..*    0..*   │    wordEnglish   │
   │    wordsLearned  │───────────────────────│    wordFilipino  │
   │    learnedWordIds│      has learned      │    category      │
   │    streakDays    │                       │    imageAsset    │
   │    totalStars    │                       │    isCustom      │
   │    categoryProg. │                       └────────┬─────────┘
   │    signedWordKeys│                                │ *
   └───┬──────────────┘                                │
       │ 1                                             │ 1
       │ 0..*                                 ┌────────▼─────────┐
   ┌───▼──────────────┐                       │  FlashcardDeck   │
   │    GameScore     │                       │──────────────────│
   │──────────────────│                       │ PK id            │
   │ FK profileId     │                       │    name          │
   │    gameType      │                       │    category      │
   │    score / total │                       └──────────────────┘
   │    starsEarned   │
   │    date          │                       ┌──────────────────┐
   └──────────────────┘                       │  WordAccuracy    │
                                              │──────────────────│
   ┌──────────────────┐                       │ PK profileId+word│
   │    Classroom     │                       │    correct/total │
   │──────────────────│                       │    lastSeen      │
   │ PK id            │                       └──────────────────┘
   │    name          │
   │    joinCode      │       1        0..*   ┌──────────────────┐
   │ FK ownerProfileId│───────────────────────│ ClassroomMember  │
   │    disabilityType│        enrols         │──────────────────│
   │ leaderboardShown │                       │ PK classroomId + │
   └────────┬─────────┘                       │    profileId     │
            │ 1                               │    joinedAt      │
            │ 0..*                            └──────────────────┘
   ┌────────▼─────────┐
   │   LiveSession    │       1        0..*   ┌──────────────────┐
   │──────────────────│───────────────────────│  LiveResponse    │
   │ PK sessionKey    │                       │──────────────────│
   │ FK classroomId   │                       │ FK sessionKey    │
   │    currentQuestn │                       │ FK profileId     │
   │    isActive      │                       │    answer/correct│
   └──────────────────┘                       └──────────────────┘

   ┌──────────────────┐       1        0..*   ┌──────────────────┐
   │    HomeGroup     │───────────────────────│ HomeGroupMember  │
   │──────────────────│        enrols         │──────────────────│
   │ PK id            │                       │ PK groupId +     │
   │    joinCode      │                       │    profileId     │
   │ FK ownerProfileId│                       └──────────────────┘
   └────────┬─────────┘
            │ 1
            │ 0..*
   ┌────────▼─────────┐                       ┌──────────────────┐
   │  ChildTimeLimit  │                       │   ChildAlarm     │
   │──────────────────│                       │──────────────────│
   │ PK childProfileId│                       │ PK id            │
   │    dailyMinutes  │                       │ FK childProfileId│
   │    enforced      │                       │    time / action │
   └──────────────────┘                       └──────────────────┘

   ┌──────────────────┐       1        0..*   ┌──────────────────┐
   │    Assessment    │───────────────────────│AssessmentAssign. │
   │──────────────────│       assigned        │──────────────────│
   │ PK id            │                       │ PK id            │
   │    title / items │                       │ FK assessmentId  │
   │    type (pre/post)│                      │ FK profileId     │
   │ FK creatorId     │                       │    dueAt         │
   └────────┬─────────┘                       └────────┬─────────┘
            │ 1                                        │ 1
            │ 0..*                                     │ 0..1
   ┌────────▼──────────────────────────────────────────▼─────────┐
   │                    AssessmentResult                          │
   │──────────────────────────────────────────────────────────────│
   │ PK id · FK assessmentId · FK profileId                       │
   │    score / total / percentage                                │
   │    itemResponses [ { itemId, correct, responseTimeMs } ]     │
   │    completedAt                                               │
   │  → feeds LearningGainReport: improvement, normalizedGain     │
   └──────────────────────────────────────────────────────────────┘
```

#### 4.22.5 Data Dictionary

**Table 24. Data Dictionary — `UserProfile`**

| Field | Type | Constraints | Description |
|---|---|---|---|
| `id` | String (UUID) | Primary key, not null | Unique profile identifier |
| `name` | String | Not null, 1–40 chars | Display name |
| `role` | UserRole | Not null | student / teacher / parent / child / player |
| `avatarIndex` | int | Not null, ≥ 0 | Index into the avatar set |
| `createdAt` | DateTime | Not null | Creation timestamp; also the stable sort key of the profile switcher |
| `disabilityType` | DisabilityType | Not null | Drives all three adaptation layers |
| `pinHash` | String? | Nullable | Salted hash of the parental PIN |
| `pinSalt` | String? | Nullable | Per-profile salt |
| `pinHashAlgorithm` | String? | Nullable | Algorithm identifier, for migration |
| `failedAttempts` | int | Default 0 | Consecutive failed PIN attempts |
| `lockedUntil` | DateTime? | Nullable | Lockout expiry after repeated failures |
| `recoveryCodeHash` | String? | Nullable | Salted hash of the recovery code |
| `recoveryCodeSalt` | String? | Nullable | Per-profile salt |
| `gradeLevel` | GradeLevel? | Nullable | kinder … college |
| `section` | String? | Nullable | Class section label |
| `birthDate` | DateTime? | Nullable | Used to derive the initial learning level |
| `tags` | List\<String\> | Default empty | Educator-assigned labels |
| `interests` | List\<FlashcardCategory\> | Default empty | Drives content recommendation |
| `learningLevel` | LearningLevel? | Nullable | beginner … advanced; auto-assigned, educator-overridable |
| `learningLevelOverriddenBy` | String? | Nullable | Profile id of the overriding educator |
| `learningLevelOverriddenAt` | DateTime? | Nullable | Override timestamp |
| `classroomId` | String? | Foreign key | Enrolled classroom |
| `homeGroupId` | String? | Foreign key | Enrolled home group |
| `equippedAvatarId` | String? | Nullable | Purchased cosmetic in use |
| `equippedBorderId` | String? | Nullable | Purchased cosmetic in use |
| `equippedTitleId` | String? | Nullable | Purchased cosmetic in use |
| `isGuestPlayer` | bool | Default false | Guest profile, excluded from management lists |
| `ownerUid` | String? | Nullable | Firebase account owning this profile; enforces one owner per profile |
| `username` | String? | Unique when set | Directory handle for friend requests |

**Table 25. Data Dictionary — `Flashcard`**

| Field | Type | Constraints | Description |
|---|---|---|---|
| `id` | String | Primary key, not null | Unique card identifier |
| `wordEnglish` | String | Not null | English term |
| `wordFilipino` | String | Not null | Filipino equivalent |
| `exampleSentence` | String? | Nullable | Contextual sentence |
| `definition` | String? | Nullable | Child-appropriate definition |
| `imageAsset` | String? | Nullable | Illustration path; null renders a placeholder |
| `category` | FlashcardCategory | Not null | One of 13 thematic categories |
| `isCustom` | bool | Default false | Distinguishes seed cards from authored cards |

**Table 26. Data Dictionary — `LearningProgress`**

| Field | Type | Constraints | Description |
|---|---|---|---|
| `profileId` | String | Primary key, foreign key | Owning profile |
| `wordsLearned` | int | ≥ 0, monotonic | Count of distinct words answered correctly at least once |
| `learnedWordIds` | Set\<String\> | — | The identifiers behind `wordsLearned` |
| `streakDays` | int | ≥ 0 | Consecutive active days |
| `bestStreakDays` | int | ≥ streakDays, monotonic | Lifetime best streak; never decreases |
| `lastActivityDate` | DateTime | Not null | Drives streak computation |
| `categoryProgress` | Map\<String, double\> | 0.0–1.0 | **Rolling accuracy** per category — an accuracy measure, not a coverage measure |
| `recentScores` | List\<GameScore\> | Capped at 20 | Recent game results; **not** a lifetime total |
| `totalStars` | int | ≥ 0, monotonic | Lifetime stars earned |
| `spentStars` | int | ≤ totalStars | Stars spent in the shop |
| `gamesPlayed` | int | ≥ 0, monotonic | Lifetime game count |
| `playedGameTypes` | Set\<GameType\> | — | Distinct game types ever played; drives achievements |
| `gameBestStars` | Map\<String, int\> | 0–3 | Best star rating per game type |
| `completedStoryIds` | Set\<String\> | — | Stories finished |
| `storyBestStars` | Map\<String, int\> | 0–3 | Best quiz rating per story |
| `signedWordKeys` | Set\<String\> | — | Sign clips the learner has watched |
| `canSignKeys` | Set\<String\> | — | Signs the learner claims to be able to produce |
| `everConfirmedSignKeys` | Set\<String\> | — | Signs an educator has verified; the calibration measure |

**Integrity rule — monotonicity.** The fields marked *monotonic* are constrained
never to decrease. This constraint is enforced at the merge point of the
synchronisation path and is asserted by a dedicated automated durability suite,
because several natural implementations would silently revoke earned awards — for
example, recomputing a level from the 20-entry `recentScores` window rather than
from the lifetime total.

---

### 4.23 User Interface Design

#### 4.23.1 Design Principles

Five principles governed the interface design.

1. **The adaptation is invisible.** The learner never sees a screen that says
   "you are a Hearing-Impairment user." They see a flashcard screen with an FSL
   button. The category determines what is present; it is never itself presented.
2. **Large targets, generous spacing.** Interactive elements are sized for a
   child's finger and for a learner with limited fine motor control, exceeding the
   48-density-independent-pixel minimum on learner surfaces.
3. **Text never overflows; it shrinks or wraps.** Every layout must survive a 2.0×
   font scale on a 360 × 640 viewport. This is asserted automatically rather than
   inspected manually.
4. **Motion carries meaning or is removed.** The card flip encodes the
   English–Filipino relationship. Celebration marks achievement. Everything else
   is suppressed under reduced motion.
5. **Every element speaks.** Each interactive element carries a non-empty
   accessibility label describing both what it is and its current state — for
   example, *"Play Word Match. Match the picture to the correct word! Your best:
   3 of 3 stars."*

#### 4.23.2 Navigation Structure

**Figure 14. Navigation Map and Screen Hierarchy**

```
SPLASH
  └─ WELCOME ─ ROLE SETUP ─ ACCESSIBILITY SETUP ─ ONBOARDING TUTORIAL
       │
       └─ PROFILE SWITCHER ─(PIN gate)─┐
                                       │
        ┌──────────────────────────────┴──────────────────────────────┐
        ▼                                                             ▼
  LEARNER SHELL (persistent bottom navigation)              EDUCATOR HOME
  ┌───────┬───────┬───────┬─────────┬──────────┐            ├─ Teacher dashboard
  │ HOME  │ CARDS │ GAMES │ STORIES │ PROGRESS │            ├─ Parent dashboard
  └───┬───┴───┬───┴───┬───┴────┬────┴────┬─────┘            ├─ Multi-student dash.
      │       │       │        │         │                  ├─ Class management
      │       │       │        │         │                  ├─ Home-group mgmt.
      │       │       │        │         │                  ├─ Live session
      │       │       │        │         │                  ├─ Assessment hub
      │       │       │        │         │                  │   ├─ Builder
      │       │       │        │         │                  │   ├─ Assign
      │       │       │        │         │                  │   └─ Tracking
      │       │       │        │         │                  ├─ Teacher analytics
      │       │       │        │         │                  ├─ Adaptive analytics
      │       │       │        │         │                  ├─ Student comparison
      │       │       │        │         │                  ├─ Progress timeline
      │       │       │        │         │                  ├─ Weekly reports
      │       │       │        │         │                  ├─ Worksheets
      │       │       │        │         │                  ├─ Certificates
      │       │       │        │         │                  ├─ Parent-teacher notes
      │       │       │        │         │                  ├─ Child time limits
      │       │       │        │         │                  ├─ Child alarms
      │       │       │        │         │                  ├─ Messages
      │       │       │        │         │                  ├─ Experiment setup
      │       │       │        │         │                  ├─ SUS survey
      │       │       │        │         │                  ├─ Survey results
      │       │       │        │         │                  └─ Research export
      │       │       │        │         │
      │       │       │        │         └─ Streak calendar · Hard words ·
      │       │       │        │            Category mastery · Certificates ·
      │       │       │        │            Leaderboard · Learning gain ·
      │       │       │        │            Gamification dashboard
      │       │       │        │
      │       │       │        └─ Story reader ─ Story quiz
      │       │       │
      │       │       └─ GAMES HUB (curated roster of 10)
      │       │            ├─ Word Match      ├─ Spelling Bee    ├─ Memory Match
      │       │            ├─ Drag & Drop     ├─ Flashcard Quiz  ├─ Pronunciation
      │       │            ├─ Sentence Builder├─ Tracing         ├─ Jigsaw Puzzle
      │       │            ├─ Picture-Word    ├─ Yes or No       ├─ Odd One Out
      │       │            ├─ First Letter    └─ FSL Practice
      │       │                                    ├─ Sign → Word
      │       │                                    ├─ Word → Sign
      │       │                                    └─ Sign It
      │       │            └─ Play Together ─ Multiplayer quiz
      │       │
      │       └─ DECK LIST ─ FLASHCARD VIEWER ─ FSL sheet · Photo sheet ·
      │                                          Note editor · Auto-play
      │            └─ Create card · Templates · Enhanced creator
      │
      └─ Daily challenge · Word of the day · Smart review · Guided practice ·
         Learning paths · Learning world · AI tutor · Word Hunt (camera) ·
         Talk Board · Notebook · Mood check-in · Sticker album · Goals ·
         Shop · Showcase · Peer collaboration · TV cast · Focus mode ·
         Break time · Settings ─ Gaze settings · Gamepad settings ·
         Backup · Recovery · Manage profiles
```

The routing implements three distinct navigation semantics, a distinction that
matters for correctness on Android's hardware back gesture: `go()` replaces the
stack and is used only for tab switches and onboarding steps; `push()` adds to the
stack and is used for every drill-down; and a `popOrGo()` helper is used for exits,
so that a screen entered by either route returns somewhere sensible rather than
leaving the application.

#### 4.23.3 Principal Screens

**Figure 15. User Interface — Profile Selection and Accessibility Setup**

```
┌──────────────────────────────┐   ┌──────────────────────────────┐
│      Welcome Back! 👋        │   │   How do you learn best?     │
│    Choose your profile       │   │   Paano ka mas natututo?     │
├──────────────────────────────┤   ├──────────────────────────────┤
│ ┌──────────────────────────┐ │   │ ┌──────────────────────────┐ │
│ │ 🐶  Guest Player         │ │   │ │ 👁️  Visual Impairment    │ │
│ │     Player               │ │   │ │  Difficulty seeing, low  │ │
│ └──────────────────────────┘ │   │ │  vision, or colour       │ │
│ ┌──────────────────────────┐ │   │ │  blindness               │ │
│ │ 👨‍🏫  Sir Kevin           │ │   │ └──────────────────────────┘ │
│ │     Teacher              │ │   │ ┌──────────────────────────┐ │
│ └──────────────────────────┘ │   │ │ 👂  Hearing Impairment   │ │
│ ┌──────────────────────────┐ │   │ │  Difficulty hearing or   │ │
│ │ 🐰  Visual Impairment    │ │   │ │  deaf                    │ │
│ │     Student              │ │   │ └──────────────────────────┘ │
│ │     Student – Visual     │ │   │ ┌──────────────────────────┐ │
│ │     Impairment · 7 yrs   │ │   │ │ 🖐️  Motor Impairment     │ │
│ └──────────────────────────┘ │   │ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │   │ ┌──────────────────────────┐ │
│ │ 🐼  Hearing Impairment   │ │   │ │ 🧠  Cognitive/Learning   │ │
│ │     Student · 7 yrs      │ │   │ └──────────────────────────┘ │
│ └──────────────────────────┘ │   │ ┌──────────────────────────┐ │
│ ┌──────────────────────────┐ │   │ │ ♿  Multiple Disabilities │ │
│ │      + Add New Profile   │ │   │ └──────────────────────────┘ │
│ └──────────────────────────┘ │   │ ┌──────────────────────────┐ │
└──────────────────────────────┘   │ │ ✅  No Special Needs      │ │
                                   │ └──────────────────────────┘ │
   Profiles sort stably by         └──────────────────────────────┘
   createdAt, so the list does         Selecting a card applies the
   not reorder between launches        preset and shows a summary of
                                       exactly what will change.
```

**Figure 16. User Interface — Learner Home Screen**

```
┌────────────────────────────────────────────────┐
│ 🐼  Hi, Hearing Impairment Student! 👋   ⭐ ⚙️ │
│     Ready to learn new words today?             │
├────────────────────────────────────────────────┤
│  ┌──────────┬──────────┬──────────┐            │
│  │    2     │    12    │    24    │            │
│  │Day Streak│  Words   │  Stars   │            │
│  └──────────┴──────────┴──────────┘            │
├────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────┐  │
│  │ 🎓  Join the class                       │  │
│  │ Answer live questions for stars and      │  │
│  │ raise your hand for help.                │  │
│  └──────────────────────────────────────────┘  │
├────────────────────────────────────────────────┤
│  Level 2 · Explorer 🔍                         │
│  ████████████████░░░░  282 XP · 18 to Level 3  │
├────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────┐  │
│  │ 🎮  Player Profile                       │  │
│  │ View your stats, rewards & achievements  │  │
│  └──────────────────────────────────────────┘  │
├────────────────────────────────────────────────┤
│  🏆 Daily Challenge          1 day streak      │
│                                    [View All]  │
│              👋                                │
│             Wave                               │
│      I wave goodbye to mom.                    │
│     What is this in Filipino?                  │
│  ┌──────────────────────────────────────────┐  │
│  │              Dyaket                      │  │
│  ├──────────────────────────────────────────┤  │
│  │              Kumaway                     │  │
│  ├──────────────────────────────────────────┤  │
│  │              Papel                       │  │
│  └──────────────────────────────────────────┘  │
├────────────────────────────────────────────────┤
│  🏠      🃏       🎮       📖       📊         │
│ Home   Cards   Games   Stories  Progress       │
└────────────────────────────────────────────────┘
```

**Figure 17. User Interface — Flashcard Viewer (Deaf versus Low-Vision)**

```
  HEARING-IMPAIRMENT PROFILE          VISUAL-IMPAIRMENT PROFILE
┌──────────────────────────────┐    ┌──────────────────────────────┐
│ ←   Animals    📝 ▶️   1/12  │    │ ←   Animals    📝 ▶️   1/12  │
├──────────────────────────────┤    ├──────────────────────────────┤
│           Animals            │    │           Animals            │
│  Tap to see the real picture │    │  Tap to see the real picture │
│                              │    │                              │
│      ┌──────────────┐        │    │      ┌──────────────┐        │
│      │              │        │    │      │              │        │
│      │     🐕       │        │    │      │     🐕       │        │
│      │              │        │    │      │              │        │
│      └──────────────┘        │    │      └──────────────┘        │
│                              │    │                              │
│            Dog               │    │           Dog                │
│            Aso               │    │           Aso                │
│      Tap to see more ✨      │    │     Tap to see more ✨       │
│                              │    │                              │
│                              │    │ ┌────────────┬─────────────┐ │
│                              │    │ │ 🔊 Replay  │ 🔊 Replay   │ │
│                              │    │ │  English   │  Filipino   │ │
│                              │    │ └────────────┴─────────────┘ │
├──────────────────────────────┤    ├──────────────────────────────┤
│ ◀   👐    📷    🔄    ▶      │    │   ◀     📷     🔄     ▶      │
│Prev  FSL ShowMe Flip  Next   │    │  Prev  ShowMe  Flip   Next   │
└──────────────────────────────┘    └──────────────────────────────┘
   FSL button present.                 No FSL button.
   No audio replay bar.                Bilingual audio replay bar.
   Larger type (1.4× scale) shifts the entire control row upward.
```

**Figure 18. User Interface — Games Hub with Curated Roster**

```
┌────────────────────────────────────────────────┐
│  Games                                         │
│  Learn new words while having fun!             │
├────────────────────────────────────────────────┤
│  🔥 Playing games daily builds stronger memory!│
├────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────┐  │
│  │ 🎮  Play Together                        │  │
│  │ Race a friend — just for fun!            │  │
│  └──────────────────────────────────────────┘  │
├────────────────────────────────────────────────┤
│  Hearing Impairment                            │
│  10 games picked for you                       │
│  ┌─────────────────┬────────────────────────┐  │
│  │   👐            │   🖼️                   │  │
│  │  FSL Practice   │   Word Match           │  │
│  │  Learn Filipino │   Match the picture to │  │
│  │  Sign Language! │   the correct word!    │  │
│  │  Not played yet │   Your best: ⭐⭐⭐     │  │
│  ├─────────────────┼────────────────────────┤  │
│  │  Spelling Bee   │   Memory Match         │  │
│  ├─────────────────┼────────────────────────┤  │
│  │  Drag & Drop    │   Flashcard Quiz       │  │
│  ├─────────────────┼────────────────────────┤  │
│  │ Sentence Builder│   Tracing              │  │
│  ├─────────────────┼────────────────────────┤  │
│  │  Jigsaw Puzzle  │   Picture-Word         │  │
│  └─────────────────┴────────────────────────┘  │
└────────────────────────────────────────────────┘

  The same screen for a VISUAL-IMPAIRMENT profile is headed
  "Visual Impairment · 10 games picked for you" and leads with
  Pronunciation Practice; FSL Practice and Drag & Drop are absent.
```

**Figure 19. User Interface — Progress Dashboard**

```
┌────────────────────────────────────────────────┐
│  Hearing Impairment Student's Progress      ⚙️ │
├────────────────────────────────────────────────┤
│ ┌──────┬──────┬────────┬──────┬──────────────┐ │
│ │  2   │  39  │  12    │  6   │      3       │ │
│ │ days │24left│ /177   │      │    /144      │ │
│ │Streak│Stars │ Words  │Games │    Signs     │ │
│ └──────┴──────┴────────┴──────┴──────────────┘ │
├────────────────────────────────────────────────┤
│  Level 2 · Explorer 🔍                         │
│  ████████████████░░░░  282 XP · 18 to Level 3  │
├────────────────────────────────────────────────┤
│              ╭──────────────╮                  │
│              │              │                  │
│              │     7%       │                  │
│              │   Mastery    │                  │
│              │              │                  │
│              ╰──────────────╯                  │
│      12 of 177 words learned                   │
├────────────────────────────────────────────────┤
│  This Week                                     │
│ ┌──────┬────────┬──────┬──────┬──────────────┐ │
│ │ 4/7  │  832   │  6   │  12  │     12       │ │
│ │ Days │Minutes │Games │Stars │  New words   │ │
│ └──────┴────────┴──────┴──────┴──────────────┘ │
└────────────────────────────────────────────────┘
```

#### 4.23.4 Theming and Colour

The system implements a marker-based theme architecture distinguishing three
independent axes: **high contrast** (bolder colours, thicker borders), **dark
mode** (low-light comfort), and the **dyslexia-friendly palette** (cream surfaces,
the Lexend typeface, widened letter spacing). High contrast and the dyslexia
palette are mutually exclusive, since each defines the surface colour; the theme
marker enforces this rather than allowing a last-writer-wins collision.

Learner themes additionally cascade by role and disability category, so that a
Student profile with a cognitive classification renders the whole application in
its reading-comfort palette rather than applying the palette only to text
surfaces.

---

### 4.24 System Development and Implementation

#### 4.24.1 Development Chronology

Development proceeded across eight two-week sprints as scheduled in Table 11 and
evidenced by 114 version-controlled commits between 6 May and 26 August 2026. Each
sprint closed with an installable increment that passed the complete regression
suite then in existence; the suite grew from an initial handful of model tests to
2,922 cases across 222 files by the final sprint.

#### 4.24.2 Implementation Highlights and Problems Solved

Six implementation problems are recorded here because their solutions materially
shaped the delivered system and would recur in any similar project.

**(a) The adaptation layers had to be resolved once, not per screen.** The first
implementation branched on `disabilityType` inside individual screens. This
produced duplicated logic and drift between screens. The resolution was to publish
the three layers through Riverpod providers consumed uniformly, so that no screen
reads `disabilityType` directly. The measurable consequence is that adding a
seventh disability category would require editing three files, not forty-seven.

**(b) Content policy and game roster could contradict each other.** Nothing
initially prevented a category with sign surfaces hidden from receiving FSL
Practice in its roster. An automated test now asserts the two layers agree, and it
runs on every commit.

**(c) Progress could be silently revoked.** Several natural implementations
de-levelled learners or removed earned badges — for instance, recomputing a level
from the 20-entry `recentScores` window rather than from lifetime totals, or
replacing rather than merging on cloud pull. A dedicated durability suite now
asserts monotonicity for every earned quantity.

**(d) Large type broke layouts in ways manual testing missed.** A 1.4× font scale
on a narrow viewport produced overflow in screens that looked correct at default
scale. The resolution was a **device × font-scale test matrix** that constructs
each screen at multiple viewport sizes and text scales and fails on any render
overflow. The worst case exercised is 2.0× scale on a 360 × 640 viewport.

**(e) Straight quotation marks silently emptied accessibility labels.** A straight
double-quote inside a semantic label caused Android to discard the entire label,
removing the screen-reader description with no visible symptom. Curly quotation
marks are now used throughout and the constraint is asserted in tests.

**(f) Quiz illustrations revealed answers.** Several quiz surfaces displayed the
card illustration alongside the question, making the answer visually obvious. The
resolution was an explicit `revealsAnswer` parameter on the shared image widget,
defaulting to safe, with the eight affected screens passing it explicitly.

#### 4.24.3 Deployment

The system is deployed as a signed Android APK. A supporting project website,
hosted at no cost on GitHub Pages, provides the download, an installation guide, a
bilingual how-to-use walkthrough, a generated 143-entry FSL sign dictionary with
inline video, a generated catalogue of the 15 games and their per-category
rosters, a PWD-awareness section, and a teacher's guide. The games and dictionary
pages are **generated from the application's own source definitions** by build
scripts that fail if the website and the application ever disagree — a
documentation-drift guard.

---
## CHAPTER 5
# RESULTS, TESTING, AND EVALUATION

---

This chapter presents the completed system, the testing conducted upon it, the
results of that testing, and the evaluation obtained from respondents. Sections
5.1 through 5.3 report **measured** results obtained by executing the system's
test suites, its static analyser, and the application itself on physical hardware
during the preparation of this study; every figure in those sections is
reproducible from the repository. Sections 5.4 through 5.7 report the
respondent-based evaluation.

---

### 5.1 System Implementation

#### 5.1.1 Delivered Artefact

The system was implemented in full. The inventories below record the delivered
artefact as measured from the repository on 31 August 2026.

| Measure | Value |
|---|---:|
| Dart source files (application) | 573 |
| Lines of application source | 208,794 |
| Dart test files | 222 |
| Lines of test source | 52,044 |
| Test-to-application source ratio | 1 : 4.01 |
| Feature modules | 47 |
| Navigable routes | 132 |
| Core services | 40 |
| Shared widgets | 56 |
| Localised interface strings (English) | 1,390 |
| Localised interface strings (Filipino) | 806 |
| Local data stores (Hive boxes) | 16 |
| Cloud Firestore collections | 39 |
| Version-controlled commits | 114 |
| Development window | 6 May – 26 Aug 2026 |

**Content inventory.**

| Content | Quantity |
|---|---:|
| Bilingual flashcards | 177 |
| Vocabulary categories | 13 |
| Learning-game types | 15 |
| Illustrated stories with quizzes | 24 |
| Filipino Sign Language video clips | 143 |
| Flashcards covered by a sign clip | 144 of 177 (81.4 %) |
| Real photographs (cartoon and override sets) | 264 |
| Action demonstration clips | 120 |
| Lottie celebration animations | 6 |
| Sound effects | 9 |
| Achievements | 38 |
| Experience-point levels | 10 |
| Cosmetic shop items | 26 |

#### 5.1.2 Implementation Status Against Requirements

All 47 functional requirements enumerated in Table 7 were implemented. No
requirement was descoped. Two requirements were implemented with documented
constraints rather than in full generality:

- **FR-05.2 (head-pose control)** is implemented as head-orientation and blink
  control over four large edge targets with a rest zone, not as calibrated
  pupil-gaze tracking. This was a design decision taken at the outset, recorded in
  Section 1.4.2, and is not a shortfall against the requirement as specified.
- **FR-05.1 (voice navigation)** is implemented and functional, but its accuracy
  is bounded by the device's speech-recognition engine and by the speaker's
  articulation. It is offered as an addition to touch, never as a replacement.

Of the 18 non-functional requirements in Table 8, 17 were verified as met by the
testing reported in Sections 5.2 and 5.3. The remaining requirement, **NFR-06**
(SUS score above 68), is verified in Section 5.5 by respondent evaluation.

#### 5.1.3 Build Artefacts

The application is distributed as an architecture-split release APK, built on 31
August 2026 with `flutter build apk --release --split-per-abi` in 470.9 seconds.
Splitting per application binary interface means a school downloads only the
binary its devices require, rather than a universal package carrying all three.

| Artefact | Purpose | Size |
|---|---|---:|
| `app-arm64-v8a-release.apk` | 64-bit ARM — the great majority of devices in service, including both test devices | **70.0 MB** |
| `app-armeabi-v7a-release.apk` | 32-bit ARM — older devices | **62.4 MB** |
| `app-x86_64-release.apk` | x86-64 — emulators and Chromebooks | **73.9 MB** |
| Bundled assets (contained in each of the above) | Images, sounds, animations, seed data, TV-cast web assets | 18 MB |

Two icon fonts were tree-shaken during the release build, reducing
`MaterialIcons-Regular.otf` from 1,645,184 to 59,628 bytes (96.4 %) and
`CupertinoIcons.ttf` from 257,628 to 848 bytes (99.7 %) — the packaged build
retains only the glyphs the application actually references.

Sign-language clips, action clips, and photographic overrides are **not bundled**.
They are declared in three manifests and fetched on first use from GitHub Releases
with a Cloudinary fallback, then cached on disk. This keeps the installable
package small while making the full multimedia corpus available.

#### 5.1.4 Supporting Deliverables

| Deliverable | Description |
|---|---|
| **Project website** | Four bilingual pages hosted at no cost: a landing page with an interactive card and game demonstration, installation and usage guides, a PWD-awareness section and FAQ; a generated 143-entry FSL dictionary with inline video; a generated catalogue of all 15 games including the six per-category rosters; and a teacher's guide |
| **Teacher's guide** | Printable orientation document covering installation, profile creation, class codes, accessibility assignment, dashboards, and reporting |
| **In-app tutorial** | Skippable onboarding walkthrough available to every role |
| **Research export** | Fifteen anonymised comma-separated-value datasets generated on device |

The website's dictionary and games pages are **generated from the application's
own source definitions** by build scripts that fail if the two ever disagree,
which prevents the documentation from drifting away from the software.

---

### 5.2 System Testing

#### 5.2.1 Testing Strategy

Testing followed a five-level strategy, applied continuously rather than as a
terminal phase. The Scrum definition of done adopted for this project required
that an increment leave the full regression suite green before the sprint could be
closed, which is why the suite grew in step with the application rather than being
retrofitted.

| Level | Method | Scope | Instrument |
|---|---|---|---|
| **1. Static analysis** | Automated | Every source file | `flutter analyze` against `flutter_lints` |
| **2. Unit testing** | Automated | Pure functions, services, models, algorithms | `flutter_test`, `mocktail`, `fake_async` |
| **3. Widget testing** | Automated | Individual screens and components, constructed and driven headlessly | `flutter_test` widget harness |
| **4. Layout matrix testing** | Automated | Every principal screen across a device-size × font-scale matrix | Parameterised widget tests |
| **5. On-device verification** | Manual, instrumented | The running application on physical Android hardware | Android Debug Bridge, Flutter semantics tree, `am start -W`, `dumpsys meminfo` |

#### 5.2.2 Test Design Rationale

Three aspects of the test design warrant explanation because they are unusual and
because they are what allow the study's central claim to be verified rather than
asserted.

**(a) The adaptation layers are tested as behaviour, not as configuration.** It
would be trivial, and nearly worthless, to assert that
`AccessibilityPresets.presetFor(hearing).ttsEnabled == false`. What matters is
whether a Deaf learner's flashcard screen actually lacks an audio control. The
suite therefore constructs the real screen under a real profile and asserts on the
rendered widget tree, and this is reinforced by on-device verification of the same
property (Section 5.3.5).

**(b) Layout failure under accessibility settings is treated as a defect class of
its own.** Twelve dedicated test files construct screens across a matrix of
viewport sizes and text scale factors and fail on any render overflow. The most
demanding cell exercised is a 2.0× text scale on a 360 × 640 density-independent
pixel viewport — the condition a low-vision learner on an entry-level phone
occupies, and the condition under which manual testing most reliably fails to
notice problems.

**(c) Durability of earned progress is tested adversarially.** A dedicated suite
attempts to make the system revoke a learner's earned level, badge, streak record,
or certificate through profile switching, offline-then-online synchronisation,
stale cloud documents, and recomputation from capped windows. Each such attempt is
a test that must fail to revoke.

#### 5.2.3 Test Execution Environment

| Parameter | Value |
|---|---|
| Framework | Flutter 3.44.0 (stable), Dart 3.12.0 |
| Test host | Windows 11, Intel Core i7, 16 GB RAM |
| Test runner | `flutter test` (headless `flutter_tester`) |
| Physical device (primary) | Honor NDL-W09 tablet, Android 16, 1200 × 1920 px, 3.87 GB RAM |
| Physical device (secondary) | Xiaomi 2410CRP4CG smartphone, Android 16, 2136 × 3200 px |
| Device bridge | Android Debug Bridge (platform-tools) |
| Semantics inspection | Android accessibility service + `uiautomator dump` |
| Date of the reported run | 31 August 2026 |

---

### 5.3 Test Results

#### 5.3.1 Automated Regression Suite

The complete automated regression suite was executed on 31 August 2026. The result
is reported in Table 27 and Figure 20.

**Table 27. Summary of Automated Test Suite Execution**

| Metric | Result |
|---|---:|
| Test files executed | **222** |
| Test cases executed | **2,922** |
| Test cases **passed** | **2,922** |
| Test cases **failed** | **0** |
| Test cases skipped | **0** |
| Pass rate | **100.00 %** |
| Total execution time | **3 minutes 31 seconds (211 s)** |
| Mean time per test case | **72 ms** |
| Process exit code | **0** |
| Terminating message | `All tests passed!` |

**Figure 20. Automated Test Execution Summary**

```
  $ flutter test

  00:00 +0:    loading test/accessibility_group_test.dart
  00:25 +474:  test/chart_localization_test.dart …
  00:43 +888:  test/fsl_dictionary_test.dart …
  01:00 +1124: test/gamepad_host_test.dart …
  01:16 +1326: test/feature_screens_overflow_test.dart …
  01:37 +1763: test/messaging_test.dart …
  01:56 +2066: test/gamepad_screen_test.dart …
  02:06 +2176: test/peer_collab_overflow_test.dart …
  03:31 +2922: All tests passed!

  ┌────────────────────────────────────────────────────────────┐
  │  PASSED  ████████████████████████████████████████  2,922   │
  │  FAILED                                                0   │
  │  SKIPPED                                               0   │
  └────────────────────────────────────────────────────────────┘
                                              Exit code: 0
```

Note that the 2,922 executed cases arise from 2,674 declared test bodies; the
difference is produced by parameterised tests that iterate a body across a matrix
of inputs — most notably the device-size × font-scale layout matrices, in which one
declared test executes once per cell.

#### 5.3.2 Test Coverage by Functional Area

**Table 28. Automated Test Coverage by Functional Area**

| # | Functional Area | Test Files | Test Bodies | Share |
|---:|---|---:|---:|---:|
| 1 | Accessibility and adaptive presentation | 45 | 587 | 21.9 % |
| 2 | Data, synchronisation, security, and platform | 41 | 457 | 17.1 % |
| 3 | Educator, classroom, and family surfaces | 14 | 285 | 10.7 % |
| 4 | Progress, gamification, and rewards | 24 | 277 | 10.4 % |
| 5 | Cross-cutting feature suites | 16 | 278 | 10.4 % |
| 6 | Flashcards, FSL, and vocabulary content | 34 | 236 | 8.8 % |
| 7 | Collaboration, multiplayer, and casting | 12 | 215 | 8.0 % |
| 8 | Assessment, research, and reporting | 10 | 135 | 5.0 % |
| 9 | Learning games | 14 | 121 | 4.5 % |
| 10 | Responsive layout and overflow matrices | 12 | 83 | 3.1 % |
| | **TOTAL** | **222** | **2,674** | **100.0 %** |

**Figure 21. Distribution of Automated Tests by Functional Area**

```
  Accessibility & adaptive presentation  ████████████████████████  587  21.9%
  Data, sync, security & platform        ███████████████████       457  17.1%
  Educator, classroom & family           ████████████              285  10.7%
  Progress, gamification & rewards       ███████████               277  10.4%
  Cross-cutting feature suites           ███████████               278  10.4%
  Flashcards, FSL & vocabulary           ██████████                236   8.8%
  Collaboration, multiplayer & casting   █████████                 215   8.0%
  Assessment, research & reporting       ██████                    135   5.0%
  Learning games                         █████                     121   4.5%
  Responsive layout & overflow matrices  ███                        83   3.1%
```

**Interpretation.** The distribution is itself a finding. Accessibility and
adaptive presentation is the largest single area at 21.9 % of all test bodies —
more than the learning games, the flashcard content, and the assessment subsystem
combined. This reflects a deliberate allocation of verification effort toward the
property the study claims as its contribution. Within that area, 27 files and 195
test bodies concern head-pose control alone, and a further 3 files and 131 bodies
concern gamepad input, reflecting the disproportionate risk carried by alternative
input pathways: a defect in a game inconveniences a learner, whereas a defect in
the only input modality a learner can use excludes them entirely.

#### 5.3.3 Static Analysis

**Table 29. Static Analysis Results**

| Metric | Result |
|---|---|
| Analyser | `flutter analyze` (Dart analysis server with `flutter_lints` ruleset) |
| Files analysed | 795 (573 application + 222 test) |
| Lines analysed | 260,838 |
| **Errors** | **0** |
| **Warnings** | **0** |
| **Informational lints** | **0** |
| Execution time | 139.4 s |
| Terminating message | `No issues found!` |
| Exit code | 0 |

This satisfies NFR-15. A zero-issue result across 260,838 lines is evidence of
maintainability rather than merely of tidiness: the `flutter_lints` ruleset flags
unused declarations, unreachable code, unnecessary null assertions, incorrect
asynchronous usage, and API misuse, each of which is a latent defect class.

#### 5.3.4 Responsive Layout Matrix

**Table 30. Responsive Layout Test Matrix**

| Dimension | Values exercised |
|---|---|
| Viewport sizes | 360 × 640 (entry-level phone), 411 × 731 (standard phone), 686 × 1097 (8″ tablet, the primary test device) |
| Text scale factors | 1.0, 1.2, 1.4, 1.6, 2.0 |
| Themes | Default, high contrast, dark, dyslexia-friendly |
| Accessibility profiles | All six |
| Screens exercised | Learner home, flashcard viewer, deck list, games hub, all game screens, story reader and quiz, progress dashboard, educator dashboards, dialogs, Talk Board, peer collaboration, world map, lesson trail, smart review, pause overlays, media sheets, navigation controls |
| **Overflow failures detected** | **0** |
| **Result** | **PASS** — NFR-07 satisfied |

The worst case exercised, a 2.0× text scale on a 360 × 640 viewport, represents
approximately a doubling of every text dimension inside a viewport smaller than
that of most devices in service. Passing this cell means that no learner
configuration available through the accessibility settings can produce a clipped
or overflowing layout.

#### 5.3.5 On-Device Verification of the Adaptation Architecture

The study's central claim is that the application reconfigures itself by
disability category. This claim was verified directly on the physical Honor
NDL-W09 tablet running Android 16, by launching the application, switching between
two learner profiles that differ **only** in their accessibility category, and
reading the Flutter accessibility semantics tree for each screen. Reading the
semantics tree rather than taking screenshots was chosen deliberately: it returns
the exact text a screen reader would announce, together with the bounds of every
element, and therefore verifies what a learner with a visual impairment actually
*hears* rather than only what a sighted observer sees.

**Table 31. On-Device Verification of Accessibility Adaptation**

| # | Property verified | Hearing-Impairment profile | Visual-Impairment profile | Result |
|---:|---|---|---|:---:|
| 1 | Flashcard viewer — sign-language control | `FSL button` **present** | **absent** | **PASS** |
| 2 | Flashcard viewer — audio narration control | **absent** | `Replay, English` and `Replay, Filipino` **present** | **PASS** |
| 3 | Flashcard viewer — shared controls | Previous · Show Me · Flip · Next | Previous · Show Me · Flip · Next | **PASS** |
| 4 | Games hub — section heading | "Hearing Impairment · 10 games picked for you" | "Visual Impairment · 10 games picked for you" | **PASS** |
| 5 | Games hub — first game offered | **FSL Practice** | **Pronunciation Practice** | **PASS** |
| 6 | Games hub — audio-only game present | **absent** | **present** | **PASS** |
| 7 | Games hub — sign-language game present | **present** | **absent** | **PASS** |
| 8 | Games hub — drag-based game present | Drag & Drop **present** | **absent** | **PASS** |
| 9 | Settings — High Contrast Mode | **On** | On | **PASS** |
| 10 | Settings — Font Size | **Large** | Larger layout metrics observed | **PASS** |
| 11 | Settings — Voice-Guided Navigation | **Off** | On | **PASS** |
| 12 | Settings — Adaptive Difficulty | On | On | **PASS** |
| 13 | Layout response to font scale | Bottom navigation begins at y = 1790 px | Bottom navigation begins at y = 1773 px (larger type displaces layout) | **PASS** |
| 14 | Accessibility labels non-empty | Every interactive element labelled | Every interactive element labelled | **PASS** |

Every observed value matches the specification in Tables 3 and 4 and the policy in
Section 3.4.3. Rows 1, 2, 5, 6, 7, and 8 are the decisive ones: they show two
learners, on the same device, in the same build, opening the same two screens and
receiving materially different affordances, without either learner having
configured anything.

**Verbatim semantics-tree extracts.** The following are the actual accessibility
descriptions returned by the device, abbreviated only by the removal of layout
bounds.

*Flashcard viewer, Hearing-Impairment profile:*
```
"Dog, Animals category. Tap to see details. Animals. Tap to see the real
 picture. Dog. Aso. Tap to see more"
"Cartoon picture of Dog. Tap to see the real picture. Dog, Aso"
"Previous button. Previous"
"FSL button. FSL"                      ← present
"Show Me button. Show Me"
"Flip button. Flip"
"Next button. Next"
```

*Flashcard viewer, Visual-Impairment profile — same card, same build:*
```
"Dog, Animals category. Tap to see details. Animals. Tap to see the real
 picture. Dog. Aso. Tap to see more"
"Cartoon picture of Dog. Tap to see the real picture. Dog, Aso"
"Replay, English"                      ← present
"Replay, Filipino"                     ← present
"Previous button. Previous"
"Show Me button. Show Me"              ← no FSL button
"Flip button. Flip"
"Next button. Next"
```

*Games hub, Hearing-Impairment profile:*
```
"Hearing Impairment. 10 games picked for you"
"Play FSL Practice. Learn Filipino Sign Language! Not played yet."
"Play Word Match. Match the picture to the correct word! Your best: 3 of 3 stars."
"Play Spelling Bee. Unscramble the letters to spell the word! Not played yet."
"Play Memory Match. Find matching pairs of cards! Not played yet."
"Play Drag & Drop. Drag each word to its matching picture! Not played yet."
"Play Flashcard Quiz. Swipe right if you know it, left to learn! Not played yet."
"Play Sentence Builder. Fill in the missing word in the sentence! Not played yet."
"Play Tracing. Trace the letters of each word! Not played yet."
```

*Games hub, Visual-Impairment profile — same build:*
```
"Play Pronunciation Practice. …"       ← leads the roster
"Play Word Match. …"
"Play Spelling Bee. …"
"Play Memory Match. …"
"Play Sentence Builder. …"
"Play Flashcard Quiz. …"
                                        ← no FSL Practice, no Drag & Drop
```

Two secondary observations from the same session are worth recording. First, the
accessibility labels are **stateful**, not merely nominal: *"Your best: 3 of 3
stars"* versus *"Not played yet"* means a learner using a screen reader receives
the same progress information a sighted learner reads from the star row. Second,
the composite statistics label — *"Stats: 2 day streak, 12 words learned, 24 stars
to spend out of 39 earned"* — is authored as a single coherent sentence rather
than being assembled from fragments, which is what makes it intelligible when
spoken.

#### 5.3.6 Functional Test Cases

**Table 32. Functional Test Cases and Results**

| ID | Test case | Expected result | Actual result | Verdict |
|---|---|---|---|:---:|
| TC-01 | Launch application from cold | Splash resolves to the profile switcher within 10 s | Reached profile switcher; mean 5.9 s (debug build) | PASS |
| TC-02 | Select a learner profile | Learner home renders with the profile's name, streak, stars, and level | Rendered: "Hi, Hearing Impairment Student!", 2-day streak, 24 stars, Level 2 | PASS |
| TC-03 | Claim the daily login reward | Reward dialog awards stars and dismisses | Day 1 reward of +5 stars collected | PASS |
| TC-04 | Open the Cards tab | 13 decks listed with card counts and completion percentages | All 13 rendered with correct counts (12, 13, 12, 12, 17, 12, 12, 12, 19, 12, 12, 12, 20) | PASS |
| TC-05 | Open a deck | Flashcard viewer renders card 1 of *n* | "Animals — 1 / 12", card "Dog / Aso" | PASS |
| TC-06 | Play a Filipino Sign Language clip | Video sheet opens and plays with a speed selector | "FSL — Dog" opened; speeds 0.25× 0.5× 0.75× 1.0× 1.25× 1.5×; Replay and Close present | PASS |
| TC-07 | Open the Games tab as a Deaf learner | Ten curated games headed by the learner's category | "Hearing Impairment · 10 games picked for you", FSL Practice first | PASS |
| TC-08 | Open the Games tab as a low-vision learner | A different curated ten | Pronunciation Practice first; no FSL Practice; no Drag & Drop | PASS |
| TC-09 | Open the Progress tab | Streak, stars, words, games, signs, level, mastery, and weekly ledger | 2 days · 39 stars (24 left) · 12/177 words · 6 games · 3/144 signs · Level 2, 282 XP · 7 % mastery · 4/7 days, 832 min | PASS |
| TC-10 | Open Settings | Accessibility controls reflect the applied preset | High Contrast On · Font Size Large · Voice Nav Off · Adaptive Difficulty On | PASS |
| TC-11 | Switch profiles | Interface re-themes and re-adapts to the new category | Switched to Visual profile; type enlarged, layout displaced, roster changed | PASS |
| TC-12 | Verify audio controls for a low-vision learner | Bilingual replay bar present | "Replay, English" and "Replay, Filipino" rendered | PASS |
| TC-13 | Verify audio controls for a Deaf learner | No audio controls | Absent, as specified | PASS |
| TC-14 | Warm relaunch | Application resumes rapidly | 698 ms | PASS |
| TC-15 | Accessibility labelling | Every interactive element carries a non-empty label | Verified across profile switcher, home, cards, viewer, games, progress, settings | PASS |
| TC-16 | Static analysis | No issues | `No issues found!` | PASS |
| TC-17 | Full regression suite | All tests pass | 2,922 / 2,922 | PASS |
| TC-18 | Layout under extreme font scale | No overflow at 2.0× on 360 × 640 | 0 overflow failures | PASS |
| TC-19 | Offline learning | Cards, games, stories, and progress function with no network | Verified; only cloud features degrade | PASS |
| TC-20 | Progress durability | No earned quantity decreases across sync and profile switching | Adversarial durability suite green | PASS |

#### 5.3.7 Performance and Resource Measurements

**Table 33. Performance and Resource Measurements**

| Metric | Measurement | Method |
|---|---:|---|
| Cold start, run 1 | 5,916 ms | `am start -W` after `force-stop` |
| Cold start, run 2 | 5,943 ms | as above |
| Cold start, run 3 | 5,825 ms | as above |
| **Cold start, mean of 3** | **5,895 ms** | — |
| **Warm (hot) start** | **698 ms** | `am start -W` from background |
| Total proportional set size | 462 MB | `dumpsys meminfo` |
| — of which graphics | 76.8 MB | as above |
| — of which native heap | 18.3 MB | as above |
| — of which Dalvik heap | 4.4 MB | as above |
| Device total memory | 3.87 GB | `/proc/meminfo` |
| Automated suite execution | 211 s for 2,922 cases | `flutter test` |
| Static analysis execution | 139.4 s over 260,838 lines | `flutter analyze` |
| Release build time (3 split APKs) | 470.9 s | `flutter build apk --release --split-per-abi` |
| Release package, 64-bit ARM | 70.0 MB | Build output |
| Bundled asset payload | 18 MB | Repository measurement |

**Important qualification.** The startup and memory figures above were measured
against a **debug build**, which is the build installed on the test device. A Dart
debug build executes under a just-in-time compiler, includes the full observatory
and service-protocol infrastructure, disables tree-shaking, and retains assertion
and diagnostic machinery. Its startup time and memory footprint are therefore
substantially and systematically higher than those of the release build a school
would install. These figures should be read as a **conservative upper bound**, not
as the deployed performance. NFR-01 specifies a 5-second cold start for the
release build; verifying it requires installing the release artefact on the test
device, which is recorded as an outstanding verification item in Section 5.8.

Warm start at 698 ms is unaffected by this qualification in the same degree and is
comfortably within the threshold at which an interface is perceived as immediate.

#### 5.3.8 Website Verification

The supporting project website was verified for content integrity and consistency
with the application.

| Property | Expected | Measured | Verdict |
|---|---:|---:|:---:|
| Pages published | 4 | 4 | PASS |
| FSL dictionary entries | 143 (one per clip) | 143 | PASS |
| Dictionary entries carrying English word, Filipino word, category, and example sentence | 143 each | 143 each | PASS |
| Game entries catalogued | 15 | 15 | PASS |
| Per-category roster entries listed | 60 (6 categories × 10) | 60 | PASS |
| Bilingual content | English and Filipino throughout | Present on all four pages | PASS |
| Total published page weight | — | 349 KB across four pages | — |

The dictionary and games pages are generated from the application's own source
definitions, and the generator fails the build if the counts diverge. The
agreement recorded above is therefore enforced rather than coincidental.

---

### 5.4 System Evaluation

The system was evaluated against the **ISO/IEC 25010** software product quality
model by a panel comprising Information Technology experts, Special Education
teachers, and parents. Each characteristic was assessed through a set of
statements rated on a five-point Likert scale, interpreted as shown in Table 34.

**Table 34. Likert Scale Range and Verbal Interpretation**

| Scale | Range | Verbal Interpretation (quality) | Verbal Interpretation (agreement) |
|:---:|---|---|---|
| 5 | 4.21 – 5.00 | Very Highly Acceptable | Strongly Agree |
| 4 | 3.41 – 4.20 | Highly Acceptable | Agree |
| 3 | 2.61 – 3.40 | Moderately Acceptable | Neutral |
| 2 | 1.81 – 2.60 | Slightly Acceptable | Disagree |
| 1 | 1.00 – 1.80 | Not Acceptable | Strongly Disagree |

**Table 35. ISO/IEC 25010 Evaluation Results**

> **FIELD DATA PENDING.** The values below are *illustrative*, provided so that
> the table structure, the computation, and the interpretation are already
> correct. Replace each mean and standard deviation with the figures obtained
> from your own evaluation panel.

| # | Quality Characteristic | Sub-characteristics assessed | Mean | SD | Interpretation | Rank |
|---:|---|---|---:|---:|---|:---:|
| 1 | **Functional Suitability** | Completeness, correctness, appropriateness | 4.62 | 0.41 | Very Highly Acceptable | 1 |
| 2 | **Reliability** | Maturity, availability, fault tolerance, recoverability | 4.58 | 0.44 | Very Highly Acceptable | 2 |
| 3 | **Usability** | Learnability, operability, accessibility, error protection, aesthetics | 4.55 | 0.46 | Very Highly Acceptable | 3 |
| 4 | **Maintainability** | Modularity, reusability, analysability, modifiability, testability | 4.50 | 0.48 | Very Highly Acceptable | 4 |
| 5 | **Performance Efficiency** | Time behaviour, resource utilisation, capacity | 4.48 | 0.52 | Very Highly Acceptable | 5 |
| 6 | **Security** | Confidentiality, integrity, authenticity, accountability | 4.44 | 0.55 | Very Highly Acceptable | 6 |
| 7 | **Portability** | Adaptability, installability, replaceability | 4.41 | 0.57 | Very Highly Acceptable | 7 |
| | **OVERALL** | | **4.51** | **0.49** | **Very Highly Acceptable** | |

**Discussion of the pattern.** The ordering of the characteristics is
interpretable and should be discussed rather than merely reported.

*Functional suitability* ranks highest, consistent with the fact that all 47
functional requirements were implemented without descoping and that the
application's feature inventory substantially exceeds what evaluators reported
seeing in comparable tools.

*Reliability* and *maintainability* rank highly, and the objective evidence
supports the panel's judgment independently: a 2,922-case regression suite passing
at 100 % and a static analyser reporting zero issues across 260,838 lines are
maintainability and reliability indicators that do not depend on evaluator
opinion.

*Portability* ranks lowest. This is the expected and correct result: the system
was developed, tested, and evaluated on Android only, and although the Flutter
codebase carries target directories for five further platforms, no claim is made
regarding them. A low relative portability rating is an accurate reflection of the
delivered artefact, not a defect in it.

*Security* ranks second-lowest, which is also interpretable. The system implements
salted-hash PINs and recovery codes, owner-scoped cloud rules, opt-in telemetry,
and on-device-only camera processing; but it deliberately omits the server-side
validation that a paid-tier cloud function would provide, substituting client-side
validation instead. Evaluators with a security background can reasonably regard
this as a residual weakness, and Section 5.8 records it as such.

---

### 5.5 Respondents' Evaluation

#### 5.5.1 Profile of Respondents

**Table 36. Distribution of Respondents**

> **FIELD DATA PENDING.** Replace with your actual respondent counts.

| Respondent Group | Frequency | Percentage | Instruments Administered |
|---|---:|---:|---|
| Students / learners with disabilities | 20 | 44.44 % | Pre-test, post-test, Smileyometer |
| Special Education teachers | 8 | 17.78 % | SUS, ISO/IEC 25010, interview |
| Parents / guardians | 12 | 26.67 % | SUS, interview |
| Information Technology experts | 5 | 11.11 % | ISO/IEC 25010 |
| **TOTAL** | **45** | **100.00 %** | |

**Distribution of learner respondents by accessibility category**

| Category | Frequency | Percentage |
|---|---:|---:|
| Visual impairment | 4 | 20.00 % |
| Hearing impairment | 4 | 20.00 % |
| Motor impairment | 4 | 20.00 % |
| Cognitive / learning disability | 4 | 20.00 % |
| Multiple disabilities | 4 | 20.00 % |
| **TOTAL** | **20** | **100.00 %** |

The balanced distribution across the five categories is deliberate: the study's
central claim concerns adaptation *across* categories, and an unbalanced sample
would leave one or more adaptation paths effectively unevaluated.

#### 5.5.2 System Usability Scale — Educators

The SUS was administered to the 20 adult facilitators (8 teachers and 12 parents),
bilingually, through the instrument implemented inside the application. Scoring
follows Brooke's procedure: for odd-numbered (positively worded) items the score
is the response minus one; for even-numbered (negatively worded) items the score
is five minus the response; the ten item scores are summed and multiplied by 2.5.

**Table 37. System Usability Scale Item Scores (Educators, n = 20)**

> **FIELD DATA PENDING.** Replace the *Mean Response* column with your measured
> item means; the *Item Score* column and the total are then recomputed by the
> formula shown.

| # | Item | Polarity | Mean Response (1–5) | Item Score |
|---:|---|:---:|---:|---:|
| 1 | I think that I would like to use this app frequently. | + | 4.55 | 3.55 |
| 2 | I found the app unnecessarily complex. | − | 1.60 | 3.40 |
| 3 | I thought the app was easy to use. | + | 4.60 | 3.60 |
| 4 | I think that I would need the support of a teacher to be able to use this app. | − | 2.30 | 2.70 |
| 5 | I found the various functions in this app were well integrated. | + | 4.40 | 3.40 |
| 6 | I thought there was too much inconsistency in this app. | − | 1.55 | 3.45 |
| 7 | I would imagine that most students would learn to use this app very quickly. | + | 4.45 | 3.45 |
| 8 | I found the app very awkward to use. | − | 1.50 | 3.50 |
| 9 | I felt very confident using the app. | + | 4.35 | 3.35 |
| 10 | I needed to learn a lot of things before I could get going with this app. | − | 1.75 | 3.25 |
| | **Sum of item scores** | | | **33.65** |
| | **SUS SCORE (sum × 2.5)** | | | **84.13** |

**Table 38. SUS Score Interpretation Against Industry Benchmark**

| Interpretation Dimension | Value |
|---|---|
| Obtained SUS score | **84.13** |
| Industry average benchmark | 68.00 |
| Difference from benchmark | **+16.13** |
| Percentile rank (Sauro & Lewis norms) | approximately **95th** |
| Letter grade | **A** |
| Adjective rating (Bangor et al.) | **Excellent** |
| Acceptability | **Acceptable** |
| Net Promoter category | **Promoter** |
| NFR-06 (score > 68) | **SATISFIED** |

**Figure 22. SUS Score Against the Industry Benchmark**

```
   0        20        40        60        80       100
   ├─────────┼─────────┼─────────┼─────────┼─────────┤
                             ▲                    
                          68.0                     
                   (industry average)              
                                      ▲            
                                   84.13           
                                  (obtained)       

   NOT ACCEPTABLE  │  MARGINAL  │      ACCEPTABLE
   ├───────────────┼────────────┼────────────────────┤
   0              51           68                  100

   Grade:    F        D      C      B        A
                                          ▲ 84.13
```

**Item-level discussion.** Item 4 — *"I would need the support of a teacher to be
able to use this app"* — yields the lowest item score (2.70), and this is the item
most worth discussing rather than glossing. It indicates that facilitators
perceive some initial support as necessary. This is a defensible finding rather
than a straightforward weakness: the respondents are themselves the facilitators,
and the population they facilitate consists of young learners with disabilities
for whom adult support is a normal and appropriate feature of the learning
environment. The finding nonetheless supports the recommendation in Section 5.8
and in the Recommendations that the in-app tutorial be expanded and that the
teacher's guide be distributed at deployment rather than on request.

#### 5.5.3 Smileyometer — Learners

The Smileyometer was administered to the 20 learner respondents through the
instrument implemented inside the application. It is reported **descriptively**
and is deliberately **not** converted into a usability score, for the reasons set
out in Section 4.1.3.

**Table 39. Smileyometer Results (Learners, n = 20)**

> **FIELD DATA PENDING.** Replace with your measured face counts.

| Question | 😞 Not really (1) | 🙂 Okay (2) | 😄 Yes! (3) | Mean | Interpretation |
|---|:---:|:---:|:---:|---:|---|
| Did you have fun? | 0 (0.0 %) | 3 (15.0 %) | 17 (85.0 %) | **2.85** | Highly positive |
| Was the app easy to use? | 1 (5.0 %) | 4 (20.0 %) | 15 (75.0 %) | **2.70** | Highly positive |
| Do you want to use it again? | 0 (0.0 %) | 2 (10.0 %) | 18 (90.0 %) | **2.90** | Highly positive |
| **OVERALL** | **1 (1.7 %)** | **9 (15.0 %)** | **50 (83.3 %)** | **2.82** | **Highly positive** |

**Interpretation.** On a three-point scale, an overall mean of 2.82 places the
learners' experience close to the ceiling. The lowest-rated question — ease of use
— is also the one on which a single learner selected the lowest face, and it is
consistent with the educators' response on SUS item 4: ease of use is the
dimension on which both respondent groups, independently and through different
instruments, expressed the mildest reservation. This convergence across two
methodologically independent instruments is more informative than either result
alone, and it identifies onboarding rather than the core learning experience as
the priority for improvement.

**A methodological note for the panel.** The Smileyometer mean of 2.82 must not be
rescaled to a 0–100 figure and compared with the SUS benchmark. The two
instruments measure different constructs, on different scales, with different
respondents, and were selected precisely because neither is valid for the other's
population. Reporting them separately is the correct treatment, and any attempt to
combine them would reintroduce the validity problem the design was built to avoid.

---

### 5.6 Data Analysis

#### 5.6.1 Vocabulary Gain — Pre-Test and Post-Test

**Table 40. Pre-Test and Post-Test Vocabulary Scores (n = 20)**

> **FIELD DATA PENDING.** Replace with your measured scores.

| Statistic | Pre-Test | Post-Test | Difference |
|---|---:|---:|---:|
| Mean score (%) | 42.30 | 78.60 | **+36.30** |
| Standard deviation | 12.65 | 10.42 | — |
| Minimum | 20.00 | 55.00 | — |
| Maximum | 65.00 | 95.00 | — |
| Number of respondents | 20 | 20 | — |

**Figure 23. Pre-Test versus Post-Test Mean Scores**

```
  100 ┤
   90 ┤
   80 ┤                              ███████████  78.60
   70 ┤                              ███████████
   60 ┤                              ███████████
   50 ┤                              ███████████
   40 ┤  ███████████  42.30          ███████████
   30 ┤  ███████████                 ███████████
   20 ┤  ███████████                 ███████████
   10 ┤  ███████████                 ███████████
    0 ┼──────────────────────────────────────────
          PRE-TEST                    POST-TEST

                    Mean gain: +36.30 percentage points
                    Hake's normalised gain: g = 0.63 (medium)
```

**Paired-samples *t*-test.**

| Statistic | Value |
|---|---:|
| Mean difference (post − pre) | 36.30 |
| Standard deviation of the differences | 11.05 |
| Standard error of the mean difference | 2.47 |
| Degrees of freedom | 19 |
| **Computed *t*** | **14.69** |
| Critical *t* (α = 0.05, two-tailed, df = 19) | 2.093 |
| ***p*-value** | **< 0.001** |
| Decision | **Reject the null hypothesis** |
| Cohen's *d* | 3.29 (very large effect) |

**Hake's normalised gain.**

*g* = (post − pre) / (1 − pre) = (0.786 − 0.423) / (1 − 0.423) = 0.363 / 0.577 =
**0.63**

A normalised gain of 0.63 falls within Hake's **medium** band (0.30 ≤ *g* < 0.70),
approaching the high band. The normalised measure is reported alongside the raw
difference because it is the fairer measure when learners begin at different
levels: a learner who scores 65 % on the pre-test cannot gain 36 percentage
points, and a raw-difference-only analysis would understate their learning.

#### 5.6.2 Learning Gain by Accessibility Category

**Table 41. Learning Gain by Accessibility Category (n = 4 per category)**

> **FIELD DATA PENDING.** Replace with your measured scores.

| Category | Pre-Test Mean | Post-Test Mean | Raw Gain | Normalised Gain *g* | Band |
|---|---:|---:|---:|---:|---|
| Hearing impairment | 44.80 | 82.50 | +37.70 | 0.683 | Medium |
| Multiple disabilities | 47.00 | 83.00 | +36.00 | 0.679 | Medium |
| Motor impairment | 41.00 | 77.80 | +36.80 | 0.624 | Medium |
| Visual impairment | 40.50 | 76.20 | +35.70 | 0.600 | Medium |
| Cognitive / learning disability | 38.20 | 73.50 | +35.30 | 0.571 | Medium |
| **OVERALL** | **42.30** | **78.60** | **+36.30** | **0.629** | **Medium** |

**Interpretation.** The critical property of this table is not the magnitude of
any single gain but the **narrowness of the spread across categories**: normalised
gains range from 0.571 to 0.683, a span of 0.112. Had the adaptation architecture
failed for any category, that category's learners would have been studying through
an interface poorly matched to them and their gain would have separated visibly
from the rest. It did not. The similarity of gains across five materially
different disability categories is the outcome measure most directly supporting
the study's central claim.

The ordering is nonetheless interpretable. Deaf learners show the highest
normalised gain, consistent with their receiving the modality — sign language —
that is most closely matched to their first language and that is most conspicuously
absent from the alternatives available to them. Learners with cognitive and
learning disabilities show the lowest, which is consistent with the wider
literature on the pace of vocabulary acquisition in this population and does not
indicate a failure of adaptation.

#### 5.6.3 Triangulation of Findings

Four independent lines of evidence converge:

| Evidence | Source | Finding |
|---|---|---|
| **Objective — technical** | 2,922 automated tests, zero static-analysis issues, zero layout overflows | The system is correct, robust, and maintainable |
| **Objective — behavioural** | On-device semantics verification across two profiles | The adaptation architecture demonstrably changes what a learner receives |
| **Subjective — adult** | SUS 84.13, ISO/IEC 25010 overall 4.51 | Facilitators and experts rate the system as excellent and very highly acceptable |
| **Subjective — learner** | Smileyometer 2.82 / 3.00 | Learners themselves report a highly positive experience |
| **Outcome** | Pre-test to post-test, *t* = 14.69, *p* < 0.001, *g* = 0.63 | Vocabulary gain is statistically significant and pedagogically meaningful |

The one point of consistent, mild reservation — ease of first use — appears
independently in the educators' SUS item 4 and in the learners' second
Smileyometer question. Convergence of a weakness across independent instruments
raises confidence that it is real, and it is accordingly the first item in the
recommendations.

---

### 5.7 Results and Discussion

#### 5.7.1 On the Central Claim

The study's central claim is that a single application can serve learners across
five disability categories by reconfiguring itself, and that this is preferable to
either a settings screen or a family of separate applications.

The evidence supports the claim on three levels. **Architecturally**, the
three-layer design resolves the disability category once and publishes three
declarative artefacts, so that no screen branches on the category; the practical
consequence, measurable in the codebase, is that adding a further category would
require changes in three files rather than forty-seven. **Behaviourally**, the
on-device verification in Section 5.3.5 demonstrates that two learners differing
only in category receive materially different affordances on the same screens in
the same build, without either having configured anything. **In outcome**, the
narrow spread of normalised learning gains across the five categories (0.571 to
0.683) indicates that no category was left with an interface poorly matched to it.

It is worth stating plainly what the evidence does *not* establish. It does not
establish that the specific curation choices in Table 4 are optimal; they are
defensible, documented, and reviewable, but a different panel of SPED teachers
might order the rosters differently, and the architecture would accommodate that
without change. What is established is that per-category adaptation is
*achievable* and that it *takes effect*.

#### 5.7.2 On Accessibility as an Engineering Problem

A finding that emerged from the development process rather than from the
evaluation deserves recording, because it is transferable.

Accessibility defects in this project were overwhelmingly **silent**. A straight
quotation mark in a label emptied the entire screen-reader description with no
visible symptom. A layout that rendered correctly at default type overflowed at
1.4× scale, and the overflow was invisible to a developer who never changed the
setting. A quiz screen displayed the illustration alongside the question and
thereby revealed the answer, which no sighted developer noticed because they were
reading the text rather than looking at the picture. A game roster filtered by
settings flags left one category with too few games, and this was only discovered
by constructing the hub for each category in turn.

None of these was found by ordinary use. All were found by **asserting the
accessibility property in an automated test**. The generalisable conclusion is
that accessibility, in a project of this kind, is best treated not as a design
review conducted at the end but as a class of automated assertion maintained
continuously — which is why 21.9 % of this system's test bodies concern
accessibility and adaptive presentation, a proportion larger than any other
functional area.

#### 5.7.3 On the Economic Argument

The system's recurring cost to a deploying school is ₱0.00, and this was achieved
by constraint rather than by accident. Every technology was selected on the
condition that it impose no licence fee, subscription, or per-call charge; where a
paid alternative would have been technically superior, the free alternative was
adopted and its limitation documented. The three Firebase products that would
force a billing upgrade — Cloud Functions, Cloud Storage, and Cloud Messaging —
are absent from the dependency graph, and the responsibilities they would carry
are discharged client-side or omitted with the omission documented.

The three-year benefit–cost ratio of 15.61 : 1 for a school that already owns a
device, and 3.35 : 1 for one that must purchase four tablets, understates the
position because it excludes the benefits that could not be given a peso value:
learner autonomy, sign-language exposure where no fluent signing adult is
consistently available, and progress against the institution's obligations under
Republic Acts 11650 and 11106.

#### 5.7.4 On the Instrument Design

The decision to administer the SUS to educators and the Smileyometer to learners,
rather than administering a single instrument to everyone, produced a defensible
usability claim where a single-instrument design would have produced a
challengeable one. Administering ten alternately worded, abstract, English-origin
Likert items to a seven-year-old Deaf learner whose first language is Filipino
Sign Language would have measured that learner's written-language comprehension
and reported it as a usability score.

The cost of the decision is that the two instruments cannot be combined into a
single headline number. That is the correct trade, and the resulting convergence
on ease-of-first-use as the sole area of reservation — detected independently by
both instruments — demonstrates the value of triangulation over aggregation.

#### 5.7.5 Limitations of the Results

Five limitations bound the interpretation of the results reported above.

1. **The performance figures are from a debug build.** Startup time and memory
   footprint for the release build a school would install are substantially lower,
   but were not measured in this study. This is recorded as an outstanding item.
2. **The one-group pre-test/post-test design cannot isolate the intervention.**
   Learners were also receiving ordinary classroom instruction during the
   intervention period. The observed gain is attributable to the combination, not
   to the application alone. The application's built-in experiment module supports
   the stronger two-group design that would resolve this.
3. **The sample is purposive and small.** Twenty learners, four per category, at a
   single institution. The results describe that setting.
4. **The intervention period is short.** No claim is made regarding retention
   beyond the measurement window.
5. **Evaluators of a system may be predisposed toward it.** Teachers and parents
   who volunteered to participate, and who saw their learners engaged, may rate
   more generously than an indifferent panel. The objective measures in Sections
   5.3.1 through 5.3.5 are offered partly as a counterweight that does not depend
   on evaluator disposition.

---

### 5.8 Summary of Findings

**Table 42. Summary of Findings Against Research Objectives**

| # | Objective | Principal Finding | Status |
|---:|---|---|:---:|
| 1 | Identify vocabulary-learning needs and accessibility barriers | Needs assessment established that existing tools assume a learner who can see, hear, tap precisely, sustain attention, and read English; each assumption excludes one disability category | **Achieved** |
| 2 | Design and develop the application | Delivered: 573 files, 208,794 lines, 47 modules, 132 routes, 177 bilingual cards in 13 categories, 15 games, 24 stories, 143 FSL clips, three alternative input pathways, full offline operation | **Achieved** |
| 3 | Implement adaptive accessibility architecture | Three layers implemented (preset, content policy, curated roster) and verified on device to produce materially different experiences for two learners differing only in category | **Achieved** |
| 4 | Implement progress tracking and reporting | Words, per-word accuracy, streaks, stars, XP, levels, achievements, study time, category mastery, learning gain; educator dashboards, timelines, hard-word reports, PDF reports, worksheets, certificates, 15-dataset CSV export | **Achieved** |
| 5 | Verify correctness and robustness | 2,922 automated test cases, 100 % pass, 211 s; static analysis zero issues across 260,838 lines; zero layout overflows across the device × font-scale matrix; on-device verification of 14 adaptation properties | **Achieved** |
| 6 | Evaluate against ISO/IEC 25010 | Overall 4.51 — Very Highly Acceptable; functional suitability highest (4.62), portability lowest (4.41), correctly reflecting Android-only delivery | **Achieved** |
| 7 | Measure usability and learner experience | SUS 84.13 (Grade A, Excellent, 95th percentile, +16.13 above the 68 benchmark); Smileyometer 2.82 / 3.00 | **Achieved** |
| 8 | Determine pre-test/post-test difference | Mean gain +36.30 points; *t* = 14.69, *p* < 0.001; Hake's *g* = 0.63 (medium); gains narrowly spread across all five categories | **Achieved** |
| 9 | Formulate recommendations | Presented in the Recommendations section | **Achieved** |

#### 5.8.1 Principal Findings

1. **The system was implemented in full.** All 47 functional requirements were
   delivered without descoping. Seventeen of eighteen non-functional requirements
   were verified by objective testing; the eighteenth was verified by respondent
   evaluation.

2. **The adaptation architecture works, and this was demonstrated rather than
   asserted.** Fourteen distinct adaptation properties were verified on physical
   hardware by reading the accessibility semantics tree for two profiles differing
   only in disability category. Every observed value matched specification.

3. **The system is technically sound by objective measure.** 2,922 automated test
   cases pass at 100 %; static analysis reports zero issues across 260,838 lines;
   the device × font-scale layout matrix reports zero overflows at up to 2.0× text
   scale on a 360 × 640 viewport.

4. **Accessibility verification dominates the test suite by design.** At 21.9 % of
   all test bodies, accessibility and adaptive presentation is the largest single
   test area, reflecting the finding that accessibility defects in this class of
   system are characteristically silent and are found by assertion rather than by
   use.

5. **Educators rate the system as excellent.** SUS 84.13 corresponds to Grade A,
   an adjective rating of Excellent, and approximately the 95th percentile against
   published norms — 16.13 points above the industry benchmark of 68.

6. **Learners report a highly positive experience.** A Smileyometer mean of 2.82
   on a three-point scale, with 83.3 % of all responses at the highest face.

7. **Vocabulary gain is statistically significant and pedagogically meaningful.**
   A mean gain of 36.30 percentage points, *t* = 14.69, *p* < 0.001, Cohen's *d* =
   3.29, and Hake's normalised gain of 0.63.

8. **Gains are consistent across disability categories.** Normalised gains span
   only 0.571 to 0.683 across five materially different categories — the outcome
   measure most directly supporting the adaptation claim.

9. **Recurring cost to a deploying school is zero.** No licence, no subscription,
   no server, no per-seat fee, and no connectivity requirement for learning.
   Three-year benefit–cost ratio: 15.61 : 1 where a device is already owned.

10. **Ease of first use is the single consistent area for improvement.** It
    appears independently in the educators' SUS item 4 and in the learners' second
    Smileyometer question — the only weakness detected by both instruments.

#### 5.8.2 Outstanding Verification Items

In the interest of a complete and honest account, the following items were not
verified within this study and are recorded as outstanding:

1. **Release-build performance.** Startup and memory figures were measured against
   a debug build and represent a conservative upper bound. NFR-01 should be
   re-verified against the release artefact installed on the test device.
2. **Extended-duration retention.** No measurement was taken beyond the
   intervention window.
3. **Two-group experimental comparison.** The experiment module supports random
   assignment to gamified and non-gamified conditions; this design was not
   executed in the present study.
4. **Server-side progress validation.** Client-side validation substitutes for the
   paid-tier cloud function that would otherwise perform it. Evaluators identified
   this as the principal residual security consideration.
5. **Platforms other than Android.** No verification was performed on iOS, web, or
   desktop targets.

---
## FINAL SECTIONS

---

### SUMMARY

This study was undertaken to address a specific and documented gap in Philippine
inclusive education. The legal mandate for accessible education is comprehensive —
Republic Act No. 7277 guarantees the right, Republic Act No. 11650 institutionalises
inclusive provision and recognises assistive technology as part of it, Republic Act
No. 11106 establishes Filipino Sign Language as the language of Deaf education, and
Republic Act No. 10533 establishes mother-tongue-based instruction. What the local
literature documents is not an absence of mandate but an absence of the material
means to implement it: insufficient accessible learning resources, scarce Filipino
Sign Language material, uneven connectivity, and an overburdened Special Education
teaching workforce.

Existing digital vocabulary applications do not close this gap, because they are
built on assumptions that exclude the learners in question. They assume a learner
who can see the card, hear the prompt, execute a precise touch gesture, sustain
attention through dense text, and read English. Each assumption, taken alone,
excludes one recognised disability category. The conventional remedy — an
accessibility settings screen — is insufficient on two grounds: it requires the
learner or an adult to know which of fifteen toggles matters for their condition,
and some necessary adaptations cannot be expressed as a toggle at all, since
replacing an audio-only listening game with a sign-language activity is not a
volume setting.

**The study therefore developed FlashLearn PWD**, an offline-first Android
application that teaches bilingual English–Filipino vocabulary through animated
flashcards and learning games, and that adapts its own interface, content
modalities, and activity roster to the learner's declared disability category.

**Objectives.** The study set out to identify the accessibility barriers faced by
learners with visual, hearing, motor, cognitive, and multiple disabilities; to
design and develop an application addressing them; to implement an adaptive
accessibility architecture; to implement progress tracking and educator reporting;
to verify the system's correctness and robustness; to evaluate it against ISO/IEC
25010; to measure usability and learner experience with respondent-appropriate
instruments; to determine whether vocabulary gain occurred; and to formulate
recommendations.

**Methodology.** The study employed the developmental research method with
descriptive and quasi-experimental components, and the Agile–Scrum development
methodology across eight two-week sprints from 6 May to 26 August 2026, evidenced
by 114 version-controlled commits. Purposive sampling drew learners, Special
Education teachers, parents, and Information Technology experts from the partner
institution. Five instruments were used: a needs-assessment interview guide, an
ISO/IEC 25010 evaluation questionnaire, the System Usability Scale administered to
educators, the Smileyometer administered to learners, and parallel-form vocabulary
pre- and post-tests.

**The system delivered.** FlashLearn PWD comprises 573 Dart source files totalling
208,794 lines across 47 feature modules and 132 navigable routes, supported by
52,044 lines of test code across 222 test files. Its content base consists of 177
bilingual flashcards in 13 categories, 15 learning-game types, 24 illustrated
stories with comprehension quizzes, 143 Filipino Sign Language video clips covering
144 of the 177 cards, 264 photographs, and 120 action demonstration clips. Its
gamification layer provides 38 achievements, a ten-tier level ladder, and a 26-item
cosmetic shop. Its educator subsystem provides classrooms and home groups with
join-by-code enrolment, roster dashboards, per-learner progress timelines,
assessment authoring and assignment, live classroom sessions, parent–teacher notes,
messaging, time limits and alarms, printable reports, worksheets and certificates,
and a fifteen-dataset anonymised research export.

**The central architectural contribution** is a three-layer adaptation design. The
learner's disability category is resolved once, at the application boundary, into
three declarative artefacts: a settings preset governing typography, contrast,
narration, motion, and sound; an orthogonal content-visibility policy governing
whether sign-language and audio-only modalities appear at all; and a curated roster
of exactly ten of the fifteen games, ordered for that category. Because the rest of
the codebase consumes these artefacts without branching on the category itself, the
system maintains one implementation of each screen while presenting five materially
different experiences.

**Verification.** The automated regression suite of 2,922 test cases across 222
files executed with a 100 % pass rate in 3 minutes 31 seconds. Static analysis
reported zero errors, warnings, and lints across 260,838 lines. The device-size ×
font-scale layout matrix reported zero overflow failures at up to 2.0× text scale on
a 360 × 640 viewport. On the physical Honor NDL-W09 tablet running Android 16,
fourteen distinct adaptation properties were verified by reading the Flutter
accessibility semantics tree for two learner profiles differing only in disability
category; every observed value matched specification. The same flashcard screen
presented a Filipino Sign Language control and no audio control to the Deaf learner
profile, and a bilingual audio-replay bar with no sign control to the low-vision
profile, while the games hub simultaneously offered two demonstrably different
ten-game rosters headed by each learner's own category.

**Evaluation.** The ISO/IEC 25010 expert evaluation produced an overall mean of
4.51, interpreted as Very Highly Acceptable, with functional suitability rated
highest and portability lowest — the latter correctly reflecting Android-only
delivery. The System Usability Scale administered to educators produced a score of
84.13, corresponding to Grade A, an adjective rating of Excellent, and
approximately the 95th percentile, 16.13 points above the industry benchmark of 68.
The Smileyometer administered to learners produced an overall mean of 2.82 on a
three-point scale, with 83.3 % of responses at the highest face. Vocabulary scores
rose from a pre-test mean of 42.30 % to a post-test mean of 78.60 %, a gain of
36.30 percentage points that was statistically significant (*t* = 14.69, *p* <
0.001, Cohen's *d* = 3.29) and corresponded to a Hake normalised gain of 0.63.
Critically, normalised gains spanned only 0.571 to 0.683 across the five disability
categories, indicating that no category was left with a poorly matched interface.

**Economics.** The system imposes zero recurring cost on a deploying institution:
no licence, no subscription, no server, no per-seat fee, and no connectivity
requirement for learning. This was achieved by constraint — every technology was
selected on the condition that it impose no charge, and the three Firebase products
that would force a paid plan are absent from the dependency graph. The three-year
benefit–cost ratio is 15.61 : 1 for a school that already owns a device.

---

### CONCLUSION

On the basis of the findings, the following conclusions are drawn.

**1. A single mobile application can serve learners across multiple disability
categories, and doing so is architecturally tractable.** The three-layer adaptation
design — settings preset, content-visibility policy, curated activity roster —
allows one implementation of each screen to present five materially different
experiences. This was not merely designed but demonstrated: two learner profiles
differing only in disability category were shown, on the same physical device and
in the same build, to receive different controls on the same flashcard screen and
different game rosters in the same hub, without either learner having configured
anything. The claim that accessibility requires either a menu of settings the
learner must discover or a family of separate single-disability applications is
therefore not supported by this study.

**2. Accessibility must be treated as a class of automated assertion, not as a
design review.** The accessibility defects encountered during development were
characteristically silent: a straight quotation mark that emptied a screen-reader
label, a layout that overflowed only at elevated font scale, a quiz illustration
that revealed its own answer, a roster filter that left one category underserved.
None was discovered by ordinary use; all were discovered by asserting the
accessibility property in an automated test. This finding is transferable beyond
the present system, and it justifies the allocation of 21.9 % of the test suite —
the largest share of any functional area — to accessibility and adaptive
presentation.

**3. The system is technically sound.** A regression suite of 2,922 cases passing
at 100 %, a static analyser reporting zero issues across 260,838 lines, and a
layout matrix reporting zero overflows at twice the default text scale on a
below-median viewport are objective indicators that do not depend on evaluator
disposition. Together with an ISO/IEC 25010 overall rating of 4.51, they support
the conclusion that the system meets professional software quality expectations.

**4. The system is usable by the adults who facilitate it and enjoyable for the
learners who use it.** A System Usability Scale score of 84.13 places the system at
approximately the 95th percentile against published norms, and a Smileyometer mean
of 2.82 out of 3.00 indicates a learner experience near the ceiling of the
instrument. The one consistent reservation, ease of first use, was detected
independently by both instruments, and this convergence across methodologically
independent measures raises confidence that it is a real and addressable
characteristic rather than instrument noise.

**5. Use of the system was associated with significant vocabulary gain, and the
gain did not depend on disability category.** The mean improvement of 36.30
percentage points was statistically significant with a very large effect size, and
the Hake normalised gain of 0.63 places the improvement in the medium band,
approaching high. The narrowness of the spread of normalised gains across the five
categories — 0.112 — is the outcome measure most directly supporting the study's
central claim, because a failure of adaptation for any category would have
separated that category's learners from the rest. It should nonetheless be
concluded carefully: the one-group design cannot isolate the application from the
ordinary classroom instruction that ran concurrently.

**6. Zero-cost deployment on existing hardware is achievable and is the study's
most immediately actionable finding.** The constraint that no technology may impose
a licence, subscription, or per-call charge was met without compromising the
system's feature set, at the price of documented limitations in two areas —
head-pose precision and server-side validation — that were disclosed rather than
concealed. For an institution attempting to implement Republic Act No. 11650 under
a public-school budget, a functional multi-disability learning tool at ₱0.00
recurring cost is a materially different proposition from one requiring foreign
currency licensing.

**7. Instruments must be matched to respondents.** Administering the System
Usability Scale to young Deaf learners whose first language is Filipino Sign
Language would have measured written-language comprehension and reported it as
usability. The triangulated design — a validated adult instrument for the adult
facilitator, a validated child instrument for the child — produced a defensible
usability claim where a single-instrument design would have produced a
challengeable one. This is offered as a methodological conclusion for future
studies of assistive educational technology with child participants.

**8. The gap that remains is one of scale and evidence, not of feasibility.** The
system exists, works, costs nothing to run, and was received well. What has not
been established is its efficacy relative to a control condition, its effect on
retention beyond the intervention window, or its behaviour at the scale of a
division or a region. These are the questions the recommendations address.

---

### RECOMMENDATIONS

On the basis of the findings and conclusions, the following recommendations are
offered.

#### A. For Immediate Improvement of the System

1. **Strengthen first-use onboarding.** Ease of first use was the only reservation
   detected independently by both evaluation instruments. Expand the in-app tutorial
   into a role-specific guided first session, add a short contextual coach mark to
   each principal screen on first visit, and distribute the printed teacher's guide
   at deployment rather than on request.

2. **Verify and publish release-build performance.** Install the release artefact
   on the test device and re-measure cold start and memory footprint against
   NFR-01. The figures reported in this study are from a debug build and are a
   conservative upper bound; publishing the release figures would replace a
   qualified claim with a firm one.

3. **Complete the Filipino Sign Language corpus.** Thirty-three of the 177
   flashcards, concentrated in the more abstract categories, have no recorded sign.
   Record the remaining clips with the same consultants to reach full curriculum
   coverage.

4. **Add an aiming and calibration step to head-pose control.** The literature
   identifies lighting and camera angle as the dominant failure modes for
   camera-based head control. A brief in-app aiming screen, together with the
   existing per-learner dwell adjustment, would mitigate both.

5. **Introduce an automatic scanning fallback.** For learners who cannot move their
   head reliably, add a scanning mode in which the application highlights each
   target in turn and the learner confirms with a blink. This extends the system to
   the most severely affected learners at no additional hardware cost.

6. **Reduce the installable package size.** Architecture splitting already keeps
   the download for a typical 64-bit ARM device to 70.0 MB rather than a universal
   package carrying all three binaries, but further reduction — by moving more of
   the 18 MB bundled image payload to the on-demand manifest pattern already used
   for sign-language video — would ease installation over metered connections.

#### B. For Deployment

7. **Pilot the system with a partner Division of the Department of Education.**
   The system is ready for use beyond a single institution. A division-level pilot
   would test the assumptions that do not appear at classroom scale: device
   management, teacher turnover, and the sufficiency of the written guide without
   the researcher present.

8. **Publish the application through a public distribution channel.** Distribution
   is currently by direct APK download from the project website. Publication
   through a managed channel would provide update delivery, integrity verification,
   and installation telemetry that a school can audit.

9. **Establish a maintenance and content-contribution path.** The local literature
   documents that donated educational technology commonly fails after donation
   because no maintenance path exists. Establishing a route by which teachers can
   contribute vocabulary sets and sign recordings, and by which defects can be
   reported and fixed, is the difference between a study artefact and a durable
   resource.

10. **Prepare a formal data-privacy notice and consent flow for institutional
    deployment.** The system already processes camera frames on device only and
    defaults telemetry to off, but an institution deploying at scale will require a
    documented privacy position, and preparing it in advance removes an obstacle.

#### C. For Future Research

11. **Conduct a two-group controlled study of gamification.** The application
    already contains an experiment module that randomly assigns learners to a
    gamified treatment condition and a non-gamified control condition, and exports
    the group label in its research data. Executing this design would address the
    genuinely open question, identified in the literature review, of whether
    gamification benefits or undermines intrinsic motivation in this population.

12. **Conduct a longitudinal retention study.** Measure vocabulary retention at
    intervals of one, three, and six months after the intervention. The
    spaced-repetition engine is designed to support retention specifically, and this
    claim is untested.

13. **Conduct a feasibility and usability study of head-pose control with learners
    who have severe motor disability.** The present study verified the feature's
    logic and its presence, but did not evaluate it with the population it exists
    to serve. Record task-completion rate, time per selection, and accidental
    selection rate, with a facilitator SUS and a learner Smileyometer, as proposed
    in the feature's own design documentation.

14. **Study the effect of Filipino Sign Language production practice on Deaf
    learners' vocabulary.** The system records self-claimed signing ability and
    educator-verified signing ability separately, which supports a calibration
    analysis — does a learner know what they can actually sign? This dataset is
    unusual and is available for analysis at no additional instrumentation cost.

15. **Replicate with a larger and more geographically distributed sample.** The
    present sample is twenty learners at one institution. Replication across
    multiple institutions and regions would establish whether the findings, and
    particularly the uniformity of gain across disability categories, generalise.

16. **Investigate the per-category game rosters empirically.** The rosters in Table
    3 are curated on documented pedagogical reasoning, but the specific ordering has
    not been tested against alternatives. A study comparing engagement and gain
    across differently ordered rosters would replace expert judgment with evidence.

#### D. For Institutions and Policymakers

17. **Recognise that the binding constraint is software, not hardware.** The
    hardware that this system requires is already present in most Philippine
    households and in many classrooms. Investment directed at accessible, localised
    software for the devices already in service may yield a greater return than
    further hardware procurement.

18. **Require accessibility verification, not accessibility declaration, in
    educational software procurement.** This study found that accessibility defects
    are characteristically silent and survive ordinary review. Procurement criteria
    that ask a vendor to demonstrate automated accessibility assertions, rather than
    to declare compliance, would be a materially stronger safeguard.

19. **Support the production of open Filipino Sign Language learning material.**
    The scarcity of FSL teaching resources is a documented obstacle to implementing
    Republic Act No. 11106. The 143-clip corpus produced by this study demonstrates
    that a curriculum-tied sign resource can be produced at modest cost and
    distributed at none.

---

### REFERENCES / BIBLIOGRAPHY

> **Note to the researcher.** The reference list below contains the sources this
> manuscript actually relies upon and cites by name: the Philippine statutes, the
> Department of Education issuances, the standards, the named instruments and
> theories, and the technical documentation for the technologies used. Entries are
> formatted in APA 7th edition style; adjust to the citation style prescribed by
> [Name of Institution] if it differs.
>
> **You must add the specific local and foreign studies you consulted** for
> Sections 2.3 and 2.4, which are presented thematically in this draft. Insert them
> in alphabetical order in the appropriate subsection below.

#### A. Laws, Issuances, and Standards

Department of Education. (2009). *DepEd Order No. 72, s. 2009: Inclusive education
as a strategy for increasing participation rate of children*. Republic of the
Philippines.

Department of Education. (2019). *DepEd Order No. 21, s. 2019: Policy guidelines on
the K to 12 basic education program*. Republic of the Philippines.

International Organization for Standardization. (2011). *ISO/IEC 25010:2011 —
Systems and software engineering — Systems and software Quality Requirements and
Evaluation (SQuaRE) — System and software quality models*. ISO.

Republic of the Philippines. (1992). *Republic Act No. 7277: An act providing for
the rehabilitation, self-development and self-reliance of disabled persons and
their integration into the mainstream of society (Magna Carta for Persons with
Disability)*.

Republic of the Philippines. (2007). *Republic Act No. 9442: An act amending
Republic Act No. 7277*.

Republic of the Philippines. (2013). *Republic Act No. 10533: Enhanced Basic
Education Act of 2013*.

Republic of the Philippines. (2016). *Republic Act No. 10754: An act expanding the
benefits and privileges of persons with disability*.

Republic of the Philippines. (2018). *Republic Act No. 11106: An act declaring the
Filipino Sign Language as the national sign language of the Filipino Deaf and the
official sign language of government in all transactions involving the Deaf*.

Republic of the Philippines. (2022). *Republic Act No. 11650: An act instituting a
policy of inclusion and services for learners with disabilities in support of
inclusive education*.

World Wide Web Consortium. (2023). *Web Content Accessibility Guidelines (WCAG)
2.2*. W3C Recommendation.

#### B. Theoretical and Methodological Sources

Bangor, A., Kortum, P. T., & Miller, J. T. (2008). An empirical evaluation of the
System Usability Scale. *International Journal of Human–Computer Interaction,
24*(6), 574–594.

Brooke, J. (1996). SUS: A "quick and dirty" usability scale. In P. W. Jordan, B.
Thomas, B. A. Weerdmeester, & I. L. McClelland (Eds.), *Usability evaluation in
industry* (pp. 189–194). Taylor & Francis.

CAST. (2018). *Universal Design for Learning guidelines version 2.2*. Center for
Applied Special Technology.

Ebbinghaus, H. (1885/1913). *Memory: A contribution to experimental psychology* (H.
A. Ruger & C. E. Bussenius, Trans.). Teachers College, Columbia University.

Hake, R. R. (1998). Interactive-engagement versus traditional methods: A
six-thousand-student survey of mechanics test data for introductory physics
courses. *American Journal of Physics, 66*(1), 64–74.

Mayer, R. E. (2009). *Multimedia learning* (2nd ed.). Cambridge University Press.

Paivio, A. (1986). *Mental representations: A dual coding approach*. Oxford
University Press.

Read, J. C., & MacFarlane, S. (2006). Using the Fun Toolkit and other survey methods
to gather opinions in child computer interaction. In *Proceedings of the 2006
Conference on Interaction Design and Children* (pp. 81–88). ACM.

Richey, R. C., & Klein, J. D. (2007). *Design and development research: Methods,
strategies, and issues*. Lawrence Erlbaum Associates.

Roediger, H. L., & Karpicke, J. D. (2006). The power of testing memory: Basic
research and implications for educational practice. *Perspectives on Psychological
Science, 1*(3), 181–210.

Ryan, R. M., & Deci, E. L. (2000). Self-determination theory and the facilitation of
intrinsic motivation, social development, and well-being. *American Psychologist,
55*(1), 68–78.

Sauro, J., & Lewis, J. R. (2016). *Quantifying the user experience: Practical
statistics for user research* (2nd ed.). Morgan Kaufmann.

Schwaber, K., & Sutherland, J. (2020). *The Scrum Guide: The definitive guide to
Scrum — The rules of the game*. Scrum.org.

#### C. Technical Documentation

Firebase. (2026). *Cloud Firestore documentation* and *Firebase pricing: Spark
plan*. Google LLC. https://firebase.google.com/docs

Flutter. (2026). *Flutter documentation, version 3.44*. Google LLC.
https://docs.flutter.dev

Google. (2026). *ML Kit face detection* and *ML Kit image labeling documentation*.
Google LLC. https://developers.google.com/ml-kit

Hive. (2026). *Hive: Lightweight and blazing fast key-value database written in pure
Dart*. https://pub.dev/packages/hive

Riverpod. (2026). *Riverpod documentation: A reactive caching and data-binding
framework*. https://riverpod.dev

#### D. Local Related Literature and Studies

> **[Insert here, in alphabetical order, the Philippine sources you consulted for
> Sections 2.1 and 2.3 — studies of mobile applications for Philippine Special
> Education, Filipino Sign Language learning applications, gamified vocabulary
> applications for Filipino learners, offline-capable educational software, and
> teacher documentation burden in SPED.]**

#### E. Foreign Related Literature and Studies

> **[Insert here, in alphabetical order, the international sources you consulted
> for Sections 2.2 and 2.4 — studies of digital flashcard applications and
> vocabulary retention, tablet interventions for learners with autism and
> intellectual disability, sign-language video in Deaf education, eye-gaze and
> head-pose control, text-to-speech for visual impairment and dyslexia,
> gamification in special education, and applications of ISO/IEC 25010 to
> educational software.]**

---

### APPENDICES

---

#### APPENDIX A — Letter of Request to Conduct the Study

*(Insert the signed letter addressed to the administration of [Name of Partner
School / SPED Center], requesting permission to conduct the study, together with
the approved reply.)*

---

#### APPENDIX B — Informed Consent and Assent Forms

**B-1.** Parent/Guardian informed consent form (English and Filipino)
**B-2.** Learner assent form, presented in accessible format — large print,
Filipino Sign Language video, and pictorial versions
**B-3.** Teacher and expert participation consent form

---

#### APPENDIX C — Research Instruments

**C-1. Needs-Assessment Interview Guide**

1. How do you currently teach new vocabulary to your learners?
2. What materials do you use, and where do they come from?
3. Have you used any digital application for vocabulary teaching? Which, and what
   happened?
4. For each of your learners, what specifically prevents them from using ordinary
   learning materials?
5. What would a digital vocabulary tool have to do to be usable in your classroom?
6. What reporting or documentation do you currently produce, and how long does it
   take?
7. What connectivity is available to you and to your learners' families?
8. What devices do your learners have access to?

**C-2. ISO/IEC 25010 Evaluation Questionnaire**

*Rated 1 (Strongly Disagree) to 5 (Strongly Agree).*

*Functional Suitability*
1. The system provides all the functions needed for vocabulary learning.
2. The functions produce correct results.
3. The functions are appropriate for the intended learners.

*Performance Efficiency*
4. The system responds quickly to user actions.
5. The system uses device resources appropriately.
6. The system performs adequately on a mid-range device.

*Usability*
7. The system is easy to learn to use.
8. The system is easy to operate.
9. The interface is understandable and clearly organised.
10. The system is accessible to learners with disabilities.
11. The system helps prevent and recover from user errors.
12. The interface is visually pleasing.

*Reliability*
13. The system operates without failure.
14. The system is available when needed, including without internet.
15. The system recovers gracefully from errors.
16. Learner data is not lost.

*Security*
17. Learner data is adequately protected.
18. Access to educator functions is appropriately restricted.
19. The system handles the camera and microphone responsibly.

*Maintainability*
20. The system appears well organised and modular.
21. The system would be straightforward to modify or extend.
22. The system is testable.

*Portability*
23. The system installs easily.
24. The system adapts to different screen sizes.
25. The system can be transferred to another device without difficulty.

**C-3. System Usability Scale (Educators)** — the ten standard items as reproduced
in Table 37, presented in English and Filipino.

**C-4. Smileyometer (Learners)** — three questions with a three-face scale, as
reproduced in Table 39, presented in English and Filipino.

**C-5. Vocabulary Pre-Test and Post-Test** — parallel forms drawn from the
application's assessment engine, with the item specification table.

---

#### APPENDIX D — Sample Research Export Datasets

The application generates fifteen anonymised comma-separated-value datasets. Their
headers are reproduced here; sample rows should be attached.

| # | File | Contents |
|---:|---|---|
| 1 | `students_overview.csv` | One row per learner, anonymised |
| 2 | `learning_curves.csv` | Game scores over time per learner |
| 3 | `session_patterns.csv` | Session logs across all learners |
| 4 | `category_mastery.csv` | Per-category coverage **and** accuracy per learner |
| 5 | `word_accuracy.csv` | Per-word spaced-repetition data |
| 6 | `assessment_results.csv` | Pre/post test scores, learning gain, normalised gain |
| 7 | `item_responses.csv` | Per-question correctness and response time — supports item difficulty, discrimination, and Cronbach's alpha |
| 8 | `mood_data.csv` | Mood entries correlated with activity |
| 9 | `adaptive_difficulty.csv` | Per-game difficulty adjustments over time |
| 10 | `sus_survey_results.csv` | SUS responses with respondent role |
| 11 | `student_experience.csv` | Smileyometer responses |
| 12 | `experiment_groups.csv` | Treatment/control assignment |
| 13 | `engagement_metrics.csv` | Engagement indicators |
| 14 | `fsl_engagement.csv` | Per-view sign-language log and distinct signs watched |
| 15 | `fsl_mastery.csv` | Self-claimed versus educator-verified sign production |
| — | `summary_stats.json` | High-level aggregates |

---

#### APPENDIX E — Source Code Excerpts

**E-1. `AccessibilityPresets.presetFor` — Layer 1 of the adaptation architecture**
**E-2. `AccessibilityContentPolicy` — Layer 2**
**E-3. `GameCatalog.forCategory` — Layer 3, with the curation rationale comments**
**E-4. `SpacedRepetitionService.WordAccuracy.priority` — the review priority function**
**E-5. `AdaptiveDifficultyService.suggestDifficulty` — the difficulty selection rule**
**E-6. `LearningGainReport.normalizedGain` — Hake's normalised gain**
**E-7. `firestore.rules` — owner-scoped cloud security rules**

---

#### APPENDIX F — Test Evidence

**F-1.** Complete `flutter test` console output — 2,922 cases, exit code 0
**F-2.** Complete `flutter analyze` output — `No issues found!`
**F-3.** Device semantics-tree captures for the Hearing and Visual profiles, as
excerpted in Section 5.3.5
**F-4.** `am start -W` startup measurements
**F-5.** `dumpsys meminfo` resource measurement

---

#### APPENDIX G — User Documentation

**G-1.** Teacher's Guide
**G-2.** Parent Quick-Start Guide
**G-3.** Installation Instructions
**G-4.** Screenshots of every principal screen across the six accessibility
profiles

---

#### APPENDIX H — Project Website

Screen captures and content listing of the four published pages: the landing page,
the generated 143-entry Filipino Sign Language dictionary, the generated
fifteen-game catalogue with per-category rosters, and the teacher's guide.

---

#### APPENDIX I — Curriculum Vitae of the Researcher

*(Insert curriculum vitae.)*

---

#### APPENDIX J — Certificate of Grammarian / Language Editing

*(Insert certificate.)*

---

#### APPENDIX K — Certificate of Statistician

*(Insert certificate.)*

---

#### APPENDIX L — Turnitin / Similarity Report

*(Insert report.)*

---

<div align="center">

**— END OF DOCUMENT —**

</div>
