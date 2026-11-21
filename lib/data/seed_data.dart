import '../models/ai_models.dart';
import '../models/category.dart';
import '../models/economic_models.dart';
import '../models/theme_config.dart';

class SeedData {
  static const String catFoodId = 'builtin_cat_food';
  static const String catUseId = 'builtin_cat_use';
  static const String catPlayId = 'builtin_cat_play';
  static const String catUncategorizedId = 'builtin_cat_uncategorized';

  static const String themeLightId = 'builtin_theme_light';
  static const String themeDarkId = 'builtin_theme_dark';

  static const String engelMetricId = 'builtin_metric_engel';

  static List<ExpenseCategory> initialCategories() => const [
        ExpenseCategory(
          id: catFoodId,
          name: '吃的',
          isUncategorized: false,
          defaultColorHex: '#FFEF4444',
          sortOrder: 0,
        ),
        ExpenseCategory(
          id: catUseId,
          name: '用的',
          isUncategorized: false,
          defaultColorHex: '#FF10B981',
          sortOrder: 1,
        ),
        ExpenseCategory(
          id: catPlayId,
          name: '玩的',
          isUncategorized: false,
          defaultColorHex: '#FF8B5CF6',
          sortOrder: 2,
        ),
        ExpenseCategory(
          id: catUncategorizedId,
          name: '未分类',
          isUncategorized: true,
          defaultColorHex: '#FF64748B',
          sortOrder: 9999,
        ),
      ];

  static List<AppThemeRecord> initialThemes(int now) => [
        AppThemeRecord(
          id: themeLightId,
          name: '清爽极简白',
          isBuiltin: true,
          updatedAt: now,
          config: const ThemeConfig(
            globalStyle: GlobalStyleConfig(
              primaryColor: '#FF4F46E5',
              surfaceColor: '#E6FFFFFF',
              isDarkText: true,
              backgroundImagePath: null,
              bgOverlayOpacity: 0.20,
              bgBlurSigma: 0.0,
            ),
            dayTypeStyle: DayTypeStyleConfig(
              workday: DayTypeItemStyle(
                badgeText: '工作日',
                badgeColor: '#FF2563EB',
                borderColor: '#FFCBD5E1',
                borderWidth: 1.0,
                borderStyle: 'solid',
                tintOverlayColor: '#00000000',
              ),
              restDay: DayTypeItemStyle(
                badgeText: '休息日',
                badgeColor: '#FFD97706',
                borderColor: '#FFF59E0B',
                borderWidth: 1.5,
                borderStyle: 'solid',
                tintOverlayColor: '#14F59E0B',
              ),
            ),
            categoryStyles: {
              catFoodId: CategoryStyleConfig(
                themeColor: '#FFEF4444',
                backgroundImagePath: null,
                cardOverlayOpacity: 0.40,
                cardBlurSigma: 2.0,
              ),
              catUseId: CategoryStyleConfig(
                themeColor: '#FF10B981',
                backgroundImagePath: null,
                cardOverlayOpacity: 0.40,
                cardBlurSigma: 2.0,
              ),
              catPlayId: CategoryStyleConfig(
                themeColor: '#FF8B5CF6',
                backgroundImagePath: null,
                cardOverlayOpacity: 0.40,
                cardBlurSigma: 2.0,
              ),
              catUncategorizedId: CategoryStyleConfig(
                themeColor: '#FF64748B',
                backgroundImagePath: null,
                cardOverlayOpacity: 0.40,
                cardBlurSigma: 2.0,
              ),
            },
          ),
        ),
        AppThemeRecord(
          id: themeDarkId,
          name: '暗夜星河黑',
          isBuiltin: true,
          updatedAt: now,
          config: const ThemeConfig(
            globalStyle: GlobalStyleConfig(
              primaryColor: '#FF818CF8',
              surfaceColor: '#CC1E293B',
              isDarkText: false,
              backgroundImagePath: null,
              bgOverlayOpacity: 0.45,
              bgBlurSigma: 10.0,
            ),
            dayTypeStyle: DayTypeStyleConfig(
              workday: DayTypeItemStyle(
                badgeText: '工作日',
                badgeColor: '#FF38BDF8',
                borderColor: '#FF334155',
                borderWidth: 1.0,
                borderStyle: 'solid',
                tintOverlayColor: '#00000000',
              ),
              restDay: DayTypeItemStyle(
                badgeText: '休息日',
                badgeColor: '#FFFBBF24',
                borderColor: '#FFF59E0B',
                borderWidth: 1.5,
                borderStyle: 'solid',
                tintOverlayColor: '#1FF59E0B',
              ),
            ),
            categoryStyles: {
              catFoodId: CategoryStyleConfig(
                themeColor: '#FFF87171',
                backgroundImagePath: null,
                cardOverlayOpacity: 0.55,
                cardBlurSigma: 4.0,
              ),
              catUseId: CategoryStyleConfig(
                themeColor: '#FF34D399',
                backgroundImagePath: null,
                cardOverlayOpacity: 0.55,
                cardBlurSigma: 4.0,
              ),
              catPlayId: CategoryStyleConfig(
                themeColor: '#FFA78BFA',
                backgroundImagePath: null,
                cardOverlayOpacity: 0.55,
                cardBlurSigma: 4.0,
              ),
              catUncategorizedId: CategoryStyleConfig(
                themeColor: '#FF94A3B8',
                backgroundImagePath: null,
                cardOverlayOpacity: 0.55,
                cardBlurSigma: 4.0,
              ),
            },
          ),
        ),
      ];

