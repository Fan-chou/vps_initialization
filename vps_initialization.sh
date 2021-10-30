#!/bin/bash

# 字体颜色定义
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_SkyBlue="\033[36m"
Font_White="\033[37m"
Font_Suffix="\033[0m"

# 消息提示定义
Msg_Info="${Font_Blue}[Info] ${Font_Suffix}"
Msg_Warning="${Font_Yellow}[Warning] ${Font_Suffix}"
Msg_Debug="${Font_Yellow}[Debug] ${Font_Suffix}"
Msg_Error="${Font_Red}[Error] ${Font_Suffix}"
Msg_Success="${Font_Green}[Success] ${Font_Suffix}"
Msg_Fail="${Font_Red}[Failed] ${Font_Suffix}"

enviorment_test() {
    echo -e "${Msg_Info} 开始检测系统环境... "
    if [ ! -f "/usr/sbin/virt-what" ]; then
        SystemInfo_GetOSRelease
        if [ "${Var_OSRelease}" = "centos" ] || [ "${Var_OSRelease}" = "rhel" ]; then
            echo -e "${Msg_Warning} Virt-What 模块未找到，安装中 ..."
            yum -y install virt-what
        elif [ "${Var_OSRelease}" = "ubuntu" ] || [ "${Var_OSRelease}" = "debian" ]; then
            echo -e "${Msg_Warning} Virt-What 模块未找到，安装中 ..."
            apt-get update
            apt-get install -y virt-what dmidecode
        elif [ "${Var_OSRelease}" = "fedora" ]; then
            echo -e "${Msg_Warning} Virt-What 模块未找到，安装中 ..."
            dnf -y install virt-what
        elif [ "${Var_OSRelease}" = "alpinelinux" ]; then
            echo -e "${Msg_Warning} Virt-What 模块未找到，安装中 ..."
            apk update
            apk add virt-what
        else
            echo -e "${Msg_Warning} Virt-What 模块未找到, 由于无法识别当前系统无法继续，请手动安装后重新执行 ..."
        fi
    fi
    # 二次检测
    if [ ! -f "/usr/sbin/virt-what" ]; then
        echo -e "${Msg_Error}Virt-What 安装失败! 尝试重新执行或者检查安装位置! (/usr/sbin/virt-what)"
        exit 1
    fi
}

