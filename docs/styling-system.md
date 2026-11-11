# How the app's styling fits together

For whoever changes a screen, a button or a theme next. One design, shared
everywhere; the few things that genuinely differ between a phone, a tablet and
a computer's browser live in one file.

## Where each thing lives

| What | Where | Notes |
| --- | --- | --- |
| Colours, shapes, type of every theme | `lib/core/theme/app_theme.dart` | Shared control builders at the top of the class: `_elevatedTheme`, `_filledTheme`, `_outlinedTheme`, `_textButtonTheme`, `_fieldTheme`, `_snackBarTheme`, `_pageTransitions`. A new theme calls these and picks colours. |
| Contrast (AA) for every theme | `lib/core/theme/accessible_theme.dart` | Every theme ends in `accessibleTheme()`. Also: `tonalButtonStyle(context)`. |
| Phone / tablet / browser differences | `lib/core/theme/form_factor.dart` | `FormFactor` decides which. `FormMetrics` holds the sizes that differ. `AdaptiveTheme` applies them to the shared theme, in `main.dart`. |
| Text that fits its box | `lib/core/widgets/auto_fit.dart`, `fit_text.dart` | See below. |
| How wide a page's content runs | `lib/core/widgets/page_frame.dart` | `PageWidth` is set per route in `lib/navigation/app_router.dart`, through `AppPageTransitions`. |
| Page gutters and grid columns | `lib/core/utils/responsive_utils.dart` | `context.pagePadding`, `gridColumns`, `maxContentWidth`. |
| Spacing tokens | `lib/core/theme/app_spacing.dart` | |

## What differs per form factor, and what does not

`FormFactor.forSize`: **phone** (short side under 600 dp, either way up),
**tablet** (touch screen, short side 600 dp or more), **desktop** (a browser on
a computer, in a window at least 600 dp wide).

Only control **sizes** change, in `FormMetrics`: button and field padding,
minimum button sizes, dialog and snack-bar widths, and the scrollbar on a
computer. Colours, shapes and type come from the shared theme, so a theme that
works on one works on all. Touch targets stay at least 56 dp tall on touch
screens; a mouse may use 48. Add a new per-device value to `FormMetrics`; do
not branch on the platform inside a screen.

## Button labels

Every Material button's label goes through `autoFitButtonForeground`, set once
in `accessibleTheme`, so a button fits its label without anyone asking:

1. a little smaller on one line, if that is all it takes;
2. otherwise on more lines, words whole, full size (at a large text size this
   comes first, because a learner who asked for big text wants it big);
3. otherwise smaller, never below `kMinReadableFontSize` (11);
4. only a single word too long for the column goes below that, whole.

A new button gets this by being a `FilledButton`, `ElevatedButton`,
`OutlinedButton` or `TextButton`. Nothing else is needed, and a label's own
`FitText` is left alone.

For text in a tile, chip or row, use one of these instead of `FittedBox`, which
has no floor and shrinks whole words to nothing:

| Widget | When |
| --- | --- |
| `AutoFit` | Any label, anywhere, including inside a `Wrap`, a button or an `IntrinsicHeight`. |
| `FitText` | A word in a fixed-width tile, where its column should be measured. Cannot sit under a parent that asks intrinsic sizes. |
| `FittedBox(scaleDown)` | Only for something that is not words, such as an icon or a score. |

Do not put a `Spacer` beside a `Flexible` holding text: the two split the free
room, and the text gets half of what it could have had.

`AutoFit` also respects a paragraph's own `maxLines`: a text allowed two lines
that needs three is drawn smaller rather than cut at its limit.

## Text sizes

Nothing a learner reads is set under 11 px. Chart axis labels, which sit in
space the chart library reserves at a fixed size, are 10. Tiles with a fixed
height (sticker shelf, FSL dictionary, template cards) take their height from
what their words need at the current text size, not from their width alone: a
`childAspectRatio` ties height to width, and bigger text then has nowhere to go.

Screens under 350 wide are a small phone, or any phone with Android's Display
Size at Largest, which low-vision learners are likely to set. There, words get
the room and decoration gives way: tiles and game cards are taller
(`hubTileHeight`, `_gameCardHeight`), four stats go two above two
(`StatsAcross`), and a decorative icon that would squeeze a label drops out.
Check a fixed shape as well as a fixed size: the Flashcard Quiz card was locked
to 3:4, so in a short space it also became narrow, with both sides of the
screen empty.

