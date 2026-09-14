/**
 * FlashLearn Cloud Functions.
 *
 * routineHelpPush — tells a learner's educators, on their own phones, that the
 * learner has been stuck on a My Day step long enough to need help. It works
 * with the educator app closed, which the in-app dashboard alert cannot.
 *
 * The learner's tablet writes one `routine_help/{child}_{day}_{step}` document
 * when a step escalates on its lock screen (the rules allow creating it once,
 * and only by the device that owns the learner). This function answers that
 * document by sending a notification to every `push_tokens` entry registered
 * by the educators it names, in each device's own language.
 */
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

// Same region as the Firestore database, so the trigger stays local.
setGlobalOptions({region: "asia-southeast1", maxInstances: 5});

/** Firestore `in` queries take at most 30 values. */
const MAX_EDUCATORS = 30;

/** FCM errors that mean the token will never work again. */
const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/**
 * The notification text for one educator's device.
 *
 * @param {object} help The routine_help document.
 * @param {boolean} filipino Whether the device uses Filipino.
 * @return {{title: string, body: string}} What the educator reads.
 */
function helpText(help, filipino) {
  const name = help.child_name || (filipino ? "Isang bata" : "A learner");
  const step = filipino ?
    (help.step_title_filipino || help.step_title || "") :
    (help.step_title || help.step_title_filipino || "");
  if (filipino) {
    return {
      title: "Kailangan ng tulong ang isang bata",
      body: step ?
        `Kailangan ng tulong si ${name} sa ${step}` :
        `Kailangan ng tulong si ${name}`,
    };
  }
  return {
    title: "A learner needs help",
    body: step ? `${name} needs help with ${step}` : `${name} needs help`,
  };
}

exports.helpText = helpText;

exports.routineHelpPush = onDocumentCreated(
    "routine_help/{helpId}",
    async (event) => {
      const help = event.data && event.data.data();
      if (!help) return;

      const educators = [...new Set(
          (help.educator_profile_ids || [])
              .filter((id) => typeof id === "string" && id.length > 0),
      )].slice(0, MAX_EDUCATORS);
      if (educators.length === 0) {
        logger.info("no educators to tell", {help: event.params.helpId});
        return;
      }

      const tokens = await getFirestore()
          .collection("push_tokens")
          .where("profile_id", "in", educators)
          .get();
      if (tokens.empty) {
        logger.info("no registered educator devices", {educators});
        return;
      }

      const key = help.key ||
        `${help.child_profile_id}|${help.day}|${help.step_id}`;
      const results = await Promise.all(tokens.docs.map(async (doc) => {
        const device = doc.data();
        const text = helpText(help, device.locale === "fil");
        try {
          await getMessaging().send({
            token: device.token,
            notification: text,
            data: {
              type: "routine_help",
              key,
              child_profile_id: String(help.child_profile_id || ""),
              title: text.title,
              body: text.body,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "routine_help",
                // One notification per learner and step, however often sent.
                tag: `routine_help_${key}`,
              },
            },
          });
          return "sent";
        } catch (e) {
          const code = e.code || (e.errorInfo && e.errorInfo.code);
          if (DEAD_TOKEN_CODES.has(code)) {
            await doc.ref.delete();
            return "removed";
          }
          logger.warn("send failed", {code, token: doc.id});
          return "failed";
        }
      }));
      logger.info("routine help pushed", {
        help: event.params.helpId,
        sent: results.filter((r) => r === "sent").length,
        removed: results.filter((r) => r === "removed").length,
        failed: results.filter((r) => r === "failed").length,
      });
    },
);
