import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'package:tvi_news/models/campeonato.dart';
import 'package:tvi_news/models/partida.dart';
import 'package:tvi_news/models/time_model.dart';
import 'package:tvi_news/services/campeonato_service.dart';
import 'package:tvi_news/services/partidas_service.dart';
import 'package:tvi_news/services/classificacao_service.dart';
import 'package:tvi_news/services/times_service.dart';
import 'package:tvi_news/services/auth_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';
import 'package:tvi_news/screens/campeonatos/partida_detail_screen.dart';
import 'package:tvi_news/screens/campeonatos/gerar_jogos_screen.dart';
import 'package:tvi_news/screens/campeonatos/fotos_campeonato_screen.dart';
import 'package:tvi_news/screens/campeonatos/configuracoes_campeonato_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TELA PRINCIPAL DE DETALHE DO CAMPEONATO — Layout Copa Fácil
// ═══════════════════════════════════════════════════════════════════════════════

class CampeonatoDetailScreen extends StatefulWidget {
  final String campeonatoId;

  const CampeonatoDetailScreen({super.key, required this.campeonatoId});

  @override
  State<CampeonatoDetailScreen> createState() => _CampeonatoDetailScreenState();
}

class _CampeonatoDetailScreenState extends State<CampeonatoDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isAdmin = false;
  String _categoriaSelecionada = 'Todas';

  // 4 abas principais: Início | Categorias | Jogos | Galeria
  static const int _numTabs = 4;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _numTabs, vsync: this);
    _verificarAdmin();
  }

  Future<void> _verificarAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'];
      final adminCheck =
          role == 'admin' || await AuthService.instance.isAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = adminCheck;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Campeonato>>(
      stream: CampeonatoService.instance.getCampeonatos(),
      builder: (context, snap) {
        Campeonato? campeonato;
        try {
          campeonato = snap.data?.firstWhere(
            (c) => c.id == widget.campeonatoId,
          );
        } catch (_) {}

        return Scaffold(
          backgroundColor: AppTheme.bgPrimary,
          appBar: _buildAppBar(campeonato),
          body: TabBarView(
            controller: _tabController,
            children: [
              // 0 — Início
              _AbaInicio(
                campeonato: campeonato,
                isAdmin: _isAdmin,
                onSelectCategoria: (cat) {
                  setState(() => _categoriaSelecionada = cat);
                  _tabController.animateTo(2); // vai para aba Jogos
                },
              ),
              // 1 — Categorias
              _AbaCategorias(
                campeonato: campeonato,
                isAdmin: _isAdmin,
                onSelectCategoria: (cat) {
                  setState(() => _categoriaSelecionada = cat);
                  _tabController.animateTo(2);
                },
              ),
              // 2 — Jogos (com sub-abas: partidas, classificação, artilharia)
              _AbaJogosCompleta(
                campeonatoId: widget.campeonatoId,
                campeonato: campeonato,
                isAdmin: _isAdmin,
                categoriaSelecionada: _categoriaSelecionada,
                categorias: campeonato?.categorias ?? [],
                onSelectCategoria: (cat) =>
                    setState(() => _categoriaSelecionada = cat),
              ),
              // 3 — Galeria
              _AbaFotos(
                campeonatoId: widget.campeonatoId,
                isAdmin: _isAdmin,
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(Campeonato? campeonato) {
    return AppBar(
      backgroundColor: AppTheme.bgPrimary,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      title: Text(
        campeonato?.nome ?? 'Campeonato',
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: AppTheme.textPrimary),
          tooltip: 'Compartilhar',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Compartilhar em breve')),
            );
          },
        ),
        if (_isAdmin && campeonato != null) ...[
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined,
                color: AppTheme.accentOrange),
            tooltip: 'Gerar Jogos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GerarJogosScreen(
                    campeonatoId: campeonato.id,
                    campeonatoNome: campeonato.nome,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ConfiguracoesCampeonatoScreen(campeonato: campeonato),
                ),
              );
            },
          ),
        ],
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
          color: AppTheme.cardColor,
          onSelected: (v) {},
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'info',
              child: Text('Informações',
                  style: GoogleFonts.poppins(color: AppTheme.textPrimary)),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: false,
        labelColor: AppTheme.accentOrange,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.accentOrange,
        indicatorWeight: 2.5,
        dividerColor: const Color(0xFF2A2A2A),
        tabs: const [
          Tab(icon: Icon(Icons.home_outlined, size: 22)),
          Tab(icon: Icon(Icons.list_outlined, size: 22)),
          Tab(icon: Icon(Icons.sports_score_outlined, size: 22)),
          Tab(icon: Icon(Icons.photo_library_outlined, size: 22)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA INÍCIO — Layout Copa Fácil
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaInicio extends StatefulWidget {
  final Campeonato? campeonato;
  final bool isAdmin;
  final void Function(String categoria)? onSelectCategoria;

  const _AbaInicio({
    required this.campeonato,
    required this.isAdmin,
    this.onSelectCategoria,
  });

  @override
  State<_AbaInicio> createState() => _AbaInicioState();
}

class _AbaInicioState extends State<_AbaInicio> {
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(StatusCampeonato status) {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    if (widget.campeonato == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentOrange),
      );
    }

    final c = widget.campeonato!;
    final fmt = DateFormat('dd/MM/yyyy');
    final cor = _statusColor(c.status);

    String periodoTexto;
    if (c.dataInicio != null && c.dataFim != null) {
      periodoTexto =
          '${fmt.format(c.dataInicio!)} — ${fmt.format(c.dataFim!)}';
    } else if (c.dataInicio != null) {
      periodoTexto = 'A partir de ${fmt.format(c.dataInicio!)}';
    } else {
      periodoTexto = 'A definir';
    }

    final hasLogo = c.logoUrl != null && c.logoUrl!.trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner + Logo sobreposto ────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner de fundo
              SizedBox(
                height: 180,
                width: double.infinity,
                child: hasLogo
                    ? CachedNetworkImage(
                        imageUrl: c.logoUrl!.trim(),
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) =>
                            Container(color: const Color(0xFF0D2B40)),
                        errorWidget: (ctx, url, err) =>
                            _buildDefaultBanner(c),
                      )
                    : _buildDefaultBanner(c),
              ),
              // Gradiente no banner
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                    ),
                  ),
                ),
              ),
              // Badge "✓ Seguindo" no canto superior direito
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Seguindo',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Logo circular sobreposto no canto inferior esquerdo do banner
              Positioned(
                bottom: -28,
                left: 16,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.bgPrimary, width: 3),
                    color: AppTheme.bgSecondary,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasLogo
                      ? CachedNetworkImage(
                          imageUrl: c.logoUrl!.trim(),
                          fit: BoxFit.cover,
                          errorWidget: (ctx, url, err) => Center(
                            child: Text(
                              c.nome.isNotEmpty ? c.nome[0].toUpperCase() : '?',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentOrange,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            c.nome.isNotEmpty ? c.nome[0].toUpperCase() : '?',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentOrange,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),

          // ── Espaço para o logo que sai do banner ───────────────────────────
          const SizedBox(height: 36),

          // ── Seguidores / público ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Público · ${c.maxTimes} vagas',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // ── Título grande ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              c.nome,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          if (c.descricao.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                c.descricao,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.accentBlue,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ── Card de informações ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'PERÍODO',
                    child: Text(
                      periodoTexto,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.circle,
                    iconColor: cor,
                    label: 'STATUS',
                    child: Text(
                      c.statusLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cor,
                      ),
                    ),
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.person_outline,
                    label: 'ORGANIZADOR',
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.organizadorNome.isNotEmpty
                                ? c.organizadorNome
                                : 'Não informado',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.open_in_new,
                            size: 14, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    icon: Icons.sports_soccer_outlined,
                    label: 'ESPORTE',
                    child: Text(
                      '${c.esporteEmoji} ${c.esporteLabel}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (c.local != null && c.local!.isNotEmpty) ...[
                    _buildDivider(),
                    _buildInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'LOCAL',
                      child: Text(
                        c.local!.trim(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Categorias ─────────────────────────────────────────────────────
          if (c.categorias.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'CATEGORIAS',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: c.categorias.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            if (widget.onSelectCategoria != null) {
                              widget.onSelectCategoria!(cat);
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.bgSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      cat.isNotEmpty
                                          ? cat[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.accentOrange,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cat.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: AppTheme.textSecondary, size: 18),
                              ],
                            ),
                          ),
                        ),
                        if (i < c.categorias.length - 1)
                          const Divider(
                              height: 1,
                              color: Color(0xFF2A2A2A),
                              indent: 58),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Mensagens ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              'MENSAGENS',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Envie uma mensagem...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_outlined,
                        color: AppTheme.accentOrange, size: 20),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultBanner(Campeonato c) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2B40), Color(0xFF0F1E10), Color(0xFF0F0F0F)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.emoji_events_rounded,
          size: 64,
          color: AppTheme.accentOrange.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 16, color: iconColor ?? AppTheme.accentOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      const Divider(height: 1, color: Color(0xFF2A2A2A), indent: 54);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA CATEGORIAS — Lista clicável estilo Copa Fácil
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaCategorias extends StatelessWidget {
  final Campeonato? campeonato;
  final bool isAdmin;
  final void Function(String categoria) onSelectCategoria;

  const _AbaCategorias({
    required this.campeonato,
    required this.isAdmin,
    required this.onSelectCategoria,
  });

  @override
  Widget build(BuildContext context) {
    if (campeonato == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentOrange),
      );
    }

    final categorias = campeonato!.categorias;

    if (categorias.isEmpty) {
      return _EstadoVazio(
        icon: Icons.list_alt_outlined,
        mensagem: isAdmin
            ? 'Nenhuma categoria criada.\nToque em + para adicionar.'
            : 'Nenhuma categoria registrada ainda.',
      );
    }

    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: categorias.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final cat = categorias[i];
            return GestureDetector(
              onTap: () => onSelectCategoria(cat),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.bgSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          cat.isNotEmpty ? cat[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        cat.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined,
                          color: AppTheme.textSecondary, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: cat));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copiado: $cat',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textSecondary, size: 20),
                  ],
                ),
              ),
            );
          },
        ),
        // FAB para admin
        if (isAdmin)
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: AppTheme.accentOrange,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Adicionar categoria em breve')),
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA JOGOS COMPLETA — com sub-tabs: Partidas | Classificação | Artilharia
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaJogosCompleta extends StatefulWidget {
  final String campeonatoId;
  final Campeonato? campeonato;
  final bool isAdmin;
  final String categoriaSelecionada;
  final List<String> categorias;
  final void Function(String) onSelectCategoria;

  const _AbaJogosCompleta({
    required this.campeonatoId,
    required this.campeonato,
    required this.isAdmin,
    required this.categoriaSelecionada,
    required this.categorias,
    required this.onSelectCategoria,
  });

  @override
  State<_AbaJogosCompleta> createState() => _AbaJogosCompletaState();
}

