import 'dart:io';

void main() {
  final file = File('android/app/google-services.json');
  if (file.existsSync()) {
    print('Found google-services.json:');
    print(file.readAsStringSync());
  } else {
    print('google-services.json not found in android/app/');
  }
}
