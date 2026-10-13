# ============================================================
#  三角洲行动 深度优化脚本 (optimize.ps1)
#  功能: 清理系统缓存 / 网络DNS优化 / 关闭系统代理 / 禁用非必要启动项 / 游戏体验优化
#  原则: 所有系统修改均可回滚; 删除的文件进入回收站; 不触碰个人文件与安全软件
#  回滚: 运行同目录 rollback_optimize.ps1
# ============================================================

# --- 自提权(需要管理员: 清 Windows\Temp / 改 DNS / 停更新服务) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "正在请求管理员权限，请在弹窗 UAC 中点击“是”..."
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File",('"' + $PSCommandPath + '"'))
    exit
}

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName Microsoft.VisualBasic

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rollback  = Join-Path $scriptDir 'rollback_optimize.ps1'
$report    = Join-Path $scriptDir 'optimize_report.txt'
$lines     = New-Object System.Collections.ArrayList

function Log($m) { $null = $lines.Add($m); Write-Host $m }

# 安全转义: 把字符串包装成 PowerShell 单引号字面量, 内部单引号翻倍, 防止回滚脚本生成时引号破坏
function Q($s) {
    if ($null -eq $s) { return "''" }
    return "'" + ($s -replace "'", "''") + "'"
}

function Get-DirSize($p) {
    if (-not (Test-Path $p)) { return 0 }
    $s = (Get-ChildItem $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $s) { return 0 }
    return $s
}

# 将目录内所有内容移入回收站(可恢复), 返回释放的字节数
function Clear-ToRecycle($path, $label) {
    if (-not (Test-Path $path)) { Log ("  [跳过] " + $label + " (不存在)"); return 0 }
    $before = Get-DirSize $path
    if ($before -le 0) { Log ("  [跳过] " + $label + " (无内容)"); return 0 }
    $items = Get-ChildItem $path -Force -ErrorAction SilentlyContinue
    foreach ($it in $items) {
        try {
            if ($it.PSIsContainer) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($it.FullName,'OnlyErrorDialogs','SendToRecycleBin')
            } else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($it.FullName,'OnlyErrorDialogs','SendToRecycleBin')
            }
        } catch { }
    }
    $after = Get-DirSize $path
    $freed = [math]::Max(0, $before - $after)
    Log ("  [清理] " + $label + " 释放约 " + [math]::Round($freed/1MB,1) + " MB")
    return $freed
}

# --- 回滚脚本初始化 ---
$rb = @()
$rb += "# 回滚脚本 - 由 optimize.ps1 自动生成 ($(Get-Date))"
$rb += "# 作用: 撤销本次深度优化对 代理/DNS/启动项/录屏/电源计划 的修改"
$rb += "# 用法: 右键 -> 使用 PowerShell 运行(管理员)"
$rb += ""
$rb += "Write-Host '=== 开始回滚深度优化 ==='"

# ============ 0. 快照 ============
$diskBefore = (Get-PSDrive C).Free
Log "=============================================="
Log " 三角洲行动 深度优化开始"
Log "=============================================="
Log ("时间: " + (Get-Date))
Log ("清理前 C 盘可用: " + [math]::Round($diskBefore/1GB,1) + " GB")

# ============ 1. 清理缓存 ============
Log ""
Log "[1/6] 清理系统与软件缓存（删除内容进入回收站，可恢复）"
$totalFreed = 0

# Windows 更新缓存: 需临时停止更新服务
$wu = Get-Service wuauserv -ErrorAction SilentlyContinue
$wuWasRunning = ($wu -and $wu.Status -eq 'Running')
if ($wuWasRunning) {
    Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
    $rb += "Start-Service wuauserv -ErrorAction SilentlyContinue"
}
$totalFreed += Clear-ToRecycle 'C:\Windows\SoftwareDistribution\Download' "Windows 更新缓存"
if ($wuWasRunning) { Start-Service wuauserv -ErrorAction SilentlyContinue }

