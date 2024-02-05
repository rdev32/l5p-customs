if (!($PSVersionTable.PSEdition -eq 'Core')) {
  Write-Host "Debes ejecutar este archivo con Powershell 7 o versiones posteriores"
  exit 0
}

function Disable-WindowsDefender {
  [CmdletBinding()]
  param()

  if (!(Test-SafeMode)) {
    Write-Host "Para usar esto, debes iniciar el computador en modo seguro."
    return
  }

  if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
    Write-Host "Esta funcionalidad debe ejecutarse como administrador"
    return
  }

  $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
  $keys = @(
    @{
      Key   = "AllowFastServiceStartup"
      Value = 0
    },
    @{
      Key   = "DisableAntiSpyware"
      Value = 1
    },
    @{
      Key   = "DisableRealtimeMonitoring"
      Value = 1
    },
    @{
      Key   = "DisableAntiVirus"
      Value = 1
    },
    @{
      Key   = "DisableSpecialRunningModes"
      Value = 1
    },
    @{
      Key   = "DisableRoutinelyTakingAction"
      Value = 1
    }
  )

  foreach ($key in $keys) {
    New-ItemProperty -Path $registryPath -Name $key.Key -PropertyType DWORD -Value $key.Value -Force
  }

  $subKeys = @(
    "Real-Time Protection",
    "Signature Updates",
    "Spynet"
  )

  foreach ($subKey in $subKeys) {
    New-Item -Path "$registryPath\$subKey" -Force
  }

  $realTimeProtectionKeys = @(
    @{
      Key   = "DisableBehaviorMonitoring"
      Value = 1
    },
    @{
      Key   = "DisableOnAccessProtection"
      Value = 1
    },
    @{
      Key   = "DisableRealtimeMonitoring"
      Value = 1
    },
    @{
      Key   = "DisableScanOnRealtimeEnable"
      Value = 1
    }
  )

  $realTimeProtectionPath = "$registryPath\Real-Time Protection"
  foreach ($key in $realTimeProtectionKeys) {
    New-ItemProperty -Path $realTimeProtectionPath -Name $key.Key -PropertyType DWORD -Value $key.Value -Force
  }

  New-ItemProperty -Path "$registryPath\Signature Updates" -Name "ForceUpdateFromMU" -PropertyType DWORD -Value 0 -Force
  New-ItemProperty -Path "$registryPath\Spynet" -Name "DisableBlockAtFirstSeen" -PropertyType DWORD -Value 1 -Force

  $services = @(
    "Sense",
    "WdBoot",
    "WdFilter",
    "WdNisDrv",
    "WdNisSvc",
    "WinDefend"
  )

  foreach ($service in $services) {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$service" -Name "Start" -Value 4
  }

  Write-Host "Windows Defender ha sido desactivado."
}

function Wait-KeyPress {
  [CmdletBinding()]
  param()
  Write-Host "Presione cualquier tecla para continuar.."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Disable-DriverUpdates {
  [CmdletBinding()]
  param()

  if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
    Write-Host "Esta funcionalidad debe ejecutarse como administrador"
    return
  }

  $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"

  if (!(Test-Path $registryPath)) {
    Write-Host "No se encontró la opción para desactivar las actualizaciones de controladores."
    return
  }

  if ((Get-ItemProperty -Path $registryPath).SearchOrderConfig -eq 0) {
    Write-Host "Ya se encuentra desactivada la actualizacion de controladores automatica."
    return
  }

  Set-ItemProperty -Path $registryPath -Name "SearchOrderConfig" -Value 0 | Out-Null
  Write-Host "Actualización de controladores desactivada."
}

function Set-ComputerModelName {
  [CmdletBinding()]
  param()

  if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")) {
    Write-Host "Esta funcionalidad debe ejecutarse como administrador"
    return
  }

  $model = (Get-ItemProperty -Path "HKLM:\SYSTEM\HardwareConfig\Current" -Name "SystemFamily").SystemFamily

  if (!$model) {
    Write-Host "No se pudo encontrar el modelo ¿Esta computadora es una laptop?"
    return
  }

  $modelPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation\"

  if (Test-Path $modelPath) {
    Set-ItemProperty -Path $modelPath -Name "Model" -Value $model | Out-Null
  }
  else {
    New-ItemProperty -Path $modelPath -Name "Model" -Value $model | Out-Null
  }

  Write-Host "Se introdujo el nombre del modelo correctamente"
}

function Test-SafeMode {
  [CmdletBinding()]
  param()

  return ((Get-CimInstance -ClassName win32_computersystem).BootupState -ne "Normal boot") ? $true : $false
}

function Test-InternetConnection {
  [CmdletBinding()]
  param()

  return (Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction Stop) ? $true : $false
}

function Open-FSWindow {
  [CmdletBinding()]
  param(
    [string]$Path
  )

  if (!(Test-Path $Path)) {
    Write-Host "No se encontro el folder de controladores, por favor coloquelo en C:\Drivers"
    return
  }

  Write-Host "Se abrio el folder de controladores."
  Invoke-Item -Path $Path
}

function Invoke-PackageInstall {
  [CmdletBinding()]
  param(
    [string]$PackageName
  )

  Start-Process -FilePath "pwsh.exe" -ArgumentList "-Command `"winget install --id $($PackageName) -e`"" -PassThru -Wait -WindowStyle Hidden | Out-Null
}

function Test-IsPackageInstalled {
  param (
    [string]$PackageName
  )

  $exitCode = (Start-Process -FilePath "pwsh.exe" -ArgumentList "-Command `"winget list --id $($PackageName) -e`"" -PassThru -Wait -WindowStyle Hidden).ExitCode
  return ($exitCode -eq 0) ? $true : $false
}


