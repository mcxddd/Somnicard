extends RefCounted
## Offline authored fundamentals. Completion is learning progress, never a skill rating.
const LESSONS = [
  {
    "id": "start",
    "title": "读懂一手牌",
    "subtitle": "先认识目标，再做决定。",
    "topic": "翻前入池",
    "questions": [
      {
        "prompt": "你有两张底牌，桌面有五张公共牌。最终怎样比较大小？",
        "choices": [
          "必须用两张底牌",
          "从七张中选最强的五张",
          "比较全部七张"
        ],
        "correct": 1,
        "reason": "德州扑克用七张牌组成最强的五张。可以使用两张、一张或零张底牌；剩余两张不参与比较。"
      },
      {
        "prompt": "公共牌是 A♠ K♠ Q♠ J♠ 10♠，两位玩家都没有弃牌。谁赢？",
        "choices": [
          "底牌点数更大的人",
          "庄家",
          "平分可共同争夺的底池"
        ],
        "correct": 2,
        "reason": "公共牌已经组成最大的同花顺，任何底牌都无法改善它。对同一底池有资格的玩家平分；不能用第六张牌决胜。"
      },
      {
        "prompt": "你本来只有约 30% 的分池份额，但这一手赢了。它说明什么？",
        "choices": [
          "刚才一定做对了",
          "对手一定犯错了",
          "仅凭结果不能评价决策"
        ],
        "correct": 2,
        "reason": "单次结果受发牌随机性影响。复盘应回到行动当时，检查价格、范围与可选行动，而不是用最后赢输倒推好坏。"
      }
    ]
  },
  {
    "id": "position",
    "title": "盲注与位置",
    "subtitle": "看清谁先行动。",
    "topic": "翻前入池",
    "questions": [
      {
        "prompt": "双人桌中，持有庄家标记 D 的玩家通常要下哪个盲注？",
        "choices": [
          "小盲",
          "大盲",
          "不用下盲注"
        ],
        "correct": 0,
        "reason": "双人桌庄家兼小盲。翻前小盲先行动，翻后由大盲先行动；与多人桌的排列要区分。"
      },
      {
        "prompt": "双人桌来到翻牌。谁先行动？",
        "choices": [
          "庄家 / 小盲",
          "大盲",
          "上轮最后加注的人"
        ],
        "correct": 1,
        "reason": "翻后由仍在局中的庄家左侧第一位玩家先行动。双人桌就是大盲，庄家拥有最后行动的位置优势。"
      },
      {
        "prompt": "九人桌中，前位拿到一手边缘起手牌时，为什么通常要比后位谨慎？",
        "choices": [
          "前位的牌天然更小",
          "后面还未行动的对手更多",
          "前位每次都必须加注"
        ],
        "correct": 1,
        "reason": "后方玩家可能加注，翻后也更容易没有位置。入池范围应考虑位置、深度和对手，而不是只看两张牌的绝对点数。"
      }
    ]
  },
  {
    "id": "price",
    "title": "算清跟注价格",
    "subtitle": "用一个分数，减少昂贵的跟注。",
    "topic": "跟注犹豫",
    "questions": [
      {
        "prompt": "面对下注后，桌上已有 60 筹码，你还需跟 20。没有边池。只考虑这次投入，盈亏平衡门槛是多少？",
        "choices": [
          "20%",
          "25%",
          "33.3%"
        ],
        "correct": 1,
        "reason": "跟注后总底池为 60 + 20 = 80，门槛是 20 ÷ 80 = 25%。这里的 60 已包含对手的下注，不能重复加一次。"
      },
      {
        "prompt": "河牌桌上已有 150，你要跟 50。估计你对对手范围只有 15% 的分池份额。忽略抽水，哪个选择更有依据？",
        "choices": [
          "跟注，因为底池很大",
          "全押，因为已经投入很多",
          "弃牌，份额低于 25% 门槛"
        ],
        "correct": 2,
        "reason": "已投入的筹码不能收回，不应成为继续投入的理由。50 ÷ 200 = 25%，15% 低于跟注需要的门槛；也不能因此自动推出全押可行。"
      },
      {
        "prompt": "翻牌权益高于当前跟注门槛，就一定应该跟注吗？",
        "choices": [
          "不一定，还要考虑后续下注和权益兑现",
          "一定，胜率够就跟",
          "一定，不能弃掉任何听牌"
        ],
        "correct": 0,
        "reason": "翻牌还没有结束，后续下注可能让你无法看到摊牌。位置、后续压力、反向隐含赔率和多人范围都会影响实际决策。"
      }
    ]
  },
  {
    "id": "sizing",
    "title": "下注与加注",
    "subtitle": "分清“加到”与“再加”。",
    "topic": "加注尺度",
    "questions": [
      {
        "prompt": "盲注 5 / 10，界面显示“加注到 3 BB”。你本轮此前没有投入，目标总额是多少？",
        "choices": [
          "15",
          "30",
          "40"
        ],
        "correct": 1,
        "reason": "1 BB 是一个大盲，即 10 筹码。加注到 3 BB 表示本轮总投入到 30，不是在已有下注上再加 30。"
      },
      {
        "prompt": "你本轮已投入 10，选择“加注到 30”。还会从剩余筹码里扣多少？",
        "choices": [
          "20",
          "30",
          "40"
        ],
        "correct": 0,
        "reason": "加注金额是本轮总额。新增投入为 30 − 10 = 20；切换 BB 和筹码显示不应改变这笔实际投入。"
      },
      {
        "prompt": "持有强牌时，应该总是选择最大的加注吗？",
        "choices": [
          "总是，强牌必须尽快全押",
          "不一定，需考虑更弱牌能否继续和有效筹码",
          "总是下注一样大小才叫 GTO"
        ],
        "correct": 1,
        "reason": "价值下注需要更弱的牌继续付钱。过大的尺寸可能让它们全部弃牌；牌面、范围和有效筹码决定可比较的尺寸。"
      }
    ]
  },
  {
    "id": "draw",
    "title": "听牌与风险",
    "subtitle": "把“可能击中”变成合理估计。",
    "topic": "跟注犹豫",
    "questions": [
      {
        "prompt": "翻牌时，你的底牌和公共牌中共有四张同一花色的牌。未知牌中还有多少张这个花色的牌？",
        "choices": [
          "8",
          "9",
          "13"
        ],
        "correct": 1,
        "reason": "同一花色一共 13 张，已知四张，因此还有九张。它们是名义上的补牌，并不保证每张都让你赢。"
      },
      {
        "prompt": "转牌有 9 张干净补牌，已知自己的两张牌和四张公共牌。河牌击中概率约为多少？",
        "choices": [
          "19.6%",
          "36%",
          "50%"
        ],
        "correct": 0,
        "reason": "未知牌为 52 − 6 = 46 张，9 ÷ 46 ≈ 19.6%。这是在补牌都干净、未知牌等可能的简化前提下，只看下一张的概率。"
      },
      {
        "prompt": "你追到同花，但公共牌已配对。为什么仍要留意对手范围？",
        "choices": [
          "同花不能击败顺子",
          "对手可能有葫芦或四条",
          "配对公共牌会取消同花"
        ],
        "correct": 1,
        "reason": "击中听牌不等于拿到最大牌。公共牌配对时存在葫芦或四条，部分补牌可能不干净；判断要结合公开行动。"
      }
    ]
  },
  {
    "id": "range",
    "title": "从单张牌到范围",
    "subtitle": "给对手一组可能的牌。",
    "topic": "诈唬判断",
    "questions": [
      {
        "prompt": "对手在河牌大额下注。只凭这一个动作，哪种说法更可靠？",
        "choices": [
          "他肯定是最大牌",
          "他肯定在诈唬",
          "需要结合之前行动和牌面更新范围"
        ],
        "correct": 2,
        "reason": "一个动作通常对应价值牌和诈唬的混合。位置、此前的下注、公共牌变化与对手风格共同提供信息，不能直接读出具体底牌。"
      },
      {
        "prompt": "你持有 A♠。构造对手可能的手牌时，哪一项必须排除？",
        "choices": [
          "所有 A 高牌",
          "含有同一张 A♠ 的组合",
          "所有同花牌"
        ],
        "correct": 1,
        "reason": "同一张牌不能出现在两个人手里。阻断牌影响具体组合数量，但持有 A♠ 不代表对手不可能拿其他 A 或其他同花牌。"
      },
      {
        "prompt": "手机教练显示一张 169 格范围图。它表达的是什么？",
        "choices": [
          "已经看穿了对手手牌",
          "按公开信息估计的相对分布",
          "未来牌堆的排列"
        ],
        "correct": 1,
        "reason": "范围图把具体组合汇总为起手牌类别。它来自模型和已知信息，是可以出错的估计，不是对手底牌的证明。"
      }
    ]
  },
  {
    "id": "review",
    "title": "让复盘有用",
    "subtitle": "每次只改进一个决定。",
    "topic": "河牌判断",
    "questions": [
      {
        "prompt": "想评估翻牌的一次跟注，应该优先查看什么？",
        "choices": [
          "最终河牌和谁赢了",
          "跟注前的底池、价格、可见牌与行动",
          "对手最终亮出的底牌，直接当作当时已知"
        ],
        "correct": 1,
        "reason": "先回到行动前的信息集。对手最终亮牌可以帮助事后理解，但不能冒充你当时已经知道的信息。"
      },
      {
        "prompt": "复盘显示两种行动的估算 EV 很接近，且差距小于估算误差。应怎样理解？",
        "choices": [
          "必须把较小数字当作严重错误",
          "这是边缘选择，不能过度解读排序",
          "以后永远只选第一项"
        ],
        "correct": 1,
        "reason": "抽样和范围建模都有误差。差距很小时，稳定的结论通常是需要更多证据，而不是精确判定其中一项必然错误。"
      },
      {
        "prompt": "哪种练习方式更适合持续改进？",
        "choices": [
          "只复盘输得最多的一手并归咎运气",
          "不看局面，重复选择最大加注",
          "选一个主题，先独立作答，再解释自己的选择"
        ],
        "correct": 2,
        "reason": "把价格、尺度或河牌判断拆开练习，并记录还不确定的局面。先思考后揭示建议，比仅浏览答案更能发现理解缺口。"
      }
    ]
  },
  {
    "id": "tools",
    "title": "正确使用 AI 与 GTO",
    "subtitle": "知道工具能回答什么。",
    "topic": "河牌判断",
    "questions": [
      {
        "prompt": "本游戏的双人河牌抽象 CFR 结果，可以直接称为完整九人 GTO 吗？",
        "choices": [
          "可以，都是扑克",
          "不可以，参与人数、范围和动作树都有限制",
          "只要计算足够久就可以"
        ],
        "correct": 1,
        "reason": "当前求解限定双人河牌和抽象范围、下注树。模型内误差不等于真实游戏误差，也不能套用到完整多人牌局。"
      },
      {
        "prompt": "AI 对手发言“这把你跟不起”。它是不是客观牌力证据？",
        "choices": [
          "是，模型一定知道正确答案",
          "不是，桌边发言也可以是诈唬或表现",
          "是，它可以看到你的底牌"
        ],
        "correct": 1,
        "reason": "发言用于桌边互动，不能作为可靠策略证明。对手只应取得自己的底牌与公开信息；牌型和合法下注由本地规则验证。"
      },
      {
        "prompt": "在线模型请求失败时，怎样继续当前练习？",
        "choices": [
          "必须卸载游戏",
          "可以重试或选择本手由本地电脑接管",
          "关闭所有保护并无限重试"
        ],
        "correct": 1,
        "reason": "保留当前牌局并提供明确的恢复选择，比反复请求或执行不完整答案可靠。本地教练与本地对手不需要 API Key。"
      }
    ]
  }
]

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 24: return false
	for key in value:
		if not key is String or not key in question_ids(): return false
		var item = value[key]
		if not item is Dictionary or not item.get("correct") is bool: return false
		if not item.get("tries") is float and not item.get("tries") is int: return false
		if not is_finite(float(item.tries)) or item.tries < 1 or item.tries > 100000 or item.tries != int(item.tries): return false
		if not item.get("date") is String or item.date.length() > 40: return false
	return true

