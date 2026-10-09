<#
.SYNOPSIS
  Compila y publica una nueva version de GravisDesignHUB en GitHub Releases.

.DESCRIPTION
  1. Comprueba que la version de pubspec.yaml y la de updater_service.dart coinciden.
  2. Compila el APK (y el zip de Windows con -ConWindows).
  3. Verifica version y FIRMA del APK (debe ser la misma llave de siempre, o Android
     no dejara actualizar encima de la version instalada).
  4. Pide que escribas PUBLICAR y sube la release con nombres de archivo fijos, de
     modo que el enlace  .../releases/latest/download/GravisDesignHUB.apk  nunca cambia.

  Las apps 1.0.8 o mas nuevas detectan la release solas. Los campos de Firebase
  (config/version) solo hacen falta para las apps 1.0.7 y anteriores; el script
  te dice exactamente que poner.

.EXAMPLE
  .\publicar-version.ps1 -SoloComprobar
  Compila y verifica todo, pero NO publica nada.

.EXAMPLE
  .\publicar-version.ps1 -Novedades "Arreglado X. Nuevo Y." -ConWindows
#>
[CmdletBinding()]
param(
  [string]$Novedades,
  [switch]$ConWindows,
  [switch]$SoloComprobar,
  [switch]$AceptarOtraFirma
)

# Los comandos nativos (flutter, gh, git) se comprueban con $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath $PSScriptRoot
try { (Get-Process -Id $PID).PriorityClass = 'BelowNormal' } catch { }

$Repo         = 'GravisLudio/GravisDesignHUB'
$ApkNombre    = 'GravisDesignHUB.apk'
$WinNombre    = 'GravisDesignHUB-windows.zip'
# Huella SHA-256 (publica) de la llave con la que estan firmados los APK en uso.
$FirmaEsperada = 'd5801bb519bc1137d4919964387eea7dd5fc5dfc846a8d570af54db1aff4a2e1'
$EnlaceFijo   = "https://github.com/$Repo/releases/latest/download/$ApkNombre"

function Fallo([string]$mensaje) {
  Write-Host ''
  Write-Host "ERROR: $mensaje" -ForegroundColor Red
  exit 1
}
function Paso([string]$mensaje) { Write-Host ''; Write-Host "== $mensaje" -ForegroundColor Cyan }
function Tamano([string]$ruta) { '{0:N1} MB' -f ((Get-Item -LiteralPath $ruta).Length / 1MB) }

# ---------------------------------------------------------------- 1. versiones
Paso 'Comprobando versiones'
$pubspec = Get-Content -LiteralPath 'pubspec.yaml' -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*(\d+(?:\.\d+)*)\+(\d+)\s*$')
if (-not $m.Success) { Fallo 'No encuentro "version: X.Y.Z+N" en pubspec.yaml.' }
$ver   = $m.Groups[1].Value
$build = $m.Groups[2].Value

$updater = Get-Content -LiteralPath 'lib\services\updater_service.dart' -Raw
$m2 = [regex]::Match($updater, "currentVersion\s*=\s*'([^']+)'")
if (-not $m2.Success) { Fallo 'No encuentro currentVersion en lib\services\updater_service.dart.' }
if ($m2.Groups[1].Value -ne $ver) {
  Fallo "pubspec.yaml dice $ver pero updater_service.dart dice $($m2.Groups[1].Value). Ponlos iguales: si no, la app creeria que siempre hay una version nueva (o nunca)."
}
Write-Host "Version a publicar: $ver (build $build)"

if (-not $SoloComprobar -and [string]::IsNullOrWhiteSpace($Novedades)) {
  $Novedades = Read-Host 'Novedades de esta version (se ven en la app y en GitHub)'
  if ([string]::IsNullOrWhiteSpace($Novedades)) { Fallo 'Las novedades no pueden estar vacias.' }
}

