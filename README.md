# perfect_game

一个基于 **Godot 4.7** 的游戏项目。

## 项目配置

| 项目 | 配置 |
| --- | --- |
| 引擎版本 | Godot 4.7（Mobile 版） |
| 渲染方式 | `mobile`（Windows 下使用 D3D12） |
| 物理引擎 | Jolt Physics（3D） |
| 窗口拉伸 | `canvas_items` / `expand` |
| .NET 程序集 | `perfect_game` |

## 目录结构

```
.
├── project.godot       # Godot 项目配置
├── icon.svg            # 项目图标
├── icon.svg.import     # 图标导入配置
├── .editorconfig       # 编辑器编码规范
├── .gitattributes      # 换行符规范化（LF）
└── .gitignore          # 忽略 Godot 缓存目录 .godot/
```

## 本地运行

1. 安装 [Godot 4.7](https://godotengine.org/download)（如需 C# 支持请安装 .NET 版）。
2. 在项目管理器中点击「导入」，选择本目录下的 `project.godot`。
3. 按 `F5` 运行，或按 `F6` 运行当前场景。

> `.godot/` 为引擎自动生成的缓存目录，已被 `.gitignore` 忽略，无需提交。
