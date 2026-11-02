const axios = require("axios");

async function checkStreamsTab(channelHandle) {
  try {
    const ytResponse = await axios.get(`https://www.youtube.com/@${channelHandle}/streams`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8"
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

      let foundLive = false;
      let liveVideoId = "";
      let liveTitle = "";

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

        console.log(`Video: ${title} | ID: ${videoId} | isLive: ${isLive} | isUpcoming: ${isUpcoming}`);

        if (isLive && !isUpcoming) {
          foundLive = true;
          liveVideoId = videoId;
          liveTitle = title;
          break; // pega a primeira (mais recente) que estiver ao vivo
        }
      }

      console.log("FINAL RESULT:", foundLive, liveVideoId, liveTitle);
    } else {
      console.log("ytInitialData not found");
    }
  } catch (err) {
    console.error("Error:", err.message);
  }
}

checkStreamsTab("tvitape2");