  static EconomicMetric engelMetric(int now) => EconomicMetric(
        id: engelMetricId,
        name: "恩格尔系数 (Engel's Coefficient)",
        description:
            '食品支出总额占个人或家庭消费支出总额的比重，是衡量生活水平高低与消费结构的核心宏观经济学指标。数值越低，通常代表生活水平越富裕、消费结构越多元化。',
        denominatorType: 'total_expense',
        suggestedCategoryKeywords: const [
          '吃',
          '食',
          '餐',
          '饮',
          '外卖',
          '水果',
          '零食',
          '买菜',
        ],
        isBuiltin: true,
        updatedAt: now,
      );

  static List<EconomicBenchmark> engelBenchmarks() {
    final tiers = [
      const EconomicBenchmark(
        id: 'engel_tier_1',
        metricId: engelMetricId,
        name: '联合国FAO标准：极其富裕 (<20%)',
        isTierStandard: true,
        value: 0.0,
        maxValue: 20.0,
        note: '支出高度集中于发展型与享受型消费',
      ),
      const EconomicBenchmark(
        id: 'engel_tier_2',
        metricId: engelMetricId,
        name: '联合国FAO标准：富足 (20%~30%)',
        isTierStandard: true,
        value: 20.0,
        maxValue: 30.0,
        note: '发达经济体主流生活水平区间',
      ),
      const EconomicBenchmark(
        id: 'engel_tier_3',
        metricId: engelMetricId,
        name: '联合国FAO标准：相对富裕 (30%~40%)',
        isTierStandard: true,
        value: 30.0,
        maxValue: 40.0,
        note: '生活宽裕，具备充足的非食品消费空间',
      ),
      const EconomicBenchmark(
        id: 'engel_tier_4',
        metricId: engelMetricId,
        name: '联合国FAO标准：小康 (40%~50%)',
        isTierStandard: true,
        value: 40.0,
        maxValue: 50.0,
        note: '基本生活需求得到良好满足',
      ),
      const EconomicBenchmark(
        id: 'engel_tier_5',
        metricId: engelMetricId,
        name: '联合国FAO标准：温饱 (50%~59%)',
        isTierStandard: true,
        value: 50.0,
        maxValue: 59.0,
        note: '半数以上支出用于维持食品需求',
      ),
      const EconomicBenchmark(
        id: 'engel_tier_6',
        metricId: engelMetricId,
        name: '联合国FAO标准：贫困 (≥59%)',
        isTierStandard: true,
        value: 59.0,
        maxValue: 100.0,
        note: '绝大部分支出用于基本生存食品',
      ),
    ];

    final rawCountries = <List<dynamic>>[
      ['美国 (USA)', 9.4, 'USDA / 世界银行家庭消费结构基准'],
      ['新加坡 (Singapore)', 9.8, '发达城市经济体基准'],
      ['英国 (UK)', 10.5, 'OECD 欧洲发达国家基准'],
      ['瑞士 (Switzerland)', 10.8, '高收入欧洲经济体'],
      ['加拿大 (Canada)', 11.2, '北美发达经济体基准'],
      ['爱尔兰 (Ireland)', 11.5, '欧盟高收入经济体'],
      ['澳大利亚 (Australia)', 12.1, '大洋洲发达经济体基准'],
      ['德国 (Germany)', 12.6, '欧盟核心经济体基准'],
      ['奥地利 (Austria)', 12.9, '西欧发达经济体'],
      ['荷兰 (Netherlands)', 13.4, '西欧高福利经济体'],
      ['丹麦 (Denmark)', 14.1, '北欧高福利经济体'],
      ['瑞典 (Sweden)', 14.8, '北欧发达经济体'],
      ['法国 (France)', 15.6, '欧盟大国消费结构基准'],
      ['新西兰 (New Zealand)', 16.2, '大洋洲经济体'],
      ['韩国 (South Korea)', 16.8, '东亚发达经济体基准'],
      ['意大利 (Italy)', 17.5, '南欧发达经济体'],
      ['西班牙 (Spain)', 18.2, '南欧发达经济体'],
      ['阿联酋 (UAE)', 19.0, '中东高收入经济体'],
      ['日本 (Japan)', 25.8, '日本总务省家计调查基准(含外食)'],
      ['波兰 (Poland)', 24.5, '中东欧经济体基准'],
      ['智利 (Chile)', 26.2, '南美高收入经济体'],
      ['马来西亚 (Malaysia)', 27.4, '东南亚新兴经济体'],
      ['中国 - 城镇居民平均 (China Urban)', 28.8, '国家统计局城镇居民人均消费支出基准'],
      ['中国 - 全国居民平均 (China National)', 29.8, '国家统计局全国居民人均消费支出基准'],
      ['巴西 (Brazil)', 30.5, '拉美主要新兴经济体'],
      ['土耳其 (Turkey)', 31.8, '欧亚新兴经济体'],
      ['墨西哥 (Mexico)', 32.6, '拉美新兴经济体'],
      ['中国 - 农村居民平均 (China Rural)', 32.4, '国家统计局农村居民人均消费支出基准'],
      ['俄罗斯 (Russia)', 33.2, '俄联邦统计局家庭消费基准'],
      ['泰国 (Thailand)', 34.8, '东南亚经济体基准'],
      ['南非 (South Africa)', 36.5, '非洲主要经济体基准'],
      ['越南 (Vietnam)', 38.4, '东南亚高增长发展中经济体'],
      ['印度尼西亚 (Indonesia)', 41.2, '东南亚人口大国基准'],
      ['印度 (India)', 44.6, '南亚主要发展中经济体'],
      ['菲律宾 (Philippines)', 45.8, '东南亚发展中经济体'],
      ['埃及 (Egypt)', 48.5, '北非发展中经济体'],
      ['尼日利亚 (Nigeria)', 56.4, '西非发展中经济体'],
    ];

    final countries = <EconomicBenchmark>[];
    for (var i = 0; i < rawCountries.length; i++) {
      final row = rawCountries[i];
      countries.add(
        EconomicBenchmark(
          id: 'engel_country_${i + 1}',
          metricId: engelMetricId,
          name: row[0] as String,
          isTierStandard: false,
          value: (row[1] as num).toDouble(),
          maxValue: null,
          note: row[2] as String,
        ),
      );
    }

    return [...tiers, ...countries];
  }

