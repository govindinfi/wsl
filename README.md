# wsl
WSL Setup Script for Ubuntu/Centos/Rhel

## Setup

### Install WSL on Windows Server 2022

```
wsl --install
```

### Install WSL on previous versions of Windows Server
To install WSL on Windows Server 2019 (version 1709+), you can follow the manual install steps below.

### Enable the Windows Subsystem for Linux

```
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
```

#### Enable the Windows Subsystem for Linux

```
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```

### Enable Virtual Machine feature

```
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

## Install Ubuntu with wsl command 

```
wsl --set-default-verion 1
```
```
wsl install -d ubuntu 
```

```
curl -sSL https://raw.githubusercontent.com/govindinfi/wsl/main/get-setup.sh | bash
```

