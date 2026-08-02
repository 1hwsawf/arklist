# =====================================================================
# GitHub 一键 STUN 穿透脚本（NatMap 端口转发增强版）
# =====================================================================

# PowerShell 下载加速
$ProgressPreference = "SilentlyContinue"

# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal]
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Red
    Write-Host " 请右键使用【管理员身份运行】PowerShell！" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Red
    Read-Host "按回车退出"
    exit
}

# 清理旧进程
Get-Process -Name "natmap" -ErrorAction SilentlyContinue | Stop-Process -Force

$installDir = "C:\NatmapTool"
$exePath = Join-Path $installDir "natmap.exe"
$zipPath = Join-Path $installDir "natmap.zip"

if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

# 检查程序
if (Test-Path $exePath) {

    Write-Host "[成功] 已检测到 natmap.exe，跳过下载。" -ForegroundColor Green

}
else {

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "浏览器即将打开下载页面..." -ForegroundColor Yellow
    Write-Host "==================================================" -ForegroundColor Cyan

    Start-Process "https://hws.lanzouu.com/iIsqe4080tqd"

    Write-Host ""
    Write-Host "请在浏览器下载完成后：" -ForegroundColor Yellow
    Write-Host "Ctrl+J → 复制真实下载地址 → 粘贴下面" -ForegroundColor Yellow

    $downloadUrl = Read-Host "下载直链"

    if ($downloadUrl -notmatch '^https?://') {
        Write-Host ""
        Write-Host "[错误] 下载链接格式错误。" -ForegroundColor Red
        Read-Host "按回车退出"
        exit
    }

    try {

        Write-Host ""
        Write-Host "开始下载..." -ForegroundColor Cyan

        Invoke-WebRequest `
            -Uri $downloadUrl `
            -OutFile $zipPath `
            -UseBasicParsing `
            -ErrorAction Stop

        if (!(Test-Path $zipPath)) {
            throw "ZIP 文件不存在。"
        }

        if ((Get-Item $zipPath).Length -lt 100000) {
            throw "下载文件异常，可能不是 ZIP。"
        }

        Write-Host "下载完成，开始解压..." -ForegroundColor Cyan

        Expand-Archive `
            -Path $zipPath `
            -DestinationPath $installDir `
            -Force

        Remove-Item $zipPath -Force

        if (!(Test-Path $exePath)) {
            throw "解压完成，但未找到 natmap.exe"
        }

        Write-Host "[成功] 解压完成。" -ForegroundColor Green

    }
    catch {

        Write-Host ""
        Write-Host "[错误] 下载失败：" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow

        Read-Host "按回车退出"
        exit

    }
}

Write-Host ""
Write-Host "正在配置 Windows 防火墙..." -ForegroundColor Cyan

# 删除旧规则
@(
"UDP_8211_IN",
"UDP_8211_OUT",
"NATMAP_IN",
"NATMAP_OUT"
) | ForEach-Object {

    netsh advfirewall firewall delete rule name="$_" *> $null

}

# 添加规则
netsh advfirewall firewall add rule name="UDP_8211_IN" dir=in action=allow protocol=UDP localport=8211 *> $null
netsh advfirewall firewall add rule name="UDP_8211_OUT" dir=out action=allow protocol=UDP localport=8211 *> $null

netsh advfirewall firewall add rule name="NATMAP_IN" dir=in action=allow program="$exePath" action=allow *> $null
netsh advfirewall firewall add rule name="NATMAP_OUT" dir=out action=allow program="$exePath" action=allow *> $null

Write-Host "[成功] 防火墙配置完成。" -ForegroundColor Green

Write-Host ""
Write-Host "启动 NatMap..." -ForegroundColor Cyan

Start-Process `
    -FilePath $exePath `
    -ArgumentList "-s stun.miwifi.com -h qq.com -b 0 -t 127.0.0.1 -p 8211 -u"

Start-Sleep 2

if (Get-Process natmap -ErrorAction SilentlyContinue) {

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host " NatMap 已成功启动！" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green

}
else {

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Red
    Write-Host " NatMap 启动失败！" -ForegroundColor Red
    Write-Host " 请检查 natmap.exe 是否被杀毒软件拦截。" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Red

}

Read-Host "按回车退出"
