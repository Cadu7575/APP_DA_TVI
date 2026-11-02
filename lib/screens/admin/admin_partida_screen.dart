import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tvi_news/models/partida.dart';
import 'package:tvi_news/services/partidas_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

/// Tela exclusiva para Administrador editar partidas já encerradas.
/// Toda alteração é registrada em log (adminEditouId + adminEditouEm).
class AdminPartidaScreen extends StatefulWidget {
  final String campeonatoId;
  final String partidaId;
  final String adminId;

  const AdminPartidaScreen({
    super.key,
    required this.campeonatoId,
    required this.partidaId,
    required this.adminId,
  });

  @override
  State<AdminPartidaScreen> createState() => _AdminPartidaScreenState();
}

class _AdminPartidaScreenState extends State<AdminPartidaScreen> {
  late TextEditingController _placarACtrl;
  late TextEditingController _placarBCtrl;
  bool _salvando = false;

  @override
  void dispose() {
    _placarACtrl.dispose();
    _placarBCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Partida?>(
      stream: PartidasService.instance
          .getPartida(widget.campeonatoId, widget.partidaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            appBar: AppBar(backgroundColor: AppTheme.bgPrimary),
            body: const Center(child: Text('Partida não encontrada')),
          );
        }

        // Inicializar controllers com os valores atuais
        _placarACtrl =
            TextEditingController(text: '${partida.placarA ?? 0}');
        _placarBCtrl =
            TextEditingController(text: '${partida.placarB ?? 0}');

        return Scaffold(
          backgroundColor: AppTheme.bgPrimary,
          appBar: AppBar(
            backgroundColor: AppTheme.bgPrimary,
            title: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppTheme.accentOrange, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Admin — Editar Partida',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Banner de aviso
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.5), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.amber, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '⚠️ Modo Administrador: As alterações são permanentes e ficam registradas em log.',
                        style: GoogleFonts.poppins(
                            color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Info da partida
              Text('${partida.timeANome}  x  ${partida.timeBNome}',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(partida.status.name,
                  style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),

              // Edição de placar
              Text('Placar',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(partida.timeANome,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textSecondary, fontSize: 12),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _placarACtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900),
                          decoration: _inputDeco('Gols'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('x',
                        style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary, fontSize: 24)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(partida.timeBNome,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textSecondary, fontSize: 12),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _placarBCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900),
                          decoration: _inputDeco('Gols'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Lances registrados
              Text('Lances Registrados',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              StreamBuilder<List<Lance>>(
                stream: PartidasService.instance
                    .getLances(widget.campeonatoId, widget.partidaId),
                builder: (context, lanceSnap) {
                  final lances = lanceSnap.data ?? [];
                  if (lances.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppTheme.bgSecondary,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('Nenhum lance registrado',
                          style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary),
                          textAlign: TextAlign.center),
                    );
                  }
                  return Column(
                    children: lances
                        .map((l) => _LanceTile(
                              lance: l,
                              campeonatoId: widget.campeonatoId,
                              partidaId: widget.partidaId,
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Botão salvar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _salvando
                      ? null
                      : () => _salvar(partida),
                  child: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Salvar Alterações',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                ),
              ),
              if (partida.editadoPorAdmin) ...[
                const SizedBox(height: 12),
                Text(
                  '✏️ Editado pelo Administrador em ${partida.adminEditouEm?.toString() ?? ''}',
                  style: GoogleFonts.poppins(
                      color: AppTheme.textMuted, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<void> _salvar(Partida partida) async {
    setState(() => _salvando = true);
    try {
      final novaPartida = Partida(
        id: partida.id,
        campeonatoId: partida.campeonatoId,
        faseId: partida.faseId,
        grupoId: partida.grupoId,
        timeAId: partida.timeAId,
        timeANome: partida.timeANome,
        timeBId: partida.timeBId,
        timeBNome: partida.timeBNome,
        placarA: int.tryParse(_placarACtrl.text) ?? partida.placarA,
        placarB: int.tryParse(_placarBCtrl.text) ?? partida.placarB,
        status: partida.status,
        arbitroId: partida.arbitroId,
        arbitroNome: partida.arbitroNome,
        dataHora: partida.dataHora,
        local: partida.local,
        rodada: partida.rodada,
        editadoPorAdmin: true,
        adminEditouId: widget.adminId,
        adminEditouEm: DateTime.now(),
      );
      await PartidasService.instance
          .atualizarPartidaAdmin(novaPartida, widget.adminId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✔ Alterações salvas e registradas em log',
                style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppTheme.accentRed));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary),
      filled: true,
      fillColor: AppTheme.bgSecondary,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppTheme.accentOrange, width: 2)),
    );
  }
}

/// Tile de lance editável pelo Admin (com botão de deletar)
class _LanceTile extends StatelessWidget {
  final Lance lance;
  final String campeonatoId;
  final String partidaId;

  const _LanceTile({
    required this.lance,
    required this.campeonatoId,
    required this.partidaId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text(lance.tipoEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text("${lance.minuto}'",
                style: GoogleFonts.poppins(
                    color: AppTheme.accentOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${lance.tipoLabel}${lance.jogadorNome != null ? ' — ${lance.jogadorNome}' : ''}',
              style: GoogleFonts.poppins(
                  color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Botão deletar
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppTheme.textMuted, size: 18),
            onPressed: () => _confirmarDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmarDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text('Remover lance?',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
            '${lance.tipoLabel}${lance.jogadorNome != null ? ' — ${lance.jogadorNome}' : ''}',
            style:
                GoogleFonts.poppins(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await PartidasService.instance.deletarLance(
                    campeonatoId, partidaId, lance.id);
              },
              child: Text('Remover',
                  style:
                      GoogleFonts.poppins(color: AppTheme.accentRed))),
        ],
      ),
    );
  }
}
