# Wallpaper Engine Display Watcher

ディスプレイが消えたらWallpaper Engineを終了し、画面が戻ったら起動し直すWindows用のバックグラウンドツールです。

**PC本体をスリープさせず、画面OFF中のWallpaper Engineを止めたい場合**に使えます。生成したEXEはターミナル・タスクバーのウィンドウ・トレイアイコンを表示しません。

> Unofficial Windows utility that closes Wallpaper Engine when the display turns off and relaunches it when the display turns on. Runs in the background without a terminal window.

## 主な動作

- Windowsの画面OFF通知から3秒後に終了要求を送ります。待機中にONへ戻ればキャンセルします。
- 自分が終了要求を送った場合に、画面ONで `wallpaper64.exe -silent` を起動します。
- ログイン時の自動起動に対応します。
- 通知待ちで動作し、画面状態を定期ポーリングしません。

Wallpaper Engineの一時停止設定だけではGPUクロックが下がらない環境向けに作りました。**消費電力やGPUクロックの低下は保証しません。**他のアプリ・ドライバー・画面構成にも左右されるため、実測して確認してください。

Wallpaper Engine公式とは無関係の個人プロジェクトです。

## 動作条件

- Windowsのユーザーデスクトップセッション
- Windows PowerShell **5.1** (`powershell.exe`) と.NET Framework：ビルドに使用
- 64-bit版Wallpaper Engine (`wallpaper64.exe`)
- 壁紙と監視が同じユーザーセッションで動作すること

Windows 11の実機で起動と画面通知の受信を確認しています。ほかのWindowsバージョン、リモートデスクトップ、複数ユーザー構成での動作は未検証です。

`WallpaperEngineDisplayWatcher.ps1` に監視処理のC#ソースを含みます。`Build-WallpaperWatcher.ps1` はそれをコンソールを持たないWindowsアプリEXEへコンパイルします。EXEはGitに含めません。

## ビルドと設置

まずソースを取得します（Gitが必要です）。

```powershell
git clone https://github.com/ryuya0124/wallpaper-engine-display-watcher.git
cd wallpaper-engine-display-watcher
```

ビルド前にWallpaper Engineのインストール先を確認してください。既定パスと違う場合は、下記「設定」のとおり変更します。

Windows PowerShell 5.1でビルドします。PowerShell 7の `pwsh.exe` ではなく、次のコマンドを使用してください。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-WallpaperWatcher.ps1
```

生成物は `dist\WallpaperEngineDisplayWatcher.exe` です。未署名のEXEで、Gitには含めません。`ExecutionPolicy Bypass` はこの実行だけに適用され、マシン全体の実行ポリシーは変更しません。

通常ユーザーで、管理者権限なしの設置・自動起動登録ができます。

```powershell
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\WallpaperEngineDisplayWatcher'
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
Copy-Item .\dist\WallpaperEngineDisplayWatcher.exe -Destination $installDir
$watcherExe = Join-Path $installDir 'WallpaperEngineDisplayWatcher.exe'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-WallpaperEngineDisplayWatcher.ps1 -WatcherPath $watcherExe
Start-Process -FilePath $watcherExe
```

`C:\Program Files\WallpaperEngineDisplayWatcher\` に置く場合は、ファイルの配置・更新に管理者権限が必要です。自動起動登録と起動は利用する通常ユーザーで行ってください。

通常ユーザーで `Install-WallpaperEngineDisplayWatcher.ps1` を実行すると、ログイン時にEXEを起動するスタートアップショートカットを登録します。即時起動は設置したEXEを実行します。

## 設定

Wallpaper Engineの既定パスは `C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe` です。

別のSteamライブラリにある場合は、`Build-WallpaperWatcher.ps1` の `Runner.Run(...)` にあるパスを変更してビルドしてください。同じ呼び出しの最後の `3` は画面OFF後の待機秒数です。現在のEXEに設定画面やパス指定のコマンドラインオプションはありません。

既存の出力EXEがあると再ビルドに失敗する場合は、別の出力先を指定できます。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-WallpaperWatcher.ps1 -OutputDirectory .\dist-new
```

ログは `%LOCALAPPDATA%\WallpaperEngineDisplayWatcher\watcher.log`。`Uninstall-WallpaperEngineDisplayWatcher.ps1` は自動起動の登録を解除して監視を停止します。インストールしたファイルは残します。

