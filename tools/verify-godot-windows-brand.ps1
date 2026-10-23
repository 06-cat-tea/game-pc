param([string]$Binary = (Join-Path $PSScriptRoot '..\artifacts\godot\windows\灰烬边境.exe'))
$ErrorActionPreference = 'Stop'
$taskExe = (Resolve-Path -LiteralPath $Binary).Path
$taskArtifacts = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\artifacts\godot')).Path
$taskVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($taskExe)
if ($taskVersion.ProductName -ne '灰烬边境：星陨纪事') { throw 'Incorrect Windows product name' }
if ($taskVersion.FileDescription -ne '灰烬边境：星陨纪事 · 原生电脑版') { throw 'Incorrect Windows file description' }
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class AshenWindowIcon {
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr SendMessage(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", EntryPoint="GetClassLongPtrW")]
    public static extern IntPtr GetClassLongPtr(IntPtr hwnd, int index);
    private delegate bool EnumWindowProc(IntPtr hwnd, IntPtr param);
    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowProc callback, IntPtr param);
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int maxCount);
    public static IntPtr FindWindow(uint pid) {
        IntPtr found=IntPtr.Zero;
        EnumWindows((hwnd,param) => {
            uint owner; GetWindowThreadProcessId(hwnd,out owner);
            var title=new StringBuilder(512); GetWindowText(hwnd,title,512);
            if(owner==pid && title.ToString().Contains("\u7070\u70ec\u8fb9\u5883")) { found=hwnd; return false; }
            return true;
        },IntPtr.Zero);
        return found;
    }
}
'@
$taskOldAppData = $env:APPDATA
$taskProfile = Join-Path $taskArtifacts 'brand-runtime-profile'
New-Item -ItemType Directory -Path $taskProfile -Force | Out-Null
$env:APPDATA = $taskProfile
$taskProcess = $null
try {
    $taskProcess = Start-Process -FilePath $taskExe -ArgumentList @('--resolution','960x540') -WorkingDirectory (Split-Path $taskExe) -WindowStyle Hidden -PassThru
    for ($taskAttempt=0; $taskAttempt -lt 80; $taskAttempt++) {
        Start-Sleep -Milliseconds 100
        $taskProcess.Refresh()
        if ($taskProcess.HasExited) { throw 'Game exited before window icon inspection' }
        $taskHwnd = [AshenWindowIcon]::FindWindow($taskProcess.Id)
        if ($taskHwnd -ne [IntPtr]::Zero) { break }
    }
    if ($taskHwnd -eq [IntPtr]::Zero) { throw 'Game window was not created' }
    $taskIcon = [AshenWindowIcon]::SendMessage($taskHwnd,0x007F,[IntPtr]1,[IntPtr]::Zero)
    if ($taskIcon -eq [IntPtr]::Zero) { $taskIcon = [AshenWindowIcon]::SendMessage($taskHwnd,0x007F,[IntPtr]2,[IntPtr]::Zero) }
    if ($taskIcon -eq [IntPtr]::Zero) { $taskIcon = [AshenWindowIcon]::SendMessage($taskHwnd,0x007F,[IntPtr]0,[IntPtr]::Zero) }
    if ($taskIcon -eq [IntPtr]::Zero) { $taskIcon = [AshenWindowIcon]::GetClassLongPtr($taskHwnd,-14) }
    if ($taskIcon -eq [IntPtr]::Zero) { throw 'No runtime window/taskbar icon' }
    $taskBitmap = [Drawing.Icon]::FromHandle($taskIcon).ToBitmap()
    $taskIconPath = Join-Path $taskArtifacts 'windows-runtime-icon.png'
    $taskBitmap.Save($taskIconPath,[Drawing.Imaging.ImageFormat]::Png)
    $taskTitle = [Text.StringBuilder]::new(512)
    [AshenWindowIcon]::GetWindowText($taskHwnd,$taskTitle,512) | Out-Null
    $taskReport = [ordered]@{ passed=$true; binarySha256=(Get-FileHash -LiteralPath $taskExe -Algorithm SHA256).Hash; productName=$taskVersion.ProductName; fileDescription=$taskVersion.FileDescription; windowTitle=$taskTitle.ToString(); runtimeIcon=$taskIconPath; iconWidth=$taskBitmap.Width; iconHeight=$taskBitmap.Height }
    $taskBitmap.Dispose()
    $taskReport | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskArtifacts 'windows-brand-acceptance.json') -Encoding UTF8
    $taskReport | ConvertTo-Json
} finally {
    if ($taskProcess -and -not $taskProcess.HasExited) {
        if ($taskHwnd -ne [IntPtr]::Zero) { [AshenWindowIcon]::SendMessage($taskHwnd,0x0010,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null }
        if (-not $taskProcess.WaitForExit(5000)) { $taskProcess.Kill() }
    }
    $env:APPDATA = $taskOldAppData
}
