# Defining variables.
$LocalPath = "C:\Program Files\yourOrg\LSInfo"

# Get device info to include in lock screen image
$IsVirtual = ((Get-WmiObject Win32_ComputerSystem).model).Contains("Virtual")
$CimSession = New-CimSession
$DeviceSerial = (Get-CimInstance -CimSession $CimSession -Class Win32_BIOS).SerialNumber
$ComputerName = $env:computername
$CurrentBuild = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Get-ItemPropertyValue -Name "CurrentBuild"
if ($CurrentBuild -gt 20000) {$WindowsVersion = "11"} else {$WindowsVersion = "10"} 
$ReleaseID = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Get-ItemPropertyValue -Name "ReleaseID"
$OSInformation = if ($ReleaseID -gt 2004) {Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Get-ItemPropertyValue -Name "DisplayVersion"} else {$ReleaseID} 
$OSVersion = "Windows $WindowsVersion ($OSInformation)"

# Store data in variable to pass to image creation
if ($IsVirtual) {
    $DeviceInfo = ([ordered]@{
        Host = $ComputerName
        OS = $OSVersion
    })
} else {
    $DeviceInfo = ([ordered]@{
        Serial = $DeviceSerial
        Host = $ComputerName
        OS = $OSVersion
    })
}

# If needed, generate serial number QR code
$QRCode = "$LocalPath\$DeviceSerial.png"
if (Test-Path -Path $QRCode) {
    Write-Output "Correct QR code already exists."
} else {
    Write-Output "Generating QR code..."
    & "$LocalPath\scripts\New-QRCodeSerial.ps1" -DeviceSerial $DeviceSerial -QRCode $QRCode
}

# Generate lock screen info image
& "$LocalPath\scripts\New-LSInfoImage.ps1" -SourcePath "$LocalPath\images" -OutputImage "$LocalPath\lock_bg.jpg" -DeviceInfo $DeviceInfo -QRCode $QRCode