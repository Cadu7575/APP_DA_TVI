const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// Tópico padrão para notificações
const TOPIC_NAME = "noticias_gerais";

// Função agendada para rodar a cada 5 minutos
exports.checkLiveStream = onSchedule("every 5 minutes", async (event) => {
  logger.info("Iniciando verificação de live no YouTube...");
  
  try {
    const channelHandle = "tvitape2";
    const response = await axios.get(`https://www.youtube.com/@${channelHandle}/live`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8"
      },
      timeout: 10000
    });

    const html = response.data;
    
    // Verifica se a página indica que está ao vivo mesmo
    // 1. Deve ter indicador de live broadcast ativo
    const isLiveBroadcast = html.includes('"isLiveBroadcast":true') || html.includes('"hlsManifestUrl"');
    
    // 2. Se tiver marcador de agendado (upcoming), NÃO está ao vivo de verdade ainda
    const isUpcoming = html.includes('"style":"UPCOMING"') || 
                       html.includes('"liveBroadcastability":"LIVE_BROADCASTABILITY_BUYABLE"') ||
                       html.includes('"isUpcoming":true');

    const isLive = isLiveBroadcast && !isUpcoming;
    logger.info(`Status do canal: Live Broadcast=${isLiveBroadcast}, Upcoming=${isUpcoming} -> Está ao Vivo=${isLive}`);

    if (isLive) {
      // Extrai o ID do vídeo ao vivo
      const videoIdMatch = html.match(/"videoId":"([a-zA-Z0-9_-]{11})"/);
      if (videoIdMatch) {
        const videoId = videoIdMatch[1];
        logger.info(`Live encontrada com o ID do vídeo: ${videoId}`);

        // Para evitar enviar notificações repetidas para a mesma transmissão ao vivo,
        // salvamos o ID da última live notificada no Firestore.
        const db = admin.firestore();
        const liveRef = db.collection("system_settings").doc("last_live");
        const doc = await liveRef.get();

        let lastNotifiedId = "";
        if (doc.exists) {
          lastNotifiedId = doc.data().videoId || "";
        }

        if (videoId !== lastNotifiedId) {
          logger.info(`Nova live detectada! Enviando push notification para o tópico: ${TOPIC_NAME}`);
          
          // Extrai o título do vídeo para mandar um push personalizado
          let title = "🔴 TVI Tape 2 está AO VIVO!";
          const titleMatch = html.match(/"title":"([^"]+)"/);
          if (titleMatch) {
            title = titleMatch[1]
              .replace(/\\u0026/g, "&")
              .replace(/\\n/g, " ")
              .substring(0, 100);
          }

          // Envia o payload do push
          const message = {
            topic: TOPIC_NAME,
            notification: {
              title: "🔴 TVI está Ao Vivo!",
              body: title,
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
          
          // Atualiza o banco com a nova live enviada
          await liveRef.set({
            videoId: videoId,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          });

          logger.info(`Notificação enviada com sucesso para a live ${videoId}`);
        } else {
          logger.info(`A live ${videoId} já foi notificada anteriormente. Nenhuma ação necessária.`);
        }
      } else {
        logger.error("Não foi possível extrair o videoId do HTML da live.");
      }
    } else {
      logger.info("O canal não está transmitindo ao vivo no momento.");
    }
  } catch (error) {
    logger.error("Erro durante a execução do monitor de live:", error);
  }
});

// Monitor automático do stream HLS (M3U8)
exports.liveStreamWatcher = onSchedule("every 1 minutes", async (event) => {
  logger.info("Iniciando verificação do status da transmissão HLS (M3U8)...");
  const db = admin.firestore();
  
  // 1. Busca a URL de stream configurada (tenta Firestore, senão usa padrão)
  let liveStreamUrl = "https://example.com/live/playlist.m3u8";
  try {
    const configDoc = await db.collection("system_settings").doc("live_config").get();
    if (configDoc.exists && configDoc.data().liveStreamUrl) {
      liveStreamUrl = configDoc.data().liveStreamUrl;
    } else {
      // Se não existir, inicializa com o placeholder
      await db.collection("system_settings").doc("live_config").set({
        liveStreamUrl: liveStreamUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }
  } catch (err) {
    logger.error("Erro ao obter URL de stream do Firestore:", err);
  }

  logger.info(`Validando HLS em: ${liveStreamUrl}`);
  let isCurrentlyLive = false;

  // 2. Faz a requisição HTTP no manifesto .m3u8
  try {
    const response = await axios.get(liveStreamUrl, {
      timeout: 8000,
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept": "*/*"
      }
    });

    if (response.status === 200 && typeof response.data === "string") {
      const content = response.data.trim();
      // Manifestos HLS válidos HLS contêm a tag #EXTM3U
      if (content.startsWith("#EXTM3U") || content.includes("#EXTM3U")) {
        isCurrentlyLive = true;
      }
    }
  } catch (err) {
    logger.info(`Erro na verificação HLS (transmissão offline): ${err.message}`);
  }

  logger.info(`Resultado HLS: isCurrentlyLive=${isCurrentlyLive}`);

  // 3. Lê o estado anterior salvo
  const statusRef = db.collection("system_settings").doc("live_status");
  
  try {
    const statusDoc = await statusRef.get();
    let wasLive = false;
    if (statusDoc.exists) {
      wasLive = !!statusDoc.data().isLive;
    }

    logger.info(`Estado anterior: wasLive=${wasLive}, Novo estado: isLive=${isCurrentlyLive}`);

    // 4. Executa a lógica de transição e notificação (Idempotente)
    if (isCurrentlyLive && !wasLive) {
      // Offline -> Online: Dispara FCM Push
      logger.info(`Canal entrou AO VIVO! Enviando notificação para o tópico: ${TOPIC_NAME}`);
      
      const message = {
        topic: TOPIC_NAME,
        notification: {
          title: "Ao vivo agora!",
          body: "A TV Itapê está transmitindo ao vivo",
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
      logger.info("Notificação de live enviada com sucesso.");
    }

    // 5. Atualiza o banco com o novo estado e timestamp (sempre atualiza lastCheckedAt)
    await statusRef.set({
      isLive: isCurrentlyLive,
      lastCheckedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

  } catch (err) {
    logger.error("Erro ao gerenciar transição de estados de live:", err);
  }
});