SystemInfo_GetOSRelease() {
    if [ -f "/etc/centos-release" ]; then # CentOS
        Var_OSRelease="centos"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        if [ "$(rpm -qa | grep -o el6 | sort -u)" = "el6" ]; then
            Var_CentOSELRepoVersion="6"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $3}')"
        elif [ "$(rpm -qa | grep -o el7 | sort -u)" = "el7" ]; then
            Var_CentOSELRepoVersion="7"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $4}')"
        elif [ "$(rpm -qa | grep -o el8 | sort -u)" = "el8" ]; then
            Var_CentOSELRepoVersion="8"
            local Var_OSReleaseVersion="$(cat /etc/centos-release | awk '{print $4}')"
        else
            local Var_CentOSELRepoVersion="unknown"
            local Var_OSReleaseVersion="<Unknown Release>"
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/redhat-release" ]; then # RedHat
        Var_OSRelease="rhel"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        if [ "$(rpm -qa | grep -o el6 | sort -u)" = "el6" ]; then
            Var_RedHatELRepoVersion="6"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $3}')"
        elif [ "$(rpm -qa | grep -o el7 | sort -u)" = "el7" ]; then
            Var_RedHatELRepoVersion="7"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $4}')"
        elif [ "$(rpm -qa | grep -o el8 | sort -u)" = "el8" ]; then
            Var_RedHatELRepoVersion="8"
            local Var_OSReleaseVersion="$(cat /etc/redhat-release | awk '{print $4}')"
        else
            local Var_RedHatELRepoVersion="unknown"
            local Var_OSReleaseVersion="<Unknown Release>"
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/fedora-release" ]; then # Fedora
        Var_OSRelease="fedora"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3}')"
        local Var_OSReleaseVersion="$(cat /etc/fedora-release | awk '{print $3,$4,$5,$6,$7}')"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/lsb-release" ]; then # Ubuntu
        Var_OSRelease="ubuntu"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/NAME/{print $3}' | head -n1)"
        local Var_OSReleaseVersion="$(cat /etc/os-release | awk -F '[= "]' '/VERSION/{print $3,$4,$5,$6,$7}' | head -n1)"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
        Var_OSReleaseVersion_Short="$(cat /etc/lsb-release | awk -F '[= "]' '/DISTRIB_RELEASE/{print $2}')"
    elif [ -f "/etc/debian_version" ]; then # Debian
        Var_OSRelease="debian"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/PRETTY_NAME/{print $3,$4}')"
        local Var_OSReleaseVersion="$(cat /etc/debian_version | awk '{print $1}')"
        local Var_OSReleaseVersionShort="$(cat /etc/debian_version | awk '{printf "%d\n",$1}')"
        if [ "${Var_OSReleaseVersionShort}" = "7" ]; then
            Var_OSReleaseVersion_Short="7"
            Var_OSReleaseVersion_Codename="wheezy"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Wheezy\""
        elif [ "${Var_OSReleaseVersionShort}" = "8" ]; then
            Var_OSReleaseVersion_Short="8"
            Var_OSReleaseVersion_Codename="jessie"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Jessie\""
        elif [ "${Var_OSReleaseVersionShort}" = "9" ]; then
            Var_OSReleaseVersion_Short="9"
            Var_OSReleaseVersion_Codename="stretch"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Stretch\""
        elif [ "${Var_OSReleaseVersionShort}" = "10" ]; then
            Var_OSReleaseVersion_Short="10"
            Var_OSReleaseVersion_Codename="buster"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Buster\""
        else
            Var_OSReleaseVersion_Short="sid"
            Var_OSReleaseVersion_Codename="sid"
            local Var_OSReleaseFullName="${Var_OSReleaseFullName} \"Sid (Testing)\""
        fi
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    elif [ -f "/etc/alpine-release" ]; then # Alpine Linux
        Var_OSRelease="alpinelinux"
        local Var_OSReleaseFullName="$(cat /etc/os-release | awk -F '[= "]' '/NAME/{print $3,$4}' | head -n1)"
        local Var_OSReleaseVersion="$(cat /etc/alpine-release | awk '{print $1}')"
        local Var_OSReleaseArch="$(arch)"
        LBench_Result_OSReleaseFullName="$Var_OSReleaseFullName $Var_OSReleaseVersion ($Var_OSReleaseArch)"
    else
        Var_OSRelease="unknown" # 未知系统分支
        LBench_Result_OSReleaseFullName="[Error: Unknown Linux Branch !]"
    fi
}

BaseInstall() {
    echo -e "${Msg_Info}开始为当前系统按照常用软件 ... "
    echo -e "${Msg_Info}检测当前系统 ... "
    SystemInfo_GetOSRelease
    if [ "${Var_OSRelease}" = "ubuntu" ]; then
        echo -e "${Msg_Info}↓↓↓ 当前系统为 Ubuntu 将安装以下软件 ↓↓↓"
        echo -e "        wget curl git lsof vim mtr jq htop sudo vnstat"
        echo -e "        iftop zsh neofetch unzip zip python3 python3-pip"
        echo -e "        socat dnsutils screen iperf3 iotop"
        echo -e "${Msg_Info}↑↑↑ 当前系统为 Ubuntu 将安装以上软件 ↑↑↑"
        echo -e "${Msg_Warning}等待 5 秒，如有疑问请键入 Ctrl + C 终止脚本运行！！！"
        sleep 5
        echo -e "${Msg_Warning}当前系统为 Ubuntu 执行安装中 ..."
        export DEBIAN_FRONTEND=noninteractive
        apt update
        apt upgrade -y
        apt install --no-install-recommends -y wget curl git lsof vim mtr jq htop sudo vnstat iftop zsh neofetch unzip zip python3 python3-pip socat dnsutils screen iperf3 iotop
        echo -e "${Msg_Warning}当前系统为 Ubuntu 执行安装结束 ..."
        echo -e "${Msg_Success}当前系统为 Ubuntu 请注意执行安装是否成功"
    elif [ "${Var_OSRelease}" = "debian" ]; then
        echo -e "${Msg_Info}↓↓↓ 当前系统为 Debian 将安装以下软件 ↓↓↓"
        echo -e "        wget curl git lsof vim mtr jq htop sudo vnstat"
        echo -e "        iftop zsh neofetch unzip zip python3 python3-pip"
        echo -e "        socat dnsutils screen iperf3"
        echo -e "${Msg_Info}↑↑↑ 当前系统为 Debian 将安装以上软件 ↑↑↑"
        echo -e "${Msg_Warning}等待 5 秒，如有疑问请键入 Ctrl + C 终止脚本运行！！！"
        sleep 5
        echo -e "${Msg_Warning}当前系统为 Debian 执行安装中 ..."
        apt update
        apt upgrade -y
        apt install -y wget curl git lsof vim mtr jq htop sudo vnstat iftop zsh neofetch unzip zip python3 python3-pip socat dnsutils screen iperf3
        echo -e "${Msg_Warning}当前系统为 Debian 执行安装结束 ..."
        echo -e "${Msg_Success}当前系统为 Debian 请注意执行安装是否成功"
    elif [ "${Var_OSRelease}" = "centos" ]; then
        echo -e "${Msg_Info}↓↓↓ 当前系统为 Centos 将安装以下软件 ↓↓↓"
        echo -e "        wget curl git lsof vim mtr jq htop sudo vnstat"
        echo -e "        iftop zsh neofetch unzip zip python3 python3-pip"
        echo -e "        socat bind-utils screen"
        echo -e "${Msg_Info}↑↑↑ 当前系统为 Centos 将安装以上软件 ↑↑↑"
        echo -e "${Msg_Warning}等待 5 秒，如有疑问请键入 Ctrl + C 终止脚本运行！！！"
        sleep 5
        echo -e "${Msg_Warning}当前系统为 Centos 执行安装中 ..."
        yum -y install epel-release
        yum install -y wget curl git lsof vim mtr jq htop sudo vnstat iftop zsh neofetch unzip zip python3 python3-pip socat bind-utils screen
        echo -e "${Msg_Warning}当前系统为 Centos 执行安装结束 ..."
        echo -e "${Msg_Success}当前系统为 Centos 请注意执行安装是否成功"
    fi
}

