import 'dart:io';

void main() {
  final hostedDir = Directory('C:\\Users\\Carlos\\AppData\\Local\\Pub\\Cache\\hosted\\pub.dev');
  if (hostedDir.existsSync()) {
    final matches = hostedDir.listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.contains('youtube_player_flutter') && f.path.endsWith('.dart'));
    for (var f in matches) {
      if (f.path.contains('youtube_player.dart') || f.path.contains('raw_youtube_player.dart')) {
        print('Found: ${f.path}');
        final contents = f.readAsStringSync();
        if (contents.contains('userAgent')) {
          print('Contains userAgent!');
        } else {
          print('Does not contain userAgent.');
        }
      }
    }
  } else {
    print('Hosted dir not found.');
  }
}
