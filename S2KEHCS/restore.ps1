# ============================================================
#  三角洲行动 恢复模式脚本 (restore.ps1)
#  用法: 打完游戏后运行(双击BAT菜单选3)
#  作用: 恢复【游戏模式】关闭前的系统代理设置
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$proxyFile = Join-Path $scriptDir 'state\proxy_backup.txt'
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'

Write-Host "=============================================="
Write-Host " 三角洲行动 恢复模式"
Write-Host "=============================================="

if (Test-Path $proxyFile) {
    $vals = @(Get-Content $proxyFile)
    if ($vals.Count -ge 1 -and $vals[0] -ne '') { Set-ItemProperty $reg -Name ProxyEnable -Value ([int]$vals[0]) }
    if ($vals.Count -ge 2 -and $vals[1]) { Set-ItemProperty $reg -Name ProxyServer -Value $vals[1] }
    if ($vals.Count -ge 3 -and $vals[2]) { Set-ItemProperty $reg -Name AutoConfigURL -Value $vals[2] }
    Write-Host ("[OK] 系统代理已恢复: 启用状态=" + $vals[0] + ", 代理地址=" + $vals[1])
    Remove-Item $proxyFile -ErrorAction SilentlyContinue
    Write-Host "[OK] 代理备份已清除"
} else {
    Write-Host "[跳过] 未找到代理备份(可能没运行过游戏模式，或已恢复过)"
}

Write-Host ""
Write-Host "提示: 深度优化(清理/启动项/DNS)的撤销请以管理员运行 rollback_optimize.ps1"
Write-Host ""
Read-Host "按回车键退出"
