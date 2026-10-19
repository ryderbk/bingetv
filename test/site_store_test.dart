import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:binge/services/site_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SiteStore Tests', () {
    late SiteStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = SiteStore();
    });

    test('loads default sites when no saved preferences exist', () async {
      final sites = await store.load();
      expect(sites.length, 2);
      expect(sites[0].name, 'BingeBang');
      expect(sites[0].url, 'https://bingebang.st/');
      expect(sites[1].name, 'Rivestream');
      expect(sites[1].url, 'https://rivestream.ru/');
    });

    test('saves and reloads custom sites', () async {
      final custom = [
        const Site(
          name: 'TestSite',
          url: 'https://testsite.com/',
          pageWidth: 1600,
        ),
      ];
      await store.save(custom);
      final loaded = await store.load();
      expect(loaded.length, 1);
      expect(loaded[0].name, 'TestSite');
      expect(loaded[0].url, 'https://testsite.com/');
      expect(loaded[0].pageWidth, 1600);
    });

    test('resets saved sites back to defaults', () async {
      await store.save([
        const Site(name: 'Temporary', url: 'https://temp.org/'),
      ]);
      expect((await store.load()).length, 1);

      await store.reset();
      final reloaded = await store.load();
      expect(reloaded.length, 2);
      expect(reloaded[0].name, 'BingeBang');
    });

    test('persists last opened site URL', () async {
      expect(await store.getLastOpenedSite(), isNull);
      await store.setLastOpenedSite('https://rivestream.ru/');
      expect(await store.getLastOpenedSite(), 'https://rivestream.ru/');
    });

    test('persists open last on start setting', () async {
      expect(await store.getOpenLastOnStart(), isFalse);
      await store.setOpenLastOnStart(true);
      expect(await store.getOpenLastOnStart(), isTrue);
    });

    test('updates and persists per-site page width setting', () async {
      await store.updateSitePageWidth('https://bingebang.st/', 1920);
      final sites = await store.load();
      final bb = sites.firstWhere((s) => s.url == 'https://bingebang.st/');
      expect(bb.pageWidth, 1920);
    });

    test('persists ad-block toggle and blocklist rules', () async {
      expect(await store.isAdBlockEnabled(), isTrue);
      await store.setAdBlockEnabled(false);
      expect(await store.isAdBlockEnabled(), isFalse);

      final customRules = [r'.*ads\.com.*', r'.*track\.org.*'];
      await store.setBlocklist(customRules);
      expect(await store.getBlocklist(), customRules);
    });
  });
}
