#!/bin/bash
# android ubuntu
# 2022年4月16日

# 安装nodejs
echo '安装nodejs开始';
if ! type node >/dev/null 2>&1; then
  wget https://deb.nodesource.com/setup_14.x -O - | bash -
  apt-get install -y nodejs
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

# 安装并运行redis
echo '安装redis开始';
apt-get install redis -y
redis-server $(pwd)/redis.conf
echo '安装redis完成';

echo '安装模块开始';
if [ ! -d "node_modules/" ];then
  npm install
  echo '安装模块完成'
else
  echo '安装模块完成'
fi

echo '安装成功';