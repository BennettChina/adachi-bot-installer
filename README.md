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


## 感谢

- 感谢[jsdelivr](https://www.jsdelivr.com/)提供的镜像加速.
- 感谢[daocloud](https://get.daocloud.io/#install-compose)提供的镜像加速.
- 感谢[GithubProxy](https://ghproxy.com/)提供的镜像加速.
- 参考了[pcrbot/hoshino-installer](https://github.com/pcrbot/hoshino-installer)的脚本写法.