InstallOhmyzsh() {
    echo -e "${Msg_Warning}提醒，当前安装过程对网络有一定要求，部分地区如中国大陆地区，请确保 github.com 的顺畅访问！！！"
    echo -e "${Msg_Warning}Ohmyzsh 将默认安装在当前账户 \$HOME 目录下，如有其它需要请键入 Ctrl + C 终止脚本运行！！！"
    sleep 5
    echo -e "${Msg_Info}开始检测 ZSH 是否安装 ... "
    if [ ! -f "/usr/bin/zsh" ]; then
        SystemInfo_GetOSRelease
        if [ "${Var_OSRelease}" = "centos" ] || [ "${Var_OSRelease}" = "rhel" ]; then
            echo -e "${Msg_Warning}zsh 未找到，安装中 ..."
            yum -y install zsh
        elif [ "${Var_OSRelease}" = "ubuntu" ] || [ "${Var_OSRelease}" = "debian" ]; then
            echo -e "${Msg_Warning}zsh 未找到，安装中 ..."
            apt-get update
            apt-get install -y zsh
        elif [ "${Var_OSRelease}" = "fedora" ]; then
            echo -e "${Msg_Warning}zsh 未找到，安装中 ..."
            dnf -y install zsh
        elif [ "${Var_OSRelease}" = "alpinelinux" ]; then
            echo -e "${Msg_Warning}zsh 未找到，安装中 ..."
            apk update
            apk add zsh
        else
            echo -e "${Msg_Warning}zsh 未找到, 由于无法识别当前系统无法继续，请手动安装后重新执行 ..."
        fi
    fi
    # 二次检测
    if [ ! -f "/usr/bin/zsh" ]; then
        echo -e "${Msg_Error}zsh 安装失败! 尝试重新执行或者检查安装位置! (/usr/bin/zsh)"
        exit 1
    fi
    echo -e "${Msg_Info}ZSH 已经安装，开始检测 ohmyzsh 是否安装 ... "

    if [ ! -d "/root/.oh-my-zsh" ]; then
        SystemInfo_GetOSRelease
        if [ "${Var_OSRelease}" = "centos" ] || [ "${Var_OSRelease}" = "rhel" ]; then
            echo -e "${Msg_Warning}安装 git 中 ..."
            yum -y install git
        elif [ "${Var_OSRelease}" = "ubuntu" ] || [ "${Var_OSRelease}" = "debian" ]; then
            echo -e "${Msg_Warning}安装 git curl 中 ..."
            apt-get update
            apt-get install -y curl git
        elif [ "${Var_OSRelease}" = "fedora" ]; then
            echo -e "${Msg_Warning}安装 git 中 ..."
            dnf -y install zsh git
        elif [ "${Var_OSRelease}" = "alpinelinux" ]; then
            echo -e "${Msg_Warning}安装 git curl 中 ..."
            apk update
            apk add curl git
        fi
        if [ ! -f "/usr/bin/curl" ]; then
            echo -e "${Msg_Warning}curl 未找到, 由于无法识别当前系统无法继续，请手动安装后重新执行 ..."
        fi
        if [ ! -f "/usr/bin/git" ]; then
            echo -e "${Msg_Warning}git 未找到, 由于无法识别当前系统无法继续，请手动安装后重新执行 ..."
        else
            cd $HOME
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended" --skip-chsh
            git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
            git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
            mkdir -p "$HOME/.zsh"
            git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
            echo "fpath+=$HOME/.zsh/pure" >>$HOME/.zshrc
            echo "autoload -U promptinit; promptinit" >>$HOME/.zshrc
            echo "zmodload zsh/nearcolor" >>$HOME/.zshrc
            echo "zstyle :prompt:pure:path color '#FF0000'" >>$HOME/.zshrc
            echo "prompt pure" >>$HOME/.zshrc
            plugins=$(cat $HOME/.zshrc | grep plugins= | grep ^p)
            sed -i "s/$plugins/plugins=(git z colored-man-pages zsh-autosuggestions zsh-syntax-highlighting extract)/g" $HOME/.zshrc
            echo -e "${Msg_Warning}Ohmyzsh 安装设置完成 ..."
            if [ "$(basename -- "$SHELL")" = "zsh" ]; then
                echo -e "${Msg_Warning}当前 Shell 为 ZSH ..."
            fi
            # Check if we're running on Termux
            case "$PREFIX" in
            *com.termux*)
                termux=true
                zsh=zsh
                ;;
            *) termux=false ;;
            esac

            if [ "$termux" != true ]; then
                # Test for the right location of the "shells" file
                if [ -f /etc/shells ]; then
                    shells_file=/etc/shells
                elif [ -f /usr/share/defaults/etc/shells ]; then # Solus OS
                    shells_file=/usr/share/defaults/etc/shells
                else
                    echo -e "${Msg_Error}/etc/shells 文件不存在. 请自行切换默认 Shell ！！！"
                    return
                fi

                # Get the path to the right zsh binary
                # 1. Use the most preceding one based on $PATH, then check that it's in the shells file
                # 2. If that fails, get a zsh path from the shells file, then check it actually exists
                if ! zsh=$(command -v zsh) || ! grep -qx "$zsh" "$shells_file"; then
                    if ! zsh=$(grep '^/.*/zsh$' "$shells_file" | tail -1) || [ ! -f "$zsh" ]; then
                        echo -e "${Msg_Error}未找到在 '$shells_file' 找到 zsh 相关内容"
                        echo -e "${Msg_Error}请自行切换默认 Shell ！！！"
                        return
                    fi
                fi
            fi

            if [ -n "$SHELL" ]; then
                echo "$SHELL" >~/.shell.pre-oh-my-zsh
            else
                grep "^$USERNAME:" /etc/passwd | awk -F: '{print $7}' >~/.shell.pre-oh-my-zsh
            fi

            # Actually change the default shell to zsh
            if ! chsh -s "$zsh"; then
                echo -e "${Msg_Error}chsh 命令执行失败，请自行切换默认 Shell ！！！"
            else
                export SHELL="$zsh"
                echo "${GREEN}Shell 已经切换至 '$zsh'"
            fi
            echo -e "${Msg_Success}Ohmyzsh 安装完成，并使用 Pure [https://github.com/sindresorhus/pure] 主题 ..."
            exec zsh -l
        fi
    else
        echo -e "${Msg_Success}Ohmyzsh 已经安装！！！"
    fi
}

