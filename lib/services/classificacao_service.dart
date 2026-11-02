import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tvi_news/models/partida.dart';

// ---------------------------------------------------------------------------
// Estruturas de dados
// ---------------------------------------------------------------------------

/// Representa a classificação de um time em uma fase do campeonato.
class ClassificacaoTime {
  /// ID do time no Firestore.
  final String timeId;

  /// Nome do time.
  final String timeNome;

  /// Pontuação total (vitória = 3pts, empate = 1pt, derrota = 0pt).
  final int pontos;

  /// Total de jogos disputados.
  final int jogos;

  /// Total de vitórias.
  final int vitorias;

  /// Total de empates.
  final int empates;

  /// Total de derrotas.
  final int derrotas;

  /// Gols marcados (pró).
  final int golsPro;

  /// Gols sofridos (contra).
  final int golsContra;

  ClassificacaoTime({
    required this.timeId,
    required this.timeNome,
    required this.pontos,
    required this.jogos,
    required this.vitorias,
    required this.empates,
    required this.derrotas,
    required this.golsPro,
    required this.golsContra,
    this.categoria,
  });

  /// Saldo de gols (golsPro - golsContra). Usado como critério de desempate.
  int get saldoGols => golsPro - golsContra;

  final String? categoria;

  /// Serializa para mapa do Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'timeId': timeId,
      'timeNome': timeNome,
      'pontos': pontos,
      'jogos': jogos,
      'vitorias': vitorias,
      'empates': empates,
      'derrotas': derrotas,
      'golsPro': golsPro,
      'golsContra': golsContra,
      'saldoGols': saldoGols,
      'categoria': categoria,
    };
  }

  /// Cria um [ClassificacaoTime] a partir de um documento do Firestore.
  factory ClassificacaoTime.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassificacaoTime(
      timeId: data['timeId'] ?? doc.id,
      timeNome: data['timeNome'] ?? '',
      pontos: data['pontos'] ?? 0,
      jogos: data['jogos'] ?? 0,
      vitorias: data['vitorias'] ?? 0,
      empates: data['empates'] ?? 0,
      derrotas: data['derrotas'] ?? 0,
      golsPro: data['golsPro'] ?? 0,
      golsContra: data['golsContra'] ?? 0,
      categoria: data['categoria'],
    );
  }
}

/// Representa um jogador no ranking de artilharia do campeonato.
class ArtiglariaItem {
  /// ID do jogador no Firestore.
  final String jogadorId;

  /// Nome do jogador.
  final String jogadorNome;

  /// ID do time ao qual o jogador pertence.
  final String timeId;

  /// Nome do time.
  final String timeNome;

  /// Quantidade de gols marcados.
  final int gols;

  /// Quantidade de cartões amarelos acumulados.
  final int cartoesAmarelos;

  /// Quantidade de cartões vermelhos acumulados.
  final int cartoesVermelhos;

  ArtiglariaItem({
    required this.jogadorId,
    required this.jogadorNome,
    required this.timeId,
    required this.timeNome,
    required this.gols,
    required this.cartoesAmarelos,
    required this.cartoesVermelhos,
  });

  /// Serializa para mapa do Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'jogadorId': jogadorId,
      'jogadorNome': jogadorNome,
      'timeId': timeId,
      'timeNome': timeNome,
      'gols': gols,
      'cartoes_amarelos': cartoesAmarelos,
      'cartoes_vermelhos': cartoesVermelhos,
    };
  }

  /// Cria um [ArtiglariaItem] a partir de um documento do Firestore.
  factory ArtiglariaItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ArtiglariaItem(
      jogadorId: data['jogadorId'] ?? doc.id,
      jogadorNome: data['jogadorNome'] ?? '',
      timeId: data['timeId'] ?? '',
      timeNome: data['timeNome'] ?? '',
      gols: data['gols'] ?? 0,
      cartoesAmarelos: data['cartoes_amarelos'] ?? 0,
      cartoesVermelhos: data['cartoes_vermelhos'] ?? 0,
    );
  }
}

// ---------------------------------------------------------------------------
// Serviço
// ---------------------------------------------------------------------------

/// Serviço responsável pelo cálculo automático de classificação e artilharia.
///
/// Estrutura de coleções:
/// - `campeonatos/{cid}/classificacao/{timeId}` — tabela de classificação
/// - `campeonatos/{cid}/artilharia/{jogadorId}` — ranking de artilharia
class ClassificacaoService {
  ClassificacaoService._();

  /// Instância singleton do serviço.
  static final ClassificacaoService instance = ClassificacaoService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Referências auxiliares
  // ---------------------------------------------------------------------------

  /// Referência à coleção de classificação de um campeonato.
  CollectionReference<Map<String, dynamic>> _classificacao(
          String campeonatoId) =>
      _firestore
          .collection('campeonatos')
          .doc(campeonatoId)
          .collection('classificacao');