$totalFreed += Clear-ToRecycle $env:TEMP "用户临时文件"
$totalFreed += Clear-ToRecycle 'C:\Windows\Temp' "系统临时文件"
$totalFreed += Clear-ToRecycle (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache') "浏览器/网络缓存"
$totalFreed += Clear-ToRecycle (Join-Path $env:LOCALAPPDATA 'D3DSCache') "DirectX 着色器缓存(游戏首次启动会重建)"
$totalFreed += Clear-ToRecycle (Join-Path $env:LOCALAPPDATA 'NVIDIA') "NVIDIA 缓存"
$totalFreed += Clear-ToRecycle (Join-Path $env:LOCALAPPDATA 'CrashDumps') "崩溃转储"

# 缩略图缓存
$tbPath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
if (Test-Path $tbPath) {
    $tbs = @(Get-ChildItem $tbPath -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue)
    $tbSize = ($tbs | Measure-Object -Property Length -Sum).Sum
    foreach ($f in $tbs) { try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($f.FullName,'OnlyErrorDialogs','SendToRecycleBin') } catch { } }
    $tbAfter = (@(Get-ChildItem $tbPath -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue) | Measure-Object -Property Length -Sum).Sum
    $tbFreed = [math]::Max(0, $tbSize - $tbAfter)
    $totalFreed += $tbFreed
    Log ("  [清理] 缩略图缓存 释放约 " + [math]::Round($tbFreed/1MB,1) + " MB")
}

# 不可逆项: 只报告, 不清理
if (Test-Path 'C:\Windows.old') { Log "  [提示] 检测到 Windows.old(旧系统备份), 默认保留; 确需删除请手动用磁盘清理处理" }
$rbSize = (Get-ChildItem 'C:\$Recycle.Bin' -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
if ($rbSize -gt 0) { Log ("  [提示] 回收站当前占用约 " + [math]::Round($rbSize/1GB,2) + " GB, 默认不清空(回收站是误删后悔药)" ) }

Log ("  -- 本次缓存清理合计释放约: " + [math]::Round($totalFreed/1MB,1) + " MB")

# ============ 2. 网络优化 ============
Log ""
Log "[2/6] 网络优化（关闭系统代理 + 设置国内公共DNS + 刷新缓存）"

# 2.1 关闭系统代理(记录原值可回滚)
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$oldPE = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).ProxyEnable
$oldPS = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).ProxyServer
$oldAC = (Get-ItemProperty $reg -ErrorAction SilentlyContinue).AutoConfigURL
if ($null -eq $oldPE) { $oldPE = 0 }
if ($oldPE -ne 0) {
    Set-ItemProperty $reg -Name ProxyEnable -Value 0
    Log ("  [修改] 系统代理已关闭 (原: 开启, 代理地址: " + $oldPS + ")")
    $rb += "New-ItemProperty -Path '$reg' -Name 'ProxyEnable' -PropertyType DWord -Value $oldPE -Force | Out-Null"
    if ($oldPS) { $rb += "Set-ItemProperty -Path $(Q $reg) -Name $(Q 'ProxyServer') -Value $(Q $oldPS)" }
    if ($oldAC) { $rb += "Set-ItemProperty -Path $(Q $reg) -Name $(Q 'AutoConfigURL') -Value $(Q $oldAC)" }
} else {
    Log "  [跳过] 系统代理已是关闭状态"
}

