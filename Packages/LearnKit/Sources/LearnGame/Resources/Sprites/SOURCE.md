# 植物与僵尸素材来源

- 上游：[wszqkzqk/pypvz](https://github.com/wszqkzqk/pypvz)
- 固定版本：`c88a018209ca48457e24db124f6532aea350f60d`
- 目录：`resources/graphics/Plants`、`resources/graphics/Zombies`、`resources/graphics/Bullets`
- 本项目仅复制 14 组、197 张必要的原始 PNG；未重新编码、未删除透明通道。各组源目录记录在 `clips.json`，原始文件校验和记录在 `sha256.json`。
- 可复现导入：`python3 scripts/import-pvz-sprites.py /path/to/pypvz`，需先将上游检出到上述版本。

上游 README 声明：

> 本项目为个人python语言学习的练习项目，仅供个人学习和研究使用，不得用于其他用途。如果这个游戏侵犯了版权，请联系我删除

这些是《植物大战僵尸》相关素材，上游未提供独立的美术素材开源许可证。本目录按本项目给自家孩子学习使用的用途引入，不将其标注为 MIT，也不视为取得商业发行授权。Fluent Emoji 的 MIT 许可证仅适用于相邻 `Pictures` 目录的对应资源。

## 显示约定

- 植物朝右、僵尸朝左；保留上游的完整帧顺序。
- 同一动画共用内容包围盒，在运行时裁去透明留白，维持原始纵横比和动画基准，避免逐帧裁切带来的抖动。
- 读报僵尸的上游帧使用纯白底色，在运行时按 `colorKey` 遮罩转为透明，原始 PNG 保持不变。
- 角色 ID、血量、速度、攻击与答题规则沿用项目现有配置；这里仅替换视觉表现，不复刻原作关卡和战斗规则。
- 自定义角色或资源缺失时使用原有矢量绘制。
