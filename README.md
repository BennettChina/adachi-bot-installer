# adachi-bot-installer
[SilveryStar/Adachi-BOT](https://github.com/SilveryStar/Adachi-BOT)的一键部署脚本

## Linux

`Linux`环境可以直接执行下面的命令，将通过安装`Docker`、`docker-compose`的方式运行BOT。

```sh
wget https://cdn.jsdelivr.net/gh/BennettChina/adachi-bot-installer@main/adachi_bot_install.sh -O adachi_bot_install.sh && sudo bash adachi_bot_install.sh && rm adachi_bot_install.sh
```


## 感谢

- 感谢[jsdelivr](https://www.jsdelivr.com/)提供的镜像加速.
- 感谢[daocloud](https://get.daocloud.io/#install-compose)提供的镜像加速.
- 感谢[GithubProxy](https://ghproxy.com/)提供的镜像加速.
- 参考了[pcrbot/hoshino-installer](https://github.com/pcrbot/hoshino-installer)的脚本写法.