  /// Referência à coleção de artilharia de um campeonato.
  CollectionReference<Map<String, dynamic>> _artilharia(String campeonatoId) =>
      _firestore
          .collection('campeonatos')
          .doc(campeonatoId)
          .collection('artilharia');

  /// Referência à subcoleção de partidas de um campeonato.
  CollectionReference<Map<String, dynamic>> _partidas(String campeonatoId) =>
      _firestore
          .collection('campeonatos')
          .doc(campeonatoId)
          .collection('partidas');

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Retorna um stream em tempo real da tabela de classificação de uma fase,
  /// ordenada por pontos (decrescente) e depois por saldo de gols (desempate).
  Stream<List<ClassificacaoTime>> getClassificacao(
    String campeonatoId,
    String faseId,
  ) {
    return _classificacao(campeonatoId)
        .where('faseId', isEqualTo: faseId)
        .snapshots()
        .map((snap) {
      final lista = snap.docs
          .map((d) => ClassificacaoTime.fromFirestore(d))
          .toList();

      // Ordena em memória para evitar a necessidade de índices compostos
      lista.sort((a, b) {
        if (b.pontos != a.pontos) return b.pontos.compareTo(a.pontos);
        if (b.saldoGols != a.saldoGols) return b.saldoGols.compareTo(a.saldoGols);
        return b.golsPro.compareTo(a.golsPro);
      });

      return lista;
    });
  }

