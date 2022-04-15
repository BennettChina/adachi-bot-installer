# adachi-bot-installer
[SilveryStar/Adachi-BOT](https://github.com/SilveryStar/Adachi-BOT)的一键部署脚本

## Linux/macOS

`Linux`环境可以直接执行下面的命令，将通过安装`Docker`、`docker-compose`的方式运行BOT，`macOS`需要自行安装`docker`(最好是比较新的版本，因为自带了`docker-compose`)，[docker下载地址](https://www.docker.com/get-started) 。

```sh
wget https://cdn.jsdelivr.net/gh/BennettChina/adachi-bot-installer@main/adachi_bot_install.sh -O adachi_bot_install.sh && sudo bash adachi_bot_install.sh && rm adachi_bot_install.sh
```

## Windows

`Windows`环境可以使用下面的命令，需要以管理员的权限打开`PowerShell`，然后输入下面的命令并运行，**注意：运行后窗口不可关闭！！！**

常见问题：

- node、git等软件下载失败，可以重新运行脚本重试
- `node_module`可能安装失败，比如`puppeteer`可能会安装失败，此时可以使用`npm i`重新安装，然后`npm start`启动服务。
- `docker`环境由于测试时的网络问题下载软件失败暂时未测试，有问题提issue反馈。
- 系统禁止运行脚本，可使用 `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force` 然后在执行命令。

```powershell
iwr "https://cdn.jsdelivr.net/gh/BennettChina/adachi-bot-installer`@main/adachi_bot_install.ps1" -O .\adachi_bot_install.ps1; .\adachi_bot_install.ps1; rm .\adachi_bot_install.ps1
```

## Android

使用 `termux` [App](https://github.com/termux/termux-app) 来安装(可以通过 `F-Droid` 来[下载](https://f-droid.org/en/packages/com.termux/) 安装)，参考[云崽BOT](https://github.com/Le-niao/Yunzai-Bot) 的安卓安装方式。

下载完 `termux` 后执行 `pkg install proot git python -y`

使用[国光大佬](https://github.com/sqlsec/termux-install-linux) 提供的Linux系统安装脚本安装一个Linux系统（虽然 `termux` 自身就是Linux环境，但毕竟是模拟的，还是需要真正的Linux环境才能安装上BOT ）

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

启动系统后再执行(目前只提供了 `Ubuntu` 的安装脚本，这个脚本只是把环境安装了，后续还需要按照[官方文档](https://docs.adachi.top/deploy/)安装)

```shell
wget https://cdn.jsdelivr.net/gh/BennettChina/adachi-bot-installer@main/termux-ubuntu.sh -O - | bash -
```


## 感谢

- 感谢[jsdelivr](https://www.jsdelivr.com/)提供的镜像加速.
- 感谢[daocloud](https://get.daocloud.io/#install-compose)提供的镜像加速.
- 感谢[GithubProxy](https://ghproxy.com/)提供的镜像加速.
- 参考了[pcrbot/hoshino-installer](https://github.com/pcrbot/hoshino-installer)的脚本写法.
- 感谢[Termux](https://github.com/termux/termux-app)提供的软件
- 感谢[国光](https://github.com/sqlsec/termux-install-linux)大佬提供的Termux安装Linux系统脚本
