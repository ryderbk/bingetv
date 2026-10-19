import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Site {
  const Site({required this.name, required this.url});

  final String name;
  final String url;

  String get host => Uri.tryParse(url)?.host ?? url;
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  Map<String, String> toJson() => {'name': name, 'url': url};

  static Site fromJson(Map<String, dynamic> json) => Site(
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

class SiteStore {
  static const _key = 'binge_sites';
  static const defaults = [
    Site(name: 'BingeBang', url: 'https://bingebang.st/'),
    Site(name: 'Rivestream', url: 'https://rivestream.ru/'),
  ];

  Future<List<Site>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return defaults;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return defaults;
      final sites = decoded
          .whereType<Map<String, dynamic>>()
          .map(Site.fromJson)
          .where((site) => site.name.trim().isNotEmpty && site.url.isNotEmpty)
          .toList();
      return sites.isEmpty ? defaults : sites;
    } on FormatException {
      return defaults;
    }
  }

  Future<void> save(List<Site> sites) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(sites.map((site) => site.toJson()).toList()),
    );
  }

  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
