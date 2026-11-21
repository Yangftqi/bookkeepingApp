import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import 'ai_analyst_view.dart';
import 'economics_compare_view.dart';

class InsightsTab extends ConsumerWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final subTab = state.insightsSubTab;
    final g = state.activeTheme.config.globalStyle;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: g.surface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
            ),
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
