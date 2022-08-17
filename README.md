# wsl
WSL Setup Script for Ubuntu/Centos/Rhel

## Setup

### Install WSL on Windows Server 2022

Follow [Install Linux on Windows with WSL](https://docs.microsoft.com/en-us/windows/wsl/install)

```
wsl --install
```

```
wsl --update
```

### Install WSL on previous versions of Windows Server
To install WSL on Windows Server 2019 (version 1709+), you can follow the manual install steps below.

### Enable the Windows Subsystem for Linux

```
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
```

## Manual installation steps for older versions of WSL

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


## Install CentOS8-steam with wsl command

```
wsl --set-default-verion 2
```
```
## Download CentOS 8 Stream Linux for WSL

curl -sSL https://github.com/mishamosher/CentOS-WSL/releases/download/8-stream-20201019/CentOS8-stream.zip -o CentOS8-stream.zip
```

![unzip](https://raw.githubusercontent.com/govindinfi/wsl/main/4.jpg)

Run Installer CentOS 8 Stream for Windows 10

![run](https://raw.githubusercontent.com/govindinfi/wsl/main/2.jpg)
![done](https://raw.githubusercontent.com/govindinfi/wsl/main/1.jpg)

- Now, again inside the same folder, run the same CentOS executable however this time you will get the command-line interface with the root user. Start using your CentOS 8 Stream WSL.



## Setup WSL for Web Application

```
curl -sSL https://raw.githubusercontent.com/govindinfi/wsl/main/get-setup.sh | sh
```

![install](https://raw.githubusercontent.com/govindinfi/wsl/main/Screenshot%202022-08-17%20193738.png)

Thank You!