  /// Retorna um stream em tempo real do ranking de artilharia do campeonato,
  /// construído a partir dos lances do tipo [TipoLance.gol] de todas as partidas.
  ///
  /// **Nota:** o stream lê da coleção `artilharia/`, que é atualizada pelo
  /// método [recalcularClassificacao]. Para dados em tempo real imediato,
  /// o recálculo deve ser acionado após cada partida encerrada.
  Stream<List<ArtiglariaItem>> getArtilharia(String campeonatoId) {
    return _artilharia(campeonatoId)
        .orderBy('gols', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => ArtiglariaItem.fromFirestore(d)).toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Recálculo de classificação
  // ---------------------------------------------------------------------------

  /// Recalcula toda a classificação de uma fase do campeonato com base nas
  /// partidas encerradas.
  ///
  /// **Fórmula de pontos:** vitória = 3pts, empate = 1pt, derrota = 0pt.
  ///
  /// **Critérios de desempate (em ordem):**
  /// 1. Saldo de gols (golsPro - golsContra)
  /// 2. Gols pró (golsPro)
  /// 3. Confronto direto (implementado como terceiro critério via Firestore)
  ///
  /// Salva os resultados em `campeonatos/{cid}/classificacao/{timeId}`.
  Future<void> recalcularClassificacao(
    String campeonatoId,
    String faseId,
  ) async {
    try {
      // Busca todas as partidas encerradas da fase
      final snap = await _partidas(campeonatoId)
          .where('faseId', isEqualTo: faseId)
          .where('status', isEqualTo: StatusPartida.encerrada.name)
          .get();

      final partidas = snap.docs.map((d) => Partida.fromFirestore(d)).toList();

      // Mapa de acumuladores: timeId → dados da classificação
      final Map<String, _Acumulador> acumuladores = {};

      for (final partida in partidas) {
        final placarA = partida.placarA ?? 0;
        final placarB = partida.placarB ?? 0;

        // Garante que ambos os times existam no mapa
        acumuladores.putIfAbsent(
          partida.timeAId,
          () => _Acumulador(partida.timeAId, partida.timeANome),
        );
        acumuladores.putIfAbsent(
          partida.timeBId,
          () => _Acumulador(partida.timeBId, partida.timeBNome),
        );

        final timeA = acumuladores[partida.timeAId]!;
        final timeB = acumuladores[partida.timeBId]!;

        // Contabiliza gols
        timeA.golsPro += placarA;
        timeA.golsContra += placarB;
        timeB.golsPro += placarB;
        timeB.golsContra += placarA;

        // Contabiliza resultado
        timeA.jogos++;
        timeB.jogos++;

        if (placarA > placarB) {
          // Time A venceu
          timeA.vitorias++;
          timeA.pontos += 3;
          timeB.derrotas++;
        } else if (placarB > placarA) {
          // Time B venceu
          timeB.vitorias++;
          timeB.pontos += 3;
          timeA.derrotas++;
        } else {
          // Empate
          timeA.empates++;
          timeA.pontos++;
          timeB.empates++;
          timeB.pontos++;
        }
      }

      // Ordena a classificação pelos critérios de desempate
      final classificados = acumuladores.values.toList()
        ..sort((a, b) {
          // 1º critério: pontos
          final cmpPontos = b.pontos.compareTo(a.pontos);
          if (cmpPontos != 0) return cmpPontos;
          // 2º critério: saldo de gols
          final cmpSaldo =
              (b.golsPro - b.golsContra).compareTo(a.golsPro - a.golsContra);
          if (cmpSaldo != 0) return cmpSaldo;
          // 3º critério: gols pró
          return b.golsPro.compareTo(a.golsPro);
        });

      // Salva no Firestore usando batch para atomicidade
      final batch = _firestore.batch();
      for (final acc in classificados) {
        final classificacaoTime = ClassificacaoTime(
          timeId: acc.timeId,
          timeNome: acc.timeNome,
          pontos: acc.pontos,
          jogos: acc.jogos,
          vitorias: acc.vitorias,
          empates: acc.empates,
          derrotas: acc.derrotas,
          golsPro: acc.golsPro,
          golsContra: acc.golsContra,
        );

        final ref = _classificacao(campeonatoId).doc(acc.timeId);
        batch.set(
          ref,
          {...classificacaoTime.toFirestore(), 'faseId': faseId},
          SetOptions(merge: false),
        );
      }

      await batch.commit();

      // Recalcula a artilharia do campeonato em seguida
      await _recalcularArtilharia(campeonatoId, partidas);
    } catch (e) {
      throw Exception('Erro ao recalcular classificação: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Recálculo de artilharia (privado)
  // ---------------------------------------------------------------------------

  /// Recalcula o ranking de artilharia lendo os lances das partidas encerradas.
  ///
  /// Contabiliza gols, cartões amarelos e cartões vermelhos por jogador.
  Future<void> _recalcularArtilharia(
    String campeonatoId,
    List<Partida> partidas,
  ) async {
    // Mapa de acumuladores de artilharia: jogadorId → dados
    final Map<String, _AcumuladorArtilharia> acumuladores = {};

    for (final partida in partidas) {
      // Busca os lances de cada partida encerrada
      final lancesSnap = await _partidas(campeonatoId)
          .doc(partida.id)
          .collection('lances')
          .get();

      for (final lanceDoc in lancesSnap.docs) {
        final lance = Lance.fromFirestore(lanceDoc);

        // Ignora lances sem jogador identificado
        if (lance.jogadorId == null || lance.jogadorNome == null) continue;

        acumuladores.putIfAbsent(
          lance.jogadorId!,
          () => _AcumuladorArtilharia(
            jogadorId: lance.jogadorId!,
            jogadorNome: lance.jogadorNome!,
            timeId: lance.timeId ?? '',
            timeNome: '',
          ),
        );

        final acc = acumuladores[lance.jogadorId!]!;

        // Contabiliza o tipo de lance
        switch (lance.tipo) {
          case TipoLance.gol:
            acc.gols++;
            break;
          case TipoLance.cartaoAmarelo:
            acc.cartoesAmarelos++;
            break;
          case TipoLance.cartaoVermelho:
            acc.cartoesVermelhos++;
            break;
          default:
            break;
        }
      }
    }

    // Salva artilharia no Firestore (apenas jogadores com ao menos 1 gol)
    final batch = _firestore.batch();
    for (final acc in acumuladores.values) {
      if (acc.gols == 0) continue;

      final item = ArtiglariaItem(
        jogadorId: acc.jogadorId,
        jogadorNome: acc.jogadorNome,
        timeId: acc.timeId,
        timeNome: acc.timeNome,
        gols: acc.gols,
        cartoesAmarelos: acc.cartoesAmarelos,
        cartoesVermelhos: acc.cartoesVermelhos,
      );

      final ref = _artilharia(campeonatoId).doc(acc.jogadorId);
      batch.set(ref, item.toFirestore(), SetOptions(merge: false));
    }

    await batch.commit();
  }
}

// ---------------------------------------------------------------------------
// Classes auxiliares internas
// ---------------------------------------------------------------------------

/// Acumulador interno para o cálculo de classificação de um time.
class _Acumulador {
  final String timeId;
  final String timeNome;
  int pontos = 0;
  int jogos = 0;
  int vitorias = 0;
  int empates = 0;
  int derrotas = 0;
  int golsPro = 0;
  int golsContra = 0;

  _Acumulador(this.timeId, this.timeNome);
}

/// Acumulador interno para o cálculo de artilharia de um jogador.
class _AcumuladorArtilharia {
  final String jogadorId;
  final String jogadorNome;
  final String timeId;
  final String timeNome;
  int gols = 0;
  int cartoesAmarelos = 0;
  int cartoesVermelhos = 0;

  _AcumuladorArtilharia({
    required this.jogadorId,
    required this.jogadorNome,
    required this.timeId,
    required this.timeNome,
  });
}
