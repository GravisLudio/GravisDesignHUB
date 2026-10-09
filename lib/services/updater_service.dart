import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Busca versiones nuevas y devuelve el enlace de descarga.
///
/// Fuente principal: la ultima "release" publicada en GitHub (el enlace de
/// descarga es fijo y no caduca). Respaldo: el documento `config/version` de
/// Firestore, que usan las versiones antiguas de la app.
class UpdaterService {
  /// Debe coincidir con la version de pubspec.yaml (publicar-version.ps1 lo comprueba).
  static const String currentVersion = '1.0.8';

  static const String githubRepo = 'GravisLudio/GravisDesignHUB';

  /// Nombres fijos de los instaladores dentro de cada release.
  static const String apkAssetName = 'GravisDesignHUB.apk';
  static const String windowsAssetName = 'GravisDesignHUB-windows.zip';

  /// Enlaces permanentes: siempre sirven la ultima release publicada.
  static const String latestApkUrl =
      'https://github.com/$githubRepo/releases/latest/download/$apkAssetName';
  static const String latestWindowsUrl =
      'https://github.com/$githubRepo/releases/latest/download/$windowsAssetName';
  static const String latestReleasePageUrl =
      'https://github.com/$githubRepo/releases/latest';

  static const String _defaultChangelog =
      'Mejoras de rendimiento y corrección de errores.';

  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;

  /// Retorna un mapa con la info de la versión si hay una nueva versión disponible, de lo contrario null.
  ///
  /// Claves: `latestVersion`, `downloadUrl`, `changelog`.
  Future<Map<String, dynamic>?> checkForUpdate() async {
    final release = await _fetchGithubRelease();
    if (release != null) {
      // GitHub respondio: es la fuente de verdad, aunque no haya nada nuevo.
      return isNewerVersion(currentVersion, release['latestVersion'] as String)
          ? release
          : null;
    }
    // Sin red hacia GitHub, o aun no hay releases: respaldo en Firestore.
    return _checkFirestore();
  }

  Future<Map<String, dynamic>?> _fetchGithubRelease() async {
    if (kIsWeb) return null;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'))
          .timeout(const Duration(seconds: 8));
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'GravisDesignHUB-updater');
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      return parseGithubRelease(json, windows: Platform.isWindows);
    } catch (e) {
      debugPrint('No se pudo consultar GitHub: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _checkFirestore() async {
    if (!isFirebaseAvailable) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('version').get();
      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      final latest = data['latestVersion'] as String?;
      final downloadUrl = data['downloadUrl'] as String?;
      final changelog = data['changelog'] as String? ?? _defaultChangelog;

      if (latest == null || downloadUrl == null) return null;

      if (isNewerVersion(currentVersion, latest)) {
        return {
          'latestVersion': latest,
          // Nunca ofrecer un enlace que solo funciona en la PC del desarrollador.
          'downloadUrl':
              isUsableDownloadUrl(downloadUrl) ? downloadUrl : latestReleasePageUrl,
          'changelog': changelog,
        };
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  /// Convierte la respuesta de GitHub (`releases/latest`) en la info de actualización.
  ///
  /// Devuelve null si la respuesta no trae una versión válida. Si la release no
  /// incluye el instalador de esta plataforma, ofrece la página de la release
  /// (que siempre existe) en vez de un enlace roto.
  @visibleForTesting
  static Map<String, dynamic>? parseGithubRelease(
    Map<String, dynamic> json, {
    required bool windows,
  }) {
    if (json['draft'] == true || json['prerelease'] == true) return null;

    var version = (json['tag_name'] as String?)?.trim() ?? '';
    if (version.startsWith('v') || version.startsWith('V')) {
      version = version.substring(1);
    }
    if (!RegExp(r'^\d+(\.\d+)*$').hasMatch(version)) return null;

    final wanted = windows ? windowsAssetName : apkAssetName;
    String? assetUrl;
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map && asset['name'] == wanted) {
          assetUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    final body = (json['body'] as String?)?.trim();
    return {
      'latestVersion': version,
      'downloadUrl': assetUrl ?? latestReleasePageUrl,
      'changelog': (body == null || body.isEmpty) ? _defaultChangelog : body,
    };
  }

  /// Un enlace sirve a los usuarios solo si es http(s) y no apunta a la propia
  /// máquina ni a una red local (ej. `http://127.0.0.1:8000/...` de pruebas).
  @visibleForTesting
  static bool isUsableDownloadUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasAuthority) return false;
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty || host == 'localhost' || host.endsWith('.local')) return false;
    if (host == '::1' || host == '0.0.0.0') return false;
    final ip = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(host);
    if (ip != null) {
      final a = int.parse(ip.group(1)!);
      final b = int.parse(ip.group(2)!);
      if (a == 10 || a == 127 || a == 0) return false;
      if (a == 192 && b == 168) return false;
      if (a == 172 && b >= 16 && b <= 31) return false;
      if (a == 169 && b == 254) return false;
    }
    return true;
  }

  static bool isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (var i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) {
          return latestParts[i] > 0;
        }
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (_) {
      return current != latest;
    }
    return false;
  }
}
