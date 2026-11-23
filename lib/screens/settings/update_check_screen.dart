import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/update_checker_service.dart';

class UpdateCheckScreen extends StatefulWidget {
  const UpdateCheckScreen({super.key});

  @override
  State<UpdateCheckScreen> createState() => _UpdateCheckScreenState();
}

class _UpdateCheckScreenState extends State<UpdateCheckScreen> {
  bool _checking = false;
  UpdateCheckResult? _result;
  String? _error;

  Future<void> _runCheck() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final res = await UpdateCheckerService.checkForUpdates();
      if (mounted) {
        setState(() {
          _result = res;
          _checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _checking = false;
        });
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final ok = await UpdateCheckerService.tryOpenInBrowser(url);
    if (!ok && mounted) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制链接，请在浏览器中粘贴打开')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final res = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('检查更新')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '基米记账',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '当前版本 v${UpdateCheckerService.currentVersion}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _checking ? null : _runCheck,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(_checking ? '正在连接 GitHub 检查...' : '立即检查更新'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Card(
              color: cs.errorContainer.withOpacity(0.45),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '检查更新失败',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.error,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(_error!, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
            ),
          if (res != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          res.hasUpdate
                              ? Icons.new_releases_rounded
                              : Icons.check_circle_rounded,
                          color: res.hasUpdate ? cs.primary : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            res.hasUpdate
                                ? '发现新版本 v${res.latestVersion}'
                                : '当前已是最新版本',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (res.releaseNotes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        res.releaseNotes,
                        style: const TextStyle(fontSize: 13, height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openUrl(res.downloadUrl),
                            icon: const Icon(Icons.open_in_new_rounded, size: 17),
                            label: Text(res.hasUpdate ? '前往仓库下载' : '打开仓库'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: res.downloadUrl),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已复制仓库链接')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('复制链接'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('GitHub 仓库地址'),
              subtitle: const Text(
                UpdateCheckerService.repoUrl,
                style: TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: '复制地址',
                icon: const Icon(Icons.copy_outlined, size: 19),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: UpdateCheckerService.repoUrl),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制 GitHub 仓库地址')),
                    );
                  }
                },
              ),
              onTap: () => _openUrl(UpdateCheckerService.repoUrl),
            ),
          ),
        ],
      ),
    );
  }
}
