$shortcutPath=Join-Path ([Environment]::GetFolderPath('Startup')) 'Wallpaper Engine Display Watcher.lnk'
if(Test-Path -LiteralPath $shortcutPath){Remove-Item -LiteralPath $shortcutPath -Force; Write-Host 'Startup shortcut removed.'}
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object {$_.CommandLine -like '*WallpaperEngineDisplayWatcher.ps1*'} |
  ForEach-Object {Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null}
Write-Host 'Watcher stopped. Wallpaper Engine was not changed.'
Get-Process -Name WallpaperEngineDisplayWatcher -ErrorAction SilentlyContinue | Stop-Process
