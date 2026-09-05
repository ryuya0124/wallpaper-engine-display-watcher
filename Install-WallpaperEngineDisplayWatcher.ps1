param([string]$WatcherPath='C:\Program Files\WallpaperEngineDisplayWatcher\WallpaperEngineDisplayWatcher.exe')
$ErrorActionPreference='Stop'
if(-not (Test-Path -LiteralPath $WatcherPath -PathType Leaf)){throw "Watcher not found: $WatcherPath"}
$shortcutPath=Join-Path ([Environment]::GetFolderPath('Startup')) 'Wallpaper Engine Display Watcher.lnk'
$powerShell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$shell=New-Object -ComObject WScript.Shell
$shortcut=$shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath=$WatcherPath
$shortcut.Arguments=''
$shortcut.WorkingDirectory=Split-Path -Parent $WatcherPath
$shortcut.Description='Stop Wallpaper Engine on display off and restart it on display on'
$shortcut.Save()
Write-Host "Startup shortcut created: $shortcutPath"
Write-Host 'The watcher will start automatically at the next logon.'
