# 云水 · 直饮水

[![Build Android APK](https://github.com/KazemiyaMione/huish/actions/workflows/build-android.yml/badge.svg)](https://github.com/KazemiyaMione/huish/actions/workflows/build-android.yml)

> **非官方 · 第三方学习项目**

基于 Flutter 重构的校园直饮水控制客户端，仅供个人学习与技术研究使用。

**本软件与「慧生活 798」及其关联公司、设备运营方无任何隶属、合作或认证关系。**

## 功能

- 手机号 + 图片验证码 + 短信验证码登录
- 设备列表（宿舍饮水机），支持缓存离线查看
- 扫码 / 手动输入设备码绑定设备
- 实时设备状态监控（累计出水量、本次接水量）
- 一键取水 / 停止取水（按量计费 type=21、按次计费 type=91）
- 手动关水自动检测，3 秒内更新状态
- 积分中心：任务列表、一键领取、收支明细
- 消费记录：账单列表、状态筛选、详情查看
- 钱包：余额展示、多钱包切换、支付宝代扣签约
- 附近设备发现
- 深色模式 + 6 色主题切换 (Material Design 3)
- 登录态持久化，退出后自动恢复
- 首次登录强制阅读免责声明

## 截图

> TODO

## 下载

前往 [Releases](https://github.com/KazemiyaMione/huish/releases/) 下载最新 APK。

## 项目结构

```
lib/
├── main.dart                       # App 入口 & 自动登录
├── api/
│   └── api_client.dart             # HTTP + SSL Pinning + Token 持久化
├── providers/
│   ├── auth_provider.dart          # 登录状态管理
│   └── settings_provider.dart      # 主题设置
├── screens/
│   ├── main_shell.dart             # 底部导航 (首页/我的)
│   ├── login_screen.dart           # 三步登录
│   ├── home_screen.dart            # 设备列表
│   ├── device_screen.dart          # 设备控制 + 状态轮询
│   ├── profile_screen.dart         # 个人中心
│   ├── score_screen.dart           # 积分中心
│   ├── bill_screen.dart            # 消费记录
│   ├── wallet_screen.dart          # 钱包 & 签约
│   ├── add_device_screen.dart      # 添加设备 (扫码/手动)
│   ├── nearby_devices_screen.dart  # 附近设备
│   └── device_settings_screen.dart # 设备管理
├── theme/
│   └── app_theme.dart              # M3 主题配置
├── utils/
│   └── sign_utils.dart             # MD5 签名算法
└── widgets/
    ├── score_header.dart           # 积分面板组件
    ├── disclaimer_dialog.dart      # 免责声明弹窗
    └── state_widgets.dart          # 通用状态组件
```

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)

## 免责声明

**本项目为第三方独立开发的非官方客户端，仅供个人学习、研究与技术交流使用。**

1. 本软件与「慧生活 798」及其关联公司、饮水设备所有权方、运营方**不存在任何隶属、合作、背书或认证关系**。
2. 所有 API 接口及数据归属原平台所有，本软件通过公开合法授权接口获取数据，不对数据的准确性、完整性做任何担保。
3. 使用本软件即表示您已自愿承担一切风险，开发者不对因使用本软件造成的任何直接或间接损失负责。
4. 本软件开源免费（MIT 协议），**严禁用于商业目的**，包括但不限于内嵌广告、收费分发、作为商业服务的一部分。
5. 请遵守中华人民共和国相关法律法规，不得利用本软件进行任何违法活动。

**如不同意上述条款，请立即停止使用并卸载本软件。**

## License

MIT
