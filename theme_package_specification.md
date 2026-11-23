# 「基米记账」主题包 (`.themepkg.zip`) 制作与美学设计规范 (Human & AI-Ready Spec)

> **适用对象**：视觉设计师、主题创作者、以及辅助生成主题包的代码/多模态 AI。
> **文档目标**：提供零歧义的 `.themepkg.zip` 目录结构、`theme.json` 字段定义、图层渲染公式、跨设备类别自动对齐机制及实战美学调优指南，让你可以在 5 分钟内制作出可直接导入「基米记账」的高颜值主题包。

---

## 1. 主题包文件结构与打包铁律

「基米记账」主题包是一个标准的 `.zip` 压缩文件，推荐以 **`.themepkg.zip`**（或 `.zip`）作为后缀名。

### 1.1 标准目录树
```text
my_custom_theme.themepkg.zip
├── theme.json                 # 【必需】位于压缩包根目录的主题配置清单（UTF-8 编码）
└── assets/                    # 【可选】存放全局背景图与各类别卡片背景图
    ├── global_bg.jpg          # 全局背景图（建议 9:16 竖屏）
    ├── cat_food.jpg           # “吃的”类别卡片背景图（建议 16:5 横幅）
    ├── cat_use.jpg            # “用的”类别卡片背景图
    ├── cat_play.jpg           # “玩的”类别卡片背景图
    └── cat_uncategorized.jpg  # “未分类”类别卡片背景图
```

### 1.2 三条打包硬性约束（AI 生成必读）
1. **禁止套壳顶层文件夹**：`theme.json` **必须直接位于 ZIP 根目录**，不能打包成 `my_theme/theme.json`。
2. **`assets/` 下图片文件名必须全局唯一**：App 导入解压时会将 `assets/<filename>` 提取到主题专属目录并取 `basename`（文件名+扩展名），因此切勿使用子目录同名文件（如 `assets/a/bg.jpg` 和 `assets/b/bg.jpg`），应命名为 `assets/global_bg.jpg`、`assets/cat_0.jpg`、`assets/cat_1.jpg` 等唯一文件名。
3. **路径分隔符统一用正斜杠 `/`**：在 `theme.json` 中引用图片时，必须使用相对路径 `"assets/<文件名>"`（如 `"assets/global_bg.jpg"`），禁止使用反斜杠 `\` 或本地绝对路径；若某处不使用图片，必须设为 `null`。

---

## 2. 渲染管线与图层叠加公式（理解每个参数如何影响画面）

在调配颜色、模糊度与不透明度前，请先理解 App 内部真实的多层渲染顺序：

### 2.1 全局页面背景渲染栈（从底到顶）
```text
[顶层] 页面 UI 内容（顶部栏 AppBar、账单卡片列表、统计图表、底部导航栏）
  ▲
[第3层] 全局可读性纯色遮罩 (bgOverlayOpacity)
        • 当 isDarkText == true（浅色主题）：叠加纯白 #FFFFFF，不透明度 = bgOverlayOpacity
        • 当 isDarkText == false（深色主题）：叠加纯黑 #000000，不透明度 = bgOverlayOpacity
  ▲
[第2层] 全局静态缓存高斯模糊 (RepaintBoundary + ImageFiltered: sigmaX = bgBlurSigma, sigmaY = bgBlurSigma)
  ▲
[第1层] 全局背景图 (globalStyle.backgroundImagePath，BoxFit.cover 铺满全屏)
        • 若未配置背景图，则直接显示纯色底（isDarkText 为 true 时显示 #F1F5F9，为 false 时显示 #0F172A）
```

### 2.2 账单流水卡片渲染栈（核心视觉区，从底到顶）
每条账单卡片是一个圆角半径为 `16px` 的独立图层容器：
```text
[顶层] 卡片前景信息
        • 左侧 6px 宽垂直高亮色条（颜色 = categoryStyles[类别].themeColor）
        • 有插画底图时：
          - 左侧为紧凑自适应宽度的「统一磨砂信息块」（78% 不透明白/深岩底托 + 细描边，12px 圆角），内置三行：类别色点 + 粗体名称、发生时间、账单备注
          - 右上角为「工作日/休息日」胶囊角标或 45° 斜角丝带（badgeStyle: "pill" | "ribbon"）
          - 右下角为同款磨砂底托包裹的 17.5pt 粗体支出金额，中部留出最大通透窗口展示插画主体
        • 无插画底图时：清爽无框三行排版（左上类别胶囊、中部时间、左下备注、右下金额）
  ▲
