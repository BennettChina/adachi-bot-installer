#!/bin/bash

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

set -e

if [ "$(uname)" != 'Linux' ] && [ "$(uname)" != 'Darwin' ]; then echo '不支持的操作系统!'; fi

if [[ "$(uname)" == 'Linux' && $EUID != 0 ]]; then
  echo "请使用root账号运行该脚本！"
  exit 1
fi

echo "the script will do:
1. install docker and docker-compose and git.(skip when installed)
2. use git clone SilveryStar/Adachi-BOT.
3. create configuration files.
4. run adachi-bot and redis in docker.
"
os=$(cat /etc/*release | grep ^NAME | tr -d 'NAME="') >/dev/null 2>&1

if [ -x "$(command -v docker)" ]; then
  echo "docker已经安装，跳过！"
elif [ "$(uname)" == 'Darwin' ]; then
  echo "请自行安装docker后再使用该脚本, docker下载地址: https://www.docker.com/get-started"
  exit 1
else
  echo "安装docker中..."
  wget https://get.docker.com -O - | bash -s docker --mirror Aliyun
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
fi

use_docker_plugin=false
if ! docker compose version; then
  if [ "$(uname)" == 'Darwin' ]; then
    echo "Docker Desktop版本太低，请更新后再使用本脚本!"
    exit 1
  else
    echo "安装docker-compose中..."
    wget "https://ghproxy.com/https://github.com/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -O "/usr/local/bin/docker-compose"
    # shellcheck disable=SC2012
    if [ ! -f "/usr/local/bin/docker-compose" ] || [ "$(ls -l /usr/local/bin/docker-compose | awk '{print $5}')" -lt 10000000 ]; then
      # 尝试从daocloud镜像源再次下载
      echo "从github下载docker-compose失败，将从镜像地址重试。"
      wget "https://get.daocloud.io/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -O "/usr/local/bin/docker-compose"
    fi
    chmod +x "/usr/local/bin/docker-compose"
    ln -s "/usr/local/bin/docker-compose" "/usr/bin/docker-compose"
  fi
else
  use_docker_plugin=true
  echo "docker compose已经安装, 跳过!"
fi

if [ -x "$(command -v git)" ]; then
  echo "git已经安装，跳过!"
else
  echo "安装git中..."
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
    echo "不支持到系统，请自行安装git。"
  fi
  echo "安装git成功"
fi

echo "开始使用git拉取adachi-bot..."
work_dir=$(pwd)
if [ -d "${work_dir}/Adachi-BOT" ]; then
  echo "adachi-bot已经存在，将在当前文件夹做备份."
  mv "Adachi-BOT" "Adachi-BOT-backup-$(date +%Y-%m-%d_%T)"
fi
git clone https://ghproxy.com/https://github.com/SilveryStar/Adachi-BOT.git --depth=1
echo "adachi-bot拉取成功."

# 安装jq解析json
echo "开始安装jq解析json..."
if ! type jq >/dev/null 2>&1; then
  if [ "$(uname)" == 'Darwin' ]; then
    if type brew >/dev/null 2>&1; then
      brew install jq
    elif type port >/dev/null 2>&1; then
      echo "使用MacPort安装jq，可能需要sudo权限。"
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
else
  echo "jq已安装"
fi

cd "Adachi-BOT/src/plugins"
echo "开始选择安装插件，回复编号选择(回复0结束选择,回复a全选)..."
plugins=$(curl -s 'https://source.hibennett.cn/bot/plugins.json')
i=1
for k in $(jq -r '.[]|.name' <<<"$plugins"); do
  echo "${i}) ${k}"
  ((i++))
done

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
      echo "${name}已下载，使用方式请访问 ${original_url}"
      use_plugins="all"
    done
    break
  fi
  if [[ "$inp" =~ " " ]]; then
    # shellcheck disable=SC2206
    arr=($inp)
    for m in "${arr[@]}"; do
      if [[ $((m)) > $i ]]; then
        echo "不存在${m}号插件."
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
      echo "${name}已下载，使用方式请访问 ${original_url}"
      use_plugins="${use_plugins}"" ${name}"
    done
    break
  fi
  if [[ $((inp)) > $i ]]; then
    echo "不存在${inp}号插件，如果你要一次多选请用空格隔开."
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
  echo "${name}已下载，使用方式请访问 ${original_url}"
  use_plugins="${use_plugins}"" ${name}"
done

if [ "${use_plugins}" ]; then
  echo "插件选择结束，你选择了:${use_plugins}"
else
  echo "插件选择结束，你未选择插件。"
fi

cd "${work_dir}"

echo "开始创建配置文件..."
if [ ! -d "${work_dir}/Adachi-BOT/config" ]; then mkdir -p "${work_dir}/Adachi-BOT/config"; fi
cd "${work_dir}/Adachi-BOT/config" && touch setting.yml commands.yml cookies.yml genshin.yml && cd "${work_dir}"

echo "请选择机器人登录平台(输入编号):"
select platform_str in "安卓手机" "安卓Pad" "安卓手表" "MacOS" "iPad"; do
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
  *)
    echo "你选择的登录平台编号非法."
    ;;
  esac
done
echo -n "请输入机器人的QQ号: "
read -r qq_num
echo "请选择登录方式: "
select login_type in "密码" "扫码"; do
  if [ $login_type == "密码" ]; then
    qq_password="$(ask Password)"
    qrcode=false
  else
    qrcode=true
    qq_password='""'
  fi
  break
done
echo -n "请输入机器人主人账号: "
read -r master_num
printf '获取米游社cookie方式:
将下面的代码复制并添加到一个书签中，书签名称自定义。然后在已登录的米游社网页中点击刚才的书签即可将cookie复制到剪切板中.
javascript:(function () {let domain = document.domain;let cookie = document.cookie;const text = document.createElement("textarea");text.hidden=true;text.value = cookie;document.body.appendChild(text);text.select();text.setSelectionRange(0, 99999);navigator.clipboard.writeText(text.value).then(()=>{alert("domain:"+domain+"\ncookie is in clipboard");});document.body.removeChild(text);})();
'
echo -n "请输入一个米游社cookie: "
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
dbPort: 56379
dbPassword: \"\"
webConsole:
  enable: false
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

echo "开始运行BOT..."
cd Adachi-BOT
if [ "${use_docker_plugin}" == "true" ]; then
  docker compose up -d --build
else
  docker-compose up -d --build
fi
printf "\t<============================BOT正在运行中,请稍等...============================>\n-) setting中基本上使用了默认配置(初次使用未开启webConsole)。\n-) 可在Adachi-BOT目录中使用docker compose down关闭服务，docker compose up -d启动服务。\n-) 可根据官方文档https://docs.adachi.top/config/#setting-yml重新设置你的配置，使用的指令可根据#help指令的结果对照在command.yml中修改。\n\t<======================以下是BOT服务的日志内容======================>"
printf "\n\n使用CTRL+C组合键即可结束日志查看...\n"

docker logs -f adachi-bot
