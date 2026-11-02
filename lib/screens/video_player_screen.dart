import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/partida.dart';
import '../services/partidas_service.dart';
import '../services/youtube_service.dart';
import '../widgets/app_theme.dart';
import 'campeonatos/partida_detail_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final YoutubeVideo video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with SingleTickerProviderStateMixin {
  late YoutubePlayerController _controller;
  TabController? _tabController;

  Partida? _partidaVinculada;
  bool _buscandoPartida = true;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.id,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        isLive: false,
        enableCaption: false,
        forceHD: true,
        loop: false,
        hideControls: false,
        controlsVisibleAtStart: true,
      ),
    );

    _buscarPartidaCorrespondente();
  }

  Future<void> _buscarPartidaCorrespondente() async {
    try {
      final p = await PartidasService.instance.encontrarPartidaPorVideo(
        videoId: widget.video.id,
        videoTitle: widget.video.title,
      );
      if (mounted) {
        setState(() {
          _partidaVinculada = p;
          _buscandoPartida = false;
          if (p != null) {
            _tabController = TabController(length: 3, vsync: this);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _buscandoPartida = false);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _openOnYoutube() async {
    final uri = Uri.parse(widget.video.youtubeWatchUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildPlacarAoVivo(Partida partida) {
    final bool isLive = partida.status == StatusPartida.emAndamento;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive
              ? AppTheme.accentOrange.withOpacity(0.5)
              : const Color(0xFF2A2A2E),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isLive
                ? AppTheme.accentOrange.withOpacity(0.12)
                : Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (partida.categoria != null && partida.categoria!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                partida.categoria!.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              // Time A
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        partida.timeANome,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildEscudo(partida.timeALogo, partida.timeANome),
                  ],
                ),
              ),

              // Placar Central
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLive
                          ? AppTheme.accentOrange
                          : const Color(0xFF333338),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (isLive)
                        BoxShadow(
                          color: AppTheme.accentOrange.withOpacity(0.25),
                          blurRadius: 8,
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${partida.placarA ?? 0}',
                        style: GoogleFonts.poppins(
                          color: isLive ? Colors.white : const Color(0xFFE0E0E0),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'x',
                          style: GoogleFonts.poppins(
                            color: isLive ? AppTheme.accentOrange : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${partida.placarB ?? 0}',
                        style: GoogleFonts.poppins(
                          color: isLive ? Colors.white : const Color(0xFFE0E0E0),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Time B
              Expanded(
                child: Row(
                  children: [
                    _buildEscudo(partida.timeBLogo, partida.timeBNome),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        partida.timeBNome,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEscudo(String? url, String teamName) {
    if (url != null && url.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentOrange),
            ),
            errorWidget: (_, __, ___) => _buildFallbackAvatar(teamName),
          ),
        ),
      );
    }
    return _buildFallbackAvatar(teamName);
  }

  Widget _buildFallbackAvatar(String name) {
    final letra = name.isNotEmpty ? name[0].toUpperCase() : 'T';
    return CircleAvatar(
      radius: 16,
      backgroundColor: const Color(0xFF2A2A2E),
      child: Text(
        letra,
        style: GoogleFonts.poppins(
          color: AppTheme.accentOrange,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildVideoDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge AO VIVO ou data
        Row(
          children: [
            if (widget.video.isLive) ...[
              _LiveBadge(),
              const Spacer(),
            ] else if (widget.video.publishedAt.isNotEmpty) ...[
              const Icon(Icons.calendar_today_rounded,
                  size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.video.publishedAt,
                  style: GoogleFonts.poppins(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: 8),
            // Botão compartilhar
            IconButton(
              icon: const Icon(Icons.share_rounded,
                  color: AppTheme.textSecondary, size: 20),
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: widget.video.youtubeWatchUrl));
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
        const SizedBox(height: 8),

        // Título do vídeo
        Text(
          widget.video.title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 14),

        // Info do canal
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppTheme.accentOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tv_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TVI Tape 2',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@tvitape2',
                    style: GoogleFonts.poppins(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _openOnYoutube,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentOrange,
                side: const BorderSide(color: AppTheme.accentOrange, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: Text(
                'YouTube',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),

        // Descrição
        if (widget.video.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(color: AppTheme.shimmerBase, height: 1),
          const SizedBox(height: 12),
          Text(
            'Descrição',
            style: GoogleFonts.poppins(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.video.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: const Color(0xFFCCCCCC),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      },
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppTheme.accentOrange,
        liveUIColor: AppTheme.accentOrange,
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: AppTheme.bgPrimary,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra superior
                Padding(
                  padding: const EdgeInsets.only(
                      left: 4, right: 12, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Player de Vídeo
                player,

                // Conteúdo inferior com suporte à Partida em tempo real
                Expanded(
                  child: _buscandoPartida
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accentOrange),
                        )
                      : _partidaVinculada != null
                          ? _buildComPartida(_partidaVinculada!)
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: _buildVideoDetails(),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComPartida(Partida pInicial) {
    return StreamBuilder<Partida?>(
      initialData: pInicial,
      stream: PartidasService.instance.getPartida(
        pInicial.campeonatoId,
        pInicial.id,
      ),
      builder: (context, snap) {
        final partida = snap.data ?? pInicial;

        return Column(
          children: [
            // Placar da Partida vinculada
            _buildPlacarAoVivo(partida),

            // TabBar para Lances, Escalação e Transmissão
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                labelColor: AppTheme.accentOrange,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: AppTheme.accentOrange,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Lances'),
                  Tab(text: 'Escalação'),
                  Tab(text: 'Detalhes'),
                ],
              ),
            ),

            // Conteúdo das Abas
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Aba Lances
                  AbaLances(
                    campeonatoId: partida.campeonatoId,
                    partidaId: partida.id,
                    partida: partida,
                  ),

                  // Aba Escalação
                  AbaEscalacao(
                    campeonatoId: partida.campeonatoId,
                    partida: partida,
                  ),

                  // Aba Detalhes do Vídeo
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildVideoDetails(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Badge piscante "AO VIVO"
class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange,
          borderRadius: BorderRadius.circular(4),
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
            const SizedBox(width: 5),
            Text(
              'AO VIVO',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
