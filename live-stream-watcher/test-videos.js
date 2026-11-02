const axios = require("axios");

async function checkVideo(videoId) {
  try {
    const ytResponse = await axios.get(`https://www.youtube.com/watch?v=${videoId}`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8"
      },
      timeout: 8000
    });

    const html = ytResponse.data;
    const playerResponseMatch = html.match(/ytInitialPlayerResponse\s*=\s*({.+?});/);
    if (playerResponseMatch) {
      const playerResponse = JSON.parse(playerResponseMatch[1]);
      const videoDetails = playerResponse.videoDetails;
      const playabilityStatus = playerResponse.playabilityStatus;

      console.log("videoDetails.isLive:", videoDetails?.isLive);
      console.log("videoDetails.isLiveContent:", videoDetails?.isLiveContent);
      console.log("videoDetails.isUpcoming:", videoDetails?.isUpcoming);
      console.log("playabilityStatus.status:", playabilityStatus?.status);
    } else {
      console.log("ytInitialPlayerResponse not found in HTML");
    }
  } catch (err) {
    console.error("Error:", err.message);
  }
}

checkVideo("ZrQfzH5joNc");
checkVideo("YuJquRMYx1E"); // the one from logs
