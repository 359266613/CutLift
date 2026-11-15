# 轻抠 CutLift · 实施进度

方案见 [PLAN.md](PLAN.md)。

## 2026-11-15

### 已完成

- [x] 调研 iOS 抠图可行路线，确认 iOS 16.5 无法使用 iOS 17 的前景实例蒙版
- [x] 定名：英文 `CutLift` / 标识 `cutlift` / 显示名「轻抠」/ 包名 `com.axs.cutlift`
- [x] 图标：紫→品红渐变 + 剪影内嵌透明棋盘格 + 虚线切割线，已出 1024/512/180/120/87/80/60/58/40/29 套图
- [x] 用生成器落工程骨架（带面板 + 滑条 + GitHub Actions）
- [x] 注入过滤器改为 5 个 Bundle：照片 / 信息 / Safari / 微信 / 抖音
- [x] 链接框架补充 `Vision` / `CoreImage` / `CoreVideo`
- [x] 面板重写为真实配置项（总开关、双指、高精度、羽化滑条、裁剪到主体）
- [x] 抠图流水线 `AxsCutLiftSegmenter`：人像分割 → 显著性兜底 → 羽化 → 裁主体 → 合成 alpha
- [x] 手势层 `AxsCutLiftGesture`：窗口级识别器 + hitTest 反查 UIImageView，不改宿主视图交互性
- [x] 结果页 `AxsCutLiftPreviewController`：棋盘格 + 拷贝 / 分享 / 关闭
- [x] HUD 与顶层控制器查找 `AxsCutLiftPresenter`
- [x] Hook 改为 `UIImageView didMoveToWindow`（移除 SpringBoard 示例）
- [x] 面板图标替换为轻抠图标（`icon@2x` / `icon@3x`）
- [x] `doctor.py` 静态检查通过（仅剩自定义过滤器的预期 WARN）

### 未验证

- [ ] **Theos 编译**：当前机器为 Windows，无 `THEOS`、无 `make/clang`，WSL 被安全策略拦截。需在 macOS/Linux 或手机端 Thoes 执行 `sh build.sh rootless`。
- [ ] **真机行为**：全部运行期结论（分割效果、手势命中、面板读写、跨 App 注入）尚未验证，仅完成静态层。

### 已知待办 / 下一步

1. 在可用 Theos 环境编译，按 PLAN 第 8 节真机清单逐项验收。
2. 编译若报 `VNGeneratePersonSegmentationRequestQualityLevelAccurate` 未声明，改为 `request.qualityLevel = (VNGeneratePersonSegmentationRequestQualityLevel)1;`（该枚举在 SDK 16.5 中应已存在，先用符号写法）。
3. 微信 / 抖音的看图页若不使用 `UIImageView`，需要补 hook 各自的图片查看控制器；先真机确认再动。
4. 可选增强：结果页加"换取纯色底/渐变底"（参考 `MMYPhotoKit`），或提供"仅导出蒙版"。
5. 可选增强：非人主体精度不足时，再评估接入 MODNet（约 7MB，Apache-2.0，需 `minimum_deployment_target=ct.target.iOS16`）。

### 记录

- 生成器输出目录必须不存在，本次先落暂存区再拷入本目录。
- 静止图标与代码均已就位，后续重跑 `doctor.py` 可作为改动后的回归检查。
