class Article {
  final int id;
  final String title;
  final String excerpt;
  final String content;
  final String date;
  final String link;
  final String? imageUrl;
  final String? categoryName;
  final int? categoryId;
  final String author;
  final String publisher;

  Article({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.date,
    required this.link,
    this.imageUrl,
    this.categoryName,
    this.categoryId,
    this.author = 'Redação TV Itapê',
    this.publisher = 'TV Itapê (xeh.com.br)',
  });

  factory Article.fromJson(Map<String, dynamic> json, {String? imageUrl, String? categoryName, int? categoryId, String? author, String? publisher}) {
    String rawTitle = json['title']?['rendered'] ?? '';
    String rawExcerpt = json['excerpt']?['rendered'] ?? '';
    String rawContent = json['content']?['rendered'] ?? '';

    return Article(
      id: json['id'] ?? 0,
      title: _stripHtml(rawTitle),
      excerpt: _stripHtml(rawExcerpt),
      content: rawContent,
      date: json['date'] ?? '',
      link: json['link'] ?? '',
      imageUrl: imageUrl,
      categoryName: categoryName,
      categoryId: categoryId,
      author: (author != null && author.isNotEmpty) ? author : 'Redação TV Itapê',
      publisher: (publisher != null && publisher.isNotEmpty) ? publisher : 'TV Itapê (xeh.com.br)',
    );
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&#8216;', ''')
        .replaceAll('&#8217;', ''')
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .trim();
  }
}

class Category {
  final int id;
  final String name;
  final int count;

  Category({required this.id, required this.name, required this.count});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}
