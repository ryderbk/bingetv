import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Site {
  const Site({required this.name, required this.url, this.pageWidth = 1280});

  final String name;
  final String url;
  final int pageWidth;

  String get host => Uri.tryParse(url)?.host ?? url;
  String get initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  Site copyWith({String? name, String? url, int? pageWidth}) => Site(
    name: name ?? this.name,
    url: url ?? this.url,
    pageWidth: pageWidth ?? this.pageWidth,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'pageWidth': pageWidth,
  };

  static Site fromJson(Map<String, dynamic> json) => Site(
    name: json['name'] as String? ?? '',
    url: json['url'] as String? ?? '',
    pageWidth: (json['pageWidth'] as num?)?.toInt() ?? 1280,
  );
}

class SiteStore {
  static const _keySites = 'binge_sites';
  static const _keyLastSite = 'binge_last_opened_site';
  static const _keyOpenLastOnStart = 'binge_open_last_on_start';
  static const _keyAdBlockEnabled = 'binge_ad_block_enabled';
  static const _keyBlocklist = 'binge_ad_blocklist';

  static const defaults = [
    Site(name: 'BingeBang', url: 'https://bingebang.st/', pageWidth: 1280),
    Site(name: 'Rivestream', url: 'https://rivestream.ru/', pageWidth: 1280),
  ];

  static const defaultBlocklist = [
    '*doubleclick.net*',
    '*googlesyndication.com*',
    '*googleadservices.com*',
    '*popads.net*',
    '*popcash.net*',
    '*adsterra.com*',
    '*propellerads.com*',
    '*exoclick.com*',
    '*juicyads.com*',
    '*trafficjunky.net*',
    '*bet365*',
    '*1xbet*',
  ];

  Future<List<Site>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_keySites);
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
      _keySites,
      jsonEncode(sites.map((site) => site.toJson()).toList()),
    );
  }

  Future<void> updateSitePageWidth(String url, int pageWidth) async {
    final sites = await load();
    final updated = sites
        .map((s) => s.url == url ? s.copyWith(pageWidth: pageWidth) : s)
        .toList();
    await save(updated);
  }

  Future<void> reset() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_keySites);
  }

  Future<String?> getLastOpenedSite() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_keyLastSite);
  }

  Future<void> setLastOpenedSite(String url) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_keyLastSite, url);
  }

  Future<bool> getOpenLastOnStart() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keyOpenLastOnStart) ?? false;
  }

  Future<void> setOpenLastOnStart(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_keyOpenLastOnStart, value);
  }

  Future<bool> isAdBlockEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_keyAdBlockEnabled) ?? true;
  }

  Future<void> setAdBlockEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_keyAdBlockEnabled, value);
  }

  Future<List<String>> getBlocklist() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_keyBlocklist) ?? defaultBlocklist;
  }

  Future<void> setBlocklist(List<String> list) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_keyBlocklist, list);
  }
}
