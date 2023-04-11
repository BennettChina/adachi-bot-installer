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

if [ "$(uname)" != 'Darwin' ]; then echo '不支持的操作系统!'; fi

printf "===============================================================================
\t 本脚本将为您在您的Mac上安装以下软件:
\t 1) xcode-select: Homebrew依赖此工具
\t 2) Homebrew: 一个macOS系统的包管理工具
\t 3) nodejs: JavaScript 运行环境
\t 4) Adachi-BOT: 开源项目https://github.com/SilveryStar/Adachi-BOT
\t 5) redis: 一个高速缓存数据库
==============================================================================="

printf "安装xcode-select"
if ! type xcode-select >/dev/null 2>&1; then
  xcode-select --install
  printf "xcode-select安装完成"
else
  printf "xcode-select已安装"
fi

# 添加brew的镜像地址环境变量
echo '
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
' >>"$HOME/.zprofile"
source "$HOME/.zprofile"

# 从镜像下载安装脚本并安装 Homebrew
printf "开始安装Homebrew"
if ! type brew >/dev/null 2>&1; then
  git clone --depth=1 https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/install.git brew-install
  /bin/bash brew-install/install.sh
  rm -rf brew-install

  if [ "$(uname -m)" == "arm64" ]; then
    # shellcheck disable=SC2016
    test -r "$HOME/.bash_profile" && echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.bash_profile"
    # shellcheck disable=SC2016
    test -r "$HOME/.zprofile" && echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
  fi
  printf "Homebrew安装完成"
else
  printf "Homebrew已安装."
fi

# 安装nodejs
echo '安装nodejs开始'
if ! type node >/dev/null 2>&1; then
  curl -o- https://ghproxy.com/https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  if [ -x "$(command -v nvm)" ]; then
    nvm use 14
  else
    brew install node@14
  fi
  echo '安装nodejs完成'
else
  echo 'nodejs已安装'
fi
npm config set registry https://registry.npmmirror.com

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
brew install redis
mv "/usr/local/etc/redis.conf" "/usr/local/etc/redis.conf.bak"
database="${work_dir}/database"
cp "redis.conf" "/usr/local/etc/redis.conf"
if [ ! -d "${database}" ]; then
  mkdir -p "${database}"
fi
sed -i "" "s|dir /data/|dir ${database}|" "/usr/local/etc/redis.conf"
printf "\ndaemonize yes" >>"/usr/local/etc/redis.conf"
redis-server /usr/local/etc/redis.conf
echo '安装redis完成'

# 安装jq解析json
if ! type jq >/dev/null 2>&1; then
  brew install jq
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
  if [[ "$inp" =~ " " ]]; then
    # shellcheck disable=SC2206
    arr=($inp)
    for m in "${arr[@]}"; do
      if [[ $m -gt $i ]]; then
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
  if [[ $inp -gt $i ]]; then
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

jwt_secret=$(LC_ALL=C tr -dc "[:alnum:]" </dev/urandom | head -c 16)

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
  sendDelay: 5" >"${work_dir}/config/setting.yml"

echo "cookies:
  - ${mys_cookie}" >"${work_dir}/config/cookies.yml"

echo "cardWeaponStyle: normal
cardProfile: random
serverPort: 58612" >"${work_dir}/config/genshin.yml"

echo "正在为您安装依赖..."
npm i
npm i pm2 -g
echo "依赖已完成安装，将为您启动服务..."

# 重新设置文件的用户组，让非ROOT用户后续自行修改文件不需要提权
if [ "$SUDO_USER" ]; then
  sudo chown -R "$(id -u "$SUDO_USER")":"$(id -u "$SUDO_USER")" .
else
  sudo chown -R "$(id -u "$USER")":"$(id -u "$USER")" .
fi

npm start
pm2 log
