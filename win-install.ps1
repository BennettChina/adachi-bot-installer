# this file should be saved as "UTF-8 with BOM"
$ErrorActionPreference = "Stop"

function Expand-ZIPFile($file, $destination)
{
    $file = (Resolve-Path -Path $file).Path
    $destination = (Resolve-Path -Path $destination).Path
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($file)
    foreach ($item in $zip.items())
    {
        $shell.Namespace($destination).copyhere($item)
    }
}

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator"))
{
    write-Warning "需要以管理员权限运行."
    exit
}

if ($Host.Version.Major -lt 3)
{
    Write-Output "powershell版本太低无法使用该脚本一键部署！"
    exit
}
if ((Get-ChildItem -Path Env:OS).Value -ine "Windows_NT")
{
    Write-Output "不支持的操作系统."
    exit
}
if (![Environment]::Is64BitProcess)
{
    Write-Output "不支持32位操作系统！"
    exit
}

if (Test-Path .\Adachi-BOT)
{
    Write-Output "已存在Adachi-BOT文件夹是否删除?"
    $reinstall = Read-Host "请输入y/n"
    Switch ($reinstall)
    {
        Y {
            Remove-Item .\Adachi-BOT -Recurse -Force
        }
        N {
            break
        }
        Default {
            break
        }
    }
}

$install_node = $true
$install_redis = $true
$install_git = $true
$run_with_docker = $false
$run_with_docker_compose = $false
$console_port = 80
$redis_port = 56379
$logger_port = 54921
$genshin_port = 58612

try
{
    docker version
    if ($LASTEXITCODE = "0")
    {
        Write-Output "docker将使用docker方式启动服务."
        $run_with_docker = $true
        $install_node = $false
        $install_redis = $false
    }
    else
    {
        Write-Output "未安装docker将使用pm2方式启动服务"
    }
}
catch [System.Management.Automation.CommandNotFoundException]
{
    Write-Output "未安装docker将使用pm2方式启动服务"
}

if ($run_with_docker)
{
    try
    {
        docker compose version
        if ($LASTEXITCODE = "0")
        {
            Write-Output "使用的高版本docker自带docker-compose,将使用docker-compose方式启动服务"
            $run_with_docker_compose = $true
        }
        else
        {
            Write-Output "使用的Docker版本太低，请更新后再使用本脚本."
            exit
        }
    }
    catch [System.Management.Automation.CommandNotFoundException]
    {
        Write-Output "使用的Docker版本太低，请更新后再使用本脚本."
        exit
    }
}

if (!$run_with_docker_compose)
{
    $redis_status = Read-Host "您是否已安装redis并已在运行？请输入 y 或 n "
    if ($redis_status -eq "y")
    {
        $install_redis = $false
    }

    try
    {
        node --version
        if ($LASTEXITCODE = "0")
        {
            Write-Output "已安装node，将不再安装node"
            $install_node = $false
        }
    }
    catch [System.Management.Automation.CommandNotFoundException]
    {
        Write-Output "未安装node，将为你自动安装node环境"
    }
}

try
{
    git --version
    $install_git = $false
    Write-Output "git已安装，跳过安装"
}
catch [System.Management.Automation.CommandNotFoundException]
{
    Write-Output "git 未安装，将自动安装"
}

$loop = $true
while ($loop)
{
    $loop = $false
    Write-Output "请选择下载源"
    Write-Output "1、中国大陆"
    Write-Output "2、港澳台或国外"
    $user_in = Read-Host "请输入编号"
    Switch ($user_in)
    {
        1 {
            $source_cn = $true
        }
        2 {
            $source_cn = $false
        }
        Default {
            $loop = $true
        }
    }
}

