class LaikaServer {
  const LaikaServer({
    required this.id,
    required this.name,
    required this.url,
    required this.key,
    this.altUrls = const [],
  });

  final String id;
  final String name;
  final String url;
  final String key;
  final List<String> altUrls;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'key': key,
    'alt_urls': altUrls,
  };

  factory LaikaServer.fromJson(Map<String, dynamic> json) {
    final rawAltUrls = json['alt_urls'];
    final altUrls = rawAltUrls is List
        ? rawAltUrls.whereType<String>().toList()
        : <String>[];
    return LaikaServer(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      key: json['key'] as String,
      altUrls: altUrls,
    );
  }
}
