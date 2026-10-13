# ============================================================
#  三角洲行动 环境体检脚本 (report.ps1)
#  用法: 双击BAT菜单选4
#  作用: 汇总系统/网络/反作弊风险因素, 生成体检报告 report.txt
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$reportFile = Join-Path $scriptDir 'report.txt'
$out = New-Object System.Collections.ArrayList
function Log($m) { $null = $out.Add($m); Write-Host $m }

Log "=========== 三角洲行动 环境体检报告 ==========="
Log ("生成时间: " + (Get-Date))
Log ""

# --- 系统 ---
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$mem = Get-CimInstance Win32_ComputerSystem
Log "[系统]"
Log ("  操作系统: " + $os.Caption + " (Build " + $os.BuildNumber + ")")
Log ("  CPU: " + $cpu.Name)
Log ("  内存: " + [math]::Round($mem.TotalPhysicalMemory/1GB,0) + " GB")
$gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA|AMD|Intel' }
foreach ($g in $gpu) { Log ("  显卡: " + $g.Name + " (驱动 " + $g.DriverVersion + ")") }

# --- 磁盘 ---
$disk = Get-PSDrive -PSProvider FileSystem
foreach ($d in $disk) {
    Log ("  磁盘 " + $d.Name + ": 已用 " + [math]::Round($d.Used/1GB,1) + " GB / 可用 " + [math]::Round($d.Free/1GB,1) + " GB")
}

# --- 网络 ---
Log ""
Log "[网络]"
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if ($adapter) {
    Log ("  网卡: " + $adapter.Name + " (" + $adapter.InterfaceDescription + ") 速率 " + $adapter.LinkSpeed)
    $dns = @((Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4).ServerAddresses)
    Log ("  DNS: " + ($dns -join ', '))
}
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$pe = (Get-ItemProperty $reg).ProxyEnable
$psv = (Get-ItemProperty $reg).ProxyServer
if ($pe -ne 0) { Log ("  [风险] 系统代理开启中: " + $psv) } else { Log "  系统代理: 关闭" }

# --- 反作弊风险因素检查 ---
Log ""
Log "[反作弊风险因素检查(ACE 敏感项)]"
$riskCount = 0
if (@(Get-Process -Name 'Veee' -ErrorAction SilentlyContinue).Count -gt 0) { Log "  [风险] Veee 代理软件正在运行 —— 游戏时请务必退出"; $riskCount++ }
if (@(Get-Process -Name 'ToDesk' -ErrorAction SilentlyContinue).Count -gt 0) { Log "  [风险] ToDesk 远程控制正在运行 —— 反作弊高度敏感, 游戏前请退出"; $riskCount++ }
$todeskDrv = Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object { $_.DeviceName -match 'ToDesk|Virtual Display' }
if ($todeskDrv) { Log "  [提示] 检测到 ToDesk 虚拟显示驱动(即使未运行也存在于系统中)"; $riskCount++ }
if (@(Get-Process -Name 'kwallpaper' -ErrorAction SilentlyContinue).Count -gt 0) { Log "  [风险] 壁纸软件 kwallpaper 正在运行 —— 持续占用GPU, 建议游戏时退出"; $riskCount++ }
$wechatCount = @(Get-Process -Name 'WeChatAppEx' -ErrorAction SilentlyContinue).Count
if ($wechatCount -gt 5) { Log ("  [提示] 微信小程序进程 " + $wechatCount + " 个, 建议游戏前退出微信或清理"); $riskCount++ }
if ($riskCount -eq 0) { Log "  未发现明显风险因素" }

# --- 进程内存占用 Top10 ---
Log ""
Log "[内存占用 TOP 10]"
Get-Process | Group-Object ProcessName | ForEach-Object {
    [PSCustomObject]@{ Name=$_.Name; MemMB=[math]::Round((($_.Group | Measure-Object WorkingSet64 -Sum).Sum)/1MB,0); Count=$_.Count }
} | Sort-Object MemMB -Descending | Select-Object -First 10 | ForEach-Object {
    Log ("  " + $_.Name.PadRight(20) + " " + $_.MemMB + " MB x" + $_.Count)
}

# --- 建议 ---
Log ""
Log "[建议]"
Log "  1. 打游戏前运行【游戏模式】(自动关代理+退后台), 不要开 Veee/ToDesk"
Log "  2. 若频繁进入观察期, 除环境外也请通过游戏内客服/ACE 官方渠道申诉"
Log "  3. 显卡驱动若偏旧, 到 NVIDIA 官网更新: https://www.nvidia.cn/drivers/"
Log "  4. C盘剩余空间较小时, 运行【深度优化】清理缓存"
Log "==============================================="
$out | Set-Content -Path $reportFile -Encoding UTF8
Write-Host ""
Write-Host ("体检报告已保存: " + $reportFile)
Write-Host ""
Read-Host "按回车键退出"