[第5层] 外边框容器 (borderColor + borderWidth + borderStyle: "solid" | "dashed")
  ▲
[第4层] 工作日 / 休息日氛围色调叠加层 (dayTypeStyle.workday/restDay.tintOverlayColor)
  ▲
[第3层] 卡片方向性渐变可读性遮罩 (基于 cardOverlayOpacity：左侧约 1.18×、中部约 0.58× 透亮窗口、右侧约 1.05×)
        • 当 isDarkText == true：叠加纯白 #FFFFFF
        • 当 isDarkText == false：叠加纯黑 #000000
  ▲
[第2层] 卡片静态缓存高斯模糊 (RepaintBoundary + ImageFiltered: sigmaX = cardBlurSigma, sigmaY = cardBlurSigma)
  ▲
[第1层] 卡片底图层
        • 若该类别配置了 backgroundImagePath：加载该图片并以 BoxFit.cover 铺满卡片
        • 若该类别 backgroundImagePath == null：直接填充高透轻玻璃底色（由 glassColor / glassOpacity 或 surfaceColor 计算）
```

---

## 3. `theme.json` 全字段字典与作用详解

颜色格式统一使用 **8 位 ARGB 十六进制字符串 `#AARRGGBB`**（前两位 `AA` 为 Alpha 不透明度：`FF`=100% 不透明，`E6`≈90%，`CC`≈80%，`80`=50%，`1F`≈12%，`14`≈8%，`00`=完全透明；也兼容 6 位 `#RRGGBB`，默认视为 `FF` 不透明）。

### 3.1 顶层结构
| 字段名 | 类型 | 必填 | 作用与约束说明 |
| :--- | :--- | :---: | :--- |
| `package_type` | `string` | 是 | **固定值 `"theme_package"`**（写错将导致导入校验拒绝）。 |
| `version` | `int` | 是 | 固定值 `1`。 |
| `name` | `string` | 是 | 主题显示名称，如 `"春日樱花手账"`、`"赛博夜之城"`。 |
| `globalStyle` | `object` | 是 | 全局色彩、明暗模式与全屏背景图配置。 |
| `dayTypeStyle` | `object` | 是 | 工作日 (`workday`) 与休息日 (`restDay`) 的卡片差异化视觉配置。 |
| `categoryStyles` | `object` | 是 | 以**类别中文名称**为 Key 的各类别专属主题色与卡片背景图字典（导入时同名自动绑定，且全部自动收录进候选库）。 |
| `cardStylePool` | `array` | 否 | **【推荐】主题候选样式库**。存放额外/备用的卡片样式套装；不会触发“创建缺失类别”弹窗，导入后全部进入该主题的「候选库」，用户可在主题编辑器随时一键绑定到任意本地类别。 |

---

