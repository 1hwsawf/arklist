$installDir = "C:\NatmapTool"
$exePath = "$installDir\natmap.exe"
$zipPath = "$installDir\natmap.zip"

if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir > $null
}

# 1. 检查是否已经有解压好的 exe
if (Test-Path $exePath) {
    Write-Host "[成功] 检测到本地已存在可运行的程序，跳过下载！" -ForegroundColor Green
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
            # 先存为 zip
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -ErrorAction Stop
            Write-Host "[执行] 下载成功！正在解压..." -ForegroundColor Cyan
            
            # 自动解压到目标文件夹
            Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
            
            # 删掉用完的压缩包
            Remove-Item -Path $zipPath -Force
            
            if (!(Test-Path $exePath)) {
                Write-Host "[错误] 解压成功，但里面没找到 natmap.exe！" -ForegroundColor Red
                exit
            }
            Write-Host "[成功] 解压完成！" -ForegroundColor Green
        } catch {
            Write-Host "[错误] 下载或解压失败，请检查链接。" -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "[错误] 链接无效。" -ForegroundColor Red
        exit
    }
}

# 2. 防火墙与打洞
Write-Host "[执行] 正在应用防火墙放行规则..." -ForegroundColor Cyan
netsh advfirewall firewall add rule name="UDP_8211_STUN" dir=in action=allow protocol=UDP localport=8211 >$null 2>&1

Write-Host "[执行] 正在连接 STUN 服务器获取公网地址..." -ForegroundColor Yellow
& $exePath -s stun.miwifi.com -p 8211 -u
