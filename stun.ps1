# 0. 启动前清理残留的 natmap 进程，防止重复运行
Stop-Process -Name "natmap" -Force -ErrorAction SilentlyContinue

$installDir = "C:\NatmapTool"
$exePath = "$installDir\natmap.exe"
$zipPath = "$installDir\natmap.zip"

if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir > $null
}

# 1. 检测本地程序文件
if (Test-Path $exePath) {
    Write-Host "[成功] 检测到本地已存在程序，跳过下载！" -ForegroundColor Green
} else {
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "[提示] 正在唤起浏览器..." -ForegroundColor Yellow
    Start-Process "https://hws.lanzouu.com/iIsqe4080tqd"
    Write-Host "请在浏览器的【下载管理(Ctrl+J)】中，右键复制真实下载直链！" -ForegroundColor Red
    Write-Host "===========================================================" -ForegroundColor Cyan
    
    $downloadUrl = Read-Host "👉 请在此处粘贴直链并按回车"
    
    if ($downloadUrl -match "^https?://") {
        Write-Host "[执行] 正在下载压缩包..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
            Write-Host "[执行] 下载成功！正在解压..." -ForegroundColor Cyan
            Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
            Remove-Item -Path $zipPath -Force
            
            if (!(Test-Path $exePath)) {
                Write-Host "[错误] 解压成功，但里面没找到 natmap.exe！" -ForegroundColor Red
                exit
            }
            Write-Host "[成功] 解压完成！" -ForegroundColor Green
        } catch {
            Write-Host "[错误] 下载或解压失败。" -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "[错误] 链接无效。" -ForegroundColor Red
        exit
    }
}

# 2. 防火墙放行本地 8211 端口
Write-Host "[执行] 正在应用防火墙放行规则..." -ForegroundColor Cyan
netsh advfirewall firewall add rule name="UDP_8211_STUN" dir=in action=allow protocol=UDP localport=8211 >$null 2>&1

# 3. 动态随机本地端口打洞，并无缝转发流量给本地 8211 端口
Write-Host "[执行] 正在连接 STUN 服务器打洞并建立转发到 8211 端口..." -ForegroundColor Yellow
& $exePath -s stun.miwifi.com -h qq.com -b 0 -t 192.168.10.21 -p 8211 -u
