# Wallpaper Engine Display Watcher

Windowsのディスプレイ電源通知を受け、画面OFFから3秒後にWallpaper Engineへ終了要求を送り、画面ONで再起動します。監視側が終了させた場合だけ再起動します。

`WallpaperEngineDisplayWatcher.ps1` に監視処理のC#ソースを含みます。`Build-WallpaperWatcher.ps1` はそれをコンソールを持たないWindowsアプリEXEへコンパイルします。EXEはGitに含めません。

## ビルドと設置

Windows PowerShell 5.1で実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-WallpaperWatcher.ps1
```

生成物は `dist\WallpaperEngineDisplayWatcher.exe`。管理者権限で `C:\Program Files\WallpaperEngineDisplayWatcher\` にコピーします。更新時は既存の監視EXEを停止してからコピーしてください。

通常ユーザーで `Install-WallpaperEngineDisplayWatcher.ps1` を実行すると、ログイン時にEXEを起動するスタートアップショートカットを登録します。即時起動は設置したEXEを実行します。

Wallpaper Engineの既定パスは `C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe`。EXE版で変更する場合はビルドスクリプト内のパスを変更して再ビルドします。

ログは `%LOCALAPPDATA%\WallpaperEngineDisplayWatcher\watcher.log`。`Uninstall-WallpaperEngineDisplayWatcher.ps1` は自動起動の登録を解除して監視を停止します。インストールしたファイルは残します。

画面通知用の非表示ウィンドウを使用します。ターミナルは不要です。自動起動はユーザーのログイン時です。
