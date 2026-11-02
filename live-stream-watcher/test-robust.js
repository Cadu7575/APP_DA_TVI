const axios = require("axios");

async function checkLive(channelHandle) {
  try {
    const timestamp = Date.now();
    const ytResponse = await axios.get(`https://www.youtube.com/@${channelHandle}/live?t=${timestamp}`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8",
        "Cookie": "CONSENT=YES+cb.20210328-17-p0.en+FX+433;"
      },
      timeout: 8000
    });

    const html = ytResponse.data;
    
    let playerResponseStr = "";
    const startPattern = "ytInitialPlayerResponse = ";
    const startIndex = html.indexOf(startPattern);
    if (startIndex !== -1) {
      const jsonStart = startIndex + startPattern.length;
      const scriptEnd = html.indexOf("</script>", jsonStart);
      if (scriptEnd !== -1) {
        let jsonEnd = html.lastIndexOf(";", scriptEnd);
        if (jsonEnd === -1 || jsonEnd < jsonStart) jsonEnd = scriptEnd;
        playerResponseStr = html.substring(jsonStart, jsonEnd).trim();
      }
    }

    if (playerResponseStr) {
      const playerResponse = JSON.parse(playerResponseStr);
      const videoDetails = playerResponse.videoDetails;
      const playabilityStatus = playerResponse.playabilityStatus;

      console.log("videoDetails.isLive:", videoDetails?.isLive);
      console.log("videoDetails.isLiveContent:", videoDetails?.isLiveContent);
      console.log("videoDetails.isUpcoming:", videoDetails?.isUpcoming);
      console.log("playabilityStatus.status:", playabilityStatus?.status);
      
      const isLiveFlag = (videoDetails?.isLive === true || videoDetails?.isLiveNow === true);
      const isUpcomingFlag = (videoDetails?.isUpcoming === true);
      const isOfflineStatus = (playabilityStatus && playabilityStatus.status === "LIVE_STREAM_OFFLINE");

      console.log("youtubeLive final:", isLiveFlag && !isUpcomingFlag && !isOfflineStatus);
    } else {
      console.log("ytInitialPlayerResponse not found in HTML");
    }
  } catch (err) {
    console.error("Error:", err.message);
  }
}

checkLive("tvitape2");
