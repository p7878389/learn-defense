# 经典模式的森林角色资源

独立路径塔防试验已移除。经典模式继续使用林间草坪、掷石斥候、暗影学徒和十种森林首领，答题、血量、出场及奖励规则由 `EnemyKind`、`UnitCatalog` 和 `GameTuning` 管理。

- `Sprites/forest-classic.json`：经典模式动画清单，由 `python3 scripts/import-forest-classic.py` 重建。
- `Sprites/ForestActions`：十一种角色共 99 张行走和攻击帧；原图与切帧方法见 [actions](actions/README.md)。
- `Sprites/ForestRoster`：巨魔六张行走帧与一张攻击立绘；行走帧重建方法见 [ogre-walk](ogre-walk/README.md)。
- `originals`：保留经典角色原画作为美术参考。`python3 scripts/import-forest-roster.py` 只转换经典动画清单引用的攻击立绘，不再生成试验专属素材；`sources.json` 记录来源。
- `Sprites/Maps/woodland-grass.png`：经典模式林间草坪背景，与已移除的路径塔防地图不同。

经典动作帧、加载、朝向、题牌、首领出场与地图测试继续保留。`ClassicForestArtworkTests` 检查十二种角色的完整且互不重复的行走和攻击帧；`scripts/tests/test_forest_roster_import.py` 检查导入范围及图像一致性。
