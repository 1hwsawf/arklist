# 0. 启动前清理残留的 natmap 进程
Stop-Process -Name "natmap" -Force -ErrorAction SilentlyContinue

$installDir = "C:\NatmapTool"
$exePath = "$installDir\natmap.exe"
$zipPath = "$installDir\natmap.zip"

if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir > $null
}

# 1. 检查本地文件
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

# 2. 关键点：配置 Windows 防火墙（双向放行端口 + 主程序进程）
Write-Host "[执行] 正在配置 Windows 防火墙放行规则..." -ForegroundColor Cyan
netsh advfirewall firewall add rule name="UDP_8211_STUN" dir=in action=allow protocol=UDP localport=8211 >$null 2>&1
netsh advfirewall firewall add rule name="NATMAP_EXE_IN" dir=in action=allow program="$exePath" >$null 2>&1

# 3. 自动提取本机真实 IPv4 地址（修正语法错误）
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254*" }).IPAddress[0]
if (!$localIP) { $localIP = "192.168.10.21" }

# 4. 运行 Lucky 同款模式打洞
Write-Host "[执行] 正在启动 STUN 穿透 (绑定内网网卡 $localIP)..." -ForegroundColor Yellow
& $exePath -s stun.miwifi.com -h qq.com -i $localIP -b 8211 -u