### 3.2 `globalStyle`（全局视觉配置）
| 字段名 | 类型 | 取值范围 / 格式 | 作用部位与设计说明 |
| :--- | :--- | :--- | :--- |
| `primaryColor` | `string` | `#AARRGGBB` | **全局主强调色**。作用于：右下角「+ 记一笔」悬浮按钮、顶部用户切换胶囊、统计总金额高亮字、趋势图柱子/折线颜色、导航栏选中态高亮、主要确认按钮。**Alpha 通道必须为 `FF`**。 |
| `surfaceColor` | `string` | `#AARRGGBB` | **容器与无图卡片底色**。作用于：顶部栏 AppBar、底部导航栏、筛选汇总栏、统计页/洞察页/设置页所有面板卡片、以及未配置专属图片的账单卡片。**强烈建议使用 `CC`~`F2` (80%~95%) 的半透明色**，这样能隐约透出底层的全局背景图，呼吸感极佳！ |
| `isDarkText` | `bool` | `true` / `false` | **明暗文字与遮罩模式开关**：<br>• `true`（**浅色/亮色主题**）：全局主文字采用深岩灰 `#0F172A`，次要文字 `#475569`；图片上方的可读性遮罩为**纯白色**。<br>• `false`（**深色/暗黑主题**）：全局主文字采用雪白 `#F8FAFC`，次要文字 `#CBD5E1`；图片上方的可读性遮罩为**纯黑色**。 |
| `accentTextFollowsPrimary` | `bool` | `true` / `false`（选填，默认 `true`） | **强调文字是否跟随主题主色**（v1.2.3+）。作用于账单页「累计总支出」金额、统计页总金额、经济学对比页大字指标与分位、未选中「批量管理」及下拉赏图提示文字。<br>• `true`（默认）：上述强调文字使用 `primaryColor`。<br>• `false`：改为跟随 `isDarkText` 决定的深/浅主文字色。当浅色主题采用马卡龙浅主色、或深色主题采用暗调主色导致数字对比度不足时，**强烈推荐设为 `false`**。 |
| `backgroundImagePath` | `string?` | `"assets/..."` 或 `null` | 全局全屏背景图在 ZIP 包内的相对路径。无背景图填 `null`。 |
| `bgOverlayOpacity` | `double` | `0.0` ~ `0.90` | 全局背景图上方的白/黑纯色遮罩不透明度。仅当配置了 `backgroundImagePath` 时生效。 |
| `bgBlurSigma` | `double` | `0.0` ~ `25.0` | 全局背景图的**总体**高斯模糊半径。`0.0` 为完全清晰无模糊。<br>⚠️ **分类铁律**：若背景为**鲜明风格的人物/角色立绘**，必须设为 **`0.0`** 以保证角色清晰；若为**纯粹的图像设计、风景或现实照片**，可设为 `2.0 ~ 12.0` 营造毛玻璃质感。 |
| `glassColor` | `string?` | `#AARRGGBB` 或 `null`（选填） | **高透轻玻璃颜色**。作用于有背景图时的所有前景面板、顶栏、底栏及极简模式卡片底色；留空时默认沿用 `surfaceColor` 的色相。 |
| `glassOpacity` | `double?` | `0.15` ~ `0.90` 或 `null`（选填，默认 `0.54`） | **高透轻玻璃不透明度**。数值越低越通透，推荐 `0.42 ~ 0.58`，既能清晰透出背景人物又保证前景文字易读。 |

---

### 3.3 `dayTypeStyle`（工作日 vs 休息日卡片视觉区分）
包含 `"workday"` 与 `"restDay"` 两个结构完全相同的子对象：

| 字段名 | 类型 | 取值范围 / 格式 | 作用部位与设计说明 |
| :--- | :--- | :--- | :--- |
| `badgeText` | `string` | 推荐 2~4 字 | 卡片右上角角标胶囊文字，以及记账弹窗/统计页中的属性名称。不仅可以用 `"工作日"` / `"休息日"`，还可以根据主题风格定制为 `"执勤日"` / `"休整日"`、`"搬砖"` / `"摸鱼"`、`"修行"` / `"祭典"`！ |
| `badgeColor` | `string` | `#AARRGGBB` | 右上角角标胶囊的底色，同时也是**【统计】页「工作日 vs 休息日」双色对比条和对比框的代表色**。因为角标内文字固定为纯白色 `#FFFFFF`，所以 `badgeColor` **明度不宜过高**（避免浅黄/浅白底导致白字看不清）。 |
| `borderColor` | `string` | `#AARRGGBB` | 账单卡片的外边框颜色。建议工作日使用克制的冷静中性色，休息日使用更活泼或暖调的高亮色。 |
| `borderWidth` | `double` | `0.0` ~ `4.0` | 卡片外边框粗细（单位 `px`）。推荐工作日 `1.0`，休息日 `1.5` ~ `2.0`。设为 `0.0` 则隐藏边框。 |
| `borderStyle` | `string` | `"solid"` 或 `"dashed"` | 边框线条样式：`"solid"` 为实线边框，`"dashed"` 为精致的圆角虚线边框（非常适合给休息日或手账风主题增加活泼感！）。 |
| `badgeStyle` | `string` | `"pill"` 或 `"ribbon"`（选填，默认 `"pill"`） | 右上角标识形态：`"pill"` 为圆角胶囊角标，`"ribbon"` 为 45° 右上斜角丝带遮盖。 |
| `tintOverlayColor` | `string` | `#AARRGGBB` | **整张卡片的冷暖氛围滤镜叠加色**。直接覆盖在卡片背景之上、文字之下。<br>• 工作日通常设为完全透明 `"#00000000"`（或极淡的冷蓝 `"#0D38BDF8"`）。<br>• 休息日推荐设为 **5%~12% 透明度 (`#0D` ~ `#1F`) 的暖色调**（如 `"#14F59E0B"`），让休息日账单一眼呈现出温暖轻松的氛围。切忌将 Alpha 设得超过 `33` (20%)，否则会让卡片发灰发脏。 |

