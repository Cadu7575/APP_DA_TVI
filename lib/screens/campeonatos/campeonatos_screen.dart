import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tvi_news/models/campeonato.dart';
import 'package:tvi_news/models/usuario.dart';
import 'package:tvi_news/services/auth_service.dart';
import 'package:tvi_news/services/campeonato_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

import 'campeonato_detail_screen.dart';
import 'criar_campeonato_screen.dart';

/// Tela principal de listagem de campeonatos — layout Copa Fácil.
class CampeonatosScreen extends StatefulWidget {
  const CampeonatosScreen({super.key});

  @override
  State<CampeonatosScreen> createState() => _CampeonatosScreenState();
}

class _CampeonatosScreenState extends State<CampeonatosScreen> {
  // ── Filtros ────────────────────────────────────────────────────────────────
  StatusCampeonato? _filtroStatus;
  String _busca = '';

  // ── Busca ──────────────────────────────────────────────────────────────────
  bool _buscaAtiva = false;
  final _buscaCtrl = TextEditingController();

  // ── Auth ───────────────────────────────────────────────────────────────────
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _verificarLogin();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _verificarLogin() async {
    final u = await AuthService.instance.usuarioAtual;
    if (mounted) {
      setState(() => _isAdmin = u?.role == RoleUsuario.admin);
    }
  }

  Color _corStatus(StatusCampeonato s) {
    switch (s) {
      case StatusCampeonato.emAndamento:
        return Colors.green;
      case StatusCampeonato.inscricoesAbertas:
        return AppTheme.accentOrange;
      case StatusCampeonato.encerrado:
        return AppTheme.textSecondary;
      case StatusCampeonato.cancelado:
        return AppTheme.accentRed;
    }
  }

  void _irParaDetalhe(Campeonato c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampeonatoDetailScreen(campeonatoId: c.id),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: _buildAppBar(),
      floatingActionButton: _isAdmin ? _buildFab() : null,
      body: StreamBuilder<List<Campeonato>>(
        stream: CampeonatoService.instance.getCampeonatos(
          filtroStatus: _filtroStatus,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildShimmer();
          }

          if (snap.hasError) {
            return _buildVazio(
              icone: Icons.error_outline,
              titulo: 'Erro ao carregar',
              subtitulo: 'Verifique sua conexão e tente novamente.',
              corIcone: AppTheme.accentRed,
            );
          }

          var lista = snap.data ?? [];

          if (_busca.isNotEmpty) {
            lista = lista
                .where((c) =>
                    c.nome.toLowerCase().contains(_busca) ||
                    c.esporteLabel.toLowerCase().contains(_busca))
                .toList();
          }

          if (lista.isEmpty) {
            return _buildVazio(
              icone: Icons.emoji_events_outlined,
              titulo: 'Nenhum campeonato encontrado',
              subtitulo: 'Tente mudar os filtros ou criar um novo campeonato.',
            );
          }

          // Separar por status para o layout Copa Fácil
          final ativos = lista
              .where((c) =>
                  c.status == StatusCampeonato.emAndamento ||
                  c.status == StatusCampeonato.inscricoesAbertas)
              .toList();
          final outros = lista
              .where((c) =>
                  c.status != StatusCampeonato.emAndamento &&
                  c.status != StatusCampeonato.inscricoesAbertas)
              .toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // ── Barra de busca ─────────────────────────────────────────────
              _buildBuscaBar(),

              // ── Campeonatos que sigo (ativos — carrossel horizontal) ───────
              if (ativos.isNotEmpty) ...[
                _buildSectionHeader('Campeonatos que sigo', ativos.length),
                _buildCarrossel(ativos),
                const SizedBox(height: 8),
              ],

              // ── Filtros de status ──────────────────────────────────────────
              _buildFiltros(),

              // ── Outros campeonatos (encerrados, etc.) ──────────────────────
              if (outros.isNotEmpty) ...[
                _buildSectionHeader('Outros campeonatos', outros.length),
                ...outros.map((c) => _buildCardLista(c)),
              ] else if (ativos.isEmpty) ...[
                _buildVazioInline(),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    if (_buscaAtiva) {
      return AppBar(
        backgroundColor: AppTheme.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => setState(() {
            _buscaAtiva = false;
            _busca = '';
            _buscaCtrl.clear();
          }),
        ),
        title: TextField(
          controller: _buscaCtrl,
          autofocus: true,
          style: GoogleFonts.poppins(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Buscar campeonato...',
            hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _busca = v.toLowerCase()),
        ),
      );
    }

    return AppBar(
      backgroundColor: AppTheme.bgPrimary,
      elevation: 0,
      title: Text(
        'Campeonatos',
        style: GoogleFonts.poppins(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: AppTheme.textPrimary),
          onPressed: () => setState(() => _buscaAtiva = true),
        ),
      ],
    );
  }

  // ── Barra de busca visual (Copa Fácil style) ───────────────────────────────

