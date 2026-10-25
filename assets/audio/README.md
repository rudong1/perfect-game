# 轻音量事件音效

六段 WAV 均由 `tools/build_sfx.py` 原创合成，无外部采样或下载依赖。

| 文件 | 触发 | 声音 |
| --- | --- | --- |
| `sfx/mirror_flip.wav` | 玩家成功按 M 翻转 | 短气流与柔和玻璃泛音 |
| `sfx/mirror_shatter.wav` | 终幕撞碎巨镜 | 轻裂响与不规则的碎玻璃散落 |
| `sfx/mirror_pass.wav` | 成功穿镜 | 低气流与逐层升起的泛音 |
| `sfx/crystal_red.wav` | 第一次获得红色 | G 小调轻响 |
| `sfx/crystal_blue.wav` | 第一次获得蓝色 | A 小调轻响 |
| `sfx/crystal_green.wav` | 第一次获得绿色 | B 小调轻响 |

44.1 kHz、16-bit、立体声，单段 0.56–1.65 秒。源文件峰值限制为 -6 dBFS；独立 SFX 总线再降 8 dB，每个事件再降 5–7 dB，单段播放峰值约 -19 至 -21 dBFS。短淡入、淡出及高频衰减避免爆音和尖锐声；不含连续背景循环。

`SoundEffects` 只观察既有信号，不改变碰撞、重力、镜像、机关或剧情。最多四个音源，同时触发去重。收集音可在暂停的 CG 中自然结束；返回标题或切换场景会停止旧声音。载入已收集颜色、重置镜像以及读取已经碎镜的结局存档不会重新响起事件音。

音量可在 Godot 的音频面板调整 `SFX` 推子，布局保存于 `default_bus_layout.tres`。Master 保持 0 dB。

重新生成：`python3 tools/build_sfx.py`（仅生成脚本依赖 NumPy；游戏运行无需 Python）。

## 背景音乐

三首现成音乐均由 Kevin MacLeod 作曲，依据 CC BY 4.0 使用。署名、原始曲目页、公开发行来源、修改说明与文件校验值保留在 [music/CREDITS.txt](music/CREDITS.txt) 和 [music/sources.json](music/sources.json)，标题与结尾画面也可点击「音乐鸣谢」。

| 配乐 | 场景 |
| --- | --- |
| Ghost Story | 标题、序章、四个解谜区域；清冷的钢琴与泛音 |
| The Descent | 追逐；低音量的管弦节奏 |
| Teller of the Tales | 赠色、复活、拥抱与结局；舒缓的鲁特琴与吉他 |

音乐保留完整乐段，仅裁掉静音边缘、归一化响度并重编码。素材目标 -21 LUFS、-6 dBTP，独立 `Music` 总线再降 13 dB。两音源交叉淡化切曲，曲尾与曲首重叠三秒循环；换关和进入结尾不会重头播放同一首。收集 CG、对白和音效响起时进一步降低音乐；碎镜瞬间先让音乐淡出，再进入安静的告解。

重建音乐：`python3 tools/prepare_music.py`，需要 ffmpeg 和网络。也可用 `--source-dir` 指定原始 Ogg 目录。脚本从固定版本下载，先校验原文件 SHA-256，再生成配乐和来源记录；游戏运行不访问网络。
