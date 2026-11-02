import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tvi_news/models/partida.dart';
import 'package:tvi_news/services/partidas_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

/// Widget reutilizável que exibe um feed compacto dos lances de uma partida
/// em tempo real, via [Stream]. Exibe no máximo 5 lances recentes.
///
/// Uso:
/// ```dart
/// LanceFeedWidget(
///   campeonatoId: 'abc',
///   partidaId: 'xyz',
/// )
/// ```
class LanceFeedWidget extends StatefulWidget {
  final String campeonatoId;
  final String partidaId;

  /// Callback opcional chamado quando o usuário toca em '+ Ver todos os lances'.
  final VoidCallback? onVerTodos;

  const LanceFeedWidget({
    super.key,
    required this.campeonatoId,
    required this.partidaId,
    this.onVerTodos,
  });

  @override
  State<LanceFeedWidget> createState() => _LanceFeedWidgetState();
}

class _LanceFeedWidgetState extends State<LanceFeedWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.3, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  Color? _corFundo(TipoLance tipo) {
    switch (tipo) {
      case TipoLance.gol:
      case TipoLance.golContra:
        return Colors.green.withOpacity(0.10);
      case TipoLance.cartaoVermelho:
        return AppTheme.accentRed.withOpacity(0.10);
      case TipoLance.cartaoAmarelo:
        return const Color(0xFFFFC107).withOpacity(0.08);
      default:
        return null;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Lance>>(
      stream: PartidasService.instance
          .getLances(widget.campeonatoId, widget.partidaId),
      builder: (context, snap) {
        final todos = snap.data ?? [];

        // Lances ordenados do mais recente (getLances já ordena por minuto desc)
        // Limita a 5 para exibição compacta
        final recentes = todos.take(5).toList();

        final isAoVivo = todos.isNotEmpty &&
            todos.any((l) =>
                l.tipo == TipoLance.inicioPrimeiroPeriodo ||
                l.tipo == TipoLance.inicioSegundoPeriodo);

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: const Border(
              top: BorderSide(color: AppTheme.accentOrange, width: 2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Cabeçalho ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Text(
                      '⚽ Lances da Partida',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                    const Spacer(),
                    if (isAoVivo) _buildAoVivoChip(),
                  ],
                ),
              ),
              // Divisor sutil
              Container(
                height: 1,
                color: const Color(0xFF2A2A2A),
              ),
              // ── Lista de lances ────────────────────────────────────────────
              if (recentes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Text(
                    '⏳ Aguardando início da partida...',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              else
                ...recentes.map((lance) => _buildLanceItem(lance)),
              // ── Rodapé ─────────────────────────────────────────────────────
              if (todos.length > 5)
                InkWell(
                  onTap: widget.onVerTodos,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFF242424),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(14),
                      ),
                    ),
                    child: Text(
                      '+ Ver todos os lances (${todos.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentOrange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (recentes.isNotEmpty)
                const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAoVivoChip() {
    return FadeTransition(
      opacity: _pulseOpacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.accentRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentRed, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 7, color: AppTheme.accentRed),
            const SizedBox(width: 4),
            Text(
              'AO VIVO',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentRed,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanceIcon(Lance lance) {
    if (lance.tipo == TipoLance.cartaoAmarelo) {
      return Container(
        width: 12,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFFFFD600),
          borderRadius: BorderRadius.circular(2),
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
        width: 12,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(2),
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
        width: 12,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF1E88E5),
          borderRadius: BorderRadius.circular(2),
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
      style: const TextStyle(fontSize: 16),
    );
  }

  Widget _buildLanceItem(Lance lance) {
    final corFundo = _corFundo(lance.tipo);
    final jogador = lance.jogadorNome ?? '';

    return Container(
      color: corFundo,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Ícone do tipo
          Container(
            width: 20,
            alignment: Alignment.center,
            child: _buildLanceIcon(lance),
          ),
          const SizedBox(width: 8),
          // Minuto
          SizedBox(
            width: 32,
            child: Text(
              "${lance.minuto}'",
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.accentOrange,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Tipo + jogador
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${lance.tipoLabel} ',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (jogador.isNotEmpty)
                    TextSpan(
                      text: jogador,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
