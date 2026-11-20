# 云端语音 ZIP 下载实施计划

**目标：** 将标准 OSS 配置改为一次下载 ZIP，SHA-256 校验、临时目录解压、完整性验证成功后启用；无需数据库迁移。
**架构：** SpeechArchive 负责校验解压和文件快照；RemoteSpeech 负责下载与单任务合并；SpeechLibrary 保持播放接口及账号偏好。旧单文件缓存保留，完整安装包离线复用。
**约束：** 复用 feature/OSS语音下载；不提交、不改数据库/Keychain/家长选择；ZIPFoundation 固定 0.9.20；网络与解压失败不能损坏旧缓存。

- [x] 先写真实 ZIP 测试：安装与离线复用、错误摘要、缺失文件、路径穿越、旧缓存保留、取消后重试。
- [x] 增加 SpeechArchive：后台流式校验与解压，拒绝符号链接/越界路径，验证 manifest 全部音频，发布完整快照后原子更新当前指针。
- [x] RemoteSpeech 标准配置使用已发布 ZIP 与固定摘要，下载到临时文件、并发请求共用任务；保留单文件配置兼容已有测试和自定义来源。
- [x] SpeechLibrary 同步整包计数，停止/重试行为保持一致，设置页显示整包准备状态。
- [x] 运行语音测试、全套 macOS 测试、iOS 构建，检查 diff 与 GitNexus 变化；用真实发布 ZIP 验证解压。

数据库 StoredSpeechClip 只索引家长账号生成的文件；ReaderPreferences 保留。OSS URL/摘要属于发布配置，完成状态属于文件缓存，不新增数据表。

验证：LearnGame 150 项、LearnCore 148 项测试通过；iOS 无签名构建通过；临时 smoke test 从 OSS 下载真实 ZIP 并用正式安装器验证 1,675 条音频通过（测试文件已移除，避免常规测试依赖公网）。
