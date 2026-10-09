import 'package:flutter_test/flutter_test.dart';
import 'package:gravdesinghub/services/updater_service.dart';

void main() {
  group('UpdaterService Version Comparison Tests', () {
    test('Should return true if latest version is newer (patch update)', () {
      expect(UpdaterService.isNewerVersion('1.0.0', '1.0.1'), isTrue);
    });

    test('Should return true if latest version is newer (minor update)', () {
      expect(UpdaterService.isNewerVersion('1.0.0', '1.1.0'), isTrue);
    });

    test('Should return true if latest version is newer (major update)', () {
      expect(UpdaterService.isNewerVersion('1.0.0', '2.0.0'), isTrue);
    });

    test('Should return false if versions are identical', () {
      expect(UpdaterService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
    });

    test('Should return false if current version is newer', () {
      expect(UpdaterService.isNewerVersion('1.0.1', '1.0.0'), isFalse);
      expect(UpdaterService.isNewerVersion('2.0.0', '1.9.9'), isFalse);
    });

    test('Should handle shorter version strings correctly', () {
      expect(UpdaterService.isNewerVersion('1.0', '1.0.1'), isTrue);
      expect(UpdaterService.isNewerVersion('1.0.1', '1.1'), isTrue);
      expect(UpdaterService.isNewerVersion('1.1', '1.0'), isFalse);
    });

    test('Should handle invalid format string comparison fallback', () {
      expect(UpdaterService.isNewerVersion('1.0.0', '1.0.0-beta'), isTrue);
      expect(UpdaterService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
    });
  });

  group('UpdaterService.parseGithubRelease', () {
    Map<String, dynamic> release({
      String tag = 'v1.0.9',
      String? body = 'Novedades de prueba',
      List<String> assets = const ['GravisDesignHUB.apk', 'GravisDesignHUB-windows.zip'],
      bool draft = false,
      bool prerelease = false,
    }) =>
        {
          'tag_name': tag,
          'body': body,
          'draft': draft,
          'prerelease': prerelease,
          'assets': [
            for (final name in assets)
              {'name': name, 'browser_download_url': 'https://github.com/x/y/releases/download/$tag/$name'},
          ],
        };

    test('Android toma el APK y quita la v del tag', () {
      final info = UpdaterService.parseGithubRelease(release(), windows: false)!;
      expect(info['latestVersion'], '1.0.9');
      expect(info['downloadUrl'], endsWith('/GravisDesignHUB.apk'));
      expect(info['changelog'], 'Novedades de prueba');
    });

    test('Windows toma el zip', () {
      final info = UpdaterService.parseGithubRelease(release(), windows: true)!;
      expect(info['downloadUrl'], endsWith('/GravisDesignHUB-windows.zip'));
    });

    test('Si falta el instalador de la plataforma ofrece la página de la release', () {
      final info = UpdaterService.parseGithubRelease(
        release(assets: ['GravisDesignHUB.apk']),
        windows: true,
      )!;
      expect(info['downloadUrl'], UpdaterService.latestReleasePageUrl);
    });

    test('Sin novedades usa el texto por defecto', () {
      final info = UpdaterService.parseGithubRelease(release(body: '  '), windows: false)!;
      expect(info['changelog'], isNotEmpty);
    });

    test('Ignora borradores, prereleases y tags que no son versiones', () {
      expect(UpdaterService.parseGithubRelease(release(draft: true), windows: false), isNull);
      expect(UpdaterService.parseGithubRelease(release(prerelease: true), windows: false), isNull);
      expect(UpdaterService.parseGithubRelease(release(tag: 'nightly'), windows: false), isNull);
      expect(UpdaterService.parseGithubRelease(release(tag: ''), windows: false), isNull);
      expect(UpdaterService.parseGithubRelease({}, windows: false), isNull);
    });
  });

  group('UpdaterService.isUsableDownloadUrl', () {
    test('Rechaza enlaces que solo funcionan en la PC del desarrollador', () {
      expect(UpdaterService.isUsableDownloadUrl('http://127.0.0.1:8000/app-release.apk'), isFalse);
      expect(UpdaterService.isUsableDownloadUrl('http://localhost:8000/app-release.apk'), isFalse);
      expect(UpdaterService.isUsableDownloadUrl('http://192.168.1.20/app.apk'), isFalse);
      expect(UpdaterService.isUsableDownloadUrl('http://10.0.0.5/app.apk'), isFalse);
      expect(UpdaterService.isUsableDownloadUrl('http://172.16.4.1/app.apk'), isFalse);
      expect(UpdaterService.isUsableDownloadUrl('http://equipo.local/app.apk'), isFalse);
    });

    test('Rechaza texto que no es un enlace web', () {
      expect(UpdaterService.isUsableDownloadUrl(''), isFalse);
      expect(UpdaterService.isUsableDownloadUrl('app-release.apk'), isFalse);
      expect(UpdaterService.isUsableDownloadUrl('ftp://example.com/app.apk'), isFalse);
    });

    test('Acepta enlaces públicos, incluido el permanente de GitHub', () {
      expect(UpdaterService.isUsableDownloadUrl(UpdaterService.latestApkUrl), isTrue);
      expect(UpdaterService.isUsableDownloadUrl('https://example.com/app.apk'), isTrue);
      expect(UpdaterService.isUsableDownloadUrl('http://172.32.0.1/app.apk'), isTrue);
    });
  });
}
