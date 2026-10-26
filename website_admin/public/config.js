// The WEBSITE's own Firebase project: not the app's pwd-flashcard project.
// These values are public by design (the website sends its counts with the
// same key). What protects the data is the sign-in plus firestore.rules.
// Written by website_admin/configure.py; an empty apiKey means "not set up".
export const FIREBASE = {
  apiKey: 'AIzaSyAGjW0oU_R0KZYQmyYujaGP1fghr9fXRNE',
  authDomain: 'flashlearn-pwd-site.firebaseapp.com',
  projectId: 'flashlearn-pwd-site',
  appId: '1:804645102008:web:b5723a8c8e178a89512f4d',
};

export const SITE = {
  url: 'https://jpaestedstu-prog.github.io/pwd_flashcard_app/',
  repo: 'jpaestedstu-prog/pwd_flashcard_app',
};
