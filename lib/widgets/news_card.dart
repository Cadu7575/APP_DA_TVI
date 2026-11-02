import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/article.dart';
import '../utils/image_utils.dart';
import 'app_theme.dart';

class NewsCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final bool isLarge;

  const NewsCard({
    super.key,
    required this.article,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161619),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF282830),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final double height = isLarge ? 220 : 180;
    final optimizedImageUrl = ImageUtils.getOptimizedImageUrl(article.imageUrl);

    if (optimizedImageUrl.isNotEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: CachedNetworkImage(
          imageUrl: optimizedImageUrl,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36',
          },
          placeholder: (context, url) => _shimmerBox(height),
          errorWidget: (context, url, error) => _fallbackImage(height),
        ),
      );
    }
    return _fallbackImage(height);
  }

  Widget _fallbackImage(double height) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppTheme.shimmerBase,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.newspaper_rounded,
              color: Color(0xFF3A3A3A), size: 48),
          const SizedBox(height: 8),
          Text(
            'Sem imagem',
            style: TextStyle(
              color: const Color(0xFF3A3A3A),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double height) {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase,
      highlightColor: AppTheme.shimmerHighlight,
      child: Container(
        height: height,
        width: double.infinity,
        color: AppTheme.shimmerBase,
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.categoryName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppTheme.accentOrange.withValues(alpha: 0.4)),
              ),
              child: Text(
                article.categoryName!.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: AppTheme.accentOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          Text(
            article.title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: isLarge ? 18 : 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (article.excerpt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              article.excerpt,
              style: GoogleFonts.poppins(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                _formatDate(article.date),
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.accentOrange),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
      if (diff.inHours < 24) return '${diff.inHours}h atrás';
      if (diff.inDays == 1) return 'Ontem';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}

class NewsCardHorizontal extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const NewsCardHorizontal({
    super.key,
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              _buildThumbnail(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final optimizedImageUrl = ImageUtils.getOptimizedImageUrl(article.imageUrl);

    if (optimizedImageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: optimizedImageUrl,
        height: 100,
        width: 110,
        fit: BoxFit.cover,
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36',
        },
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: AppTheme.shimmerBase,
          highlightColor: AppTheme.shimmerHighlight,
          child:
              Container(height: 100, width: 110, color: AppTheme.shimmerBase),
        ),
        errorWidget: (context, url, error) => _noImageBox(),
      );
    }
    return _noImageBox();
  }

  Widget _noImageBox() {
    return Container(
      height: 100,
      width: 110,
      color: AppTheme.shimmerBase,
      child: const Icon(
        Icons.newspaper_rounded,
        color: Color(0xFF3A3A3A),
        size: 32,
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.categoryName != null)
            Text(
              article.categoryName!.toUpperCase(),
              style: GoogleFonts.poppins(
                color: AppTheme.accentOrange,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            article.title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(article.date),
            style: GoogleFonts.poppins(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
      if (diff.inHours < 24) return '${diff.inHours}h atrás';
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
