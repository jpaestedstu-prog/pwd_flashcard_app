# Free for users, and what it costs to run

## FlashLearn PWD is free, for good

The Android app is free to download and use. Nothing in it asks for money:
there are no purchases, no subscriptions, no ads and no paid tier. The Star
Shop's "premium" items are bought with stars a learner earns by learning, never
with money. The website says so ("100% free", "No ads").

**Rule for future work:** every feature a learner, teacher or parent needs
stays free. No paid gates, subscriptions, trials, ads or charges for core
features, and nothing that makes the app depend on a paid service. A change
that would need one is a decision for the project owner first, made in the
open, with this page updated.

## What it costs the owner today: nothing

Everything runs on free plans, and **none of them has a payment method or a
billing account attached**, so none of them can charge. Going over a free
limit means a service pauses, not a bill.

| Service | Used for | Free limit | Over the limit |
|---|---|---|---|
| Firebase **Spark** plan: Cloud Firestore | syncing profiles, progress, classes, messages | per day: 50,000 document reads, 20,000 writes, 20,000 deletes; 1 GiB stored; 10 GiB a month downloaded | Firestore refuses requests until the daily reset (midnight Pacific time, 3 pm or 4 pm in the Philippines); the app keeps working offline and syncs afterwards |
| Firebase Anonymous Authentication | a private account per device | no charge on Spark | not applicable |
| Firebase Analytics, Crashlytics | off unless a teacher or parent turns them on | no charge | not applicable |
| GitHub (public repository) | code, Releases (the APKs and sign videos), Pages (the website), Actions (CI) | free for public repositories; Pages: about 100 GB of traffic a month; a release file up to 2 GB | GitHub may ask to reduce Pages traffic; nothing is charged |
| Cloudinary free plan | a second copy of the sign videos (the app tries GitHub first) | monthly credits | the copies stop loading until the next month; the app falls back to GitHub |

**Real use, measured on 13 October 2026** (`tool/usage_report.py`, last 30
days): usually under 3 % of any daily quota. The busiest day, 27 September, used
36 % of the reads; that was a one-off audit of the whole database, not the app.

## Watching it

- **`tool/usage_report.py`** prints reads, writes and deletes per day against
  the quotas and flags a day above 70 % (it needs a project owner's access
  token; see the file). Run it now and then, and before a big class session.
- The Firebase console shows the same under **Firestore → Usage**, and
  **Usage and billing** shows the plan.

**Budget alerts are not available, on purpose.** Google's budget alerts
belong to a billing account, and the project has none: adding one is what
would make charges possible. If the project ever moves to the pay-as-you-go
Blaze plan, set a budget with alerts (Google Cloud → Billing → Budgets &
alerts) *before* switching, and keep the daily-quota thinking: Blaze has no
hard stop, only alerts.

## What could cost money later, and only by choice

| Item | Cost | Needed for |
|---|---|---|
| Firebase Blaze plan | pay as you go | Cloud Functions, Cloud Storage, push messages, or more than the Spark quotas. Not needed today |
| Google Play Console | one-time registration fee | publishing on Google Play (the website APK needs nothing) |
| Apple Developer Program | yearly fee | not needed: iOS support was stopped on 13 October 2026 ([ios_testing.md](ios_testing.md)) |
| A custom domain | yearly fee | only if the website moves off `github.io` |

None of these is required for the Android app as it is distributed today.

## Risks to the free setup

- **Quota exhaustion.** A misbehaving copy of the app, or a script holding the
  public client key, could use up a day's reads; syncing would pause for
  everyone until the reset. The security rules limit what such a script can
  do, and App Check would be the stronger defence once store accounts exist
  ([security.md](security.md)).
- **Big classes.** A class of 30 learners syncing all day uses a few thousand
  reads, far from the limit; the report above shows the real numbers.
- **Plan changes by the providers.** Free plans can change; this page should
  be re-checked when one announces changes.
