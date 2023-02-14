packer {
  required_plugins {
    azure = {
      version = ">= 1.4.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "subscription_id" {
  type    = string
  default = ""
}
variable "resource_group" {
  type    = string
  default = ""
}
variable "location" {
  type    = string
  default = ""
}

variable "image_name" {
  type    = string
  default = "win22"
}

variable "azure_tag" {
  type    = map(string)
  default = {}
}

variable "helper_script_folder" {
  type    = string
  default = "/imagegeneration/helpers"
}

variable "run_validation_diskspace" {
  type    = bool
  default = false
}

variable "agent_tools_directory" {
  type    = string
  default = "C:\\hostedtoolcache\\windows"
}

variable "image_folder" {
  type    = string
  default = "C:\\image"
}

variable "image_os" {
  type    = string
  default = "win22"
}

variable "image_version" {
  type    = string
  default = "dev"
}

variable "imagedata_file" {
  type    = string
  default = "C:\\imagedata.json"
}

variable "install_password" {
  type      = string
  sensitive = true
}

variable "install_user" {
  type    = string
  default = "installer"
}

variable "client_app_id" {
  type = string
}

variable "client_app_secret" {
  type      = string
  sensitive = true
}

variable "vnet" {
  type = string
}

variable "vnet_rg" {
  type = string
}

variable "subnet" {
  type = string
}

source "azure-arm" "base_image" {
  temp_resource_group_name            = "builder-${var.resource_group}"
  communicator                        = "winrm"
  image_offer                         = "WindowsServer"
  image_publisher                     = "MicrosoftWindowsServer"
  image_sku                           = "2022-Datacenter"
  location                            = "${var.location}"
  managed_image_name                  = "${var.image_name}"
  managed_image_resource_group_name   = "${var.resource_group}"
  os_type                             = "windows"
  subscription_id                     = "${var.subscription_id}"
  vm_size                             = "Standard_D4s_v4"
  client_id                           = "${var.client_app_id}"
  client_secret                       = "${var.client_app_secret}"
  virtual_network_name                = "${var.vnet}"
  virtual_network_resource_group_name = "${var.vnet_rg}"
  virtual_network_subnet_name         = "${var.subnet}"
  winrm_insecure                      = "true"
  winrm_use_ssl                       = "true"
  winrm_username                      = "packer"

  dynamic "azure_tag" {
    for_each = var.azure_tag
    content {
      name  = azure_tag.key
      value = azure_tag.value
    }
  }
}
build {
  name    = "default image build"
  sources = ["source.azure-arm.base_image"]

  provisioner "powershell" {
    inline = ["New-Item -Path ${var.image_folder} -ItemType Directory -Force"]
  }

  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/scripts/ImageHelpers"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/SoftwareReport"
  }

  provisioner "file" {
    destination = "${var.image_folder}/SoftwareReport/"
    source      = "${path.root}/../../helpers/software-report-base"
  }

  provisioner "file" {
    destination = "C:/"
    source      = "${path.root}/post-generation"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/Tests"
  }

  provisioner "file" {
    destination = "${var.image_folder}\\toolset.json"
    source      = "${path.root}/toolsets/toolset-2022.json"
  }

  provisioner "windows-shell" {
    inline = ["net user ${var.install_user} ${var.install_password} /add /passwordchg:no /passwordreq:yes /active:yes /Y", "net localgroup Administrators ${var.install_user} /add", "winrm set winrm/config/service/auth @{Basic=\"true\"}", "winrm get winrm/config/service/auth"]
  }

  provisioner "powershell" {
    inline = ["if (-not ((net localgroup Administrators) -contains '${var.install_user}')) { exit 1 }"]
  }

  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    inline            = ["bcdedit.exe /set TESTSIGNING ON"]
  }

  provisioner "powershell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "IMAGE_OS=${var.image_os}", "AGENT_TOOLSDIRECTORY=${var.agent_tools_directory}", "IMAGEDATA_FILE=${var.imagedata_file}"]
    execution_policy = "unrestricted"
    scripts          = ["${path.root}/scripts/Installers/Configure-Antivirus.ps1", "${path.root}/scripts/Installers/Install-PowerShellModules.ps1", "${path.root}/scripts/Installers/Install-WindowsFeatures.ps1", "${path.root}/scripts/Installers/Install-Choco.ps1", "${path.root}/scripts/Installers/Initialize-VM.ps1", "${path.root}/scripts/Installers/Update-ImageData.ps1", "${path.root}/scripts/Installers/Update-DotnetTLS.ps1"]
  }

  provisioner "windows-restart" {
    check_registry        = true
    restart_check_command = "powershell -command \"& {while ( (Get-WindowsOptionalFeature -Online -FeatureName Containers -ErrorAction SilentlyContinue).State -ne 'Enabled' ) { Start-Sleep 30; Write-Output 'InProgress' }}\""
    restart_timeout       = "10m"
  }

  provisioner "powershell" {
    scripts = ["${path.root}/scripts/Installers/Install-Docker.ps1", "${path.root}/scripts/Installers/Install-PowershellCore.ps1", "${path.root}/scripts/Installers/Install-WebPlatformInstaller.ps1"]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    scripts           = ["${path.root}/scripts/Installers/Install-VS.ps1", "${path.root}/scripts/Installers/Install-KubernetesTools.ps1"]
    valid_exit_codes  = [0, 3010]
  }

  provisioner "windows-restart" {
    check_registry  = true
    restart_timeout = "10m"
  }

  provisioner "powershell" {
    pause_before = "2m0s"
    scripts      = ["${path.root}/scripts/Installers/Install-Wix.ps1", "${path.root}/scripts/Installers/Install-WDK.ps1", "${path.root}/scripts/Installers/Install-Vsix.ps1", "${path.root}/scripts/Installers/Install-AzureCli.ps1", "${path.root}/scripts/Installers/Install-AzureDevOpsCli.ps1", "${path.root}/scripts/Installers/Install-CommonUtils.ps1", "${path.root}/scripts/Installers/Install-JavaTools.ps1", "${path.root}/scripts/Installers/Install-Kotlin.ps1"]
  }

  provisioner "powershell" {
    execution_policy = "remotesigned"
    scripts          = ["${path.root}/scripts/Installers/Install-ServiceFabricSDK.ps1"]
  }

  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "windows-shell" {
    inline = ["wmic product where \"name like '%%microsoft azure powershell%%'\" call uninstall /nointeractive"]
  }

  provisioner "powershell" {
    scripts = ["${path.root}/scripts/Installers/Install-Ruby.ps1", "${path.root}/scripts/Installers/Install-PyPy.ps1", "${path.root}/scripts/Installers/Install-Toolset.ps1", "${path.root}/scripts/Installers/Configure-Toolset.ps1", "${path.root}/scripts/Installers/Install-NodeLts.ps1", "${path.root}/scripts/Installers/Install-AndroidSDK.ps1", "${path.root}/scripts/Installers/Install-AzureModules.ps1", "${path.root}/scripts/Installers/Install-Pipx.ps1", "${path.root}/scripts/Installers/Install-PipxPackages.ps1", "${path.root}/scripts/Installers/Install-Git.ps1", "${path.root}/scripts/Installers/Install-GitHub-CLI.ps1", "${path.root}/scripts/Installers/Install-PHP.ps1", "${path.root}/scripts/Installers/Install-Rust.ps1", "${path.root}/scripts/Installers/Install-Sbt.ps1", "${path.root}/scripts/Installers/Install-Chrome.ps1", "${path.root}/scripts/Installers/Install-Edge.ps1", "${path.root}/scripts/Installers/Install-Firefox.ps1", "${path.root}/scripts/Installers/Install-Selenium.ps1", "${path.root}/scripts/Installers/Install-IEWebDriver.ps1", "${path.root}/scripts/Installers/Install-Apache.ps1", "${path.root}/scripts/Installers/Install-Nginx.ps1", "${path.root}/scripts/Installers/Install-Msys2.ps1", "${path.root}/scripts/Installers/Install-WinAppDriver.ps1", "${path.root}/scripts/Installers/Install-R.ps1", "${path.root}/scripts/Installers/Install-AWS.ps1", "${path.root}/scripts/Installers/Install-DACFx.ps1", "${path.root}/scripts/Installers/Install-MysqlCli.ps1", "${path.root}/scripts/Installers/Install-SQLPowerShellTools.ps1", "${path.root}/scripts/Installers/Install-SQLOLEDBDriver.ps1", "${path.root}/scripts/Installers/Install-DotnetSDK.ps1", "${path.root}/scripts/Installers/Install-Mingw64.ps1", "${path.root}/scripts/Installers/Install-Haskell.ps1", "${path.root}/scripts/Installers/Install-Stack.ps1", "${path.root}/scripts/Installers/Install-Miniconda.ps1", "${path.root}/scripts/Installers/Install-AzureCosmosDbEmulator.ps1", "${path.root}/scripts/Installers/Install-Mercurial.ps1", "${path.root}/scripts/Installers/Install-Zstd.ps1", "${path.root}/scripts/Installers/Install-NSIS.ps1", "${path.root}/scripts/Installers/Install-Vcpkg.ps1", "${path.root}/scripts/Installers/Install-PostgreSQL.ps1", "${path.root}/scripts/Installers/Install-Bazel.ps1", "${path.root}/scripts/Installers/Install-AliyunCli.ps1", "${path.root}/scripts/Installers/Install-RootCA.ps1", "${path.root}/scripts/Installers/Install-MongoDB.ps1", "${path.root}/scripts/Installers/Install-CodeQLBundle.ps1", "${path.root}/scripts/Installers/Disable-JITDebugger.ps1"]
  }

  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    scripts           = ["${path.root}/scripts/Installers/Install-WindowsUpdates.ps1", "${path.root}/scripts/Installers/Configure-DynamicPort.ps1", "${path.root}/scripts/Installers/Configure-GDIProcessHandleQuota.ps1", "${path.root}/scripts/Installers/Configure-Shell.ps1", "${path.root}/scripts/Installers/Enable-DeveloperMode.ps1", "${path.root}/scripts/Installers/Install-LLVM.ps1"]
  }

  provisioner "windows-restart" {
    check_registry        = true
    restart_check_command = "powershell -command \"& {if ((-not (Get-Process TiWorker.exe -ErrorAction SilentlyContinue)) -and (-not [System.Environment]::HasShutdownStarted) ) { Write-Output 'Restart complete' }}\""
    restart_timeout       = "30m"
  }

  provisioner "powershell" {
    pause_before = "2m0s"
    scripts      = ["${path.root}/scripts/Installers/Wait-WindowsUpdatesForInstall.ps1", "${path.root}/scripts/Tests/RunAll-Tests.ps1"]
  }

  provisioner "powershell" {
    inline = ["if (-not (Test-Path ${var.image_folder}\\Tests\\testResults.xml)) { throw '${var.image_folder}\\Tests\\testResults.xml not found' }"]
  }

  provisioner "powershell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}"]
    inline           = ["pwsh -File '${var.image_folder}\\SoftwareReport\\SoftwareReport.Generator.ps1'"]
  }

  provisioner "powershell" {
    inline = ["if (-not (Test-Path C:\\software-report.md)) { throw 'C:\\software-report.md not found' }", "if (-not (Test-Path C:\\software-report.json)) { throw 'C:\\software-report.json not found' }"]
  }

  provisioner "file" {
    destination = "${path.root}/Windows2022-Readme.md"
    direction   = "download"
    source      = "C:\\software-report.md"
  }

  provisioner "file" {
    destination = "${path.root}/software-report.json"
    direction   = "download"
    source      = "C:\\software-report.json"
  }

  provisioner "powershell" {
    environment_vars = ["INSTALL_USER=${var.install_user}"]
    scripts          = ["${path.root}/scripts/Installers/Run-NGen.ps1", "${path.root}/scripts/Installers/Finalize-VM.ps1"]
    skip_clean       = true
  }

  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "powershell" {
    inline = ["if( Test-Path $Env:SystemRoot\\System32\\Sysprep\\unattend.xml ){ rm $Env:SystemRoot\\System32\\Sysprep\\unattend.xml -Force}", "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /mode:vm /quiet /quit", "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"]
  }

}