画面通知用の非表示ウィンドウを使用します。ターミナルは不要です。自動起動はユーザーのログイン時です。

## 動作確認

```powershell
Get-Process WallpaperEngineDisplayWatcher -ErrorAction SilentlyContinue
Get-Content "$env:LOCALAPPDATA\WallpaperEngineDisplayWatcher\watcher.log" -Tail 20
```

壁紙を動かした状態で、Windowsの設定によるディスプレイOFFを待ち、マウスやキーボードで復帰します。ログには次のイベントが記録されます。

```text
Watcher started: ...
Display OFF detected.
Requested graceful Wallpaper Engine shutdown.
Display ON detected.
Wallpaper Engine restarted.
```

`Requested graceful...` は終了要求を送った記録で、終了完了の保証ではありません。ログの自動ローテーション機能はありません。

## 内部の仕組み

1. 非表示ウィンドウを作成し、`RegisterPowerSettingNotification` で `GUID_CONSOLE_DISPLAY_STATE` を購読します。
2. `WM_POWERBROADCAST` のOFF通知で3秒のタイマーを開始します。
3. まだOFFなら、`wallpaper64` のウィンドウへ `WM_CLOSE` を送ります。
4. ON通知で、自分が終了要求を送っていればWallpaper Engineを起動します。終了処理中なら1秒後に再確認します。

ビルド時にはPS1内のC#監視コードへエントリーポイントを追加し、コンソールを持たない `WindowsApplication` 形式にコンパイルします。

## 制約

- モニターの物理電源ボタンや複数画面のうち1枚だけのOFFが、WindowsのOFF通知につながるとは限りません。
- DIM（減光）だけでは終了しません。PCのスリープ・GPU性能・電源プランの設定は変更しません。
- Wallpaper Engineの強制終了は行いません。終了対象のウィンドウがない場合やアプリが終了要求に応じない場合は、壁紙が動き続けることがあります。
- 画面OFFより前に手動終了した壁紙は通常再起動しません。ただし終了要求後のユーザー操作まで区別する仕組みではありません。
- 再起動の要否はメモリ上の状態です。壁紙を終了させた後に監視自体を止めると、その情報は失われます。必要なら壁紙を手動で起動してください。
- 同一セッションの重複起動を抑制するMutexを使っています。繰り返し起動する必要はありません。
- `wallpaper32.exe` は対象外です。

## 停止・更新・アンインストール

一時停止するには以下を実行します。スタートアップ登録は残ります。

```powershell
Get-Process WallpaperEngineDisplayWatcher -ErrorAction SilentlyContinue | Stop-Process
```

更新は `git pull` → 別出力先で再ビルド → 監視停止 → 設置先のEXEを置換 → 起動、の順です。同じ設置先なら自動起動の再登録は不要です。

自動起動の解除と監視停止：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-WallpaperEngineDisplayWatcher.ps1
```

この操作は旧PowerShell版の監視も停止します。EXE・ソース・ログは残るので、不要なら自分で設置したフォルダから削除してください。

スタートアップのリンクは `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Wallpaper Engine Display Watcher.lnk` に作成されます。

## トラブルシューティング

| 症状 | 確認箇所 |
| --- | --- |
| ターミナルが表示される | スタートアップのリンク先がPS1やPowerShellではなく、生成EXEになっているか確認してください。 |
| 壁紙が再起動しない | ビルド時の壁紙パスとログの `Restart failed` を確認してください。 |
| 画面OFFでも停止しない | `Display OFF detected` の有無を確認。`No target window found` は終了対象のウィンドウを取得できなかったことを示します。 |
| 起動したか分からない | トレイアイコンはありません。プロセスとログで確認してください。 |
| ビルドできない | Windows PowerShell 5.1を使用し、別の出力先を試してください。 |

## ファイル構成

| ファイル | 役割 |
| --- | --- |
| `WallpaperEngineDisplayWatcher.ps1` | C#監視ソースを含む元スクリプト |
| `Build-WallpaperWatcher.ps1` | バックグラウンドEXEのビルド |
| `Install-WallpaperEngineDisplayWatcher.ps1` | ログイン時の自動起動登録 |
| `Uninstall-WallpaperEngineDisplayWatcher.ps1` | 自動起動解除と監視停止 |
| `dist/` | ビルド生成物（Git対象外） |