---

### 3.4 `categoryStyles`（默认类别匹配样式）与 `cardStylePool`（主题候选样式库）
`categoryStyles` 是一个以**类别名称**为 Key 的字典：
- **系统内置 4 大基础类别**：`"吃的"`、`"用的"`、`"玩的"`、`"未分类"`（**强烈建议每个主题包至少包含这 4 个基础类别**）。
- **零浪费双轨导入机制**：
  1. 导入主题包时，App 会先按名称将 `categoryStyles` 自动绑定到同名本地类别，并把 **`categoryStyles` 中的全部卡片样式（哪怕用户选择「仅收录到候选库」而不创建缺失类别）** 完整解压收录进本主题的「主题候选库」，绝不浪费任何一张背景图！
  2. 如果你的主题包还附带了多套额外/备用卡片皮肤（例如“奶茶风”“手办风”“旅行风”），强烈建议放在顶层可选数组 **`cardStylePool`** 中——这些额外皮肤不会误触发“创建缺失类别”弹窗，导入后直接出现在【主题编辑器 → 主题候选库】中供用户随时一键套用到任意类别。

`cardStylePool` 数组中每一项的对象结构：
| 字段名 | 类型 | 必填 | 说明 |
| :--- | :--- | :---: | :--- |
| `name` | `string` | 是 | 候选样式展示名称（如 `"樱花甜品"`、`"深夜拉面"`）。 |
| `defaultCategory` | `string?` | 否 | 建议默认匹配的类别名（若本地存在该类别且尚未绑定样式，导入时可自动匹配）。 |
| `themeColor` | `string` | 是 | `#FFRRGGBB` 卡片代表色。 |
| `backgroundImagePath` | `string?` | 否 | `"assets/..."` 相对路径或 `null`。 |
| `cardOverlayOpacity` | `double` | 是 | 卡片遮罩不透明度 (`0.0 ~ 0.90`)。 |
| `cardBlurSigma` | `double` | 是 | 卡片模糊半径 (`0.0 ~ 20.0`)。 |

`categoryStyles` 中每个类别对象包含以下 5 个字段：

| 字段名 | 类型 | 取值范围 / 格式 | 作用部位与设计说明 |
| :--- | :--- | :--- | :--- |
| `themeColor` | `string` | `#FFRRGGBB` | **该类别的核心代表色（Alpha 必须为 `FF`）**。同时作用于 4 处：<br>1. 账单卡片左侧 `6px` 垂直高亮色条；<br>2. 账单卡片左上角类别胶囊标签；<br>3. 记账弹窗中的类别选择网格边框；<br>4. **【统计】页环形饼图扇区颜色与排行榜进度条颜色**。<br>⚠️ **重要**：不同类别的 `themeColor` 在色相（Hue）上必须拉开差距，否则统计页饼图会糊成一团！ |
| `default_color_hex` | `string` | `#FFRRGGBB` | 当用户通过主题包一键创建缺失类别时的默认兜底色，**请直接填写与 `themeColor` 相同的值**。 |
| `backgroundImagePath` | `string?` | `"assets/..."` 或 `null` | 该类别账单卡片的专属横幅底图相对路径（如 `"assets/cat_food.jpg"`）。若不设底图请填 `null`。 |
| `cardOverlayOpacity` | `double` | `0.0` ~ `0.90` | 卡片底图上方的白/黑可读性遮罩不透明度（`isDarkText: true` 时为白遮罩，`false` 时为黑遮罩）。直接决定卡片上文字与金额是否清晰可读！ |
| `cardBlurSigma` | `double` | `0.0` ~ `20.0` | 卡片底图的**总体**毛玻璃模糊度。<br>⚠️ **分类铁律**：<br>• **鲜明风格的人物/角色主题**：必须设为 **`0.0`**（切勿用总体模糊把角色五官糊掉！应通过图片自身的左/右边缘散景虚化 + 适度 `cardOverlayOpacity` 保证文字可读性）。<br>• **纯粹的图像设计或现实照片背景**：推荐开启 **`1.5` ~ `5.0`** 的总体模糊，让前景文字瞬间清晰浮现。 |