InstallCollectd() {
    #   echo -e "${Msg_Warning}提醒，当前安装过程对网络有一定要求，部分地区如中国大陆地区，请确保 github.com 的顺畅访问！！！"
    #   echo -e "${Msg_Warning}Ohmyzsh 将默认安装在当前账户 \$HOME 目录下，如有其它需要请键入 Ctrl + C 终止脚本运行！！！"
    #   sleep 5
    echo -e "${Msg_Info}开始检测 collectd 是否安装 ... "
    if [ ! -f "/usr/sbin/collectd" ]; then
        SystemInfo_GetOSRelease
        if [ "${Var_OSRelease}" = "centos" ] || [ "${Var_OSRelease}" = "rhel" ]; then
            echo -e "${Msg_Warning}暂不支持 ${Var_OSRelease}"
        elif [ "${Var_OSRelease}" = "ubuntu" ] || [ "${Var_OSRelease}" = "debian" ]; then
            echo -e "${Msg_Warning}zsh 未找到，安装中 ..."
            apt-get update
            apt-get autoremove lvm2 collectd-core collectd -y
            apt-get purge lvm2 collectd-core collectd -y
            apt-get install lvm2 -y
            apt-get install collectd-core -y
            apt-get install collectd liboping0 -y
        elif [ "${Var_OSRelease}" = "fedora" ]; then
            echo -e "${Msg_Warning}暂不支持 ${Var_OSRelease}"
        elif [ "${Var_OSRelease}" = "alpinelinux" ]; then
            echo -e "${Msg_Warning}暂不支持 ${Var_OSRelease}"
        else
            echo -e "${Msg_Warning}collectd 未找到, 由于无法识别当前系统无法继续 ..."
        fi
    else
        echo -e "${Msg_Warning}collectd 已经安装 ..."
    fi
    # 二次检测
    if [ ! -f "/usr/sbin/collectd" ]; then
        echo -e "${Msg_Error}collectd 安装失败! 尝试重新执行或者检查安装位置! (/usr/sbin/collectd)"
        exit 1
    else
        systemctl enable collectd
        echo -e "${Msg_Warning}已经添加 collectd 开机自启动 ..."
    fi
}

