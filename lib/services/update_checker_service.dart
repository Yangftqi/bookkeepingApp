import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class UpdateCheckResult {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String downloadUrl;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

class UpdateCheckerService {
  static const String currentVersion = '1.2.1';
  static const String repoUrl = 'https://github.com/Yangftqi/bookkeepingApp';
  static const String releasesUrl =
      'https://github.com/Yangftqi/bookkeepingApp/releases';

  /// Manually checks GitHub for a newer release or higher version in pubspec.yaml.
  /// Never called automatically on startup to preserve offline-first behavior.
  static Future<UpdateCheckResult> checkForUpdates() async {
    // 1. Check GitHub Releases API first
    try {
      final apiUri = Uri.parse(
        'https://api.github.com/repos/Yangftqi/bookkeepingApp/releases/latest',
      );
      final resp = await http.get(
        apiUri,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final rawTag = (data['tag_name'] as String?)?.trim() ?? '';
        final cleanVer = _cleanVersion(rawTag);
        if (cleanVer.isNotEmpty) {
          final newer = isNewerVersion(cleanVer, currentVersion);
          return UpdateCheckResult(
            hasUpdate: newer,
            currentVersion: currentVersion,
            latestVersion: cleanVer,
            releaseNotes: (data['body'] as String?)?.trim() ?? '',
            downloadUrl: (data['html_url'] as String?)?.trim() ?? releasesUrl,
          );
        }
      }
    } catch (_) {
      // Fall through to raw pubspec check
    }

    // 2. Fallback: Check main branch pubspec.yaml
    final rawUri = Uri.parse(
      'https://raw.githubusercontent.com/Yangftqi/bookkeepingApp/main/pubspec.yaml',
    );
    final rawResp =
        await http.get(rawUri).timeout(const Duration(seconds: 12));
    if (rawResp.statusCode == 200) {
      final text = utf8.decode(rawResp.bodyBytes);
      final match =
          RegExp(r'^version:\s*([^\s+#]+)', multiLine: true).firstMatch(text);
      final remoteVer = _cleanVersion(match?.group(1) ?? currentVersion);
      final newer = isNewerVersion(remoteVer, currentVersion);
      return UpdateCheckResult(
        hasUpdate: newer,
        currentVersion: currentVersion,
        latestVersion: remoteVer,
        releaseNotes: newer ? 'GitHub 仓库发现新版本 v$remoteVer，可前往仓库下载最新安装包。' : '',
        downloadUrl: repoUrl,
      );
    }

    throw Exception('无法连接至 GitHub 仓库（HTTP ${rawResp.statusCode}），请检查网络连接');
  }

  static String _cleanVersion(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    final plusIdx = s.indexOf('+');
    if (plusIdx != -1) {
      s = s.substring(0, plusIdx);
    }
    return s.trim();
  }

  static bool isNewerVersion(String remote, String local) {
    final rParts = _cleanVersion(remote)
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final lParts = _cleanVersion(local)
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final len = rParts.length > lParts.length ? rParts.length : lParts.length;
    for (var i = 0; i < len; i++) {
      final r = i < rParts.length ? rParts[i] : 0;
      final l = i < lParts.length ? lParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }

  /// Opens [url] in the system browser where supported on desktop/mobile.
  static Future<bool> tryOpenInBrowser(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
        return true;
      } else if (Platform.isAndroid) {
        const channel = MethodChannel('com.yangftqi.bookkeeping_app/launcher');
        final ok = await channel.invokeMethod<bool>('openUrl', {'url': url});
        return ok == true;
      }
    } catch (_) {}
    return false;
  }
}
