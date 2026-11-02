import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../services/youtube_service.dart';
import '../widgets/app_theme.dart';
import 'video_player_screen.dart';


class YoutubeScreen extends StatefulWidget {
  const YoutubeScreen({super.key});

  @override
  State<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen>
    with TickerProviderStateMixin {
  final YoutubeService _youtubeService = YoutubeService();
  List<YoutubeVideo> _videos = [];
  bool _isLoading = true;
  bool _hasError = false;
  late AnimationController _liveBlinkController;
  late Animation<double> _liveBlinkAnimation;
  late TabController _tabController;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Animação de piscar para o badge "AO VIVO"
    _liveBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _liveBlinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _liveBlinkController, curve: Curves.easeInOut),
    );
    _loadVideos(isRefresh: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _liveBlinkController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos({bool isRefresh = false}) async {
    if (isRefresh && mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    } else {
      _isLoading = true;
      _hasError = false;
    }
    try {
      final videos = await _youtubeService.fetchChannelVideos();
      if (mounted) {
        setState(() {
          _videos = videos;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _openVideo(YoutubeVideo video) async {
    if (_isNavigating) return;
    _isNavigating = true;

    // Abre o player embutido no app (sem sair para o YouTube)
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VideoPlayerScreen(video: video),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );

    _isNavigating = false;
  }

  Future<void> _openChannel() async {
    final uri = Uri.parse('https://www.youtube.com/@tvitape2');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Separa: ao vivo real, em breve (agendados), e gravações
    final liveVideos = _videos.where((v) => v.isLive).toList();
    final upcomingVideos = _videos.where((v) => v.isUpcoming && !v.isLive).toList();
    final regularVideos = _videos.where((v) => !v.isLive && !v.isUpcoming).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [_buildSliverAppBar(liveVideos.isNotEmpty)];
          },
          body: _isLoading
              ? _buildLoadingState()
              : _hasError
                  ? _buildErrorState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLiveTab(liveVideos),
                        _buildUpcomingTab(upcomingVideos),
                        _buildRegularTab(regularVideos),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool hasLive) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.bgPrimary,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.bgSecondary,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 18),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      title: Row(
        children: [
          // Ícone YouTube
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentOrange,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TVI Tape 2',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '@tvitape2',
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (hasLive) ...[
            const SizedBox(width: 10),
            FadeTransition(
              opacity: _liveBlinkAnimation,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '● AO VIVO',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => _loadVideos(isRefresh: true),
          tooltip: 'Atualizar',
        ),
        IconButton(
          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
          onPressed: _openChannel,
          tooltip: 'Abrir Canal',
        ),
        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.accentOrange,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        tabs: const [
          Tab(text: 'AO VIVO'),
          Tab(text: 'EM BREVE'),
          Tab(text: 'GRAVAÇÕES'),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmer(120, 70, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmer(14, double.infinity),
                const SizedBox(height: 6),
                _shimmer(12, 150),
                const SizedBox(height: 6),
                _shimmer(10, 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmer(double height, double width, {double radius = 4}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, child) {
        return Container(
          height: height,
          width: width == double.infinity ? null : width,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppTheme.shimmerBase,
              AppTheme.shimmerHighlight,
              value,
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                color: AppTheme.textMuted, size: 72),
            const SizedBox(height: 20),
            Text(
              'Não foi possível carregar os vídeos',
              style: GoogleFonts.poppins(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Verifique sua conexão e tente novamente',
              style: GoogleFonts.poppins(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _loadVideos(isRefresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Tentar Novamente',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _openChannel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.accentOrange),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('Abrir YouTube',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLiveTab(List<YoutubeVideo> videos) {
    return RefreshIndicator(
      onRefresh: _loadVideos,
      color: AppTheme.accentOrange,
      backgroundColor: AppTheme.cardColor,
      child: videos.isEmpty
          ? _buildLiveOfflineState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: videos.length,
              itemBuilder: (context, index) => _buildVideoCard(videos[index], isLive: true),
            ),
    );
  }

  Widget _buildLiveOfflineState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _liveBlinkAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSecondary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentOrange.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.portable_wifi_off_rounded,
                        color: AppTheme.accentOrange,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Canal Offline',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Não há nenhuma transmissão ao vivo no momento. Acompanhe nossas redes ou assista às gravações.',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () {
                      _tabController.animateTo(2); // Muda para a aba de Gravações!
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.video_library_rounded, size: 18),
                    label: Text(
                      'Ver Gravações',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTab(List<YoutubeVideo> videos) {
    return RefreshIndicator(
      onRefresh: _loadVideos,
      color: AppTheme.accentOrange,
      backgroundColor: AppTheme.cardColor,
      child: videos.isEmpty
          ? _buildEmptyStateTab(
              icon: Icons.schedule_rounded,
              title: 'Sem Agendamentos',
              description: 'Nenhuma transmissão ao vivo agendada para os próximos dias.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: videos.length,
              itemBuilder: (context, index) => _buildVideoCard(videos[index], isUpcoming: true),
            ),
    );
  }

  Widget _buildRegularTab(List<YoutubeVideo> videos) {
    return RefreshIndicator(
      onRefresh: _loadVideos,
      color: AppTheme.accentOrange,
      backgroundColor: AppTheme.cardColor,
      child: videos.isEmpty
          ? _buildEmptyStateTab(
              icon: Icons.video_library_rounded,
              title: 'Nenhuma Gravação',
              description: 'Nenhum vídeo gravado foi encontrado no canal no momento.',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: videos.length,
              itemBuilder: (context, index) => _buildVideoCard(videos[index]),
            ),
    );
  }

  Widget _buildEmptyStateTab({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: AppTheme.textMuted,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(YoutubeVideo video,
      {bool isLive = false, bool isUpcoming = false}) {
    return GestureDetector(
      onTap: () => _openVideo(video),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161619),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLive
                ? AppTheme.accentOrange.withOpacity(0.8)
                : isUpcoming
                    ? AppTheme.accentBlue.withOpacity(0.6)
                    : const Color(0xFF282830),
            width: isLive ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isLive
                  ? AppTheme.accentOrange.withOpacity(0.2)
                  : Colors.black.withOpacity(0.35),
              blurRadius: isLive ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
              child: Stack(
                children: [
                  // Thumbnail image
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppTheme.bgSecondary,
                        child: const Center(
                          child: Icon(Icons.play_circle_outline_rounded,
                              color: Colors.white54, size: 48),
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppTheme.shimmerBase,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.accentOrange,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Overlay gradiente
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Play icon (apenas para não-upcoming)
                  if (!isUpcoming)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  // Badge AO VIVO (piscante)
                  if (isLive)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: FadeTransition(
                        opacity: _liveBlinkAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '● AO VIVO',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Badge EM BREVE (estático, azul)
                  if (isUpcoming)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '🕐 EM BREVE',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Informações do vídeo
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ícone do canal
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tv_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Meta info
                        Row(
                          children: [
                            Text(
                              'TVI Tape 2',
                              style: GoogleFonts.poppins(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            if (video.publishedAt.isNotEmpty) ...[
                              Text(
                                '  •  ',
                                style: GoogleFonts.poppins(
                                    color: AppTheme.textMuted, fontSize: 11),
                              ),
                              Text(
                                isLive
                                    ? 'Ao vivo agora'
                                    : video.publishedAt,
                                style: GoogleFonts.poppins(
                                  color: isLive
                                      ? AppTheme.accentOrange
                                      : isUpcoming
                                          ? AppTheme.accentBlue
                                          : AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: (isLive || isUpcoming)
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Menu de ações
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppTheme.textMuted, size: 18),
                    onPressed: () => _showVideoOptions(video),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoOptions(YoutubeVideo video) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Título
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(color: AppTheme.shimmerBase),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded,
                    color: AppTheme.accentOrange),
                title: Text(
                  'Abrir no YouTube',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openVideo(video);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded,
                    color: AppTheme.textSecondary),
                title: Text(
                  'Copiar link',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(
                      ClipboardData(text: video.youtubeWatchUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Link copiado!',
                          style: GoogleFonts.poppins(color: Colors.white)),
                      backgroundColor: AppTheme.accentOrange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
