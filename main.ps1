if (![bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')) {
  Write-Host "Debes ejecutar este archivo como administrador"
  exit 0
}

if (!($PSVersionTable.PSEdition -eq 'Core')) {
  Write-Host "Debes ejecutar este archivo con Powershell 7 o versiones posteriores"
  exit 0
}

$beforeTitle = $Host.UI.RawUI.WindowTitle
function Disable-WindowsDefender {
  param()

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
  Write-Host "Presione cualquier tecla para continuar.."
  $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Disable-DriverUpdates {
  param()

  $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"

  if (!(Test-Path $registryPath)) {
    Write-Host "No se encontró la opción para desactivar las actualizaciones de controladores."
    return -1
  }

  Set-ItemProperty -Path $registryPath -Name 'SearchOrderConfig' -Value 0 | Out-Null
  Write-Host "Actualización de controladores desactivada."
}

function Set-ComputerModelName {
  param()

  $model = (Get-ItemProperty -Path 'HKLM:\SYSTEM\HardwareConfig\Current' -Name 'SystemFamily').SystemFamily

  if (!$model) {
    Write-Host "No se pudo encontrar el modelo ¿Esta computadora es una laptop?"
    return -1
  }

  $modelPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation\'

  if (Test-Path $modelPath) {
    Set-ItemProperty -Path $modelPath -Name 'Model' -Value $model | Out-Null
  }
  else {
    New-ItemProperty -Path $modelPath -Name 'Model' -Value $model | Out-Null
  }

  Write-Host "Se introdujo el nombre del modelo correctamente"
}

function Test-SafeMode {
  param()

  $bootmode = Get-CimInstance -ClassName win32_computersystem | Select-Object -ExpandProperty BootupState

  if ($bootmode -eq 'Normal boot') {
    return -1
  }

  return 0
}

function Invoke-ProcessInstallation {
  param(
    [string]$command
  )

  $process = Start-Process -FilePath "pwsh.exe" -ArgumentList "-Command `"$command`"" -PassThru -Wait -WindowStyle Hidden
  return $process.ExitCode
}

function Install-SoftwarePackage {
  param(
    [string[]]$Packages
  )

  $currentProgress = 0
  foreach ($name in $Packages) {
    $currentProgress++
    $progressStatus = "($($currentProgress) / $($Packages.Count)) $($name)"

    if (!(Invoke-ProcessInstallation -command "winget list --id $($name) -e" -eq 0)) {
      Write-Host "El programa $($name) ya esta instalado`t"
      continue
    }

    Write-Host "Instalando $($progressStatus)"
    Invoke-ProcessInstallation -command "winget install --id $($name) -e"
  }

  Write-Host "Instalacion completada con exito"
}

$essentials =
"Google.Chrome",
"Notepad++.Notepad++",
"7zip.7zip",
"Discord.Discord",
"9NKSQGP7F2NH",
"Spotify.Spotify",
"Zoom.Zoom",
"Valve.Steam"

$windowsDevelopment =
"Git.Git",
"Oracle.JDK.17",
"JetBrains.IntelliJIDEA.Community",
"Microsoft.VisualStudioCode",
"Microsoft.VisualStudio.2022.Community",
"Python.Python.3.12",
"OpenJS.NodeJS",
"Oracle.VirtualBox"

$wslDevelopment =
"Neovim.Neovim",
"Github.cli",
"Docker.DockerDesktop",
"Microsoft.VisualStudioCode",
"WinSCP.WinSCP"

$Host.UI.RawUI.WindowTitle = "Legion 5 Pro Customization Tools v1.1"
while (1) {
  Clear-Host
  Write-Host @"
  `t   __       ______   ______     ______   __  __   ______   _________  ______   ___ __ __   ______
  `t  /_/\     /_____/\ /_____/\   /_____/\ /_/\/_/\ /_____/\ /________/\/_____/\ /__//_//_/\ /_____/\
  `t  \:\ \    \::::_\/_\:::_ \ \  \:::__\/ \:\ \:\ \\::::_\/_\__.::.__\/\:::_ \ \\::\ | \ | \ \\::::_\/_
  `t   \:\ \    \:\/___/\\:(_) \ \  \:\ \  __\:\ \:\ \\:\/___/\  \::\ \   \:\ \ \ \\:.      \ \\:\/___/\
  `t    \:\ \____\_::._\:\\: ___\/   \:\ \/_/\\:\ \:\ \\_::._\:\  \::\ \   \:\ \ \ \\:.\-/\  \ \\_::._\:\
  `t     \:\/___/\/_____\/ \ \ \      \:\_\ \ \\:\_\:\ \ /____\:\  \::\ \   \:\_\ \ \\. \  \  \ \ /____\:\
  `t      \_____\/\_____/   \_\/       \_____\/ \_____\/ \_____\/   \__\/    \_____\/ \__\/ \__\/ \_____\/
  `t
  `t     ____  ____  _____   ________  ____  ____ _/ /_____     ____ ___  ____  ____  _________  __  __
  `t    / __ \/ __ \/ ___/  / ___/ _ \/ __ \/ __ `/ __/ __ \   / __ `__ \/ __ \/ __ \/ ___/ __ \/ / / /
  `t   / /_/ / /_/ / /     / /  /  __/ / / / /_/ / /_/ /_/ /  / / / / / / /_/ / / / / /  / /_/ / /_/ /
  `t  / .___/\____/_/     /_/   \___/_/ /_/\__, _/\__/\____/  /_/ /_/ /_/\____/_/ /_/_/   \____/\__, /
  `t /_/                                                                                      /____/
"@

  Write-Host @"
  `t`t`t`t1 - Restauracion del nombre del modelo
  `t`t`t`t2 - Instalacion manual de controladores
  `t`t`t`t3 - Desactivar actualizaciones a los controladores
  `t`t`t`t4 - Instalacion de herramientas de desarrollo para Windows
  `t`t`t`t5 - Instalacion de herramientas de desarrollo para WSL
  `t`t`t`t6 - Instalacion de programas comunes
  `t`t`t`t7 - Desactivar Windows Defender
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
      Write-Host "Not implemented"
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
      if (!(Test-SafeMode)) {
        Disable-WindowsDefender
      } else {
        Write-Host "You must run this on Safe Mode."
      }
      Wait-KeyPress
    }

    "8" {
      Clear-Host
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