class _AbaJogosCompletaState extends State<_AbaJogosCompleta>
    with SingleTickerProviderStateMixin {
  late final TabController _subTabCtrl;

  @override
  void initState() {
    super.initState();
    _subTabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs
        Container(
          color: AppTheme.bgPrimary,
          child: TabBar(
            controller: _subTabCtrl,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle:
                GoogleFonts.poppins(fontSize: 12),
            labelColor: AppTheme.accentOrange,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.accentOrange,
            indicatorWeight: 2,
            dividerColor: const Color(0xFF2A2A2A),
            tabs: const [
              Tab(text: 'Partidas'),
              Tab(text: 'Classificação'),
              Tab(text: 'Artilharia'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabCtrl,
            children: [
              _AbaJogos(
                campeonatoId: widget.campeonatoId,
                isAdmin: widget.isAdmin,
                categoriaSelecionada: widget.categoriaSelecionada,
                categorias: widget.categorias,
                onSelectCategoria: widget.onSelectCategoria,
              ),
              _AbaClassificacao(
                campeonatoId: widget.campeonatoId,
                categoriaSelecionada: widget.categoriaSelecionada,
                categorias: widget.categorias,
                onSelectCategoria: widget.onSelectCategoria,
              ),
              _AbaArtilharia(campeonatoId: widget.campeonatoId),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA CLASSIFICAÇÃO
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaClassificacao extends StatelessWidget {
  final String campeonatoId;
  final String categoriaSelecionada;
  final List<String> categorias;
  final void Function(String categoria) onSelectCategoria;

  const _AbaClassificacao({
    required this.campeonatoId,
    required this.categoriaSelecionada,
    required this.categorias,
    required this.onSelectCategoria,
  });

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
    return Column(
      children: [
        if (categorias.isNotEmpty)
          _FiltroCategoriasBar(
            categorias: categorias,
            categoriaSelecionada: categoriaSelecionada,
            onSelectCategoria: onSelectCategoria,
          ),
        Expanded(
          child: StreamBuilder<List<ClassificacaoTime>>(
            stream: ClassificacaoService.instance
                .getClassificacao(campeonatoId, 'geral'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.accentOrange),
                );
              }

              final todosItens = snap.data ?? [];
              final itens = categoriaSelecionada == 'Todas'
                  ? todosItens
                  : todosItens
                      .where((item) =>
                          item.categoria != null &&
                          item.categoria!.toLowerCase() ==
                              categoriaSelecionada.toLowerCase())
                      .toList();

              if (itens.isEmpty) {
                return _EstadoVazio(
                  icon: Icons.table_chart_outlined,
                  mensagem: categoriaSelecionada == 'Todas'
                      ? 'Nenhuma classificação ainda'
                      : 'Nenhuma classificação nesta categoria ($categoriaSelecionada)',
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _LegendaItem(
                          cor: Colors.green.withValues(alpha: 0.35),
                          label: 'Zona de promoção',
                        ),
                        _LegendaItem(
                          cor: AppTheme.accentRed.withValues(alpha: 0.25),
                          label: 'Zona de rebaixamento',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Table(
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FixedColumnWidth(28),
                            1: FlexColumnWidth(2.5),
                            2: FixedColumnWidth(28),
                            3: FixedColumnWidth(28),
                            4: FixedColumnWidth(28),
                            5: FixedColumnWidth(28),
                            6: FixedColumnWidth(28),
                            7: FixedColumnWidth(32),
                            8: FixedColumnWidth(32),
                            9: FixedColumnWidth(32),
                          },
                          children: [
                            _headerRow(),
                            ...itens.asMap().entries.map((e) {
                              final pos = e.key + 1;
                              final item = e.value;
                              final isPromocao = pos <= 2;
                              final isRebaixamento =
                                  itens.length >= 4 && pos >= itens.length - 1;

                              Color? rowBg;
                              if (isPromocao) {
                                rowBg = Colors.green.withValues(alpha: 0.12);
                              } else if (isRebaixamento) {
                                rowBg =
                                    AppTheme.accentRed.withValues(alpha: 0.10);
                              }

                              return _dataRow(pos, item, rowBg, _avatarColor);
                            }),
                          ],
                        ),
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
  }

  TableRow _headerRow() {
    final labels = ['#', 'Time', 'P', 'J', 'V', 'E', 'D', 'GP', 'GC', 'SG'];
    return TableRow(
      decoration: const BoxDecoration(
        color: Color(0xFF252525),
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      children: labels.map((l) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Text(
            l,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
            textAlign: l == 'Time' ? TextAlign.left : TextAlign.center,
          ),
        );
      }).toList(),
    );
  }

  TableRow _dataRow(
    int pos,
    ClassificacaoTime item,
    Color? bg,
    Color Function(String) avatarColorFn,
  ) {
    final initial =
        item.timeNome.isNotEmpty ? item.timeNome[0].toUpperCase() : '?';

    Widget cell(String text, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        );

    return TableRow(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      children: [
        cell('$pos'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: avatarColorFn(item.timeNome),
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.timeNome,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        cell('${item.pontos}', bold: true),
        cell('${item.jogos}'),
        cell('${item.vitorias}'),
        cell('${item.empates}'),
        cell('${item.derrotas}'),
        cell('${item.golsPro}'),
        cell('${item.golsContra}'),
        cell('${item.saldoGols}'),
      ],
    );
  }
}

class _LegendaItem extends StatelessWidget {
  final Color cor;
  final String label;
  const _LegendaItem({required this.cor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, color: cor),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA JOGOS (Partidas)
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaJogos extends StatelessWidget {
  final String campeonatoId;
  final bool isAdmin;
  final String categoriaSelecionada;
  final List<String> categorias;
  final void Function(String categoria) onSelectCategoria;

  const _AbaJogos({
    required this.campeonatoId,
    required this.isAdmin,
    required this.categoriaSelecionada,
    required this.categorias,
    required this.onSelectCategoria,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (categorias.isNotEmpty)
          _FiltroCategoriasBar(
            categorias: categorias,
            categoriaSelecionada: categoriaSelecionada,
            onSelectCategoria: onSelectCategoria,
          ),
        Expanded(
          child: StreamBuilder<List<Partida>>(
            stream: PartidasService.instance.getPartidas(campeonatoId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.accentOrange),
                );
              }

              final todasPartidas = snap.data ?? [];
              final partidas = categoriaSelecionada == 'Todas'
                  ? todasPartidas
                  : todasPartidas
                      .where((p) =>
                          p.categoria != null &&
                          p.categoria!.toLowerCase() ==
                              categoriaSelecionada.toLowerCase())
                      .toList();

              if (partidas.isEmpty) {
                return _EstadoVazio(
                  icon: Icons.sports_outlined,
                  mensagem: categoriaSelecionada == 'Todas'
                      ? 'Nenhum jogo agendado ainda'
                      : 'Nenhum jogo nesta categoria ($categoriaSelecionada)',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: partidas.length,
                itemBuilder: (context, i) => _CardPartida(
                  partida: partidas[i],
                  campeonatoId: campeonatoId,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FiltroCategoriasBar extends StatelessWidget {
  final List<String> categorias;
  final String categoriaSelecionada;
  final void Function(String) onSelectCategoria;

  const _FiltroCategoriasBar({
    required this.categorias,
    required this.categoriaSelecionada,
    required this.onSelectCategoria,
  });

  @override
  Widget build(BuildContext context) {
    final listaCompleta = ['Todas', ...categorias];

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: listaCompleta.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = listaCompleta[i];
          final isSelected =
              cat.toLowerCase() == categoriaSelecionada.toLowerCase();

          return Center(
            child: ChoiceChip(
              label: Text(
                cat,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.accentOrange,
              backgroundColor: AppTheme.cardColor,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected
                    ? AppTheme.accentOrange
                    : const Color(0xFF2E2E2E),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => onSelectCategoria(cat),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CARD PARTIDA — estilo Copa Fácil
// ═══════════════════════════════════════════════════════════════════════════════

class _CardPartida extends StatelessWidget {
  final Partida partida;
  final String campeonatoId;
  const _CardPartida({required this.partida, required this.campeonatoId});

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

  Color get _statusColor {
    switch (partida.status) {
      case StatusPartida.encerrada:
        return AppTheme.textSecondary;
      case StatusPartida.emAndamento:
        return AppTheme.accentRed;
      case StatusPartida.agendada:
        return AppTheme.accentBlue;
      case StatusPartida.adiada:
        return Colors.amber;
      case StatusPartida.cancelada:
        return AppTheme.textMuted;
    }
  }

  String get _statusLabel {
    switch (partida.status) {
      case StatusPartida.encerrada:
        return 'ENCERRADO';
      case StatusPartida.emAndamento:
        return 'AO VIVO';
      case StatusPartida.agendada:
        return 'AGENDADA';
      case StatusPartida.adiada:
        return 'ADIADA';
      case StatusPartida.cancelada:
        return 'CANCELADA';
    }
  }

  String _formatarDataLocal() {
    final partes = <String>[];
    if (partida.dataHora != null) {
      final dateFmt = DateFormat('dd/MM/yyyy');
      final timeFmt = DateFormat('HH:mm');
      partes.add(
        '${dateFmt.format(partida.dataHora!)} ${timeFmt.format(partida.dataHora!)}',
      );
    }
    if (partida.local != null && partida.local!.trim().isNotEmpty) {
      partes.add(partida.local!.trim());
    }
    if (partes.isEmpty) return 'Data e local a definir';
    return partes.join(' • ');
  }

  Widget _buildTeamLogo(String nome, String? logoUrl) {
    final initial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarColor(nome),
      ),
      clipBehavior: Clip.antiAlias,
      child: (logoUrl != null && logoUrl.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Center(
                child: Text(
                  initial,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                initial,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriaTexto =
        partida.categoria != null && partida.categoria!.isNotEmpty
            ? partida.categoria!
            : '';
    final grupoTexto =
        partida.grupoId != null && partida.grupoId!.isNotEmpty
            ? 'Grupo ${partida.grupoId}'
            : '';
    final rodadaNum =
        partida.rodada > 0 ? 'Rodada ${partida.rodada}' : '';
    final partes = [categoriaTexto, grupoTexto, rodadaNum]
        .where((s) => s.isNotEmpty)
        .toList();
    final rodadaTexto = partes.isNotEmpty ? partes.join(' • ') : 'Jogo';

    final placarTexto =
        (partida.placarA != null && partida.placarB != null)
            ? '${partida.placarA} : ${partida.placarB}'
            : '- : -';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PartidaDetailScreen(
              campeonatoId: campeonatoId,
              partidaId: partida.id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: partida.emAndamento
              ? Border.all(
                  color: AppTheme.accentRed.withValues(alpha: 0.6),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          children: [
            // Header da rodada
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF252525),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rodadaTexto.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _statusColor, width: 1),
                    ),
                    child: Text(
                      _statusLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Corpo: times e placar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  // Time A
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(
                            partida.timeANome, partida.timeALogo),
                        const SizedBox(height: 6),
                        Text(
                          partida.timeANome,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      placarTexto,
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: partida.emAndamento
                            ? AppTheme.accentRed
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  // Time B
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(
                            partida.timeBNome, partida.timeBLogo),
                        const SizedBox(height: 6),
                        Text(
                          partida.timeBNome,
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
            ),
            // Local e data
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                _formatarDataLocal(),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA ARTILHARIA
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaArtilharia extends StatelessWidget {
  final String campeonatoId;
  const _AbaArtilharia({required this.campeonatoId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ArtiglariaItem>>(
      stream: ClassificacaoService.instance.getArtilharia(campeonatoId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentOrange),
          );
        }

        final artilheiros = snap.data ?? [];

        if (artilheiros.isEmpty) {
          return const _EstadoVazio(
            icon: Icons.sports_soccer_outlined,
            mensagem: 'Nenhum gol registrado ainda',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: artilheiros.length,
          itemBuilder: (context, i) {
            final a = artilheiros[i];
            final initial =
                a.jogadorNome.isNotEmpty ? a.jogadorNome[0].toUpperCase() : '?';
            final isTop3 = i < 3;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: isTop3
                    ? Border.all(
                        color: AppTheme.accentOrange.withValues(alpha: 0.3),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${i + 1}º',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isTop3
                            ? AppTheme.accentOrange
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.bgSecondary,
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.jogadorNome,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          a.timeNome,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${a.gols}',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                      Text(
                        'gols',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
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

// (ABA TIMES removida — não utilizada na versão atual)

// ═══════════════════════════════════════════════════════════════════════════════
// ABA FOTOS (Galeria)
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaFotos extends StatelessWidget {
  final String campeonatoId;
  final bool isAdmin;

  const _AbaFotos({required this.campeonatoId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return FotosCampeonatoScreen(
      campeonatoId: campeonatoId,
      isAdmin: isAdmin,
      mostrarAppBar: false,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ESTADO VAZIO GENÉRICO
// ═══════════════════════════════════════════════════════════════════════════════

class _EstadoVazio extends StatelessWidget {
  final IconData icon;
  final String mensagem;

  const _EstadoVazio({required this.icon, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              mensagem,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BADGE DE STATUS (mantido para compatibilidade)
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