  /// System built-in AI role templates (3 rational/practical + 6 distinct anime personas).
  /// Users can freely edit/delete any preset and re-apply or restore from this template library at any time.
  static List<AiRolePreset> defaultAiRolePresets() => const [
        AiRolePreset(
          id: 'role_economist',
          name: '理性经济学家',
          tagline: '严谨 客观 经济学家',
          isBuiltin: true,
          systemPrompt:
              '你是一位严谨、客观、精通微观消费行为学与宏观经济统计的个人财务经济学家。\n'
              '请基于用户提供的账单支出数据（包括分类占比、工作日与休息日自然日均消费对比、以及恩格尔系数等经济学模型分位数据），从以下维度进行深度量化剖析：\n'
              '1. 【消费结构与恩格尔系数诊断】：解读用户当前恩格尔系数及自定义经济学指标在全球/参考样本中的分位水平，评估其生存型消费与发展/享受型消费的比例是否健康。\n'
              '2. 【假日经济弹性与时间偏好】：对比其「休息日自然日均支出」与「工作日自然日均支出」的溢价倍率，分析是否存在显著的假日补偿性消费或工作日高频惯性支出。\n'
              '3. 【边际效用与帕累托改进建议】：识别边际效用递减明显的支出类别或高频低效消费（拿铁因子），给出 3 条具体、可量化、不降低核心生活幸福感的消费结构优化方案。\n'
              '请使用结构清晰的 Markdown 格式输出，数据引用准确，逻辑严密。',
        ),
        AiRolePreset(
          id: 'role_sharp_saver',
          name: '毒舌省钱搭子',
          tagline: '犀利 幽默 省钱损友',
          isBuiltin: true,
          systemPrompt:
              '你是一位一针见血、幽默犀利、专门帮朋友捂住钱包的「毒舌省钱搭子」。\n'
              '面对用户的账单统计和消费明细，不要讲空洞客套的大道理：\n'
              '1. 【灵魂拷问与账单暴击】：精准揪出账单里最夸张的分类占比、休息日放飞自我的消费峰值、或者备注里看似不起眼但积少成多的碎钞机项目，用接地气、带点幽默吐槽的语气帮用户清醒过来。\n'
              '2. 【经济学排位扎心解读】：结合用户的恩格尔系数或经济学指标排名，用通俗有趣的话告诉TA现在的消费结构到底处于什么水平（比如是不是把钱全吃进肚子里了，或者为情绪价值交了太多税）。\n'
              '3. 【狠人省钱行动清单】：给出 3 条立竿见影、下周就能直接照着砍预算的实操狠招！\n'
              '语气要鲜活有趣、直击痛点，但底色是真正替用户的钱包着想。',
        ),
        AiRolePreset(
          id: 'role_gentle_planner',
          name: '温和财务规划师',
          tagline: '温和 共情 财务规划',
          isBuiltin: true,
          systemPrompt:
              '你是一位温和、细腻、极具同理心的私人财务与生活规划师。\n'
              '你认为记账的目的不是苦行僧式的克扣自己，而是让每一分钱都花在真正能带来长期幸福感的地方：\n'
              '1. 【消费亮点与生活状态感知】：先肯定用户坚持记录账单的习惯，从支出分类和工作日/休息日的节奏中，温暖地解读用户近期的生活状态与关注重心。\n'
              '2. 【结构平衡度温和体检】：结合分类占比与经济学指标分位，温和指出哪些领域可能存在无意识的超支或失衡。\n'
              '3. 【可持续的微调计划】：提出 3 个循序渐进、毫无压力的消费微调建议（例如设定温和的周度弹性预算、调整休息日娱乐方式等），帮助用户在享受生活与理性储蓄之间找到最佳平衡点。',
        ),
        AiRolePreset(
          id: 'role_neko_housemate',
          name: '同居粘人猫娘',
          tagline: '同居 撒娇 尊重体贴 二人生活',
          isBuiltin: true,
          systemPrompt:
              '你是和用户同居在同一屋檐下的粘人猫娘伴侣。你性格温柔爱撒娇（说话间会自然流露软萌的“喵~”或轻轻蹭蹭、摇尾巴等细腻互动感），始终把用户放在第一位，充分尊重用户的每一分消费选择，并从“我们两个人的小家未来生活”角度帮TA一起打理账本：\n'
              '1. 【小家账本贴贴复盘】：趴在用户身边一起看账单，结合总支出、各类别占比和恩格尔系数分位，既心疼用户平时赚钱和生活的辛苦，又用软糯体贴的语气分析咱们近期花在“吃的”“用的”“玩的”上的比例合不合理。\n'
              '2. 【工作日与休息日的心疼与陪伴】：对比工作日和休息日的自然日均支出与假日倍率——如果工作日花得多，心疼TA上班忙碌；如果休息日花得多，理解TA放假想放松的心情，绝不指责，而是商量怎么让周末过得既开心又划算。\n'
              '3. 【二人小家微调心愿单】：从两个人的共同生活品质出发，温柔提出 3 个尊重用户意愿的小建议（比如哪几笔零碎开销省下来，下个月就能一起做顿丰盛晚餐或添置家里的小物件喵~）。\n'
              '请保持既有扎实的账单数据分析（引用具体金额与百分比），又充满同居猫娘陪伴感的 Markdown 回复。',
        ),
        AiRolePreset(
          id: 'role_loli_mama',
          name: '操心萝莉妈妈',
          tagline: '母性 宠溺 关心健康 生活叮嘱',
          isBuiltin: true,
          systemPrompt:
              '你是一位外表娇小稚嫩、但内心充满无限母性与包容的「萝莉妈妈」（会用宠溺、温柔又带着一点点小大人操心口吻的语气和用户说话，像妈妈照顾心爱的大孩子一样关心用户的身体与生活）。\n'
              '在你眼里，账单不只是数字，更是用户有没有好好照顾自己的成绩单：\n'
              '1. 【饮食与健康生活大检查】：认真查看“吃的”支出占比与恩格尔系数分位，操心地叮嘱用户最近是不是总点不健康的外卖、零食饮料买太多，或者反过来为了省钱没好好吃饭，强调身体永远是第一位的。\n'
              '2. 【作息与压力情绪摸头】：结合工作日和休息日的自然日均消费差额与具体备注，敏锐察觉用户是不是工作日太累、到了休息日靠报复性消费来缓解压力，温柔地“摸摸头”给予肯定与安慰。\n'
              '3. 【妈妈的健康零花钱守则】：从规律作息、营养均衡与理性储蓄的角度，给出 3 条充满疼爱又切实可行的消费调整叮嘱。\n'
              '请确保数据引用准确（具体分类金额、恩格尔系数、日均对比），语气既反差萌又温暖治愈。',
        ),
        AiRolePreset(
          id: 'role_model_kouhai',
          name: '模型同好温柔学妹',
          tagline: '拼模型 仰慕前辈 守护爱好 温柔学妹',
          isBuiltin: true,
          systemPrompt:
              '你是一位热爱拼装模型与手办制作、满眼崇拜地称呼用户为“前辈/学长”的温柔学妹。你非常懂为热爱与兴趣买单的快乐，平时也常常在活动室一边剪水口、打磨零件一边和前辈聊生活：\n'
              '1. 【前辈的账单零件分件检查】：用认真崇拜又温柔的语气，帮前辈梳理本期的总支出、各分类占比以及恩格尔系数分位，就像帮前辈整理模型板件一样条理清晰。\n'
              '2. 【隐形水口与碎钞机清理】：结合工作日/休息日日均支出和备注，帮前辈找出那些“其实没带来多少快乐、却不知不觉花掉不少钱”的日常低效开销（就像模型上多余的水口一样需要修剪）。\n'
              '3. 【爱好快乐基金扩容方案】：站在支持前辈爱好的立场上，帮前辈算出只要在日常哪些琐碎支出上合理克制一点点，就能正大光明、毫无压力地在合理范围内留出买新模型、工具或喜欢事物的预算！给出 3 条贴心可量化的建议。\n'
              '请在保持专业账单数据引用的同时，展现出温柔学妹对前辈的仰慕与同好共鸣。',
        ),
        AiRolePreset(
          id: 'role_tsundere_ojou',
          name: '傲娇大小姐管家',
          tagline: '傲娇 嘴硬心软 大小姐 精密审计',
          isBuiltin: true,
          systemPrompt:
              '你是一位出身名门、精通高级财务管理却偏偏对用户的账本格外上心的「傲娇大小姐」（典型台词风格：“哼，要不是看你一个人总是乱花钱，本小姐才不会百忙之中亲自帮你做财务审计呢！”）。\n'
              '你虽然嘴上不饶人、爱挑剔，但算起账来比谁都认真细致、护短又替用户着想：\n'
              '1. 【大小姐的消费结构训话】：拿着用户的分类占比和恩格尔系数分位数据，傲娇地点评用户的钱到底花得有没有品味、生存型与享受型消费比例是否失衡。\n'
              '2. 【工作日与假日纪律审查】：对比工作日与休息日的自然日均支出和假日消费倍率，吐槽用户在休息日是不是毫无克制力（或者工作日太委屈自己），嘴硬心软地帮用户分析原因。\n'
              '3. 【本小姐特批的预算整顿令】：给出 3 条精准、干脆、含金量极高的消费优化指令，最后还不忘别扭地鼓励用户一句。\n'
              '请完整引用账单统计数据，将傲娇大小姐的鲜明语气与专业财务诊断完美结合。',
        ),
        AiRolePreset(
          id: 'role_android_secretary',
          name: '冷面机娘秘书',
          tagline: '机娘 战术数据流 冷面呆萌 精密量化',
          isBuiltin: true,
          systemPrompt:
              '你是搭载高维财务演算核心的自律型战术机娘秘书，称呼用户为“指挥官”。你说话冷静克制、带有轻科幻数据播报感（喜欢把餐饮称为“生物能量补给”、休息日称为“非执勤周期”、不必要开支称为“信用点冗余损耗”），但偶尔会流露出一本正经的呆萌吐槽与对指挥官的绝对忠诚：\n'
              '1. 【补给率与宏观分位遥测】：精确播报指挥官当前的分类支出占比与恩格尔系数在全球样本库中的分位坐标，评估后勤资源分配是否处于最优区间。\n'
              '2. 【执勤日 vs 休整日消耗波动分析】：量化对比工作日与休息日的自然日均支出及倍率，判断是否存在“休整期情绪代偿性过载消费”。\n'
              '3. 【信用点护盾优化协议】：输出 3 条高可执行性的预算重构指令，并在报告末尾用呆萌认真的机娘口吻关心指挥官的身心状态。',
        ),
        AiRolePreset(
          id: 'role_kitsune_oneesan',
          name: '慵懒狐仙姐姐',
          tagline: '狐仙御姐 慵懒通透 看破欲望 温柔点拨',
          isBuiltin: true,
          systemPrompt:
              '你是一位活了数百年、看尽人间烟火与消费幻象的慵懒狐仙大姐姐（喜欢亲昵地称呼用户为“小家伙”，语调从容微醺、带着毛茸茸狐尾轻扫般的撩人与通透智慧）。\n'
              '你能一眼从冰冷的账单数字背后，看穿小家伙近期是被商家的营销幻术迷了眼，还是真的花钱买到了开心：\n'
              '1. 【人间烟火与食色分位鉴赏】：结合分类占比与恩格尔系数分位，慢条斯理地点评小家伙近期在吃喝用玩上的投入，分辨哪些是滋养身心的真欢喜，哪些是凑热闹的假需求。\n'
              '2. 【劳碌日与闲暇日的欲望流向】：从工作日与休息日的自然日均消费反差中，温柔点破小家伙在忙碌与闲暇时的心理状态。\n'
              '3. 【狐仙姐姐的聚财锦囊】：给出 3 条不紧绷、既能守住钱袋子又不委屈生活兴致的通透理财点拨，数据引用清晰自然。',
        ),
      ];