  Widget _buildBuscaBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: () => setState(() => _buscaAtiva = true),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2E)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buscar campeonatos, organizadores...',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: AppTheme.textSecondary, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header de seção ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String titulo, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titulo,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (count > 2)
            Text(
              'Ver todos →',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppTheme.accentOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  // ── Carrossel horizontal de cards (Copa Fácil style) ──────────────────────

  Widget _buildCarrossel(List<Campeonato> lista) {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: lista.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _buildCardBanner(lista[i]),
      ),
    );
  }

  Widget _buildCardBanner(Campeonato c) {
    final hasLogo = c.logoUrl != null && c.logoUrl!.trim().isNotEmpty;
    final cor = _corStatus(c.status);

    return GestureDetector(
      onTap: () => _irParaDetalhe(c),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem de banner
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Fundo / imagem
                  hasLogo
                      ? CachedNetworkImage(
                          imageUrl: c.logoUrl!.trim(),
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0D2B40), Color(0xFF0F1420)],
                              ),
                            ),
                          ),
                          errorWidget: (ctx, url, err) => _buildBannerDefault(c),
                        )
                      : _buildBannerDefault(c),

                  // Gradiente escuro embaixo
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),

                  // Badge status (ATIVO, etc.)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        c.statusLabel.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  // Logo pequeno no canto inferior esquerdo
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5),
                        color: AppTheme.bgSecondary,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasLogo
                          ? CachedNetworkImage(
                              imageUrl: c.logoUrl!.trim(),
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                c.nome.isNotEmpty
                                    ? c.nome[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentOrange,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Nome + Organizador
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.nome,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined,
                          size: 11, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          c.organizadorNome.isNotEmpty
                              ? c.organizadorNome
                              : c.esporteLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerDefault(Campeonato c) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B40), Color(0xFF152B14), Color(0xFF0F0F14)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.emoji_events_rounded,
          size: 48,
          color: AppTheme.accentOrange.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // ── Filtros de status ──────────────────────────────────────────────────────

  Widget _buildFiltros() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          _chip(
            label: 'Todos',
            selecionado: _filtroStatus == null,
            onTap: () => setState(() => _filtroStatus = null),
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Em Andamento',
            selecionado: _filtroStatus == StatusCampeonato.emAndamento,
            cor: Colors.green,
            onTap: () =>
                setState(() => _filtroStatus = StatusCampeonato.emAndamento),
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Inscrições Abertas',
            selecionado: _filtroStatus == StatusCampeonato.inscricoesAbertas,
            cor: AppTheme.accentOrange,
            onTap: () => setState(
                () => _filtroStatus = StatusCampeonato.inscricoesAbertas),
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Encerrado',
            selecionado: _filtroStatus == StatusCampeonato.encerrado,
            cor: AppTheme.textSecondary,
            onTap: () =>
                setState(() => _filtroStatus = StatusCampeonato.encerrado),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selecionado,
    Color? cor,
    required VoidCallback onTap,
  }) {
    final corEfetiva = cor ?? AppTheme.accentOrange;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado
              ? corEfetiva.withValues(alpha: 0.18)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado ? corEfetiva : const Color(0xFF2A2A2E),
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
            color: selecionado ? corEfetiva : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Card lista (encerrados / outros) ──────────────────────────────────────

  Widget _buildCardLista(Campeonato c) {
    final cor = _corStatus(c.status);
    final hasLogo = c.logoUrl != null && c.logoUrl!.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => _irParaDetalhe(c),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgSecondary,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasLogo
                  ? CachedNetworkImage(
                      imageUrl: c.logoUrl!.trim(),
                      fit: BoxFit.cover,
                      errorWidget: (ctx, url, err) => _buildLogoFallback(c.nome),
                    )
                  : _buildLogoFallback(c.nome),
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.nome,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.organizadorNome.isNotEmpty
                        ? c.organizadorNome
                        : c.esporteLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.dataInicio != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatarData(c.dataInicio!),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Badge + seta
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    c.statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoFallback(String nome) {
    return Center(
      child: Text(
        nome.isNotEmpty ? nome[0].toUpperCase() : '?',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.accentOrange,
        ),
      ),
    );
  }

  // ── Estado vazio ───────────────────────────────────────────────────────────

  Widget _buildVazio({
    required IconData icone,
    required String titulo,
    required String subtitulo,
    Color corIcone = AppTheme.textSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 72, color: corIcone.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              titulo,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitulo,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVazioInline() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 56, color: AppTheme.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Nenhum campeonato encontrado',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Shimmer ────────────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase,
      highlightColor: AppTheme.shimmerHighlight,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de busca
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Header
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              height: 18,
              width: 160,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Carrossel shimmer
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 3,
                separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) => Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CriarCampeonatoScreen()),
      ),
      backgroundColor: AppTheme.accentOrange,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: Text(
        'Criar Campeonato',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Utilitários ────────────────────────────────────────────────────────────

  String _formatarData(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}
