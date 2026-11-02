import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';

class NewsService {
  static const String _baseUrl = 'https://xeh.com.br/wp-json/wp/v2';
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json',
  };

  // Cache simples com expiração de tempo
  static final Map<String, List<Article>> _articleCache = {};
  static final Map<String, DateTime> _articleCacheTime = {};
  static List<Category> _categoryCache = [];
  static DateTime? _categoryCacheTime;

  static const Duration _cacheDuration = Duration(minutes: 2);

  Future<List<Category>> fetchCategories() async {
    // Cache válido por 2 minutos
    if (_categoryCache.isNotEmpty &&
        _categoryCacheTime != null &&
        DateTime.now().difference(_categoryCacheTime!) < _cacheDuration) {
      return _categoryCache;
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/categories?per_page=20&hide_empty=true'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _categoryCache = data.map((e) => Category.fromJson(e)).toList();
        _categoryCache.sort((a, b) => b.count.compareTo(a.count));
        _categoryCacheTime = DateTime.now();
        return _categoryCache;
      }
    } catch (e) {
      // retorna lista padrão em caso de erro
      if (_categoryCache.isNotEmpty) return _categoryCache;
    }
    return [];
  }

  Future<List<Article>> fetchArticles({
    int page = 1,
    int perPage = 20,
    int? categoryId,
  }) async {
    final cacheKey = '${categoryId ?? 'all'}_${page}_$perPage';
    // Cache válido por 2 minutos
    final cacheTime = _articleCacheTime[cacheKey];
    if (_articleCache.containsKey(cacheKey) &&
        cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheDuration) {
      return _articleCache[cacheKey]!;
    }

    try {
      String url = '$_baseUrl/posts?per_page=$perPage&page=$page&_embed=1';
      if (categoryId != null) url += '&categories=$categoryId';

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final articles = data.map((json) {
          String? imageUrl;
          String? categoryName;
          int? catId;

          String? authorName;

          // Extrai imagem e autor do _embedded
          try {
            final embedded = json['_embedded'];
            if (embedded != null) {
              final featuredMedia = embedded['wp:featuredmedia'];
              if (featuredMedia != null && featuredMedia.isNotEmpty) {
                imageUrl = featuredMedia[0]['source_url'];
              }
              final terms = embedded['wp:term'];
              if (terms != null && terms.isNotEmpty) {
                final cats = terms[0];
                if (cats != null && cats.isNotEmpty) {
                  categoryName = cats[0]['name'];
                  catId = cats[0]['id'];
                }
              }
              final authorList = embedded['author'];
              if (authorList != null && authorList.isNotEmpty) {
                authorName = authorList[0]['name'];
              }
            }
          } catch (_) {}

          return Article.fromJson(json,
              imageUrl: imageUrl,
              categoryName: categoryName,
              categoryId: catId,
              author: authorName);
        }).toList();

        _articleCache[cacheKey] = articles;
        _articleCacheTime[cacheKey] = DateTime.now();
        return articles;
      }
    } catch (e) {
      // retorna cache anterior (mesmo vencido) em caso de erro de rede
      if (_articleCache.containsKey(cacheKey)) return _articleCache[cacheKey]!;
    }
    return [];
  }

  void clearCache() {
    _articleCache.clear();
    _categoryCache.clear();
  }
}
