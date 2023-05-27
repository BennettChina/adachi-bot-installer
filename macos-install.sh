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

if [ "$(uname)" != 'Darwin' ]; then echo -e "${RED}不支持的操作系统!${RESET}"; fi

printf "\n%b===============================================================================
\t 本脚本将为您在您的Mac上安装以下软件:
\t 1) xcode-select: Homebrew依赖此工具
\t 2) Homebrew: 一个macOS系统的包管理工具
\t 3) nodejs: JavaScript 运行环境
\t 4) Adachi-BOT: 开源项目https://github.com/SilveryStar/Adachi-BOT
\t 5) redis: 一个高速缓存数据库
===============================================================================%b\n" "${GREEN}" "${RESET}"

echo -e "\n${GREEN}安装xcode-select...${RESET}\n"
if ! type xcode-select >/dev/null 2>&1; then
  xcode-select --install
  echo -e "\n${GREEN}xcode-select安装完成.${RESET}\n"
else
  echo -e "\n${CYAN}xcode-select已安装.${RESET}\n"
fi

# 添加brew的镜像地址环境变量
echo '
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
' >>"$HOME/.zprofile"
source "$HOME/.zprofile"

# 从镜像下载安装脚本并安装 Homebrew
printf "\n%b开始安装Homebrew%b\n" "${GREEN}" "${RESET}"
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
  printf "\n%bHomebrew安装完成%b\n" "${GREEN}" "${RESET}"
else
  printf "\n%bHomebrew已安装.%b\n" "${CYAN}" "${RESET}"
fi

# 安装nodejs
printf '\n%b安装nodejs开始%b\n' "${GREEN}" "${RESET}"
if ! type node >/dev/null 2>&1; then
  curl -o- https://ghproxy.com/https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  if [ -x "$(command -v nvm)" ]; then
    nvm use 14
  else
    brew install node@14
  fi
  printf '\n%b安装nodejs完成%b\n' "${GREEN}" "${RESET}"
else
  printf '\n%bnodejs已安装%b\n' "${CYAN}" "${RESET}"
fi
npm config set registry https://registry.npmmirror.com

# 克隆项目
printf '\n%b克隆Adachi-BOT开始%b\n' "${GREEN}" "${RESET}"
if [ ! -d "Adachi-BOT/" ]; then
  git clone https://ghproxy.com/https://github.com/SilveryStar/Adachi-BOT.git --depth=1
else
  printf '\n%b项目已存在%b\n' "${YELLOW}" "${RESET}"
fi

cd Adachi-BOT || {
  printf "\n%b克隆项目失败%b\n" "${RED}" "${RESET}"
  exit 1
}
work_dir=$(pwd)

# 安装并运行redis
printf '\n%b安装redis开始 >>>%b\n' "${GREEN}" "${RESET}"
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
printf '\n%b安装redis完成 >>>%b\n' "${GREEN}" "${RESET}"

# 安装jq解析json
echo -e "${GREEN}开始安装jq解析json...${RESET}"
if ! type jq >/dev/null 2>&1; then
  brew install jq
  echo -e "${GREEN}jq安装完成...${RESET}"
else
  echo -e "${CYAN}jq已安装，开始解析...${RESET}"
fi

cd "src/plugins" || {
  printf "\n%bBOT项目结构发生变化或者未完整克隆，可在GitHub中提交issue提醒脚本作者更新!%b\n" "${RED}" "${RESET}"
  exit 1
}
printf "\n%b开始选择安装插件，回复编号选择(回复0结束选择,回复a全选)...%b\n" "${GREEN}" "${RESET}"
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
      echo -e "${GREEN}${name}${RESET}已下载，使用方式请访问 ${GREEN}${original_url}${RESET}"
      use_plugins="all"
    done
    break
  fi
  if [[ "$inp" =~ " " ]]; then
    # shellcheck disable=SC2206
    arr=($inp)
    for m in "${arr[@]}"; do
      if [[ $m -gt $len ]]; then
        echo -e "${RED}不存在${m}号插件.${RESET}"
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
      echo -e "${GREEN}${name}${RESET}已下载，使用方式请访问 ${GREEN}${original_url}${RESET}"
      use_plugins="${use_plugins}"" ${name}"
    done
    break
  fi
  if [[ $inp -gt $len ]]; then
    echo -e "${RED}不存在${inp}号插件，如果你要一次多选请用空格隔开.${RESET}"
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
  echo -e "${GREEN}${name}${RESET}已下载，使用方式请访问 ${GREEN}${original_url}${RESET}"
  use_plugins="${use_plugins}"" ${name}"
done

if [ "${use_plugins}" ]; then
  echo -e "${YELLOW}>>> 插件选择结束，你选择了:${RESET}${GREEN}${use_plugins}${RESET}"
else
  echo -e "${YELLOW}>>> 插件选择结束，你未选择插件。${RESET}"
fi
cd "${work_dir}" || {
  echo -e "${RED}插件安装完成，退出插件目录失败!${RESET}"
  exit 1
}

echo -e "\n==============\n${GREEN}开始创建配置文件${RESET}\n==============\n"
if [ ! -d "${work_dir}/config" ]; then mkdir -p "${work_dir}/config"; fi
cd "${work_dir}/config" && touch setting.yml commands.yml cookies.yml genshin.yml && (cd "${work_dir}" || {
  echo -e "${RED}退出配置目录失败!${RESET}"
  exit 1
})

echo -e "${YELLOW}请选择机器人登录平台(输入编号):${RESET}"
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
    echo -e "${RED}你选择的登录平台编号非法，重选！${RESET}"
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
  sendDelay: 5" >"${work_dir}/config/setting.yml"

echo "cookies:
  - ${mys_cookie}" >"${work_dir}/config/cookies.yml"

echo "cardWeaponStyle: normal
cardProfile: random
serverPort: 58612" >"${work_dir}/config/genshin.yml"

echo -e "\n${GREEN}==================== ↓ ↓ ↓ 正在为您安装依赖 ↓ ↓ ↓ ====================${RESET}\n"
npm i
npm i pm2 -g
echo -e "\n${GREEN}============= ↓ ↓ ↓ 依赖已完成安装，将为您启动服务 ↓ ↓ ↓ =============${RESET}\n"

# 重新设置文件的用户组，让非ROOT用户后续自行修改文件不需要提权
if [[ $EUID == 0 ]]; then
  if [ "$SUDO_USER" ]; then
    chown -R "$(id -u "$SUDO_USER")":"$(id -u "$SUDO_USER")" .
  else
    chown -R "$(id -u "$USER")":"$(id -u "$USER")" .
  fi
fi

npm start
pm2 log
