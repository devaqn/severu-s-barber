$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$androidDir = Join-Path $projectRoot "android"
$flutterBin = "C:\Users\Administrator\flutter\bin\flutter.bat"
$jdkHome = "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
$gradleTmp = "C:\gradle-tmp"
$gradleUserHome = "C:\gradle-home"
$maxFlutterAttempts = 3
$maxFallbackAttempts = 3

function Ensure-Directory {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Invoke-CmdWithLog {
    param(
        [string]$CommandLine,
        [string]$LogFile
    )

    $wrapped = "$CommandLine > `"$LogFile`" 2>&1"
    cmd /c $wrapped
    $exitCode = $LASTEXITCODE

    $logLines = @()
    if (Test-Path $LogFile) {
        $logLines = Get-Content $LogFile
        $logLines | ForEach-Object { Write-Host $_ }
    }

    return @{
        ExitCode = $exitCode
        LogText = ($logLines | Out-String)
    }
}

function Stop-GradleInfrastructure {
    param([string]$ProjectRoot)

    $stopCmd = "`"$ProjectRoot\android\gradlew.bat`" --stop >nul 2>&1"
    cmd /c $stopCmd | Out-Null

    $gradleJava = Get-CimInstance Win32_Process -Filter "Name = 'java.exe' OR Name = 'javaw.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match "GradleDaemon|org\.gradle\.launcher\.daemon" }
    foreach ($proc in $gradleJava) {
        try {
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
        }
        catch {
            # Ignore processes that exited between query and stop.
        }
    }
}

function Sync-GradleApkToFlutterOutput {
    param([string]$ProjectRoot)

    $gradleApk = Join-Path $ProjectRoot "android\app\build\outputs\apk\release\app-release.apk"
    $flutterApkDir = Join-Path $ProjectRoot "build\app\outputs\flutter-apk"
    $flutterApk = Join-Path $flutterApkDir "app-release.apk"

    if (Test-Path $gradleApk) {
        Ensure-Directory -Path $flutterApkDir
        Copy-Item -Path $gradleApk -Destination $flutterApk -Force
        Write-Host "APK pronta em $flutterApk"
    }
}

if (-not (Test-Path $flutterBin)) {
    throw "Flutter nao encontrado em $flutterBin"
}

if (-not (Test-Path $jdkHome)) {
    throw "JDK 17 nao encontrado em $jdkHome"
}

Ensure-Directory -Path $gradleTmp
Ensure-Directory -Path $gradleUserHome

$env:JAVA_HOME = $jdkHome
if ($env:Path -notlike "*$jdkHome\bin*") {
    $env:Path = "$jdkHome\bin;$env:Path"
}
if ($env:Path -notlike "*C:\Users\Administrator\flutter\bin*") {
    $env:Path = "C:\Users\Administrator\flutter\bin;$env:Path"
}

$javaNetworkFlags = "-Djava.net.preferIPv4Stack=true -Djava.net.preferIPv6Addresses=false"
$env:JAVA_TOOL_OPTIONS = "$javaNetworkFlags -Djava.io.tmpdir=$gradleTmp"
$env:GRADLE_OPTS = "$javaNetworkFlags -Dorg.gradle.daemon=false -Dorg.gradle.vfs.watch=false"
$env:GRADLE_USER_HOME = $gradleUserHome
$env:TEMP = $gradleTmp
$env:TMP = $gradleTmp

Push-Location $projectRoot
try {
    Stop-GradleInfrastructure -ProjectRoot $projectRoot
    & $flutterBin clean
    & $flutterBin pub get

    $loopbackErrorDetected = $false
    $lastFlutterLog = $null

    for ($attempt = 1; $attempt -le $maxFlutterAttempts; $attempt++) {
        Write-Host "Tentativa ${attempt}/${maxFlutterAttempts}: flutter build apk --release"

        $logFile = Join-Path $gradleTmp "flutter-build-release-attempt-$attempt.log"
        $flutterCmd = "`"$flutterBin`" build apk --release"
        $result = Invoke-CmdWithLog -CommandLine $flutterCmd -LogFile $logFile
        $lastFlutterLog = $logFile

        if ($result.ExitCode -eq 0) {
            Write-Host "Build concluido com sucesso."
            exit 0
        }

        $loopbackError = $result.LogText -match "Unable to establish loopback connection"
        if (-not $loopbackError) {
            throw "Build falhou no flutter build. Veja o log: $logFile"
        }

        $loopbackErrorDetected = $true
        if ($attempt -lt $maxFlutterAttempts) {
            Write-Host "Erro de loopback detectado. Reiniciando infraestrutura Gradle..."
            Stop-GradleInfrastructure -ProjectRoot $projectRoot
            Start-Sleep -Seconds 3
            continue
        }
    }

    if (-not $loopbackErrorDetected) {
        throw "Build falhou sem erro de loopback conhecido. Ultimo log: $lastFlutterLog"
    }

    Write-Host "Loopback persistiu no flutter build. Iniciando fallback via gradlew."

    $lastFallbackLog = $null
    for ($attempt = 1; $attempt -le $maxFallbackAttempts; $attempt++) {
        Write-Host "Fallback gradlew tentativa ${attempt}/${maxFallbackAttempts}: assembleRelease"

        $fallbackLog = Join-Path $gradleTmp "gradlew-fallback-release-attempt-$attempt.log"
        $gradleCmd = "cd /d `"$androidDir`" && gradlew.bat assembleRelease --no-daemon --stacktrace --info --max-workers=2 --no-watch-fs"
        $result = Invoke-CmdWithLog -CommandLine $gradleCmd -LogFile $fallbackLog
        $lastFallbackLog = $fallbackLog

        if ($result.ExitCode -eq 0) {
            Sync-GradleApkToFlutterOutput -ProjectRoot $projectRoot
            Write-Host "Build concluido com sucesso (fallback gradlew)."
            exit 0
        }

        $loopbackError = $result.LogText -match "Unable to establish loopback connection"
        if ($loopbackError -and $attempt -lt $maxFallbackAttempts) {
            Write-Host "Loopback no fallback gradlew. Limpando daemons e tentando novamente..."

            Stop-GradleInfrastructure -ProjectRoot $projectRoot
            $daemonDirs = @(
                (Join-Path $androidDir ".gradle\daemon"),
                (Join-Path $gradleUserHome "daemon")
            )
            foreach ($daemonDir in $daemonDirs) {
                if (Test-Path $daemonDir) {
                    Remove-Item -Path $daemonDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            Start-Sleep -Seconds 3
            continue
        }

        throw "Fallback gradlew falhou. Veja o log: $fallbackLog"
    }

    throw "Build falhou tambem no fallback via gradlew. Ultimo log: $lastFallbackLog"
}
finally {
    Pop-Location
}
