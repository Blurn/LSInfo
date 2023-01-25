# Much of this script is from David Segura - https://twitter.com/SeguraOSD - https://www.osdeploy.com/modules/pshot/technical/resolution-scale-and-dpi

function Get-DisplayPrimaryMonitorSize {
    [CmdletBinding()]
    param ()
  
    Add-Type -Assembly System.Windows.Forms
    Return ([System.Windows.Forms.SystemInformation]::PrimaryMonitorSize | Select-Object Width, Height)
}

function Get-DisplayPrimaryScaling {
    [CmdletBinding()]
    param ()

$SourceType = @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
 
public class DPI {
[DllImport("gdi32.dll")]
static extern int GetDeviceCaps(IntPtr hdc, int nIndex);
 
public enum DeviceCap {
VERTRES = 10,
DESKTOPVERTRES = 117
}
 
public static float scaling() {
Graphics g = Graphics.FromHwnd(IntPtr.Zero);
IntPtr desktop = g.GetHdc();
int LogicalScreenHeight = GetDeviceCaps(desktop, (int)DeviceCap.VERTRES);
int PhysicalScreenHeight = GetDeviceCaps(desktop, (int)DeviceCap.DESKTOPVERTRES);
 
return (float)PhysicalScreenHeight / (float)LogicalScreenHeight;
}
}
"@
    Add-Type -TypeDefinition $SourceType -ReferencedAssemblies 'System.Drawing.dll' -ErrorAction Stop
        Return [math]::round(([DPI]::scaling() * 100), 0)
    }

$GetDisplayPrimaryMonitorSize = Get-DisplayPrimaryMonitorSize
$GetDisplayPrimaryScaling = Get-DisplayPrimaryScaling
foreach ($Item in $GetDisplayPrimaryMonitorSize) {
    [int32]$Item.Width = [math]::round($(($Item.Width * $GetDisplayPrimaryScaling) / 100), 0)
    [int32]$Item.Height = [math]::round($(($Item.Height * $GetDisplayPrimaryScaling) / 100), 0)
}
Return $GetDisplayPrimaryMonitorSize