# ---------------------------------------------------------------- 2. herramientas
Paso 'Comprobando herramientas'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Fallo 'No encuentro "flutter" en el PATH.' }
$tieneGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)
if (-not $tieneGh -and -not $SoloComprobar) { Fallo 'No encuentro "gh" (GitHub CLI). Instalalo y ejecuta: gh auth login' }
if ($tieneGh) {
  gh auth status *> $null
  if ($LASTEXITCODE -ne 0) {
    if ($SoloComprobar) { Write-Host 'Aviso: gh no tiene sesion iniciada (no hace falta en -SoloComprobar).' -ForegroundColor Yellow; $tieneGh = $false }
    else { Fallo 'gh no tiene sesion iniciada. Ejecuta: gh auth login' }
  }
}
if ($tieneGh) {
  gh release view "v$ver" --repo $Repo *> $null
  if ($LASTEXITCODE -eq 0) { Fallo "La release v$ver ya existe en GitHub. Sube la version en pubspec.yaml y en updater_service.dart." }
}

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\sdk' }
$bt = Get-ChildItem -LiteralPath (Join-Path $sdk 'build-tools') -Directory -ErrorAction SilentlyContinue |
      Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending | Select-Object -First 1
if (-not $bt) { Fallo "No encuentro build-tools del Android SDK en $sdk." }
$apksigner = Join-Path $bt.FullName 'apksigner.bat'
$aapt2     = Join-Path $bt.FullName 'aapt2.exe'
if (-not $env:JAVA_HOME) {
  $jbr = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
  if (Test-Path -LiteralPath $jbr) { $env:JAVA_HOME = $jbr }
}

# ---------------------------------------------------------------- 3. estado de git
Paso 'Estado del codigo en GitHub'
$codigoSinSubir = $false
$cambios = @(git status --porcelain 2>$null)
$local   = (git rev-parse HEAD 2>$null)
$remoto  = (git rev-parse 'origin/main' 2>$null)
if ($cambios.Count -gt 0) { $codigoSinSubir = $true; Write-Host "Hay $($cambios.Count) archivos con cambios sin commitear." -ForegroundColor Yellow }
if ($local -ne $remoto)   { $codigoSinSubir = $true; Write-Host 'Tu commit local no es el mismo que origin/main.' -ForegroundColor Yellow }
if (-not $codigoSinSubir) { Write-Host 'El codigo de esta version ya esta en GitHub.' }

# ---------------------------------------------------------------- 4. APK
Paso "Compilando APK $ver (puede tardar varios minutos)"
flutter build apk --release
if ($LASTEXITCODE -ne 0) { Fallo 'flutter build apk fallo. Revisa el mensaje de arriba.' }
$apkOrigen = 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $apkOrigen)) { Fallo "No aparece $apkOrigen despues de compilar." }

Paso 'Verificando el APK'
$badging = & $aapt2 dump badging $apkOrigen 2>&1 | Out-String
$mb = [regex]::Match($badging, "versionCode='(\d+)'\s+versionName='([^']+)'")
if (-not $mb.Success) { Fallo 'No pude leer la version del APK con aapt2.' }
if ($mb.Groups[2].Value -ne $ver -or $mb.Groups[1].Value -ne $build) {
  Fallo "El APK dice $($mb.Groups[2].Value) (build $($mb.Groups[1].Value)) y esperaba $ver (build $build)."
}
Write-Host "Version del APK: $ver (build $build)  OK"

$firma = & $apksigner verify --print-certs $apkOrigen 2>&1 | Out-String
$mf = [regex]::Match($firma, 'SHA-256 digest:\s*([0-9a-fA-F]{64})')
if (-not $mf.Success) { Fallo 'No pude leer la firma del APK con apksigner (revisa JAVA_HOME).' }
$huella = $mf.Groups[1].Value.ToLower()
if ($huella -eq $FirmaEsperada) {
  Write-Host 'Firma del APK: la misma de siempre  OK' -ForegroundColor Green
} elseif ($AceptarOtraFirma) {
  Write-Host "Firma DISTINTA ($huella) aceptada con -AceptarOtraFirma. Quien tenga la app instalada tendra que DESINSTALARLA antes de instalar esta." -ForegroundColor Yellow
} else {
  Fallo ("El APK esta firmado con otra llave ($huella).`n" +
         "Android NO deja actualizar encima de la version instalada si la firma cambia: cada usuario tendria que desinstalar y reinstalar.`n" +
         "Recupera tu debug.keystore original (carpeta .android de tu usuario). Si de verdad quieres cambiar de llave, repite con -AceptarOtraFirma.")
}

