import 'package:flutter/foundation.dart' show kIsWeb;

class ImageUtils {
  /// Retorna a URL da imagem otimizada com proxy CORS se estiver rodando na web.
  static String getOptimizedImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return '';
    if (kIsWeb) {
      // Remove o protocolo https:// ou http://
      final cleanUrl = originalUrl
          .replaceFirst('https://', '')
          .replaceFirst('http://', '');
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(cleanUrl)}';
    }
    return originalUrl;
  }

  /// Processa o HTML do artigo para usar o proxy de imagens quando rodando na web.
  static String processHtmlContent(String htmlContent) {
    if (!kIsWeb) return htmlContent;
    
    // Expressão regular para encontrar caminhos de imagens em tags <img>
    final regExp = RegExp(
      r'''src=["'](https?://xeh\.com\.br/wp-content/uploads/[^"']+)["']''',
      caseSensitive: false,
    );

    return htmlContent.replaceAllMapped(regExp, (match) {
      final originalSrc = match.group(1);
      if (originalSrc != null) {
        final proxyUrl = getOptimizedImageUrl(originalSrc);
        return 'src="$proxyUrl"';
      }
      return match.group(0) ?? '';
    });
  }
}
