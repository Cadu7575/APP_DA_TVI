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
  console.log("Iniciando verificação de live HLS (M3U8) e YouTube...");

  if (!admin.apps.length) {
    return res.status(500).json({
      error: "Firebase Admin SDK não foi inicializado. Verifique a variável FIREBASE_SERVICE_ACCOUNT."
    });
  }

  const db = admin.firestore();

  // 1. Busca a URL do stream do Firestore ou usa valor padrão
  let liveStreamUrl = "https://example.com/live/playlist.m3u8";
  try {
    const configDoc = await db.collection("system_settings").doc("live_config").get();
    if (configDoc.exists && configDoc.data().liveStreamUrl) {
      liveStreamUrl = configDoc.data().liveStreamUrl;
    }
  } catch (err) {
    console.error("Erro ao ler liveStreamUrl do Firestore:", err);
  }

  let hlsLive = false;
  
  // 2. Valida o manifesto HLS .m3u8 se não for a URL padrão/placeholder
  if (liveStreamUrl && liveStreamUrl !== "https://example.com/live/playlist.m3u8") {
    try {
      console.log(`Checando URL HLS: ${liveStreamUrl}`);
      const response = await axios.get(liveStreamUrl, {
        timeout: 6000,
        headers: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          "Accept": "*/*"
        }
      });

      if (response.status === 200 && typeof response.data === "string") {
        const content = response.data.trim();
        if (content.startsWith("#EXTM3U") || content.includes("#EXTM3U")) {
          hlsLive = true;
        }
      }
    } catch (err) {
      console.log(`Stream HLS offline ou erro: ${err.message}`);
    }
  }

  // 3. Checa o status do YouTube Live (@tvitape2)
  let youtubeLive = false;
  let youtubeVideoId = "";
  let youtubeTitle = "A TV Itapê está transmitindo ao vivo";

  try {
    const channelHandle = "tvitape2";
    console.log(`Checando canal do YouTube: @${channelHandle}`);
    const ytResponse = await axios.get(`https://www.youtube.com/@${channelHandle}/streams`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
        "Cookie": "PREF=tz=America/Sao_Paulo; CONSENT=YES+cb.20210328-17-p0.en+FX+433;"
      },
      timeout: 8000
    });

    const html = ytResponse.data;
    const startPattern = "ytInitialData = ";
    const startIndex = html.indexOf(startPattern);
    
    if (startIndex !== -1) {
      const jsonStart = startIndex + startPattern.length;
      const scriptEndIndex = html.indexOf("</script>", jsonStart);
      
      let jsonEnd = html.lastIndexOf(";", scriptEndIndex);
      if (jsonEnd === -1 || jsonEnd < jsonStart) {
        jsonEnd = scriptEndIndex;
      }
      
      const jsonStr = html.substring(jsonStart, jsonEnd).trim();
      const data = JSON.parse(jsonStr);

      const lockups = [];
      function findLockups(node) {
        if (typeof node === "object" && node !== null) {
          if (node.lockupViewModel) {
            lockups.push(node.lockupViewModel);
          } else {
            for (const key in node) {
              findLockups(node[key]);
            }
          }
        } else if (Array.isArray(node)) {
          for (const val of node) {
            findLockups(val);
          }
        }
      }
      findLockups(data);

      for (const l of lockups) {
        const videoId = l.contentId;
        const metadata = l.metadata?.lockupMetadataViewModel;
        const title = metadata?.title?.content || "";

        if (!videoId || !title) continue;

        let isLive = false;
        let isUpcoming = false;
        
        const overlays = l.contentImage?.thumbnailViewModel?.overlays;
        if (overlays) {
          for (const o of overlays) {
            const badge = o.thumbnailBottomOverlayViewModel?.badges?.[0]?.thumbnailBadgeViewModel;
            if (badge) {
              const text = badge.text || "";
              const style = badge.badgeStyle || "";
              if (text === "Em breve" || text === "Upcoming" || style.includes("UPCOMING")) {
                isUpcoming = true;
              } else if (text === "Ao vivo" || text === "AO VIVO" || text === "LIVE" || style.includes("LIVE")) {
                isLive = true;
              }
            }
          }
        }

        if (isLive && !isUpcoming) {
          youtubeLive = true;
          youtubeVideoId = videoId;
          youtubeTitle = stripEmojis(
            title.replace(/\\u0026/g, "&").replace(/\\n/g, " ")
          ).substring(0, 100);
          console.log(`Live ENCONTRADA: ${youtubeTitle} (ID: ${videoId})`);
          break; // pega a primeira live ativa que encontrar
        }
      }
    } else {
      console.log("ytInitialData não encontrado na aba de streams.");
    }

    // Fallback de título se vazio
    if (!youtubeTitle) {
      youtubeTitle = "A TV Itapê está transmitindo ao vivo";
    }
  } catch (err) {
    console.error("Erro ao verificar status do YouTube:", err.message);
  }

  const isCurrentlyLive = hlsLive || youtubeLive;
  console.log(`Checagem final: HLS Live=${hlsLive}, YouTube Live=${youtubeLive} ➔ Está ao Vivo=${isCurrentlyLive} (VideoId: ${youtubeVideoId})`);

  // 4. Lê o estado anterior salvo
  const statusRef = db.collection("system_settings").doc("live_status");
  const lastLiveRef = db.collection("system_settings").doc("last_live");
  
  try {
    const statusDoc = await statusRef.get();
    let wasLive = false;
    if (statusDoc.exists) {
      wasLive = !!statusDoc.data().isLive;
    }

    const lastLiveDoc = await lastLiveRef.get();
    let lastNotifiedVideoId = "";
    if (lastLiveDoc.exists) {
      lastNotifiedVideoId = lastLiveDoc.data().videoId || "";
    }

    console.log(`Estado anterior: wasLive=${wasLive}. Última live notificada ID=${lastNotifiedVideoId}`);

    let shouldNotify = false;

    // Condição de envio de Push:
    // A) Entrou ao vivo no HLS (offline -> online)
    if (hlsLive && !wasLive) {
      shouldNotify = true;
      console.log("Transmissão HLS iniciou. Habilitando notificação.");
    }
    // B) Entrou ao vivo no YouTube e o videoId é diferente do último notificado
    else if (youtubeLive && youtubeVideoId && youtubeVideoId !== lastNotifiedVideoId) {
      shouldNotify = true;
      console.log(`Nova live no YouTube detectada (ID: ${youtubeVideoId}). Habilitando notificação.`);
    }
    // C) Entrou ao vivo de forma geral (wasLive era false e agora isCurrentlyLive é true) e não tínhamos ID gravado
    else if (isCurrentlyLive && !wasLive) {
      shouldNotify = true;
      console.log("Transmissão geral detectada de offline para online. Habilitando notificação.");
    }

    let notificationSent = false;

    if (shouldNotify) {
      console.log(`Disparando push notification para o tópico: ${TOPIC_NAME}`);
      
      const message = {
        topic: TOPIC_NAME,
        notification: {
          title: "Ao vivo agora!",
          body: youtubeLive ? youtubeTitle : "A TV Itapê está transmitindo ao vivo",
        },
        data: {
          type: "live",
          link: "live",
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
      console.log("Push notification enviado com sucesso.");

      // Salva o ID da live do YouTube notificada para evitar spam
      if (youtubeLive && youtubeVideoId) {
        await lastLiveRef.set({
          videoId: youtubeVideoId,
          title: youtubeTitle,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
      }
    }

    // 5. Salva o novo status no Firestore (atualizando timestamp)
    await statusRef.set({
      isLive: isCurrentlyLive,
      lastCheckedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return res.status(200).json({
      success: true,
      isLive: isCurrentlyLive,
      wasLive: wasLive,
      hlsLive: hlsLive,
      youtubeLive: youtubeLive,
      youtubeVideoId: youtubeVideoId,
      notificationSent: notificationSent,
      checkedAt: new Date().toISOString()
    });

  } catch (err) {
    console.error("Erro ao gerenciar estado de live:", err);
    return res.status(500).json({
      success: false,
      error: err.message
    });
  }
};
