// COLE ESTE SCRIPT NO CONSOLE DO CHROME ENQUANTO ESTIVER NO copafacil.com LOGADO
// Pressione F12 > Console > Cole tudo abaixo > Enter

fetch('https://copafacil-web.firebaseio.com/teams/-OWFvy-UxIzR-GQEMi2_.json?auth=' + (await firebase.auth().currentUser.getIdToken())).then(r=>r.json()).then(d=>console.log('TESTE TEAM:', JSON.stringify(d)));
