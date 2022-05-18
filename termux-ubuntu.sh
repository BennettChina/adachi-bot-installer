#!/bin/bash
# android ubuntu
# 2022年4月16日

ask() {
    char_count='0'
    prompt="${1}: "
    reply=''
    while IFS='' read -n '1' -p "${prompt}" -r -s 'char'
    do
        case "${char}" in
            # Handles NULL
            ( $'\000' )
            break
            ;;
            # Handles BACKSPACE and DELETE
            ( $'\010' | $'\177' )
            if (( char_count > 0 )); then
                prompt=$'\b \b'
                reply="${reply%?}"
                (( char_count-- ))
            else
                prompt=''
            fi
            ;;
            ( * )
            prompt='*'
            reply+="${char}"
            (( char_count++ ))
            ;;
        esac
    done
    printf '\n' >&2
    printf '%s\n' "${reply}"
}

# 安装nodejs
echo '安装nodejs开始';
if ! type node >/dev/null 2>&1; then
  wget https://deb.nodesource.com/setup_14.x -O - | bash -
  apt-get install -y nodejs
  npm config set registry https://registry.npmmirror.com
else
  echo 'nodejs已安装';
fi
echo '安装nodejs完成';

# 安装chromium
echo '安装redis开始';
apt install chromium-browser -y
echo '安装chromium完成';

# 安装中文字体
echo '安装中文字体开始';
apt install -y --force-yes --no-install-recommends fonts-wqy-microhei
echo '安装中文字体完成';

# 安装git
echo '安装git开始';
apt install git -y
echo '安装git完成';

# 克隆项目
echo '克隆Adachi-BOT开始';
if [ ! -d "Adachi-BOT/" ];then
  git clone https://ghproxy.com/https://github.com/SilveryStar/Adachi-BOT.git
  if [ ! -d "Adachi-BOT/" ];then
    echo "克隆失败"
    exit 1
  else
    echo '克隆完成'
  fi
else
  echo '克隆完成'
fi

cd Adachi-BOT
work_dir=$(pwd)

# 安装并运行redis
echo '安装redis开始';
apt-get install redis -y
mv "/etc/redis/redis.conf" "/etc/redis/redis.conf.bak"
database="${work_dir}/database"
cp "redis.conf" "/etc/redis/redis.conf"
if [ ! -d "${database}" ]; then
    mkdir -p "${database}"
fi
sed -i "s|dir /data/|dir ${database}|" "/etc/redis/redis.conf"
echo "daemonize yes" >> "/etc/redis/redis.conf"
redis-server /etc/redis/redis.conf
echo '安装redis完成';

echo "开始选择安装插件，回复编号选择(回复all选择全部,回复0结束选择)..."
cd "src/plugins"
use_plugins=""
select plugin in "音乐插件" "抽卡分析" "圣遗物评分" "聊天插件" "搜图插件" "设置入群欢迎词插件" "热点新闻订阅插件"; do
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
    "圣遗物评分")
      git clone https://ghproxy.com/https://github.com/wickedll/genshin_rating.git --depth=1
      use_plugins="${use_plugins} "" [圣遗物评分插件]"
      echo "圣遗物评分插件已下载，使用方式请访问 https://github.com/wickedll/genshin_rating"
    ;;
    "聊天插件")
      git clone https://ghproxy.com/https://github.com/Extrwave/Chat-Plugins.git --depth=1
      use_plugins="${use_plugins} "" [聊天插件]"
      echo "聊天插件已下载，使用方式请访问 https://github.com/Extrwave/Chat-Plugins"
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
      git clone https://ghproxy.com/https://github.com/wickedll/genshin_rating.git --depth=1
      echo "圣遗物评分插件已下载，使用方式请访问 https://github.com/wickedll/genshin_rating"
      git clone https://ghproxy.com/https://github.com/Extrwave/Chat-Plugins.git --depth=1
      echo "聊天插件已下载，使用方式请访问 https://github.com/Extrwave/Chat-Plugins"
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
cd "${work_dir}"

echo "开始创建配置文件..."
if [ ! -d "${work_dir}/config" ]; then mkdir -p ${work_dir}/config; fi
cd  ${work_dir}/config && touch setting.yml commands.yml cookies.yml genshin.yml && cd ${work_dir}


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
echo '获取米游社cookie方式:
将下面的代码复制并添加到一个书签中，书签名称自定义。然后在已登录的米游社网页中点击刚才的书签即可将cookie复制到剪切板中.
javascript:(function () {let domain = document.domain;let cookie = document.cookie;const text = document.createElement("textarea");text.hidden=true;text.value = cookie;document.body.appendChild(text);text.select();text.setSelectionRange(0, 99999);navigator.clipboard.writeText(text.value).then(()=>{alert("domain:"+domain+"\ncookie is in clipboard");});document.body.removeChild(text);})();
'
read -p "请输入一个米游社cookie: " mys_cookie

jwt_secret="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)"

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
addFriend: true"  >  ${work_dir}/config/setting.yml

echo "cookies:
  - ${mys_cookie}"  >  ${work_dir}/config/cookies.yml

echo "cardWeaponStyle: normal
cardProfile: random
serverPort: 58612"  >  ${work_dir}/config/genshin.yml

echo "正在为您安装依赖..."
npm i
npm i pm2 -g
echo "依赖已完成安装，将为您启动服务..."
npm start
pm2 log