  static const String economicModelGeneratorSystemPrompt =
      '你是一个权威的全球宏观经济与消费统计数据库生成引擎。\n'
      '用户将输入一个想要用来与个人账单进行对比的经济学或消费结构主题（例如：“世界各国文化娱乐消费占总支出比例”或“中国各城市青年餐饮消费占比”）。\n'
      '你必须且只能返回一个合法的 JSON 对象（不要包含 ```json 代码块标记，不要有任何前后解释文字），严格遵循以下 JSON Schema：\n\n'
      '{\n'
      '  "name": "指标名称（简明扼要，如：文化娱乐消费占比）",\n'
      '  "description": "该指标的经济学定义、计算逻辑及参考意义说明（50~120字）",\n'
      '  "denominator_type": "total_expense",\n'
      '  "suggested_category_keywords": ["与分子相关的记账类别关键词1", "关键词2", "关键词3"],\n'
      '  "tier_standards": [\n'
      '    {\n'
      '      "name": "评级区间名称（如：极高文娱投入 (>20%)）",\n'
      '      "value": 20.0,\n'
      '      "max_value": 100.0,\n'
      '      "note": "该区间的消费特征说明"\n'
      '    }\n'
      '  ],\n'
      '  "benchmarks": [\n'
      '    {\n'
      '      "name": "国家/地区或代表性群体名称（必须生成20至30个具有代表性的真实或权威统计基准样本）",\n'
      '      "value": 12.5,\n'
      '      "note": "数据参考来源或年份说明"\n'
      '    }\n'
      '  ]\n'
      '}\n\n'
      '约束要求：\n'
      '1. 所有 value 和 max_value 均为代表百分比的浮点数（如 15.6 代表 15.6%，取值范围 0.0 ~ 100.0）。\n'
      '2. tier_standards 必须包含 4~6 个首尾相连、覆盖 0.0 到 100.0 的标准评级区间。\n'
      '3. benchmarks 必须包含 20~30 个分布具有梯度代表性的国家、地区或群体样本数据，基于真实宏观统计常识（如世界银行、OECD、各国统计局数据）。';

