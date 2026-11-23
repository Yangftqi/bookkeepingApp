import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../widgets/glass_surface.dart';
import 'ai_analyst_view.dart';
import 'economics_compare_view.dart';

class InsightsTab extends ConsumerWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final subTab = state.insightsSubTab;
    final themeCfg = state.activeTheme.config;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: GlassSurface(
            themeConfig: themeCfg,
            padding: const EdgeInsets.all(6),
            borderRadius: 14,
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.public_rounded, size: 18),
                    label: Text('经济学数据对比'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.psychology_rounded, size: 18),
                    label: Text('AI 账单分析师'),
                  ),
                ],
                selected: {subTab},
                onSelectionChanged: (s) => ref
                    .read(appControllerProvider.notifier)
                    .setInsightsSubTab(s.first),
              ),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: subTab,
            children: const [
              EconomicsCompareView(),
              AiAnalystView(),
            ],
          ),
        ),
      ],
    );
  }
}
