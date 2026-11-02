import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tvi_news/models/partida.dart';

class ArbitroService {
  ArbitroService._();
  static final ArbitroService instance = ArbitroService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _lances(
    String campeonatoId,
    String partidaId,
  ) =>
      _firestore
          .collection('campeonatos')
          .doc(campeonatoId)
          .collection('partidas')
          .doc(partidaId)
          .collection('lances');

  CollectionReference<Map<String, dynamic>> _partidas(String campeonatoId) =>
      _firestore
          .collection('campeonatos')
          .doc(campeonatoId)
          .collection('partidas');

  Future<void> iniciarPartida(Partida partida) async {
    try {
      final batch = _firestore.batch();
      final partidaRef = _partidas(partida.campeonatoId).doc(partida.id);
      batch.update(partidaRef, {
        'status': StatusPartida.emAndamento.name,
        'placarA': 0,
        'placarB': 0,
      });
      final lanceRef = _lances(partida.campeonatoId, partida.id).doc();
      batch.set(lanceRef, {
        'partidaId': partida.id,
        'campeonatoId': partida.campeonatoId,
        'tipo': TipoLance.inicioPrimeiroPeriodo.name,
        'jogadorId': null,
        'jogadorNome': null,
        'jogadorSaiId': null,
        'jogadorSaiNome': null,
        'timeId': null,
        'minuto': 0,
        'descricao': 'Início do 1º tempo',
        'registradoPorId': _uid,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
      await batch.commit();
    } catch (e) {
      throw Exception('Erro ao iniciar partida: $e');
    }
  }

  Future<void> encerrarPartida(Partida partida) async {
    try {
      final batch = _firestore.batch();
      final partidaRef = _partidas(partida.campeonatoId).doc(partida.id);
      batch.update(partidaRef, {'status': StatusPartida.encerrada.name});
      final lanceRef = _lances(partida.campeonatoId, partida.id).doc();
      batch.set(lanceRef, {
        'partidaId': partida.id,
        'campeonatoId': partida.campeonatoId,
        'tipo': TipoLance.fimJogo.name,
        'jogadorId': null,
        'jogadorNome': null,
        'jogadorSaiId': null,
        'jogadorSaiNome': null,
        'timeId': null,
        'minuto': 90,
        'descricao': 'Fim do jogo',
        'registradoPorId': _uid,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
      await batch.commit();
    } catch (e) {
      throw Exception('Erro ao encerrar partida: $e');
    }
  }

  Future<void> registrarLance(Lance lance, Partida partida) async {
    try {
      final batch = _firestore.batch();
      final lanceRef = _lances(partida.campeonatoId, partida.id).doc();
      final dados = lance.toFirestore()
        ..['registradoPorId'] = _uid;
      batch.set(lanceRef, dados);
      if (lance.tipo == TipoLance.gol || lance.tipo == TipoLance.golContra) {
        final partidaRef = _partidas(partida.campeonatoId).doc(partida.id);
        final bool isGolContra = lance.tipo == TipoLance.golContra;
        final bool marcaParaA = isGolContra
            ? lance.timeId == partida.timeBId
            : lance.timeId == partida.timeAId;
        if (marcaParaA) {
          batch.update(partidaRef, {'placarA': FieldValue.increment(1)});
        } else {
          batch.update(partidaRef, {'placarB': FieldValue.increment(1)});
        }
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Erro ao registrar lance: $e');
    }
  }

  Future<void> removerLance(
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