static func question_ids() -> Array:
	var out = []
	for lesson in LESSONS:
		for i in range(lesson.questions.size()): out.append(lesson.id + ":" + str(i))
	return out

static func progress(data: Dictionary) -> Dictionary:
	var answers: Dictionary = data.get("academy", {})
	var done = 0
	var next = 0
	var total = 0
	for i in range(LESSONS.size()):
		var count = 0
		for q in range(LESSONS[i].questions.size()):
			if answers.get(LESSONS[i].id + ":" + str(q), {}).get("correct", false): count += 1
		total += count
		if count == LESSONS[i].questions.size(): done += 1
	# First unfinished lesson remains a suggestion; every lesson is freely accessible.
	next = LESSONS.size() - 1
	for i in range(LESSONS.size()):
		if range(LESSONS[i].questions.size()).any(func(q): return not answers.get(LESSONS[i].id + ":" + str(q), {}).get("correct", false)):
			next = i
			break
	var today = Time.get_date_string_from_system()
	var attempts = data.get("attempts", []).filter(func(a): return str(a.get("date", "")).begins_with(today)).size()
	return {"lessons": done, "questions": total, "next": next, "today": attempts}

static func answer(store, lesson: int, question: int, choice: int) -> Dictionary:
	if lesson < 0 or lesson >= LESSONS.size() or question < 0 or question >= LESSONS[lesson].questions.size(): return {"error": "题目不存在"}
	var q = LESSONS[lesson].questions[question]
	if choice < 0 or choice >= q.choices.size(): return {"error": "请选择一个答案"}
	if not store.data.has("academy"): store.data["academy"] = {}
	var key = LESSONS[lesson].id + ":" + str(question)
	var old = store.data.academy.get(key, {})
	var correct: bool = choice == q.correct
	store.data.academy[key] = {"correct": correct or old.get("correct", false), "tries": mini(100000, int(old.get("tries", 0)) + 1), "date": Time.get_datetime_string_from_system()}
	var saved: bool = store.save()
	return {"correct": correct, "reason": q.reason, "saved": saved}
