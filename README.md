# adachi-bot-installer

[SilveryStar/Adachi-BOT](https://github.com/SilveryStar/Adachi-BOT)
的一键部署脚本，不包含签名服务的部署（只有Docker模式会使用项目的 `docker-compose.yml` 自动启动签名服务。），所以部署前如果不用
Docker 需要自行先部署一套签名服务。

指路👉[unidbg-fetch-qsign/wiki](https://github.com/fuqiuluo/unidbg-fetch-qsign/wiki)

## Linux

`Linux`环境可以直接执行下面的命令，将通过安装`Docker`、`docker-compose`的方式运行BOT。不想使用 `Docker`
启动的方式可以使用 [安装BOT的脚本](#安装BOT的脚本)
这个脚本安装，这个脚本将在物理机安装 `nodejs`、`redis`、`chrome`等

```sh
sudo bash <(curl -L -# https://ghproxy.com/https://raw.githubusercontent.com/BennettChina/adachi-bot-installer/main/unix-docker-install.sh)
```

## macOS

### Docker 模式安装（推荐）

`macOS`如果用Docker模式需要自行安装`docker`(
最好是比较新的版本，因为自带了`docker-compose`)，[docker下载地址](https://www.docker.com/get-started) 。

```shell
bash <(curl -L -# https://ghproxy.com/https://raw.githubusercontent.com/BennettChina/adachi-bot-installer/main/unix-docker-install.sh)
```

### 非 Docker 模式安装

不使用Docker模式可以使用下面的命令安装

```shell
bash <(curl -L -# https://ghproxy.com/https://raw.githubusercontent.com/BennettChina/adachi-bot-installer/main/macos-install.sh)
```

这种方式不是很推荐，因为会给你安装好几个软件(`xcode-select`, `homebrew`,`nodejs`,`redis`, `Adachi-BOT`)，容易给你的环境搞乱。

## Windows

`Windows`环境可以使用下面的命令，需要以管理员的权限打开`PowerShell`，然后`cd 你想要安装的目录路径`再输入下面的命令并运行。

常见问题：

- 如果遇到 `ghproxy.com` 无法解析的问题可尝试在浏览器访问 https://ghproxy.com
- node、git等软件下载失败，可以重新运行脚本重试
- `node_module`可能安装失败，比如`puppeteer`可能会安装失败，此时可以使用`npm i`重新安装，然后`npm start`启动服务。
- `docker`环境由于测试时的网络问题下载软件失败暂时未测试，有问题提issue反馈。
- 系统禁止运行脚本，可使用 `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force` 然后在执行命令。

```powershell
iwr "https://ghproxy.com/https://raw.githubusercontent.com/BennettChina/adachi-bot-installer/main/win-install.ps1" -O .\adachi_bot_install.ps1; .\adachi_bot_install.ps1; rm .\adachi_bot_install.ps1
```

## Android

使用 `termux` [App](https://github.com/termux/termux-app) 来安装(可以通过 `F-Droid`
来[下载](https://f-droid.org/en/packages/com.termux/) 安装)，参考[云崽BOT](https://github.com/Le-niao/Yunzai-Bot)
的安卓安装方式。

下载完 `termux` 后执行 `pkg install proot git python -y`

### 安装Linux系统

使用[国光大佬](https://github.com/sqlsec/termux-install-linux) 提供的Linux系统安装脚本安装一个Linux系统（虽然 `termux`
自身就是Linux环境，但毕竟是模拟的，还是需要真正的Linux环境才能安装上BOT ）

```shell
git clone https://ghproxy.com/https://github.com/sqlsec/termux-install-linux
cd termux-install-linux
python termux-linux-install.py
```

安装后启动系统，比如 `Ubuntu` 的系统

```shell
cd ~/Termux-Linux/Ubuntu
./start-ubuntu.sh
```

### 安装BOT的脚本

启动系统后再执行下面的命令(脚本暂时只支持 `Ubuntu`、`Debian`、`Centos`
，除已选择的配置其他均使用的都是官方的默认配置，可根据 [官方文档](https://docs.adachi.top/config/)
自定义配置)

```shell
wget https://ghproxy.com/https://raw.githubusercontent.com/BennettChina/adachi-bot-installer/main/linux-install.sh -O linux-install.sh && sudo bash linux-install.sh && rm linux-install.sh
```

## 感谢

- 感谢[daocloud](https://get.daocloud.io/#install-compose)提供的镜像加速.
- 感谢[GithubProxy](https://ghproxy.com/)提供的镜像加速.
- 参考了[pcrbot/hoshino-installer](https://github.com/pcrbot/hoshino-installer)的脚本写法.
- 感谢[Termux](https://github.com/termux/termux-app)提供的软件
- 感谢[国光](https://github.com/sqlsec/termux-install-linux)大佬提供的Termux安装Linux系统脚本
