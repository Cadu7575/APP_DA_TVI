import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tvi_news/models/time_model.dart';
import 'package:tvi_news/models/jogador.dart';

/// Serviço responsável pelo CRUD de [Time] e [Jogador] no Firestore.
///
/// Estrutura de coleções:
/// - `campeonatos/{campeonatoId}/times/{timeId}`
/// - `campeonatos/{campeonatoId}/times/{timeId}/jogadores/{jogadorId}`
class TimesService {
  TimesService._();

  /// Instância singleton do serviço.
  static final TimesService instance = TimesService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Referências auxiliares
  // ---------------------------------------------------------------------------

  /// Referência à subcoleção de times de um campeonato.
  CollectionReference<Map<String, dynamic>> _times(String campeonatoId) =>
      _firestore.collection('campeonatos').doc(campeonatoId).collection('times');

  /// Referência à subcoleção de jogadores de um time.
  CollectionReference<Map<String, dynamic>> _jogadores(
    String campeonatoId,
    String timeId,
  ) =>
      _times(campeonatoId).doc(timeId).collection('jogadores');

  // ---------------------------------------------------------------------------
  // Streams — Times
  // ---------------------------------------------------------------------------

  /// Retorna um stream em tempo real com a lista de [Time] de um campeonato.
  Stream<List<Time>> getTimes(String campeonatoId) {
    return _times(campeonatoId)
        .orderBy('nome')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Time.fromFirestore(d)).toList());
  }

  // ---------------------------------------------------------------------------
  // Streams — Jogadores
  // ---------------------------------------------------------------------------

  /// Retorna um stream em tempo real com os [Jogador] de um time específico.
  Stream<List<Jogador>> getJogadores(String campeonatoId, String timeId) {
    return _jogadores(campeonatoId, timeId)
        .orderBy('nome')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Jogador.fromFirestore(d)).toList());
  }

  // ---------------------------------------------------------------------------
  // CRUD — Times
  // ---------------------------------------------------------------------------

  /// Adiciona um novo [Time] ao campeonato.
  ///
  /// Retorna o ID gerado automaticamente pelo Firestore.
  Future<String> adicionarTime(Time t) async {
    try {
      final docRef = await _times(t.campeonatoId).add(t.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Erro ao adicionar time: $e');
    }
  }

  /// Atualiza os dados de um [Time] existente.
  Future<void> atualizarTime(Time t) async {
    try {
      await _times(t.campeonatoId).doc(t.id).update(t.toFirestore());
    } catch (e) {
      throw Exception('Erro ao atualizar time: $e');
    }
  }

  /// Remove um time e todos os seus jogadores do campeonato.
  Future<void> removerTime(String campeonatoId, String timeId) async {
    try {
      // Remove todos os jogadores do time antes de remover o time
      final jogadoresSnap =
          await _jogadores(campeonatoId, timeId).get();
      final batch = _firestore.batch();
      for (final doc in jogadoresSnap.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_times(campeonatoId).doc(timeId));
      await batch.commit();
    } catch (e) {
      throw Exception('Erro ao remover time: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // CRUD — Jogadores
  // ---------------------------------------------------------------------------

  /// Adiciona um [Jogador] ao time de um campeonato.
  ///
  /// **Validação de unicidade:** antes de inserir, verifica se já existe um
  /// jogador com o mesmo CPF ou mesmo nome em qualquer outro time do campeonato.
  /// Caso exista, lança [Exception] com mensagem descritiva.
  ///
  /// Retorna o ID gerado automaticamente pelo Firestore.
  Future<String> adicionarJogador(Jogador j) async {
    try {
      // Busca todos os jogadores do campeonato para validação de unicidade
      final todosJogadores =
          await getJogadoresDoCampeonato(j.campeonatoId);

      for (final existente in todosJogadores) {
        // Ignora jogadores do mesmo time (atualização permitida)
        if (existente.timeId == j.timeId) continue;

        // Valida CPF duplicado (se ambos possuem CPF informado)
        final cpfDuplicado = j.cpf != null &&
            j.cpf!.isNotEmpty &&
            existente.cpf != null &&
            existente.cpf!.isNotEmpty &&
            existente.cpf == j.cpf;

        // Valida nome duplicado (comparação sem distinção de maiúsculas)
        final nomeDuplicado = existente.nome.trim().toLowerCase() ==
            j.nome.trim().toLowerCase();

        if (cpfDuplicado || nomeDuplicado) {
          throw Exception(
            'Jogador já está inscrito em outro time neste campeonato.',
          );
        }
      }

      final docRef =
          await _jogadores(j.campeonatoId, j.timeId).add(j.toFirestore());
      return docRef.id;
    } on Exception {
      // Re-lança exceções de negócio sem encapsular
      rethrow;
    } catch (e) {
      throw Exception('Erro ao adicionar jogador: $e');
    }
  }

  /// Remove um [Jogador] de um time.
  Future<void> removerJogador(
    String campeonatoId,
    String timeId,
    String jogadorId,
  ) async {
    try {
      await _jogadores(campeonatoId, timeId).doc(jogadorId).delete();
    } catch (e) {
      throw Exception('Erro ao remover jogador: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Consultas especiais
  // ---------------------------------------------------------------------------

  /// Retorna todos os [Jogador] de todos os times de um campeonato.
  ///
  /// Usado internamente para validação de unicidade, mas também pode ser
  /// utilizado para exibição de listas globais do campeonato.
  Future<List<Jogador>> getJogadoresDoCampeonato(String campeonatoId) async {
    try {
      final timesSnap = await _times(campeonatoId).get();
      final jogadores = <Jogador>[];

      // Consulta paralela para maior eficiência
      final futures = timesSnap.docs.map((timeDoc) async {
        final jogSnap =
            await _jogadores(campeonatoId, timeDoc.id).get();
        return jogSnap.docs.map((d) => Jogador.fromFirestore(d)).toList();
      });

      final resultados = await Future.wait(futures);
      for (final lista in resultados) {
        jogadores.addAll(lista);
      }

      return jogadores;
    } catch (e) {
      throw Exception('Erro ao buscar jogadores do campeonato: $e');
    }
  }
}
