# Usability & Learner-Feedback Methodology (Triangulation)

This app evaluates usability with **two complementary instruments**, each
administered to the respondent who can answer it validly. This document records
the rationale and the design — cite it in the thesis methodology chapter.

## The problem with a single instrument

The **System Usability Scale (SUS)** (Brooke, 1996) is a validated 10-item,
0–100 usability instrument — but it is an **adult, English-origin, abstract**
scale with alternating positive/negative wording. Administering it *directly to
young Deaf/Hard-of-Hearing (DHH) PWD learners*, whose first language is Filipino
Sign Language rather than written Filipino/English, violates its assumptions:

1. **Reading/language.** Items such as *"unnecessarily complex"*,
   *"too much inconsistency"*, *"very awkward"* require high written-language
   comprehension — for DHH learners it becomes a reading test, not a usability
   rating.
2. **Alternating polarity.** Mixed positive/negative items cause response errors
   and acquiescence bias even in adults; far worse with children.
3. **5-point bipolar abstraction.** Young children do not reliably map feelings
   onto a 5-point agree/disagree scale.
4. **Metacognitive judgment.** "I felt confident using the app" asks for a
   reflective self-assessment many young learners cannot form reliably.

The result would be low-reliability data and a usability claim a panel could
challenge.

## The approach: triangulation (Option D)

| Instrument | Respondent | Role in the thesis | Reported as |
|---|---|---|---|
| **SUS** (standard 10-item, EN/FIL) | **Teacher / facilitator** | Primary, *validated* usability measure | 0–100 score; >68 = above average |
| **Smileyometer** (3-face visual scale) | **Student / learner** | The learners' own experience | Descriptive (% per face, mean 1–3) — **not** a usability score |

- The **teacher SUS** preserves the validated instrument and its benchmark,
  completed by an adult who can answer all 10 items correctly. It is framed in
  the app as the teacher/facilitator rating the app's usability.
- The **Smileyometer** (Read & MacFarlane, *Fun Toolkit*) is a child-friendly,
  visual-first scale (😞 🙂 😄 = 1/2/3) over three short questions (fun / ease /
  intent to reuse). It captures the learner voice in a form DHH children can
  answer, and is reported **descriptively** — it is explicitly *not* converted
  to a SUS-style score.

This separation is the key methodological point: each instrument is used only
where it is valid, and the two are reported under distinct headings.

## How it works in the app

- **SUS** — Educator Home → *Survey Results* → *Take Survey* (`/sus-survey`).
  Saved against the active (teacher) profile. Items are kept verbatim for
  validity; only an intro line frames the teacher as the respondent.
- **Smileyometer** — a "How was it? / Kumusta?" entry on each learner home
  (`/smileyometer`). Big tappable faces, minimal text. Saved against the active
  (student) profile.

## Research export

Both instruments are exported by `ResearchExportService` (anonymized):

- `sus_survey_results.csv` — `respondent_id, respondent_role, survey_date,
  q1..q10, sus_score, grade_label, feedback_length`. Filter `respondent_role ==
  'teacher'` (or `'parent'`) for the primary usability analysis.
- `student_experience.csv` — `student_id, group_label, completed_at, q1, q2, q3,
  mean_rating`. Report descriptively, optionally split by `group_label`
  (treatment vs control).

Row formatting is unit-tested in `test/core/research_export_rows_test.dart`.

## Note on the Filipino scale

The Filipino SUS anchor for *Strongly Disagree* was previously duplicated with
*Disagree*; it is now `'Lubos na Hindi Sang-ayon'`, giving five distinct anchors
that match the English scale.

## References

- Brooke, J. (1996). *SUS: A 'quick and dirty' usability scale.*
- Read, J. C., & MacFarlane, S. (2006). *Using the Fun Toolkit and other survey
  methods to gather opinions in Child Computer Interaction.*
