import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tvi_news/services/classificacao_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

/// Tela de artilharia do campeonato — ranking de gols por jogador.
class ArtilhariaScreen extends StatelessWidget {
  final String campeonatoId;
  final String campeonatoNome;

  const ArtilhariaScreen({
    super.key,
    required this.campeonatoId,
    required this.campeonatoNome,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Artilharia',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              campeonatoNome,
              style: GoogleFonts.poppins(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<ArtiglariaItem>>(
        stream: ClassificacaoService.instance.getArtilharia(campeonatoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accentOrange),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erro ao carregar artilharia',
                style: GoogleFonts.poppins(color: AppTheme.textSecondary),
              ),
            );
          }

          final artilheiros = snapshot.data ?? [];

          if (artilheiros.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_soccer_outlined,
                      color: AppTheme.textMuted, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum gol marcado ainda',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: artilheiros.length,
            itemBuilder: (context, index) {
              final item = artilheiros[index];
              final isTop3 = index < 3;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isTop3
                      ? AppTheme.accentOrange.withValues(alpha: 0.08)
                      : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: isTop3
                      ? Border.all(
                          color: AppTheme.accentOrange.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Posição
                      SizedBox(
                        width: 32,
                        child: Text(
                          '#${index + 1}',
                          style: GoogleFonts.poppins(
                            color: isTop3
                                ? AppTheme.accentOrange
                                : AppTheme.textSecondary,
                            fontWeight: isTop3
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Avatar
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: _colorFromName(item.jogadorNome),
                        child: Text(
                          item.jogadorNome.isNotEmpty
                              ? item.jogadorNome[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    item.jogadorNome,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        item.timeNome,
                        style: GoogleFonts.poppins(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (item.cartoesAmarelos > 0) ...[
                        const SizedBox(width: 8),
                        _miniCartao(Colors.yellow, item.cartoesAmarelos),
                      ],
                      if (item.cartoesVermelhos > 0) ...[
                        const SizedBox(width: 4),
                        _miniCartao(Colors.red, item.cartoesVermelhos),
                      ],
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${item.gols} ⚽',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _miniCartao(Color cor, int quantidade) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cor, width: 1),
      ),
      child: Text(
        '$quantidade',
        style: TextStyle(
          color: cor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _colorFromName(String name) {
    const colors = [
      Color(0xFF1E63C8),
      Color(0xFF2E7D32),
      Color(0xFF6B2CB3),
      Color(0xFFE30613),
      Color(0xFFFF6B00),
      Color(0xFF0097A7),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
