$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$androidDir = Join-Path $projectRoot "android"
$flutterBin =
if ($env:FLUTTER_ROOT) {
    Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
} else {
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd -and $flutterCmd.Source) {
        $flutterCmd.Source
    } else {
        "C:\Users\Administrator\flutter\bin\flutter.bat"
    }
}
$jdkHome =
if ($env:JAVA_HOME) {
    $env:JAVA_HOME
} else {
    "C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot"
}
$gradleTmp =
if ($env:GRADLE_TMP) {
    $env:GRADLE_TMP
} else {
    "C:\gradle-tmp"
}
$gradleUserHome =
if ($env:GRADLE_USER_HOME) {
    $env:GRADLE_USER_HOME
} else {
    "C:\gradle-home"
}
$maxFlutterAttempts = 3
$maxFallbackAttempts = 3
$envFile = Join-Path $projectRoot ".env"
$requiredEnvKeys = @(
    "FIREBASE_PROJECT_ID",
    "FIREBASE_MESSAGING_SENDER_ID",
    "FIREBASE_ANDROID_API_KEY",
    "FIREBASE_ANDROID_APP_ID"
)
$dartDefineKeys = @(
    "FIREBASE_PROJECT_ID",
    "FIREBASE_MESSAGING_SENDER_ID",
    "FIREBASE_STORAGE_BUCKET",
    "FIREBASE_AUTH_DOMAIN",
    "FIREBASE_WEB_API_KEY",
    "FIREBASE_WEB_APP_ID",
    "FIREBASE_ANDROID_API_KEY",
    "FIREBASE_ANDROID_APP_ID",
    "FIREBASE_IOS_API_KEY",
    "FIREBASE_IOS_APP_ID",
    "FIREBASE_IOS_BUNDLE_ID",
    "FIREBASE_MACOS_API_KEY",
    "FIREBASE_MACOS_APP_ID",
    "FIREBASE_MACOS_BUNDLE_ID",
    "FIREBASE_WINDOWS_API_KEY",
    "FIREBASE_WINDOWS_APP_ID",
    "FIREBASE_LINUX_API_KEY",
    "FIREBASE_LINUX_APP_ID",
    "FIREBASE_TEST_ADMIN_EMAIL",
    "FIREBASE_TEST_ADMIN_PASSWORD",
    "FIREBASE_TEST_ADMIN_NAME",
    "OFFLINE_ADMIN_EMAIL",
    "OFFLINE_ADMIN_PASSWORD",
    "ENABLE_FIREBASE_TEST_SHORTCUT",
    "ENABLE_OFFLINE_LOGIN"
)

function Ensure-Directory {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Parse-DotEnv {
    param([string]$EnvPath)

    $values = @{}
    if (-not (Test-Path $EnvPath)) {
        return $values
    }

    foreach ($line in Get-Content $EnvPath) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }

        $eqIndex = $trimmed.IndexOf("=")
        if ($eqIndex -lt 1) { continue }

        $key = $trimmed.Substring(0, $eqIndex).Trim()
        $value = $trimmed.Substring($eqIndex + 1).Trim()
        if ([string]::IsNullOrWhiteSpace($key)) { continue }

        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $values[$key] = $value
    }

    return $values
}

function Ensure-RequiredEnvVars {
    param(
        [hashtable]$Values,
        [string[]]$RequiredKeys
    )

    foreach ($key in $RequiredKeys) {
        if (-not $Values.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($Values[$key])) {
            throw "Variavel obrigatoria $key nao definida no .env"
        }
    }
}

