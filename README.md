# CSC258 Project: Magical Drop

<!-- course-navigation:start -->
[← 返回 CSC258 主页](../README.md) · [← 返回学期总览](../../semester-dashboard.md)
<!-- course-navigation:end -->

用 MIPS 汇编写的 Magical Drop,在 Saturn 或 MARS 里运行。

## 成员

| 姓名 | 学号 |
|---|---|
| Xiangyu Zhou | 1012571708 |
| Belina Zhu | 1011889262 |

## 文件

| 文件 | 说明 |
|---|---|
| `submission/MagicalDrop.asm` | 游戏程序 |
| `submission/project_report.tex` | 项目报告源文件 |
| `submission/project_report.pdf` | 由 tex 编译出的报告 |
| `submission/figures/` | 报告用到的四张图(`layout.png`、`screens.png`、`static_scene.png`、`memory_screenshot.png`)。和 tex 放在一起时,编译出的报告带图;没有这个文件夹时 tex 也能编译,图的位置会换成提示框,提交的 PDF 里图是全的 |

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
- 球被推到角色那一行,游戏结束,画面停在最后一帧。如果压到底的球正好在角色那一格,显示的是这颗球,而不是角色。

## 完成的 Milestone 和功能

- Milestone 1–5 全部完成。一共 2 个 easy + 4 个 hard,满足 Milestone 5 的组合 (d)(2 easy + 3 hard)和组合 (e)(4 hard)。

| 类型 | 编号 | 功能 |
|---|---|---|
| easy | 1 | 定时推行 |
| easy | 2 | 推行逐渐加速 |
| hard | 2 | flood fill:相连的同色球一起消掉 |
| hard | 3 | gravity:悬空的球往上浮 |
| hard | 5 | 连锁:上浮后又凑成三连,会接着再消,直到没有为止 |
| hard | 6 | 角色所在列的闪烁瞄准虚线 |

## 分工

每个 Milestone 由一个人负责;Milestone 4 和 5 的功能每人 1 个 easy、2 个 hard;Belina Zhu 负责把两个人的代码合并起来。

### 代码结构

`MagicalDrop.asm` 从上到下分成 6 个 Part,每个人的代码都集中在一起:

| Part | 负责人 | 内容 |
|---|---|---|
| Part 0 | Belina Zhu(整合) | 共用数据(`.data`):棋盘、角色位置、手里的球、计数器、颜色 |
| Part 1 | Xiangyu Zhou | Milestone 1:开局初始化、画墙、棋盘、球和角色 |
| Part 2 | Xiangyu Zhou | Milestone 2:主循环、读键盘、移动、吸球、每 10 次按键推一行、结束和退出 |
| Part 3 | Xiangyu Zhou | easy 2 推行加速、hard 3 向上补位、hard 6 闪烁瞄准线 |
| Part 4 | Belina Zhu | Milestone 3:越界判断、扔球、找三连和删除 |
| Part 5 | Belina Zhu | easy 1 定时推行、hard 2 flood fill、hard 5 连锁 |

前面的 Part 可以调用后面 Part 里的函数,比如 Part 2 的 `game_loop` 读到 `w` 就 `jal handle_throw`(Part 4)。调用处的注释写明了函数在哪个 Part。

### 总览

| 部分 | 负责人 | 在哪个 Part |
|---|---|---|
| Milestone 1:开局和画场景 | Xiangyu Zhou | Part 1 |
| Milestone 2:主循环和操作 | Xiangyu Zhou | Part 2 |
| easy 2:推行逐渐加速 | Xiangyu Zhou | Part 3 |
| hard 3:gravity | Xiangyu Zhou | Part 3 |
| hard 6:闪烁瞄准虚线 | Xiangyu Zhou | Part 3 |
| Milestone 3:扔球和消除 | Belina Zhu | Part 4 |
| easy 1:定时推行 | Belina Zhu | Part 5 |
| hard 2:flood fill | Belina Zhu | Part 5 |
| hard 5:连锁 | Belina Zhu | Part 5 |
| 整合代码 | Belina Zhu | Part 0 和 preamble |

### Xiangyu Zhou

