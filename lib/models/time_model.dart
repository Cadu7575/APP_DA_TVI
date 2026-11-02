import 'package:cloud_firestore/cloud_firestore.dart';

class Time {
  final String id;
  final String campeonatoId;
  final String nome;
  final String? logoUrl;
  final String? categoria;
  final String responsavelNome;
  final String? responsavelTelefone;
  final String organizadorId;
  final DateTime criadoEm;

  Time({
    required this.id,
    required this.campeonatoId,
    required this.nome,
    this.logoUrl,
    this.categoria,
    required this.responsavelNome,
    this.responsavelTelefone,
    required this.organizadorId,
    required this.criadoEm,
  });

  factory Time.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Time(
      id: doc.id,
      campeonatoId: data['campeonatoId'] ?? '',
      nome: data['nome'] ?? '',
      logoUrl: data['logoUrl'],
      categoria: data['categoria'],
      responsavelNome: data['responsavelNome'] ?? '',
      responsavelTelefone: data['responsavelTelefone'],
      organizadorId: data['organizadorId'] ?? '',
      criadoEm: data['criadoEm'] != null
          ? (data['criadoEm'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'campeonatoId': campeonatoId,
      'nome': nome,
      'logoUrl': logoUrl,
      'categoria': categoria,
      'responsavelNome': responsavelNome,
      'responsavelTelefone': responsavelTelefone,
      'organizadorId': organizadorId,
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }
}
