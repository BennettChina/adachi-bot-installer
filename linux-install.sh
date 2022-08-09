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

if [ "$(uname)" != 'Linux' ]; then echo '不支持的操作系统!'; fi

if [ $EUID -ne 0 ]; then
  echo "请使用root账号运行该脚本！"
  exit 1
fi

os=$(cat /etc/*release | grep ^NAME | tr -d 'NAME="' | tr '[:upper:]' '[:lower:]') >/dev/null 2>&1
# 安装nodejs
echo '安装nodejs开始'
if ! type node >/dev/null 2>&1; then
  if [[ "$os" == ubuntu* || "$os" == debian* ]]; then
    wget https://deb.nodesource.com/setup_14.x -O - | bash -
    apt-get install -y nodejs
  elif [[ "$os" == centos* ]]; then
    wget https://rpm.nodesource.com/setup_14.x -O - | bash -
    yum install -y nodejs
  fi
else
  echo 'nodejs已安装'
fi
npm config set registry https://registry.npmmirror.com
echo '安装nodejs完成'

# 安装chromium
echo '安装chromium开始'
if [[ "$os" == ubuntu* || "$os" == debian* ]]; then
  apt install chromium-browser -y
elif [[ "$os" == centos* ]]; then
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
  dnf install google-chrome-stable_current_x86_64.rpm
fi
echo '安装chromium完成'

# 安装中文字体
echo '安装中文字体开始'
if [[ "$os" == ubuntu* || "$os" == debian* ]]; then
  apt install -y --force-yes --no-install-recommends fonts-wqy-microhei
  echo '安装中文字体完成'
elif [[ "$os" == centos* ]]; then
  yum -y install wqy-microhei-fonts
  rpm -qa | grep wqy-microhei-fonts &>/dev/null
  if "$?"; then
    echo "安装中文字体完成"
  else
    echo "中文字体安装失败,未找到该字体的可用源。"
  fi
fi

# 安装git
echo '安装git开始'
if [[ "$os" == ubuntu* || "$os" == debian* ]]; then
  apt install git -y
elif [[ "$os" == centos* ]]; then
  yum -y install git
fi
echo '安装git完成'

# 克隆项目
echo '克隆Adachi-BOT开始'
if [ ! -d "Adachi-BOT/" ]; then
  git clone https://ghproxy.com/https://github.com/SilveryStar/Adachi-BOT.git --depth=1
else
  echo '项目已存在'
fi

cd Adachi-BOT || {
  echo "克隆项目失败"
  exit 1
}
work_dir=$(pwd)

# 安装并运行redis
echo '安装redis开始'
if [[ "$os" == ubuntu* || "$os" == debian* ]]; then
  apt-get install redis -y
  mv "/etc/redis/redis.conf" "/etc/redis/redis.conf.bak"
  database="${work_dir}/database"
  cp "redis.conf" "/etc/redis/redis.conf"
  if [ ! -d "${database}" ]; then
    mkdir -p "${database}"
  fi
  sed -i "s|dir /data/|dir ${database}|" "/etc/redis/redis.conf"
  echo "daemonize yes" >>"/etc/redis/redis.conf"
  redis-server /etc/redis/redis.conf
elif [[ "$os" == centos* ]]; then
  yum install redis -y
  mv "/etc/redis.conf" "/etc/redis.conf.bak"
  database="${work_dir}/database"
  cp "redis.conf" "/etc/redis.conf"
  if [ ! -d "${database}" ]; then
    mkdir -p "${database}"
  fi
  sed -i "s|dir /data/|dir ${database}|" "/etc/redis.conf"
  echo "daemonize yes" >>"/etc/redis.conf"
  redis-server /etc/redis.conf
fi
echo '安装redis完成'

# 安装jq解析json
echo "开始安装jq解析json..."
if ! type jq >/dev/null 2>&1; then
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
else
  echo "jq已安装"
fi
cd "src/plugins" || {
  echo "BOT项目结构发生变化或者未完整克隆，可在GitHub中提交issue提醒脚本作者更新!"
  exit 1
}
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

cd "${work_dir}" || {
  echo "插件安装完成，退出插件目录失败"
  exit 1
}

echo "开始创建配置文件..."
if [ ! -d "${work_dir}/config" ]; then mkdir -p "${work_dir}/config"; fi
cd "${work_dir}/config" && touch setting.yml commands.yml cookies.yml genshin.yml && (cd "${work_dir}" || {
  echo "退出配置目录失败"
  exit 1
})

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
echo "请选择登录方式:"
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

jwt_secret="$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 16 | head -n 1)"

echo "qrcode: ${qrcode}
number: ${qq_num}
password: ${qq_password}
master: ${master_num}
header: \"#\"
platform: ${platform}
atUser: false
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
atBOT: false
addFriend: true" >"${work_dir}/config/setting.yml"

echo "cookies:
  - ${mys_cookie}" >"${work_dir}/config/cookies.yml"

echo "cardWeaponStyle: normal
cardProfile: random
serverPort: 58612" >"${work_dir}/config/genshin.yml"

echo "正在为您安装依赖..."
npm i
npm i pm2 -g
echo "依赖已完成安装，将为您启动服务..."
npm start
pm2 log