## Titles

Every app bar title is an `AppBarTitle`. An app bar lays its title out with no
limit on height, so `AppBarTitle` passes the bar's own height to `FitText`: at
the largest Font Size a long title takes two lines and shrinks only as far as
it must to stay inside the bar (`test/app_bar_title_inside_bar_test.dart`). In
an expanding header (`FlexibleSpaceBar`) it keeps the header's room.

## Wide buttons

`CappedWidth` (`lib/core/widgets/capped_width.dart`) fills the column on a
phone and stops at `kMaxButtonWidth` (600), centred, on a tablet held sideways
or a computer. Put it around whatever made a button full width (a
`SizedBox(width: double.infinity)`, `minimumSize: Size.fromHeight(…)`, a gaze
tile) so a focus ring still hugs the button. `AppButton(fullWidth: true)` does
this itself.

## The AI Buddy

The AI Buddy is a floating action button (`CompanionHost`, drawn above the
whole app): its face (the 🤖 tile, 🧸 for a Child) in the bottom-right corner
of the five learner hubs and a Guest's pages, above the tab bar. It is never an
item in the navigation bar: the owner asked for exactly that (10 Nov 2026),
after a trial build docked it at the end of the tabs. `CompanionFab`
(`lib/features/companion/widgets/companion_clearance.dart`) is the one source
of its numbers, for the overlay that draws it and for everything that keeps
clear of it:

- `CompanionFab.margin`: 16 dp from the right edge and above the tab bar on a
  phone, 24 on a tablet or a computer, plus the system's insets (the gesture
  bar, a camera cutout at the side). A Guest's rests above the bottom of the
  safe area, level with its floating Home button at the other corner.
- `CompanionFab.size`: `CompanionPresentation.launcherSize` (60 dp; 68 for
  motor, visual and multiple needs) grown with the text to 1.25x.
- `CompanionFab.rect`: where it rests. It does not move: no drag, the same
  place on every hub, a little pop as it appears (playful presentation only),
  and it rises and fades with the tab bar (`CompanionFab.reveal`) when a hub
  comes back from a game.
- `companionShownOn`: the five hubs only. Never a game, the card viewer, a
  story being read, the full tutor, or a page opened over a hub such as
  Settings (it would rest on the switches down the right-hand side).
- It steps aside while something covers the hub: a sheet or dialog on the
  shell's navigator (`shellModalObserver.popupCovering`) or the root one
  (`rootPopupObserver.covering`), and in-screen modals with no route of their
  own, such as Home's first-visit tour or a level-up card
  (`GazeModalRegion.openCount`). It floated, bright and tappable, over all
  of them.

Keeping clear of it:

- The hubs run under it, as under any floating action button, and keep room
  at the end of their lists (`CompanionClearanceSliver`, `companionClearance`:
  the button and the gap above it; the owl mascot's room when the buddy is
  switched off, `AnimatedMascotBuddy.shownFor`), so that whatever it rests
  over can be scrolled clear, and at the end of a list nothing is under it.
  Guard: `test/companion_hubs_clear_test.dart` (every learner kind, five hubs,
  seven window sizes, normal and 1.5x text: the list runs on under it, no band
  and no column; nothing out of reach; nothing under it at the end).
- The guest home is a short page of a few big buttons, the guest's whole menu,
  so it keeps clear of the button outright (`roomBesideBuddy`): a slightly
  narrower column where that clears it (a tablet, a phone on its side), or a
  page that stops just above it (a phone held upright). Guard:
  `test/companion_guest_home_clear_test.dart` (no button under it at any
  scroll position).
- Floating messages on the learner shell rise above it
  (`_messagesClearOfBuddy` in `bottom_nav_shell.dart`): it covered the OK of
  "Something went wrong" (`test/companion_snackbar_clear_test.dart`).
- No tab is ever under it (`test/companion_tab_bar_clear_test.dart`), and
  `test/companion_fab_test.dart` checks where it rests at eight window sizes
  and two text sizes, that a drag leaves it there, and that its panel opens
  over its corner, standing on the tab bar.

