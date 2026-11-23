import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../models/category.dart';
import '../../models/expense.dart';
import '../../models/theme_config.dart';
import '../../providers/app_providers.dart';
import '../../services/image_service.dart';
import '../../utils/color_utils.dart';
import '../../utils/date_utils_ext.dart';
import '../../widgets/expense_card.dart';
import '../../widgets/image_cropper_page.dart';

class ThemeEditorScreen extends ConsumerStatefulWidget {
  final AppThemeRecord themeRecord;
  final bool isNew;

  const ThemeEditorScreen({
    super.key,
    required this.themeRecord,
    required this.isNew,
  });

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  static const _uuid = Uuid();
  late TextEditingController _nameCtrl;
  late ThemeConfig _config;
  bool _keepLossless = false; // Default OFF: Smart HD compression
  bool _previewRestDay = false;
  String? _previewCatId;
  bool _saving = false;

  static const _colorPalette = [
    '#FF4F46E5',
    '#FF818CF8',
    '#FF2563EB',
    '#FF38BDF8',
    '#FF10B981',
    '#FF34D399',
    '#FFEF4444',
    '#FFF87171',
    '#FFF59E0B',
    '#FFD97706',
    '#FF8B5CF6',
    '#FFA78BFA',
    '#FFEC4899',
    '#FF14B8A6',
    '#FF64748B',
    '#FFCBD5E1',
    '#FF334155',
    '#FF0F172A',
    '#E6FFFFFF',
    '#CC1E293B',
    '#00000000',
    '#14F59E0B',
    '#1F38BDF8',
    '#1FF59E0B',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.themeRecord.name);
    _config = widget.themeRecord.config;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List?> _pickImageBytes() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery);
      if (xfile == null) return null;
      return xfile.readAsBytes();
    } else {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image);
      if (picked == null || picked.files.single.path == null) return null;
      return File(picked.files.single.path!).readAsBytes();
    }
  }

  Future<void> _pickAndCropGlobalBackground() async {
    final raw = await _pickImageBytes();
    if (raw == null || !mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageCropperPage(
          imageBytes: raw,
          initialAspectRatio: 9 / 16,
          title: '裁剪全局背景图 (9:16 或自由比例)',
          allowFreeRatio: true,
        ),
      ),
    );
    if (cropped == null || !mounted) return;

    final savedPath = await ImageService.saveThemeImage(
      themeId: widget.themeRecord.id,
      croppedBytes: cropped,
      isGlobalBg: true,
      keepLossless: _keepLossless,
      prefix: 'global_bg',
    );
    setState(() {
      _config = _config.copyWith(
        globalStyle: _config.globalStyle.copyWith(backgroundImagePath: savedPath),
      );
    });
  }

  Future<void> _pickAndCropCategoryBackground(ExpenseCategory cat) async {
    final raw = await _pickImageBytes();
    if (raw == null || !mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageCropperPage(
          imageBytes: raw,
          initialAspectRatio: 16 / 5,
          title: '裁剪「${cat.name}」卡片底图 (16:5)',
          allowFreeRatio: true,
        ),
      ),
    );
    if (cropped == null || !mounted) return;

    final savedPath = await ImageService.saveThemeImage(
      themeId: widget.themeRecord.id,
      croppedBytes: cropped,
      isGlobalBg: false,
      keepLossless: _keepLossless,
      prefix: 'cat_${cat.id.hashCode.abs()}',
    );
    final currentStyle = _config.styleForCategory(
      categoryId: cat.id,
      categoryName: cat.name,
      defaultColorHex: cat.defaultColorHex,
    );
    final updatedStyle = currentStyle.copyWith(backgroundImagePath: savedPath);
    final updatedMap =
        Map<String, CategoryStyleConfig>.from(_config.categoryStyles)
          ..[cat.id] = updatedStyle;
    final updatedPool = List<CardStylePreset>.from(_config.cardStylePool)
      ..add(
        CardStylePreset(
          id: 'preset_${_uuid.v4().substring(0, 8)}',
          name: cat.name,
          defaultCategory: cat.name,
          style: updatedStyle,
        ),
      );
    setState(() {
      _config = _config.copyWith(
        categoryStyles: updatedMap,
        cardStylePool: updatedPool,
      );
    });
  }

  Future<void> _applyPresetToCategoryDialog(ExpenseCategory cat) async {
    final pool = _config.cardStylePool;
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前主题候选库为空，可先裁剪卡片图或导入主题包')),
      );
      return;
    }

    final chosen = await showDialog<CardStylePreset>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('为「${cat.name}」套用候选样式'),
        content: SizedBox(
          width: 420,
          height: 360,
          child: ListView.separated(
            itemCount: pool.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final preset = pool[i];
              return _CandidatePresetPreviewTile(
                preset: preset,
                isDarkText: _config.globalStyle.isDarkText,
                surfaceColor: _config.globalStyle.surface,
                onTap: () => Navigator.of(ctx).pop(preset),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (chosen == null) return;

    final updatedMap =
        Map<String, CategoryStyleConfig>.from(_config.categoryStyles)
          ..[cat.id] = chosen.style;
    setState(() {
      _config = _config.copyWith(categoryStyles: updatedMap);
      _previewCatId = cat.id;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将「${chosen.name}」套用到「${cat.name}」')),
      );
    }
  }

  Future<void> _bindPresetToAnyCategoryDialog(
    CardStylePreset preset,
    List<ExpenseCategory> categories,
  ) async {
    final targetCat = await showDialog<ExpenseCategory>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('将「${preset.name}」一键绑定到类别'),
        children: categories
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(c.name, style: const TextStyle(fontSize: 15)),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (targetCat == null) return;

    final updatedMap =
        Map<String, CategoryStyleConfig>.from(_config.categoryStyles)
          ..[targetCat.id] = preset.style;
    setState(() {
      _config = _config.copyWith(categoryStyles: updatedMap);
      _previewCatId = targetCat.id;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将「${preset.name}」绑定到「${targetCat.name}」')),
      );
    }
  }

  Future<String?> _showColorPickerDialog(String title, String initialHex) async {
    final hexCtrl = TextEditingController(text: initialHex);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorPalette.map((hex) {
                  final color = ColorUtils.fromHex(hex);
                  return GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hex.toUpperCase() == initialHex.toUpperCase()
                              ? Colors.black
                              : Colors.grey.shade400,
                          width: hex.toUpperCase() == initialHex.toUpperCase()
                              ? 3
                              : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: hexCtrl,
                decoration: const InputDecoration(
                  labelText: '或输入 ARGB Hex（如 #FF4F46E5）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(hexCtrl.text.trim()),
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTheme() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('主题名称不能为空')),
      );
      return;
    }
    setState(() => _saving = true);
    final updated = widget.themeRecord.copyWith(
      name: name,
      config: _config,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(appControllerProvider.notifier).saveTheme(updated);
    if (widget.isNew) {
      await ref
          .read(appControllerProvider.notifier)
          .bindThemeToCurrentUser(updated.id);
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('主题「$name」已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final categories = state.categories;
    final previewCat = categories.firstWhere(
      (c) => c.id == _previewCatId,
      orElse: () => categories.first,
    );
    _previewCatId = previewCat.id;

    final now = DateTime.now();
    final sampleExpense = Expense(
      id: 'preview',
      userId: 'preview',
      amount: 128.50,
      categoryId: previewCat.id,
      timestamp: now.millisecondsSinceEpoch,
      dateStr: DateUtilsExt.toDateStr(now),
      isRestDay: _previewRestDay,
      note: '午餐便当',
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? '新建主题' : '编辑主题'),
        actions: [
          FilledButton.icon(
            onPressed: _saving ? null : _saveTheme,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('保存主题'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Lossless Toggle at top of Theme Workshop Editor
          Card(
            child: SwitchListTile(
              title: const Text(
                '保留无损原图',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _keepLossless ? '已开启：保存裁剪后原图' : '默认关闭：自动高清压缩以提升滚动流畅度',
                style: const TextStyle(fontSize: 12),
              ),
              value: _keepLossless,
              onChanged: (v) => setState(() => _keepLossless = v),
            ),
          ),
          const SizedBox(height: 10),

          // Live Preview Box
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '实时账单卡片预览',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('工作日')),
                          ButtonSegment(value: true, label: Text('休息日')),
                        ],
                        selected: {_previewRestDay},
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        onSelectionChanged: (s) =>
                            setState(() => _previewRestDay = s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: categories.map((c) {
                      return ChoiceChip(
                        label: Text(c.name, style: const TextStyle(fontSize: 11.5)),
                        selected: c.id == previewCat.id,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _previewCatId = c.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _config.globalStyle.isDarkText
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ExpenseCard(
                      expense: sampleExpense,
                      category: previewCat,
                      themeConfig: _config,
                      currencyPrefix: state.settings.displayCurrency,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Theme Name & Global Style
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. 全局视觉配置',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '主题名称',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('使用深色文字与图标（适合浅色/亮色背景）'),
                    value: _config.globalStyle.isDarkText,
                    onChanged: (v) => setState(() {
                      _config = _config.copyWith(
                        globalStyle:
                            _config.globalStyle.copyWith(isDarkText: v),
                      );
                    }),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final hex = await _showColorPickerDialog(
                              '选择全局主色调',
                              _config.globalStyle.primaryColor,
                            );
                            if (hex != null) {
                              setState(() {
                                _config = _config.copyWith(
                                  globalStyle: _config.globalStyle
                                      .copyWith(primaryColor: hex),
                                );
                              });
                            }
                          },
                          icon: Icon(
                            Icons.circle,
                            color: _config.globalStyle.primary,
                            size: 16,
                          ),
                          label: const Text('主色调'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final hex = await _showColorPickerDialog(
                              '选择卡片默认底色',
                              _config.globalStyle.surfaceColor,
                            );
                            if (hex != null) {
                              setState(() {
                                _config = _config.copyWith(
                                  globalStyle: _config.globalStyle
                                      .copyWith(surfaceColor: hex),
                                );
                              });
                            }
                          },
                          icon: Icon(
                            Icons.circle,
                            color: _config.globalStyle.surface,
                            size: 16,
                          ),
                          label: const Text('卡片底色'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _pickAndCropGlobalBackground,
                          icon: const Icon(Icons.wallpaper_rounded, size: 18),
                          label: Text(
                            _config.globalStyle.backgroundImagePath != null
                                ? '更换全局背景图'
                                : '选择并裁剪全局背景图',
                          ),
                        ),
                      ),
                      if (_config.globalStyle.backgroundImagePath != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '清除全局背景图',
                          onPressed: () => setState(() {
                            _config = _config.copyWith(
                              globalStyle: _config.globalStyle
                                  .copyWith(clearBackgroundImage: true),
                            );
                          }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '全局背景模糊度：${_config.globalStyle.bgBlurSigma.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Slider(
                    value: _config.globalStyle.bgBlurSigma.clamp(0.0, 25.0),
                    min: 0,
                    max: 25,
                    onChanged: (v) => setState(() {
                      _config = _config.copyWith(
                        globalStyle:
                            _config.globalStyle.copyWith(bgBlurSigma: v),
                      );
                    }),
                  ),
                  Text(
                    '全局背景遮罩不透明度：${(_config.globalStyle.bgOverlayOpacity * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Slider(
                    value:
                        _config.globalStyle.bgOverlayOpacity.clamp(0.0, 0.9),
                    min: 0,
                    max: 0.9,
                    onChanged: (v) => setState(() {
                      _config = _config.copyWith(
                        globalStyle:
                            _config.globalStyle.copyWith(bgOverlayOpacity: v),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Workday / Rest-Day Styles
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2. 工作日 / 休息日卡片区分样式',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildDayStyleEditor(
                    title: '工作日样式',
                    style: _config.dayTypeStyle.workday,
                    onChanged: (s) => setState(() {
                      _config = _config.copyWith(
                        dayTypeStyle: _config.dayTypeStyle.copyWith(workday: s),
                      );
                    }),
                  ),
                  const Divider(height: 20),
                  _buildDayStyleEditor(
                    title: '休息日样式',
                    style: _config.dayTypeStyle.restDay,
                    onChanged: (s) => setState(() {
                      _config = _config.copyWith(
                        dayTypeStyle: _config.dayTypeStyle.copyWith(restDay: s),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Per-Category Styles (including permanent '未分类')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3. 各类别专属主题色与卡片背景图（含「未分类」）',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...categories.map((cat) {
                    final style = _config.styleForCategory(
                      categoryId: cat.id,
                      categoryName: cat.name,
                      defaultColorHex: cat.defaultColorHex,
                    );
                    void updateCatStyle(CategoryStyleConfig next) {
                      final map = Map<String, CategoryStyleConfig>.from(
                        _config.categoryStyles,
                      )..[cat.id] = next;
                      setState(() {
                        _config = _config.copyWith(categoryStyles: map);
                      });
                    }

                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: style.color,
                      ),
                      title: Text(
                        cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        style.backgroundImagePath != null
                            ? '已配卡片背景图 · 模糊 ${style.cardBlurSigma.toStringAsFixed(1)}'
                            : '纯色卡片 · 主题色 ${style.themeColor}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final hex = await _showColorPickerDialog(
                                  '选择「${cat.name}」主题色',
                                  style.themeColor,
                                );
                                if (hex != null) {
                                  updateCatStyle(
                                    style.copyWith(themeColor: hex),
                                  );
                                }
                              },
                              icon: Icon(
                                Icons.circle,
                                color: style.color,
                                size: 15,
                              ),
                              label: const Text('主题色'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  _pickAndCropCategoryBackground(cat),
                              icon: const Icon(Icons.image_outlined, size: 16),
                              label: Text(
                                style.backgroundImagePath != null
                                    ? '更换卡片图'
                                    : '裁剪卡片图',
                              ),
                            ),
                            if (_config.cardStylePool.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _applyPresetToCategoryDialog(cat),
                                icon: const Icon(
                                  Icons.collections_bookmark_outlined,
                                  size: 16,
                                ),
                                label: const Text('从候选库套用'),
                              ),
                            if (style.backgroundImagePath != null)
                              IconButton(
                                tooltip: '移除卡片背景图',
                                onPressed: () => updateCatStyle(
                                  style.copyWith(clearBackgroundImage: true),
                                ),
                                icon: const Icon(Icons.delete_outline, size: 19),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '卡片背景模糊度：${style.cardBlurSigma.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        Slider(
                          value: style.cardBlurSigma.clamp(0.0, 20.0),
                          min: 0,
                          max: 20,
                          onChanged: (v) =>
                              updateCatStyle(style.copyWith(cardBlurSigma: v)),
                        ),
                        Text(
                          '卡片遮罩不透明度：${(style.cardOverlayOpacity * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        Slider(
                          value: style.cardOverlayOpacity.clamp(0.0, 0.9),
                          min: 0,
                          max: 0.9,
                          onChanged: (v) => updateCatStyle(
                            style.copyWith(cardOverlayOpacity: v),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Collapsible Theme Candidate Card Style Pool
          Card(
            child: ExpansionTile(
              title: Text(
                '4. 主题候选库 (${_config.cardStylePool.length} 套)',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                '已收录的卡片样式套装，可随时一键绑定到任意本地类别',
                style: TextStyle(fontSize: 12),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: _config.cardStylePool.isEmpty
                  ? [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '暂无候选样式。导入主题包或从相册裁剪卡片图后会自动收录于此。',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ]
                  : _config.cardStylePool.map((preset) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CandidatePresetPreviewTile(
                          preset: preset,
                          isDarkText: _config.globalStyle.isDarkText,
                          surfaceColor: _config.globalStyle.surface,
                          onTap: () =>
                              _bindPresetToAnyCategoryDialog(preset, categories),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                onPressed: () => _bindPresetToAnyCategoryDialog(
                                  preset,
                                  categories,
                                ),
                                child: const Text(
                                  '绑定',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                tooltip: '从候选库移除',
                                icon: const Icon(Icons.delete_outline, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _config = _config.copyWith(
                                      cardStylePool: _config.cardStylePool
                                          .where((p) => p.id != preset.id)
                                          .toList(),
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDayStyleEditor({
    required String title,
    required DayTypeItemStyle style,
    required ValueChanged<DayTypeItemStyle> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: style.badgeText,
                decoration: const InputDecoration(
                  labelText: '角标文字',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => onChanged(style.copyWith(badgeText: v)),
              ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'solid', label: Text('实线')),
                ButtonSegment(value: 'dashed', label: Text('虚线')),
              ],
              selected: {style.borderStyle},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (s) =>
                  onChanged(style.copyWith(borderStyle: s.first)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final hex =
                    await _showColorPickerDialog('$title角标底色', style.badgeColor);
                if (hex != null) onChanged(style.copyWith(badgeColor: hex));
              },
              icon: Icon(Icons.circle, color: style.badgeColorObj, size: 15),
              label: const Text('角标色'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final hex = await _showColorPickerDialog(
                  '$title边框颜色',
                  style.borderColor,
                );
                if (hex != null) onChanged(style.copyWith(borderColor: hex));
              },
              icon: Icon(Icons.circle, color: style.borderColorObj, size: 15),
              label: const Text('边框色'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final hex = await _showColorPickerDialog(
                  '$title底色冷暖叠加色',
                  style.tintOverlayColor,
                );
                if (hex != null) {
                  onChanged(style.copyWith(tintOverlayColor: hex));
                }
              },
              icon: Icon(
                Icons.circle,
                color: style.tintOverlayColorObj,
                size: 15,
              ),
              label: const Text('叠加色调'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '边框宽度：${style.borderWidth.toStringAsFixed(1)} px',
          style: const TextStyle(fontSize: 11.5),
        ),
        Slider(
          value: style.borderWidth.clamp(0.0, 4.0),
          min: 0,
          max: 4,
          divisions: 8,
          onChanged: (v) => onChanged(style.copyWith(borderWidth: v)),
        ),
      ],
    );
  }
}

class _CandidatePresetPreviewTile extends StatelessWidget {
  final CardStylePreset preset;
  final bool isDarkText;
  final Color surfaceColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _CandidatePresetPreviewTile({
    required this.preset,
    required this.isDarkText,
    required this.surfaceColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final style = preset.style;
    final bgPath = style.backgroundImagePath;
    final hasBg =
        bgPath != null && bgPath.isNotEmpty && File(bgPath).existsSync();
    final overlayColor = (isDarkText ? Colors.white : Colors.black)
        .withOpacity(style.cardOverlayOpacity.clamp(0.0, 0.92));
    final textColor =
        isDarkText ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: style.color.withOpacity(0.55),
                width: 1.2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasBg)
                  Image(
                    image: ResizeImage.resizeIfNeeded(
                      640,
                      null,
                      FileImage(File(bgPath)),
                    ),
                    fit: BoxFit.cover,
                  )
                else
                  ColoredBox(color: surfaceColor),
                if (hasBg && style.cardBlurSigma > 0.1)
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: style.cardBlurSigma,
                      sigmaY: style.cardBlurSigma,
                    ),
                    child: const SizedBox.expand(),
                  ),
                if (hasBg) ColoredBox(color: overlayColor),
                Row(
                  children: [
                    Container(width: 6, color: style.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '${preset.defaultCategory != null ? "默认：${preset.defaultCategory} · " : ""}${hasBg ? "含背景图" : "纯色"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textColor.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      trailing!,
                      const SizedBox(width: 6),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.touch_app_rounded,
                          size: 18,
                          color: style.color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
