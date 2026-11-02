import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tvi_news/models/jogador.dart';
import 'package:tvi_news/models/partida.dart';
import 'package:tvi_news/services/arbitro_service.dart';
import 'package:tvi_news/services/partidas_service.dart';
import 'package:tvi_news/services/times_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';
import 'package:tvi_news/widgets/lance_feed_widget.dart';

/// Tela de Súmula Digital — exclusiva para árbitros designados.
/// Permite registrar lances durante a partida em tempo real.
/// Após encerrar, apenas o Admin pode editar.
class SumulaScreen extends StatefulWidget {
  final String campeonatoId;
  final String partidaId;
  final String arbitroId;
  final Partida? partidaInicial;

  const SumulaScreen({
    super.key,
    required this.campeonatoId,
    required this.partidaId,
    required this.arbitroId,
    this.partidaInicial,
  });

  @override
  State<SumulaScreen> createState() => _SumulaScreenState();
}

class _SumulaScreenState extends State<SumulaScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Partida?>(
      initialData: widget.partidaInicial,
      stream: PartidasService.instance
          .getPartida(widget.campeonatoId, widget.partidaId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppTheme.bgPrimary,
            appBar: AppBar(
              backgroundColor: AppTheme.bgPrimary,
              title: Text(
                'Súmula Digital',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 17),
              ),
            ),
            body: Center(
              child: Text(
                'Erro ao carregar partida: ${snapshot.error}',
                style: GoogleFonts.poppins(color: AppTheme.accentRed),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppTheme.bgPrimary,
            body: Center(
                child: CircularProgressIndicator(color: AppTheme.accentOrange)),
          );
        }

        final partida = snapshot.data;
        if (partida == null) {
          return Scaffold(
            backgroundColor: AppTheme.bgPrimary,
            appBar: AppBar(
              backgroundColor: AppTheme.bgPrimary,
              title: Text(
                'Súmula Digital',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 17),
              ),
            ),
            body: Center(
              child: Text(
                'Partida não encontrada',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppTheme.bgPrimary,
            title: Row(
              children: [
                Text('📋 Súmula Digital',
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                _statusBadge(partida.status),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header placar
              _buildPlacarHeader(partida),
              const SizedBox(height: 20),

              // Corpo conforme status
              if (partida.status == StatusPartida.agendada)
                _buildBotaoIniciar(partida)
              else if (partida.status == StatusPartida.emAndamento) ...[
                _buildBotoesLances(partida),
                const SizedBox(height: 20),
                LanceFeedWidget(
                  campeonatoId: widget.campeonatoId,
                  partidaId: widget.partidaId,
                ),
                const SizedBox(height: 20),
                _buildBotaoEncerrar(partida),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.textMuted.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.lock_outline,
                          color: AppTheme.textMuted, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Partida encerrada.',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Apenas o Administrador pode editar os dados desta partida.',
                        style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                LanceFeedWidget(
                  campeonatoId: widget.campeonatoId,
                  partidaId: widget.partidaId,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlacarHeader(Partida p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3A1B), Color(0xFF0F1F0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
              child: Text(p.timeANome,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                  textAlign: TextAlign.center,
                  maxLines: 2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${p.placarA ?? 0}  x  ${p.placarB ?? 0}',
              style: GoogleFonts.poppins(
                  color: AppTheme.accentOrange,
                  fontSize: 28,
                  fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
              child: Text(p.timeBNome,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                  textAlign: TextAlign.center,
                  maxLines: 2)),
        ],
      ),
    );
  }

  Widget _buildBotaoIniciar(Partida partida) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
        label: Text('INICIAR PARTIDA',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        onPressed: () => _confirmarIniciar(partida),
      ),
    );
  }

  Widget _buildBotaoEncerrar(Partida partida) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentRed,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
        label: Text('ENCERRAR PARTIDA',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        onPressed: () => _confirmarEncerrar(partida),
      ),
    );
  }

  Widget _buildBotoesLances(Partida partida) {
    final acoes = [
      {'emoji': '⚽', 'label': 'GOL', 'cor': Colors.green, 'tipo': TipoLance.gol},
      {'emoji': '🟡', 'label': 'CARTÃO AMARELO', 'cor': Colors.amber, 'tipo': TipoLance.cartaoAmarelo},
      {'emoji': '🔴', 'label': 'CARTÃO VERMELHO', 'cor': Colors.red, 'tipo': TipoLance.cartaoVermelho},
      {'emoji': '🔄', 'label': 'SUBSTITUIÇÃO', 'cor': Colors.blue, 'tipo': TipoLance.substituicao},
      {'emoji': '🤕', 'label': 'LESÃO', 'cor': Colors.purple, 'tipo': TipoLance.lesao},
      {'emoji': '📋', 'label': 'OCORRÊNCIA', 'cor': Colors.grey, 'tipo': TipoLance.ocorrencia},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: acoes.map((a) {
        final cor = a['cor'] as Color;
        final tipo = a['tipo'] as TipoLance;
        return GestureDetector(
          onTap: () => _abrirRegistroLance(partida, tipo, cor),
          child: Container(
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cor.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(a['emoji'] as String, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    a['label'] as String,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _abrirRegistroLance(Partida partida, TipoLance tipo, Color cor) async {
    // Mapas auxiliares pois tipoEmoji/tipoLabel são métodos de Lance, não TipoLance
    const emojiMap = {
      TipoLance.gol: '⚽',
      TipoLance.golContra: '⚽',
      TipoLance.cartaoAmarelo: '🟡',
      TipoLance.cartaoVermelho: '🔴',
      TipoLance.substituicao: '🔄',
      TipoLance.lesao: '🤕',
      TipoLance.ocorrencia: '📋',
      TipoLance.penalti: '🎯',
    };
    const labelMap = {
      TipoLance.gol: 'GOL',
      TipoLance.golContra: 'GOL CONTRA',
      TipoLance.cartaoAmarelo: 'CARTÃO AMARELO',
      TipoLance.cartaoVermelho: 'CARTÃO VERMELHO',
      TipoLance.substituicao: 'SUBSTITUIÇÃO',
      TipoLance.lesao: 'LESÃO',
      TipoLance.ocorrencia: 'OCORRÊNCIA',
      TipoLance.penalti: 'PÊNALTI',
    };

    String? timeSelecionadoId;
    Jogador? jogadorSelecionado;
    Jogador? jogadorSaiSelecionado;
    final minutoCtrl = TextEditingController(text: '1');
    final descricaoCtrl = TextEditingController();

    // Carregar jogadores
    final todosJogadores = await TimesService.instance
        .getJogadoresDoCampeonato(partida.campeonatoId);
    final jogadoresA = todosJogadores
        .where((j) => j.timeId == partida.timeAId)
        .toList();
    final jogadoresB = todosJogadores
        .where((j) => j.timeId == partida.timeBId)
        .toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        final jogadoresDoTime = timeSelecionadoId == partida.timeAId
            ? jogadoresA
            : jogadoresB;

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emojiMap[tipo] ?? '📋',
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Text('Registrar ${labelMap[tipo] ?? tipo.name}',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),

              // Selecionar time
              DropdownButtonFormField<String>(
                dropdownColor: AppTheme.bgSecondary,
                decoration: _inputDecoration('Time'),
                items: [
                  DropdownMenuItem(
                      value: partida.timeAId,
                      child: Text(partida.timeANome,
                          style: const TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: partida.timeBId,
                      child: Text(partida.timeBNome,
                          style: const TextStyle(color: Colors.white))),
                ],
                onChanged: (v) => setModalState(() {
                  timeSelecionadoId = v;
                  jogadorSelecionado = null;
                  jogadorSaiSelecionado = null;
                }),
              ),
              if (timeSelecionadoId != null) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<Jogador>(
                  dropdownColor: AppTheme.bgSecondary,
                  decoration: _inputDecoration(
                      tipo == TipoLance.substituicao ? 'Jogador entra' : 'Jogador'),
                  items: jogadoresDoTime
                      .map((j) => DropdownMenuItem(
                          value: j,
                          child: Text(j.nomeExibicao,
                              style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) =>
                      setModalState(() => jogadorSelecionado = v),
                ),
              ],
              if (tipo == TipoLance.substituicao &&
                  timeSelecionadoId != null) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<Jogador>(
                  dropdownColor: AppTheme.bgSecondary,
                  decoration: _inputDecoration('Jogador sai'),
                  items: jogadoresDoTime
                      .map((j) => DropdownMenuItem(
                          value: j,
                          child: Text(j.nomeExibicao,
                              style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) =>
                      setModalState(() => jogadorSaiSelecionado = v),
                ),
              ],
              if (tipo == TipoLance.ocorrencia) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: descricaoCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Descrição da ocorrência'),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: minutoCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Minuto'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: cor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    try {
                      final lance = Lance(
                        id: '',
                        partidaId: partida.id,
                        campeonatoId: partida.campeonatoId,
                        tipo: tipo,
                        jogadorId: jogadorSelecionado?.id,
                        jogadorNome: jogadorSelecionado?.nomeExibicao,
                        jogadorSaiId: jogadorSaiSelecionado?.id,
                        jogadorSaiNome: jogadorSaiSelecionado?.nomeExibicao,
                        timeId: timeSelecionadoId,
                        minuto: int.tryParse(minutoCtrl.text) ?? 1,
                        descricao: descricaoCtrl.text.trim().isEmpty
                            ? null
                            : descricaoCtrl.text.trim(),
                        registradoPorId: widget.arbitroId,
                        timestamp: DateTime.now(),
                      );
                      await ArbitroService.instance
                          .registrarLance(lance, partida);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppTheme.accentRed));
                      }
                    }
                  },
                  child: Text('Confirmar',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _confirmarIniciar(Partida partida) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title:
            Text('⚠️ Iniciar partida?', style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('Confirma o início de ${partida.timeANome} x ${partida.timeBNome}?',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Iniciar',
                  style: GoogleFonts.poppins(color: Colors.green))),
        ],
      ),
    );
    if (ok == true) {
      await ArbitroService.instance.iniciarPartida(partida);
    }
  }

  Future<void> _confirmarEncerrar(Partida partida) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text('⚠️ Encerrar partida?',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
            'Esta ação não poderá ser desfeita pelo árbitro. Apenas o Administrador poderá editar após encerrar.',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style:
                      GoogleFonts.poppins(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Encerrar',
                  style: GoogleFonts.poppins(color: AppTheme.accentRed))),
        ],
      ),
    );
    if (ok == true) {
      await ArbitroService.instance.encerrarPartida(partida);
    }
  }

  Widget _statusBadge(StatusPartida status) {
    final map = {
      StatusPartida.agendada: ('Agendada', Colors.grey),
      StatusPartida.emAndamento: ('🔴 AO VIVO', Colors.red),
      StatusPartida.encerrada: ('Encerrada', Colors.blueGrey),
      StatusPartida.adiada: ('Adiada', Colors.orange),
      StatusPartida.cancelada: ('Cancelada', AppTheme.accentRed),
    };
    final (label, cor) = map[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withValues(alpha: 0.5), width: 1)),
      child: Text(label,
          style: GoogleFonts.poppins(
              color: cor, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.cardColor,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTheme.accentOrange, width: 1.5)),
    );
  }
}
