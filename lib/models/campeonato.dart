import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusCampeonato { inscricoesAbertas, emAndamento, encerrado, cancelado }

enum EsporteCampeonato { futebol, futsal, basquete, volei, handebol, outro }

class Campeonato {
  final String id;
  final String nome;
  final String descricao;
  final EsporteCampeonato esporte;
  final StatusCampeonato status;
  final String organizadorId;
  final String organizadorNome;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final String? local;
  final String? logoUrl;
  final List<String> categorias;
  final int maxTimes;
  final List<String> patrocinadores;
  final DateTime criadoEm;

  Campeonato({
    required this.id,
    required this.nome,
    this.descricao = '',
    required this.esporte,
    required this.status,
    required this.organizadorId,
    required this.organizadorNome,
    this.dataInicio,
    this.dataFim,
    this.local,
    this.logoUrl,
    this.categorias = const [],
    this.maxTimes = 16,
    this.patrocinadores = const [],
    required this.criadoEm,
  });

  String get esporteLabel {
    switch (esporte) {
      case EsporteCampeonato.futebol:
        return 'Futebol';
      case EsporteCampeonato.futsal:
        return 'Futsal';
      case EsporteCampeonato.basquete:
        return 'Basquete';
      case EsporteCampeonato.volei:
        return 'Vôlei';
      case EsporteCampeonato.handebol:
        return 'Handebol';
      case EsporteCampeonato.outro:
        return 'Outro';
    }
  }

  String get statusLabel {
    switch (status) {
      case StatusCampeonato.inscricoesAbertas:
        return 'Inscrições Abertas';
      case StatusCampeonato.emAndamento:
        return 'Em Andamento';
      case StatusCampeonato.encerrado:
        return 'Encerrado';
      case StatusCampeonato.cancelado:
        return 'Cancelado';
    }
  }

  String get esporteEmoji {
    switch (esporte) {
      case EsporteCampeonato.futebol:
        return '⚽';
      case EsporteCampeonato.futsal:
        return '⚽';
      case EsporteCampeonato.basquete:
        return '🏀';
      case EsporteCampeonato.volei:
        return '🏐';
      case EsporteCampeonato.handebol:
        return '🤾';
      case EsporteCampeonato.outro:
        return '🏆';
    }
  }

  factory Campeonato.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Campeonato(
      id: doc.id,
      nome: data['nome'] ?? '',
      descricao: data['descricao'] ?? '',
      esporte: EsporteCampeonato.values.firstWhere(
        (e) => e.name == (data['esporte'] ?? 'futebol'),
        orElse: () => EsporteCampeonato.futebol,
      ),
      status: StatusCampeonato.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'inscricoesAbertas'),
        orElse: () => StatusCampeonato.inscricoesAbertas,
      ),
      organizadorId: data['organizadorId'] ?? '',
      organizadorNome: data['organizadorNome'] ?? '',
      dataInicio: data['dataInicio'] != null
          ? (data['dataInicio'] as Timestamp).toDate()
          : null,
      dataFim: data['dataFim'] != null
          ? (data['dataFim'] as Timestamp).toDate()
          : null,
      local: data['local'],
      logoUrl: data['logoUrl'],
      categorias: List<String>.from(data['categorias'] ?? []),
      maxTimes: data['maxTimes'] ?? 16,
      patrocinadores: List<String>.from(data['patrocinadores'] ?? []),
      criadoEm: data['criadoEm'] != null
          ? (data['criadoEm'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'descricao': descricao,
      'esporte': esporte.name,
      'status': status.name,
      'organizadorId': organizadorId,
      'organizadorNome': organizadorNome,
      'dataInicio':
          dataInicio != null ? Timestamp.fromDate(dataInicio!) : null,
      'dataFim': dataFim != null ? Timestamp.fromDate(dataFim!) : null,
      'local': local,
      'logoUrl': logoUrl,
      'categorias': categorias,
      'maxTimes': maxTimes,
      'patrocinadores': patrocinadores,
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }
}
