const admin = require('firebase-admin');
const sa = require('./tvi-news-service-account.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const securityRules = admin.securityRules();

const newRules = "rules_version = '2';\n" +
"service cloud.firestore {\n" +
"  match /databases/{database}/documents {\n" +
"    match /campeonatos/{id} {\n" +
"      allow read: if true;\n" +
"      allow write: if request.auth != null;\n" +
"      match /{allSubpaths=**} {\n" +
"        allow read: if true;\n" +
"        allow write: if request.auth != null;\n" +
"      }\n" +
"    }\n" +
"    match /usuarios/{uid} {\n" +
"      allow read, write: if request.auth.uid == uid;\n" +
"    }\n" +
"  }\n" +
"}";

async function updateRules() {
  const ruleset = await securityRules.createRuleset({
    source: [{
      name: 'firestore.rules',
      content: newRules,
    }]
  });
  await securityRules.releaseFirestoreRuleset(ruleset.name);
  console.log('Successfully released recursive subcollection rules!');
}
updateRules().catch(console.error);
