import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tvi_news/services/auth_service.dart';
import 'package:tvi_news/widgets/app_theme.dart';

/// Tela de punições e suspensões do campeonato.
/// Exibe jogadores com cartões acumulados e suspensões ativas.
class PunicoesScreen extends StatelessWidget {
  final String campeonatoId;
  final String campeonatoNome;

  const PunicoesScreen({
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
              'Punições e Suspensões',
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
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('campeonatos')
            .doc(campeonatoId)
            .collection('punicoes')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accentOrange),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel_outlined,
                      color: AppTheme.textMuted, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma punição registrada',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Legenda
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _legendaChip('🟡 2 amarelos = 1 jogo suspenso',
                        Colors.yellow.withValues(alpha: 0.15),
                        Colors.yellow),
                    const SizedBox(width: 8),
                    _legendaChip('🔴 = suspensão direta',
                        Colors.red.withValues(alpha: 0.15), Colors.red),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final cartoesAmarelos = data['cartoesAmarelos'] ?? 0;
                    final cartoesVermelhos = data['cartoesVermelhos'] ?? 0;
                    final suspenso = data['suspenso'] ?? false;
                    final jogosSuspenso = data['jogosSuspenso'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: suspenso
                            ? Colors.red.withValues(alpha: 0.08)
                            : AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: suspenso
                            ? Border.all(
                                color: Colors.red.withValues(alpha: 0.4),
                                width: 1)
                            : null,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: suspenso
                              ? Colors.red.withValues(alpha: 0.3)
                              : AppTheme.bgSecondary,
                          child: Text(
                            (data['jogadorNome'] as String? ?? '?')
                                .isNotEmpty
                                ? (data['jogadorNome'] as String)[0]
                                    .toUpperCase()
                                : '?',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          data['jogadorNome'] ?? 'Jogador',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          data['timeNome'] ?? '',
                          style: GoogleFonts.poppins(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (cartoesAmarelos > 0)
                                  _cartaoBadge(
                                      '🟡 $cartoesAmarelos', Colors.yellow),
                                if (cartoesVermelhos > 0) ...[
                                  const SizedBox(width: 4),
                                  _cartaoBadge(
                                      '🔴 $cartoesVermelhos', Colors.red),
                                ],
                              ],
                            ),
                            if (suspenso) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  jogosSuspenso > 0
                                      ? 'SUSPENSO ($jogosSuspenso jogo${jogosSuspenso > 1 ? 's' : ''})'
                                      : 'SUSPENSO',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: AuthService.instance.isAdmin(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return FloatingActionButton.extended(
              onPressed: () => _adicionarPunicaoManual(context),
              backgroundColor: AppTheme.accentOrange,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Punição Manual',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _cartaoBadge(String label, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _legendaChip(String label, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  void _adicionarPunicaoManual(BuildContext context) {
    // Apenas Admin — tela de punição manual
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSecondary,
        title: Text(
          'Punição Manual',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'Funcionalidade disponível para o Administrador. Use a tela de edição da partida para adicionar lances de cartão.',
          style: GoogleFonts.poppins(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK',
                style: GoogleFonts.poppins(color: AppTheme.accentOrange)),
          ),
        ],
      ),
    );
  }
}
