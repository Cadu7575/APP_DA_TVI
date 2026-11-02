import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../widgets/app_theme.dart';
import '../utils/image_utils.dart';
import 'contact_screen.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final optimizedImageUrl = ImageUtils.getOptimizedImageUrl(article.imageUrl);
    final processedHtml = ImageUtils.processHtmlContent(article.content);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: CustomScrollView(
          slivers: [
            // AppBar com imagem de capa
            SliverAppBar(
              expandedHeight: optimizedImageUrl.isNotEmpty ? 280 : 100,
              pinned: true,
              backgroundColor: AppTheme.bgSecondary,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.share_rounded,
                        color: Colors.white, size: 18),
                    onPressed: () => _shareArticle(context),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: optimizedImageUrl.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          // Imagem
                          CachedNetworkImage(
                            imageUrl: optimizedImageUrl,
                            fit: BoxFit.cover,
                            httpHeaders: const {
                              'User-Agent':
                                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36',
                            },
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: AppTheme.shimmerBase,
                              highlightColor: AppTheme.shimmerHighlight,
                              child: Container(color: AppTheme.shimmerBase),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppTheme.bgSecondary,
                              child: const Icon(Icons.newspaper_rounded,
                                  color: Color(0xFF3A3A3A), size: 64),
                            ),
                          ),
                          // Gradiente preto na parte inferior
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                  AppTheme.bgPrimary,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(color: AppTheme.bgSecondary),
              ),
            ),
            // Conteúdo do Artigo
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categoria
                    if (article.categoryName != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.accentOrange
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          article.categoryName!.toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: AppTheme.accentOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Título
                    Text(
                      article.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Metadados: Data, Autor e Fonte (Conformidade com a Política de Notícias do Google Play)
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 5),
                            Text(
                              _formatFullDate(article.date),
                              style: GoogleFonts.poppins(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 14, color: AppTheme.accentOrange),
                            const SizedBox(width: 5),
                            Text(
                              article.author,
                              style: GoogleFonts.poppins(
                                color: AppTheme.accentOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 14, color: AppTheme.accentBlue),
                            const SizedBox(width: 5),
                            Text(
                              article.publisher,
                              style: GoogleFonts.poppins(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: AppTheme.shimmerBase, height: 1),
                    const SizedBox(height: 24),

                    // HTML Renderizado Nativamente
                    HtmlWidget(
                      processedHtml,
                      textStyle: GoogleFonts.poppins(
                        color: const Color(0xFFE0E0E0),
                        fontSize: 15,
                        height: 1.7,
                      ),
                      customStylesBuilder: (element) {
                        if (element.localName == 'a') {
                          return {'color': '#FF6B00', 'text-decoration': 'none'};
                        }
                        if (element.localName == 'h1' ||
                            element.localName == 'h2' ||
                            element.localName == 'h3') {
                          return {
                            'color': '#FFFFFF',
                            'font-weight': 'bold',
                            'margin-top': '24px',
                            'margin-bottom': '12px'
                          };
                        }
                        if (element.localName == 'blockquote') {
                          return {
                            'border-left': '4px solid #FF6B00',
                            'padding-left': '16px',
                            'font-style': 'italic',
                            'color': '#A0A0A0',
                            'margin': '16px 0'
                          };
                        }
                        return null;
                      },
                      onTapUrl: (url) async {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return true;
                        }
                        return false;
                      },
                    ),

                    const SizedBox(height: 35),
                    // Card de Transparência Editorial e Contato (Exigência Google Play)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.shimmerBase),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_outlined,
                                  color: AppTheme.accentOrange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Transparência Editorial',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Matéria apurada e publicada por ${article.author} para o veículo ${article.publisher}. Cobertura jornalística local e regional de Itapetininga e região.',
                            style: GoogleFonts.poppins(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ContactScreen(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.accentOrange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.contact_mail_rounded,
                                      size: 16, color: AppTheme.accentOrange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Falar com a Redação / Contato do App',
                                      style: GoogleFonts.poppins(
                                        color: AppTheme.accentOrange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 12, color: AppTheme.accentOrange),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Divider(color: AppTheme.shimmerBase, height: 1),
                    const SizedBox(height: 25),

                    // Botão Ler no Navegador
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => _openInBrowser(article.link),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: AppTheme.shimmerBase),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                        label: Text(
                          'Ver matéria no site original',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Janeiro',
        'Fevereiro',
        'Março',
        'Abril',
        'Maio',
        'Junho',
        'Julho',
        'Agosto',
        'Setembro',
        'Outubro',
        'Novembro',
        'Dezembro'
      ];
      return '${date.day} de ${months[date.month - 1]} de ${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _shareArticle(BuildContext context) {
    Clipboard.setData(ClipboardData(text: article.link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Link copiado com sucesso!',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: AppTheme.accentOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
