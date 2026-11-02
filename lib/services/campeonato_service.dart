import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tvi_news/models/campeonato.dart';

/// Serviço responsável pelo CRUD de [Campeonato] no Firestore.
/// Os campeonatos são armazenados na coleção `campeonatos`.
class CampeonatoService {
  CampeonatoService._();

  /// Instância singleton do serviço.
  static final CampeonatoService instance = CampeonatoService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Referência à coleção raiz de campeonatos.
  CollectionReference<Map<String, dynamic>> get _colecao =>
      _firestore.collection('campeonatos');

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// Retorna um stream em tempo real com a lista de campeonatos.
  ///
  /// Parâmetros opcionais de filtro:
  /// - [filtroEsporte]: filtra pelo nome do esporte (valor do enum, ex: 'futebol').
  /// - [filtroStatus]: filtra pelo [StatusCampeonato].
  Stream<List<Campeonato>> getCampeonatos({
    String? filtroEsporte,
    StatusCampeonato? filtroStatus,
  }) {
    // Quando há filtro de status, busca sem orderBy para evitar índice composto.
    // A ordenação é feita em memória.
    Query<Map<String, dynamic>> query = _colecao;

    if (filtroStatus != null) {
      query = query.where('status', isEqualTo: filtroStatus.name);
    } else {
      // Sem filtro de status: pode ordenar normalmente
      query = query.orderBy('criadoEm', descending: true);
    }

    if (filtroEsporte != null && filtroEsporte.isNotEmpty) {
      query = query.where('esporte', isEqualTo: filtroEsporte);
    }

    return query.snapshots().map((snapshot) {
      final lista = snapshot.docs
          .map((doc) => Campeonato.fromFirestore(doc))
          .toList();
      // Ordena em memória por criadoEm (mais recente primeiro)
      lista.sort((a, b) {
        if (a.criadoEm != null && b.criadoEm != null) {
          return b.criadoEm!.compareTo(a.criadoEm!);
        }
        return a.nome.compareTo(b.nome);
      });
      return lista;
    });
  }

  // ---------------------------------------------------------------------------
  // Métodos de leitura
  // ---------------------------------------------------------------------------

  /// Busca um campeonato pelo [id].
  /// Retorna [null] se o documento não existir.
  Future<Campeonato?> getCampeonato(String id) async {
    try {
      final doc = await _colecao.doc(id).get();
      if (!doc.exists) return null;
      return Campeonato.fromFirestore(doc);
    } catch (e) {
      throw Exception('Erro ao buscar campeonato: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Métodos de escrita
  // ---------------------------------------------------------------------------

  /// Cria um novo campeonato no Firestore.
  ///
  /// Retorna o ID gerado automaticamente pelo Firestore.
  Future<String> criarCampeonato(Campeonato c) async {
    try {
      final docRef = await _colecao.add(c.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Erro ao criar campeonato: $e');
    }
  }

  /// Atualiza todos os campos de um campeonato existente.
  ///
  /// O [Campeonato.id] deve ser válido e existir no Firestore.
  Future<void> atualizarCampeonato(Campeonato c) async {
    try {
      await _colecao.doc(c.id).update(c.toFirestore());
    } catch (e) {
      throw Exception('Erro ao atualizar campeonato: $e');
    }
  }

  /// Atualiza apenas o status de um campeonato identificado por [id].
  Future<void> atualizarStatus(String id, StatusCampeonato status) async {
    try {
      await _colecao.doc(id).update({'status': status.name});
    } catch (e) {
      throw Exception('Erro ao atualizar status do campeonato: $e');
    }
  }

  /// Remove permanentemente um campeonato pelo [id].
  ///
  /// **Atenção:** esta operação não remove subcoleções (times, partidas, etc.).
  Future<void> deletarCampeonato(String id) async {
    try {
      await _colecao.doc(id).delete();
    } catch (e) {
      throw Exception('Erro ao deletar campeonato: $e');
    }
  }
}
