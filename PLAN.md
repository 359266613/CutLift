# 轻抠 CutLift · 技术方案

> 状态文件。方案变更请同步修改本文件，实施进度见 [PROGRESS.md](PROGRESS.md)。

## 1. 目标与约束

| 项目 | 值 |
|---|---|
| 目标设备 | iPhone 14 Pro（A16，有 Neural Engine） |
| 目标系统 | iOS 16.5，Dopamine 无根越狱（rootless） |
| 编译 SDK | 16.5（`AxsCutLiftBuild.mk` 统一） |
| 最低部署版本 | iOS 15.0 |
| 注入进程 | 照片 / 信息 / Safari / 微信 / 抖音 |
| 产物 | deb（`AxsCutLift` dylib + `AxsCutLiftPrefs` 面板） |

**核心约束：iOS 17 的两条关键 API 在 16.5 上不存在。**

| API | 最低版本 | 16.5 可用 | 用途 |
|---|---|---|---|
| `VNGenerateForegroundInstanceMaskRequest` | iOS 17 | 否 | 任意物体实例分割 |
| `VNGeneratePersonInstanceMaskRequest` | iOS 17 | 否 | 多人分别出蒙版 |
| `VNGeneratePersonSegmentationRequest` | iOS 15 | **是** | 人像分割（主路径） |
| `VNGenerateObjectnessBasedSaliencyImageRequest` | iOS 13 | **是** | 显著物体（兜底） |
| `ImageAnalysisInteraction` | iOS 16 | 部分 | `.imageSubject` 是 iOS 17 新增，`ImageAnalyzer` 编程取主体在 16.x 有文档冲突 |

因此**不引入第三方 CoreML 模型**：人像分割 + 显著性兜底已覆盖绝大多数场景，且包体零增长。
若后续确需"任意物体高精度"，再单独评估 MODNet（约 7MB，Apache-2.0）；RMBG-2.0 因 CC BY-NC 4.0 禁止商用，不采用。

## 2. 抠图流水线

```
UIImage
  ↓ 方向归一化（重绘为 .up，避免 90° 旋转）
CIImage
  ↓ VNGeneratePersonSegmentationRequest（.accurate / .balanced）
  ├─ 无人像 → VNGenerateObjectnessBasedSaliencyImageRequest（对比度+gamma 压成硬边）
  ↓ 蒙版缩放到原图尺寸
  ↓ CIGaussianBlur 羽化（半径来自面板，裁回原 extent）
  ↓ 可选：扫描蒙版求主体外框 → 裁到主体
  ↓ CIBlendWithMask（背景用 CIImage.emptyImage）
带 alpha 的 UIImage
```

关键实现细节：

- 蒙版位图原点在左上、CI 在左下，求外框后必须翻转 y 才能裁剪正确。
- 外框扫描先把蒙版降到 ≤256px 再逐字节扫描，避免 12MP 图全量遍历。
- 渲染统一走单例 `CIContext`，不做每帧新建。
- 全流程在 `QOS_CLASS_USER_INITIATED` 队列，回调切回主线程。

## 3. 交互设计

**双指长按图片（0.45s）** → HUD「抠图中…」→ 结果页。

刻意规避的两个坑：

1. **不改 `userInteractionEnabled`。** `UIImageView` 默认不可交互，为挂手势而打开它会抢走父视图（cell、按钮）的点击。因此识别器**挂在 UIWindow 上**，命中窗口后自行 `hitTest` 反查被按压的 `UIImageView`。
2. **优先双指。** 单指长按在各 App 里普遍被"保存/转发/识别二维码"菜单占用，双指几乎无冲突。面板可切回单指。

识别器设置 `cancelsTouchesInView = NO`、`delaysTouchesBegan = NO`，不干扰 App 原有手势。
小于 160px 的图（图标、表情、缩略图）直接忽略。

结果页：棋盘格透明底 + 拷贝 / 分享 / 关闭。不做"直接存相册"——那需要宿主 App 具备 `NSPhotoLibraryAddUsageDescription`，缺失会导致宿主崩溃；改由系统分享面板承接存图。

## 4. 文件职责

| 文件 | 职责 |
|---|---|
| `Hooks/AxsCutLiftMain.xm` | `%hook UIImageView didMoveToWindow`，仅负责在开关打开时补挂识别器 |
| `Sources/AxsCutLiftSegmenter.h/.m` | 分割流水线（Vision + CoreImage），无 UI 依赖 |
| `Sources/AxsCutLiftGesture.h/.m` | 识别器安装、hitTest 反查、结果/失败弹窗 |
| `Sources/AxsCutLiftPresenter.h/.m` | 取活动窗口与顶层控制器（下钻 Tab/Nav/Split）、HUD |
| `Sources/AxsCutLiftPreviewController.h/.m` | 结果预览与拷贝/分享 |
| `Sources/AxsCutLiftConfig.h/.m` | 配置快照（生成器提供，只读） |
| `Sources/AxsCutLiftPreferences.h` | 配置读写与通知（生成器提供，**仅面板可写**） |
| `AxsCutLiftPrefs/` | PreferenceBundle，配置文件的唯一写入方 |

## 5. 配置键

| 键 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `enabled` | bool | false | 总开关 |
| `twoFinger` | bool | true | 双指长按；关闭为单指 |
| `accurate` | bool | true | 人像分割高精度档 |
| `feather` | real | 2.0 | 羽化半径 0–6 |
| `trim` | bool | true | 裁到主体外框 |

Tweak 只读快照，永不写默认值；面板是唯一写入方，写入后发 `com.axs.cutlift.preferences-changed`。

## 6. 参考仓库（第一档）与借鉴点

| 仓库 | 借鉴了什么 |
|---|---|
| [riskycheng/VisionKitTool](https://github.com/riskycheng/VisionKitTool) | 人像分割 `.accurate` 档参数、显著性检测做物体分支的组合方式 |
| [build-your-own-x-with-ai/RemoveBG](https://github.com/build-your-own-x-with-ai/RemoveBG) | 方向归一化写法、`CIBlendWithMask` 合成、棋盘格透明底的表现形式 |
| [Ezaldeen99/BackgroundRemoval](https://github.com/Ezaldeen99/BackgroundRemoval) | 对外 API 形态（一行调用 + 可选只出蒙版） |
| [MuMuY66/MMYPhotoKit](https://github.com/MuMuY66/MMYPhotoKit) | Objective-C 侧封装思路、纯色底替换的扩展方向 |

## 7. 已知边界

- 只识别**人像**为强项；非人主体走显著性，边缘偏软，复杂背景可能失败。
- 依赖 `UIImageView`。用 `CALayer contents` 或自绘的看图页（部分第三方 App）不会命中。
- `twoFinger` 改动需重开 App 或 respring 才重装识别器。
- 结果页的"分享面板 → 存储图像"若宿主缺相册写入权限描述，仍可能被系统拒绝（不做越权规避）。

## 8. 验收计划

1. **静态**：`python scripts/doctor.py <项目路径>` — 已通过。
2. **编译**：`sh build.sh rootless`（需 macOS/Linux + Theos）。
3. **真机**（iOS 16.5 / 14 Pro）：
   - [ ] 面板可打开、开关可保存、无崩溃
   - [ ] 照片 App 双指长按人像 → 出透明底结果
   - [ ] 信息 / Safari / 微信 / 抖音 各验一次
   - [ ] 非人主体（宠物、静物）→ 走显著性分支或给出失败提示
   - [ ] `feather` / `trim` / `accurate` 三项改动能即时生效
   - [ ] 关闭总开关后长按无反应
   - [ ] 拷贝后粘贴到其他 App 保持透明