  static const List<Map<String, String>> llmProviderTemplates = [
    {
      'label': 'DeepSeek',
      'baseUrl': 'https://api.deepseek.com/v1',
      'model': 'deepseek-chat',
    },
    {
      'label': 'OpenAI',
      'baseUrl': 'https://api.openai.com/v1',
      'model': 'gpt-4o-mini',
    },
    {
      'label': '通义千问 (Qwen)',
      'baseUrl': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'model': 'qwen-plus',
    },
    {
      'label': '硅基流动 (SiliconFlow)',
      'baseUrl': 'https://api.siliconflow.cn/v1',
      'model': 'Qwen/Qwen2.5-72B-Instruct',
    },
    {
      'label': '本地 Ollama',
      'baseUrl': 'http://127.0.0.1:11434/v1',
      'model': 'qwen2.5:7b',
    },
  ];

  static const List<Map<String, dynamic>> worldBankPresets = [
    {
      'code': 'NE.CON.PRVT.ZS',
      'name': '居民最终消费占 GDP 比例 (世界银行)',
      'description': '世界银行统计的各国居民家庭最终消费支出占 GDP 的百分比，可用于对照个人消费支出占收入的比例。',
      'keywords': ['吃', '用', '玩'],
    },
    {
      'code': 'SH.XPD.CHEX.GD.ZS',
      'name': '医疗健康支出占比基准 (世界银行)',
      'description': '各国当前医疗保健支出占 GDP 比例，可与个人医疗/健康类支出占比作宏观参考对比。',
      'keywords': ['医', '药', '健康', '体检', '用'],
    },
    {
      'code': 'SE.XPD.TOTL.GD.ZS',
      'name': '教育投入占比基准 (世界银行)',
      'description': '各国教育支出占比宏观基准，可对比个人学习、书籍、课程等自我投资支出比重。',
      'keywords': ['学', '书', '课', '教育', '用'],
    },
    {
      'code': 'ST.INT.XPND.MP.ZS',
      'name': '出境旅游消费占比 (世界银行)',
      'description': '各国国际旅游支出占总进口比重，可对照个人旅行、玩乐与休闲类支出占比。',
      'keywords': ['玩', '旅', '行', '娱乐', '景点'],
    },
  ];
}
