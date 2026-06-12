# 慧生活798 (com.cloudora.android) — 完整 API 对接文档

> **逆向工具**: JADX MCP + IDA Pro 7.x + Frida 17.9.9  
> **日期**: 2026-06-12  
> **包名**: `com.cloudora.android`  
> **线上地址**: `https://i.ilife798.com`  
> **状态**: ✅ 全量 API 已打通，登录/积分/钱包/设备/账单 均已验证

---

## 目录

1. [基础信息](#1-基础信息)
2. [认证流程](#2-认证流程)
3. [积分系统 ★](#3-积分系统-)
4. [设备控制](#4-设备控制)
5. [钱包支付](#5-钱包支付)
6. [账单模块](#6-账单模块)
7. [PGA 签约](#7-pga-签约)
8. [工单模块](#8-工单模块)
9. [IC 卡模块](#9-ic-卡模块)
10. [扫码模块](#10-扫码模块)
11. [其他模块](#11-其他模块)
12. [数据模型字典](#12-数据模型字典)
13. [Sign 算法](#13-sign-算法)
14. [环境配置](#14-环境配置)

---

## 1. 基础信息

### 1.1 环境

| 环境 | Base URL | 传输 |
|------|----------|------|
| `online` | `https://i.ilife798.com` | ✅ HTTPS |
| `prerelease` | `https://prerelease.ilife798.com` | ✅ HTTPS |
| `act` | `https://act.hnkzy.com` | ✅ HTTPS |
| `act2` | `https://act2.hnkzy.com` | ✅ HTTPS |
| `dl` | `http://dl.hnkzy.com:8081` | ⚠️ HTTP 明文 |

驾考题库: `https://driving-exam.ilife798.com`

### 1.2 请求头

```http
Authorization: <token>              # 登录后必带
ApplicationType: 1,1                # 固定
VersionCode: <app版本号>             # 如 3.1.4
user-agent: Android_ilife798_<v>    # 如 Android_ilife798_314
Content-Type: application/json
Accept-Encoding: gzip
Connection: Keep-Alive
```

### 1.3 通用响应格式 `BaseReq<T>`

```json
{
  "code": 0,           // >=0 成功; -99 签名过期需重新登录; -98 频率限制
  "data": {},          // 泛型, 成功时返回具体数据
  "msg": "string",     // 错误提示
  "size": 0,           // 列表分页大小
  "time": 1781240935203 // 服务器毫秒时间戳
}
```

| code | 含义 |
|------|------|
| >= 0 | 成功 |
| -1 | 业务错误 (msg 中有详情) |
| -10 | 短信发送频率限制 |
| -98 | 请求过于频繁 (接口限流) |
| -99 | 签名验签失败, 需重新登录 |

### 1.4 网络层架构

```
Retrofit2 + OkHttp3
  ├── BasicParamsInterceptor (动态 Header/Query 注入)
  ├── HttpLoggingInterceptor (Level: BODY)
  └── GsonConverterFactory
```

---

## 2. 认证流程

### 2.1 登录流程图

```
GET /api/v1/captcha/?s=<random>&r=<timestamp_ms>
  ↓  返回 PNG/JPEG 图片
用户输入验证码
  ↓
POST /api/v1/acc/login/code
  ↓  发送短信验证码到手机
用户输入短信验证码
  ↓
POST /api/v1/acc/login
  ↓  返回 token + uid + eid
后续请求带 Header: Authorization: <token>
```

### 2.2 接口详情

#### 获取图形验证码

```
GET /api/v1/captcha/?s={float}&r={int_ms}

Query:
  s   float   (必填) 随机数, 也作为验证码 session ID
  r   int     (必填) 毫秒时间戳, 防缓存

Response:
  Content-Type: image/png 或 image/jpeg
  Body: 图片二进制流

⚠️ s 必须和后续 /acc/login/code 中的 s 一致 (session 关联)
```

#### 发送短信验证码

```
POST /api/v1/acc/login/code
Headers: 无需 Authorization

Body (JSON):
{
  "un":       string,   (必填) 手机号
  "authCode": string,   (必填) 图形验证码答案
  "s":        number    (必填) 来自 captcha 接口的 s, 验证码 session ID!
}

Response: BaseReq
  code=0  → 短信已发送
  code=-10 → 短信发送频率限制
  code=-2  → 图形验证码错误
```

#### 验证码登录

```
POST /api/v1/acc/login
Headers: 无需 Authorization

Body (JSON):
{
  "un":       string,   (必填) 手机号
  "authCode": string    (必填) 短信验证码
}

Response: BaseReq<LoginData>
{
  "code": 0,
  "data": {
    "al": {                    // LoginInfo
      "token": "string",       // ★ JWT token, 后续所有请求用
      "uid":   "string",       // ★ 用户唯一ID (16位hex)
      "eid":   "string",       // 企业ID (16位hex)
      "atype": 0,              // int 账号类型
      "stype": 0               // int 子类型
    },
    "ar": {}                   // LoginConfigInfo
  }
}
```

#### 校验 Token

```
GET /api/v1/acc/stat
Headers: Authorization: <token>

Response: BaseReq
  code>=0 → token 有效
```

#### 登出

```
GET /api/v1/acc/logout
Headers: Authorization: <token>

Response: BaseReq
```

#### 发送注销验证码

```
POST /api/v1/acc/sms/cancel

Body (JSON):
{
  "un":       string,   (必填) 手机号
  "authCode": string,   (必填) 图形验证码
  "s":        number    (必填) 验证码 session ID
}

Response: BaseReq
```

#### 注销账号

```
POST /api/v1/acc/cancel/account
Headers: Authorization: <token>

Body: CancelAccountParm

Response: BaseReq
```

#### 检查是否可注销

```
GET /api/v1/acc/valid/cancel
Headers: Authorization: <token>

Response: BaseReq
```

### 2.3 账号管理

#### 获取账户信息

```
GET /api/v1/acc/
Headers: Authorization: <token>

Response: BaseReq<AccountData>
{
  "code": 0,
  "data": {
    "account": {               // UserInfo
      "id":    "string",       // 用户ID
      "name":  "string",       // 昵称
      "phone": "string",       // 手机号
      "avt":   "string"        // 头像URL
    }
  }
}
```

#### 更新账号设置

```
POST /api/v1/acc/upt
Headers: Authorization: <token>

Body (JSON):
{
  "name":        "string",   // 新昵称
  "useScore":    0,          // int 积分抵扣开关: 1=开启 0=关闭
  "newPayPwd":   "string",   // ⚠️ 新支付密码, 明文传输!
  "oriPayPwd":   "string",   // ⚠️ 旧支付密码, 明文传输!
  "resetPayPwd": false,      // bool 是否重置密码
  "type":        0           // int 修改类型
}

Response: BaseReq  ({"code":0} 成功)
```

#### 积分抵扣开关 (快捷)

```
POST /api/v1/acc/upt
Headers: Authorization: <token>

Body: {"useScore": 1}   // 1=开启积分抵扣, 0=关闭

Response: {"code": 0}
```

已验证: `{"useScore":1}` → `{"code":0}` ✅

#### 实名认证

```
POST /api/v1/acc/basic/acc-attestation
Headers: Authorization: <token>

Body (JSON):
{
  "ep":        AttestationEpParm,
  "name":      "string",    // 真实姓名
  "stuNum":    "string",    // 学号
  "idCard":    "string",    // ⚠️ 身份证号, 明文传输!
  "classInfo": AttestationClassParm,
  "dev":       AttestationEpParm
}

Response: BaseReq
```

---

## 3. 积分系统 ★

> **Sign 算法**: `MD5(adId + v20 + token[-8:] + uid[-8:] + "aslkdvcniu34h9tgufh278wv2")`  
> **来源**: `libnative_crypto.so` → `NativeCryptoUtils.nativeSign()` (IDA Pro 逆向验证)  
> **与 PGA sign 区分**: PGA 签约 sign 是服务端生成的 (见第 7 章), 积分 sign 是客户端 MD5

### 3.1 任务列表

```
GET /api/v1/acc/score/mission-lst
Headers: Authorization: <token>

Response: BaseReq<TaskData>
{
  "code": 0,
  "time": 1781240935203,         // ★ 服务端毫秒时间戳, 用于 sign 生成
  "data": {
    "missions": [                // List<MissionInfo>
      {
        "id":    "string",       // 任务唯一ID
        "name":  "string",       // 任务名称, 如 "观看广告，获取积分"
        "desc":  "string",       // 任务描述
        "refId": "string",       // ★ 关联广告ID, sign 生成的 adId 参数
        "score": 10,             // ★ int 奖励积分数
        "type":  1,              // int 任务大类
        "mtype": 3,              // int 任务类型 (3=广告)
        "atype": 0,              // int 广告类型
        "limit": 5,              // int 每日限制次数 (-4=不限)
        "cnt":   3,              // int 已完成次数
        "stype": [1, 2],         // List<int> 积分类型
        "apply": [1, 2, 3],      // List<int> 适用对象类型
        "range": [1, 7],         // List<int> 有效期(星期几)
        "imgs":  ["url"],        // List<string> 图标URL
        "url":   "string",       // 跳转URL
        "begin": 1717920000000,  // long 任务开始时间(ms)
        "end":   1718006400000,  // long 任务结束时间(ms)
        "validTime": 30          // int 有效时长(秒)
      }
    ],
    "accScoreRsp": {             // AccScoreRspInfo 积分汇总
      "score":      "105",       // string 当前可用积分
      "totalScore": "105",       // string 累计获得积分
      "validScore": "105",       // string 有效积分
      "gift":       "0",         // string 礼品
      "limits": [                // 任务限制信息
        {
          "limit":  0,           // int 当日剩余可领次数, 0=已满
          "refId":  "string"     // 对应任务 refId
        }
      ],
      "daily": {},               // DailyInfo 每日信息
      "address": {}              // 地址
    },
    "lotteryEnable": true,       // bool 是否可抽奖
    "dailyRSP": {}               // DailyRspInfo
  }
}
```

### 3.2 积分发放 ★ 核心

```
POST /api/v1/acc/score/score-send?sign={MD5}&s=1
Headers: Authorization: <token>
Content-Type: application/json

Query:
  sign   string   (必填) ★ MD5 签名, 见第13章
  s      int      (必填) 固定值 1

Body (JSON):
{
  "adId":        "string",   (必填) 任务 refId
  "type":        101,        (必填) int 固定值 101
  "weekday":     null,       int|null 星期几 (补签时传入)
  "addScoreType": 1,         (必填) int 完成类型: 1=WATCH_AD 2=FULL_AD
  "addScore":    10,         (必填) int 积分数
  "token":       "string"    (必填) 登录 token (冗余, Header 已有)
}

Response: BaseReq
  code=0  → 积分发放成功
  code=-98 → 请求过于频繁 (需等 10-20 秒重试)
  code=-1  → 任务未完成或条件不满足
```

**已验证成功示例**:

```
refId=1705776998 (观看视频) → code=0 +30分
refId=popsreen    (观看广告) → code=0 +10分
refId=50_2023112825000072047 (免费权益) → code=-1 需要真正完成任务
```

### 3.3 积分明细

```
GET /api/v1/acc/score/score-lst?page={int}&size={int}&hasCount={bool}&src={int}
Headers: Authorization: <token>

Query:
  page     int    (必填) 页码
  size     int    (必填) 每页条数
  hasCount bool   (可选) 是否返回总数
  src      int    (可选) 积分来源筛选: 0=全部

Response: BaseReq<List<PointsDetailInfo>>
{
  "code": 0,
  "data": [],
  "size": "0"
}
```

---

## 4. 设备控制

### 4.1 首页 Master 数据

```
GET /api/v1/ui/app/master
Headers: Authorization: <token>

Response: BaseReq<MasterData>
{
  "code": 0,
  "data": {
    "account": {                 // UserInfo
      "id":    "string",
      "name":  "string",
      "phone": "string",
      "avt":   "string"
    },
    "ads": [                     // List<AdvertisementInfo>
      {
        "id":    "string",
        "title": "string",
        "imgs":  ["url"],
        "mtype": 3,
        "url":   "string"
      }
    ],
    "favos": [                   // List<DeviceInfo> 收藏的设备
      {
        "id":     "string",      // ★ 设备ID (did)
        "name":   "string",      // 设备名称
        "status": 0,             // int 设备状态
        "addr": {                // AddressInfo
          "prov":   "string",
          "city":   "string",
          "area":   "string",
          "detail": "string",
          "lng":    113.123456,
          "lat":    23.123456,
          "poiName":"string"
        },
        "bm": {                  // DeviceModelInfo
          "dtype": 8,            // ★ int 设备类型: 8=直饮水机, 1=取货机, 2=POS机
          "name":  "string",
          "desc":  "string",
          "spec":  "string",
          "brand": "string",
          "model": "string",
          "unit":  "string"
        },
        "ep": {                  // EnterpriseInfo
          "id":     "string",    // ★ 企业ID (eid)
          "name":   "string",
          "status": 1
        },
        "gene": {                // DevicePropertyInfo
          "status": 0,           // int 运行状态
          "price":  0,           // long 价格(分)
          "unit":   "string",
          "secs":   21.8,        // float 使用秒数
          "vel":    0.6          // float 流速
        },
        "ext": {                 // DeviceExtInfo
          "tid": "string"        // 终端ID
        },
        "subs": [                // List<DeviceSubsInfo> 子设备
          { "out": 0.0 },
          { "out": 0.405 }
        ],
        "gtype":  0,             // int 商品类型
        "btype":  -1,            // int 业务类型
        "ntype":  -1,            // int 通知类型
        "prepay": false,         // bool 是否支持预付
        "fmv":    "string",      // 固件版本
        "utime":  1781174324228  // long 更新时间(ms)
      }
    ],
    "pltTotalScore": "316449015" // string 平台总积分
  }
}
```

### 4.2 设备详情

```
GET /api/v1/ui/app/dev/home/1?did={string}&apply={int}
Headers: Authorization: <token>

Query:
  did    string   (必填) 设备ID, 如 "862270065552594"
  apply  int      (可选) 默认 0

Response: BaseReq<DeviceDetailData>
{
  "code": 0,
  "data": {
    "device":  { DeviceInfo },       // 设备信息 (同 Master 中的结构)
    "wallet":  {                     // WalletInfo 用户在此设备的钱包
      "id":      "string",           // 钱包ID = uid + eid
      "olCash":  0.01,               // float 线上余额-现金
      "olGift":  0.0,                // float 线上余额-赠送
      "ofCash":  0.0,                // float 线下余额-现金
      "ofGift":  0.0,                // float 线下余额-赠送
      "total":   0.01,               // float 总余额
      "rtime":   1726994046075,      // long 充值时间(ms)
      "times":   0,                  // int 使用次数
      "utime":   1781189780119,      // long 更新时间(ms)
      "ep":      { EnterpriseInfo }, // 所属企业
      "owner":   {                   // 拥有者
        "id":   "string",
        "name": "string",
        "pn":   "string"             // 手机号
      }
    },
    "payItems": [                    // List<PayItemInfo>
      { "type": 91 }
    ],
    "deviceShare": {},               // DeviceShare 分享信息
    "user":  { UserInfo },
    "ads":   [ AdvertisementInfo ],
    "parts": {},                     // DevicePartsInfo 配件
    "showAd": 0,
    "dr":     {},                    // DeviceDrInfo
    "prepay": false,
    "encrypt": "string",             // ⚠️ 加密数据 (用途不明)
    "lockDoorExt": {}                // 门锁扩展
  }
}
```

### 4.3 设备启动 ★

```
GET /api/v1/dev/start?did={string}&upgrade={bool}&ptype={int}&args={string}&rcp={bool}&cnt={int}
Headers: Authorization: <token>

Query:
  did      string   (必填) 设备ID
  upgrade  bool     (可选) 是否升级模式, 默认 false
  ptype    int      (可选) 支付类型, 默认 0
  args     string   (可选) 额外参数
  rcp      bool     (可选) 是否领取模式, 默认 false
  cnt      int      (可选) 数量/次数, 默认 1

Response: BaseReq
  code>=0 → 设备已启动
```

### 4.4 设备停止

```
GET /api/v1/dev/end?did={string}&rcp={bool}
Headers: Authorization: <token>

Query:
  did   string   (必填) 设备ID
  rcp   bool     (可选) 默认 false

Response: BaseReq
```

### 4.5 发送设备指令 ★

```
POST /api/v1/ui/app/dev/command
Headers: Authorization: <token>

Body (JSON):
{
  "id": "string",              // (必填) 设备ID
  "gene": {                    // CmdGeneInfo
    "status": 1,               // int 设备状态: 1=ON(开启), 0=OFF(关闭)
    "uid":    "string",        // string 操作用户ID
    "mode":   100              // int ★ 查询模式
  },
  "token": "string"            // 登录token
}

mode 枚举:
  100  T100_QUERY  取货机 (PICK_UP_MACHINE, dtype=1)
  62   T62_QUERY   POS机 (POS_MACHINE, dtype=2)

Response: BaseReq
```

### 4.6 设备状态查询

```
GET /api/v1/ui/app/dev/status?did={string}&more={bool}
Headers: Authorization: <token>

Query:
  did   string   (必填) 设备ID
  more  bool     (可选) 是否返回更多信息

Response: BaseReq<DeviceDetailData>
```

### 4.7 设备收藏/取消

```
GET /api/v1/dev/favo?did={string}&remove={int}
Headers: Authorization: <token>

Query:
  did     string   (必填) 设备ID
  remove  int      (必填) 0=收藏, 非0=取消

Response: BaseReq
```

### 4.8 设置设备模式

```
GET /api/v1/dev/mode/start?did={string}&mode={int}&args={string}
Headers: Authorization: <token>

Query:
  did   string   (必填) 设备ID
  mode  int      (必填) 模式
  args  string   (可选) 额外参数

Response: BaseReq
```

### 4.9 设备使用模式选择

```
GET /api/v1/ui/app/dev/dev-use-way?way={any}
Headers: Authorization: <token>

Query:
  way   string|int   使用方式

Response: BaseReq
```

### 4.10 附近设备

```
GET /api/v1/dev/near?eid={string}&dtype={int}&lng={float}&lat={float}&size={int}
Headers: Authorization: <token>

Query:
  eid    string   (必填) 企业ID
  dtype  int      (可选) 设备类型
  lng    float    (可选) 经度
  lat    float    (可选) 纬度
  size   int      (可选) 每页条数, 默认 20

Response: BaseReq<List<NearbyDeviceData>>
```

### 4.11 设备认领

```
GET /api/v1/dev/receive?mac={string}&data={string}
Headers: Authorization: <token>

Query:
  mac   string   (必填) MAC地址
  data  string   (可选) 加密数据

Response: BaseReq<Object>
```

### 4.12 设备分享列表

```
GET /api/v1/dev/share/lst?uid={string}&dtype={int}
Headers: Authorization: <token>

Query:
  uid    string   (必填) 用户ID
  dtype  int      (可选) 设备类型

Response: BaseReq<List<DoorLockInfo>>
```

### 4.13 淋浴设备

```
GET /api/v1/dev/rela/view-stat?eid={string}
Headers: Authorization: <token>

Query:
  eid   string   (必填) 企业ID

Response: BaseReq<ShowerData>
```

---

## 5. 钱包支付

### 5.1 钱包详情

```
GET /api/v1/acc/wallet/detail?id={string}&eid={string}&pn={string}
Headers: Authorization: <token>

Query:
  id   string   (必填) 钱包ID 或 设备ID
  eid  string   (必填) 企业ID
  pn   string   (可选) 手机号

Response: BaseReq<WalletInfo>
{
  "code": 0,
  "data": {
    "auth":     false,          // bool 是否实名认证
    "ep":       { EnterpriseInfo },
    "owner":    {                // 拥有者
      "id":   "string",
      "name": "string",
      "pn":   "string"
    },
    "olCash":   0.0,            // float 线上余额-现金
    "olGift":   0.0,            // float 线上余额-赠送
    "ofCash":   0.0,            // float 线下余额-现金
    "ofGift":   0.0,            // float 线下余额-赠送
    "total":    0.0             // float 总余额
  }
}

⚠️ 注意: id 和 eid 需同时传, 只传 eid 会返回 code=-1 "请求参数错误"
```

### 5.2 钱包拥有者

```
GET /api/v1/acc/wallet/owner?eid={string}&all={bool}
Headers: Authorization: <token>

Query:
  eid   string   (必填) 企业ID
  all   bool     (可选) 是否全部

Response: BaseReq<WalletReq>
```

### 5.3 联系人列表

```
GET /api/v1/acc/wallet/contact?pn={string}
Headers: Authorization: <token>

Query:
  pn   string   电话号码

Response: BaseReq<List<ContactInfo>>
```

### 5.4 退款

```
POST /api/v1/acc/wallet/refund
Headers: Authorization: <token>

Body (JSON):
{
  "eid":  "string",   (必填) 企业ID
  "type": 0           int 退款类型

Response: BaseReq<Object>
```

### 5.5 支付渠道

```
GET /api/v1/bill/pay/channels?id={string}
Headers: Authorization: <token>

Query:
  id   string   订单ID

Response: BaseReq<PayChannelData>
```

### 5.6 创建预付订单

```
GET /api/v1/trans/prepay/{type}?id={string}
Headers: Authorization: <token>

Path:
  type   string   支付类型: "alipay" | "wechat" | ...

Query:
  id     string   关联ID

Response: BaseReq<Object>
```

### 5.7 确认支付

```
GET /api/v1/trans/confirm?id={string}
Headers: Authorization: <token>

Query:
  id   string   订单ID

Response: BaseReq<Object>
```

### 5.8 关闭订单

```
GET /api/v1/trans/close?id={string}
Headers: Authorization: <token>

Query:
  id   string   订单ID

Response: BaseReq
```

### 5.9 订单错误信息

```
GET /api/v1/trans/errorMsg?id={string}
Headers: Authorization: <token>

Query:
  id   string   订单ID

Response: BaseReq<Object>
```

### 5.10 获取支付 Ticket

```
POST /api/v1/sys/ticket
Headers: Authorization: <token>

Body: Map<String, Boolean>

Response: BaseReq<String>  (ticket 字符串)
```

---

## 6. 账单模块

### 6.1 账单列表

```
GET /api/v1/bill/lst-owner?page={int}&size={int}&hasCount={bool}&status={int}
Headers: Authorization: <token>

Query:
  page      int    (必填) 页码
  size      int    (必填) 每页条数
  hasCount  bool   (可选) 是否返回总数
  status    int    (可选) 状态筛选

Response: BaseReq<List<BillData>>
{
  "code": 0,
  "size": 23,
  "data": [
    {
      "id":     "string",          // 账单ID
      "cata":   6,                 // int 分类
      "ctime":  1781174275000,     // long 创建时间(ms)
      "utime":  1781174325305,     // long 更新时间(ms)
      "dir":    1,                 // int 方向: 1=支出
      "msg":    "string",          // 描述, 如 "管线/饮水机设备(6-0612)消费"
      "payment": 0.21,             // float 金额
      "status": 3,                 // int 状态: 3=已完成
      "type":   21,                // int 账单类型
      "dev": {                     // 关联设备
        "bm": { "dtype": 8 }
      },
      "owner": {                   // 拥有者
        "id":   "string",
        "name": "string",
        "oid":  "string",
        "pn":   "string"
      }
    }
  ]
}
```

### 6.2 账单详情

```
GET /api/v1/bill/view-full?id={string}
Headers: Authorization: <token>

Query:
  id   string   (必填) 账单ID

Response: BaseReq<BillDetailData>
{
  "code": 0,
  "data": {
    "bill": {
      "cata":     6,               // int 分类
      "commis":   0.0,             // float 手续费
      "ctime":    1781174275000,   // long 创建时间
      "utime":    1781174325305,   // long 更新时间
      "dev":      { DeviceInfo },  // 关联设备完整信息
      "dir":      1,               // int 方向
      "discount": 0.0,             // float 折扣
      "ep":       { EnterpriseInfo },
      "id":       "string",
      "mk":       { "olCash": 0.21 },  // 标记金额
      "mode":     2,               // int 模式
      "msg":      "string",
      "oid":      "string",
      "owner":    {                // 拥有者
        "id":   "string",
        "name": "string",
        "oid":  "string",
        "pn":   "string"
      },
      "payee":   "string",         // 收款方
      "payment": 0.21,             // float 支付金额
      "refId":   "string",
      "status":  3,                // int 状态
      "stype":   1,                // int 子类型
      "tag":     "string",         // 支付宝交易号
      "type":    21                // int 账单类型
    }
  }
}
```

### 6.3 创建账单

```
POST /api/v1/bill/save
Headers: Authorization: <token>

Body: RechargeBillParm

Response: BaseReq<Long>  (新账单ID)
```

---

## 7. PGA 签约

> PGA = Payment Gateway Authorization  
> ⚠️ PGA sign 是 **服务端生成**的, 和积分 sign (客户端 MD5) 是两套体系

### 7.1 获取签约 Sign (服务端生成)

```
GET /api/v1/ui/app/sign-pga?type={int}
Headers: Authorization: <token>

Query:
  type   int   PGAgreementType: 1=支付宝, 2=银联

Response: BaseReq<AccountSignData>
{
  "code": 0,
  "data": {
    "sign":   "string",     // ★ 服务端生成的签名
    "status": 2,            // int 签约状态
    "type":   20,           // int 类型
    "code":   "string",     // pgacode (支付宝小程序用)
    "id":     "string",     // 签约记录ID
    "uid":    "string",     // 用户ID
    "bTime":  null,         // long|null 开始时间
    "cTime":  null,         // long|null 创建时间
    "vTime":  null,         // long|null 验证时间
    "appId":  null,         // string|null
    "lId":    null,         // string|null
    "oId":    null          // string|null
  }
}
```

### 7.2 签约渠道列表

```
GET /api/v1/ui/app/acc-pgas?eid={string}
Headers: Authorization: <token>

Query:
  eid   string   (必填) 企业ID

Response: BaseReq<SignData>
{
  "code": 0,
  "data": {
    "channels": [
      { "type": 1, "name": "支付宝" },
      { "type": 2, "name": "银联" }
    ]
  }
}
```

### 7.3 检查签约状态

```
GET /api/v1/ui/app/pga-check?eid={string}&cardNo={string}&isCombine={bool}
Headers: Authorization: <token>

Query:
  eid        string   (必填) 企业ID
  cardNo     string   (可选) 卡号
  isCombine  bool     (可选) 是否合并, 默认 false

Response: BaseReq<AccountSignData>
```

### 7.4 解约

```
GET /api/v1/pga/unsign-owner
Headers: Authorization: <token>

Response: BaseReq
```

---

## 8. 工单模块

### 8.1 工单列表

```
GET /api/v1/ord/lst-owner?page={int}&size={int}&hasCount={bool}&uid={string}&types={string}&isPos={bool}&hasBill={bool}&sort={string}
Headers: Authorization: <token>

Query:
  page      int      (必填) 页码
  size      int      (必填) 每页条数
  hasCount  bool     (可选)
  uid       string   (可选) 用户ID
  types     string   (可选) 工单类型
  isPos     bool     (可选)
  hasBill   bool     (可选)
  sort      string   (可选) 排序

Response: BaseReq<List<WorkOrderDetailInfo>>
```

### 8.2 工单详情

```
GET /api/v1/ord/view-full?id={string}
Headers: Authorization: <token>

Query:
  id   string   (必填) 工单ID

Response: BaseReq<WorkOrderDetailData>
```

### 8.3 提交工单

```
POST /api/v1/ord/save
Headers: Authorization: <token>

Body (JSON):
{
  "did":     "string",       // 设备ID
  "note":    "string",       // 备注
  "rtime":   1718000000000,  // long 预约时间戳(ms)
  "type":    1,              // int 工单类型
  "contact": {},             // 联系人
  "owner":   {},             // 拥有者
  "addr":    {},             // 地址
  "status":  0,              // int
  "ep":      {},             // 企业信息
  "mode":    0,              // int
  "station": {},             // 站点
  "imgs":    ["url"]         // List<string> 图片URL数组
}

Response: BaseReq<String>  (工单ID)
```

### 8.4 评价工单

```
GET /api/v1/ord/appraised?id={string}&score={int}&desc={string}
Headers: Authorization: <token>

Query:
  id     string   (必填) 工单ID
  score  int      (必填) 评分
  desc   string   (可选) 评价内容

Response: BaseReq
```

### 8.5 取消工单

```
POST /api/v1/ord/cancel
Headers: Authorization: <token>

Body: Map<String, String>

Response: BaseReq
```

### 8.6 工单日志

```
GET /api/v1/log/lst?refId={string}&hasCount={bool}
Headers: Authorization: <token>

Query:
  refId     string   (必填) 关联ID
  hasCount  bool     (可选)

Response: BaseReq
```

---

## 9. IC 卡模块

### 9.1 绑定 IC 卡

```
POST /api/v1/ic/bind
Body: CardBindParm
Response: BaseReq<Object>
```

### 9.2 解绑 IC 卡

```
POST /api/v1/ic/unbind
Body: Map<String, String>
Response: BaseReq<List<Object>>
```

### 9.3 IC 卡列表

```
GET /api/v1/ic/lst-owner?size={int}
Response: BaseReq<List<CardInfo>>
```

### 9.4 IC 卡详情

```
GET /api/v1/ic/owner-view?id={string}
Response: BaseReq<CardInfo>
```

### 9.5 更新 IC 卡

```
POST /api/v1/ic/upt
Body: CardBindParm
Response: BaseReq<Object>
```

### 9.6 验证 IC 卡

```
POST /api/v1/ic/valid
Body: Map<String, String>
Response: BaseReq<List<Object>>
```

### 9.7 IC 卡加密查看

```
GET /api/v1/ic/cipher/view-owner?id={string}
Response: BaseReq<EnterpriseInfo>
```

---

## 10. 扫码模块

### 10.1 扫码解析 ★

```
GET /api/v1/qr/use?id={string}
Headers: Authorization: <token>

Query:
  id   string   (必填) 扫描结果/二维码ID

Response: BaseReq<QRCodeData>
{
  "code": 0,
  "data": {
    "qr":     {},              // QRCodeInfo 二维码元信息
    "dev":    { DeviceInfo },  // 设备信息 (可为null)
    "card":   { CardInfo },    // IC卡信息 (可为null)
    "wallet": { WalletInfo }   // 钱包信息 (可为null)
  }
}

扫码结果类型分流 (type → 处理):
  2 → "b"      设备
  3 → "s"      扫码设备
  5 → "billing" 账单支付
  6 → "vip"    VIP会员
  7 → "wallet" 钱包
```

---

## 11. 其他模块

### 11.1 优惠券

```
GET /api/v1/promo/lst-owner?type={List<int>}&status={int}&id={string}
Response: BaseReq<List<CouponsData>>

GET /api/v1/promo/apply?bid={string}&pit={string}
Response: BaseReq
```

### 11.2 广告

```
GET /api/v1/ad/acc-lst       → BaseReq  广告列表
GET /api/v1/ad/view?id={str} → BaseReq  广告详情
GET /api/v1/ad/swtich        → BaseReq  广告开关
```

### 11.3 文件上传

```
POST /api/v1/fs/up
Content-Type: multipart/form-data

Response: BaseReq
```

### 11.4 App 更新

```
GET /api/v1/sys/app/upt?appid={string}&version={string}&type={int}
Response: BaseReq<LatestVersionData>
```

### 11.5 商户

```
GET /api/v1/ep/lst-simple                    → BaseReq  商户列表
GET /api/v1/ep/station/lst?eid={string}       → BaseReq  商户附近
GET /api/v1/ep/station/view?eid={string}      → BaseReq  商户详情
```

### 11.6 商品

```
GET /api/v1/prd/lst                           → BaseReq  商品列表
```

### 11.7 驾考题库

```
GET /api/v1/acc/master?subject={int}&type={string}  (base: driving-exam)
GET /api/v1/question/lst?{params}                    (base: driving-exam)
```

### 11.8 消息通知

```
POST/GET /api/v1/cloud/msg/internal-msg/*
```

---

## 12. 数据模型字典

### DeviceInfo (设备信息)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 设备唯一ID |
| name | String | 设备名称 |
| status | int | 设备状态 |
| addr | AddressInfo | 地址信息 |
| bm | DeviceModelInfo | 设备型号 (含 ★dtype) |
| ep | EnterpriseInfo | 所属企业 (含 ★eid) |
| gene | DevicePropertyInfo | 设备属性 |
| gtype | int | 商品类型 |
| btype | int | 业务类型 |
| ntype | int | 通知类型 |
| gs | GoodsShelfInfo | 货架信息 |
| ls | LeaseSettingInfo | 租赁设置 |
| ext | DeviceExtInfo | 扩展信息 |
| adShow | int | 广告展示 |
| refId | String | 关联ID |
| subs | List\<DeviceSubsInfo\> | 子设备 |
| prepay | Boolean | 是否支持预付 |
| fmv | String | 固件版本 |
| utime | long | 更新时间(ms) |

### DeviceModelInfo.bm.dtype 枚举

| dtype | 名称 | mode |
|-------|------|------|
| 1 | 取货机 PICK_UP_MACHINE | T100_QUERY (100) |
| 2 | POS机 POS_MACHINE | T62_QUERY (62) |
| 8 | 直饮水机 | — |

### WalletInfo (钱包)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 钱包ID = uid + eid |
| olCash | float | 线上余额-现金 |
| olGift | float | 线上余额-赠送 |
| ofCash | float | 线下余额-现金 |
| ofGift | float | 线下余额-赠送 |
| total | float | 总余额 |
| rtime | long | 充值时间(ms) |
| times | int | 使用次数 |
| utime | long | 更新时间(ms) |
| ep | EnterpriseInfo | 所属企业 |
| owner | UserInfo | 拥有者 |
| auth | boolean | 是否实名 |
| perms | Map\<String,Long\> | 权限 |

### MissionInfo (任务)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 任务ID |
| name | String | 任务名称 |
| desc | String | 任务描述 |
| refId | String | ★ 关联广告ID (sign 的 adId) |
| score | int | ★ 奖励积分 |
| type | int | 任务大类 |
| mtype | int | 任务类型 (3=广告) |
| atype | int | 广告类型 |
| limit | int | 每日限制 (-4=不限) |
| cnt | int | 已完成次数 |
| stype | List\<int\> | 积分类型 |
| apply | List\<int\> | 适用对象 |
| range | List\<int\> | 有效期(星期) |
| imgs | List\<String\> | 图标URL |
| url | String | 跳转URL |
| begin | long | 开始时间(ms) |
| end | long | 结束时间(ms) |
| validTime | int | 有效时长(秒) |

### BillData (账单)

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 账单ID |
| cata | int | 分类 (6=饮水) |
| ctime | long | 创建时间(ms) |
| utime | long | 更新时间(ms) |
| dir | int | 方向 (1=支出) |
| payment | float | 金额 |
| status | int | 状态 (3=已完成) |
| type | int | 账单类型 (21=消费) |
| stype | int | 子类型 |
| tag | String | 支付宝交易号 |
| msg | String | 描述 |
| mode | int | 模式 |
| commis | float | 手续费 |
| discount | float | 折扣 |
| dev | DeviceInfo | 关联设备 |
| ep | EnterpriseInfo | 企业 |
| owner | UserInfo | 拥有者 |
| oid | String | 订单ID |
| payee | String | 收款方 |

### LoginData (登录)

| 字段 | 类型 | 说明 |
|------|------|------|
| al.token | String | ★ JWT Token |
| al.uid | String | ★ 用户ID (16位hex) |
| al.eid | String | 企业ID (16位hex) |
| al.atype | int | 账号类型 |
| al.stype | int | 子类型 |

---

## 13. Sign 算法

### 13.1 积分 Sign (客户端 MD5)

> **来源**: `libnative_crypto.so` → `Java_com_ilife_lib_common_util_NativeCryptoUtils_nativeSign`  
> **验证**: ✅ 已通过 `score-send` 接口验证成功 (`code=0`)

```
sign = MD5(adId + v20 + token[-8:] + uid[-8:] + SALT)

SALT = "aslkdvcniu34h9tgufh278wv2"  (25字节, .rodata 提取)
```

#### v20 计算

```c
// IDA Pro 反编译原始代码:
v20 = 10 * ((serverTs - localTs + std::chrono::system_clock::now() / 1000) / 10000);

// 等价于:
now_ms = int(time.time() * 1000)
v20 = 10 * ((server_ts - local_ts + now_ms) // 10000)
// ≈ (server_ts - local_ts + now_ms) / 1000  秒级整数
```

#### 参数来源

| 参数 | 来源 | 说明 |
|------|------|------|
| adId | mission.refId | 从任务列表获取 |
| token[-8:] | 登录 token 末8字符 | 完整 JWT |
| uid[-8:] | 登录 uid 末8字符 | 16位 hex |
| local_ts | System.currentTimeMillis() | 获取任务列表时记录 |
| server_ts | BaseReq.time | 任务列表响应中的 time 字段 |
| SALT | libnative_crypto.so | 硬编码 |

#### Python 实现

```python
import hashlib
import time

SALT = "aslkdvcniu34h9tgufh278wv2"

def generate_score_sign(ad_id, token, uid, local_ts, server_ts, now_ms=None):
    if now_ms is None:
        now_ms = int(time.time() * 1000)
    v20 = 10 * ((server_ts - local_ts + now_ms) // 10000)
    raw = f"{ad_id}{v20}{token[-8:]}{uid[-8:]}{SALT}"
    return hashlib.md5(raw.encode()).hexdigest()
```

### 13.2 PGA Sign (服务端生成)

不同于积分 sign, PGA 签约 sign 由服务端通过 `GET /api/v1/ui/app/sign-pga?type={int}` 生成下发, 客户端仅透传。

---

## 14. 环境配置

### 14.1 多环境

```python
ENVIRONMENTS = {
    "online":     "https://i.ilife798.com",
    "prerelease": "https://prerelease.ilife798.com",
    "act":        "https://act.hnkzy.com",
    "act2":       "https://act2.hnkzy.com",
    "dl":         "http://dl.hnkzy.com:8081",   # ⚠️ HTTP 明文!
}
```

### 14.2 穿山甲广告 SDK

| 配置 | 值 |
|------|-----|
| AppId | 5655586 |
| AppName | 慧生活798 |
| useMediation | true |

### 14.3 支付宝小程序

| 配置 | 值 |
|------|-----|
| AppId | 2019061465519660 |
| 积分页 | /task/pouch |

---

## 附录 A: 完整端点清单 (67+)

| # | 方法 | 路径 | 说明 |
|---|------|------|------|
| 1 | GET | /api/v1/captcha/ | 图形验证码 |
| 2 | POST | /api/v1/acc/login/code | 发送短信验证码 |
| 3 | POST | /api/v1/acc/login | 验证码登录 |
| 4 | GET | /api/v1/acc/stat | 校验Token |
| 5 | GET | /api/v1/acc/logout | 登出 |
| 6 | GET | /api/v1/acc/ | 账户信息 |
| 7 | POST | /api/v1/acc/upt | 更新账号设置 |
| 8 | POST | /api/v1/acc/cac/code | 发账号设置验证码 |
| 9 | POST | /api/v1/acc/sms/cancel | 发注销验证码 |
| 10 | GET | /api/v1/acc/valid/cancel | 检查是否可注销 |
| 11 | POST | /api/v1/acc/cancel/account | 注销账号 |
| 12 | POST | /api/v1/acc/basic/acc-attestation | 实名认证 |
| 13 | GET | /api/v1/ui/app/master | 首页Master数据 |
| 14 | GET | /api/v1/ui/app/dev/home/1 | 设备详情 |
| 15 | GET | /api/v1/ui/app/dev/status | 设备状态 |
| 16 | GET | /api/v1/dev/start | 设备启动 ★ |
| 17 | GET | /api/v1/dev/end | 设备停止 |
| 18 | POST | /api/v1/ui/app/dev/command | 设备指令 ★ |
| 19 | GET | /api/v1/dev/favo | 收藏/取消 |
| 20 | GET | /api/v1/dev/mode/start | 设置设备模式 |
| 21 | GET | /api/v1/ui/app/dev/dev-use-way | 选择使用模式 |
| 22 | GET | /api/v1/dev/near | 附近设备 |
| 23 | GET | /api/v1/dev/receive | 设备认领 |
| 24 | GET | /api/v1/dev/share/lst | 设备分享列表 |
| 25 | GET | /api/v1/dev/rela/view-stat | 淋浴设备 |
| 26 | GET | /api/v1/qr/use | 扫码解析 ★ |
| 27 | GET | /api/v1/acc/wallet/detail | 钱包详情 |
| 28 | GET | /api/v1/acc/wallet/owner | 钱包拥有者 |
| 29 | GET | /api/v1/acc/wallet/contact | 联系人 |
| 30 | POST | /api/v1/acc/wallet/refund | 退款 |
| 31 | GET | /api/v1/bill/pay/channels | 支付渠道 |
| 32 | GET | /api/v1/trans/prepay/{type} | 创建预付订单 |
| 33 | GET | /api/v1/trans/confirm | 确认支付 |
| 34 | GET | /api/v1/trans/close | 关闭订单 |
| 35 | GET | /api/v1/trans/errorMsg | 订单错误 |
| 36 | POST | /api/v1/sys/ticket | 获取支付Ticket |
| 37 | GET | /api/v1/bill/lst-owner | 账单列表 |
| 38 | GET | /api/v1/bill/view-full | 账单详情 |
| 39 | POST | /api/v1/bill/save | 创建账单 |
| 40 | GET | /api/v1/acc/score/mission-lst | 任务列表 ★ |
| 41 | POST | /api/v1/acc/score/score-send | ★ 积分发放 (MD5 sign) |
| 42 | GET | /api/v1/acc/score/score-lst | 积分明细 |
| 43 | GET | /api/v1/ui/app/sign-pga | ★ PGA签约sign (服务端) |
| 44 | GET | /api/v1/ui/app/acc-pgas | 签约渠道列表 |
| 45 | GET | /api/v1/ui/app/pga-check | 检查签约状态 |
| 46 | GET | /api/v1/pga/unsign-owner | 解约 |
| 47 | GET | /api/v1/ord/lst-owner | 工单列表 |
| 48 | GET | /api/v1/ord/view-full | 工单详情 |
| 49 | POST | /api/v1/ord/save | 提交工单 |
| 50 | POST | /api/v1/ord/cancel | 取消工单 |
| 51 | GET | /api/v1/ord/appraised | 评价工单 |
| 52 | GET | /api/v1/log/lst | 工单日志 |
| 53 | POST | /api/v1/ic/bind | 绑定IC卡 |
| 54 | POST | /api/v1/ic/unbind | 解绑IC卡 |
| 55 | GET | /api/v1/ic/lst-owner | IC卡列表 |
| 56 | GET | /api/v1/ic/owner-view | IC卡详情 |
| 57 | POST | /api/v1/ic/upt | 更新IC卡 |
| 58 | POST | /api/v1/ic/valid | 验证IC卡 |
| 59 | GET | /api/v1/ic/cipher/view-owner | IC卡加密查看 |
| 60 | GET | /api/v1/promo/lst-owner | 优惠券列表 |
| 61 | GET | /api/v1/promo/apply | 领取优惠券 |
| 62 | GET | /api/v1/ad/acc-lst | 广告列表 |
| 63 | GET | /api/v1/ad/view | 广告详情 |
| 64 | GET | /api/v1/ad/swtich | 广告开关 |
| 65 | POST | /api/v1/fs/up | 上传文件 |
| 66 | GET | /api/v1/sys/app/upt | 检查更新 |
| 67 | GET | /api/v1/ep/lst-simple | 商户列表 |
| 68 | GET | /api/v1/ep/station/lst | 商户附近 |
| 69 | GET | /api/v1/ep/station/view | 商户详情 |
| 70 | GET | /api/v1/prd/lst | 商品列表 |
| 71 | GET | /api/v1/acc/master | 驾考Master |

---

*文档生成时间: 2026-06-12*  
*统计: 71 个端点, 12 个数据模型, 2 套 Sign 体系 (积分MD5 + PGA服务端)*  
*Python 对接项目: `ilife798_login/` (90+ API 方法)*
