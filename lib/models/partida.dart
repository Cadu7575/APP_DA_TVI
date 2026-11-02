import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusPartida { agendada, emAndamento, encerrada, adiada, cancelada }

enum TipoLance {
  gol,
  cartaoAmarelo,
  cartaoVermelho,
  cartaoAzul,
  substituicao,
  lesao,
  ocorrencia,
  inicioPrimeiroPeriodo,
  fimPrimeiroPeriodo,
  inicioSegundoPeriodo,
  fimJogo,
  golContra,
  penalti,
}

class Lance {
  final String id;
  final String partidaId;
  final String campeonatoId;
  final TipoLance tipo;
  final String? jogadorId;
  final String? jogadorNome;
  final String? jogadorSaiId;   // para substituições
  final String? jogadorSaiNome;
  final String? timeId;
  final int minuto;
  final String? descricao;
  final String registradoPorId;
  final DateTime timestamp;

  Lance({
    required this.id,
    required this.partidaId,
    required this.campeonatoId,
    required this.tipo,
    this.jogadorId,
    this.jogadorNome,
    this.jogadorSaiId,
    this.jogadorSaiNome,
    this.timeId,
    required this.minuto,
    this.descricao,
    required this.registradoPorId,
    required this.timestamp,
  });

  String get tipoLabel {
    switch (tipo) {
      case TipoLance.gol:
        return 'GOL';
      case TipoLance.cartaoAmarelo:
        return 'CARTÃO AMARELO';
      case TipoLance.cartaoVermelho:
        return 'CARTÃO VERMELHO';
      case TipoLance.cartaoAzul:
        return 'CARTÃO AZUL';
      case TipoLance.substituicao:
        return 'SUBSTITUIÇÃO';
      case TipoLance.lesao:
        return 'LESÃO';
      case TipoLance.ocorrencia:
        return 'OCORRÊNCIA';
      case TipoLance.inicioPrimeiroPeriodo:
        return 'INÍCIO DO 1º TEMPO';
      case TipoLance.fimPrimeiroPeriodo:
        return 'FIM DO 1º TEMPO';
      case TipoLance.inicioSegundoPeriodo:
        return 'INÍCIO DO 2º TEMPO';
      case TipoLance.fimJogo:
        return 'FIM DO JOGO';
      case TipoLance.golContra:
        return 'GOL CONTRA';
      case TipoLance.penalti:
        return 'PÊNALTI';
    }
  }

  String get tipoEmoji {
    switch (tipo) {
      case TipoLance.gol:
      case TipoLance.golContra:
        return '⚽';
      case TipoLance.cartaoAmarelo:
        return '🟡';
      case TipoLance.cartaoVermelho:
        return '🔴';
      case TipoLance.cartaoAzul:
        return '🟦';
      case TipoLance.substituicao:
        return '🔄';
      case TipoLance.lesao:
        return '🤕';
      case TipoLance.ocorrencia:
        return '📋';
      case TipoLance.penalti:
        return '🎯';
      default:
        return '⏱️';
    }
  }

