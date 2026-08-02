# 定义固定的存放文件夹和程序路径
$installDir = "C:\NatmapTool"
$exePath = "$installDir\natmap.exe"

# 1. 检查并创建基础文件夹
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir > $null
}

# 2. 核心逻辑：检测与下载，带有容错机制
if (Test-Path $exePath) {
    Write-Host "[成功] 检测到本地已存在穿透组件，跳过下载步骤！" -ForegroundColor Green
} else {
    Write-Host "[提示] 首次运行，正在从 GitHub 拉取穿透组件，请稍候..." -ForegroundColor Cyan
    try {
        # 获取最新版本下载链接
        $url=(Invoke-RestMethod "https://api.github.com/repos/heiher/natmap/releases/latest").assets.browser_download_url -match "windows-amd64.exe$"
        
        # 使用更稳定的 ghp.ci 代理节点，并设置 -ErrorAction Stop 以便捕捉错误
        Invoke-WebRequest "https://ghp.ci/$url" -OutFile $exePath -ErrorAction Stop
        
        Write-Host "[成功] 下载完成！" -ForegroundColor Green
    } catch {
        Write-Host "[失败] 无法下载穿透组件！可能是加速节点不稳定。" -ForegroundColor Red
        Write-Host "系统报错: $($_.Exception.Message)" -ForegroundColor DarkGray
        exit # 下载失败，立即终止脚本运行
    }
}

# 3. 再次确认文件存在后，执行后续操作
if (Test-Path $exePath) {
    Write-Host "[执行] 正在应用防火墙放行规则..." -ForegroundColor Cyan
    netsh advfirewall firewall add rule name="UDP_8211_STUN" dir=in action=allow protocol=UDP localport=8211 >$null 2>&1

    Write-Host "[执行] 正在连接 STUN 服务器获取公网地址..." -ForegroundColor Yellow
    & $exePath -s stun.miwifi.com -p 8211 -u
}