if ($source_cn)
{
    $node = "https://repo.huaweicloud.com/nodejs/v17.6.0/node-v17.6.0-x64.msi"
    $git = "https://mirrors.huaweicloud.com/git-for-windows/v2.35.1.windows.1/Git-2.35.1-64-bit.exe"
    $redis = "https://ghproxy.com/https://github.com/microsoftarchive/redis/releases/download/win-3.0.504/Redis-x64-3.0.504.zip"
    $adachi_bot_repo_url = "https://ghproxy.com/https://github.com/SilveryStar/Adachi-BOT.git"
}
else
{
    $node = "https://nodejs.org/dist/v17.7.0/node-v17.7.0-x64.msi"
    $git = "https://github.com/git-for-windows/git/releases/download/v2.35.1.windows.2/Git-2.35.1.2-64-bit.exe"
    $redis = "https://github.com/microsoftarchive/redis/releases/download/win-3.0.504/Redis-x64-3.0.504.zip"
    $adachi_bot_repo_url = "https://github.com/SilveryStar/Adachi-BOT.git"
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($install_node)
{
    Write-Output "正在安装node中..."
    Invoke-CimMethod -ClassName Win32_Product -MethodName Install -Arguments @{ PackageLocation = "$node" }
    # set env
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Output "node 安装成功."
    # set npm mirror
    if ($source_cn)
    {
        npm config set registry https://registry.npmmirror.com
    }
}
if ($install_git)
{
    Write-Output "正在安装git中 ..."
    Invoke-WebRequest $git -OutFile .\git-2.35.1.exe
    Start-Process -Wait -FilePath .\git-2.35.1.exe -ArgumentList "/SILENT /SP-"
    $env:Path += ";C:\Program Files\Git\bin"
    Write-Output "git 安装成功."
    Remove-Item git-2.35.1.exe
}

if ($install_redis)
{
    Write-Output "正在安装redis中 ..."
    Invoke-WebRequest $redis -O .\redis.zip
    New-Item -Path ".\redis" -ItemType Directory
    Expand-ZIPFile redis.zip -Destination ".\redis\"
    Remove-Item redis.zip
    $redis_path = $( Get-Item . ).FullName + "\redis"
    $env:Path += ";$redis_path"
    $env:Path += ";$redis_path" + "redis.windows.conf"
    Set-Location ".\redis"
    New-Item -Path ".\database" -ItemType Directory
    New-Item -Path .\redis.windows.conf -ItemType File -Force -Value "stop-writes-on-bgsave-error no
rdbcompression no
dbfilename dump.rdb

appendonly yes
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

port 6379
#requirepass yourpassword
dir ./database/"
    Write-Output "正在启动redis中..."
    redis-server --service-install redis.windows.conf --loglevel verbose
    redis-server --service-start
    Set-Location ..

    Write-Output "redis已成功在后台运行, 端口是6379, 数据将存储在${redis_path}\database目录中。"
}

git clone $adachi_bot_repo_url --depth=1
Write-Output "adachi-bot clone success."

Set-Location Adachi-BOT
$work_dir = Get-Item .

Set-Location "src\plugins"
$plugins = Invoke-RestMethod -Uri "https://source.hibennett.cn/bot/plugins.json"
Write-Output "以下插件名称将使用英文名称(中文在win乱码，见谅)，可在 https://github.com/SilveryStar/Adachi-Plugin 查看插件描述"
Write-Output "请选择需要使用的插件"
$i = 1
foreach ($item in $plugins)
{
    Write-Output $( "$i) " + $item.en_name )
    $i++
}
$len = $i + 1

$use_plugins = ""
while ($true)
{
    $user_in = Read-Host "请输入编号,输入0结束,输入all选择全部"
    if ($user_in -eq "0")
    {
        Write-Output "结束选择插件，你选择了$use_plugins"
        break
    }
    if ($user_in -eq "all")
    {
        foreach ($item in $plugins)
        {
            $opt = ""
            if ($null -ne $item.ref)
            {
                $opt = "-b$($item.ref)"
            }
            $alias = $item.alias
            if ($null -eq $alias)
            {
                $alias = ""
            }
            git clone --depth=1 $opt $item.url $alias
        }
        Write-Output "结束选择插件，你选择了全部插件"
        break
    }

    if ($user_in.Contains(' ')) {
        $arr = $user_in.Split(' ')
        foreach ($word in $arr) {
            if ([int]$word -gt [int]$len)
            {
                Write-Output "不存在${word}号插件."
                continue
            }
            $item=$plugins[$($word - 1)]
            $opt = ""
            if ($null -ne $item.ref)
            {
                $opt = "-b$($item.ref)"
            }
            $alias = $item.alias
            if ($null -eq $alias)
            {
                $alias = ""
            }
            git clone --depth=1 $opt $item.url $alias
            $use_plugins = "$use_plugins $($item.en_name)"
        }
        break
    }

    if ([int]$user_in -gt [int]$len)
    {
        Write-Output "不存在${user_in}号插件，如果你要一次多选请用空格隔开."
        continue
    }

    $item=$plugins[$($user_in - 1)]
    $opt = ""
    if ($null -ne $item.ref)
    {
        $opt = "-b$($item.ref)"
    }
    $alias = $item.alias
    if ($null -eq $alias)
    {
        $alias = ""
    }
    git clone --depth=1 $opt $item.url $alias
    $use_plugins = "$use_plugins $($item.en_name)"
}

Set-Location $work_dir

Write-Output "开始创建配置文件..."
if (!(Test-Path -Path "${work_dir}/config"))
{
    New-Item -Path ".\config" -ItemType Directory
}
New-Item -ItemType "file" -Path ".\config\setting.yml", ".\config\commands.yml", ".\config\cookies.yml", ".\config\genshin.yml" -Force

$loop = $true
while ($loop)
{
    $loop = $false
    Write-Output "请选择机器人登录平台"
    Write-Output "1）安卓手机"
    Write-Output "2）安卓Pad"
    Write-Output "3）安卓手表"
    Write-Output "4）MacOS"
    Write-Output "5）iPad"
    Write-Output "6）安卓8.8.88"
    $user_in = Read-Host "请输入编号"
    Switch ($user_in)
    {
        1 {
            $platform = 1
        }
        2 {
            $platform = 2
        }
        3 {
            $platform = 3
        }
        4 {
            $platform = 4
        }
        5 {
            $platform = 5
        }
        6 {
            $platform = 6
        }
        Default {
            Write-Output "你输入的编号非法,请重新输入!"
            $loop = $true
        }
    }
}

$jwt_secret = -join ((65..90) + (97..122) | Get-Random -Count 16 | ForEach-Object { [char]$_ })

$qq_num = Read-Host "请输入机器人的QQ号"
$loop = $true
while ($loop)
{
    Write-Output "请选择机器人登录方式"
    Write-Output "1) 密码登录"
    Write-Output "2) 扫码登录"
    $user_in = Read-Host "输入编号选择: "
    $loop = $false
    Switch ($user_in)
    {
        1 {
            $pwd_secure_str = Read-Host -AsSecureString "请输入机器人的QQ密码"
            $qq_password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pwd_secure_str))
            $qr_code = $false
            $npm_param = "docker-start"
        }
        2 {
            $qr_code = $true
            $qq_password = "`"`""
            $npm_param = "login"
        }
        Default {
            Write-Output "你输入的编号非法,请重新输入!"
            $loop = $true
        }
    }
}
$master_num = Read-Host "请输入机器人主人的QQ号"
Write-Output '获取米游社cookie方式一:
  1) 无痕模式打开 https://www.miyoushe.com/ys/ 页面
  2) F12打开网页控制台，按下Ctrl+F8(⌘+F8)后再按F8即可解除暂停
  3) 在Network(网络)栏，在Filter(过滤)里粘贴 getUserGameUnreadCount，同时选择Fetch/XHR
  4) 点击一条捕获到的结果，往下拉，找到Cookie后复制其内容即可。\n\n'

Write-Output "获取米游社cookie方式二:
  1) 无痕模式打开 https://user.mihoyo.com/ 并进行登入操作
  2) 同方式一中的第二步解除暂停
  3) 在Console(控制台)栏输入 copy(document.cookie) 后回车即可将Cookie复制在剪切板中。\n\n"

$mys_cookie = Read-Host "请输入一个米游社cookie: "


if (!($run_with_docker_compose))
{
    $redis_port = 6379
    $logger_port = 4921
    $genshin_port = 8612
}


New-Item -Path .\config\setting.yml -ItemType File -Force -Value "tip: 前往 https://docs.adachi.top/config 查看配置详情
qrcode: ${qrcode}
number: ${qq_num}
password: ${qq_password}
master: ${master_num}
header: `"#`"
platform: ${platform}
atUser: false
atBOT: false
addFriend: true
autoChat:
  enable: false
  type: 1
  secretId: `"`"
  secretKey: `"`"
inviteAuth: master
countThreshold: 60
groupIntervalTime: 1500
privateIntervalTime: 2000
helpMessageStyle: message
logLevel: info
logKeepDays: 30
dbPort: ${redis_port}
dbPassword: `"`"
webConsole:
  enable: true
  consolePort: ${console_port}
  tcpLoggerPort: ${logger_port}
  jwtSecret: ${jwt_secret}
helpPort: 54919
callTimes: 3
fuzzyMatch: false
matchPrompt: true
useWhitelist: false
banScreenSwipe:
  enable: false
  limit: 10
  duration: 1800
  prompt: true
  promptMsg: 请不要刷屏哦~
banHeavyAt:
  enable: false
  limit: 10
  duration: 1800
  prompt: true
  promptMsg: 你at太多人了，会被讨厌的哦~
ThresholdInterval: false
ffmpegPath: `"`"
ffprobePath: `"`"
mailConfig:
  platform: qq
  user: 123456789@qq.com
  authCode: `"`"
  logoutSend: false
  sendDelay: 5
"

New-Item -Path .\config\cookies.yml -ItemType File -Force -Value "cookies:
  - ${mys_cookie}"

New-Item -Path .\config\genshin.yml -ItemType File -Force -Value "cardWeaponStyle: normal
cardProfile: random
serverPort: ${genshin_port}"

# 启动程序
if ($run_with_docker_compose)
{
    docker compose up -d --build
}
else
{
    npm i
    npm i pm2 -g
    Write-Output "\t<============================ ↓ ↓ ↓ 服务已经在启动中了，以下是BOT服务的日志内容(CTRL+C结束查看日志) ↓ ↓ ↓ ======================>"
    npm start
    pm2 logs --lines 100
}

if ($run_with_docker_compose)
{
    Write-Output "\t<============================ ↓ ↓ ↓ 服务已经在启动中了...,以下是BOT服务的日志内容(CTRL+C结束查看日志) ↓ ↓ ↓ ======================>"
    docker logs -f adachi-bot
}