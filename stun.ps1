# =====================================================================
# GitHub 一键 STUN 穿透脚本 (Natmap 端口转发无冲突版)
# =====================================================================

# 0. 启动前强行清理残留的 natmap 进程，防止端口与死锁
Get-Process -Name "natmap" -ErrorAction SilentlyContinue | Stop-Process -Force

$installDir = "C:\NatmapTool"
$exePath = "C:\NatmapTool\natmap.exe"
$zipPath = "C:\NatmapTool\natmap.zip"

if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir > $null
}

# 1. 检查本地程序文件，不存在则引导下载
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

# 2. 配置 Windows 防火墙（双向放行 8211 端口与主程序）
Write-Host "[执行] 正在配置 Windows 防火墙双向放行规则..." -ForegroundColor Cyan
netsh advfirewall firewall add rule name="UDP_8211_STUN" dir=in action=allow protocol=UDP localport=8211 >$null 2>&1
netsh advfirewall firewall add rule name="NATMAP_EXE_IN" dir=in action=allow program="$exePath" >$null 2>&1

# 3. 启动打洞并建立转发 (-b 0 随机空闲端口打洞，转发给本地 8211)
Write-Host "[执行] 正在连接 STUN 服务器打洞并建立转发到 8211 端口..." -ForegroundColor Yellow
Start-Process -FilePath $exePath -ArgumentList "-s stun.miwifi.com -h qq.com -b 0 -t 127.0.0.1 -p 8211 -u" -NoNewWindow