# 2.2 DNS 设置为 阿里+腾讯 公共DNS(可回滚)
$adapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'Realtek|Intel' } | Select-Object -First 1
if ($adapter) {
    $oldDns = @((Get-DnsClientServerAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses @('223.5.5.5','119.29.29.29') -ErrorAction SilentlyContinue
    Log ("  [修改] " + $adapter.Name + " 的 DNS 已设为 223.5.5.5 / 119.29.29.29")
    if ($oldDns -and $oldDns.Count -gt 0 -and $oldDns[0]) {
        $dnsList = $oldDns -join "','"
        $rb += "Set-DnsClientServerAddress -InterfaceAlias '$($adapter.Name)' -ServerAddresses @('$dnsList')"
    } else {
        $rb += "Set-DnsClientServerAddress -InterfaceAlias '$($adapter.Name)' -ResetServerAddresses"
    }
} else {
    Log "  [跳过] 未找到活动网卡, DNS 未修改"
}
ipconfig /flushdns | Out-Null
Log "  [完成] DNS 缓存已刷新"

# ============ 3. 启动项优化 ============
Log ""
Log "[3/6] 禁用非必要开机启动项（全部可回滚）"
$runKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
$targets = 'BaiduYunDetect|Veee|QuarkUpdater|qianwen|Qianwen|汽水音乐|SodaMusic|kwallpaper|EdgeAutoLaunch|QQNT'
$disabled = @()
foreach ($k in $runKeys) {
    if (-not (Test-Path $k)) { continue }
    $props = Get-ItemProperty $k -ErrorAction SilentlyContinue
    foreach ($pn in $props.PSObject.Properties.Name) {
        if ($pn -match $targets) {
            $val = $props.$pn
            $rb += "New-ItemProperty -Path $(Q $k) -Name $(Q $pn) -PropertyType String -Value $(Q $val) -Force | Out-Null"
            Remove-ItemProperty -Path $k -Name $pn -ErrorAction SilentlyContinue
            $disabled += $pn
            Log ("  [禁用] 启动项: " + $pn)
        }
    }
}
if ($disabled.Count -eq 0) { Log "  [跳过] 未发现需要禁用的启动项" }
$rb += "Write-Host '启动项已恢复'"

# ============ 4. 游戏体验优化 ============
Log ""
Log "[4/6] 游戏体验优化（关闭后台录屏 + 高性能电源计划，可回滚）"

# 4.1 关闭 Game Bar 后台录屏
$gdc = 'HKCU:\System\GameConfigStore'
$gdv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
if (Test-Path $gdc) {
    $oldG = (Get-ItemProperty $gdc -ErrorAction SilentlyContinue).GameDVR_Enabled
    if ($oldG -ne 0) {
        Set-ItemProperty $gdc -Name GameDVR_Enabled -Value 0 -ErrorAction SilentlyContinue
        $rb += "Set-ItemProperty -Path '$gdc' -Name 'GameDVR_Enabled' -Value $oldG -ErrorAction SilentlyContinue"
        Log "  [修改] 已关闭 Game Bar 后台录屏(降低游戏时CPU/GPU占用)"
    } else { Log "  [跳过] Game Bar 录屏已是关闭状态" }
}
if (Test-Path $gdv) {
    $oldA = (Get-ItemProperty $gdv -ErrorAction SilentlyContinue).AppCaptureEnabled
    if ($oldA -ne 0) {
        Set-ItemProperty $gdv -Name AppCaptureEnabled -Value 0 -ErrorAction SilentlyContinue
        $rb += "Set-ItemProperty -Path '$gdv' -Name 'AppCaptureEnabled' -Value $oldA -ErrorAction SilentlyContinue"
    }
}

# 4.2 高性能电源计划(台式机建议)
$curScheme = ((powercfg /getactivescheme) | Select-Object -First 1) -replace '.*\(([0-9a-fA-F\-]+)\)\s*$','$1'
if ($curScheme -eq '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c') {
    Log "  [跳过] 电源计划已是“高性能”"
} else {
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    if ($LASTEXITCODE -eq 0) {
        Log "  [修改] 电源计划已切换为“高性能”(原: $curScheme)"
        $rb += "powercfg /setactive $curScheme"
    } else {
        Log "  [提示] 高性能电源计划切换失败(可能被策略限制), 保持原计划"
    }
}

# ============ 5. 写回滚脚本 ============
Log ""
Log "[5/6] 生成回滚脚本"
$rb += ""
$rb += "Write-Host '=== 回滚完成 ==='"
$rb | Set-Content -Path $rollback -Encoding UTF8
Log ("  回滚脚本已生成: " + $rollback)

# ============ 6. 汇总 ============
$diskAfter = (Get-PSDrive C).Free
Log ""
Log "[6/6] 优化完成汇总"
Log ("C 盘可用空间: " + [math]::Round($diskBefore/1GB,1) + " GB -> " + [math]::Round($diskAfter/1GB,1) + " GB")
Log ("本次清理共释放约: " + [math]::Round($totalFreed/1MB,1) + " MB (文件已移入回收站, 可恢复)")
Log ""
Log "注意事项:"
Log " 1. 清理的缓存文件已移入回收站; 确认游戏稳定运行后可手动清空回收站"
Log " 2. 代理/DNS/启动项/录屏/电源 的修改可用 rollback_optimize.ps1 一键撤销"
Log " 3. 显卡驱动 560.94 偏旧, 建议到 NVIDIA 官网更新最新驱动: https://www.nvidia.cn/drivers/"
Log " 4. 打游戏前请运行【游戏模式】; 游戏期间请勿开启 Veee 等代理软件"
Log " 5. 若你玩的是国际服需要加速器, 请使用正规游戏加速器(如UU/奇游)而非翻墙代理"
$lines | Set-Content -Path $report -Encoding UTF8
Write-Host ""
Write-Host ("完整报告已保存: " + $report)
Write-Host ""
Read-Host "按回车键关闭窗口"
