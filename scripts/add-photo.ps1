# Pick a menu photo from your computer and wire it into the site.
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\add-photo.ps1
#
# Pops up a file picker, then a slot picker (torpedo / pizza / etc.),
# copies the file into assets\menu\<slot>.<ext>, and re-runs the generator.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

$root      = Split-Path -Parent $PSScriptRoot
$menuDir   = Join-Path $root "assets\menu"
$generator = Join-Path $PSScriptRoot "generate.ps1"

if (-not (Test-Path $menuDir)) { New-Item -ItemType Directory -Path $menuDir -Force | Out-Null }

# 1. File picker
$dlg = New-Object System.Windows.Forms.OpenFileDialog
$dlg.Title  = "Pick a menu photo"
$dlg.Filter = "Images (*.jpg, *.jpeg, *.png, *.webp)|*.jpg;*.jpeg;*.png;*.webp|All files (*.*)|*.*"
$dlg.InitialDirectory = [Environment]::GetFolderPath("MyPictures")
if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
  Write-Host "Cancelled."
  exit
}
$source = $dlg.FileName
Write-Host "Picked: $source"

# 2. Slot picker
$choices = @(
  @{ key = "1"; slot = "torpedo";      label = "Torpedo Subs" },
  @{ key = "2"; slot = "pizza";        label = "Detroit Square Pizza" },
  @{ key = "3"; slot = "party-shoppe"; label = "Party Shoppe" },
  @{ key = "4"; slot = "catering";     label = "Catering & Trays" }
)

Write-Host ""
Write-Host "Which menu card is this photo for?"
foreach ($c in $choices) { Write-Host "  $($c.key)) $($c.label)  -> assets\menu\$($c.slot).<ext>" }
Write-Host ""

$pick = Read-Host "Enter 1, 2, 3, or 4"
$choice = $choices | Where-Object { $_.key -eq $pick.Trim() }
if (-not $choice) {
  Write-Host "Unrecognized choice. Aborting."
  exit
}

# 3. Copy
$ext  = [System.IO.Path]::GetExtension($source).ToLower().TrimStart('.')
if ([string]::IsNullOrEmpty($ext)) { $ext = "jpg" }
# Remove any existing photo for this slot (any extension)
Get-ChildItem -Path $menuDir -Filter "$($choice.slot).*" -ErrorAction SilentlyContinue | Remove-Item -Force
$dest = Join-Path $menuDir "$($choice.slot).$ext"
Copy-Item -LiteralPath $source -Destination $dest -Force
$kb = [math]::Round((Get-Item $dest).Length / 1KB, 1)
Write-Host "[ok] Saved $dest ($kb KB)"

# 4. Regenerate
Write-Host ""
Write-Host "Regenerating site..."
& powershell -ExecutionPolicy Bypass -File $generator
Write-Host ""
Write-Host "Done. Refresh http://localhost:8080/ to see it."
