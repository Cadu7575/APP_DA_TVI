import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = 'https://www.youtube.com/@tvitape2/streams';
  final response = await http.get(Uri.parse(url), headers: {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
  });

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
        try {
          final data = json.decode(jsonStr);
          
          final tab = data['contents']?['twoColumnBrowseResultsRenderer']?['tabs']?[3];
          final contents = tab?['tabRenderer']?['content']?['richGridRenderer']?['contents'];
          if (contents != null && contents.isNotEmpty) {
            final firstItem = contents[0];
            final lockup = firstItem['richItemRenderer']?['content']?['lockupViewModel'];
            if (lockup != null) {
              // ignore: avoid_print
              print('--- lockupViewModel Keys ---');
              // ignore: avoid_print
              print(lockup.keys.toList());
              // ignore: avoid_print
              print('----------------------------');
              
              // ignore: avoid_print
              print('--- metadata ---');
              print(const JsonEncoder.withIndent('  ').convert(lockup['metadata']));
              
              print('--- contentImage (Without buttons/toggle) ---');
              final contentImage = Map.from(lockup['contentImage']);
              // Clear overlays to avoid too much verbosity, keep badges
              final overlays = contentImage['thumbnailViewModel']?['overlays'] as List?;
              if (overlays != null) {
                final cleanedOverlays = [];
                for (final o in overlays) {
                  if (o.containsKey('thumbnailBottomOverlayViewModel')) {
                    cleanedOverlays.add(o);
                  }
                }
                contentImage['thumbnailViewModel']['overlays'] = cleanedOverlays;
              }
              print(const JsonEncoder.withIndent('  ').convert(contentImage));
            }
          }
        } catch (e) {
          print('Erro: $e');
        }
      }
    }
  }
}
