#!/usr/bin/env bash
# The long surveys in test/surveys, which ordinary test runs skip: they press
# every control on every screen (twice over: a tablet in English, a small phone
# at the largest text size in Filipino) and lay every screen out across screen
# sizes, orientations, text sizes, themes and languages, with the store full of
# the longest text people may type. About 30 minutes on this PC.
#
#   bash tool/run_surveys.sh            then python tool/survey_report.py
#                                       and  python tool/ui_metrics_report.py
#
# The last group (ui) measures what the others cannot see: how each button's
# label sits in it, text drawn under 11 px or cut by a box, layouts stretched
# across a tablet or a computer, and light panels left on dark themes.
#
# What they find goes to build/, for reading: a survey reports, it does not pass
# or fail. Start them one at a time: flutter's tool crashes when several start
# in the same moment and copy the same file.
set -u
cd "$(dirname "$0")/.."
export FLASHLEARN_SURVEY=1
rm -f build/matrix_*.json build/crawl_*.json build/english_*.json build/filipino_*.json build/seen_*.json build/ui_metrics_*.json

group() { # name variable file
  local name=$1 variable=$2 file=$3
  for i in 0 1 2 3; do
    (
      env "$variable=$name$i" flutter test "$file" \
        --total-shards 4 --shard-index "$i" --concurrency 1 \
        > "build/survey_${name}_$i.log" 2>&1
      echo "$name group $i: $(tail -1 "build/survey_${name}_$i.log" | cut -c1-80)"
    ) &
    sleep 45
  done
  wait
}

group normal CRAWL_SHARD test/surveys/button_crawl_survey_test.dart
export CRAWL_SMALL=1
group small CRAWL_SHARD test/surveys/button_crawl_survey_test.dart
unset CRAWL_SMALL
group matrix MATRIX_SHARD test/surveys/layout_matrix_survey_test.dart
group live LIVE_SHARD test/surveys/live_language_survey_test.dart
group ui UI_SHARD test/surveys/ui_metrics_survey_test.dart
echo "done: python tool/survey_report.py; python tool/ui_metrics_report.py"
