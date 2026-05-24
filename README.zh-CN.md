# RawComp

<p align="center">
  <img width="300" height="300" alt="RawComp 应用图标" src="https://github.com/user-attachments/assets/f243fc9f-c521-4b75-a801-7424d81ad1ad" />
</p>

<p align="center">
  <strong>适用于 macOS 的多图并排对比工具。</strong>
</p>

<p align="center">
  RawComp 面向摄影师、修图师和评审场景，用来并排检查 RAW 文件、压缩导出图、后期版本、裁切差异、锐度、色彩以及局部细节之间的细微区别。
</p>

<p align="center">
  <a href="README.md">English Doc</a>
</p>

<p align="center">
  <img width="862" height="567" alt="Screenshot 2026-05-23 at 11 25 34 AM" src="https://github.com/user-attachments/assets/f92833ea-7fe3-42f5-9f39-2aa92a5f3f3f" />
</p>

## 功能特性

- 支持在一个窗口中同时对比 `2`、`3`、`4` 或 `6` 张图片。
- 支持打开常见图片格式以及多种常见相机 RAW 格式。
- 支持缩放、平移、旋转、适应窗口以及一键跳转到 `100%`。
- 支持联动或取消联动各个视图窗格，让所有图片同步移动或独立操作。
- 支持标记同步高亮区域，用于强调各图中对应的细节位置。
- 支持对所有已加载窗格统一应用曝光、亮度、对比度、饱和度和锐化等对比调整。
- 支持查看当前活动窗格的文件元数据。

## 当前状态

RawComp 目前处于早期但可用的 MVP 阶段。

当前已经比较稳定的能力：

- 多窗格并排查看
- 视口联动检查
- 同步高亮区域
- 统一图像调整，方便放大细微差异
- 元数据查看

仍在推进中的方向：

- 基于 LibRaw 的更完整 RAW 解码
- 文件夹浏览 / 胶片条工作流
- 会话保存与重新打开
- 导出
- 差异、擦除对比、闪烁对比等更高级的比较工具

## 支持格式

RawComp 旨在同时支持压缩图像和广泛的相机 RAW 格式。

当前识别的目标扩展名包括：

- RAW 与相机格式：
  `dng`, `arw`, `srf`, `sr2`, `cr2`, `cr3`, `crw`, `nef`, `nrw`, `raf`, `rw2`, `rw1`, `orf`, `ori`, `pef`, `ptx`, `kdc`, `dcr`, `k25`, `erf`, `mef`, `mos`, `iiq`, `3fr`, `fff`, `x3f`, `srw`, `bay`, `cap`, `tif`, `tiff`
- 标准格式：
  `jpg`, `jpeg`, `png`, `webp`, `heic`, `heif`, `gif`, `tif`, `tiff`

重要说明：

当前版本依赖 macOS 自带图像解码器以及 Quick Look 预览作为回退路径。这意味着某些 RAW 文件是否可用，取决于本机系统是否能直接解码或生成预览。在当前版本中，部分 RAW 文件打开后可能显示的是预览图，而不是完整解码后的传感器数据。

## macOS 要求

- macOS 14 或更高版本
- 如果你要从源码运行，需要支持 Swift 6 的 Xcode

## 下载

可从 [Releases](https://github.com/franklioxygen/raw-comp/releases) 页面下载最新构建版本。

## 运行 RawComp

在仓库目录下执行：

```bash
swift run RawComp
```

也可以直接用 Xcode 打开 `Package.swift` 并运行应用。

## 基本工作流

1. 启动 RawComp。
2. 点击 `Open` 加载图片，或将文件拖放到某个窗格。
3. 选择布局：`2 Up`、`3 Up`、`4 Up` 或 `6 Up`。
4. 在 `Free` 和 `Synced` 联动模式之间切换，决定各窗格是否同步移动。
5. 使用工具栏中的缩放、适应窗口、`100%` 和旋转控制。
6. 使用 `Mark Region` 将当前可见区域记录为同步高亮区域。
7. 使用检查器中的滑杆统一调整所有已加载图片，让不易察觉的差异更明显。

## 为什么统一调整很重要

有些图像差异在中性视图下并不明显，尤其是在阴影、低对比纹理、边缘、压缩伪影或细微噪点这些区域。

统一调整控件可以让你用相同方式同时推动每一张图，因此既保持比较公平，又更容易把这些差异看出来。

## 规划方向

RawComp 的目标是成为一个专注的比较工具，而不是完整的照片库或 RAW 编辑器。

计划中的改进包括：

- 更强的 RAW 解码覆盖
- 更完善的高亮工具
- 文件夹与胶片条浏览
- 会话保存
- 比较结果导出
- 更多偏技术向的检查工具

## 产品规格文档

更完整的规划文档在这里：

[rawcomp-product-spec.md](documents/rawcomp-product-spec.md)
