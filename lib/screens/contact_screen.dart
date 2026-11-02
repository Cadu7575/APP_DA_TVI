import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_theme.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const String emailRedacao = 'redacao@tvitape.com.br';
  static const String emailContato = 'contato@tvitape.com.br';
  static const String telefoneRedacao = '(15) 3271-0000';
  static const String siteWeb = 'https://xeh.com.br';
  static const String urlContatoWeb = 'https://live-stream-watcher-two.vercel.app/contato.html';
  static const String urlPrivacidade = 'https://live-stream-watcher-two.vercel.app/privacidade.html';

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: Text(
          'Contato & Expediente',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header do Veículo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.shimmerBase),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentOrange, width: 2),
                    ),
                    child: const Icon(
                      Icons.newspaper_rounded,
                      color: AppTheme.accentOrange,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'TVI News • TV Itapê',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Jornalismo Regional de Itapetininga e Região\nPortal de Notícias e Transmissões ao Vivo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Seção: Fale Conosco / Contato da Redação (Exigência Google Play)
            _buildSectionHeader('Fale com a Redação'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.shimmerBase),
              ),
              child: Column(
                children: [
                  _buildContactTile(
                    icon: Icons.email_rounded,
                    title: 'E-mail da Redação',
                    subtitle: emailRedacao,
                    onTap: () => _launchUrl('mailto:$emailRedacao?subject=Sugestão de Pauta / Contato - TVI News'),
                  ),
                  const Divider(color: AppTheme.shimmerBase, height: 1),
                  _buildContactTile(
                    icon: Icons.alternate_email_rounded,
                    title: 'E-mail Geral / Atendimento',
                    subtitle: emailContato,
                    onTap: () => _launchUrl('mailto:$emailContato?subject=Contato TVI News'),
                  ),
                  const Divider(color: AppTheme.shimmerBase, height: 1),
                  _buildContactTile(
                    icon: Icons.phone_rounded,
                    title: 'Telefone da Redação',
                    subtitle: telefoneRedacao,
                    onTap: () => _launchUrl('tel:1532710000'),
                  ),
                  const Divider(color: AppTheme.shimmerBase, height: 1),
                  _buildContactTile(
                    icon: Icons.location_on_rounded,
                    title: 'Sede & Cobertura',
                    subtitle: 'Itapetininga - SP, Brasil',
                    onTap: null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Seção: Expediente Editorial e Transparência
            _buildSectionHeader('Expediente Editorial & Fontes'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.shimmerBase),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    label: 'Editora Responsável:',
                    value: 'TV Itapê Comunicações / TVI',
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    label: 'Fonte das Notícias:',
                    value: 'Portal TVI (xeh.com.br) e Redação TV Itapê',
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    label: 'Linha Editorial:',
                    value: 'Cobertura jornalística independente, com foco em notícias locais, prestação de serviços, política, esportes e cultura de Itapetininga e região.',
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    label: 'Direito de Resposta e Correções:',
                    value: 'Para correções, pedidos de esclarecimento ou direito de resposta, envie um e-mail para $emailRedacao.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Seção: Links Oficiais
            _buildSectionHeader('Links Oficiais na Web'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.shimmerBase),
              ),
              child: Column(
                children: [
                  _buildContactTile(
                    icon: Icons.language_rounded,
                    title: 'Portal de Notícias na Web',
                    subtitle: siteWeb,
                    onTap: () => _launchUrl(siteWeb),
                  ),
                  const Divider(color: AppTheme.shimmerBase, height: 1),
                  _buildContactTile(
                    icon: Icons.public_rounded,
                    title: 'Página Web de Contato Oficial',
                    subtitle: 'live-stream-watcher-two.vercel.app/contato.html',
                    onTap: () => _launchUrl(urlContatoWeb),
                  ),
                  const Divider(color: AppTheme.shimmerBase, height: 1),
                  _buildContactTile(
                    icon: Icons.policy_rounded,
                    title: 'Política de Privacidade',
                    subtitle: 'Ver termos e privacidade do usuário',
                    onTap: () => _launchUrl(urlPrivacidade),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                'TVI News • Versão 1.0.1\nTV Itapê — Todos os direitos reservados',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: AppTheme.accentOrange,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.accentOrange, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildInfoRow({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
