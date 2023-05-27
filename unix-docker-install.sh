#!/bin/bash

set -e

# 定义颜色常量
ESC="\033"; RESET="${ESC}[0;39m"
RED="${ESC}[31m"; GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; BLUE="${ESC}[34m"; MAGENTA="${ESC}[35m"; CYAN="${ESC}[36m"

ask() {
  char_count='0'
  prompt="${1}: "
  reply=''
  while IFS='' read -n '1' -p "${prompt}" -r -s 'char'; do
    case "${char}" in
    # Handles NULL
    $'\000')
      break
      ;;
      # Handles BACKSPACE and DELETE
    $'\010' | $'\177')
      if ((char_count > 0)); then
        prompt=$'\b \b'
        reply="${reply%?}"
        ((char_count--))
      else
        prompt=''
      fi
      ;;
    *)
      prompt='*'
      reply+="${char}"
      ((char_count++))
      ;;
    esac
  done
  printf '\n' >&2
  printf '%s\n' "${reply}"
}

if [ "$(uname)" != 'Linux' ] && [ "$(uname)" != 'Darwin' ]; then echo -e "${RED}不支持的操作系统!${RESET}"; fi

if [[ "$(uname)" == 'Linux' && $EUID != 0 ]]; then
  echo -e "${RED}请使用root账号运行该脚本！${RESET}"
  exit 1
fi

echo -e "${GREEN}这个脚本将为你做以下工作:
  1. 安装Docker、docker-compose、Git.(如果已安装则跳过)
  2. 使用 Git 克隆 SilveryStar/Adachi-BOT 项目.
  3. 创建 BOT 需要的基础配置文件.
  4. 使用 Docker 运行 BOT 和 Redis.${RESET}
