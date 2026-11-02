import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tvi_news/models/foto_campeonato.dart';

export 'package:tvi_news/models/foto_campeonato.dart';

class FotosService {
  FotosService._();

  static final FotosService instance = FotosService._();

  factory FotosService() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _fotosRef(String campeonatoId) =>
      _firestore.collection('campeonatos').doc(campeonatoId).collection('fotos');

  Stream<List<FotoCampeonato>> getFotos(String campeonatoId) {
    return _fotosRef(campeonatoId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FotoCampeonato.fromFirestore(doc))
            .toList());
  }

  Future<void> adicionarFoto({
    required String campeonatoId,
    required String url,
    required String descricao,
    required String enviadoPorId,
    required String enviadoPorNome,
    DateTime? timestamp,
  }) async {
    await _fotosRef(campeonatoId).add({
      'url': url.trim(),
      'descricao': descricao.trim(),
      'enviadoPorId': enviadoPorId,
      'enviadoPorNome': enviadoPorNome,
      'timestamp': timestamp != null
          ? Timestamp.fromDate(timestamp)
          : FieldValue.serverTimestamp(),
    });
  }

  Future<void> removerFoto(String campeonatoId, String fotoId) async {
    await _fotosRef(campeonatoId).doc(fotoId).delete();
  }
}
