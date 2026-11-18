# dsh-browser-use-skill

[English](README.md) | 中文

> 给 DeepSeek Harness 用的 browser-use 技能包。

这个包 fork 自 browser-use 自带的 agent 技能，也就是 [browser-use/browser-use](https://github.com/browser-use/browser-use) 仓库里那份文档。改写成了 DSH 版本：一个常驻的 Python REPL、browser-harness 的辅助函数、直接走 CDP；另外补上了通用技能写不到的内容——PowerShell 的调用写法、每次调用要付多少开销、多个 agent 同时跑时怎么不互相抢标签页。browser-use 那个 Python 项目本身没有改动，归属声明和上游许可见 `NOTICE`。

```
  ● 加载技能              browser-use — 1.6k tokens，按需
  │
  ● 模型写一段代码        new_tab(url); wait_for_load(); js(...)
  │
  ● REPL 在 Chrome 里执行  直接走 CDP，守护进程常驻
  │
  ✓ 一次调用十步          回到上下文的只有 ~200 字符
```

这个 bundle 只提供技能：不注册面向模型的工具，也不调用云 API。

## 该用哪个

| 你想要 | 用这个 |
|---|---|
| 从自己的代码里驱动真实浏览器 | 本包 + browser-use CLI |
| 一个 API key 拿到托管浏览器和模型 | [Browser Use Cloud](https://docs.browser-use.com/cloud/agent/quickstart) |
| 包装云 API 的工具 | 另一个包；本包教 agent 用 CLI |

## 安装

```sh
dsh plugin add dsh-browser-use-skill
```

从本地 checkout 装：在 **Plugins → Add plugin** 里选目录，或用插件管理器安装包目录。bundle 用 `includeDefaultRoots: false` 挂载自带的 `skills/`，只贡献一个技能，不去扫描你其它的技能目录。

## 前置：CLI

```sh
uv tool install 'browser-use==1.0.6'   # 需要 Python 3.11+
browser-use --doctor                   # 安装 / 浏览器 / 守护进程 / key，各一行
```

版本精确锁 `==`，不要写 `>=`。上游发版频繁，接口会变。

## 相比上游加了什么

上游是单份 2.5k tokens 的文档，按 bash 和通用机器写。这里做了拆分。

| 方面 | 上游 | 这里 |
|---|---|---|
| 调用方式 | 只有 bash heredoc | 先给 PowerShell 的 `@'…'@ \| browser-use`，再给 bash |
| 常驻开销 | 全部章节每次都进上下文 | 触发时 1.6k tokens，细节按需读 |
| 调用成本 | 没写 | 实测的固定开销，以及什么时候该批量 |
| 浏览器选择 | 一段说明 | 专用 profile 和你自己的 Chrome 分别是什么情况，哪个会弹确认框 |
| 读页面 | 「尽量用无障碍树」 | 一张成本表：截图 / `js()` / 过滤后的 AX / 全量打印 |
| 并行 agent | 「用云浏览器」 | `BU_NAME` 守护进程、专属标签页、每 agent 一个浏览器、启动脚本 |
| 排障 | 通用 | Chrome 136+ 对默认 profile 的限制、新版 Chrome 少了那个勾选框、守护进程的假警报 |

主文件 `SKILL.md` 1.6k tokens，长尾内容放 `references/`。

## 一次调用要花多少

| 素材 | tokens |
|---|---:|
| 打印一个标题 | ~15 |
| 过滤后的无障碍树，5 行 | ~300–800 |
| `max_dim=768` 的截图 | ~800 |
| 原尺寸截图（1137×1153） | ~1,500 |
| 整棵无障碍树全打印 | 20k–200k |

规则很笨但管用：在 Python 里先切片，打印数量和几个样本，别 `print(nodes)`。

## 并行 agent

默认一个 agent 占一个浏览器会话。

```powershell
$env:BU_NAME = 'agent3'                     # 独立守护进程 + 独立后台标签页
$env:BU_CDP_URL = 'http://127.0.0.1:9223'   # 可选：独立浏览器实例
```

两个 agent 用同一个 `BU_NAME`，会互相覆盖标签页和导航。名字不同则共用一个 Chrome（Cookie 也共用），各自拿到独立标签页。要隔离登录态，就给每个 agent 单独一个浏览器。本地跑到四个左右，内存会先撑不住。

`skills/browser-use/scripts/ensure-browser.ps1` 按需拉起实例，已经在跑的不动它。

## 常见问题

<details>
<summary><b>需要 API key 吗？</b></summary>

本地浏览器不需要，技能通过 CDP 直接驱动 Chrome，不涉及账号。key 只用于 Browser Use Cloud 的浏览器和 `bu-*` 模型。
</details>

<details>
<summary><b>为什么不直接调 CLI？</b></summary>

可以直接调。技能补的是判断部分：怎么批量、用哪种方式读页面最省、别让几个 agent 共用一个守护进程、出问题先跑 `--doctor`。没有这些，模型照样能把上下文烧掉，也照样会撞在自己身上。
</details>

<details>
<summary><b>Windows 能用吗？</b></summary>

能。这个 fork 主要就是为了 Windows 写的：上游示例全是 bash heredoc，而 DSH 在 Windows 上跑的是 PowerShell，`<<'PY'` 在那里不存在。技能里先给能跑的那个写法。
</details>

<details>
<summary><b>它是沙箱吗？</b></summary>

不是。模型写的 Python 能读文件、能发网络请求，页面内容也可能试图指挥模型。不可信的任务放到容器里跑。技能里写了这一点，但它拦不住。
</details>

<details>
<summary><b>能驱动我正在用的 Chrome 吗？</b></summary>

能，带着你的登录态——在 `chrome://inspect/#remote-debugging` 打开远程调试即可。之后 Chrome 每次新连接都会问一次是否允许，这个同意无法持久保存。用专用 profile 就不弹窗，但那边是空的登录态。两种情况技能里都写了。
</details>

## 目录

```
cordis.patch.yml                 bundle 补丁，插入一行
index.js                         把 skills/ 挂到文件系统技能提供者上
locale/en.json                   插件管理器的标题和描述
icon.svg                         bundle 图标
skills/browser-use/SKILL.md      技能本体
skills/browser-use/references/   并行 agent · 排障 · 云浏览器 · 录屏
skills/browser-use/scripts/      ensure-browser.ps1
```

## 验证过的内容

- `node --check index.js`、JSON 清单合法、图标在大小限制内。
- 装进真实的 DSH profile：bundle 状态 `applied`，技能从本包加载。
- 发布前扫过一遍，技能文本里没有主机相关的标识。

## 已知限制

- 技能只给建议，管不住模型打印 5 万 token 的无障碍树。
- Chrome 不记住远程调试的授权，每次连接都要点一次。
- 上游变动快，技能按 browser-use 1.0.6 的行为写的。
- 这是非官方的包：两个项目的维护者都没有审阅或背书它。Browser Use Cloud、Browser Use、DeepSeek Harness 及其标识归各自所有者。

## 许可

MIT。包含改编自 browser-use / browser-harness（MIT）的文本，见 `NOTICE`。
