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
          
          bool found = false;
          
          void search(dynamic node, List<String> path) {
            if (found) return;
            if (node is Map) {
              if (node.containsKey('upcomingEventData')) {
                // ignore: avoid_print
                print('Found upcomingEventData at path: ${path.join(' -> ')}');
                // ignore: avoid_print
                print('Value: ${node['upcomingEventData']}');
                found = true;
                return;
              }
              node.forEach((key, val) {
                search(val, [...path, key.toString()]);
              });
            } else if (node is List) {
              for (int i = 0; i < node.length; i++) {
                search(node[i], [...path, '[$i]']);
              }
            }
          }
          search(data, ['root']);
          if (!found) {
            // ignore: avoid_print
            print('upcomingEventData not found in JSON');
          }
        } catch (e) {
          // ignore: avoid_print
          print('Erro: $e');
        }
      }
    }
  }
}
