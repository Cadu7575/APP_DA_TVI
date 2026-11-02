import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../widgets/app_theme.dart';

/// Tela intermediária: carrega uma matéria pelo ID (para deep links de notificação)
class ArticleFromIdScreen extends StatefulWidget {
  final String articleId;

  const ArticleFromIdScreen({super.key, required this.articleId});

  @override
  State<ArticleFromIdScreen> createState() => _ArticleFromIdScreenState();
}

class _ArticleFromIdScreenState extends State<ArticleFromIdScreen> {
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    try {
      final url =
          'https://xeh.com.br/wp-json/wp/v2/posts/${widget.articleId}?_embed=1';
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        String? imageUrl;
        String? categoryName;
        int? categoryId;

        try {
          final embedded = data['_embedded'];
          if (embedded != null) {
            final featuredMedia = embedded['wp:featuredmedia'];
            if (featuredMedia != null && featuredMedia.isNotEmpty) {
              imageUrl = featuredMedia[0]['source_url'];
            }
            final terms = embedded['wp:term'];
            if (terms != null && terms.isNotEmpty && terms[0].isNotEmpty) {
              categoryName = terms[0][0]['name'];
              categoryId = terms[0][0]['id'];
            }
          }
        } catch (_) {}

        final article = Article.fromJson(
          data,
          imageUrl: imageUrl,
          categoryName: categoryName,
          categoryId: categoryId,
        );

        if (mounted) {
          // Substitui esta tela pelo detalhe do artigo
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleDetailScreen(article: article),
            ),
          );
        }
      } else {
        _showError('Matéria não encontrada (${response.statusCode})');
      }
    } catch (e) {
      _showError('Erro ao carregar a matéria. Verifique sua conexão.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Carregando matéria...',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.textMuted, size: 64),
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _error = null);
                        _loadArticle();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('Tentar Novamente',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppTheme.accentOrange,
                    backgroundColor: AppTheme.accentOrange.withValues(alpha: 0.15),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Carregando matéria...',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
