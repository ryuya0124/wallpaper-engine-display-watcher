param(
    [string]$WallpaperEnginePath = 'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine\wallpaper64.exe',
    [int]$OffDelaySeconds = 3,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $WallpaperEnginePath -PathType Leaf)) {
    throw "Wallpaper Engine が見つかりません: $WallpaperEnginePath"
}

$dataDirectory = Join-Path $env:LOCALAPPDATA 'WallpaperEngineDisplayWatcher'
$logPath = Join-Path $dataDirectory 'watcher.log'
New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null
Add-Type -AssemblyName System.Windows.Forms

$source = @'
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace WallpaperEnginePowerWatcher {
  public sealed class WatcherContext : ApplicationContext {
    const int WM_POWERBROADCAST=0x218, PBT_POWERSETTINGCHANGE=0x8013;
    const uint WM_CLOSE=0x10, DEVICE_NOTIFY_WINDOW_HANDLE=0;
    static readonly Guid DisplayGuid=new Guid("6FE69556-704A-47A0-8F24-C28D936FDA47");
    readonly string exe, log; readonly System.Windows.Forms.Timer timer; readonly PowerWindow window; readonly Mutex mutex;
    bool ownsMutex, stoppedByWatcher; int displayState=1;

    public WatcherContext(string exePath,string logPath,int delaySeconds) {
      exe=exePath; log=logPath;
      mutex=new Mutex(true,"Local\\WallpaperEngineDisplayWatcher",out ownsMutex);
      if(!ownsMutex) { WriteLog("Already running."); ExitThread(); return; }
      timer=new System.Windows.Forms.Timer(); timer.Interval=Math.Max(1,delaySeconds)*1000; timer.Tick+=OnTimer;
      window=new PowerWindow(OnDisplayState); WriteLog("Watcher started: "+exe);
    }
    void OnDisplayState(int state) {
      displayState=state;
      if(state==0) { WriteLog("Display OFF detected."); timer.Stop(); timer.Start(); }
      else if(state==1) { WriteLog("Display ON detected."); timer.Stop(); RestartIfNeeded(); }
      else WriteLog("Display DIM detected.");
    }
    void OnTimer(object sender,EventArgs e) { timer.Stop(); if(displayState==0) StopWallpaper(); }
    void StopWallpaper() {
      Process[] ps=Process.GetProcessesByName("wallpaper64");
      if(ps.Length==0) { WriteLog("Wallpaper Engine is already stopped."); return; }
      bool sent=false;
      foreach(Process p in ps) {
        int pid=p.Id;
        EnumWindows(delegate(IntPtr h,IntPtr l) { uint wp; GetWindowThreadProcessId(h,out wp);
          if(wp==(uint)pid) { PostMessage(h,WM_CLOSE,IntPtr.Zero,IntPtr.Zero); sent=true; } return true; },IntPtr.Zero);
      }
      if(sent) { stoppedByWatcher=true; WriteLog("Requested graceful Wallpaper Engine shutdown."); }
      else WriteLog("No target window found; refusing forced termination.");
    }
    void RestartIfNeeded() {
      if(!stoppedByWatcher) return;
      if(Process.GetProcessesByName("wallpaper64").Length!=0) {
        WriteLog("Shutdown still in progress; retrying in one second.");
        var retry=new System.Windows.Forms.Timer(); retry.Interval=1000; retry.Tick+=(s,e)=>{ retry.Stop(); retry.Dispose(); RestartIfNeeded(); }; retry.Start(); return;
      }
      try {
        var si=new ProcessStartInfo(exe,"-silent"); si.WorkingDirectory=Path.GetDirectoryName(exe); si.UseShellExecute=true;
        Process.Start(si); stoppedByWatcher=false; WriteLog("Wallpaper Engine restarted.");
      } catch(Exception ex) { WriteLog("Restart failed: "+ex.Message); }
    }
    void WriteLog(string s) { try { File.AppendAllText(log,DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")+"  "+s+Environment.NewLine); } catch {} }
    protected override void ExitThreadCore() {
      if(timer!=null) { timer.Stop(); timer.Dispose(); } if(window!=null) window.Dispose();
      if(ownsMutex) { mutex.ReleaseMutex(); ownsMutex=false; } if(mutex!=null) mutex.Dispose(); base.ExitThreadCore();
    }
    sealed class PowerWindow : NativeWindow,IDisposable {
      readonly Action<int> changed; IntPtr notification;
      public PowerWindow(Action<int> callback) { changed=callback; CreateHandle(new CreateParams()); Guid g=DisplayGuid;
        notification=RegisterPowerSettingNotification(Handle,ref g,DEVICE_NOTIFY_WINDOW_HANDLE);
        if(notification==IntPtr.Zero) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error()); }
      protected override void WndProc(ref Message m) {
        if(m.Msg==WM_POWERBROADCAST && m.WParam.ToInt32()==PBT_POWERSETTINGCHANGE && m.LParam!=IntPtr.Zero) {
          Guid g=(Guid)Marshal.PtrToStructure(m.LParam,typeof(Guid)); int len=Marshal.ReadInt32(m.LParam,16);
          if(g==DisplayGuid && len>=4) changed(Marshal.ReadInt32(m.LParam,20)); }
        base.WndProc(ref m);
      }
      public void Dispose() { if(notification!=IntPtr.Zero) UnregisterPowerSettingNotification(notification); DestroyHandle(); }
    }
    delegate bool EnumWindowsProc(IntPtr h,IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb,IntPtr l);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
    [DllImport("user32.dll",SetLastError=true)] static extern IntPtr RegisterPowerSettingNotification(IntPtr r,ref Guid g,uint f);
    [DllImport("user32.dll")] static extern bool UnregisterPowerSettingNotification(IntPtr h);
  }
  public static class Runner {
    public static void Run(string exe,string log,int delay) { Application.Run(new WatcherContext(exe,log,delay)); }
  }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies 'System.dll','System.Drawing.dll','System.Windows.Forms.dll'
if ($SelfTest) {
    Write-Host 'コンパイル成功'
    Write-Host "Wallpaper Engine: $WallpaperEnginePath"
    Write-Host "ログ: $logPath"
    exit 0
}
[WallpaperEnginePowerWatcher.Runner]::Run($WallpaperEnginePath,$logPath,$OffDelaySeconds)
