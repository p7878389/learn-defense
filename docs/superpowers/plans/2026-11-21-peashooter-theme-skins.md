# 四款射手主题皮肤接入计划

目标：完成翡翠星使、星轨术士、霜晶骑士、花火游侠的独立分层资源并接入收藏、存档、试穿和战斗。
设计依据：docs/skin-designs/peashooter-skin-design.json。
架构：复用 ThemeSkin / FXLibrary / ShotAttack。新资源各自使用独立头部、叶脚、真实 muzzle、主题弹和一次性特效。仅扩展枚举、目录和资源映射；不改伤害、射速及附加效果。

- [x] 扩展现有参数化装备和运行测试；确认四款尚不存在时失败。
- [x] 添加霜晶皮肤真实命中后不减速的回归测试。
- [x] 使用已归档概念生成四份 3×2 透明图集，检查 alpha、布局和小尺寸辨识。
- [x] 新建 scripts/build-peashooter-skins.swift，离线输出头部/叶脚及弹道 PNG、五类 SKS、头像与命名动作；保持其他皮肤资源不变。
- [x] 扩展 CharacterSkin、cosmetics.json、ThemeSkin 和 CharacterSkinEffects 的穷举分支；四款等级 1 免费，仅豌豆射手可装备，独立子弹外观优先。
- [x] 完成全套 Swift 测试、iOS 构建、真实战场和收藏试穿渲染；检查暂停、打断恢复、边界及节点清理。
- [x] 记录来源、提示词、资源清单、验收和图分析限制，git diff --check。

本轮沿用 codex/defender-theme-skins，保留已有成果；不自动提交、推送或合并。
