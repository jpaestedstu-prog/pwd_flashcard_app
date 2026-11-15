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

// Email notices (../email_notifier): the website's feedback form also sends each
// rating or message to the team's own Google Apps Script, which emails it to
// `to`. `to` is shown on the Tools page and must match ADMIN_EMAIL in Code.gs
// (configure.py --check compares them); `url` is the script's web app address
// (configure.py --mail-url), empty until it is set up. Public by design like the
// values above: the script can only ever email that one address.
export const MAIL = {
  to: 'jaj4ngpinasto@gmail.com',
  url: '',
};
