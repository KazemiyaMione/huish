# 云水 · 慧生活798 去广告版

[![Build Android APK](https://github.com/KazemiyaMione/cloudora/actions/workflows/build-android.yml/badge.svg)](https://github.com/KazemiyaMione/cloudora/actions/workflows/build-android.yml)

基于 Flutter 重构的直饮水控制客户端，专为宿舍饮水机设计。通过抓包逆向原版 API 实现核心功能，**彻底移除广告、摇一摇跳转、开屏牛皮癣**。

## 功能

- 手机号 + 图片验证码 + 短信验证码登录
- 账号信息 / 余额 / 积分展示
- 设备列表（宿舍饮水机）
- 扫码绑定新设备
- 实时设备状态监控（累计出水量、本次接水量）
- 一键取水 / 停止取水（支持按量计费、按次计费）
- 手动关水后自动检测，3 秒内更新状态
- 登录态持久化，退出后自动恢复，无需重复登录
- 设备列表离线缓存，二次打开秒出数据

## 截图

> TODO: 添加截图

## 下载

前往 [Releases](https://github.com/KazemiyaMione/cloudora/releases) 下载最新 APK。每次打 tag 后 GitHub Actions 自动构建并发布。


## 平台支持

| 平台 | 状态 |
|---|---|
| Android APK | 支持 |
| Android AAB (Google Play) | 支持 |
| HarmonyOS (华为鸿蒙) | 暂不支持 — Flutter 官方尚未适配鸿蒙，华为推荐使用 ArkUI 重构。社区有 [flutter-hmos](https://github.com/harmony-os/flutter) 但稳定性不足 |
| iOS | 理论支持，未测试 |



## 项目结构

```
lib/
├── main.dart                    # 入口，Splash 自动登录检测
├── api/
│   └── api_client.dart          # API 封装，SSL Pinning，token 持久化
├── providers/
│   └── auth_provider.dart       # 登录状态管理
└── screens/
    ├── login_screen.dart        # 三步登录（手机号→图片验证码→短信验证码）
    ├── home_screen.dart         # 首页，设备列表，下拉刷新
    ├── device_screen.dart       # 设备详情，取水控制，状态轮询
    └── qr_scan_screen.dart      # 扫码绑定设备
```


## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)

## 免责声明

本项目仅供学习交流，不得用于商业用途。接口和资源版权归原平台所有。使用本软件产生的任何问题与作者无关。

## License

MIT
