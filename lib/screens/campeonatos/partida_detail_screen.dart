import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:tvi_news/models/partida.dart';
import 'package:tvi_news/models/jogador.dart';
import 'package:tvi_news/services/partidas_service.dart';
import 'package:tvi_news/services/times_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

import 'package:share_plus/share_plus.dart';
import 'package:tvi_news/services/sumula_pdf_service.dart';
import 'package:tvi_news/screens/arbitro/sumula_screen.dart';
import 'package:tvi_news/services/auth_service.dart';
import 'package:tvi_news/models/usuario.dart';

class PartidaDetailScreen extends StatefulWidget {
  final String campeonatoId;
  final String partidaId;

  const PartidaDetailScreen({
    super.key,
    required this.campeonatoId,
    required this.partidaId,
  });

  @override
  State<PartidaDetailScreen> createState() => _PartidaDetailScreenState();
}

class _PartidaDetailScreenState extends State<PartidaDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const List<String> _abas = ['Lances', 'Escalação', 'Informações'];

  Usuario? _usuarioAtual;
  // Mostra o botão para todos os usuários — validação de permissão é feita na SumulaScreen
  bool get _podeEditarSumula => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _abas.length, vsync: this);
    _verificarUsuario();
  }

  Future<void> _verificarUsuario() async {
    final u = await AuthService.instance.usuarioAtual;
    if (mounted) setState(() => _usuarioAtual = u);
  }

  void _abrirSumula(Partida partida) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SumulaScreen(
          campeonatoId: widget.campeonatoId,
          partidaId: partida.id,
          arbitroId: _usuarioAtual?.id ?? 'arbitro',
          partidaInicial: partida,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _compartilharResultado(Partida partida) async {
    final placar = partida.placarA != null && partida.placarB != null
        ? '${partida.timeANome} ${partida.placarA} x ${partida.placarB} ${partida.timeBNome}'
        : '${partida.timeANome} vs ${partida.timeBNome}';

    final dataStr = partida.dataHora != null
        ? DateFormat("dd/MM/yyyy • HH'h'mm", 'pt_BR').format(partida.dataHora!)
        : 'Data a definir';

    final statusStr = partida.status == StatusPartida.encerrada
        ? '🏆 RESULTADO FINAL'
        : partida.status == StatusPartida.emAndamento
            ? '🔴 AO VIVO'
            : '📅 PRÓXIMO JOGO';

    final texto = '''
$statusStr
⚽ $placar
📍 Local: ${partida.local ?? "A definir"}
⏰ $dataStr

Acompanhe ao vivo pelo App TVI News Esportes! 📺📲
#TVINews #EsporteLocal #Futsal #Futebol
''';

    await SharePlus.instance.share(
      ShareParams(
        text: texto,
        subject: 'Resultado: $placar',
      ),
    );
  }

  Future<void> _gerarSumulaPdf(Partida partida) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gerando súmula em PDF...'),
          duration: Duration(seconds: 1),
        ),
      );

      final jogadoresA = await TimesService.instance
          .getJogadores(widget.campeonatoId, partida.timeAId)
          .first;
      final jogadoresB = await TimesService.instance
          .getJogadores(widget.campeonatoId, partida.timeBId)
          .first;
      final lances = await PartidasService.instance
          .getLances(widget.campeonatoId, partida.id)
          .first;

      await SumulaPdfService.instance.imprimirOuCompartilharSumula(
        partida: partida,
        campeonatoNome: 'Copa TVitapê 2025',
        jogadoresTimeA: jogadoresA,
        jogadoresTimeB: jogadoresB,
        lances: lances,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar súmula: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Partida?>(
      stream: PartidasService.instance
          .getPartida(widget.campeonatoId, widget.partidaId),
      builder: (context, snap) {
        final partida = snap.data;

        return Scaffold(
          backgroundColor: AppTheme.bgPrimary,
          appBar: _buildAppBar(partida),
          body: Column(
            children: [
              // Hero de placar
              _HeroPlacar(partida: partida),
              // TabBar
              Container(
                color: AppTheme.bgSecondary,
                child: TabBar(
                  controller: _tabController,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
                  labelColor: AppTheme.accentOrange,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.accentOrange,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  tabs: _abas.map((a) => Tab(text: a)).toList(),
                ),
              ),
              // Conteúdo das abas
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    AbaLances(
                      campeonatoId: widget.campeonatoId,
                      partidaId: widget.partidaId,
                      partida: partida,
                    ),
                    AbaEscalacao(
                      campeonatoId: widget.campeonatoId,
                      partida: partida,
                    ),
                    _AbaInformacoes(partida: partida),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: (_podeEditarSumula && partida != null)
              ? Container(
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.bgSecondary,
                  child: SafeArea(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note, color: Colors.white, size: 24),
                        label: Text(
                          'ABRIR SÚMULA DIGITAL DO ÁRBITRO',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () => _abrirSumula(partida),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  AppBar _buildAppBar(Partida? partida) {
    Color badgeColor;
    String badgeLabel;

    switch (partida?.status) {
      case StatusPartida.emAndamento:
        badgeColor = Colors.green;
        badgeLabel = 'Em Andamento';
        break;
      case StatusPartida.encerrada:
        badgeColor = AppTheme.textSecondary;
        badgeLabel = 'Encerrada';
        break;
      case StatusPartida.agendada:
        badgeColor = AppTheme.accentBlue;
        badgeLabel = 'Agendada';
        break;
      default:
        badgeColor = AppTheme.textMuted;
        badgeLabel = 'Partida';
    }

    return AppBar(
      backgroundColor: AppTheme.bgPrimary,
      iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      title: Text(
        'Partida',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      actions: [
        if (partida != null) ...[
          if (_podeEditarSumula)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: AppTheme.accentOrange, size: 26),
              tooltip: 'Súmula do Árbitro',
              onPressed: () => _abrirSumula(partida),
            ),
          // Compartilhar resultado
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Compartilhar Resultado',
            onPressed: () => _compartilharResultado(partida),
          ),
          // Gerar/Imprimir Súmula em PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: AppTheme.accentOrange),
            tooltip: 'Súmula Oficial em PDF',
            onPressed: () => _gerarSumulaPdf(partida),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor, width: 1),
            ),
            child: Text(
              badgeLabel,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
      ],
      elevation: 0,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO PLACAR
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroPlacar extends StatelessWidget {
  final Partida? partida;
  const _HeroPlacar({this.partida});

  Color _avatarColor(String nome) {
    const palette = [
      Color(0xFF1E63C8),
      Color(0xFFFF6B00),
      Color(0xFF6B2CB3),
      Color(0xFF009688),
      Color(0xFFE91E63),
      Color(0xFF607D8B),
    ];
    if (nome.isEmpty) return palette[0];
    return palette[nome.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final timeANome = partida?.timeANome ?? '—';
    final timeBNome = partida?.timeBNome ?? '—';
    final placar = partida?.placarTexto ?? '– x –';
    final isAoVivo = partida?.status == StatusPartida.emAndamento;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
        ),
      ),
      child: Column(
        children: [
          // Badge AO VIVO
          if (isAoVivo) ...[
            _PulsatingLiveBadge(),
            const SizedBox(height: 10),
          ],
          // Times + placar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Time A
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _avatarColor(timeANome),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (partida?.timeALogo != null && partida!.timeALogo!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: partida!.timeALogo!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  timeANome.isNotEmpty ? timeANome[0].toUpperCase() : '?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                timeANome.isNotEmpty ? timeANome[0].toUpperCase() : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeANome,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Placar central
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  placar,
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: isAoVivo ? Colors.green : AppTheme.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
              ),
              // Time B
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _avatarColor(timeBNome),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (partida?.timeBLogo != null && partida!.timeBLogo!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: partida!.timeBLogo!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  timeBNome.isNotEmpty ? timeBNome[0].toUpperCase() : '?',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                timeBNome.isNotEmpty ? timeBNome[0].toUpperCase() : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeBNome,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Badge pulsante AO VIVO ────────────────────────────────────────────────────

class _PulsatingLiveBadge extends StatefulWidget {
  @override
  State<_PulsatingLiveBadge> createState() => _PulsatingLiveBadgeState();
}

class _PulsatingLiveBadgeState extends State<_PulsatingLiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accentRed.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentRed, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 8, color: AppTheme.accentRed),
            const SizedBox(width: 5),
            Text(
              'AO VIVO',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentRed,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA LANCES
// ═══════════════════════════════════════════════════════════════════════════════

class AbaLances extends StatelessWidget {
  final String campeonatoId;
  final String partidaId;
  final Partida? partida;

  const AbaLances({
    super.key,
    required this.campeonatoId,
    required this.partidaId,
    this.partida,
  });

  Color? _corLinha(TipoLance tipo) {
    switch (tipo) {
      case TipoLance.gol:
      case TipoLance.golContra:
        return Colors.green.withOpacity(0.12);
      case TipoLance.cartaoVermelho:
        return AppTheme.accentRed.withOpacity(0.12);
      case TipoLance.cartaoAmarelo:
        return const Color(0xFFFFC107).withOpacity(0.10);
      default:
        return null;
    }
  }

  Widget _buildLanceIcon(Lance lance) {
    if (lance.tipo == TipoLance.cartaoAmarelo) {
      return Container(
        width: 14,
        height: 19,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD600),
          borderRadius: BorderRadius.circular(2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );
    }
    if (lance.tipo == TipoLance.cartaoVermelho) {
      return Container(
        width: 14,
        height: 19,
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );
    }
    if (lance.tipo == TipoLance.cartaoAzul) {
      return Container(
        width: 14,
        height: 19,
        decoration: BoxDecoration(
          color: const Color(0xFF1E88E5),
          borderRadius: BorderRadius.circular(2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );
    }
    return Text(
      lance.tipoEmoji,
      style: const TextStyle(fontSize: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lance>>(
      stream: PartidasService.instance.getLances(campeonatoId, partidaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentOrange),
          );
        }

        final lances = snap.data ?? [];
        final isAoVivo = partida?.status == StatusPartida.emAndamento;

        if (lances.isEmpty) {
          if (isAoVivo) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsatingLiveBadge(),
                  const SizedBox(height: 20),
                  Text(
                    'PARTIDA EM ANDAMENTO',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aguardando primeiros lances...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          final isEncerrada = partida?.status == StatusPartida.encerrada;
          if (isEncerrada) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Partida Encerrada',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Os lances minuto a minuto não foram registrados nesta partida.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: Text(
              '⏳ Aguardando início da partida...',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: lances.length,
          itemBuilder: (context, i) {
            final lance = lances[i];
            final corBg = _corLinha(lance.tipo);
            final jogador = lance.jogadorNome ?? '';

            return Container(
              color: corBg,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Ícone tipo (cartão retangular realista ou emoji da bola)
                  Container(
                    width: 24,
                    alignment: Alignment.center,
                    child: _buildLanceIcon(lance),
                  ),
                  const SizedBox(width: 10),
                  // Minuto
                  SizedBox(
                    width: 36,
                    child: Text(
                      "${lance.minuto}'",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Descrição
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lance.tipoLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (jogador.isNotEmpty)
                          Text(
                            jogador,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        if (lance.descricao != null &&
                            lance.descricao!.isNotEmpty)
                          Text(
                            lance.descricao!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA ESCALAÇÃO
// ═══════════════════════════════════════════════════════════════════════════════

class AbaEscalacao extends StatelessWidget {
  final String campeonatoId;
  final Partida? partida;

  const AbaEscalacao({super.key, required this.campeonatoId, this.partida});

  @override
  Widget build(BuildContext context) {
    if (partida == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentOrange),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _ColunaTimes(
            campeonatoId: campeonatoId,
            timeId: partida!.timeAId,
            timeNome: partida!.timeANome,
          ),
        ),
        Container(width: 1, color: const Color(0xFF2A2A2A)),
        Expanded(
          child: _ColunaTimes(
            campeonatoId: campeonatoId,
            timeId: partida!.timeBId,
            timeNome: partida!.timeBNome,
          ),
        ),
      ],
    );
  }
}

class _ColunaTimes extends StatelessWidget {
  final String campeonatoId;
  final String timeId;
  final String timeNome;

  const _ColunaTimes({
    required this.campeonatoId,
    required this.timeId,
    required this.timeNome,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Jogador>>(
      stream: TimesService.instance.getJogadores(campeonatoId, timeId),
      builder: (context, snap) {
        final jogadores = snap.data ?? [];

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: AppTheme.bgSecondary,
              child: Text(
                timeNome,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: jogadores.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Escalação não informada',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: jogadores.length,
                      itemBuilder: (context, i) {
                        final j = jogadores[i];
                        // Consideramos os primeiros 11 como titulares
                        final isTitular = i < 11;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: isTitular
                                    ? Colors.green
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              if (j.numero != null) ...[
                                SizedBox(
                                  width: 20,
                                  child: Text(
                                    '${j.numero}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accentOrange,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  j.nomeExibicao,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: isTitular
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA INFORMAÇÕES
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaInformacoes extends StatelessWidget {
  final Partida? partida;
  const _AbaInformacoes({this.partida});

  @override
  Widget build(BuildContext context) {
    if (partida == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentOrange),
      );
    }

    final fmt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _InfoTile(
          icon: Icons.calendar_today_outlined,
          label: 'Data e hora',
          value: partida!.dataHora != null
              ? fmt.format(partida!.dataHora!)
              : 'A definir',
        ),
        _InfoTile(
          icon: Icons.location_on_outlined,
          label: 'Local',
          value: partida!.local ?? 'A definir',
        ),
        _InfoTile(
          icon: Icons.person_outline,
          label: 'Árbitro',
          value: partida!.arbitroNome ?? 'Não designado',
        ),
        _InfoTile(
          icon: Icons.flag_outlined,
          label: 'Rodada',
          value: 'Rodada ${partida!.rodada}',
        ),
        _InfoTile(
          icon: Icons.layers_outlined,
          label: 'Fase',
          value: partida!.faseId.isNotEmpty ? partida!.faseId : '—',
        ),
        if (partida!.grupoId != null && partida!.grupoId!.isNotEmpty)
          _InfoTile(
            icon: Icons.group_work_outlined,
            label: 'Grupo',
            value: partida!.grupoId!,
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.accentOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
