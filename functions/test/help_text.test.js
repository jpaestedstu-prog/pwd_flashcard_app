const test = require("node:test");
const assert = require("node:assert/strict");

// index.js initialises firebase-admin at load; the text builder is pure, so it
// is loaded with the admin/functions modules stubbed out.
const Module = require("node:module");
const realLoad = Module._load;
Module._load = function(request, ...rest) {
  if (request === "firebase-admin/app") return {initializeApp: () => {}};
  if (request === "firebase-admin/firestore") return {getFirestore: () => ({})};
  if (request === "firebase-admin/messaging") return {getMessaging: () => ({})};
  if (request === "firebase-functions/v2") return {setGlobalOptions: () => {}};
  if (request === "firebase-functions/logger") {
    return {info: () => {}, warn: () => {}};
  }
  if (request === "firebase-functions/v2/firestore") {
    return {onDocumentCreated: (_, handler) => handler};
  }
  return realLoad.call(this, request, ...rest);
};
const {helpText} = require("../index.js");
Module._load = realLoad;

const help = {
  child_name: "Ana",
  step_title: "Brushing Teeth",
  step_title_filipino: "Pagsisipilyo",
};

test("English names the learner and the step", () => {
  assert.deepEqual(helpText(help, false), {
    title: "A learner needs help",
    body: "Ana needs help with Brushing Teeth",
  });
});

test("Filipino uses the Filipino step title", () => {
  assert.deepEqual(helpText(help, true), {
    title: "Kailangan ng tulong ang isang bata",
    body: "Kailangan ng tulong si Ana sa Pagsisipilyo",
  });
});

test("a missing title or name still reads as a sentence", () => {
  assert.equal(helpText({}, false).body, "A learner needs help");
  assert.equal(helpText({child_name: "Ben"}, true).body,
      "Kailangan ng tulong si Ben");
  assert.equal(helpText({child_name: "Ben", step_title: "Lunch"}, true).body,
      "Kailangan ng tulong si Ben sa Lunch");
});
