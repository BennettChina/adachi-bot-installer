#!/bin/bash

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

set -e

if [ "$(uname)" != 'Linux' ] && [ "$(uname)" != 'Darwin' ]; then echo '不支持的操作系统!'; fi

echo "the script will do:
1. install docker and docker-compose and git.(skip when installed)
2. use git clone SilveryStar/Adachi-BOT.
3. create configuration files.
4. run adachi-bot and redis in docker.
"

if [ -x "$(command -v docker)" ]; then
	echo "docker已经安装，跳过！"
elif [ "$(uname)" == 'Darwin' ]; then
  echo "请自行安装docker后再使用该脚本, docker下载地址: https://www.docker.com/get-started"
  exit 1
else
	echo "安装docker中..."
	wget https://get.docker.com -O - | bash -s docker --mirror Aliyun
	mkdir -p /etc/docker && touch /etc/docker/daemon.json
	echo '{
  "registry-mirrors" : [
    "https://ajxzc7hl.mirror.aliyuncs.com",
    "https://registry.docker-cn.com",
    "http://docker.mirrors.ustc.edu.cn",
    "http://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ],
  "debug" : true,
  "experimental" : true
}' > /etc/docker/daemon.json
	systemctl start docker
	echo "安装docker成功！"
fi

if [ -x "$(command -v docker-compose)" ]; then
	echo "docker-compose已经安装, 跳过!"
elif [ "$(uname)" == 'Darwin' ]; then
  docker compose version
  if [ "$?" != "0" ]; then
    echo "Docker Desktop版本太低，请更新后再使用本脚本!"
    exit 1
  fi
else
	echo "安装docker-compose中..."
	wget "https://ghproxy.com/https://github.com/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -O "/usr/local/bin/docker-compose"
	if [ ! -f "/usr/local/bin/docker-compose" ] || [ "$(ls -l /usr/local/bin/docker-compose | awk '{print $5}')" -lt 10000000 ]; then
		# 尝试从daocloud镜像源再次下载
		echo "从github下载docker-compose失败，将从镜像地址重试。"
		wget "https://get.daocloud.io/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -O "/usr/local/bin/docker-compose"
	fi
	chmod +x /usr/local/bin/docker-compose
	ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

os=$(cat /etc/*release | grep ^NAME | tr -d 'NAME="') > /dev/null 2>&1

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
	      echo 'FreeBSD: {
                url: "pkg+http://mirrors.ustc.edu.cn/freebsd-pkg/${ABI}/quarterly",
              }' > "/usr/local/etc/pkg/repos/FreeBSD.conf"
	  fi
	  pkg install -y git
	elif [ -x "$(command -v dnf)" ]; then
	  dnf install -y git
	elif [ -x "$(command -v pacman)" ]; then
	  pacman -S git
	elif [ -x "$(command -v emerge)" ]; then
	  emerge --verbose dev-vcs/git
	elif [ -x "$(command -v zypper)" ]; then
	  zypper install git
	elif [ -x "$(command -v urpmi)" ]; then
	  urpmi git
	elif [ -x "$(command -v nix-env)" ]; then
	  nix-env -i git
	elif [ -x "$(command -v pkgutil)" ]; then
	  pkgutil -i git
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

echo "开始选择安装插件，回复编号选择(回复all选择全部,回复0结束选择)..."
cd "Adachi-BOT/src/plugins"
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
      use_analysis_plugin=true
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
      use_analysis_plugin=true
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
      echo "插件选择结束，你选择了${use_plugins}"
      break
    ;;
  esac
done
cd "${work_dir}"

echo "开始创建配置文件..."
if [ ! -d "${work_dir}/Adachi-BOT/config" ]; then mkdir -p ${work_dir}/Adachi-BOT/config; fi
cd  ${work_dir}/Adachi-BOT/config && touch setting.yml commands.yml cookies.yml genshin.yml && cd ${work_dir}


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

if [ "$(uname)" == 'Darwin' ]; then
  jwt_secret=$(LC_ALL=C tr -dc "[:alnum:]" < /dev/urandom | head -c 16)
else
  jwt_secret="$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 16 | head -n 1)"
fi

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
addFriend: true"  >  ${work_dir}/Adachi-BOT/config/setting.yml

echo "cookies:
  - ${mys_cookie}"  >  ${work_dir}/Adachi-BOT/config/cookies.yml


echo "cardWeaponStyle: normal
cardProfile: random
serverPort: 58612"  >  ${work_dir}/Adachi-BOT/config/genshin.yml

#优化Dockerfile
if [ "${use_analysis_plugin}" == true ]; then
	echo "FROM silverystar/centos-puppeteer-env

ENV LANG en_US.utf8
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && yum install -y git && npm config set registry https://registry.npmmirror.com && mkdir -p /usr/share/fonts/chinese && chmod -R 755 /usr/share/fonts/chinese && curl -L -# \"https://source.hibennett.cn/MiSans-Light.ttf\" -o \"/usr/share/fonts/chinese/MiSans-Light.ttf\" && cd /usr/share/fonts/chinese && mkfontscale

COPY . /bot
WORKDIR /bot
RUN npm i puppeteer --unsafe-perm=true --allow-root
CMD nohup sh -c \"npm i && npm run docker-start\"" > ${work_dir}/Adachi-BOT/Dockerfile
fi

echo "开始运行BOT..."
cd Adachi-BOT
docker-compose up -d --build
echo "\t<============================BOT正在运行中,请稍等...============================>\n-) setting中基本上使用了默认配置(初次使用未开启webConsole)。\n-) 可在Adachi-BOT目录中使用docker-compose down关闭服务，docker-compose up -d启动服务。\n-) 可根据官方文档https://docs.adachi.top/config/#setting-yml重新设置你的配置，使用的指令可根据#help指令的结果对照在command.yml中修改。\n\t<======================以下是BOT服务的日志内容======================>"
echo "使用CTRL+C组合键即可结束日志查看."

docker logs -f adachi-bot
