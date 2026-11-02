import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tvi_news/models/time_model.dart';
import 'package:tvi_news/models/jogador.dart';
import 'package:tvi_news/services/times_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

/// Tela de listagem e gerenciamento dos times de um campeonato.
class TimesScreen extends StatelessWidget {
  final String campeonatoId;
  final String campeonatoNome;
  final bool isOrganizador;

  const TimesScreen({
    super.key,
    required this.campeonatoId,
    required this.campeonatoNome,
    this.isOrganizador = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: Text(
          'Times — $campeonatoNome',
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: StreamBuilder<List<Time>>(
        stream: TimesService.instance.getTimes(campeonatoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.accentOrange));
          }
          final times = snapshot.data ?? [];
          if (times.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.groups_outlined,
                      color: AppTheme.textMuted, size: 64),
                  const SizedBox(height: 16),
                  Text('Nenhum time inscrito ainda',
                      style: GoogleFonts.poppins(
                          color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: times.length,
            itemBuilder: (context, index) {
              final time = times[index];
              return _TimeCard(
                time: time,
                campeonatoId: campeonatoId,
                isOrganizador: isOrganizador,
                onDelete: () => _confirmarRemocao(context, time),
              );
            },
          );
        },
      ),
      floatingActionButton: isOrganizador
          ? FloatingActionButton(
              onPressed: () => _adicionarTime(context),
              backgroundColor: AppTheme.accentOrange,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Future<void> _confirmarRemocao(BuildContext context, Time time) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text('Remover time?',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
            'Remover "${time.nome}" e todos os seus jogadores?',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remover',
                  style: GoogleFonts.poppins(color: AppTheme.accentRed))),
        ],
      ),
    );
    if (ok == true) {
      await TimesService.instance.removerTime(campeonatoId, time.id);
    }
  }

  void _adicionarTime(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final respCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final catCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Adicionar Time',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _campo(nomeCtrl, 'Nome do time *'),
            const SizedBox(height: 10),
            _campo(catCtrl, 'Categoria (ex: Adulto, Sub-20)'),
            const SizedBox(height: 10),
            _campo(respCtrl, 'Responsável / Capitão *'),
            const SizedBox(height: 10),
            _campo(telCtrl, 'Telefone do responsável', isPhone: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (nomeCtrl.text.trim().isEmpty ||
                      respCtrl.text.trim().isEmpty) return;
                  try {
                    await TimesService.instance.adicionarTime(Time(
                      id: '',
                      campeonatoId: campeonatoId,
                      nome: nomeCtrl.text.trim(),
                      categoria: catCtrl.text.trim().isEmpty
                          ? null
                          : catCtrl.text.trim(),
                      responsavelNome: respCtrl.text.trim(),
                      responsavelTelefone: telCtrl.text.trim().isEmpty
                          ? null
                          : telCtrl.text.trim(),
                      organizadorId: '',
                      criadoEm: DateTime.now(),
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(e.toString())));
                    }
                  }
                },
                child: Text('Salvar Time',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label,
      {bool isPhone = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.accentOrange, width: 1.5)),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final Time time;
  final String campeonatoId;
  final bool isOrganizador;
  final VoidCallback onDelete;

  const _TimeCard({
    required this.time,
    required this.campeonatoId,
    required this.isOrganizador,
    required this.onDelete,
  });

  Color get _avatarColor {
    const colors = [
      Color(0xFF1E63C8), Color(0xFF2E7D32), Color(0xFF6B2CB3),
      Color(0xFFE30613), Color(0xFF0097A7),
    ];
    if (time.nome.isEmpty) return colors[0];
    return colors[time.nome.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(time.id),
      direction: isOrganizador
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppTheme.accentRed,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JogadoresScreen(
              campeonatoId: campeonatoId,
              time: time,
              isOrganizador: isOrganizador,
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _avatarColor,
                child: Text(
                  time.nome.isNotEmpty ? time.nome[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(time.nome,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    if (time.categoria != null)
                      Text(time.categoria!,
                          style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    Text('Resp: ${time.responsavelNome}',
                        style: GoogleFonts.poppins(
                            color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppTheme.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tela de jogadores de um time.
class JogadoresScreen extends StatelessWidget {
  final String campeonatoId;
  final Time time;
  final bool isOrganizador;

  const JogadoresScreen({
    super.key,
    required this.campeonatoId,
    required this.time,
    this.isOrganizador = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: Text('Jogadores — ${time.nome}',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
      ),
      body: StreamBuilder<List<Jogador>>(
        stream: TimesService.instance.getJogadores(campeonatoId, time.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.accentOrange));
          }
          final jogadores = snapshot.data ?? [];
          if (jogadores.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off_outlined,
                      color: AppTheme.textMuted, size: 64),
                  const SizedBox(height: 16),
                  Text('Nenhum jogador inscrito',
                      style: GoogleFonts.poppins(
                          color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jogadores.length,
            itemBuilder: (context, index) {
              final j = jogadores[index];
              return _JogadorTile(
                jogador: j,
                isOrganizador: isOrganizador,
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.bgSecondary,
                      title: Text('Remover jogador?',
                          style: GoogleFonts.poppins(color: Colors.white)),
                      content: Text('Remover "${j.nomeExibicao}" do time?',
                          style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancelar',
                                style: GoogleFonts.poppins(
                                    color: AppTheme.textSecondary))),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Remover',
                                style: GoogleFonts.poppins(
                                    color: AppTheme.accentRed))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await TimesService.instance
                        .removerJogador(campeonatoId, time.id, j.id);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: isOrganizador
          ? FloatingActionButton(
              onPressed: () => _adicionarJogador(context),
              backgroundColor: AppTheme.accentOrange,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
    );
  }

  void _adicionarJogador(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final apelidoCtrl = TextEditingController();
    final numeroCtrl = TextEditingController();
    final posicaoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Adicionar Jogador',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _campoTexto(nomeCtrl, 'Nome completo *'),
            const SizedBox(height: 10),
            _campoTexto(apelidoCtrl, 'Apelido (opcional)'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _campoTexto(numeroCtrl, 'Nº camisa',
                      keyboard: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: _campoTexto(posicaoCtrl, 'Posição')),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (nomeCtrl.text.trim().isEmpty) return;
                  try {
                    await TimesService.instance.adicionarJogador(Jogador(
                      id: '',
                      campeonatoId: campeonatoId,
                      timeId: time.id,
                      nome: nomeCtrl.text.trim(),
                      apelido: apelidoCtrl.text.trim().isEmpty
                          ? null
                          : apelidoCtrl.text.trim(),
                      numero: int.tryParse(numeroCtrl.text.trim()),
                      posicao: posicaoCtrl.text.trim().isEmpty
                          ? null
                          : posicaoCtrl.text.trim(),
                      criadoEm: DateTime.now(),
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppTheme.accentRed));
                    }
                  }
                },
                child: Text('Salvar Jogador',
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _campoTexto(TextEditingController ctrl, String label,
      {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.cardColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.accentOrange, width: 1.5)),
      ),
    );
  }
}

class _JogadorTile extends StatelessWidget {
  final Jogador jogador;
  final bool isOrganizador;
  final VoidCallback onDelete;

  const _JogadorTile({
    required this.jogador,
    required this.isOrganizador,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(jogador.id),
      direction: isOrganizador
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        color: AppTheme.accentRed,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.person_remove, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Número da camisa
            if (jogador.numero != null)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${jogador.numero}',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14),
                  ),
                ),
              )
            else
              const SizedBox(width: 36),
            const SizedBox(width: 12),
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.bgSecondary,
              child: Text(
                jogador.nome.isNotEmpty ? jogador.nome[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jogador.nomeExibicao,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  if (jogador.posicao != null)
                    Text(jogador.posicao!,
                        style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
