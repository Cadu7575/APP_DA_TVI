import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tvi_news/models/partida.dart';

/// Serviço responsável pelo gerenciamento de [Partida] e [Lance] no Firestore.
///
/// Estrutura de coleções:
/// - `campeonatos/{campeonatoId}/partidas/{partidaId}`
/// - `campeonatos/{campeonatoId}/partidas/{partidaId}/lances/{lanceId}`
class PartidasService {
  PartidasService._();

  /// Instância singleton do serviço.
  static final PartidasService instance = PartidasService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Referências auxiliares
  // ---------------------------------------------------------------------------

  /// Referência à subcoleção de partidas de um campeonato.
  CollectionReference<Map<String, dynamic>> _partidas(String campeonatoId) =>
      _firestore
          .collection('campeonatos')
          .doc(campeonatoId)
          .collection('partidas');

  /// Referência à subcoleção de lances de uma partida.
  CollectionReference<Map<String, dynamic>> _lances(
    String campeonatoId,
    String partidaId,
  ) =>
      _partidas(campeonatoId).doc(partidaId).collection('lances');

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Retorna um stream em tempo real com a lista de [Partida] de um campeonato.
  ///
  /// Filtros opcionais:
  /// - [faseId]: filtra por fase do campeonato.
  /// - [status]: filtra por [StatusPartida].
  Stream<List<Partida>> getPartidas(
    String campeonatoId, {
    String? faseId,
    StatusPartida? status,
  }) {
    // Usa criadoEm como ordenação padrão (dataHora pode ser nulo em partidas migradas)
    Query<Map<String, dynamic>> query = _partidas(campeonatoId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    if (faseId != null && faseId.isNotEmpty) {
      query = query.where('faseId', isEqualTo: faseId);
    }

    return query.snapshots().map(
          (snap) {
            final partidas = snap.docs.map((d) => Partida.fromFirestore(d)).toList();
            // Ordena em memória: primeiro por dataHora (não-nulo), depois encerradas, depois por id
            partidas.sort((a, b) {
              if (a.dataHora != null && b.dataHora != null) {
                return a.dataHora!.compareTo(b.dataHora!);
              }
              if (a.dataHora != null) return -1;
              if (b.dataHora != null) return 1;
              return a.id.compareTo(b.id);
            });
            return partidas;
          },
        );
  }

  /// Retorna um stream em tempo real de uma [Partida] específica.
  /// Emite [null] se a partida não existir.
  Stream<Partida?> getPartida(String campeonatoId, String partidaId) {
    return _partidas(campeonatoId).doc(partidaId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Partida.fromFirestore(doc);
    });
  }

  /// Retorna um stream em tempo real dos [Lance] de uma partida,
  /// ordenados por minuto e depois por timestamp (em memória para não exigir índice composto no Firestore).
  Stream<List<Lance>> getLances(String campeonatoId, String partidaId) {
    return _lances(campeonatoId, partidaId).snapshots().map((snap) {
      final lances = snap.docs.map((d) => Lance.fromFirestore(d)).toList();
      lances.sort((a, b) {
        final cmpMinuto = a.minuto.compareTo(b.minuto);
        if (cmpMinuto != 0) return cmpMinuto;
        return a.timestamp.compareTo(b.timestamp);
      });
      return lances;
    });
  }

  // ---------------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------------

