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

/// Tela principal de listagem de campeonatos com filtros e busca.
class CampeonatosScreen extends StatefulWidget {
  const CampeonatosScreen({super.key});

  @override
  State<CampeonatosScreen> createState() => _CampeonatosScreenState();
}

class _CampeonatosScreenState extends State<CampeonatosScreen> {
  // ── Filtros ativos ─────────────────────────────────────────────────────────
  StatusCampeonato? _filtroStatus;
  EsporteCampeonato? _filtroEsporte;
  String _busca = '';

  // ── Busca ──────────────────────────────────────────────────────────────────
  bool _buscaAtiva = false;
  final _buscaCtrl = TextEditingController();

  // ── Auth state ─────────────────────────────────────────────────────────────
  bool _usuarioLogado = false;
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
      setState(() {
        _usuarioLogado = u != null;
        _isAdmin = u?.role == RoleUsuario.admin;
      });
    }
  }

  // ── Helpers de cores por status ────────────────────────────────────────────

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

  // ── Build principal ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: _buildAppBar(),
      floatingActionButton: _isAdmin ? _buildFab() : null,
      body: Column(
        children: [
          // Filtros
          _buildFiltros(),
          // Lista
          Expanded(child: _buildLista()),
        ],
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
          onPressed: () {
            setState(() {
              _buscaAtiva = false;
              _busca = '';
              _buscaCtrl.clear();
            });
          },
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
          tooltip: 'Buscar',
          onPressed: () => setState(() => _buscaAtiva = true),
        ),
      ],
    );
  }

  // ── FilterChips ────────────────────────────────────────────────────────────

  Widget _buildFiltros() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Todos
          _chip(
            label: 'Todos',
            selecionado: _filtroStatus == null && _filtroEsporte == null,
            onTap: () => setState(() {
              _filtroStatus = null;
              _filtroEsporte = null;
            }),
          ),
          const SizedBox(width: 8),
          // Por status
          _chip(
            label: 'Inscrições Abertas',
            selecionado: _filtroStatus == StatusCampeonato.inscricoesAbertas,
            cor: AppTheme.accentOrange,
            onTap: () => setState(() {
              _filtroStatus = StatusCampeonato.inscricoesAbertas;
              _filtroEsporte = null;
            }),
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Em Andamento',
            selecionado: _filtroStatus == StatusCampeonato.emAndamento,
            cor: Colors.green,
            onTap: () => setState(() {
              _filtroStatus = StatusCampeonato.emAndamento;
              _filtroEsporte = null;
            }),
          ),
          const SizedBox(width: 8),
          _chip(
            label: 'Encerrado',
            selecionado: _filtroStatus == StatusCampeonato.encerrado,
            cor: AppTheme.textSecondary,
            onTap: () => setState(() {
              _filtroStatus = StatusCampeonato.encerrado;
              _filtroEsporte = null;
            }),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: selecionado
              ? corEfetiva.withValues(alpha: 0.2)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selecionado ? corEfetiva : Colors.transparent,
            width: 1.5,
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

  // ── Lista ──────────────────────────────────────────────────────────────────

  Widget _buildLista() {
    return StreamBuilder<List<Campeonato>>(
      stream: CampeonatoService.instance.getCampeonatos(
        filtroStatus: _filtroStatus,
        filtroEsporte: _filtroEsporte?.name,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildShimmer();
        }

        if (snap.hasError) {
          return _buildMensagemVazia(
            icone: Icons.error_outline,
            titulo: 'Erro ao carregar',
            subtitulo: 'Verifique sua conexão e tente novamente.',
            corIcone: AppTheme.accentRed,
          );
        }

        var lista = snap.data ?? [];

        // Filtro de busca local
        if (_busca.isNotEmpty) {
          lista = lista
              .where(
                (c) =>
                    c.nome.toLowerCase().contains(_busca) ||
                    c.esporteLabel.toLowerCase().contains(_busca),
              )
              .toList();
        }

        if (lista.isEmpty) {
          return _buildMensagemVazia(
            icone: Icons.emoji_events_outlined,
            titulo: 'Nenhum campeonato encontrado',
            subtitulo: 'Tente mudar os filtros ou criar um novo campeonato.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: lista.length,
          itemBuilder: (ctx, i) => _buildCard(lista[i]),
        );
      },
    );
  }

  Widget _buildCard(Campeonato c) {
    final cor = _corStatus(c.status);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CampeonatoDetailScreen(campeonatoId: c.id),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: cor, width: 4),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nome,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.esporteLabel +
                          (c.local != null && c.local!.isNotEmpty
                              ? ' • ${c.local}'
                              : ''),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (c.dataInicio != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Início: ${_formatarData(c.dataInicio!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Badge status + seta
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.15),
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
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMensagemVazia({
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

  // ── Shimmer de carregamento ────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase,
      highlightColor: AppTheme.shimmerHighlight,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemCount: 3,
        itemBuilder: (context, _) => Container(
          height: 84,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
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
