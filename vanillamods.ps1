# Minecraft Mods and Resource Packs Installer
Write-Host "Starting Minecraft mods and resource packs installation..." -ForegroundColor Green

# Load required assembly for URL decoding
try {
    Add-Type -AssemblyName System.Web
}
catch {
    Write-Host "Warning: Could not load System.Web assembly for URL decoding. Using raw filenames." -ForegroundColor Yellow
}

# Define paths
$appdata = [Environment]::GetFolderPath("ApplicationData")
$minecraftPath = Join-Path $appdata ".minecraft"
$modsPath = Join-Path $minecraftPath "mods"
$resourcePacksPath = Join-Path $minecraftPath "resourcepacks"

# Single mod files (.jar) - direct download
$mods = @(
    # "https://example.com/mod1.jar",
    # "https://example.com/mod2.jar"
)

# ZIP files (Dropbox links recommended with ?dl=1) - will be extracted into mods folder
$modZips = @(
    "https://www.dropbox.com/scl/fi/30ugq0sdse94x2kud2ics/mods.zip?rlkey=gdfn0cdo1wq06ry7su8hugc9i&st=g7yh7jut&dl=1"
)

# Mods to remove if present (filenames)
$modsToRemove = @(
    # "badmod.jar",
    # "oldmod.jar"
)

# Resource packs (name + url pair)
$resourcePacks = @(
    # [PSCustomObject]@{Name="pack1.zip"; Url="https://..."}
)

# Resource packs to remove (just filenames)
$resourcePacksToRemove = @(
    # "uglypack.zip"
)

# ────────────────────────────────────────────────────────────────
# Function to decode URL-encoded filename
# ────────────────────────────────────────────────────────────────
function Get-DecodedFilename {
    param($url)
    try {
        $uri = [uri]$url
        $pathPart = $uri.AbsolutePath
        $fileName = Split-Path -Leaf $pathPart
        
        # Fallback if no filename in path (common with Dropbox)
        if ([string]::IsNullOrWhiteSpace($fileName) -or $fileName -eq '/') {
            $fileName = "downloaded_file.zip"  # or throw error, your choice
        }
        
        # Decode any URL encoding in the filename itself
        if ([Type]::GetType("System.Web.HttpUtility")) {
            $fileName = [System.Web.HttpUtility]::UrlDecode($fileName)
        }
        
        # Optional: Clean invalid filesystem characters
        $fileName = $fileName -replace '[<>:"/\\|?*]', '_'
        
        return $fileName
    }
    catch {
        Write-Host "Filename extraction failed for $url : $_ Using fallback name." -ForegroundColor Yellow
        return "modpack_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    }
}

# ────────────────────────────────────────────────────────────────
# Function to download a file
# ────────────────────────────────────────────────────────────────
function Download-File {
    param($url, $outputPath)
    try {
        Write-Host "Downloading $(Split-Path $outputPath -Leaf)..." -ForegroundColor Cyan
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
        Write-Host "Successfully downloaded $(Split-Path $outputPath -Leaf)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Error downloading $(Split-Path $outputPath -Leaf): $_" -ForegroundColor Red
        return $false
    }
}

# ────────────────────────────────────────────────────────────────
# Handle mods folder
# ────────────────────────────────────────────────────────────────
try {
    Write-Host "Checking for mods folder at $modsPath..." -ForegroundColor Yellow
    if (-not (Test-Path $modsPath)) {
        New-Item -Path $modsPath -ItemType Directory -Force | Out-Null
        Write-Host "Created mods folder" -ForegroundColor Green
    }

    # Remove unwanted mods
    foreach ($mod in $modsToRemove) {
        $filePath = Join-Path $modsPath $mod
        if (Test-Path $filePath) {
            Write-Host "Removing unwanted mod $mod..." -ForegroundColor Yellow
            Remove-Item -Path $filePath -Force
            Write-Host "Removed $mod" -ForegroundColor Green
        }
    }

    # 1. Download & install single .jar mods
    foreach ($mod in $mods) {
        $fileName = Get-DecodedFilename -url $mod
        $outputPath = Join-Path $modsPath $fileName
        if (Test-Path $outputPath) {
            Write-Host "Mod $fileName already exists, skipping..." -ForegroundColor Green
        }
        else {
            Download-File -url $mod -outputPath $outputPath | Out-Null
        }
    }

    # 2. Download & extract ZIP modpacks
    $tempFolder = Join-Path $env:TEMP "MinecraftModZips_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

    foreach ($zipUrl in $modZips) {
        $zipFileName = Get-DecodedFilename -url $zipUrl
        $tempZipPath = Join-Path $tempFolder $zipFileName

        Write-Host "Processing ZIP modpack: $zipFileName" -ForegroundColor Cyan

        if (-not (Download-File -url $zipUrl -outputPath $tempZipPath)) {
            Write-Host "Skipping failed ZIP download" -ForegroundColor Red
            continue
        }

        Write-Host "Extracting to mods folder..." -ForegroundColor Cyan
        try {
            Expand-Archive -Path $tempZipPath -DestinationPath $modsPath -Force -ErrorAction Stop
            Write-Host "Successfully extracted $zipFileName" -ForegroundColor Green
        }
        catch {
            Write-Host "Extraction failed for $zipFileName : $_" -ForegroundColor Red
        }

        # Clean up this ZIP
        Remove-Item $tempZipPath -Force -ErrorAction SilentlyContinue
    }

    # Final cleanup of temp folder
    Remove-Item $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "Error handling mods folder: $_" -ForegroundColor Red
    exit
}

# ────────────────────────────────────────────────────────────────
# Handle resource packs folder (unchanged)
# ────────────────────────────────────────────────────────────────
try {
    Write-Host "Checking for resource packs folder at $resourcePacksPath..." -ForegroundColor Yellow
    if (-not (Test-Path $resourcePacksPath)) {
        New-Item -Path $resourcePacksPath -ItemType Directory -Force | Out-Null
        Write-Host "Created resource packs folder" -ForegroundColor Green
    }

    foreach ($pack in $resourcePacksToRemove) {
        $filePath = Join-Path $resourcePacksPath $pack
        if (Test-Path $filePath) {
            Write-Host "Removing unwanted resource pack $pack..." -ForegroundColor Yellow
            Remove-Item -Path $filePath -Force
            Write-Host "Removed $pack" -ForegroundColor Green
        }
    }

    foreach ($pack in $resourcePacks) {
        $outputPath = Join-Path $resourcePacksPath $pack.Name
        if (Test-Path $outputPath) {
            Write-Host "Resource pack $($pack.Name) already exists, skipping..." -ForegroundColor Green
        }
        else {
            Download-File -url $pack.Url -outputPath $outputPath | Out-Null
        }
    }
}
catch {
    Write-Host "Error handling resource packs folder: $_" -ForegroundColor Red
    exit
}

Write-Host "Installation completed successfully!" -ForegroundColor Green
Write-Host "Press any key to exit..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")