function Install-SoftwarePackage {
  param(
    [string[]]$Packages
  )

  if (!(Test-InternetConnection)) {
    Write-Host "No tienes conexion a internet"
    return
  }

  foreach ($name in $Packages) {
    if (Test-IsPackageInstalled($name)) {
      Write-Host "El programa $($name) ya esta instalado"
    } else {
      Write-Host "Instalando $($name)"
      Invoke-PackageInstall($name)
    }
  }

  Write-Host "`nInstalacion completada con exito"
}

$essentials =
"Google.Chrome",
"Notepad++.Notepad++",
"7zip.7zip",
"Discord.Discord",
#"Spotify.Spotify", gives random problems
"Zoom.Zoom",
"Valve.Steam"

$windowsDevelopment =
"Git.Git",
"Github.cli",
"Oracle.JDK.17",
"JetBrains.IntelliJIDEA.Community",
"Microsoft.VisualStudioCode",
"Microsoft.VisualStudio.2022.Community",
"Python.Python.3.12",
"OpenJS.NodeJS",
"Oracle.VirtualBox"

$wslDevelopment =
"Docker.DockerDesktop",
"Microsoft.VisualStudioCode",
"WinSCP.WinSCP"

$beforeTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "Legion 5 Pro Customization Tools v1.2"

while (1) {
  Clear-Host
  Write-Host @"
  `t   __       ______   ______     ______   __  __   ______   _________  ______   ___ __ __   ______
  `t  /_/\     /_____/\ /_____/\   /_____/\ /_/\/_/\ /_____/\ /________/\/_____/\ /__//_//_/\ /_____/\
  `t  \:\ \    \::::_\/_\:::_ \ \  \:::__\/ \:\ \:\ \\::::_\/_\__.::.__\/\:::_ \ \\::\ | \ | \ \\::::_\
  `t   \:\ \    \:\/___/\\:(_) \ \  \:\ \  __\:\ \:\ \\:\/___/\  \::\ \   \:\ \ \ \\:.      \ \\:\/___/\
  `t    \:\ \____\_::._\:\\: ___\/   \:\ \/_/\\:\ \:\ \\_::._\:\  \::\ \   \:\ \ \ \\:.\-/\  \ \\_::._\:\
  `t     \:\/___/\/_____\/ \ \ \      \:\_\ \ \\:\_\:\ \ /____\:\  \::\ \   \:\_\ \ \\. \  \  \ \ /____\:\
  `t      \_____\/\_____/   \_\/       \_____\/ \_____\/ \_____\/   \__\/    \_____\/ \__\/ \__\/ \_____\/
  `t
  `t     ____  ____  _____   ________  ____  ____ _/ /_____     ____ ___  ____  ____  _________  __  __
  `t    / __ \/ __ \/ ___/  / ___/ _ \/ __ \/ __ `/ __/ __ \   / __ `__ \/ __ \/ __ \/ ___/ __ \/ / / /
  `t   / /_/ / /_/ / /     / /  /  __/ / / / /_/ / /_/ /_/ /  / / / / / / /_/ / / / / /  / /_/ / /_/ /
  `t  / .___/\____/_/     /_/   \___/_/ /_/\__, _/\__/\___/  /_/ /_/ /_/\____/_/ /_/_/   \____/\__, /
  `t /_/                                                                                      /____/
"@

  Write-Host @"
  `t`t`t`t1 - Restauracion del nombre del modelo (ADMIN)
  `t`t`t`t2 - Instalacion manual de controladores
  `t`t`t`t3 - Desactivar actualizaciones a los controladores (ADMIN)
  `t`t`t`t4 - Instalacion de herramientas de desarrollo para Windows
  `t`t`t`t5 - Instalacion de herramientas de desarrollo para WSL
  `t`t`t`t6 - Instalacion de programas comunes
  `t`t`t`t7 - Desactivar Windows Defender (ADMIN)
  `t`t`t`t8 - Activacion para MS Windows 10/11 & Office Pro Plus 2021
  `t`t`t`t9 - Salir
"@

  $option = Read-Host "`t`t`t`t`t`t`t`tSelecciona una opcion"
  switch ($option) {
    "1" {
      Clear-Host
      Set-ComputerModelName
      Wait-KeyPress
    }

    "2" {
      Clear-Host
      Open-FSWindow("C:\Drivers")
      Wait-KeyPress
    }

    "3" {
      Clear-Host
      Disable-DriverUpdates
      Wait-KeyPress
    }

    "4" {
      Clear-Host
      Install-SoftwarePackage -Packages $windowsDevelopment
      Wait-KeyPress
    }

    "5" {
      Clear-Host
      Install-SoftwarePackage -Packages $wslDevelopment
      Wait-KeyPress
    }

    "6" {
      Clear-Host
      Install-SoftwarePackage -Packages $essentials
      Wait-KeyPress
    }

    "7" {
      Clear-Host
      Disable-WindowsDefender
      Wait-KeyPress
    }

    "8" {
      Clear-Host
      # TODO: Pull script from remote repo
      Write-Host "Not implemented"
      Wait-KeyPress
    }

    "9" {
      $Host.UI.RawUI.WindowTitle = $beforeTitle
      exit 0
    }

    Default {}
  }
}