History, so it is not undone by accident: in 1.4.3 a hub's last row could end
under the buddy, and at the largest text the guest home's "How was it?" did.
Round 8 (9 Nov) made every hub stop short of it, which left an empty band
across the bottom of each hub (upright, cards cut off above it) and an empty
column down the right (sideways); the owner asked what had happened to the
buddy (10 Nov). A trial build then docked it in the tab bar, and the owner
asked for a floating button instead.

## Arrow keys and D-pads on every window

The arrow keys of a keyboard, remote or switch box move focus through
`GazeFocusDriver.move` (`lib/features/gaze_control/logic/gaze_focus_driver.dart`).
Three rules matter for layouts:

- From a page, a shell control (a tab, the guest's Home button, the AI Buddy)
  is taken only when the page has nothing further that way in the same column
  or row. On a tablet held sideways a tall card's middle lies below a tab's, so
  ▼ from it went out to the tab bar before the next card: the decks and stories
  under it could only be reached by wrapping round.
- From a shell control, a page control counts only when its middle is in
  view. On a short window a card built past the bottom edge sits "level" with
  the tabs, and ◀ ▶ along the tabs went to it, out of sight. "In view" also
  means not under a shell control: a page scrolls on behind the tab bar, so a
  card there is inside its list and the window, yet hidden
  (`_underShellControl`).
- From a shell control, ◀ ▶ count a page control as level only by a part of
  it in sight: the point of it at the tab's height must not be under the tab
  bar. Scrolled, a sideways Home has a row of tiles whose lower edges run
  behind the bar; level with the tabs by that hidden edge, they took ◀ ▶ from
  Cards (`test/dpad_tab_bar_sideways_test.dart` scrolls one there).

`test/support/dpad_reach_matrix.dart` checks every control on every hub and
Settings, for every kind of learner, reached by an arrow pointing at it — at
four window sizes, one test file each: `dpad_reach_test` (Honor upright),
`dpad_reach_sideways_test`, `dpad_reach_phone_test`,
`dpad_reach_phone_sideways_test`. Its walker jumps focus back to each control
it explores; it shows the control first (the app always shows what has focus)
and, in a long list, brings a control scrolled away back by name.

## Mouse regions

Any `MouseRegion` added for hover or a cursor must use
`hitTestBehavior: HitTestBehavior.deferToChild`. With `opaque: false` it
answers "not hit" to its parents, and a tap handler above it that defers to its
child never sees a tap (`test/pressable_taps_test.dart`).

## Pages on big screens

Phones are never framed. On a wider window a route says how its content is
laid out, by `PageWidth`:

- `form` (640 wide, on windows from 720 up): fields, switches and their
  buttons — Settings, Edit Profile, joining a class, Goals and the like. A
  tablet held upright (about 690 wide) is not framed; held sideways it is.
- `content` (1040 wide, on windows from 1200 up): lists, dashboards, games,
  readers. The default for pushed screens.
- `full`: the tab hubs, camera and lock screens.

Inside a frame, the screen is told the column **is** the window
(`MediaQuery.size`), so nothing else in the screen changes. The tab hubs fill
the window and keep their content in a column through `context.pagePadding`,
which grows on windows 1200 and wider — sideways only. For space above and
below, use `context.pageInset`, which never grows: a grid padded on all sides
with `pagePadding` opened a 260 px gap above the Games cards on a computer.

## Checking a change

`test/auto_fit_test.dart`, `test/form_factor_test.dart`,
`test/pressable_taps_test.dart` and `test/app_bar_title_inside_bar_test.dart`
pin all of this.
`test/surveys/ui_metrics_survey_test.dart` (see `tool/run_surveys.sh` for how
surveys run) measures every screen at phone, tablet and desktop sizes: button
labels, text drawn under 11 px, text cut by a box, stretched layouts, and light
panels on dark themes. Its report is `tool/ui_metrics_report.py`. It runs as a
learner with low vision; `UI_DISABILITY=hearing` runs it as a learner who signs,
who has more controls on some screens (FSL, Show Me).

Those numbers cannot see a layout that is technically fine and practically
useless. On a phone with Display Size at Largest, the five controls under a
flashcard wrapped and left the card a thin strip, in no test, because test
cards had fewer controls. `test/viewer_controls_one_row_test.dart` now guards
that one; look at a real device or the phone emulator as well
(`adb shell wm density 540` on the 1080-wide AVD gives 320 wide).
