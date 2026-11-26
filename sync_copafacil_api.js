/**
 * Copa Fácil API v2 - FULL DATA SYNC
 * Fetches all available data from Copa Fácil API and syncs to TVI Firestore
 */
const https = require('https');
const admin = require('firebase-admin');
const CF_API_KEY = '4YW3-V7UC-WR5A';

// Initialize Firebase Admin
const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
const db = admin.firestore();

function cfApi(path, extraHeaders) {
  return new Promise((resolve) => {
    const opts = {
      hostname: 'copafacil.com',
      path: '/api2' + path,
      headers: { 'x-api-key': CF_API_KEY, 'lang': 'pt', 'gmt': '-3', ...extraHeaders }
    };
    https.get(opts, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(d) }); }
        catch(e) { resolve({ status: res.statusCode, raw: d }); }
      });
    }).on('error', e => resolve({ error: e.message }));
  });
}

const tournaments = [
  { cfId: '-077g4', fsId: 'copafacil_077g4', nome: 'Varzeano Itapetininga 2026' },
  { cfId: '-5fqd2', fsId: 'copafacil_5fqd2', nome: 'Copa TVitapê 2026' },
  { cfId: '-jcgq9', fsId: 'copafacil_jcgq9', nome: 'Copa TVitapê 2025' },
  { cfId: '-rmjb0', fsId: 'copafacil_rmjb0', nome: 'Varzeano Itapetininga 2025' },
];

