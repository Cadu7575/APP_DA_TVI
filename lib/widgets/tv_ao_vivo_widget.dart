import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../widgets/app_theme.dart';

/// URL HLS da TVitapê via XEH
const String _kXehHlsUrl =
    'https://stream01.msolutionbrasil.com.br/hls/tvitape/live.m3u8';

class TvAoVivoScreen extends StatefulWidget {
  const TvAoVivoScreen({super.key});

  @override
  State<TvAoVivoScreen> createState() => _TvAoVivoScreenState();
}

class _TvAoVivoScreenState extends State<TvAoVivoScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _videoController?.dispose();
      _chewieController?.dispose();

      final uri = Uri.parse(_kXehHlsUrl);
      _videoController = VideoPlayerController.networkUrl(uri);
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        aspectRatio: _videoController!.value.aspectRatio,
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: AppTheme.accentOrange),
          ),
        ),
        errorBuilder: (context, errorMessage) => _buildPlayerError(errorMessage),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.accentOrange,
          handleColor: AppTheme.accentOrange,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.grey.shade600,
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildPlayerError(String msg) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.signal_wifi_off_rounded,
                  color: Colors.white54, size: 40),
              const SizedBox(height: 12),
              Text(
                'Falha ao carregar o stream',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _initPlayer,
                icon: const Icon(Icons.refresh_rounded,
                    color: AppTheme.accentOrange),
                label: Text('Tentar novamente',
                    style: GoogleFonts.poppins(color: AppTheme.accentOrange)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Player Card TVitapê ───────────────────────────
        _buildTvCard(),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTvCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accentOrange.withValues(alpha: 0.7),
          width: 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentOrange.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do card
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Logo TVitapê
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tv_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TVitapê',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'xeh.com.br/tvitape',
                        style: GoogleFonts.poppins(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge AO VIVO piscante
                FadeTransition(
                  opacity: _blinkAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
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
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Player / Error / Loading
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _isLoading
                ? Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: AppTheme.accentOrange),
                          SizedBox(height: 12),
                          Text('Conectando ao stream...',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                : _hasError
                    ? Container(
                        color: Colors.black,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.signal_wifi_off_rounded,
                                    color: Colors.white54, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  'Stream indisponível',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'A TVitapê pode não estar transmitindo no momento.',
                                  style: GoogleFonts.poppins(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  onPressed: _initPlayer,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentOrange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 16),
                                  label: Text('Tentar Novamente',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Chewie(controller: _chewieController!),
          ),
        ],
      ),
    );
  }
}