---

## 4. 美学优化与黄金参数配方（Designer & AI 调参指南）

为了让制作出的主题既惊艳又具备极佳的日常记账可读性（WCAG 对比度达标、列表 120 帧流畅滚动），请遵循以下黄金法则：

### 4.1 图片尺寸、构图与「左-中-右」三段式视觉重心规范
1. **全局背景图 (`globalStyle.backgroundImagePath`)**：
   - **最佳比例与分辨率**：**9:16 竖屏**，推荐分辨率 **`1440 × 2560`**（或 `1080 × 1920`），JPEG 质量 85%~90%（单张建议控制在 `300KB ~ 800KB` 以内）。
   - **⚠️ 上下安全区避让法则（极重要！）**：
     - App 的**最上方约 12%** 会被顶部栏（AppBar + 状态栏）覆盖，**最下方约 12%** 会被底部导航栏（NavigationBar）覆盖。
     - 因此，在绘制或裁剪全局背景图时，**人物面部、头部、关键徽标等核心视觉主体必须避开画面最上方 12% 与最下方 12%**，优先布局在画面**中段安全区（垂直方向 18% ~ 82%）**，这样无论是在常规浏览页还是在账单页下拉进入「纯净赏图模式」，人物都不会被上下栏边框裁切或遮挡！
2. **类别卡片背景图 (`categoryStyles[*].backgroundImagePath`)**：
   - **最佳比例与分辨率**：**16:5 超宽横幅比例**（账单卡片实际宽高比约为 `16:4.5 ~ 16:5.5`），推荐分辨率 **`1280 × 400`**（或 `960 × 300`），JPEG 质量 85%（单张建议控制在 `80KB ~ 200KB` 以内）。
   - **视觉重心黄金法则（极重要！避免人物与右侧支出金额重合）**：
     - 账单卡片的 UI 前景信息分布在**左右两端**：
       - **左侧区域（水平 `0% ~ 40%`）**：左上角有类别胶囊标签与时间，左下角有账单备注文字；
       - **右侧区域（水平 `75% ~ 100%`）**：右上角有「工作日/休息日」胶囊角标，**右下角有最核心的大号粗体支出金额数字**。
     - ⚠️ **严禁把人物重心贴在最右侧（`75% ~ 100%`）**，否则角色的面部或核心动作道具会与右侧重点（支出金额、角标）严重重合打架！
     - ✅ **正确做法（「左-中-右」三段式构图）**：
       - 将**人物主体/视觉重心设置在画面「中部偏右的无遮挡黄金窗口」（水平中心约在 `50% ~ 65%` 处）**；
       - **左侧边缘 (`0% ~ 42%`)** 与 **右侧边缘 (`76% ~ 100%`)** 留出相对干净的柔光背景或做**局部边缘散景虚化（Bokeh）**。这样既能让左侧备注与右侧支出金额清晰可读，又能让中间的人物立绘 100% 完整无遮挡地展现！

### 4.2 背景图片两大分类与「模糊度 / 可读性遮罩」黄金搭配表
在设置模糊度 (`cardBlurSigma` / `bgBlurSigma`) 前，必须先将背景图片归为以下**两大类别**并采取截然不同的模糊策略：

1. **类型 A：鲜明风格的人物 / 角色插画背景**（如二次元角色、拟人形象、人物特写）
   - **模糊策略**：**禁止添加总体模糊（`cardBlurSigma: 0.0`，`bgBlurSigma: 0.0`）**，确保人物五官、神情与线条清晰锐利。
   - **可读性策略**：在制图/裁剪阶段保留或生成**左侧（及右侧金额区）边缘散景模糊（Local Edge Bokeh）**，并配合适度的可读性纯色遮罩 (`cardOverlayOpacity`)。
2. **类型 B：纯粹的图像设计 / 风景插画 / 现实照片背景**（无特定中心人物五官特写）
   - **模糊策略**：**推荐开启总体毛玻璃模糊（`cardBlurSigma: 1.5 ~ 5.0`，`bgBlurSigma: 2.0 ~ 12.0`）**，利用全局高斯模糊柔化高频纹理，营造通透的磨砂毛玻璃质感。