"
os=""
if [ "$(uname)" == "Linux" ]; then
  os=$(cat /etc/*release | grep ^NAME | tr -d 'NAME="') >/dev/null 2>&1
fi

if [ -x "$(command -v docker)" ]; then
  echo -e "\n${CYAN}docker已经安装，跳过！${RESET}\n"
elif [ "$(uname)" == 'Darwin' ]; then
  echo -e "\n${RED}请自行安装docker后再使用该脚本, docker下载地址: https://www.docker.com/get-started ${RESET}\n"
  exit 1
else
  echo -e "\n${GREEN}安装docker中...${RESET}\n"
  wget https://get.docker.com -O - | bash -s docker --mirror Aliyun
  if ! [ "$(getent group docker)" ]; then
    #添加docker用户组
    groupadd docker
  fi
  if [ "$SUDO_USER" ]; then
    #如果是sudo模式则将sudo用户加入组中
    gpasswd -a "$SUDO_USER" docker
  else
    #将登陆用户加入到docker用户组中
    gpasswd -a "$USER" docker
  fi
  #更新用户组
  newgrp docker <<EOF
    mkdir -p "/etc/docker" && touch "/etc/docker/daemon.json"
    echo '{
    "registry-mirrors" : [
      "https://ajxzc7hl.mirror.aliyuncs.com",
      "https://registry.docker-cn.com",
      "http://docker.mirrors.ustc.edu.cn",
      "http://hub-mirror.c.163.com",
      "https://mirror.ccs.tencentyun.com"
    ],
    "debug" : false,
    "experimental" : true
  }' >"/etc/docker/daemon.json"
    systemctl start docker
    # 开机自启动
    systemctl enable docker
    echo "安装docker成功！"
EOF
fi

use_docker_plugin=false
if ! docker compose version; then
  if [ "$(uname)" == 'Darwin' ]; then
    echo -e "\n${RED}Docker Desktop版本太低，请更新后再使用本脚本!${RESET}\n"
    exit 1
  else
    echo -e "\n${GREEN}安装docker-compose中...${RESET}\n"
    wget "https://ghproxy.com/https://github.com/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -O "/usr/local/bin/docker-compose"
    # shellcheck disable=SC2012
    if [ ! -f "/usr/local/bin/docker-compose" ] || [ "$(ls -l /usr/local/bin/docker-compose | awk '{print $5}')" -lt 10000000 ]; then
      # 尝试从daocloud镜像源再次下载
      echo -e "\n${YELLOW}从github下载docker-compose失败，将从镜像地址重试。${RESET}\n"
      wget "https://get.daocloud.io/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -O "/usr/local/bin/docker-compose"
    fi
    chmod +x "/usr/local/bin/docker-compose"
    ln -s "/usr/local/bin/docker-compose" "/usr/bin/docker-compose"
  fi
else
  use_docker_plugin=true
  echo -e "\n${CYAN}docker compose已经安装, 跳过!${RESET}\n"
fi

if [ -x "$(command -v git)" ]; then
  echo -e "\n${CYAN}git已经安装，跳过!${RESET}\n"
else
  echo -e "\n${GREEN}安装git中...${RESET}\n"
  if [ -x "$(command -v yum)" ]; then
    yum install -y git
  elif [ -x "$(command -v apt-get)" ] && [ "$os" == 'Ubuntu' ]; then
    add-apt-repository -y ppa:git-core/ppa
    apt update
    apt install -y git
  elif [ -x "$(command -v apt-get)" ]; then
    apt-get install -y git
  elif [ -x "$(command -v pkg)" ] && [ "$os" == 'FreeBSD' ]; then
    if [ ! -f "/usr/local/etc/pkg/repos/FreeBSD.conf" ]; then
      # 添加镜像加速
      mkdir -p "/usr/local/etc/pkg/repos"
      # shellcheck disable=SC2016
      echo 'FreeBSD: {
                url: "pkg+http://mirrors.ustc.edu.cn/freebsd-pkg/${ABI}/quarterly",
              }' | tee "/usr/local/etc/pkg/repos/FreeBSD.conf" >"/dev/null"
    fi
    pkg install -y git
  elif [ -x "$(command -v dnf)" ]; then
    dnf install -y git
  elif [ -x "$(command -v pacman)" ]; then
    pacman -S git -y
  elif [ -x "$(command -v emerge)" ]; then
    emerge --verbose dev-vcs/git -y
  elif [ -x "$(command -v zypper)" ]; then
    zypper install git -y
  elif [ -x "$(command -v urpmi)" ]; then
    urpmi git -y
  elif [ -x "$(command -v nix-env)" ]; then
    nix-env -i git -y
  elif [ -x "$(command -v pkgutil)" ]; then
    pkgutil -i git -y
  elif [ -x "$(command -v pkg)" ]; then
    pkg install -y developer/versioning/git
  elif [ "$(command -v pkg_add)" ]; then
    pkg_add -y git
  elif [ -x "$(command -v apk)" ]; then
    apk add -y git
  else
    echo "\n${RED}不支持到系统，请自行安装git。${RESET}\n"
    exit 2
  fi
  echo -e "\n${GREEN}安装git成功${RESET}\n"
fi

echo -e "\n${GREEN}开始使用git拉取adachi-bot...${RESET}\n"
work_dir=$(pwd)
if [ -d "${work_dir}/Adachi-BOT" ]; then
  echo -e "\n${YELLOW}adachi-bot已经存在，将在当前文件夹做备份.${RESET}\n"
  mv "Adachi-BOT" "Adachi-BOT-backup-$(date +%Y-%m-%d_%T)"
fi
git clone https://ghproxy.com/https://github.com/SilveryStar/Adachi-BOT.git --depth=1
echo -e "\n${GREEN}adachi-bot拉取成功.${RESET}\n"

# 安装jq解析json
echo -e "\n${GREEN}开始安装jq解析json...${RESET}\n"
if ! type jq >/dev/null 2>&1; then
  if [ "$(uname)" == 'Darwin' ]; then
    if type brew >/dev/null 2>&1; then
      brew install jq
    elif type port >/dev/null 2>&1; then
      echo -e "\n${YELLOW}使用MacPort安装jq，可能需要sudo权限。${RESET}\n"
      sudo port install jq -y
    else
      curl -L -# "https://ghproxy.com/https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64" -o "/usr/local/bin/jq"
      chmod +x "/usr/local/bin/jq"
      ln -s "/usr/local/bin/jq" "/usr/bin/jq"
    fi
  else
    if type apt-get >/dev/null 2>&1; then
      apt-get install jq -y
    elif type dnf >/dev/null 2>&1; then
      dnf install jq -y
    elif type zypper >/dev/null 2>&1; then
      zypper install jq -y
    elif type pacman >/dev/null 2>&1; then
      pacman -S jq -y
    else
      wget "https://ghproxy.com/https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" -O "/usr/local/bin/jq"
      chmod +x "/usr/local/bin/jq"
      ln -s "/usr/local/bin/jq" "/usr/bin/jq"
    fi
  fi
  echo -e "\n${GREEN}jq安装完成...${RESET}\n"
else
  echo -e "\n${CYAN}jq已安装，开始解析...${RESET}\n"
fi

cd "Adachi-BOT/src/plugins"
echo -e "\n${CYAN}开始选择安装插件，回复编号选择(回复0结束选择,回复a全选)...${RESET}\n"
plugins=$(curl -s 'https://source.hibennett.cn/bot/plugins.json')
i=1
for k in $(jq -r '.[]|.name' <<<"$plugins"); do
  echo "${i}) ${k}"
  ((i++))
done
len=$((i-1))

while true; do
  echo -n "#? "
  read -r inp
  if [ "${inp}" == "0" ]; then
    break
  fi
  if [ "${inp}" == "a" ]; then
    # 下载全部插件
    for k in $(jq -r 'keys|.[]' <<<"$plugins"); do
      p=$(jq -r ".[${k}]" <<<"${plugins}")
      ref=$(jq -r ".ref?" <<<"${p}")
      opt=""
      if [ "$ref" != "null" ]; then
        opt="-b ${ref} "
      fi
      name=$(jq -r ".name" <<<"${p}")
      url=$(jq -r ".url" <<<"${p}")
      alias=$(jq -r ".alias" <<<"${p}")
      if [ "${alias}" == "null" ]; then
        alias=""
      fi
      original_url=$(jq -r ".original_url" <<<"${p}")
      opt="${opt}${url} ${alias}"
      # shellcheck disable=SC2086
      git clone --depth=1 ${opt}
      echo -e "\n${GREEN}${name}${RESET}已下载，使用方式请访问 ${GREEN}${original_url}${RESET}\n"
      use_plugins="all"
    done
    break
  fi
  if [[ "$inp" =~ " " ]]; then
    # shellcheck disable=SC2206
    arr=($inp)
    for m in "${arr[@]}"; do
      if [[ $m -gt $len ]]; then
        echo -e "\n${RED}不存在${m}号插件.${RESET}\n"
        continue
      fi
      idx=$((m - 1))
      p=$(jq -r ".[${idx}]" <<<"${plugins}")
      ref=$(jq -r ".ref?" <<<"${p}")
      opt=""
      if [ "$ref" != "null" ]; then
        opt="-b ${ref} "
      fi
      name=$(jq -r ".name" <<<"${p}")
      url=$(jq -r ".url" <<<"${p}")
      alias=$(jq -r ".alias" <<<"${p}")
      if [ "${alias}" == "null" ]; then
        alias=""
      fi
      original_url=$(jq -r ".original_url" <<<"${p}")
      opt="${opt}${url} ${alias}"
      # shellcheck disable=SC2086
      git clone --depth=1 ${opt}
      echo -e "\n${GREEN}${name}${RESET}已下载，使用方式请访问 ${GREEN}${original_url}${RESET}\n"
      use_plugins="${use_plugins}"" ${name}"
    done
    break
  fi
  if [[ $inp -gt $len ]]; then
    echo -e "\n${RED}不存在${inp}号插件，如果你要一次多选请用空格隔开.${RESET}\n"
    continue
  fi
  idx=$((inp - 1))
  p=$(jq -r ".[${idx}]" <<<"${plugins}")
  ref=$(jq -r ".ref?" <<<"${p}")
  opt=""
  if [ "$ref" != "null" ]; then
    opt="-b ${ref} "
  fi
  name=$(jq -r ".name" <<<"${p}")
  url=$(jq -r ".url" <<<"${p}")
  alias=$(jq -r ".alias" <<<"${p}")
  if [ "${alias}" == "null" ]; then
    alias=""
  fi
  original_url=$(jq -r ".original_url" <<<"${p}")
  opt="${opt}${url} ${alias}"
  # shellcheck disable=SC2086
  git clone --depth=1 ${opt}
  echo -e "\n${GREEN}${name}${RESET}已下载，使用方式请访问 ${GREEN}${original_url}${RESET}\n"
  use_plugins="${use_plugins}"" ${name}"
done

if [ "${use_plugins}" ]; then
  echo -e "\n${YELLOW}>>> 插件选择结束，你选择了:${RESET}${GREEN}${use_plugins}${RESET}\n"
else
  echo -e "\n${YELLOW}>>> 插件选择结束，你未选择插件。${RESET}\n"
fi

cd "${work_dir}"

echo -e "\n==============\n${GREEN}开始创建配置文件${RESET}\n==============\n"
if [ ! -d "${work_dir}/Adachi-BOT/config" ]; then mkdir -p "${work_dir}/Adachi-BOT/config"; fi
cd "${work_dir}/Adachi-BOT/config" && touch setting.yml commands.yml cookies.yml genshin.yml && cd "${work_dir}"

echo -e "\n${YELLOW}请选择机器人登录平台(输入编号):${RESET}"
select platform_str in "安卓手机" "安卓Pad" "安卓手表" "MacOS" "iPad" "安卓8.8.88"; do
  case $platform_str in
  "安卓手机")
    platform=1
    break
    ;;
  "安卓Pad")
    platform=2
    break
    ;;
  "安卓手表")
    platform=3
    break
    ;;
  "MacOS")
    platform=4
    break
    ;;
  "iPad")
    platform=5
    break
    ;;
  "安卓8.8.88")
    platform=6
    break
    ;;
  *)
    echo -e "\n${RED}你选择的登录平台编号非法，重选！${RESET}\n"
    ;;
  esac
done
echo -n -e "${YELLOW}请输入机器人的QQ号: ${RESET}"
read -r qq_num
echo -e "${YELLOW}请选择登录方式: ${RESET}"
select login_type in "密码" "扫码"; do
  case $login_type in
  "密码")
    qq_password="$(ask Password)"
    qrcode=false
    break
    ;;
  "扫码")
    qrcode=true
    qq_password='""'
    break
    ;;
  *)
    echo -e "${RED}没有这种登录方式，重选！${RESET}"
    ;;
  esac
done
echo -n -e "${YELLOW}请输入机器人主人账号: ${RESET}"
read -r master_num
echo -e "${CYAN}获取米游社cookie方式一:${RESET}
  1) 无痕模式打开 ${GREEN}https://www.miyoushe.com/ys/${RESET} 页面
  2) F12打开网页控制台，按下${MAGENTA}Ctrl+F8(⌘+F8)${RESET}后再按${MAGENTA}F8${RESET}即可解除暂停
  3) 在${YELLOW}Network(网络)${RESET}栏，在${YELLOW}Filter(过滤)${RESET}里粘贴 ${CYAN}getUserGameUnreadCount${RESET}，同时选择${CYAN}Fetch/XHR${RESET}
  4) 点击一条捕获到的结果，往下拉，找到 Cookie 后复制其内容即可。\n\n"

echo -e "${CYAN}获取米游社cookie方式二:${RESET}
  1) 无痕模式打开 ${GREEN}https://user.mihoyo.com/${RESET} 并进行登入操作
  2) 同方式一中的第二步解除暂停
  3) 在Console(控制台)栏输入 ${CYAN}copy(document.cookie)${RESET} 后回车即可将Cookie复制在剪切板中。\n\n"

echo -n -e "${GREEN}请输入一个米游社cookie: ${RESET}"
read -r mys_cookie

if [ "$(uname)" == 'Darwin' ]; then
  jwt_secret=$(LC_ALL=C tr -dc "[:alnum:]" </dev/urandom | head -c 16)
else
  jwt_secret="$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)"
fi

echo "tip: 前往 https://docs.adachi.top/config 查看配置详情
qrcode: ${qrcode}
number: ${qq_num}
password: ${qq_password}
master: ${master_num}
header: \"#\"
platform: ${platform}
atUser: false
atBOT: false
addFriend: true
autoChat:
  enable: false
  type: 1
  secretId: \"\"
  secretKey: \"\"
inviteAuth: master
countThreshold: 60
groupIntervalTime: 1500
privateIntervalTime: 2000
helpMessageStyle: message
logLevel: info
logKeepDays: 30
dbPort: 56379
dbPassword: \"\"
webConsole:
  enable: true
  consolePort: 80
  tcpLoggerPort: 54921
  jwtSecret: ${jwt_secret}
helpPort: 54919
callTimes: 3
fuzzyMatch: false
matchPrompt: true
useWhitelist: false
banScreenSwipe:
  enable: false
  limit: 10
  duration: 1800
  prompt: true
  promptMsg: 请不要刷屏哦~
banHeavyAt:
  enable: false
  limit: 10
  duration: 1800
  prompt: true
  promptMsg: 你at太多人了，会被讨厌的哦~
ThresholdInterval: false
ffmpegPath: \"\"
ffprobePath: \"\"
mailConfig:
  platform: qq
  user: 123456789@qq.com
  authCode: \"\"
  logoutSend: false
  sendDelay: 5" >"${work_dir}/Adachi-BOT/config/setting.yml"

echo "cookies:
  - ${mys_cookie}" >"${work_dir}/Adachi-BOT/config/cookies.yml"

echo "cardWeaponStyle: normal
cardProfile: random
serverPort: 58612" >"${work_dir}/Adachi-BOT/config/genshin.yml"

printf "\n%b>>> 开始运行BOT >>>%b\n" "${GREEN}" "${RESET}"
cd Adachi-BOT

# 重新设置文件的用户组，让非ROOT用户后续自行修改文件不需要提权
if [[ $EUID == 0 ]]; then
  if [ "$SUDO_USER" ]; then
    chown -R "$(id -u "$SUDO_USER")":"$(id -u "$SUDO_USER")" .
  else
    chown -R "$(id -u "$USER")":"$(id -u "$USER")" .
  fi
fi
shell_str=""
if [ "${use_docker_plugin}" == "true" ]; then
  docker compose up -d --build
  shell_str="docker compose"
else
  docker-compose up -d --build
  shell_str="docker-compose"
fi
# shellcheck disable=SC2028
echo -e "<====================================${GREEN}BOT正在运行中,请稍等...${RESET}===================================>\n
\t  1) ${YELLOW}setting中基本上使用了默认配置，已启用WebConsole。${RESET}\n
\t  2) ${YELLOW}可在Adachi-BOT目录中使用${shell_str} down关闭服务，${shell_str} up -d启动服务。${RESET}\n
\t  3) ${YELLOW}可根据官方文档 https://docs.adachi.top/config/#setting-yml 重新设置你的配置，
\t     使用的指令可根据#help指令的结果对照在command.yml中修改。${RESET}\n
\t  4) ${YELLOW}使用CTRL+C组合键结束日志查看... ${RESET}\n
<===========================${GREEN} ↓ ↓ ↓ ️以下是BOT服务的日志内容 ↓ ↓ ↓ ${RESET}️==============================>\n\n"

docker logs -f adachi-bot
