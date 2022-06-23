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
echo "daemonize yes" >>"/usr/local/etc/redis.conf"
redis-server /usr/local/etc/redis.conf
echo '安装redis完成'

echo "开始选择安装插件，回复编号选择(回复0结束选择)..."
cd "src/plugins" || {
  echo "BOT项目结构发生变化或者未完整克隆，可在GitHub中提交issue提醒脚本作者更新!"
  exit 1
}
use_plugins=""
select plugin in "all" "音乐插件" "抽卡分析" "云原神签到插件" "圣遗物评分" "搜图插件" "设置入群欢迎词插件" "热点新闻订阅插件"; do
  case $plugin in
  "音乐插件")
    git clone -b music https://ghproxy.com/https://github.com/SilveryStar/Adachi-Plugin.git --depth=1 music
    use_plugins="${use_plugins} ""[音乐插件]"
    echo "音乐插件已下载，使用方式请访问 https://github.com/SilveryStar/Adachi-Plugin/tree/music"
    ;;
  "抽卡分析")
    git clone https://ghproxy.com/https://github.com/wickedll/genshin_draw_analysis.git --depth=1
    use_plugins="${use_plugins}"" [抽卡分析插件]"
    echo "抽卡分析插件已下载，使用方式请访问 https://github.com/wickedll/genshin_draw_analysis"
    ;;
  "云原神签到插件")
    git clone https://ghproxy.com/https://github.com/Extrwave/cloud_genshin.git --depth=1
    use_plugins="${use_plugins}"" [云原神签到插件]"
    echo "云原神签到插件已下载，使用方式请访问 https://github.com/Extrwave/cloud_genshin"
    ;;
  "圣遗物评分")
    git clone https://ghproxy.com/https://github.com/wickedll/genshin_rating.git --depth=1
    use_plugins="${use_plugins} "" [圣遗物评分插件]"
    echo "圣遗物评分插件已下载，使用方式请访问 https://github.com/wickedll/genshin_rating"
    ;;
  "搜图插件")
    git clone https://ghproxy.com/https://github.com/MarryDream/pic_search.git --depth=1
    use_plugins="${use_plugins} "" [搜图插件]"
    echo "搜图插件已下载，使用方式请访问 https://github.com/MarryDream/pic_search"
    ;;
  "设置入群欢迎词插件")
    git clone https://ghproxy.com/https://github.com/BennettChina/group_helper.git --depth=1
    use_plugins="${use_plugins} "" [设置入群欢迎词插件]"
    echo "设置入群欢迎词插件已下载，使用方式请访问 https://github.com/BennettChina/group_helper"
    ;;
  "热点新闻订阅插件")
    git clone https://ghproxy.com/https://github.com/BennettChina/hot-news.git --depth=1
    use_plugins="${use_plugins} "" [热点新闻订阅插件]"
    echo "热点新闻订阅插件已下载，使用方式请访问 https://github.com/BennettChina/hot-news"
    ;;
  "all")
    git clone -b music https://ghproxy.com/https://github.com/SilveryStar/Adachi-Plugin.git --depth=1 music
    echo "音乐插件已下载，使用方式请访问 https://github.com/SilveryStar/Adachi-Plugin/tree/music"
    git clone https://ghproxy.com/https://github.com/wickedll/genshin_draw_analysis.git --depth=1
    echo "抽卡分析插件已下载，使用方式请访问 https://github.com/wickedll/genshin_draw_analysis"
    git clone https://ghproxy.com/https://github.com/Extrwave/cloud_genshin.git --depth=1
    echo "云原神签到插件已下载，使用方式请访问 https://github.com/Extrwave/cloud_genshin"
    git clone https://ghproxy.com/https://github.com/wickedll/genshin_rating.git --depth=1
    echo "圣遗物评分插件已下载，使用方式请访问 https://github.com/wickedll/genshin_rating"
    git clone https://ghproxy.com/https://github.com/MarryDream/pic_search.git --depth=1
    echo "搜图插件已下载，使用方式请访问 https://github.com/MarryDream/pic_search"
    git clone https://ghproxy.com/https://github.com/BennettChina/group_helper.git --depth=1
    echo "设置入群欢迎词插件已下载，使用方式请访问 https://github.com/BennettChina/group_helper"
    git clone https://ghproxy.com/https://github.com/BennettChina/hot-news.git --depth=1
    echo "热点新闻订阅插件已下载，使用方式请访问 https://github.com/BennettChina/hot-news"
    echo "已为你下载全部插件!"
    break
    ;;
  *)
    if [ "${use_plugins}" ]; then
      echo "插件选择结束，你选择了${use_plugins}"
      break
    fi
    echo "插件选择结束，你未选择插件!"
    break
    ;;
  esac
done
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
read -p "请输入机器人的QQ号: " qq_num
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
read -p "请输入机器人主人账号: " master_num
printf '获取米游社cookie方式:
将下面的代码复制并添加到一个书签中，书签名称自定义。然后在已登录的米游社网页中点击刚才的书签即可将cookie复制到剪切板中.
javascript:(function () {let domain = document.domain;let cookie = document.cookie;const text = document.createElement("textarea");text.hidden=true;text.value = cookie;document.body.appendChild(text);text.select();text.setSelectionRange(0, 99999);navigator.clipboard.writeText(text.value).then(()=>{alert("domain:"+domain+"\ncookie is in clipboard");});document.body.removeChild(text);})();
'
read -p "请输入一个米游社cookie: " mys_cookie

jwt_secret=$(LC_ALL=C tr -dc "[:alnum:]" < /dev/urandom | head -c 16)

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
addFriend: true
autoChat: false" >"${work_dir}/config/setting.yml"

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
