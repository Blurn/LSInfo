[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter(Mandatory=$True)] [String] $SourcePath = "",
    [Parameter(Mandatory=$True)] [String] $QRCode = "",
    [Parameter(Mandatory=$True)] [object] $DeviceInfo,
    [Parameter(Mandatory=$True)] [String] $OutputImage = ""
)

# Load assemblies
[system.reflection.assembly]::loadWithPartialName('system') | out-null
[system.reflection.assembly]::loadWithPartialName('system.drawing') | out-null
[system.reflection.assembly]::loadWithPartialName('system.drawing.imaging') | out-null
[system.reflection.assembly]::loadWithPartialName('system.windows.forms') | out-null

# Function to generate image - the original version of this script by Travis Hardiman (dieseltravis) can be found here: https://gist.github.com/dieseltravis/3066def0ddaf7a8a0b6d?permalink_comment_id=4198305
Function New-ImageInfo {
    param(  
        [Parameter(Mandatory=$True, Position=1)] [object] $data,
        [Parameter(Mandatory=$True)] [string] $in,
        [float] $size=12.0,
        [float] $textPaddingLeft = 0,
        [float] $textPaddingTop = 0,
        [float] $textItemSpace = 0,
        [string] $out="out.jpeg" 
    )

    $foreBrush  = [System.Drawing.Brushes]::White
    $backBrush  = new-object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(192, 0, 0, 0))

    # Create Bitmap
    $SR = . "$LocalPath\scripts\Get-PrimaryDisplayResolution.ps1"
    $background = new-object system.drawing.bitmap($SR.Width, $SR.Height)
    $bmp = new-object system.drawing.bitmap -ArgumentList $in

    # Create Graphics
    $image = [System.Drawing.Graphics]::FromImage($background)
    $Image.SmoothingMode = "AntiAlias"
    $Image.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Image.TextRenderingHint = "ClearType"

    # Paint image's background
    $rect = new-object system.drawing.rectanglef(0, 0, $SR.width, $SR.height)
    $image.FillRectangle($backBrush, $rect)

    # add in image
    $topLeft = new-object System.Drawing.RectangleF(0, 0, $SR.Width, $SR.Height)
    $image.DrawImage($bmp, $topLeft)

    # Load QR Code
    $OverlayQRCode = [System.Drawing.Image]::FromFile($QRCode)

    # Draw string
    $strFrmt = new-object system.drawing.stringformat
    $strFrmt.Alignment = [system.drawing.StringAlignment]::Near
    $strFrmt.LineAlignment = [system.drawing.StringAlignment]::Near

    # first get max key & val widths
    $maxKeyWidth = 0
    $maxValWidth = 0
    $textBgHeight = 0
    $textBgWidth = 0

    # a reversed ordered collection is used since it starts from the bottom
    $reversed = [ordered]@{}

    foreach ($h in $data.GetEnumerator()) {
        $valString = "$($h.Value)"
        $valFont = New-Object System.Drawing.Font("Consolas", $size, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
        $valSize = [system.windows.forms.textrenderer]::MeasureText($valString, $valFont) 
        $maxValWidth = [math]::Max($maxValWidth, $valSize.Width) + 15

        $keyString = "$($h.Name) "
        $keyFont = New-Object System.Drawing.Font("Input", $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
        $keySize = [system.windows.forms.textrenderer]::MeasureText($keyString, $keyFont)
        $maxKeyWidth = [math]::Max($maxKeyWidth, $keySize.Width)

        $maxItemHeight = [math]::Max($valSize.Height, $keySize.Height)
        $textBgHeight += ($maxItemHeight + $textItemSpace)

        $reversed.Insert(0, $h.Name, $h.Value)
    }

    $textBgWidth = $maxKeyWidth + $maxValWidth + $textPaddingLeft
    $textBgHeight += $textPaddingTop + $OverlayQRCode.Height
    $textBgX = $SR.Width - $textBgWidth
    $textBgY = $SR.Height - $textBgHeight - (($SR.Height)*0.07)

    $textBgRect = New-Object System.Drawing.RectangleF($textBgX, $textBgY, $textBgWidth, $textBgHeight)
    $image.FillRectangle($backBrush, $textBgRect)

    $i = 0
    $cumulativeHeight = $SR.Height - (($SR.Height)*0.07)

    foreach ($h in $reversed.GetEnumerator()) {
        $valString = "$($h.Value)"
        $valFont = New-Object System.Drawing.Font("Consolas", $size, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
        $valSize = [system.windows.forms.textrenderer]::MeasureText($valString, $valFont)

        $keyString = "$($h.Name) "
        $keyFont = New-Object System.Drawing.Font("Input", $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point)
        $keySize = [system.windows.forms.textrenderer]::MeasureText($keyString, $keyFont)

        $maxItemHeight = [math]::Max($valSize.Height, $keySize.Height) + $textItemSpace

        $valX = $SR.Width - $maxValWidth
        $valY = $cumulativeHeight - $maxItemHeight

        $keyX = $valX - $maxKeyWidth
        $keyY = $valY
        
        $valRect = New-Object System.Drawing.RectangleF($valX, $valY, $maxValWidth, $valSize.Height)
        $keyRect = New-Object System.Drawing.RectangleF($keyX, $keyY, $maxKeyWidth, $keySize.Height)

        $cumulativeHeight = $valRect.Top

        $image.DrawString($keyString, $keyFont, $foreBrush, $keyRect, $strFrmt)
        $image.DrawString($valString, $valFont, $foreBrush, $valRect, $strFrmt)

        $i++
    }
    
    # Include QR code in image
    $QRCodeX = $textBgX + $textPaddingLeft
    $QRCodeY = $textBgY + 10
    $image.DrawImage($OverlayQRCode, $QRCodeX, $QRCodeY)
    $OverlayQRCode.Dispose()

    # Close Graphics
    $image.Dispose();

    # Save and close Bitmap
    $background.Save($out, [system.drawing.imaging.imageformat]::Jpeg);
    $background.Dispose();
    $bmp.Dispose();

    # Output file
    Get-Item -Path $out
}

# Randomly select image with matching aspect ratio
$CandidateImages = @()
$ScreenResolution = . "$LocalPath\scripts\Get-PrimaryDisplayResolution.ps1"
$ScreenAspectRatio = [math]::round($(($ScreenResolution.Width)/$($ScreenResolution.Height)), 2)
Get-ChildItem -Path "$SourcePath\*" -Include *.* | Select-Object Name,FullName,Directory | ForEach-Object {
    if ($_) {
        #Get the image
        $CandidateImage = [System.Drawing.Image]::FromFile($_.FullName)
        #Get aspect ratio
        $ImageAspectRatio = [math]::round(($($CandidateImage.Width)/$($CandidateImage.Height)), 2)
        $CandidateImages += if ($ImageAspectRatio -eq $ScreenAspectRatio) {
            $_.FullName
        }
        $CandidateImage.Dispose()
    }
}
$RandomImage = Get-Random -InputObject $CandidateImages

# Larger font size for high res. displays
if ($ScreenResolution.Height -gt "1440") {
    $FontSize = "20"
} else {
    $FontSize = "16"
}

# Create new lock screen image and save it to output folder
New-ImageInfo -in $RandomImage -out $OutputImage -data $DeviceInfo -size $FontSize -textPaddingLeft "15" -textPaddingTop "15" -textItemSpace "5" | Out-Null