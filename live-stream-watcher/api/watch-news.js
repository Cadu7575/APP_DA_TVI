const admin = require("firebase-admin");
const axios = require("axios");

// Inicializa o Firebase Admin com a chave JSON das variáveis de ambiente
if (!admin.apps.length) {
  try {
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      let serviceAccountString = process.env.FIREBASE_SERVICE_ACCOUNT;
      if (!serviceAccountString.trim().startsWith("{")) {
        serviceAccountString = Buffer.from(serviceAccountString, "base64").toString("utf-8");
      }
      
      const serviceAccount = JSON.parse(serviceAccountString);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      console.log("Firebase Admin SDK inicializado com sucesso.");
    } else {
      console.error("Variável de ambiente FIREBASE_SERVICE_ACCOUNT não está definida.");
    }
  } catch (error) {
    console.error("Falha ao inicializar o Firebase Admin SDK:", error);
  }
}

const TOPIC_NAME = "noticias_gerais";

// Função para limpar tags HTML
function stripHtml(html) {
  if (!html) return "";
  return html.replace(/<[^>]*>/g, "");
}

// Função para decodificar entidades HTML comuns do WordPress
function decodeEntities(str) {
  if (!str) return "";
  return str
    .replace(/&#8211;/g, "—")
    .replace(/&#8216;/g, "‘")
    .replace(/&#8217;/g, "’")
    .replace(/&#8220;/g, "“")
    .replace(/&#8221;/g, "”")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'");
}

// Função para remover emojis, ícones e símbolos especiais de um texto
function stripEmojis(text) {
  if (!text) return "";
  return text
    .replace(/\p{Emoji_Presentation}/gu, "")
    .replace(/\p{Emoji}/gu, "")
    .replace(/\s+/g, " ")
    .trim();
}

module.exports = async (req, res) => {
  console.log("Iniciando verificação de novas notícias via WordPress...");

  if (!admin.apps.length) {
    return res.status(500).json({
      error: "Firebase Admin SDK não foi inicializado. Verifique a variável FIREBASE_SERVICE_ACCOUNT."
    });
  }

  const db = admin.firestore();

  try {
    // 1. Busca a última matéria publicada no WordPress (xeh.com.br)
    const response = await axios.get("https://xeh.com.br/wp-json/wp/v2/posts?per_page=1", {
      timeout: 10000,
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "application/json"
      }
    });

    if (response.status !== 200 || !Array.isArray(response.data) || response.data.length === 0) {
      return res.status(500).json({
        success: false,
        error: "Resposta inválida ou vazia da API do WordPress."
      });
    }

    const latestPost = response.data[0];
    const postId = latestPost.id;
    let postTitle = stripEmojis(decodeEntities(stripHtml(latestPost.title.rendered)));
    
    if (!postTitle) {
      postTitle = "Nova notícia publicada";
    }
    
    console.log(`Última matéria encontrada no site: ID ${postId} - "${postTitle}"`);

    // 2. Busca o ID da última notícia que notificamos no Firestore
    const lastNotifiedRef = db.collection("system_settings").doc("last_news_notified");
    const lastNotifiedDoc = await lastNotifiedRef.get();

    let lastNotifiedId = null;
    if (lastNotifiedDoc.exists) {
      lastNotifiedId = lastNotifiedDoc.data().postId;
    }

    console.log(`Estado no Firestore: Último ID notificado = ${lastNotifiedId}`);

    let notificationSent = false;

    // 3. Se o ID for diferente, significa que temos uma matéria nova!
    if (lastNotifiedId !== null && postId !== lastNotifiedId) {
      console.log(`Nova matéria detectada! Disparando push notification para o tópico: ${TOPIC_NAME}`);

      const message = {
        topic: TOPIC_NAME,
        notification: {
          title: "Nova notícia!",
          body: postTitle,
        },
        data: {
          type: "news",
          link: String(postId), // ID da matéria para abrir no app
        },
        android: {
          notification: {
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK"
          }
        },
        apns: {
          payload: {
            aps: {
              sound: "default"
            }
          }
        }
      };

      await admin.messaging().send(message);
      notificationSent = true;
      console.log(`Notificação enviada com sucesso para o post ${postId}`);
    } else if (lastNotifiedId === null) {
      // Primeira execução: inicializa o banco com o ID atual sem mandar push (para evitar spam da primeira carga)
      console.log("Primeira execução: Salvando ID atual no banco sem disparar push.");
    } else {
      console.log("Nenhuma matéria nova detectada desde a última checagem.");
    }

    // 4. Salva o novo ID no Firestore para controle de idempotência
    await lastNotifiedRef.set({
      postId: postId,
      title: postTitle,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return res.status(200).json({
      success: true,
      postId: postId,
      title: postTitle,
      notificationSent: notificationSent,
      checkedAt: new Date().toISOString()
    });

  } catch (err) {
    console.error("Erro na verificação de notícias:", err);
    return res.status(500).json({
      success: false,
      error: err.message
    });
  }
};
