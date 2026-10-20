$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Invoke-Checked([string] $Program, [string[]] $Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed ($LASTEXITCODE)" }
}
Invoke-Checked 'cmake' @('-S', 'native', '-B', 'native/build', '-DCMAKE_BUILD_TYPE=Release')
Invoke-Checked 'cmake' @('--build', 'native/build', '--config', 'Release', '--target', 'hifi_audio_ffi', '--parallel')
Invoke-Checked 'flutter' @('build', 'windows', '--release')
$Apps = @(Get-ChildItem build/windows -Filter hide_player_flutter.exe -Recurse | Where-Object { $_.Directory.Name -eq 'Release' })
if ($Apps.Count -ne 1) { throw 'Cannot identify the Windows Release bundle' }
$Library = @(Get-ChildItem native/build -Filter hifi_audio_ffi.dll -Recurse | Where-Object { $_.Directory.Name -eq 'Release' -or $_.Directory.FullName -eq (Resolve-Path native/build).Path })
if ($Library.Count -ne 1) { throw 'Cannot identify the Release audio DLL' }
Copy-Item $Library[0].FullName $Apps[0].Directory.FullName -Force
# SDL2.dll must be deployed next to the executable when using shared SDL.
$SdlLibrary = Join-Path $Library[0].Directory.FullName 'SDL2.dll'
if (Test-Path $SdlLibrary) { Copy-Item $SdlLibrary $Apps[0].Directory.FullName -Force }
Write-Output "Release bundle: $($Apps[0].Directory.FullName)"