  factory Lance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lance(
      id: doc.id,
      partidaId: data['partidaId'] ?? '',
      campeonatoId: data['campeonatoId'] ?? '',
      tipo: TipoLance.values.firstWhere(
        (e) => e.name == (data['tipo'] ?? 'ocorrencia'),
        orElse: () => TipoLance.ocorrencia,
      ),
      jogadorId: data['jogadorId'],
      jogadorNome: data['jogadorNome'],
      jogadorSaiId: data['jogadorSaiId'],
      jogadorSaiNome: data['jogadorSaiNome'],
      timeId: data['timeId'],
      minuto: data['minuto'] ?? 0,
      descricao: data['descricao'],
      registradoPorId: data['registradoPorId'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'partidaId': partidaId,
      'campeonatoId': campeonatoId,
      'tipo': tipo.name,
      'jogadorId': jogadorId,
      'jogadorNome': jogadorNome,
      'jogadorSaiId': jogadorSaiId,
      'jogadorSaiNome': jogadorSaiNome,
      'timeId': timeId,
      'minuto': minuto,
      'descricao': descricao,
      'registradoPorId': registradoPorId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class Partida {
  final String id;
  final String campeonatoId;
  final String faseId;
  final String? grupoId;
  final String timeAId;
  final String timeANome;
  final String? timeALogo;
  final String timeBId;
  final String timeBNome;
  final String? timeBLogo;
  final int? placarA;
  final int? placarB;
  final StatusPartida status;
  final String? arbitroId;
  final String? arbitroNome;
  final DateTime? dataHora;
  final String? local;
  final int rodada;
  final String? categoria;
  final String? youtubeVideoId;
  final bool editadoPorAdmin;
  final String? adminEditouId;
  final DateTime? adminEditouEm;

  Partida({
    required this.id,
    required this.campeonatoId,
    required this.faseId,
    this.grupoId,
    required this.timeAId,
    required this.timeANome,
    this.timeALogo,
    required this.timeBId,
    required this.timeBNome,
    this.timeBLogo,
    this.placarA,
    this.placarB,
    required this.status,
    this.arbitroId,
    this.arbitroNome,
    this.dataHora,
    this.local,
    this.rodada = 1,
    this.categoria,
    this.youtubeVideoId,
    this.editadoPorAdmin = false,
    this.adminEditouId,
    this.adminEditouEm,
  });

  bool get emAndamento => status == StatusPartida.emAndamento;
  bool get encerrada => status == StatusPartida.encerrada;

  String get placarTexto {
    if (placarA == null || placarB == null) return 'x';
    return '$placarA x $placarB';
  }

  factory Partida.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Partida(
      id: doc.id,
      campeonatoId: data['campeonatoId'] ?? '',
      faseId: data['faseId'] ?? '',
      grupoId: data['grupoId'],
      timeAId: data['timeAId'] ?? '',
      timeANome: data['timeANome'] ?? '',
      timeALogo: data['timeALogo'],
      timeBId: data['timeBId'] ?? '',
      timeBNome: data['timeBNome'] ?? '',
      timeBLogo: data['timeBLogo'],
      placarA: data['placarA'],
      placarB: data['placarB'],
      status: StatusPartida.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'agendada'),
        orElse: () => StatusPartida.agendada,
      ),
      arbitroId: data['arbitroId'],
      arbitroNome: data['arbitroNome'],
      dataHora: data['dataHora'] != null
          ? (data['dataHora'] as Timestamp).toDate()
          : null,
      local: data['local'],
      rodada: data['rodada'] ?? 1,
      categoria: data['categoria'],
      youtubeVideoId: data['youtubeVideoId'],
      editadoPorAdmin: data['editadoPorAdmin'] ?? false,
      adminEditouId: data['adminEditouId'],
      adminEditouEm: data['adminEditouEm'] != null
          ? (data['adminEditouEm'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'campeonatoId': campeonatoId,
      'faseId': faseId,
      'grupoId': grupoId,
      'timeAId': timeAId,
      'timeANome': timeANome,
      'timeALogo': timeALogo,
      'timeBId': timeBId,
      'timeBNome': timeBNome,
      'timeBLogo': timeBLogo,
      'placarA': placarA,
      'placarB': placarB,
      'status': status.name,
      'arbitroId': arbitroId,
      'arbitroNome': arbitroNome,
      'dataHora': dataHora != null ? Timestamp.fromDate(dataHora!) : null,
      'local': local,
      'rodada': rodada,
      'categoria': categoria,
      'youtubeVideoId': youtubeVideoId,
      'editadoPorAdmin': editadoPorAdmin,
      'adminEditouId': adminEditouId,
      'adminEditouEm':
          adminEditouEm != null ? Timestamp.fromDate(adminEditouEm!) : null,
    };
  }
}
