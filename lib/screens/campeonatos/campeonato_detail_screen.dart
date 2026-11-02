import 'package:flutter/material.dart';
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

  static const List<String> _abas = [
    'Início',
    'Classificação',
    'Jogos',
    'Artilharia',
    'Times',
    'Fotos',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _abas.length, vsync: this);
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
          appBar: AppBar(
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
              if (_isAdmin && campeonato != null) ...[
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    'Gerar Jogos',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GerarJogosScreen(
                          campeonatoId: campeonato!.id,
                          campeonatoNome: campeonato.nome,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Configurações do Campeonato',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConfiguracoesCampeonatoScreen(
                          campeonato: campeonato!,
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
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
          body: TabBarView(
            controller: _tabController,
            children: [
              _AbaInicio(
                campeonato: campeonato,
                onSelectCategoria: (cat) {
                  setState(() {
                    _categoriaSelecionada = cat;
                  });
                  _tabController.animateTo(2); // Muda para aba Jogos
                },
              ),
              _AbaClassificacao(
                campeonatoId: widget.campeonatoId,
                categoriaSelecionada: _categoriaSelecionada,
                categorias: campeonato?.categorias ?? [],
                onSelectCategoria: (cat) {
                  setState(() {
                    _categoriaSelecionada = cat;
                  });
                },
              ),
              _AbaJogos(
                campeonatoId: widget.campeonatoId,
                categoriaSelecionada: _categoriaSelecionada,
                categorias: campeonato?.categorias ?? [],
                onSelectCategoria: (cat) {
                  setState(() {
                    _categoriaSelecionada = cat;
                  });
                },
              ),
              _AbaArtilharia(campeonatoId: widget.campeonatoId),
              _AbaTimes(
                campeonatoId: widget.campeonatoId,
                organizadorId: campeonato?.organizadorId,
              ),
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
}

// ── Badge de status ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
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

// ═══════════════════════════════════════════════════════════════════════════════
// ABA INÍCIO
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaInicio extends StatelessWidget {
  final Campeonato? campeonato;
  final void Function(String categoria)? onSelectCategoria;

  const _AbaInicio({required this.campeonato, this.onSelectCategoria});

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

  Widget _buildBanner(BuildContext context, Campeonato c) {
    final hasLogo = c.logoUrl != null && c.logoUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasLogo)
              CachedNetworkImage(
                imageUrl: c.logoUrl!.trim(),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppTheme.cardColor,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    _buildDefaultBannerContent(c),
              )
            else
              _buildDefaultBannerContent(c),

            if (hasLogo)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

            if (hasLogo)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  c.nome,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            Positioned(
              top: 14,
              right: 14,
              child: _StatusBadge(
                label: c.statusLabel,
                color: _statusColor(c.status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultBannerContent(Campeonato c) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D2B14),
            Color(0xFF0F1E10),
            Color(0xFF0F0F0F),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 60,
                color: Color(0xFFFFD700),
              ),
              const SizedBox(height: 8),
              Text(
                c.nome,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.bgSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.accentOrange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (campeonato == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accentOrange),
      );
    }

    final c = campeonato!;
    final fmt = DateFormat('dd/MM/yyyy');

    String periodoTexto;
    if (c.dataInicio != null && c.dataFim != null) {
      periodoTexto =
          '${fmt.format(c.dataInicio!)} — ${fmt.format(c.dataFim!)}';
    } else if (c.dataInicio != null) {
      periodoTexto = 'A partir de ${fmt.format(c.dataInicio!)}';
    } else {
      periodoTexto = 'A definir';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(context, c),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'PERÍODO',
                  content: Text(
                    periodoTexto,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(color: Color(0xFF2A2A2A), height: 16),
                _buildInfoItem(
                  icon: Icons.info_outline,
                  label: 'STATUS',
                  content: Text(
                    c.statusLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(c.status),
                    ),
                  ),
                ),
                const Divider(color: Color(0xFF2A2A2A), height: 16),
                _buildInfoItem(
                  icon: Icons.person_outline,
                  label: 'ORGANIZADOR',
                  content: Text(
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
                const Divider(color: Color(0xFF2A2A2A), height: 16),
                _buildInfoItem(
                  icon: Icons.sports_soccer_outlined,
                  label: 'ESPORTE',
                  content: Text(
                    '${c.esporteEmoji} ${c.esporteLabel}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(color: Color(0xFF2A2A2A), height: 16),
                _buildInfoItem(
                  icon: Icons.location_on_outlined,
                  label: 'LOCAL',
                  content: Text(
                    c.local != null && c.local!.trim().isNotEmpty
                        ? c.local!.trim()
                        : 'A definir',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const Divider(color: Color(0xFF2A2A2A), height: 16),
                _buildInfoItem(
                  icon: Icons.label_outline,
                  label: 'CATEGORIAS',
                  content: c.categorias.isEmpty
                      ? Text(
                          'Nenhuma categoria informada',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: c.categorias.map((cat) {
                            return InkWell(
                              onTap: () {
                                if (onSelectCategoria != null) {
                                  onSelectCategoria!(cat);
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgSecondary,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.accentOrange,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cat,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 10,
                                      color: AppTheme.accentOrange,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ÚLTIMAS NOTÍCIAS',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.newspaper_outlined,
                  size: 38,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  'Em breve',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
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
                  child: CircularProgressIndicator(color: AppTheme.accentOrange),
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
                          cor: Colors.green.withOpacity(0.35),
                          label: 'Zona de promoção',
                        ),
                        _LegendaItem(
                          cor: AppTheme.accentRed.withOpacity(0.25),
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
                                rowBg = Colors.green.withOpacity(0.12);
                              } else if (isRebaixamento) {
                                rowBg = AppTheme.accentRed.withOpacity(0.10);
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
    final labels = [
      '#', 'Time', 'P', 'J', 'V', 'E', 'D', 'GP', 'GC', 'SG'
    ];
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
              color:
                  bold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        );

    return TableRow(
      decoration: BoxDecoration(
        color: bg,
        border:
            const Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
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
// ABA JOGOS
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaJogos extends StatelessWidget {
  final String campeonatoId;
  final String categoriaSelecionada;
  final List<String> categorias;
  final void Function(String categoria) onSelectCategoria;

  const _AbaJogos({
    required this.campeonatoId,
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
                  child: CircularProgressIndicator(color: AppTheme.accentOrange),
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = listaCompleta[i];
          final isSelected = cat.toLowerCase() == categoriaSelecionada.toLowerCase();

          return Center(
            child: ChoiceChip(
              label: Text(
                cat,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.accentOrange,
              backgroundColor: AppTheme.cardColor,
              showCheckmark: false,
              side: BorderSide(
                color: isSelected ? AppTheme.accentOrange : const Color(0xFF2E2E2E),
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
        return Colors.green;
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

  @override
  Widget build(BuildContext context) {
    final initialA = partida.timeANome.isNotEmpty
        ? partida.timeANome[0].toUpperCase()
        : '?';
    final initialB = partida.timeBNome.isNotEmpty
        ? partida.timeBNome[0].toUpperCase()
        : '?';

    final categoriaTexto = partida.categoria != null && partida.categoria!.isNotEmpty
        ? partida.categoria!
        : '';
    final grupoTexto = partida.grupoId != null && partida.grupoId!.isNotEmpty
        ? 'Grupo ${partida.grupoId}'
        : '';
    final rodadaNum = partida.rodada > 0 ? 'Rodada ${partida.rodada}' : '';
    final partes = [categoriaTexto, grupoTexto, rodadaNum].where((s) => s.isNotEmpty).toList();
    final rodadaTexto = partes.isNotEmpty ? partes.join(' • ') : 'Jogo';

    final placarTexto = (partida.placarA != null && partida.placarB != null)
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: partida.emAndamento
              ? Border.all(
                  color: AppTheme.accentRed.withOpacity(0.6),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          children: [
            Text(
              rodadaTexto,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor, width: 1),
              ),
              child: Text(
                _statusLabel,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _avatarColor(partida.timeANome),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (partida.timeALogo != null && partida.timeALogo!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: partida.timeALogo!,
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
                                    initialA,
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
                                  initialA,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    placarTexto,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: partida.emAndamento
                          ? AppTheme.accentRed
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _avatarColor(partida.timeBNome),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: (partida.timeBLogo != null && partida.timeBLogo!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: partida.timeBLogo!,
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
                                    initialB,
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
                                  initialB,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
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
            const SizedBox(height: 12),
            Text(
              _formatarDataLocal(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                        color: AppTheme.accentOrange.withOpacity(0.3),
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

// ═══════════════════════════════════════════════════════════════════════════════
// ABA TIMES
// ═══════════════════════════════════════════════════════════════════════════════

class _AbaTimes extends StatelessWidget {
  final String campeonatoId;
  final String? organizadorId;

  const _AbaTimes({required this.campeonatoId, this.organizadorId});

  bool get _isOrganizador {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == organizadorId;
  }

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
    return StreamBuilder<List<Time>>(
      stream: TimesService.instance.getTimes(campeonatoId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentOrange),
          );
        }

        final times = snap.data ?? [];

        return Stack(
          children: [
            times.isEmpty
                ? const _EstadoVazio(
                    icon: Icons.groups_outlined,
                    mensagem: 'Nenhum time inscrito ainda',
                  )
                : GridView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: times.length,
                    itemBuilder: (context, i) {
                      final time = times[i];
                      final initial = time.nome.isNotEmpty
                          ? time.nome[0].toUpperCase()
                          : '?';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _avatarColor(time.nome),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (time.logoUrl != null && time.logoUrl!.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: time.logoUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
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
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        initial,
                                        style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              time.nome,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              time.responsavelNome,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            if (_isOrganizador)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  backgroundColor: AppTheme.accentOrange,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Adicionar time em breve'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    'Adicionar time',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ABA FOTOS
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
