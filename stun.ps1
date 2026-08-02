# 1. 在防火墙中同时放行 UDP 8211 端口 和 natmap 主程序本身（防止入站拦截）
Write-Host "[执行] 正在配置 Windows 防火墙双向放行..." -ForegroundColor Cyan
netsh advfirewall firewall add rule name="UDP_8211_STUN" dir=in action=allow protocol=UDP localport=8211 >$null 2>&1
netsh advfirewall firewall add rule name="NATMAP_EXE" dir=in action=allow program="$exePath" >$null 2>&1

# 2. 获取你电脑真实的局域网 IP
$localIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "以太网*","Wi-Fi*" | Where-Host -FilterScript {$_.IPAddress -notlike "169.254*"}).IPAddress[0]
if (!$localIP) { $localIP = "192.168.10.21" }

# 3. 运行 Lucky 同款模式打洞 (绑定真实局域网网卡 IP)
Write-Host "[执行] 正在启动 STUN 穿透 (绑定本机局域网 IP: $localIP)..." -ForegroundColor Yellow
& $exePath -s stun.miwifi.com -h qq.com -i $localIP -b 8211 -u
