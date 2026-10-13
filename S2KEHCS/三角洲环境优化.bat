@echo off
chcp 65001 >nul
title 三角洲行动 游戏环境优化工具
color 0A
echo ==============================================
echo    三角洲行动 游戏环境优化工具
echo ==============================================
echo.
echo  [1] 深度优化   - 清理缓存/网络DNS/关闭代理/禁用多余启动项
echo                  (需要管理员权限, 会弹出UAC请点"是")
echo  [2] 游戏模式   - 打游戏前运行: 关闭代理+退出后台程序
echo  [3] 恢复模式   - 打完游戏运行: 恢复系统代理
echo  [4] 环境体检   - 生成当前环境与反作弊风险报告
echo  [0] 退出
echo.
set /p sel=请输入选项数字并回车: 

if "%sel%"=="1" goto optimize
if "%sel%"=="2" goto gamemode
if "%sel%"=="3" goto restore
if "%sel%"=="4" goto report
if "%sel%"=="0" exit
echo 输入无效，请重新运行本工具
pause
exit

:optimize
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0optimize.ps1"
exit

:gamemode
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0gamemode.ps1"
exit

:restore
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore.ps1"
exit

:report
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0report.ps1"
exit