请参考以下经过实测的分类黄金区间：

| 背景图分类与细分类型 | 浅色模式 (`isDarkText: true`) 推荐参数 | 深色模式 (`isDarkText: false`) 推荐参数 | 视觉效果说明 |
| :--- | :--- | :--- | :--- |
| **【类型 A】鲜明风格的人物 / 角色插画**<br>*(全局背景 + 各类别卡片底图)* | `cardOverlayOpacity`: **`0.32 ~ 0.48`**<br>`cardBlurSigma`: **`0.0`（严禁总体模糊）**<br>`bgOverlayOpacity`: **`0.18 ~ 0.30`**<br>`bgBlurSigma`: **`0.0`（严禁总体模糊）** | `cardOverlayOpacity`: **`0.40 ~ 0.55`**<br>`cardBlurSigma`: **`0.0`（严禁总体模糊）**<br>`bgOverlayOpacity`: **`0.35 ~ 0.50`**<br>`bgBlurSigma`: **`0.0`（严禁总体模糊）** | 角色五官与神情保持 100% 原画级清晰度；依靠卡片左右边缘的局部散景虚化与轻盈遮罩，使左侧备注和右侧支出金额同样清晰锐利。 |
| **【类型 B-1】高细节现实照片 / 繁杂风景画**<br>*(无人物主体或纯氛围图)* | `cardOverlayOpacity`: **`0.45 ~ 0.62`**<br>`cardBlurSigma`: **`2.0 ~ 4.5`**<br>`bgOverlayOpacity`: **`0.20 ~ 0.35`**<br>`bgBlurSigma`: **`3.0 ~ 8.0`** | `cardOverlayOpacity`: **`0.52 ~ 0.68`**<br>`cardBlurSigma`: **`2.5 ~ 5.0`**<br>`bgOverlayOpacity`: **`0.38 ~ 0.55`**<br>`bgBlurSigma`: **`4.0 ~ 12.0`** | 开启总体毛玻璃高斯模糊，压低照片高频噪点，让前景文字像印刷品一样浮现。 |
| **【类型 B-2】纯粹图像设计 / 低饱和水彩 / 极简渐变** | `cardOverlayOpacity`: **`0.20 ~ 0.35`**<br>`cardBlurSigma`: **`0.0 ~ 1.5`**<br>`bgOverlayOpacity`: **`0.15 ~ 0.25`**<br>`bgBlurSigma`: **`0.0 ~ 3.0`** | `cardOverlayOpacity`: **`0.35 ~ 0.48`**<br>`cardBlurSigma`: **`0.0 ~ 2.0`**<br>`bgOverlayOpacity`: **`0.30 ~ 0.45`**<br>`bgBlurSigma`: **`0.0 ~ 4.0`** | 保留图像设计的细腻笔触与几何纹理，轻度模糊或不模糊即可获得极高对比度。 |

### 4.3 色彩搭配建议
- **饼图高辨识度色板**：`categoryStyles` 中各分类的 `themeColor` 建议分布在色轮的不同象限。例如：
  - `吃的`：暖红/珊瑚橘/蜜桃粉（如 `#FFEF4444`、`#FFF43F5E`、`#FFFB7185`）
  - `用的`：翡翠绿/薄荷青/湖蓝（如 `#FF10B981`、`#FF14B8A6`、`#FF06B6D4`）
  - `玩的`：紫罗兰/流光紫/琥珀金（如 `#FF8B5CF6`、`#FFA855F7`、`#FFF59E0B`）
  - `未分类`：高级灰蓝/中性石板色（如 `#FF64748B`、`#FF94A3B8`）
- **工作日 vs 休息日冷暖反差**：
  - `workday` 建议采用**理性冷色调**（钴蓝 `#FF2563EB`、天青 `#FF0284C7`、板岩灰边框 `#FFCBD5E1`，`borderStyle: "solid"`，`tintOverlayColor: "#00000000"`）。
  - `restDay` 建议采用**愉悦暖色调**（琥珀橙 `#FFD97706`、樱花粉 `#FFDB2777`、珊瑚金边框 `#FFF59E0B`，`borderStyle: "dashed"` 或 `1.5px solid`，配合微暖滤镜 `tintOverlayColor: "#14F59E0B"`）。

