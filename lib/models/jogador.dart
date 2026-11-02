import 'package:cloud_firestore/cloud_firestore.dart';

class Jogador {
  final String id;
  final String campeonatoId;
  final String timeId;
  final String nome;
  final String? apelido;
  final int? numero;
  final String? posicao;
  final String? fotoUrl;
  final String? cpf; // usado para validar unicidade no campeonato
  final DateTime criadoEm;

  Jogador({
    required this.id,
    required this.campeonatoId,
    required this.timeId,
    required this.nome,
    this.apelido,
    this.numero,
    this.posicao,
    this.fotoUrl,
    this.cpf,
    required this.criadoEm,
  });

  String get nomeExibicao => apelido?.isNotEmpty == true ? apelido! : nome;

  factory Jogador.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Jogador(
      id: doc.id,
      campeonatoId: data['campeonatoId'] ?? '',
      timeId: data['timeId'] ?? '',
      nome: data['nome'] ?? '',
      apelido: data['apelido'],
      numero: data['numero'],
      posicao: data['posicao'],
      fotoUrl: data['fotoUrl'],
      cpf: data['cpf'],
      criadoEm: data['criadoEm'] != null
          ? (data['criadoEm'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'campeonatoId': campeonatoId,
      'timeId': timeId,
      'nome': nome,
      'apelido': apelido,
      'numero': numero,
      'posicao': posicao,
      'fotoUrl': fotoUrl,
      'cpf': cpf,
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }
}
