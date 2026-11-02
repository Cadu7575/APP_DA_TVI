import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../models/article.dart';
import '../services/youtube_service.dart';
import '../utils/image_utils.dart';
import 'app_theme.dart';

class HeroCarousel extends StatefulWidget {
  final List<Article> articles;
  final YoutubeVideo? highlightVideo;
  final Function(Article) onTap;
  final Function(YoutubeVideo) onTapVideo;

  const HeroCarousel({
    super.key,
    required this.articles,
    this.highlightVideo,
    required this.onTap,
    required this.onTapVideo,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  int _currentIndex = 0;

  int get _itemCount {
    int count = widget.articles.length;
    if (widget.highlightVideo != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty && widget.highlightVideo == null) {
      return _buildShimmer();
    }

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: _itemCount,
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1.0,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            onPageChanged: (index, reason) {
              setState(() => _currentIndex = index);
            },
          ),
          itemBuilder: (context, index, realIndex) {
            if (widget.highlightVideo != null && index == 0) {
              return _buildVideoSlide(widget.highlightVideo!);
            }
            final articleIndex = widget.highlightVideo != null ? index - 1 : index;
            return _buildSlide(widget.articles[articleIndex]);
          },
        ),
        const SizedBox(height: 12),
        _buildDots(),
      ],
    );
  }

  Widget _buildSlide(Article article) {
    final optimizedImageUrl = ImageUtils.getOptimizedImageUrl(article.imageUrl);

    return GestureDetector(
      onTap: () => widget.onTap(article),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem de fundo
          if (optimizedImageUrl.isNotEmpty)
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
                color: const Color(0xFF1A1A1A),
                child: const Center(
                  child: Icon(
                    Icons.newspaper_rounded,
                    color: Color(0xFF3A3A3A),
                    size: 60,
                  ),
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF1A1A1A),
              child: const Center(
                child: Icon(
                  Icons.newspaper_rounded,
                  color: Color(0xFF3A3A3A),
                  size: 60,
                ),
              ),
            ),

          // Gradiente sobreposto
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Conteúdo textual
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (article.categoryName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentOrange, AppTheme.accentRed],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.categoryName!.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      shadows: [
                        const Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                        )
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.play_circle_fill,
                          color: AppTheme.accentOrange, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Ler matéria',
                        style: GoogleFonts.poppins(
                          color: AppTheme.accentOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // Badge DESTAQUE
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'DESTAQUE',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _itemCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 6,
          width: index == _currentIndex ? 24 : 6,
          decoration: BoxDecoration(
            color: index == _currentIndex
                ? AppTheme.accentOrange
                : AppTheme.textMuted,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSlide(YoutubeVideo video) {
    return GestureDetector(
      onTap: () => widget.onTapVideo(video),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem de fundo (Thumbnail)
          if (video.thumbnailUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppTheme.shimmerBase,
                highlightColor: AppTheme.shimmerHighlight,
                child: Container(color: AppTheme.shimmerBase),
              ),
              errorWidget: (context, url, error) => Container(
                color: const Color(0xFF1A1A1A),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFF3A3A3A),
                    size: 60,
                  ),
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF1A1A1A),
              child: const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF3A3A3A),
                  size: 60,
                ),
              ),
            ),

          // Gradiente sobreposto
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Borda decorativa laranja (sinaliza live ou destaque especial!)
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: video.isLive 
                    ? AppTheme.accentOrange.withValues(alpha: 0.6) 
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),

          // Conteúdo textual
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: video.isLive 
                            ? [AppTheme.accentOrange, AppTheme.accentRed] 
                            : [AppTheme.bgSecondary, AppTheme.textSecondary],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      video.isLive ? 'AO VIVO' : 'ÚLTIMA GRAVAÇÃO',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video.isLive ? 'Assista à TV Itapê Ao Vivo agora!' : video.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      shadows: [
                        const Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                        )
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        video.isLive ? Icons.live_tv_rounded : Icons.play_circle_fill_rounded,
                        color: AppTheme.accentOrange, 
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        video.isLive ? 'Assistir Transmissão' : 'Assistir Gravação',
                        style: GoogleFonts.poppins(
                          color: AppTheme.accentOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),

          // Badge DESTAQUE ou AO VIVO
          Positioned(
            top: 16,
            right: 16,
            child: video.isLive
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'NO AR',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSecondary.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TVI TAPE 2',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.shimmerBase,
      highlightColor: AppTheme.shimmerHighlight,
      child: Container(
        height: 300,
        width: double.infinity,
        color: AppTheme.shimmerBase,
      ),
    );
  }
}