---

## 5. 完整可直接使用的 `theme.json` 范例模板

下面是一份包含自定义图片引用与扩展类别的完整 `theme.json` 范例，制作新主题时可直接复制修改：

```json
{
  "package_type": "theme_package",
  "version": 1,
  "name": "樱花微风手账",
  "globalStyle": {
    "primaryColor": "#FFEC4899",
    "surfaceColor": "#EBFFFDFD",
    "isDarkText": true,
    "accentTextFollowsPrimary": true,
    "backgroundImagePath": "assets/global_bg.jpg",
    "bgOverlayOpacity": 0.22,
    "bgBlurSigma": 1.5,
    "glassColor": "#EBFFFDFD",
    "glassOpacity": 0.54
  },
  "dayTypeStyle": {
    "workday": {
      "badgeText": "日常",
      "badgeColor": "#FF6366F1",
      "borderColor": "#FFE2E8F0",
      "borderWidth": 1.0,
      "borderStyle": "solid",
      "tintOverlayColor": "#00000000"
    },
    "restDay": {
      "badgeText": "休日",
      "badgeColor": "#FFEC4899",
      "borderColor": "#FFF472B6",
      "borderWidth": 1.5,
      "borderStyle": "dashed",
      "tintOverlayColor": "#14F472B6"
    }
  },
  "categoryStyles": {
    "吃的": {
      "themeColor": "#FFF43F5E",
      "default_color_hex": "#FFF43F5E",
      "backgroundImagePath": "assets/cat_food.jpg",
      "cardOverlayOpacity": 0.45,
      "cardBlurSigma": 2.0
    },
    "用的": {
      "themeColor": "#FF10B981",
      "default_color_hex": "#FF10B981",
      "backgroundImagePath": "assets/cat_use.jpg",
      "cardOverlayOpacity": 0.45,
      "cardBlurSigma": 2.0
    },
    "玩的": {
      "themeColor": "#FF8B5CF6",
      "default_color_hex": "#FF8B5CF6",
      "backgroundImagePath": "assets/cat_play.jpg",
      "cardOverlayOpacity": 0.45,
      "cardBlurSigma": 2.0
    },
    "未分类": {
      "themeColor": "#FF64748B",
      "default_color_hex": "#FF64748B",
      "backgroundImagePath": null,
      "cardOverlayOpacity": 0.40,
      "cardBlurSigma": 2.0
    }
  },
  "cardStylePool": [
    {
      "name": "樱花午后茶歇（备用）",
      "defaultCategory": "吃的",
      "themeColor": "#FFEC4899",
      "backgroundImagePath": "assets/pool_teatime.jpg",
      "cardOverlayOpacity": 0.42,
      "cardBlurSigma": 2.0
    },
    {
      "name": "春日出游列车（备用）",
      "defaultCategory": "交通",
      "themeColor": "#FF3B82F6",
      "backgroundImagePath": "assets/pool_train.jpg",
      "cardOverlayOpacity": 0.45,
      "cardBlurSigma": 2.5
    }
  ]
}
```

---

## 6. 给 AI 主题生成器的自动化脚本参考 (Python 一键打包脚本)

如果由 AI 代理为用户自动生成主题包，可使用以下 Python 代码将 `theme_dict` 与生成的裁剪图片直接打包为合规的 `.themepkg.zip`：

```python
import json
import zipfile
from pathlib import Path

def build_themepkg_zip(output_zip_path: str, theme_dict: dict, asset_files: dict[str, str]):
    """
    :param output_zip_path: 输出路径，如 'sakura_theme.themepkg.zip'
    :param theme_dict: 符合本规范第 5 节结构的 dict（确保 package_type == 'theme_package'）
    :param asset_files: {'assets/global_bg.jpg': '/local/path/to/bg.jpg', ...}
    """
    assert theme_dict.get("package_type") == "theme_package"
    with zipfile.ZipFile(output_zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("theme.json", json.dumps(theme_dict, ensure_ascii=False, indent=2))
        for zip_rel_path, local_file_path in asset_files.items():
            zf.write(local_file_path, arcname=zip_rel_path.replace("\\", "/"))
```
