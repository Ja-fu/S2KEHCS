# ============================================================
#  三角洲行动 游戏模式脚本 (gamemode.ps1)
#  用法: 每次打游戏前运行(双击BAT菜单选2)
#  作用: 关闭系统代理 / 退出非必要后台程序 / 清理用户临时文件 / 刷新DNS
#  特点: 不修改任何常驻设置; 重启电脑或运行【恢复模式】即可还原
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateDir  = Join-Path $scriptDir 'state'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$proxyFile = Join-Path $stateDir 'proxy_backup.txt'

Write-Host "=============================================="
Write-Host " 三角洲行动 游戏模式"
Write-Host "=============================================="
Write-Host "将执行: 关闭系统代理 / 退出非必要后台程序 / 清理临时缓存 / 刷新DNS"
Write-Host "不会修改系统常驻设置，结束后可运行【恢复模式】还原代理。"
Write-Host ""

# --- 1. 关闭系统代理(保存原值到 state\proxy_backup.txt) ---
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$oldPE = (Get-ItemProperty $reg).ProxyEnable
$oldPS = (Get-ItemProperty $reg).ProxyServer
$oldAC = (Get-ItemProperty $reg).AutoConfigURL
if ($null -eq $oldPE) { $oldPE = 0 }
@("$oldPE","$oldPS","$oldAC") | Set-Content $proxyFile
if ($oldPE -ne 0) {
    Set-ItemProperty $reg -Name ProxyEnable -Value 0
    Write-Host "[OK] 系统代理已关闭 (原代理: $oldPS; 已备份, 可恢复)"
} else {
    Write-Host "[OK] 系统代理本来就是关闭状态"
}

# --- 2. 退出非必要后台程序(均为普通软件, 可随时手动重启) ---
Write-Host ""
Write-Host "[步骤2] 退出非必要后台程序..."
$killNames = @('Veee','ToDesk','kwallpaper','BaiduNetdisk','BaiduNetdiskHost','SodaMusic','SodaMusicLauncher','QQ','WeChatAppEx','WPS','Quark','QianwenApp','qianwen','Xunlei','ThunderPlatform','WpsCenter')
foreach ($n in $killNames) {
    $p = @(Get-Process -Name $n -ErrorAction SilentlyContinue)
    if ($p.Count -gt 0) {
        Stop-Process -Name $n -Force -ErrorAction SilentlyContinue
        Write-Host ("[OK] 已退出: " + $n + " (" + $p.Count + " 个进程)")
    }
}
# 微信主程序/QQ 保留不杀(如需请手动关闭); Edge 浏览器保留(可查攻略)

# --- 3. 清理用户临时文件(直接删除, 可再生的缓存) ---
Write-Host ""
Write-Host "[步骤3] 清理用户临时文件..."
$tmp = $env:TEMP
$before = (Get-ChildItem $tmp -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
Get-ChildItem $tmp -Force -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
}
$after = (Get-ChildItem $tmp -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$freed = [math]::Max(0, $before - $after)
Write-Host ("[OK] 临时文件已清理, 释放约 " + [math]::Round($freed/1MB,1) + " MB")

# --- 4. 刷新 DNS ---
Write-Host ""
Write-Host "[步骤4] 刷新 DNS 缓存..."
ipconfig /flushdns | Out-Null
Write-Host "[OK] DNS 缓存已刷新"

# --- 5. 环境检查 ---
Write-Host ""
Write-Host "[步骤5] 游戏环境检查..."
$risk = @()
if (@(Get-Process -Name 'ToDesk' -ErrorAction SilentlyContinue).Count -gt 0) { $risk += 'ToDesk 仍在运行' }
if (@(Get-Process -Name 'Veee' -ErrorAction SilentlyContinue).Count -gt 0) { $risk += 'Veee 代理仍在运行' }
$pe2 = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).ProxyEnable
if ($pe2 -ne 0) { $risk += '系统代理仍开启' }
if ($risk.Count -gt 0) {
    Write-Host ("[警告] " + ($risk -join '; ') + " —— 请手动关闭后再进游戏")
} else {
    Write-Host "[OK] 游戏环境已就绪，可以启动三角洲行动！"
}

Write-Host ""
Write-Host "提示: 游戏期间请勿打开 Veee / ToDesk / 壁纸软件;"
Write-Host "      打完游戏运行【恢复模式】即可还原系统代理。"
Write-Host ""
Read-Host "按回车键退出"
