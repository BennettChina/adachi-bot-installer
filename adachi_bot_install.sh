#!/bin/bash
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
else
	echo "安装docker-compose中..."
	if [ "$(uname)" == 'Darwin' ]; then
	  curl -L "https://ghproxy.com/https://github.com/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -o "/usr/local/bin/docker-compose"
	else
	  wget "https://ghproxy.com/https://github.com/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -O "/usr/local/bin/docker-compose"
	fi
	if [ ! -f "/usr/local/bin/docker-compose" ] || [ "$(ls -l /usr/local/bin/docker-compose | awk '{print $5}')" -lt 10000000 ]; then
		# 尝试从daocloud镜像源再次下载
		echo "从github下载docker-compose失败，将从镜像地址重试。"
		if [ "$(uname)" == 'Darwin' ]; then
		  curl -L "https://get.daocloud.io/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -o "/usr/local/bin/docker-compose"
		else
		  wget "https://get.daocloud.io/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -O "/usr/local/bin/docker-compose"
		fi
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

echo "开始选择安装插件，回复编号选择(回复0结束选择)..."
cd "Adachi-BOT/src/plugins"
use_plugins=""
select plugin in "音乐插件" "抽卡分析" "圣遗物评分"; do
  case $plugin in
    "音乐插件")
      git clone -b music https://ghproxy.com/https://github.com/SilveryStar/Adachi-Plugin.git --depth=1 music
      use_plugins="${use_plugins} ""[音乐插件]"
      echo "音乐插件已下载，使用方式请访问 https://github.com/SilveryStar/Adachi-Plugin/tree/music"
    ;;
    "抽卡分析")
      git clone https://ghproxy.com/https://github.com/wickedll/genshin_draw_analysis.git --depth=1
      use_plugins="${use_plugins}"" [抽卡分析插件]"
      # 下载插件需要的中文字体,此处使用小米的MiSans-Light字体
      mkdir -p "${work_dir}/Adachi-BOT/font"
      echo "开始下载插件需要的中文字体..."
      if [ "$(uname)" == 'Darwin' ]; then
        curl -L "https://source.hibennett.cn/MiSans-Light.ttf" -o "${work_dir}/Adachi-BOT/font/MiSans-Light.ttf"
      else
        wget "https://source.hibennett.cn/MiSans-Light.ttf" -O "${work_dir}/Adachi-BOT/font/MiSans-Light.ttf"
      fi
      use_analysis_plugin=true
      echo "抽卡分析插件已下载，使用方式请访问 https://github.com/wickedll/genshin_draw_analysis"
    ;;
    "圣遗物评分")
      git clone https://ghproxy.com/https://github.com/wickedll/genshin_rating.git --depth=1
      use_plugins="${use_plugins} "" [圣遗物评分插件]"
      echo "抽卡分析插件已下载，使用方式请访问 https://github.com/wickedll/genshin_rating"
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
		 read -p "请输入机器人的密码: " qq_password
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
webConsole:
  enable: true
  consolePort: 80
  tcpLoggerPort: 54921
  jwtSecret: ${jwt_secret}
atBOT: false
addFriend: false"  >  ${work_dir}/Adachi-BOT/config/setting.yml

echo "cookies:
  - ${mys_cookie}"  >  ${work_dir}/Adachi-BOT/config/cookies.yml


echo "cardWeaponStyle: normal
cardProfile: random
serverPort: 58612"  >  ${work_dir}/Adachi-BOT/config/genshin.yml

npm_param="start"
if [ "${qrcode}" == true ]; then
  npm_param="run login"
fi

#优化Dockerfile
if [ "${use_analysis_plugin}" != true ]; then

	echo "FROM silverystar/centos-puppeteer-env

ENV LANG en_US.utf8
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

WORKDIR /bot
COPY . /bot

CMD nohup sh -c \"cnpm install && npm ${npm_param}\""  >  ${work_dir}/Adachi-BOT/Dockerfile
else
	echo "FROM silverystar/centos-puppeteer-env

#设置容器内的字符集,处理header为中文时乱码问题
ENV LANG en_US.utf8
#设置时区、创建字体文件夹
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && mkdir -p /usr/share/fonts/chinese && chmod -R 755 /usr/share/fonts/chinese
#将字体拷贝到容器内(字体文件名可修改为你使用的字体)
COPY font/MiSans-Light.ttf /usr/share/fonts/chinese
#扫描字体并进行索引
RUN cd /usr/share/fonts/chinese && mkfontscale

WORKDIR /bot
COPY . /bot

CMD nohup sh -c \"cnpm install && npm ${npm_param}\"" > ${work_dir}/Adachi-BOT/Dockerfile
fi

#优化docker-compose.yml
echo "version: \"3.7\"
services:
  redis:
    image: redis:6.2.3
    container_name: adachi-redis
    environment:
      - TZ=Asia/Shanghai
    restart: always
    command: redis-server /usr/local/etc/redis/redis.conf
    volumes:
      - ./database:/data
      - ./redis.conf:/usr/local/etc/redis/redis.conf
  bot:
    build:
      context: .
    image: adachi-bot:latest
    ports:
      - 80:80
    container_name: adachi-bot
    environment:
      docker: \"yes\"
    depends_on:
      - redis
    volumes:
      - ./config:/bot/config
      - ./logs:/bot/logs
      - ./src:/bot/src
      - ./package.json:/bot/package.json"  >  ${work_dir}/Adachi-BOT/docker-compose.yml

echo "开始运行BOT..."
cd Adachi-BOT
if [ "${qrcode}" != true ]; then
  docker-compose up -d --build
else
  # 扫码方式启动
  echo 'ticket请输入到控制台后「回车」即可，账号登录成功后CTRL+C结束并手动运行cd Adachi-BOT && docker-compose down && docker-compose up -d --build'
  # 将登录替换启动
  docker-compose build
  if [ "$(uname)" == 'Darwin' ]; then
    sed -i '' 's/run login/start/' "${work_dir}/Adachi-BOT/Dockerfile"
  else
    sed -i 's/run login/start/' "${work_dir}/Adachi-BOT/Dockerfile"
  fi
  docker-compose up --no-build
  exit 0
fi
echo "BOT正在运行中,请稍等..."

log_file=${work_dir}/Adachi-BOT/logs/bot.$(date +%Y-%m-%d).log

#一直循环直到log文件已经创建
while [ ! -f ${log_file} ]; do sleep 10s; done

echo "\t<============================服务已启动============================>\n-) setting中使用了默认配置。\n-) 可在Adachi-BOT目录中使用docker-compose down关闭服务，docker-compose up -d启动服务。\n-) 可根据官方文档https://docs.adachi.top/config/#setting-yml重新设置你的配置，使用的指令可根据#help指令的结果对照在command.yml中修改。\n\t<======================以下是BOT服务的日志内容======================>"

echo "使用CTRL+C组合键即可结束日志查看."
tail -100f "${work_dir}/Adachi-BOT/logs/bot.$(date +%Y-%m-%d).log"
