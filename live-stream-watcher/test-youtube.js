const axios = require("axios");

async function checkLive(channelHandle) {
  try {
    console.log(`Checking @${channelHandle}...`);
    const ytResponse = await axios.get(`https://www.youtube.com/@${channelHandle}/live`, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8"
      },
      timeout: 8000
    });

    const html = ytResponse.data;
    const playerResponseMatch = html.match(/ytInitialPlayerResponse\s*=\s*({.+?});/);
    if (playerResponseMatch) {
      console.log("ytInitialPlayerResponse FOUND!");
      const playerResponse = JSON.parse(playerResponseMatch[1]);
      const videoDetails = playerResponse.videoDetails;
      console.log("Video ID:", videoDetails?.videoId);
      console.log("isLive:", videoDetails?.isLive);
      console.log("isLiveContent:", videoDetails?.isLiveContent);
    } else {
      console.log("ytInitialPlayerResponse NOT FOUND!");
      // let's see if there's any other json
      if (html.includes("ytInitialPlayerResponse")) {
        console.log("The word ytInitialPlayerResponse exists in the HTML, but regex failed.");
      }
      
      const fs = require("fs");
      fs.writeFileSync("failed-html.html", html);
      console.log("Dumped HTML to failed-html.html");
    }
  } catch (err) {
    console.error("Error:", err.message);
  }
}

checkLive("tvitape2");