Installsysctl() {
    echo -e "${Msg_Info}正在添加 sysctl 参数 ... "
    SystemInfo_GetOSRelease
    if [ "${Var_OSRelease}" = "ubuntu" ] || [ "${Var_OSRelease}" = "debian" ]; then
        sed -i "$a net.ipv4.ip_forward=1" /etc/sysctl.conf
        sed -i "$a net.core.default_qdisc=fq" /etc/sysctl.conf
        sed -i "$a net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf
        sed -i "$a net.ipv4.conf.default.rp_filter=0" /etc/sysctl.conf
        sed -i "$a net.ipv4.conf.all.rp_filter=0" /etc/sysctl.conf
        sed -i "$a vm.swappiness = 5" /etc/sysctl.conf

        /usr/sbin/sysctl -p
    else
        echo -e "${Msg_Warning}暂不支持 ${Var_OSRelease}..."
    fi
}

# InstallGolang() {
#     echo -e "${Msg_Info}开始检测 Golang 是否安装 ... "
#     golang_dir=$(which go)
#     if [ $? -ne 0 ]; then
#         SystemInfo_GetOSRelease

#         if [ "${Var_OSRelease}" = "centos" ] || [ "${Var_OSRelease}" = "rhel" ]; then
#             echo -e "${Msg_Warning}暂不支持 ${Var_OSRelease}"
#         elif [ "${Var_OSRelease}" = "ubuntu" ] || [ "${Var_OSRelease}" = "debian" ]; then
#             echo -e "${Msg_Warning}Golang 未找到，安装中 ..."
#             apt-get update
#             apt-get autoremove lvm2 collectd-core collectd -y
#             apt-get purge lvm2 collectd-core collectd -y
#             apt-get install lvm2 -y
#             apt-get install collectd-core -y
#             apt-get install collectd liboping0 -y
#         elif [ "${Var_OSRelease}" = "fedora" ]; then
#             echo -e "${Msg_Warning}暂不支持 ${Var_OSRelease}"
#         elif [ "${Var_OSRelease}" = "alpinelinux" ]; then
#             echo -e "${Msg_Warning}暂不支持 ${Var_OSRelease}"
#         else
#             echo -e "${Msg_Warning}collectd 未找到, 由于无法识别当前系统无法继续 ..."
#         fi
#         if [ ! -f "/usr/bin/curl" ]; then
#             echo -e "${Msg_Warning}curl 未找到, 由于无法识别当前系统无法继续，请手动安装后重新执行 ..."
#         fi
#     else
#         echo -e "${Msg_Warning}检测到 Goalng 已经安装 ("${golang_dir}") ..."
#     fi
#     # 二次检测
#     if [ ! -f "/usr/sbin/collectd" ]; then
#         echo -e "${Msg_Error}collectd 安装失败! 尝试重新执行或者检查安装位置! (/usr/sbin/collectd)"
#         exit 1
#     else
#         systemctl enable collectd
#         echo -e "${Msg_Warning}已经添加 collectd 开机自启动 ..."
#     fi
# }

