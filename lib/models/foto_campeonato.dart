import 'package:cloud_firestore/cloud_firestore.dart';

class FotoCampeonato {
  final String id;
  final String url;
  final String descricao;
  final String enviadoPorId;
  final String enviadoPorNome;
  final DateTime timestamp;

  FotoCampeonato({
    required this.id,
    required this.url,
    required this.descricao,
    required this.enviadoPorId,
    required this.enviadoPorNome,
    required this.timestamp,
  });

  factory FotoCampeonato.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FotoCampeonato(
      id: doc.id,
      url: data['url'] as String? ?? '',
      descricao: data['descricao'] as String? ?? '',
      enviadoPorId: data['enviadoPorId'] as String? ?? '',
      enviadoPorNome: data['enviadoPorNome'] as String? ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'url': url,
      'descricao': descricao,
      'enviadoPorId': enviadoPorId,
      'enviadoPorNome': enviadoPorNome,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
