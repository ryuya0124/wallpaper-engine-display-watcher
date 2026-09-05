param([string]$OutputDirectory = (Join-Path $PSScriptRoot 'dist'))
$ErrorActionPreference = 'Stop'
$directory = $PSScriptRoot
$script = Get-Content -LiteralPath (Join-Path $directory 'WallpaperEngineDisplayWatcher.ps1') -Raw
$match = [regex]::Match($script, '(?s)\$source = @''\r?\n(.*?)\r?\n''@')
if (-not $match.Success) { throw 'Watcher source block not found.' }
$entry = @'
public static class BackgroundEntry {
  [System.STAThread]
  public static void Main() {
    string directory = System.IO.Path.Combine(System.Environment.GetFolderPath(System.Environment.SpecialFolder.LocalApplicationData), "WallpaperEngineDisplayWatcher");
    System.IO.Directory.CreateDirectory(directory);
    string log = System.IO.Path.Combine(directory, "watcher.log");
    try {
      WallpaperEnginePowerWatcher.Runner.Run(@"C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe", log, 3);
    } catch (System.Exception ex) {
      System.IO.File.AppendAllText(log, System.DateTime.Now.ToString("o") + " Background watcher failed: " + ex.ToString() + System.Environment.NewLine);
    }
  }
}
'@
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
Add-Type -TypeDefinition ($match.Groups[1].Value + [Environment]::NewLine + $entry) -ReferencedAssemblies 'System.dll','System.Drawing.dll','System.Windows.Forms.dll' -OutputAssembly (Join-Path $OutputDirectory 'WallpaperEngineDisplayWatcher.exe') -OutputType WindowsApplication
