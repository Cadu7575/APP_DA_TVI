import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';


class YoutubeVideo {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String publishedAt;
  final String videoUrl;

  /// true SOMENTE se o vídeo estiver ao vivo AGORA (verificado via /live)
  final bool isLive;

  /// true se estiver agendado para o futuro (upcoming/em breve)
  final bool isUpcoming;

  YoutubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.videoUrl,
    this.isLive = false,
    this.isUpcoming = false,
  });

  String get youtubeWatchUrl => 'https://www.youtube.com/watch?v=$id';
  String get embedUrl => 'https://www.youtube.com/embed/$id?autoplay=1';
}

class YoutubeService {
  static const String _channelHandle = 'tvitape2';
  static const String _rssFeedBaseUrl =
      'https://www.youtube.com/feeds/videos.xml';

  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
    'Cookie': 'PREF=tz=America/Sao_Paulo',
  };

  static List<YoutubeVideo>? _cachedVideos;
  static DateTime? _cacheTime;

  /// Busca vídeos do canal + verifica ao vivo real
  Future<List<YoutubeVideo>> fetchChannelVideos() async {
    // Cache de 3 minutos (curto para detectar início de ao vivo rapidamente)
    if (_cachedVideos != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 3) {
      return _cachedVideos!;
    }

    // 1. Tenta buscar a live ativa registrada no Firestore (imediato e sem bloqueio de CORS na web)
    // Verifica TANTO o last_live (dados do vídeo) QUANTO o live_status (se realmente está ao vivo)
    YoutubeVideo? liveAtivaFirestore;
    try {
      // Busca ambos documentos em paralelo
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('system_settings')
            .doc('last_live')
            .get(),
        FirebaseFirestore.instance
            .collection('system_settings')
            .doc('live_status')
            .get(),
      ]);

      final docLastLive = results[0];
      final docLiveStatus = results[1];

      // Verifica se live_status confirma que está realmente ao vivo
      bool isRealmenteAoVivo = false;
      if (docLiveStatus.exists) {
        final statusData = docLiveStatus.data()!;
        final isLive = statusData['isLive'] as bool? ?? false;
        final lastChecked = statusData['lastCheckedAt'];

        if (isLive) {
          // Verifica se o lastCheckedAt não está muito velho (>10 min = possivelmente offline)
          if (lastChecked != null) {
            DateTime? checkedTime;
            if (lastChecked is Timestamp) {
              checkedTime = lastChecked.toDate();
            }
            if (checkedTime != null &&
                DateTime.now().difference(checkedTime).inMinutes <= 10) {
              isRealmenteAoVivo = true;
            } else if (checkedTime == null) {
              // Se não conseguiu parsear o timestamp, confia no isLive
              isRealmenteAoVivo = true;
            }
          } else {
            // Sem lastCheckedAt mas isLive=true, confia
            isRealmenteAoVivo = true;
          }
        }
      }

      if (isRealmenteAoVivo && docLastLive.exists) {
        final data = docLastLive.data()!;
        final vId = data['videoId'] as String?;
        final vTitle = data['title'] as String? ?? ' Ao Vivo na TVI';
        if (vId != null && vId.isNotEmpty) {
          liveAtivaFirestore = YoutubeVideo(
            id: vId,
            title: vTitle,
            description: '',
            thumbnailUrl: 'https://i.ytimg.com/vi/$vId/hqdefault.jpg',
            publishedAt: 'Ao vivo agora',
            videoUrl: 'https://www.youtube.com/watch?v=$vId',
            isLive: true,
          );
        }
      }
    } catch (_) {}

    try {
      final url = 'https://www.youtube.com/@$_channelHandle/streams';
      final response = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final html = response.body;
        final startPattern = 'ytInitialData = ';
        final startIndex = html.indexOf(startPattern);
        if (startIndex != -1) {
          final jsonStart = startIndex + startPattern.length;
          final scriptEndIndex = html.indexOf('</script>', jsonStart);
          if (scriptEndIndex != -1) {
            var jsonEnd = html.lastIndexOf(';', scriptEndIndex);
            if (jsonEnd == -1 || jsonEnd < jsonStart) {
              jsonEnd = scriptEndIndex;
            }
            final jsonStr = html.substring(jsonStart, jsonEnd).trim();
            final data = json.decode(jsonStr);

            final List<Map<String, dynamic>> lockups = [];

            void findLockups(dynamic node) {
              if (node is Map) {
                if (node.containsKey('lockupViewModel')) {
                  lockups.add(Map<String, dynamic>.from(node['lockupViewModel']));
                } else {
                  for (final val in node.values) {
                    findLockups(val);
                  }
                }
              } else if (node is List) {
                for (final val in node) {
                  findLockups(val);
                }
              }
            }

            findLockups(data);

            final List<YoutubeVideo> parsedVideos = [];

            for (final l in lockups) {
              final videoId = l['contentId'] as String?;
              final metadata = l['metadata']?['lockupMetadataViewModel'];
              final title = metadata?['title']?['content'] as String? ?? '';

              if (videoId == null || videoId.isEmpty || title.isEmpty) continue;

              // Extrai imagem
              String thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
              final sources = l['contentImage']?['thumbnailViewModel']?['image']?['sources'] as List?;
              if (sources != null && sources.isNotEmpty) {
                thumbnailUrl = sources.last['url'] as String? ?? thumbnailUrl;
              }

              // Verifica badges (LIVE / UPCOMING)
              bool isLive = false;
              bool isUpcoming = false;
              final overlays = l['contentImage']?['thumbnailViewModel']?['overlays'] as List?;
              if (overlays != null) {
                for (final o in overlays) {
                  final badge = o['thumbnailBottomOverlayViewModel']?['badges']?[0]?['thumbnailBadgeViewModel'];
                  if (badge != null) {
                    final text = badge['text'] as String? ?? '';
                    final style = badge['badgeStyle'] as String? ?? '';
                    if (text == 'Em breve' || style.contains('UPCOMING')) {
                      isUpcoming = true;
                    } else if (text == 'Ao vivo' || text == 'AO VIVO' || style.contains('LIVE')) {
                      isLive = true;
                    }
                  }
                }
              }

              // Extrai metadados (views, data relativa, agendamento)
              String publishedAt = '';
              final metaRows = metadata?['metadata']?['contentMetadataViewModel']?['metadataRows'] as List?;
              if (metaRows != null && metaRows.isNotEmpty) {
                final parts = metaRows[0]['metadataParts'] as List?;
                if (parts != null) {
                  final texts = parts
                      .map((p) => p['text']?['content'] as String?)
                      .where((t) => t != null && t.isNotEmpty)
                      .cast<String>()
                      .toList();
                  publishedAt = texts.join(' • ');
                  if (texts.any((t) => t.contains('Programado para'))) {
                    isUpcoming = true;
                  }
                }
              }

              parsedVideos.add(YoutubeVideo(
                id: videoId,
                title: title,
                description: '',
                thumbnailUrl: thumbnailUrl,
                publishedAt: publishedAt,
                videoUrl: 'https://www.youtube.com/watch?v=$videoId',
                isLive: isLive,
                isUpcoming: isUpcoming,
              ));
            }

            if (parsedVideos.isNotEmpty) {
              // Se o scraping encontrou vídeos mas nenhum ao vivo,
              // e o Firestore diz que há live ativa, injeta no topo
              if (liveAtivaFirestore != null &&
                  !parsedVideos.any((v) => v.isLive) &&
                  !parsedVideos.any((v) => v.id == liveAtivaFirestore!.id)) {
                parsedVideos.insert(0, liveAtivaFirestore!);
              }
              _cachedVideos = parsedVideos;
              _cacheTime = DateTime.now();
              return parsedVideos;
            }
          }
        }
      }
    } catch (e) {
      // Fallback para RSS em caso de falha de conexão ou parser
    }

    final fallback = await _fetchRssVideos();

    // Se o RSS retornou vídeos e tem live ativa no Firestore, injeta no topo
    if (liveAtivaFirestore != null &&
        !fallback.any((v) => v.isLive) &&
        !fallback.any((v) => v.id == liveAtivaFirestore!.id)) {
      fallback.insert(0, liveAtivaFirestore!);
    }

    _cachedVideos = fallback;
    _cacheTime = DateTime.now();
    return fallback;
  }

  /// Busca lista de vídeos via RSS feed
  Future<List<YoutubeVideo>> _fetchRssVideos() async {
    try {
      final channelId = await _getChannelId();
      if (channelId == null) return [];

      final rssUrl = '$_rssFeedBaseUrl?channel_id=$channelId';
      final response = await http.get(
        Uri.parse(rssUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return _parseRssFeed(response.body);
      }
    } catch (_) {}
    return [];
  }

  Future<String?> _getChannelId() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.youtube.com/@$_channelHandle'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;
        final channelIdRegex = RegExp(r'"channelId":"(UC[a-zA-Z0-9_-]{22})"');
        final match = channelIdRegex.firstMatch(body);
        if (match != null) return match.group(1);

        final metaRegex = RegExp(r'channel_id=(UC[a-zA-Z0-9_-]{22})');
        final metaMatch = metaRegex.firstMatch(body);
        if (metaMatch != null) return metaMatch.group(1);
      }
    } catch (_) {}
    return null;
  }

  List<YoutubeVideo> _parseRssFeed(String xmlContent) {
    final List<YoutubeVideo> videos = [];

    try {
      final document = XmlDocument.parse(xmlContent);
      final entries = document.findAllElements('entry');

      for (final entry in entries) {
        final videoId =
            entry.findElements('yt:videoId').firstOrNull?.innerText;
        final title = entry.findElements('title').firstOrNull?.innerText;
        final published =
            entry.findElements('published').firstOrNull?.innerText;
        final mediaGroup =
            entry.findElements('media:group').firstOrNull;
        final description = mediaGroup
            ?.findElements('media:description')
            .firstOrNull
            ?.innerText;
        final thumbnailEl =
            mediaGroup?.findElements('media:thumbnail').firstOrNull;
        final thumbnailUrl = thumbnailEl?.getAttribute('url');

        if (videoId == null || title == null) continue;

        final thumb = thumbnailUrl ??
            'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

        // NÃO detecta ao vivo pelo título — apenas pela verificação real
        // Detecta apenas "upcoming" por datas futuras ou indicadores do título
        final isUpcoming = _isUpcomingByTitle(title, published);

        videos.add(YoutubeVideo(
          id: videoId,
          title: title,
          description: description ?? '',
          thumbnailUrl: thumb,
          publishedAt: published ?? '',
          videoUrl: 'https://www.youtube.com/watch?v=$videoId',
          isLive: false, // será atualizado depois se necessário
          isUpcoming: isUpcoming,
        ));
      }
    } catch (_) {}

    return videos;
  }

  /// Heurística simples para detectar streams agendados pelo título
  bool _isUpcomingByTitle(String title, String? published) {
    if (published == null) return false;
    try {
      final pubDate = DateTime.parse(published);
      // Se a data de publicação for no futuro, é um agendado
      if (pubDate.isAfter(DateTime.now())) return true;
    } catch (_) {}
    return false;
  }

  void clearCache() {
    _cachedVideos = null;
    _cacheTime = null;
  }

  static String formatPublishedDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'agora mesmo';
      if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'há ${diff.inHours}h';
      if (diff.inDays == 1) return 'ontem';
      if (diff.inDays < 7) return 'há ${diff.inDays} dias';

      final months = [
        'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
        'jul', 'ago', 'set', 'out', 'nov', 'dez'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return '';
    }
  }
}
