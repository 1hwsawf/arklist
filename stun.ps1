# 定义固定的存放文件夹和程序路径，防止被系统自动清理
$installDir = "C:\NatmapTool"
$exePath = "$installDir\natmap.exe"

# 1. 检查并创建基础文件夹
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir > $null
}

# 2. 核心逻辑：检测可执行文件是否已经下载
if (Test-Path $exePath) {
    Write-Host "[成功] 检测到本地已存在穿透组件，跳过下载步骤！" -ForegroundColor Green
} else {
    Write-Host "[提示] 首次运行，正在从 GitHub 拉取穿透组件，请稍候..." -ForegroundColor Cyan
    $url=(Invoke-RestMethod "https://api.github.com/repos/heiher/natmap/releases/latest").assets.browser_download_url -match "windows-amd64.exe$"
    Invoke-WebRequest "https://mirror.ghproxy.com/$url" -OutFile $exePath
    Write-Host "[成功] 下载完成！" -ForegroundColor Green
}

# 3. 确保防火墙放行
Write-Host "[执行] 正在应用防火墙放行规则..." -ForegroundColor Cyan
netsh advfirewall firewall add rule name="UDP_8211_STUN" dir=in action=allow protocol=UDP localport=8211 >$null 2>&1

# 4. 运行打洞程序
Write-Host "[执行] 正在连接 STUN 服务器获取公网地址..." -ForegroundColor Yellow
& $exePath -s stun.miwifi.com -p 8211 -u