  /// Helper de normalização de strings para busca inteligente
  static String _normalizarTexto(String? texto) {
    if (texto == null) return '';
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàâãä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòôõö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), ' ')
        .trim();
  }

  /// Verifica se o nome do time casa com o título do vídeo
  static bool _timeCombinaComTitulo(String rawTeamName, String normTitle) {
    final baseName = rawTeamName.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final candidatos = [_normalizarTexto(rawTeamName), _normalizarTexto(baseName)];

    final titleWords = normTitle.split(RegExp(r'\s+'));
    const stopWords = {
      'futsal', 'fc', 'sc', 'futebol', 'clube', 'itape', 'sorocaba',
      'de', 'do', 'da', 'e', 'a', 'o', 'tvi', 'copa'
    };

    for (final normTeam in candidatos) {
      if (normTeam.isEmpty) continue;
      // Match direto se o nome tem tamanho relevante
      if (normTeam.length >= 3 && !stopWords.contains(normTeam) && normTitle.contains(normTeam)) return true;

      final words = normTeam
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 3 && !stopWords.contains(w))
          .toList();

      if (words.isEmpty) continue;

      // Se pelo menos uma das palavras-chave significativas do time estiver no título
      final matched = words.where((w) => titleWords.contains(w) || (w.length >= 4 && normTitle.contains(w))).length;
      if (matched >= 1 && (matched / words.length >= 0.4 || words.length == 1)) return true;
    }

    return false;
  }

  /// Busca de forma inteligente e automática a [Partida] associada a um vídeo do YouTube.
  /// 1. Prioriza correspondência manual por `youtubeVideoId`.
  /// 2. Prioriza partidas [emAndamento] se houver live ativa.
  /// 3. Faz match semântico no título (ambos os times e categoria).
  Future<Partida?> encontrarPartidaPorVideo({
    required String videoId,
    required String videoTitle,
  }) async {
    try {
      final normTitle = _normalizarTexto(videoTitle);
      final snapAll = await _firestore.collectionGroup('partidas').get();

      Partida? melhorPartida;
      int melhorPontuacao = 0;

      for (final doc in snapAll.docs) {
        if (doc.reference.parent.parent?.id == 'Sl47UJ2ixicOki48NdIn') continue;

        final p = Partida.fromFirestore(doc);

        // 1. Se tiver o ID do vídeo vinculado manualmente, retorna direto
        if (p.youtubeVideoId != null && p.youtubeVideoId == videoId) {
          return p;
        }

        final temA = _timeCombinaComTitulo(p.timeANome, normTitle);
        final temB = _timeCombinaComTitulo(p.timeBNome, normTitle);

        int score = 0;
        if (temA && temB) {
          score = 100;
          if (p.status == StatusPartida.emAndamento) score += 100;
          if (p.categoria != null && normTitle.contains(_normalizarTexto(p.categoria))) {
            score += 25;
          }
        } else if (temA || temB) {
          // Se encontrou ao menos um time e a partida está ao vivo
          if (p.status == StatusPartida.emAndamento) {
            score = 80;
          }
        }

        if (score > melhorPontuacao) {
          melhorPontuacao = score;
          melhorPartida = p;
        }
      }

      // Se encontrou match com pontuação relevante
      if (melhorPontuacao >= 80) {
        return melhorPartida;
      }

      // Fallback para transmissão ao vivo se houver alguma partida marcada como emAndamento
      for (final doc in snapAll.docs) {
        if (doc.reference.parent.parent?.id == 'Sl47UJ2ixicOki48NdIn') continue;
        final p = Partida.fromFirestore(doc);
        if (p.status == StatusPartida.emAndamento) {
          return p;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Vincula manualmente um vídeo do YouTube a uma partida
  Future<void> vincularYoutubeVideo(
    String campeonatoId,
    String partidaId,
    String? youtubeVideoId,
  ) async {
    try {
      await _partidas(campeonatoId).doc(partidaId).update({
        'youtubeVideoId': youtubeVideoId,
      });
    } catch (e) {
      throw Exception('Erro ao vincular vídeo: $e');
    }
  }

  /// Busca globalmente todas as partidas com status [StatusPartida.emAndamento].
  ///
  /// Utilizado pela tela "Ao Vivo" para exibir partidas em andamento de qualquer
  /// campeonato. Requer índice composto no Firestore para o campo `status`.
  Future<List<Partida>> getPartidasEmAndamento() async {
    try {
      final snap = await _firestore
          .collectionGroup('partidas')
          .where('status', isEqualTo: StatusPartida.emAndamento.name)
          .get();

      final lista = snap.docs.map((d) => Partida.fromFirestore(d)).toList();
      // Ordena em memória para evitar índice composto
      lista.sort((a, b) {
        if (a.dataHora != null && b.dataHora != null) {
          return a.dataHora!.compareTo(b.dataHora!);
        }
        return 0;
      });
      return lista;
    } catch (e) {
      throw Exception('Erro ao buscar partidas em andamento: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Escrita
  // ---------------------------------------------------------------------------

  /// Cria uma nova [Partida] no Firestore.
  ///
  /// Retorna o ID gerado automaticamente pelo Firestore.
  Future<String> criarPartida(Partida p) async {
    try {
      final docRef = await _partidas(p.campeonatoId).add(p.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Erro ao criar partida: $e');
    }
  }

  /// Atualiza somente o placar de uma partida.
  Future<void> atualizarPlacar(
    String campeonatoId,
    String partidaId,
    int placarA,
    int placarB,
  ) async {
    try {
      await _partidas(campeonatoId).doc(partidaId).update({
        'placarA': placarA,
        'placarB': placarB,
      });
    } catch (e) {
      throw Exception('Erro ao atualizar placar: $e');
    }
  }

  /// Atualiza somente o status de uma partida.
  Future<void> atualizarStatus(
    String campeonatoId,
    String partidaId,
    StatusPartida status,
  ) async {
    try {
      await _partidas(campeonatoId).doc(partidaId).update({
        'status': status.name,
      });
    } catch (e) {
      throw Exception('Erro ao atualizar status da partida: $e');
    }
  }

  /// Permite que um admin edite todos os campos de uma partida.
  ///
  /// Registra o ID do admin ([adminId]) e o momento da edição nos campos
  /// `adminEditouId`, `adminEditouEm` e marca `editadoPorAdmin` como verdadeiro.
  Future<void> atualizarPartidaAdmin(Partida p, String adminId) async {
    try {
      final dados = p.toFirestore()
        ..addAll({
          'editadoPorAdmin': true,
          'adminEditouId': adminId,
          'adminEditouEm': Timestamp.fromDate(DateTime.now()),
        });

      await _partidas(p.campeonatoId).doc(p.id).update(dados);
    } catch (e) {
      throw Exception('Erro ao salvar edição do admin: $e');
    }
  }

  /// Designa um árbitro para uma partida, salvando seu ID e nome.
  Future<void> designarArbitro(
    String campeonatoId,
    String partidaId,
    String arbitroId,
    String arbitroNome,
  ) async {
    try {
      await _partidas(campeonatoId).doc(partidaId).update({
        'arbitroId': arbitroId,
        'arbitroNome': arbitroNome,
      });
    } catch (e) {
      throw Exception('Erro ao designar árbitro: $e');
    }
  }

  /// Remove um lance registrado. Uso exclusivo do Admin.
  Future<void> deletarLance(
    String campeonatoId,
    String partidaId,
    String lanceId,
  ) async {
    try {
      await _lances(campeonatoId, partidaId).doc(lanceId).delete();
    } catch (e) {
      throw Exception('Erro ao remover lance: $e');
    }
  }
}

