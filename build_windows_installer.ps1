$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterBin = "C:\Users\Administrator\flutter\bin\flutter.bat"

function Resolve-IsccPath {
    $command = Get-Command iscc -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

Push-Location $projectRoot
try {
    if (-not (Test-Path $flutterBin)) {
        $flutterBin = "flutter"
    }

    $iscc = Resolve-IsccPath
    if (-not $iscc) {
        throw "Inno Setup nao encontrado. Instale com: winget install JRSoftware.InnoSetup"
    }

    Write-Host "Resolvendo dependencias..."
    & $flutterBin pub get
    if ($LASTEXITCODE -ne 0) {
        throw "Falha no flutter pub get."
    }

    Write-Host "Gerando app Windows (release)..."
    & $flutterBin build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Falha no flutter build windows --release."
    }

    $versionMatch = Select-String -Path "pubspec.yaml" -Pattern "^\s*version:\s*([0-9]+\.[0-9]+\.[0-9]+)" | Select-Object -First 1
    $appVersion = if ($versionMatch -and $versionMatch.Matches.Count -gt 0) {
        $versionMatch.Matches[0].Groups[1].Value
    } else {
        "3.0.0"
    }

    Write-Host "Gerando instalador Inno Setup..."
    & $iscc "/DAppVersion=$appVersion" "$projectRoot\installer\SeverusBarberSetup.iss"
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao gerar instalador com Inno Setup."
    }

    $distDir = Join-Path $projectRoot "dist"
    $installer = Get-ChildItem $distDir -Filter "SeverusBarber-Setup-*.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($installer) {
        Write-Host "Instalador pronto: $($installer.FullName)"
    } else {
        Write-Host "Build concluido, mas nao foi possivel localizar o arquivo no dist."
    }
}
finally {
    Pop-Location
}
