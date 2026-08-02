# 1. 定义程序存放路径
$installDir = "C:\NatmapTool"
$exePath = "$installDir\natmap.exe"

# 检查并创建基础文件夹
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Force -Path $installDir > $null
}

# 2. 交互式下载逻辑
if (Test-Path $exePath) {
    Write-Host "[成功] 检测到本地已存在穿透组件，跳过下载步骤！" -ForegroundColor Green
} else {
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "[提示] 首次运行，正在为您唤起浏览器打开蓝奏云..." -ForegroundColor Yellow
    
    # 自动打开默认浏览器访问蓝奏云
    Start-Process "https://hws.lanzouu.com/iIsqe4080tqd"
    
    Write-Host ""
    Write-Host "操作指引：" -ForegroundColor Cyan
    Write-Host "1. 请在刚刚弹出的网页中，点击下载按钮。"
    Write-Host "2. 在浏览器的下载管理/下载任务中，找到该文件的【真实下载直链】并复制。"
    Write-Host "   (或者在下载按钮上 右键 -> 复制链接地址)"
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # 暂停脚本，等待用户粘贴
    $downloadUrl = Read-Host "👉 请在此处粘贴复制好的直链地址并按回车 (右键即可粘贴)"
    
    # 简单验证链接格式
    if ($downloadUrl -match "^https?://") {
        Write-Host "[执行] 正在下载，请稍候..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -ErrorAction Stop
            Write-Host "[成功] 下载完成！" -ForegroundColor Green
        } catch {
            Write-Host "[错误] 下载失败！可能是链接已过期，或复制的不是直接下载链接。" -ForegroundColor Red
            Write-Host "系统报错: $($_.Exception.Message)" -ForegroundColor DarkGray
            exit
        }
    } else {
        Write-Host "[错误] 您输入的似乎不是一个有效的网址。" -ForegroundColor Red
        exit
    }
}

# 3. 确保防火墙放行
Write-Host "[执行] 正在应用防火墙放行规则..." -ForegroundColor Cyan
netsh advfirewall firewall add rule name="UDP_8211_STUN" dir=in action=allow protocol=UDP localport=8211 >$null 2>&1

# 4. 运行打洞程序
Write-Host "[执行] 正在连接 STUN 服务器获取公网地址..." -ForegroundColor Yellow
& $exePath -s stun.miwifi.com -p 8211 -u