async function main() {
  console.log('═══════════════════════════════════════════════');
  console.log('  Copa Fácil API v2 → TVI Firestore SYNC');
  console.log('═══════════════════════════════════════════════\n');

  for (const t of tournaments) {
    console.log(`\n${'━'.repeat(50)}`);
    console.log(`📌 ${t.nome} (${t.cfId})`);
    console.log(`${'━'.repeat(50)}`);

    // 1. STAGES (fases)
    console.log('\n1️⃣  Fases...');
    const stagesR = await cfApi(`/tournament/${t.cfId}/stages`);
    const stages = stagesR.data || [];
    console.log(`   ${stages.length} fases encontradas`);
    
    if (stages.length > 0) {
      for (const stage of stages) {
        console.log(`   📋 ${stage.title} (${stage.id}) round_robin=${stage.round_robin}`);
        
        // 1a. CLASSIFICATION TABLE
        const tableR = await cfApi(`/tournament/${t.cfId}/stages/${stage.id}/table`);
        if (tableR.data?.teams?.length > 0) {
          console.log(`      📊 Classificação: ${tableR.data.teams.length} times`);
          tableR.data.teams.forEach(team => {
            console.log(`         ${team.position}. ${team.name} (${team.id})`);
          });
          
          // Save classification to Firestore
          const classRef = db.collection('campeonatos').doc(t.fsId)
            .collection('classificacao').doc(stage.id);
          await classRef.set({
            faseId: stage.id,
            faseTitulo: stage.title,
            roundRobin: stage.round_robin || false,
            header: tableR.data.header || [],
            times: tableR.data.teams.map(team => ({
              nome: team.name,
              posicao: team.position,
              fotoUrl: team.photo || null,
              timeId: team.id,
              dados: team.tableData || [],
            })),
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(`      ✅ Classificação salva no Firestore`);
        }
        
        // 1b. ROUNDS (rodadas)
        const roundsR = await cfApi(`/tournament/${t.cfId}/stages/${stage.id}/rounds`);
        const rounds = roundsR.data || [];
        console.log(`      🔄 ${rounds.length} rodadas`);
        
        for (const round of rounds) {
          // 1c. MATCHES (partidas)
          const matchesR = await cfApi(`/tournament/${t.cfId}/stages/${stage.id}/rounds/${round.id}/matchs`);
          const matches = matchesR.data || [];
          
          if (matches.length > 0) {
            console.log(`         📅 ${round.title}: ${matches.length} partidas`);
            
            for (const match of matches) {
              const teams = match.teams || {};
              const result = match.result || {};
              const team1 = teams.team_1?.name || 'Time 1';
              const team2 = teams.team_2?.name || 'Time 2';
              
              console.log(`            ⚽ ${team1} ${result.pts1 || 0} x ${result.pts2 || 0} ${team2} [${match.status}]`);
              
              // Update or create the match in Firestore
              // Find existing match by copafacilId or create new
              const matchRef = db.collection('campeonatos').doc(t.fsId)
                .collection('partidas').doc(match.id);
              
              const matchData = {
                campeonatoId: t.fsId,
                copafacilId: match.id,
                titulo: match.title || `${team1} x ${team2}`,
                timeANome: team1,
                timeBNome: team2,
                timeAId: teams.team_1?.id || null,
                timeBId: teams.team_2?.id || null,
                timeAFoto: teams.team_1?.photo || null,
                timeBFoto: teams.team_2?.photo || null,
                placarA: result.pts1 || 0,
                placarB: result.pts2 || 0,
                penaltiA: result.penalt1 || null,
                penaltiB: result.penalt2 || null,
                status: match.status === 'Encerrado' ? 'encerrada' : 
                        match.status === 'Em Andamento' ? 'emAndamento' : 
                        match.status === 'Agendado' ? 'agendada' : match.status,
                faseId: stage.id,
                faseTitulo: stage.title,
                rodadaId: round.id,
                rodadaTitulo: round.title,
                local: match.location || match.local || null,
                dataHora: match.date || match.dateTime || null,
                atualizadoViaCopafacilApi: true,
                atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
              };
              
              // Merge to preserve existing data
              await matchRef.set(matchData, { merge: true });
            }
          }
        }
      }
    }
    
    // 2. TEAMS (equipes)
    console.log('\n2️⃣  Equipes...');
    const teamsR = await cfApi(`/tournament/${t.cfId}/teams`);
    if (teamsR.data?.teams?.length > 0) {
      console.log(`   ${teamsR.data.teams.length} equipes`);
      for (const team of teamsR.data.teams) {
        console.log(`   🏟️  ${team.name}`);
        
        // Update team in Firestore
        if (team.id) {
          const teamRef = db.collection('campeonatos').doc(t.fsId)
            .collection('times').doc(team.id);
          await teamRef.set({
            nome: team.name,
            logoUrl: team.photo || null,
            atualizadoViaCopafacilApi: true,
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      }
    } else {
      console.log('   (nenhuma equipe retornada pela API)');
    }
    
    // 3. RANKINGS (artilharia, assistências, penalidades)
    console.log('\n3️⃣  Rankings...');
    const rankingsR = await cfApi(`/tournament/${t.cfId}/rankings`);
    const rankings = rankingsR.data || [];
    console.log(`   ${rankings.length} tipos de ranking`);
    
    for (const ranking of rankings) {
      const rankDataR = await cfApi(`/tournament/${t.cfId}/rankings/${ranking.id}`);
      const rankData = rankDataR.data;
      
      if (rankData?.players?.length > 0) {
        console.log(`   🏆 ${ranking.title1}: ${rankData.players.length} jogadores`);
        
        // Show top 5
        rankData.players.slice(0, 5).forEach(p => {
          console.log(`      ${p.position}. ${p.name} (${p.teamName}) - ${p.data?.join(', ')}`);
        });
        
        // Save ranking to Firestore
        const rankRef = db.collection('campeonatos').doc(t.fsId)
          .collection('rankings').doc(ranking.id);
        await rankRef.set({
          tipo: ranking.id,
          titulo: ranking.title1,
          subtitulo: ranking.title2 || '',
          header: rankData.header || ranking.headers || [],
          jogadores: rankData.players.map(p => ({
            nome: p.name,
            apelido: p.nickName || null,
            posicao: p.position,
            fotoUrl: p.photo || null,
            timeNome: p.teamName,
            timeId: p.teamId,
            timeFoto: p.teamPhoto || null,
            jogadorId: p.playerId,
            dados: p.data || [],
          })),
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`      ✅ Ranking salvo no Firestore`);
      }
    }
    
    // 4. GALLERY (galeria de fotos/vídeos)
    console.log('\n4️⃣  Galeria...');
    const galleryR = await cfApi(`/tournament/${t.cfId}/gallery?max=100`);
    const gallery = galleryR.data || [];
    console.log(`   ${gallery.length} mídias`);
    
    if (gallery.length > 0) {
      gallery.slice(0, 3).forEach(m => {
        console.log(`   📸 ${m.leg?.substring(0, 60)}...`);
      });
      
      // Save gallery to Firestore
      const galleryRef = db.collection('campeonatos').doc(t.fsId)
        .collection('galeria');
      
      for (const media of gallery) {
        await galleryRef.doc(media.id).set({
          legenda: media.leg || '',
          url: media.url || '',
          link: media.link || null,
          dataCriacao: media.creation_date || null,
          atualizadoViaCopafacilApi: true,
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      console.log(`   ✅ ${gallery.length} mídias salvas no Firestore`);
    }
    
    // 5. PLAYERS (jogadores) - need team IDs first
    console.log('\n5️⃣  Jogadores...');
    
    // Get player keys first
    const keysR = await cfApi(`/tournament/${t.cfId}/players/keys`);
    const playerKeys = keysR.data?.header || [];
    console.log(`   Chaves disponíveis: ${playerKeys.map(k => k.key).join(', ')}`);
    
    // Get all teams from Firestore to get their IDs
    const teamsSnap = await db.collection('campeonatos').doc(t.fsId)
      .collection('times').get();
    const teamIds = teamsSnap.docs.map(d => d.id);
    
    if (teamIds.length > 0 && playerKeys.length > 0) {
      // Build query params
      const keyParams = playerKeys.map(k => `key=${k.key}`).join('&');
      const teamParams = teamIds.map(id => `team=${id}`).join('&');
      
      const playersR = await cfApi(`/tournament/${t.cfId}/players?${keyParams}&${teamParams}&staff=true`);
      if (playersR.data?.players?.length > 0) {
        console.log(`   ${playersR.data.players.length} jogadores`);
        playersR.data.players.slice(0, 5).forEach(p => {
          console.log(`      👤 ${p.name} (${p.team})`);
        });
        
        // Save player report to Firestore
        const playerReportRef = db.collection('campeonatos').doc(t.fsId)
          .collection('relatorio_jogadores').doc('geral');
        await playerReportRef.set({
          header: playersR.data.header || [],
          jogadores: playersR.data.players,
          totalJogadores: playersR.data.players.length,
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`   ✅ Relatório de jogadores salvo`);
      }
    } else {
      console.log(`   (${teamIds.length} times no Firestore, ${playerKeys.length} chaves na API)`);
    }
  }

  console.log('\n\n═══════════════════════════════════════════════');
  console.log('  ✅ SINCRONIZAÇÃO CONCLUÍDA!');
  console.log('═══════════════════════════════════════════════');
  
  process.exit(0);
}

main().catch(e => {
  console.error('❌ Erro fatal:', e.message);
  process.exit(1);
});
