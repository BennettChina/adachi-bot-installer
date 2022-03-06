#!/bin/bash
set -e

if [ $EUID -ne 0 ]; then
	echo "Please run as root."
	exit
fi

echo "the script will do:
1. install docker and docker-compose.(skip when installed)
2. download SilveryStar/Adachi-BOT.
3. create configuration files.
4. run adachi-bot and redis in docker.
"

if [ -x "$(command -v docker)" ]; then
	echo "docker has installed, skip."
else
	echo "installing docker..."
	curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
	mkdir -p /etc/docker && touch /etc/docker/daemon.json
	echo '{
  "registry-mirrors" : [
    "https://ajxzc7hl.mirror.aliyuncs.com",
    "https://registry.docker-cn.com",
    "http://docker.mirrors.ustc.edu.cn",
    "http://hub-mirror.c.163.com"
  ],
  "debug" : true,
  "experimental" : true
}' > /etc/docker/daemon.json
	systemctl start docker
	echo "install docker success"
fi

if [ -x "$(command -v docker-compose)" ]; then
	echo "docker-compose has installed, skip."
else
	echo "installing docker-compose..."
	curl -L "https://github.com/docker/compose/releases/download/v2.3.0/docker-compose-$(uname -s)-$(uname -m)" -o "/usr/local/bin/docker-compose"
	if [ ! -f "/usr/local/bin/docker-compose" -o $(ls -l docker-compose | awk '{print $5}') -lt 10000000 ]; then
		# 尝试从daocloud镜像源再次下载
		echo "download github docker-compose faild, will retry from daocloud.io"
		curl -L 'https://get.daocloud.io/docker/compose/releases/download/v2.3.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose'
	fi
	chmod +x /usr/local/bin/docker-compose
	ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

echo "downloading adachi-bot..."

work_dir=$(pwd)
curl -O 'https://ghproxy.com/https://github.com/SilveryStar/Adachi-BOT/archive/refs/heads/master.zip'
unzip -q -o master.zip
rm -rf ${work_dir}/Adachi-BOT
mv ${work_dir}/Adachi-BOT-master ${work_dir}/Adachi-BOT 
rm -rf ${work_dir}/master.zip
ls "${work_dir}/Adachi-BOT" > /dev/null 2>&1
if [ $? -ne 0 ]; then echo "download adachi-bot faild."; exit; fi
echo "download adachi-bot success."


echo "create configuration files begin..."
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
echo "请选择登录方式(扫码方式目前有问题,二维码发不出来):"
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

jwt_secret="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
echo "${jwt_secret}"

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
"  >  ${work_dir}/Adachi-BOT/config/setting.yml

echo "cookies:
  - ${mys_cookie}
"  >  ${work_dir}/Adachi-BOT/config/cookies.yml


echo "cardWeaponStyle: normal
cardProfile: random
serverPort: 58612
"  >  ${work_dir}/Adachi-BOT/config/genshin.yml

#优化Dockerfile
echo "FROM silverystar/centos-puppeteer-env

ENV LANG en_US.utf8
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

WORKDIR /bot
COPY . /bot

CMD nohup sh -c \"cnpm install && npm start\"
"  >  ${work_dir}/Adachi-BOT/Dockerfile

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
      - 8848:80
    container_name: adachi-bot
    environment:
      docker: \"yes\"
    depends_on:
      - redis
    volumes:
      - ./config:/bot/config
      - ./logs:/bot/logs
      - ./src:/bot/src
      - ./package.json:/bot/package.json
"  >  ${work_dir}/Adachi-BOT/docker-compose.yml

echo "bot and redis run beginning..."
cd Adachi-BOT && docker-compose up -d --build
echo "bot and redis running..."

if [ $qrcode == "true" ]; then
	log_file=${work_dir}/Adachi-BOT/logs/bot.$(date +%Y-%m-%d).log
	
	#一直循环直到log文件已经创建
	while [ ! -f ${log_file} ]; do sleep 10s; done
	
	echo "扫码登录后使用CTRL+C组合键即可结束日志查看."
	tail -100f "${work_dir}/Adachi-BOT/logs/bot.$(date +%Y-%m-%d).log"
fi
