# BlakeLets user easily add printers using a batch file. - Blake

# Paths
$user        = (Get-WmiObject -Class Win32_ComputerSystem).UserName
$username    = $user.Split('\')[-1]
$desktop     = "C:\Users\$username\Desktop"
$batPath     = Join-Path $desktop "Add A Printer.bat"
$ps1Folder   = "C:\PrinterScript"
$ps1Path     = Join-Path $ps1Folder "Add-A-Printer.ps1"

# Ensure the C:\PrinterScript folder exists
if (-not (Test-Path $ps1Folder)) {
    New-Item -Path $ps1Folder -ItemType Directory -Force | Out-Null
}

# PowerShell logic file content
$ps1Content = @'
function Add-NetworkPrinter {
    param ([string]$printerName, [string]$printerIP, [string]$driverName)

    $portName = "IP_$printerIP"

    try {
        if (-not (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue)) {
            Write-Host "[INFO] Creating port $portName for IP $printerIP..."
            Add-PrinterPort -Name $portName -PrinterHostAddress $printerIP -ErrorAction Stop
        } else {
            Write-Host "[INFO] Port $portName already exists."
        }

        if (-not (Get-Printer -Name $printerName -ErrorAction SilentlyContinue)) {
            Write-Host "[INFO] Adding printer $printerName..."
            Add-Printer -Name $printerName -DriverName $driverName -PortName $portName -ErrorAction Stop
            Write-Host "[SUCCESS] Printer $printerName added successfully!"
        } else {
            Write-Host "[INFO] Printer $printerName already exists."
        }

    } catch {
        Write-Host ""
        Write-Host "[ERROR] Something went wrong. Please contact IT."
        Write-Host "Details: $($_.Exception.Message)"
    }
}

$driverMap = @{
    "1" = "HP Universal Printing PCL 5"
    "2" = "ZDesigner GX420D"
    "3" = "Zebra ZP 500 (ZPL)"
    "4" = "Microsoft Enhanced Point and Print Compatibility Driver"
}

Write-Host ""
Write-Host "[MENU] What type of printer are you adding?"
Write-Host "[1] HP"
Write-Host "[2] ZDesigner"
Write-Host "[3] Zebra (generic)"
Write-Host "[4] Other (generic)"
$choice = Read-Host "Enter the number of the printer type [1-4]"

$driverName = $driverMap[$choice]
if (-not $driverName) {
    Write-Host "[WARN] Invalid choice. Defaulting to Zebra Printer driver."
    $driverName = $driverMap["2"]
}

Write-Host ""
Write-Host "If you don't know how to get your printer's IP address!"
Write-Host "If it's a label printer try holding down the print button until you see the light blink once."
Write-Host "It should then print a label telling you the IP towards the top!"
Write-Host ""
$printerIP = Read-Host "Enter the printer's IP address (e.g. 192.168.1.123)"
$printerName = Read-Host "Enter a name for this printer (e.g. 'Shipping Label')"

Add-NetworkPrinter -printerName $printerName -printerIP $printerIP -driverName $driverName

Write-Host ""
Read-Host "Press Enter to close..."
'@

# Write the .ps1 logic file first
try {
    Set-Content -Path $ps1Path -Value $ps1Content -Encoding UTF8 -Force
    Start-Sleep -Seconds 1
} catch {
    Write-Host "[ERROR] Failed to write PowerShell logic script."
    exit 1
}

if (-not (Test-Path $ps1Path)) {
    Write-Host "[ERROR] PowerShell script path is missing after creation."
    exit 1
}

# Now generate the .bat file with the hardcoded PS1 path
$batContent = @"
@echo off
if not exist "$ps1Path" (
    echo [ERROR] Script not found: $ps1Path
    pause
    exit /b 1
)
PowerShell -ExecutionPolicy Bypass -NoProfile -File "$ps1Path"
pause
"@

try {
    Set-Content -Path $batPath -Value $batContent -Encoding ASCII -Force
    Write-Host "[SUCCESS] Deployment complete:"
    Write-Host "         - Desktop Shortcut: $batPath"
    Write-Host "         - Script Location:  $ps1Path"
} catch {
    Write-Host "[ERROR] Failed to write batch launcher to desktop."
}