function Build-DartDefineArgs {
    param(
        [hashtable]$Values,
        [string[]]$Keys
    )

    $args = @()
    foreach ($key in $Keys) {
        if (-not $Values.ContainsKey($key)) { continue }
        $value = $Values[$key]
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        $args += " --dart-define=$key=$value"
    }
    return ($args -join "")
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

function Test-Utf8SourceFiles {
    param([string]$ProjectRoot)

    $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
    $mojibakePattern = '[\u00C3][\u0080-\u00BF]|[\u00C2][\u0080-\u00BF]|[\u00E2][\u0080-\u00BF]{1,2}'
    $targetDirs = @(
        (Join-Path $ProjectRoot "lib"),
        (Join-Path $ProjectRoot "test"),
        (Join-Path $ProjectRoot "docs"),
        (Join-Path $ProjectRoot "android"),
        (Join-Path $ProjectRoot "ios"),
        (Join-Path $ProjectRoot "web"),
        (Join-Path $ProjectRoot "windows"),
        (Join-Path $ProjectRoot "linux"),
        (Join-Path $ProjectRoot "macos")
    ) | Where-Object { Test-Path $_ }
    $targetFiles = @(
        (Join-Path $ProjectRoot "README.md"),
        (Join-Path $ProjectRoot "FIREBASE_SETUP.md"),
        (Join-Path $ProjectRoot "pubspec.yaml"),
        (Join-Path $ProjectRoot "analysis_options.yaml")
    ) | Where-Object { Test-Path $_ }
    $extensions = @(
        ".dart", ".md", ".yaml", ".yml", ".json", ".kts", ".ps1",
        ".gradle", ".properties", ".xml", ".kt", ".java",
        ".swift", ".m", ".mm", ".plist", ".pbxproj", ".xcconfig",
        ".cmake", ".txt", ".sh", ".bat", ".arb", ".html", ".js", ".css"
    )

    $fileSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $excludedSegments = @(
        "\.git\",
        "\.dart_tool\",
        "\build\",
        "\.gradle\",
        "\Pods\",
        "\node_modules\"
    )

    foreach ($dir in $targetDirs) {
        Get-ChildItem -Path $dir -Recurse -File | ForEach-Object {
            $fullName = $_.FullName
            $isExcluded = $false
            foreach ($segment in $excludedSegments) {
                if ($fullName.IndexOf($segment, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $isExcluded = $true
                    break
                }
            }
            if (-not $isExcluded -and $extensions -contains $_.Extension.ToLowerInvariant()) {
                [void]$fileSet.Add($_.FullName)
            }
        }
    }
    foreach ($file in $targetFiles) {
        [void]$fileSet.Add($file)
    }

    $invalidUtf8 = New-Object System.Collections.Generic.List[string]
    $mojibakeFound = New-Object System.Collections.Generic.List[string]

    foreach ($filePath in $fileSet) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $text = $utf8Strict.GetString($bytes)
            if ($text -match $mojibakePattern) {
                $mojibakeFound.Add($filePath)
            }
        }
        catch {
            $invalidUtf8.Add($filePath)
        }
    }

    if ($invalidUtf8.Count -gt 0) {
        $items = ($invalidUtf8 | Sort-Object -Unique) -join "`n - "
        throw "Arquivos com codificacao invalida (nao UTF-8):`n - $items"
    }
    if ($mojibakeFound.Count -gt 0) {
        $items = ($mojibakeFound | Sort-Object -Unique) -join "`n - "
        throw "Arquivos com texto possivelmente corrompido (mojibake):`n - $items"
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
$flutterDir = Split-Path -Parent $flutterBin
if ($env:Path -notlike "*$flutterDir*") {
    $env:Path = "$flutterDir;$env:Path"
}

$javaNetworkFlags = "-Djava.net.preferIPv4Stack=true -Djava.net.preferIPv6Addresses=false"
$env:JAVA_TOOL_OPTIONS = "$javaNetworkFlags -Djava.io.tmpdir=$gradleTmp"
$env:GRADLE_OPTS = "$javaNetworkFlags -Dorg.gradle.daemon=false -Dorg.gradle.vfs.watch=false"
$env:GRADLE_USER_HOME = $gradleUserHome
$env:TEMP = $gradleTmp
$env:TMP = $gradleTmp

$dotenvValues = Parse-DotEnv -EnvPath $envFile
if ($dotenvValues.Count -eq 0) {
    throw "Arquivo .env nao encontrado ou vazio em $envFile"
}
Ensure-RequiredEnvVars -Values $dotenvValues -RequiredKeys $requiredEnvKeys
$dartDefineArgs = Build-DartDefineArgs -Values $dotenvValues -Keys $dartDefineKeys

$keyPropertiesPath = Join-Path $androidDir "key.properties"
$allowInsecureDebugSigning = $false
$gradleSigningArg = ""
if (-not (Test-Path $keyPropertiesPath)) {
    $allowInsecureDebugSigning = $true
    $gradleSigningArg = " -PallowInsecureDebugSigning=true"
    Write-Host "AVISO: android/key.properties ausente. Usando assinatura debug para gerar release local."
}

Push-Location $projectRoot
try {
    Stop-GradleInfrastructure -ProjectRoot $projectRoot
    & $flutterBin clean
    & $flutterBin pub get
    Test-Utf8SourceFiles -ProjectRoot $projectRoot

    $loopbackErrorDetected = $false
    $lastFlutterLog = $null

    for ($attempt = 1; $attempt -le $maxFlutterAttempts; $attempt++) {
        Write-Host "Tentativa ${attempt}/${maxFlutterAttempts}: flutter build apk --release"

        $logFile = Join-Path $gradleTmp "flutter-build-release-attempt-$attempt.log"
        $flutterCmd = "`"$flutterBin`" build apk --release$dartDefineArgs"
        $result = Invoke-CmdWithLog -CommandLine $flutterCmd -LogFile $logFile
        $lastFlutterLog = $logFile

        if ($result.ExitCode -eq 0) {
            Write-Host "Build concluido com sucesso."
            exit 0
        }

        if ($allowInsecureDebugSigning -and
            $result.LogText -match "Assinatura release obrigatoria") {
            $loopbackErrorDetected = $true
            Write-Host "Flutter build bloqueou por assinatura. Continuando no fallback gradlew com -PallowInsecureDebugSigning=true."
            break
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
        $gradleCmd = "cd /d `"$androidDir`" && gradlew.bat assembleRelease$gradleSigningArg --no-daemon --stacktrace --info --max-workers=2 --no-watch-fs"
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