New-Item -ItemType Directory -Force -Path 'release' | Out-Null
$apkFinal = Join-Path 'release' $ApkNombre
Copy-Item -LiteralPath $apkOrigen -Destination $apkFinal -Force
$archivos = @($apkFinal)

# ---------------------------------------------------------------- 5. Windows (opcional)
if ($ConWindows) {
  Paso 'Compilando Windows'
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { Fallo 'flutter build windows fallo.' }
  $rel = 'build\windows\x64\runner\Release'
  $exe = Join-Path $rel 'gravdesinghub.exe'
  if (-not (Test-Path -LiteralPath $exe)) { Fallo "No aparece $exe." }
  $pv = (Get-Item -LiteralPath $exe).VersionInfo.ProductVersion
  if ($pv -ne "$ver+$build") { Fallo "El .exe dice version $pv y esperaba $ver+$build." }
  $zip = Join-Path 'release' $WinNombre
  if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
  $contenido = Get-ChildItem -LiteralPath $rel | Where-Object { $_.Extension -notin '.lib', '.exp', '.pdb' }
  Compress-Archive -Path $contenido.FullName -DestinationPath $zip -Force
  $archivos += $zip
}

# ---------------------------------------------------------------- 6. resumen y confirmacion
Paso 'Resumen'
Write-Host "Version : $ver (build $build)"
Write-Host "Repo    : https://github.com/$Repo"
foreach ($a in $archivos) { Write-Host ("Archivo : {0}  ({1})" -f $a, (Tamano $a)) }
if ($codigoSinSubir) {
  Write-Host "Ojo    : el codigo de esta version NO esta subido a GitHub. La release se publicaria igual, pero la etiqueta v$ver apuntaria al ultimo commit publicado, no a tu codigo actual." -ForegroundColor Yellow
}
Write-Host 'Aviso  : el repo es PUBLICO; cualquiera con el enlace podra descargar el instalador.' -ForegroundColor Yellow

if ($SoloComprobar) {
  Write-Host ''
  Write-Host 'Modo -SoloComprobar: todo verificado, NO se ha publicado nada.' -ForegroundColor Green
  Write-Host "Instalador de prueba: $((Resolve-Path -LiteralPath $apkFinal).Path)"
  exit 0
}

Write-Host ''
$resp = Read-Host 'Escribe PUBLICAR para subirla a GitHub (cualquier otra cosa cancela)'
if ($resp -cne 'PUBLICAR') { Write-Host 'Cancelado. No se subio nada.'; exit 0 }

# ---------------------------------------------------------------- 7. publicar
Paso 'Publicando release en GitHub'
gh release create "v$ver" @archivos --repo $Repo --title "GravisDesignHUB v$ver" --notes $Novedades --latest
if ($LASTEXITCODE -ne 0) { Fallo "gh release create fallo. Puede que no se haya publicado nada o que haya quedado a medias: revisa https://github.com/$Repo/releases" }

Paso 'Comprobando que el enlace fijo responde'
try {
  $r = Invoke-WebRequest -Uri $EnlaceFijo -Method Head -MaximumRedirection 5 -UseBasicParsing -TimeoutSec 30
  Write-Host "Enlace fijo: HTTP $($r.StatusCode)  OK" -ForegroundColor Green
} catch {
  Write-Host "No pude comprobar el enlace ahora ($($_.Exception.Message)). Pruebalo a mano en el navegador." -ForegroundColor Yellow
}

# ---------------------------------------------------------------- 8. que hacer en Firebase
Write-Host ''
Write-Host '== Siguiente paso (lo haces tu, en la consola de Firebase)' -ForegroundColor Cyan
Write-Host 'Firestore > coleccion  config > documento  version  y cambia estos 3 campos:'
Write-Host "  latestVersion = $ver"
Write-Host "  downloadUrl   = $EnlaceFijo"
Write-Host "  changelog     = $Novedades"
Write-Host ''
Write-Host 'Las apps 1.0.8 o mas nuevas ya detectan la release solas; estos campos son para las 1.0.7 y anteriores.'
Write-Host 'Hazlo DESPUES de que la release exista (ya existe) para que el enlace no de 404.'
Write-Host ''
Write-Host 'Recuerda: guarda una copia de tu llave de firma (carpeta .android\debug.keystore) fuera de este PC.' -ForegroundColor Yellow
