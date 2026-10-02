class LaikaServer {
  const LaikaServer({
    required this.id,
    required this.name,
    required this.url,
    required this.key,
  });

  final String id;
  final String name;
  final String url;
  final String key;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'key': key,
      };

  factory LaikaServer.fromJson(Map<String, dynamic> json) {
    return LaikaServer(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      key: json['key'] as String,
    );
  }
}
