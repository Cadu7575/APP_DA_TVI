import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tvi_news/models/partida.dart';
import 'package:tvi_news/models/time_model.dart';
import 'package:uuid/uuid.dart';

enum FormatoTorneio {
  pontosCorridos, // Todos contra todos (Turno Único)
  idaEVolta,      // Todos contra todos (Ida e Volta)
  mataMata,       // Eliminatórias simples
}

class GeradorJogosService {
  GeradorJogosService._();
  static final GeradorJogosService instance = GeradorJogosService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  /// Gera e salva no Firestore todas as partidas do torneio automaticamente.
  Future<List<Partida>> gerarEGravarPartidas({
    required String campeonatoId,
    required String faseId,
    required List<Time> times,
    required FormatoTorneio formato,
    required DateTime dataInicio,
    required int intervaloDias,
    String? localPadrao,
  }) async {
    if (times.length < 2) {
      throw Exception('É necessário pelo menos 2 times para gerar partidas.');
    }

    List<Partida> partidasGeradas = [];

    switch (formato) {
      case FormatoTorneio.pontosCorridos:
        partidasGeradas = _gerarRoundRobin(
          campeonatoId: campeonatoId,
          faseId: faseId,
          times: times,
          idaEVolta: false,
          dataInicio: dataInicio,
          intervaloDias: intervaloDias,
          localPadrao: localPadrao,
        );
        break;

      case FormatoTorneio.idaEVolta:
        partidasGeradas = _gerarRoundRobin(
          campeonatoId: campeonatoId,
          faseId: faseId,
          times: times,
          idaEVolta: true,
          dataInicio: dataInicio,
          intervaloDias: intervaloDias,
          localPadrao: localPadrao,
        );
        break;

      case FormatoTorneio.mataMata:
        partidasGeradas = _gerarMataMata(
          campeonatoId: campeonatoId,
          faseId: faseId,
          times: times,
          dataInicio: dataInicio,
          localPadrao: localPadrao,
        );
        break;
    }

    // Salvar em lote (batch) no Firestore
    final batch = _firestore.batch();
    for (final partida in partidasGeradas) {
      final docRef = _firestore
          .collection('campeonatos')
          .doc(campeonatoId)
          .collection('partidas')
          .doc(partida.id);
      batch.set(docRef, partida.toFirestore());
    }

    await batch.commit();
    return partidasGeradas;
  }

  /// Algoritmo padrão de Round-Robin (Círculo de Berger)
  List<Partida> _gerarRoundRobin({
    required String campeonatoId,
    required String faseId,
    required List<Time> times,
    required bool idaEVolta,
    required DateTime dataInicio,
    required int intervaloDias,
    String? localPadrao,
  }) {
    List<Partida> partidas = [];
    List<Time?> listaTimes = List.from(times);

    // Se o número de times for ímpar, adicionamos um 'bye' (folga)
    if (listaTimes.length % 2 != 0) {
      listaTimes.add(null);
    }

    final int numTimes = listaTimes.length;
    final int rodadasTurno = numTimes - 1;
    final int jogosPorRodada = numTimes ~/ 2;

    DateTime dataAtual = dataInicio;

    // Gerar Turno
    for (int rodada = 1; rodada <= rodadasTurno; rodada++) {
      for (int i = 0; i < jogosPorRodada; i++) {
        final timeA = listaTimes[i];
        final timeB = listaTimes[numTimes - 1 - i];

        if (timeA != null && timeB != null) {
          // Alternar mandante para balanceamento
          final bool inverte = (i == 0 && rodada % 2 == 0);
          final mandante = inverte ? timeB : timeA;
          final visitante = inverte ? timeA : timeB;

          partidas.add(Partida(
            id: _uuid.v4(),
            campeonatoId: campeonatoId,
            faseId: faseId,
            timeAId: mandante.id,
            timeANome: mandante.nome,
            timeALogo: mandante.logoUrl,
            timeBId: visitante.id,
            timeBNome: visitante.nome,
            timeBLogo: visitante.logoUrl,
            status: StatusPartida.agendada,
            rodada: rodada,
            dataHora: dataAtual,
            local: localPadrao ?? 'A definir',
          ));
        }
      }

      // Rotacionar lista mantendo o primeiro fixo
      listaTimes.insert(1, listaTimes.removeLast());
      dataAtual = dataAtual.add(Duration(days: intervaloDias));
    }

    // Se for Ida e Volta, duplicamos invertendo mandantes
    if (idaEVolta) {
      final int totalPartidasTurno = partidas.length;
      for (int i = 0; i < totalPartidasTurno; i++) {
        final p = partidas[i];
        dataAtual = p.dataHora!.add(Duration(days: rodadasTurno * intervaloDias));

        partidas.add(Partida(
          id: _uuid.v4(),
          campeonatoId: campeonatoId,
          faseId: faseId,
          timeAId: p.timeBId,
          timeANome: p.timeBNome,
          timeALogo: p.timeBLogo,
          timeBId: p.timeAId,
          timeBNome: p.timeANome,
          timeBLogo: p.timeALogo,
          status: StatusPartida.agendada,
          rodada: p.rodada + rodadasTurno,
          dataHora: dataAtual,
          local: localPadrao ?? 'A definir',
        ));
      }
    }

    return partidas;
  }

  /// Gerador de eliminatórias simples (Mata-mata)
  List<Partida> _gerarMataMata({
    required String campeonatoId,
    required String faseId,
    required List<Time> times,
    required DateTime dataInicio,
    String? localPadrao,
  }) {
    List<Partida> partidas = [];
    final int total = times.length;

    for (int i = 0; i < total; i += 2) {
      if (i + 1 < total) {
        partidas.add(Partida(
          id: _uuid.v4(),
          campeonatoId: campeonatoId,
          faseId: faseId,
          timeAId: times[i].id,
          timeANome: times[i].nome,
          timeALogo: times[i].logoUrl,
          timeBId: times[i + 1].id,
          timeBNome: times[i + 1].nome,
          timeBLogo: times[i + 1].logoUrl,
          status: StatusPartida.agendada,
          rodada: 1,
          dataHora: dataInicio,
          local: localPadrao ?? 'A definir',
        ));
      }
    }

    return partidas;
  }
}
