# vps_initialization

在目标账户上安装基础软件，并把交互 shell 配成 Bash 5。

官方软件包路径仍是 Ubuntu、Debian 和 CentOS。仓库合并到默认分支之后，可以用下面的命令。

```bash
bash <(curl -L -s https://github.com/Fan-chou/vps_initialization/raw/main/vps_initialization.sh) -i
```

检出本仓库时，直接运行 `bash vps_initialization.sh -i`。脚本会使用旁边的 `share/bash/`。

## 默认安装

不带软件名的 `-i` 做两件事。

1. 安装原来的基础软件包。这一步不再安装 zsh。
2. 给目标账户安装 Bash 5 交互配置。Bash 低于 5 时，这一步停止，并且不改 rc，也不改登录 shell。基础软件安装已经执行过。

交互配置固定使用这些版本：

- ble.sh 提交 `152942758f567e51fd17bdc7b3783d27b3c476aa`，版本号 `0.4.0-devel4+1529427`
- bash-completion `2.18.0`
- rupa/z 提交 `d37a763a6a30e1b32766fecc3b8ffd6127f8a0fd`，读取已有的 `~/.z`

另外包含红色路径提示符、`extract`、彩色 man、Bash 版 git 别名，以及按原始前缀去重的 Up 和 Down。Up 会跳过已经显示成灰色建议的那一条。Down 按上去的顺序返回。到最早的一条就停止。

目标账户按这个顺序决定。先用 `VPS_INIT_USER`。否则，root 且存在非 root 的 `SUDO_USER` 时用 `SUDO_USER`。否则用当前用户。家目录来自该账户的 passwd 记录。文件写到这个家目录。

已有的 `~/.bashrc`、`~/.bash_profile`、`~/.bash_login` 或 `~/.profile` 只插入一段带标记的引用。Bash 选择它本来就会读的那一个登录文件。已有 `~/.profile` 时不会新建 `~/.bash_profile`。标记外的内容保留。`~/.config/bash/local.sh` 如果存在，会在 ble 附着前被 source，安装程序不创建也不覆盖它。`~/.config/bash/` 里的其他文件由安装程序维护，下次运行会换成仓库里的版本。

重复运行不会追加第二段引用。写入先落到同一目录的临时文件，再改名。用户 rc 的内容要变化时，旧文件复制到 `~/.config/bash/backups/<时间>/`。

第一次安装把当时的登录 shell 记到 `~/.config/bash/previous-login-shell`。以后的运行不覆盖这个文件。登录 shell 的文件名还不是 `bash`，并且 `/etc/shells` 里有 bash 时，安装程序执行 `chsh`。当前进程不会被换成新 shell。

## 可选命令

这些命令只在点名时运行。`collectd` 和 `sysctl` 的行为没有改。

```bash
bash vps_initialization.sh -i ohmyzsh
bash vps_initialization.sh -i collectd
bash vps_initialization.sh -i sysctl
```

`ohmyzsh` 仍安装 Zsh、Oh My Zsh、Pure 和原来的插件，并尝试把目标账户的登录 shell 改成 zsh。它使用和 Bash 安装相同的账户解析。

## 回退

只把登录 shell 改回第一次 Bash 安装时记下的路径。不删除 Bash、Zsh 或历史文件。

```bash
bash vps_initialization.sh -i bash-rollback
```

在目标账户自己的家目录里，也可以手动执行：

```bash
chsh -s "$(cat ~/.config/bash/previous-login-shell)"
```

## Zsh 历史

默认安装不读取、不转换、不覆盖 `~/.zsh_history`，也不覆盖已有的 `~/.bash_history`。

Bash 历史文件是 `~/.bash_history`。`HISTSIZE` 和 `HISTFILESIZE` 小于 50000 时会抬到 50000。`histappend` 会打开。

要转换时，显式运行离线脚本。它只接受 zsh 扩展历史，格式是 `: 时间:耗时;命令`。命令里的换行按反斜杠加换行还原，输出是 Bash 的 `#时间` 格式。耗时被丢掉。目标文件必须不存在或为空。脚本拒绝符号链接、非 UTF-8，以及任何不是扩展历史的内容。以奇数个反斜杠结尾的命令，和反斜杠加换行的续行无法区分，脚本按续行处理。

```bash
python3 ~/.config/bash/zsh-history-to-bash.py ~/.zsh_history /tmp/bash_history.new
```

看过 `/tmp/bash_history.new` 之后，只在 Bash 历史为空时自己放进 `~/.bash_history`。

## 隔离检查

不要对正在使用的机器执行完整的 `-i`。检查使用临时家目录，不改本机登录 shell。

```bash
bash tests/run.sh
```

`VPS_INIT_HOME` 把文件写到指定目录，并且不会调用真正的 `chsh`。`VPS_INIT_SKIP_DOWNLOADS=1` 只布置 rc，不下载 ble.sh。

## 未在这里验证的边界

- 没有在 Ubuntu、Debian 或 CentOS 里执行 apt 或 yum，没有重启，也没有对真实账户执行 `chsh`。
- Bash 4 的停止路径用的是版本字符串，不是一台 Bash 4。
- Arch 不是官方软件包路径。用户级配置要求本机已经有 Bash 5、git、curl、make、gawk 和 xz。
- 没有验证其他 ble.sh 提交。Up 和 Down 依赖该提交的 `ble/history/get-count` 与 `ble/history/get-edited-entry`。
- 没有验证 zsh 元字符历史。以反斜杠结尾的命令会按续行处理。
- 提示符是近似 Pure 的红色路径，颜色是 `#FF0000`。它不是 Zsh 的 Pure 主题。
- `gtl` 在 Bash 里没有 zsh 的 `noglob`。参数里的通配符会先被 Bash 展开。`gk` 和 `gke` 把 gitk 放到后台并 `disown`。