| 部分 | 内容 | 相关代码 |
|---|---|---|
| Milestone 1(Part 1) | 开局 5 行随机球;画出整个场景:墙、红线、格子、球、角色、颜色表 | `main`、`random_colour`、`push_row`、`draw_walls`、`clear_screen`、`draw_hline`、`draw_vline`、`draw_board`、`draw_grid`、`draw_bubble`、`draw_player`、`palette`、`player_sprite` |
| Milestone 2(Part 2) | 主循环、读键盘、左右移动、吸球、每 10 次按键推一行、每帧重画、`q` 退出、球到底就结束 | `game_loop`、`move_left`、`move_right`、`handle_grab`、`find_lowest`、`advance_row`、`game_over`、`quit_game`、`sleep_ms` |
| easy 2(Part 3) | 推行逐渐加速 | `speed_up` |
| hard 3(Part 3) | gravity:悬空的球往上浮 | `float_step` |
| hard 6(Part 3) | 闪烁瞄准虚线 | `draw_aim`、`frame_count` |
| 报告 | Bitmap 设置、屏幕布局、Milestone 1、Milestone 2、easy 2、hard 3、hard 6、How to Play | |
| Demo | 开局画面、移动、吸球、按键推行、推行越来越快、上浮补位、瞄准线、游戏结束、退出 | |

### Belina Zhu

| 部分 | 内容 | 相关代码 |
|---|---|---|
| Milestone 3(Part 4) | 左右边界、扔球、找竖着的三连并删除 | `in_field`、`handle_throw`、`find_matches`、`remove_marked` |
| easy 1(Part 5) | 定时推行 | `row_timer_tick`、`row_timer_reset`、`row_timer` |
| hard 2(Part 5) | flood fill | `flood_fill`、`ff_try`、`ff_stack` |
| hard 5(Part 5) | 连锁:把找三连、flood fill、删除、上浮按顺序串起来,重复到没有三连为止 | `resolve_matches` |
| 整合 | 把两个人的代码按 Part 0–5 的顺序合并成一个文件;负责 `.data` 内存布局和 preamble;合并后在 Saturn 里测试 | `.data`(Part 0)、preamble |
| 报告 | 内存表和截图、Milestone 3、easy 1、hard 2、hard 5(含消除分步图) | |
| Demo | 左右边界、扔球、三连消除、flood fill、连锁(配合分步图讲)、定时推行 | |

### 衔接约定

- 写代码前先约定好共用的格式:
  - `grid`:98 个 word,0 表示空,1–4 表示红、黄、绿、蓝;第 r 行第 c 列存在 `grid + 4 * (7r + c)`。
  - 角色和手里的球:`player_col`、`held_colour`、`held_count`。
- 跨 Part 调用的函数接口:
  - `find_lowest`(Xiangyu Zhou 写,Part 2;`handle_throw` 和 `draw_aim` 也会用):`$a0` 传列号,`$v0` 返回这一列最下面那个球的行号,空列返回 -1。
  - `float_step`(Xiangyu Zhou 写,Part 3;`resolve_matches` 会用):没有参数;让悬空的球往上浮一格,`$v0` = 1 表示还有球在动。
  - `speed_up`(Xiangyu Zhou 写,Part 3;`game_loop` 每来一行新的之后调用):没有参数,把 `row_interval` 减 50,最少 150。
  - `in_field`(Belina Zhu 写,Part 4;`move_left`、`move_right` 会用):`$a0` 传想去的列号,`$v0` = 1 表示这一列在场地内(0–6),`$a0` 不变。
  - `row_timer_tick`(Belina Zhu 写,Part 5;`game_loop` 每帧调用):没有参数;计时加 1,`$v0` = 1 表示时间到了,该来新的一行。
  - `row_timer_reset`(Belina Zhu 写,Part 5):没有参数;来了新的一行后把计时清零。
  - `resolve_matches`(Belina Zhu 写,Part 5):没有参数;开局时、每次扔完球、每来一行新的之后调用,做完后盘面上不会留下竖着的三连。
- 计时、加速和边界判断的代码都写在各自的 Part 里,不夹在 Part 2 中间:`game_loop` 只用 `jal` 调用 `row_timer_tick`、`row_timer_reset`、`speed_up`,`move_left` / `move_right` 只用 `jal` 调用 `in_field`。
- 合并后一起在 Saturn 里测试,并准备 demo。
- 两个人都要各自在 Quercus 提交 `MagicalDrop.asm`、`project_report.tex`、`project_report.pdf`,`figures/` 里的图按 Quercus 的要求一并提交。