echo_help() {
    echo -e " "
    echo -e "${Font_SkyBlue}JackChou${Font_Suffix} ${Font_Yellow}Server Operation and maintenance${Font_Suffix}"
    echo -e " "
    echo -e "${Font_Yellow}Reference from:${Font_Suffix}\t\t ${Font_SkyBlue}iLemonrain <ilemonrain@ilemonrain.com>${Font_Suffix}"
    # echo -e "${Font_Yellow}Project Homepage:${Font_Suffix}\t ${Font_SkyBlue}https://blog.ilemonrain.com/linux/LemonBench.html${Font_Suffix}"
    # echo -e "${Font_Yellow}Code Version:${Font_Suffix}\t\t ${Font_SkyBlue}${BuildTime}${Font_Suffix}"
    echo -e " "
    echo -e "Usage:"
    # echo -e "${Font_SkyBlue}>> One-Key Benchmark${Font_Suffix}"
    # echo -e "${Font_Yellow}--mode TestMode${Font_Suffix}\t${Font_SkyBlue}Test Mode (fast/full, aka FastMode/FullMode)${Font_Suffix}"
    # echo -e ""
    echo -e "${Font_SkyBlue}>> Single Command${Font_Suffix}"
    echo -e "${Font_Yellow}-i or --install [software]${Font_Suffix}\t${Font_SkyBlue}Base software install${Font_Suffix}"
    echo -e "${Font_Yellow}-h or --help${Font_Suffix}\t\t\t${Font_SkyBlue}Print Help memu${Font_Suffix}"
    # echo -e "${Font_Yellow}--spfast${Font_Suffix}\t\t${Font_SkyBlue}Speedtest Test (Fast Test Mode)${Font_Suffix}"
    # echo -e "${Font_Yellow}--spfull${Font_Suffix}\t\t${Font_SkyBlue}Speedtest Test (Full Test Mode)${Font_Suffix}"
    # echo -e "${Font_Yellow}--trfast${Font_Suffix}\t\t${Font_SkyBlue}Traceroute Test (Fast Test Mode)${Font_Suffix}"
    # echo -e "${Font_Yellow}--trfull${Font_Suffix}\t\t${Font_SkyBlue}Traceroute Test (Full Test Mode)${Font_Suffix}"
    # echo -e "${Font_Yellow}--sbcfast${Font_Suffix}\t\t${Font_SkyBlue}CPU Benchmark Test (Fast Test Mode)${Font_Suffix}"
    # echo -e "${Font_Yellow}--sbcfull${Font_Suffix}\t\t${Font_SkyBlue}CPU Benchmark Test (Full Test Mode)${Font_Suffix}"
    # echo -e "${Font_Yellow}--sbmfast${Font_Suffix}\t\t${Font_SkyBlue}Memory Benchmark Test (Fast Test Mode)${Font_Suffix}"
    # echo -e "${Font_Yellow}--sbmfull${Font_Suffix}\t\t${Font_SkyBlue}Memory Benchmark Test (Full Test Mode)${Font_Suffix}"
    # echo -e "${Font_Yellow}--spoof${Font_Suffix}\t\t${Font_SkyBlue}Caida Spoofer Test ${Font_Yellow}(Use it at your own risk)${Font_Suffix}${Font_Suffix}"
}

case $1 in
--install | -i)
    if [ $# -eq 1 ]; then
        enviorment_test
        BaseInstall
    elif [ $# -eq 2 ]; then
        case $2 in
        ohmyzsh)
            InstallOhmyzsh
            ;;
        collectd)
            InstallCollectd
            ;;
        sysctl)
            Installsysctl
            ;;
        *)
            [[ "$1" != 'error' ]] && echo -ne "\n${Msg_Error}Not Support install $2\n"
            ;;
        esac
    fi
    ;;
--help | -h)
    echo_help
    ;;
*)
    [[ "$1" != 'error' ]] && echo -ne "\n${Msg_Error}Invalid Parameters: \"$1\"\n"
    echo_help
    exit 1
    ;;
esac
