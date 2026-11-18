# CSC258 Project: Magical Drop

用 MIPS 汇编写的 Magical Drop,在 Saturn 或 MARS 里运行。

## 成员

| 姓名 | 学号 |
|---|---|
| Xiangyu Zhou | 1012571708 |
| Belina | TODO |

## 文件

| 文件 | 说明 |
|---|---|
| `submission/MagicalDrop.asm` | 游戏程序 |
| `submission/project_report.tex` | 项目报告源文件 |
| `submission/project_report.pdf` | 由 tex 编译出的报告 |
| `submission/figures/` | 报告用到的三张图(`layout.png`、`screens.png`、`static_scene.png`),编译 tex 时需要 |

## 运行

Bitmap Display 设置:

| 项目 | 值 |
|---|---|
| Unit width / height | 8 / 8 |
| Display width | 256 |
| Display height | 512 |
| Base address | `0x10008000 ($gp)` |

**Saturn**:`File → Open File` 打开 `MagicalDrop.asm`,按 `Cmd + T` 打开下方面板,在 Bitmap tab 里按上表设置,点右上角绿色按钮运行,再点一下 Bitmap 画面,按键才会送进程序。

**MARS**:打开 `MagicalDrop.asm`,在 `Tools → Bitmap Display` 里按上表设置并点 `Connect to MIPS`;再打开 `Tools → Keyboard and Display MMIO Simulator`,点 `Connect to MIPS`。两个窗口都不要关,然后 `Run → Assemble`、`Run → Go`,在 MMIO 工具的键盘区输入按键。

## 操作

| 按键 | 作用 |
|---|---|
| `a` / `d` | 左移 / 右移 |
| `s` | 吸起头顶这一列最下面的球,以及紧挨在它上面的同色球 |
| `w` | 把手里的球扔回头顶这一列(落在闪烁虚线的末端) |
| `q` | 退出 |

## 玩法

- 场地是 7 列 × 14 行,球从顶上往下排,角色在最底下一行。
- 竖着凑成三个或以上同色就会消掉;和它们上下左右相连的同色球也一起消掉。消掉后,下面的球往上浮补位;如果因此又凑成三连,会继续消。
- 每按 10 次键(`a`、`d`、`s`、`w`),或者计时到了,顶上就会来一行新的球,把所有球往下推。计时一开始是 500 帧,每来一行少 50 帧,最少 150 帧。
- 球被推到角色那一行,游戏结束。

## 完成的 Milestone 和功能

- Milestone 1–5 全部完成。Milestone 5 用组合 (d):2 个 easy + 3 个 hard。

| 类型 | 编号 | 功能 |
|---|---|---|
| easy | 1 | 定时推行 |
| easy | 2 | 推行逐渐加速 |
| hard | 2 | flood fill:相连的同色球一起消掉 |
| hard | 3 | gravity:悬空的球往上浮 |
| hard | 6 | 角色所在列的闪烁瞄准虚线 |

## 分工

### Xiangyu Zhou

| 部分 | 内容 | 相关代码 |
|---|---|---|
| Milestone 1 | 画出整个场景:墙、红线、格子、球、角色、颜色表 | `draw_walls`、`draw_board`、`draw_grid`、`draw_bubble`、`draw_player`、`draw_hline`、`draw_vline`、`clear_screen`、`palette`、`player_sprite` |
| Milestone 2 | 主循环、读键盘、左右移动、开局 5 行、每 10 次按键推一行、球到底就结束 | `main`、`game_loop`、`move_left`、`move_right`、`push_row`、`random_colour`、`advance_row`、`game_over` |
| Milestone 3 | 左右边界 | `move_left`、`move_right` |
| easy 1 | 定时推行 | `game_loop` 里的 `row_timer` |
| easy 2 | 推行逐渐加速 | `game_loop` 里的 `row_interval` |
| hard 6 | 闪烁瞄准虚线 | `draw_aim`、`frame_count` |
| 报告 | Bitmap 设置、屏幕布局、内存表和截图、Milestone 1 和 2、easy 1、easy 2、hard 6、How to Play | |
| Demo | 开局画面、移动和边界、定时推行、加速、瞄准线、游戏结束 | |

### Belina

| 部分 | 内容 | 相关代码 |
|---|---|---|
| Milestone 2 | 吸球 | `handle_grab`、`find_lowest` |
| Milestone 3 | 扔球、找竖着的三连并删除 | `handle_throw`、`find_matches`、`resolve_matches` |
| hard 2 | flood fill | `flood_fill`、`ff_try`、`remove_marked`、`ff_stack` |
| hard 3 | gravity | `float_step` |
| 报告 | Milestone 3 的消除流程和分步图 | |
| Demo | 吸球、扔球、三连消除、flood fill、上浮补位 | |

### 一起完成

- 开头的 preamble 和 `.data` 内存布局。
- 写代码前先约定好共用的格式:
  - `grid`:98 个 word,0 表示空,1–4 表示红、黄、绿、蓝;第 r 行第 c 列存在 `grid + 4 * (7r + c)`。
  - 角色和手里的球:`player_col`、`held_colour`、`held_count`。
  - `find_lowest`:`$a0` 传列号,`$v0` 返回这一列最下面那个球的行号,空列返回 -1。
- 合并后一起在 Saturn 里测试,并准备 demo。
- 两个人都要各自在 Quercus 提交 `MagicalDrop.asm`、`project_report.tex`、`project_report.pdf`,`figures/` 里的图按 Quercus 的要求一并提交。
