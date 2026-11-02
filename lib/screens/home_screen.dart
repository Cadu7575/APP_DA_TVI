import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/article.dart';
import '../services/news_service.dart';
import '../services/youtube_service.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/news_card.dart';
import '../widgets/app_theme.dart';
import 'article_detail_screen.dart';
import 'video_player_screen.dart';
import 'youtube_screen.dart';
import 'contact_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final NewsService _newsService = NewsService();
  final YoutubeService _youtubeService = YoutubeService();
  final ScrollController _scrollController = ScrollController();

  List<Article> _heroArticles = [];
  List<Article> _allArticles = [];
  List<Article> _filteredArticles = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  String _selectedCategoryName = 'Todas';
  YoutubeVideo? _highlightVideo;
  List<YoutubeVideo> _youtubeVideos = [];
  bool _isNavigating = false;

  bool _isLoadingHero = true;
  bool _isLoadingList = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingHero = true;
      _isLoadingList = true;
    });

    // FASE 1: carrega notícias e categorias rapidamente (sem esperar YouTube)
    try {
      final newsFutures = await Future.wait([
        _newsService.fetchArticles(page: 1, perPage: 20),
        _newsService.fetchCategories(),
      ]);

      if (mounted) {
        setState(() {
          final allArticles = newsFutures[0] as List<Article>;
          _heroArticles = allArticles.take(5).toList();
          _allArticles = allArticles;
          _filteredArticles = allArticles;
          _categories = newsFutures[1] as List<Category>;
          _isLoadingHero = false;
          _isLoadingList = false;
          _currentPage = 1;
          _hasMore = true;
        });
        _fadeController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHero = false;
          _isLoadingList = false;
        });
      }
    }

    // FASE 2: carrega YouTube em segundo plano sem bloquear a tela
    _loadYoutubeVideos();
  }

  Future<void> _loadYoutubeVideos() async {
    try {
      final youtubeVideos = await _youtubeService.fetchChannelVideos();
      if (mounted) {
        setState(() {
          _youtubeVideos = youtubeVideos;
          final liveVideo = youtubeVideos.where((v) => v.isLive).firstOrNull;
          if (liveVideo != null) {
            _highlightVideo = liveVideo;
          } else {
            _highlightVideo = youtubeVideos
                .where((v) => !v.isLive && !v.isUpcoming)
                .firstOrNull;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final newArticles = await _newsService.fetchArticles(
      page: _currentPage + 1,
      perPage: 20,
      categoryId: _selectedCategoryId,
    );

    setState(() {
      if (newArticles.isEmpty) {
        _hasMore = false;
      } else {
        _filteredArticles.addAll(newArticles);
        _currentPage++;
      }
      _isLoadingMore = false;
    });
  }

  Future<void> _onRefresh() async {
    _newsService.clearCache();
    _fadeController.reset();
    _currentPage = 1;
    _hasMore = true;
    await _loadData();
  }

  Future<void> _filterByCategory(int? categoryId, String name) async {
    if (_selectedCategoryId == categoryId) return;

    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCategoryName = name;
      _isLoadingList = true;
      _currentPage = 1;
      _hasMore = true;
      _filteredArticles = [];
    });

    final articles = await _newsService.fetchArticles(
      page: 1,
      perPage: 20,
      categoryId: categoryId,
    );

    setState(() {
      _filteredArticles = articles;
      _isLoadingList = false;
    });
  }

  Future<void> _openArticle(Article article) async {
    if (_isNavigating) return;
    _isNavigating = true;

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ArticleDetailScreen(article: article),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    _isNavigating = false;
  }

  Future<void> _openVideo(YoutubeVideo video) async {
    if (_isNavigating) return;
    _isNavigating = true;

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VideoPlayerScreen(video: video),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    _isNavigating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppTheme.accentOrange,
          backgroundColor: AppTheme.cardColor,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(child: _buildHeroSection()),
              SliverToBoxAdapter(child: _buildTVIPlaySection()),
              SliverToBoxAdapter(child: _buildCategoryFilter()),
              SliverToBoxAdapter(child: _buildSectionTitle()),
              _buildArticleList(),
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentOrange,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: _buildFooterContactBanner()),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 0,
      backgroundColor: AppTheme.bgPrimary,
      elevation: 0,
      flexibleSpace: null,
      title: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/images/logo.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'XEH',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tv_rounded, color: AppTheme.accentOrange, size: 24),
          tooltip: 'TVI Play',
          onPressed: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const YoutubeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
          tooltip: 'Contato & Expediente',
          onPressed: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const ContactScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () => _showSearch(),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accentBlue, AppTheme.accentOrange, AppTheme.accentPurple],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    if (_isLoadingHero) {
      return Container(
        height: 330,
        color: AppTheme.shimmerBase,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentOrange),
        ),
      );
    }
    return HeroCarousel(
      articles: _heroArticles,
      highlightVideo: _highlightVideo,
      onTap: _openArticle,
      onTapVideo: _openVideo,
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            'Categorias',
            style: GoogleFonts.poppins(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryChip(null, 'Todas'),
              ..._categories.take(10).map(
                    (cat) => _buildCategoryChip(cat.id, cat.name),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCategoryChip(int? id, String name) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () => _filterByCategory(id, name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentOrange : const Color(0xFF1E1E22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentOrange
                : const Color(0xFF2C2C32),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentOrange.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            name,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : const Color(0xFFA0A0A5),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.accentOrange, AppTheme.accentRed],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _selectedCategoryName == 'Todas'
                ? 'Últimas Notícias'
                : _selectedCategoryName,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  SliverList _buildArticleList() {
    if (_isLoadingList) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildShimmerCard(),
          childCount: 5,
        ),
      );
    }

    if (_filteredArticles.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                const Icon(Icons.newspaper_rounded,
                    color: AppTheme.textMuted, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Nenhuma notícia encontrada',
                  style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final article = _filteredArticles[index];
          // Alterna entre card grande (a cada 4) e horizontal
          if (index % 5 == 0) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: NewsCard(
                article: article,
                onTap: () => _openArticle(article),
                isLarge: true,
              ),
            );
          }
          return FadeTransition(
            opacity: _fadeAnimation,
            child: NewsCardHorizontal(
              article: article,
              onTap: () => _openArticle(article),
            ),
          );
        },
        childCount: _filteredArticles.length,
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _shimmerBox(180),
          const SizedBox(height: 12),
          _shimmerBox(16, width: double.infinity),
          const SizedBox(height: 8),
          _shimmerBox(14, width: 200),
        ],
      ),
    );
  }

  Widget _shimmerBox(double height, {double? width}) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [AppTheme.shimmerBase, AppTheme.shimmerHighlight, AppTheme.shimmerBase],
      ).createShader(bounds),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppTheme.shimmerBase,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: _NewsSearchDelegate(_allArticles, _openArticle),
    );
  }

  Widget _buildTVIPlaySection() {
    if (_isLoadingHero || _youtubeVideos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Cabeçalho da seção
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppTheme.accentOrange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TVI Play',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const YoutubeScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentOrange,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver Tudo',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Lista horizontal de vídeos
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _youtubeVideos.length > 6 ? 6 : _youtubeVideos.length, // Mostra no máximo 6 vídeos na home
            itemBuilder: (context, index) {
              final video = _youtubeVideos[index];
              return _buildVideoCard(video);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(YoutubeVideo video) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (video.isLive) {
      badgeColor = AppTheme.accentOrange;
      badgeText = 'AO VIVO';
      badgeIcon = Icons.sensors_rounded;
    } else if (video.isUpcoming) {
      badgeColor = const Color(0xFF00ADB5); // Ciano moderno
      badgeText = 'EM BREVE';
      badgeIcon = Icons.upcoming_rounded;
    } else {
      badgeColor = const Color(0xFF555555); // Cinza grafite premium
      badgeText = 'GRAVAÇÃO';
      badgeIcon = Icons.videocam_rounded;
    }

    return GestureDetector(
      onTap: () => _openVideo(video),
      child: Container(
        width: 220,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail com cantos arredondados e Badge
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      video.thumbnailUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppTheme.bgSecondary,
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            color: Colors.white24,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black45],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Título do vídeo
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            // Detalhes (ex: data de publicação)
            Text(
              video.isLive ? 'Transmitindo agora' : video.publishedAt,
              style: GoogleFonts.poppins(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterContactBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.shimmerBase),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.newspaper_rounded, color: AppTheme.accentOrange, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TVI News • TV Itapê',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Jornalismo Regional de Itapetininga e Região',
                      style: GoogleFonts.poppins(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Informações editoriais, fontes jornalísticas, expediente da redação e canais diretos de contato com o veículo.',
            style: GoogleFonts.poppins(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.contact_mail_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Falar com a Redação / Contato',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsSearchDelegate extends SearchDelegate<Article?> {
  final List<Article> articles;
  final Function(Article) onSelect;

  _NewsSearchDelegate(this.articles, this.onSelect);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: AppTheme.bgPrimary,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.bgSecondary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.poppins(color: AppTheme.textSecondary),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = articles
        .where((a) => a.title.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (results.isEmpty) {
      return Container(
        color: AppTheme.bgPrimary,
        child: Center(
          child: Text(
            'Nenhum resultado para "$query"',
            style: GoogleFonts.poppins(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Container(
      color: AppTheme.bgPrimary,
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, index) {
          final article = results[index];
          return NewsCardHorizontal(
            article: article,
            onTap: () => onSelect(article),
          );
        },
      ),
    );
  }
}
