# 闲庭斗地主

Flutter + Flame 开发的中文离线斗地主，一名玩家与两名本地电脑对战。支持 Windows 10+、Android 手机/折叠屏/平板和 Web。无账号、广告、联网对战或真钱功能。

## 0.2.1（验证中）

统一保存设置、总战绩和最近记录，兼容旧版资料；电脑策略仅接收自己手牌和公开信息。

## 0.2.0

牌桌菜单新增难度设置和最近战绩：轻松/标准两种电脑，下局生效；最近 20 局记录本地时间、身份、难度、胜负和积分。

## 0.1.1

优化候选出牌排序，缓存牌型判定，统一日志与界面的版本信息。16 个测试与三端 CI 构建通过，[三端下载](https://github.com/qpzm7903/flutter-game/releases/tag/v0.1.1)已发布。

## 0.1.0

- 三人叫分、地主底牌、完整经典牌型、提示出牌、农民合作策略。
- 炸弹翻倍、春天/反春天、阵营结算及本机积分战绩。
- 自适应中文牌桌、可点击手牌、规则说明、离开应用暂停。
- Windows 日志：`%USERPROFILE%/.xianting-doudizhu/logs/doudizhu.log`；Android：应用文档目录下 `logs/doudizhu.log`。界面「诊断日志」可查看路径、复制日志，Web 可下载浏览器日志。
- 原生日志单文件约 1 MiB，保留一个轮转备份；Web 日志限制约 64K 字符，不上传。

点击手牌选中，再点「出牌」；「提示」选中建议牌；两人连续不出后由上一位出牌者自由领出。详细地方规则约定见游戏内说明与 [plan.md](plan.md)。

## 开发与构建

仅在 `main` 开发，所有 Flutter 分析、测试、构建在 Actions 执行，不要求本地安装 SDK。首版参考 [flutter-snake](https://github.com/g-ai-002/flutter-snake)（MIT），保留其授权与 GitHub/Gitea 构建发布结构。Android SDK：min 35 / target 37 / compile 37。

GitHub CI 已通过 20 个测试及三端构建；[v0.1.0 正式 Release](https://github.com/qpzm7903/flutter-game/releases/tag/v0.1.0) 已包含三端下载件。发布地址：[Releases](https://github.com/qpzm7903/flutter-game/releases)。具体 CI 状态与配置差异记录于 [plan.md](plan.md)。

Web ZIP 解压后可用现有静态服务器访问；渲染资源和中文后备字体均随包提供。字体来自 Noto Sans SC，采用 OFL 许可，见 `assets/fonts/OFL.txt`；不在运行时调用字体服务。

验证覆盖 50 局随机模拟、320/360/800/1400 宽度布局、日志轮转，以及浏览器完整离线牌局与日志下载。Windows/Android 已完成 CI 构建，尚未在本次环境中进行真机安装测试。
