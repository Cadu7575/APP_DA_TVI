import 'dart:io';

void main() {
  final file = File('C:\\Users\\Carlos\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev\\youtube_player_flutter-9.1.3\\lib\\src\\player\\raw_youtube_player.dart');
  final lines = file.readAsLinesSync();
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].contains('userAgent')) {
      print('${i + 1}: ${lines[i]}');
    }
  }
}
