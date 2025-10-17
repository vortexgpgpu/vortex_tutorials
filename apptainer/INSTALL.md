Apptainer (formerly Singularity) is a container system optimized for HPC and secure scientific environments, so installation varies by OS family.


## 🐧 1. Ubuntu / Debian
#### ✅ Option A — Install via .deb package 

```
sudo apt update
sudo apt install -y build-essential libseccomp-dev pkg-config squashfs-tools cryptsetup wget

# Download the latest stable release
wget https://github.com/apptainer/apptainer/releases/download/v1.2.2/apptainer_1.2.2_amd64.deb

# Install
sudo apt install ./apptainer_1.2.2_amd64.deb

# Verify
apptainer --version
```

#### ✅ Option B — Build from source (if .deb not available)
```
sudo apt update
sudo apt install -y build-essential uuid-dev libseccomp-dev pkg-config squashfs-tools cryptsetup wget git golang-go

cd /tmp
wget https://github.com/apptainer/apptainer/releases/download/v1.2.2/apptainer-1.2.2.tar.gz
tar -xzf apptainer-1.2.2.tar.gz
cd apptainer-1.2.2
./mconfig
make -C builddir
sudo make -C builddir install

# Verify
apptainer --version
```


## 🧱 2. RHEL / AlmaLinux / Rocky / CentOS
#### ✅ Option A — Install via EPEL (Recommended)
```
sudo dnf install -y epel-release
sudo dnf config-manager --set-enabled crb
sudo dnf install -y apptainer
```

Works for RHEL 8/9, AlmaLinux, Rocky Linux, CentOS Stream, etc.

#### ✅ Option B — Build from source
```
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y golang libseccomp-devel squashfs-tools cryptsetup wget git pkg-config make

cd /tmp
wget https://github.com/apptainer/apptainer/releases/download/v1.2.2/apptainer-1.2.2.tar.gz
tar -xzf apptainer-1.2.2.tar.gz
cd apptainer-1.2.2
./mconfig
make -C builddir
sudo make -C builddir install

# Verify
apptainer --version
```


## 🍎 3. macOS

Apptainer doesn’t run natively on macOS — it’s a Linux-only system (needs Linux kernel namespaces).
But you can run it using Linux virtual environments:

#### ✅ Option A — Using Homebrew + Apptainer inside a Linux VM

Install Homebrew and a lightweight Linux VM (like multipass):

```
brew install --cask multipass
multipass launch --name ubuntu --cpus 4 --mem 4G --disk 20G
multipass shell ubuntu
```

Inside the VM, follow the Ubuntu install steps above.

#### ✅ Option B — Using Docker + Apptainer inside container
```
docker run -it --privileged ghcr.io/apptainer/apptainer:latest bash

# Verify
apptainer --version
```


## 🪟 4. Windows 10/11

Apptainer requires Linux namespaces → it cannot run directly on native Windows.

#### ✅ Option A — Use WSL2 (Windows Subsystem for Linux)

Enable WSL2 and install Ubuntu:
```
wsl --install -d Ubuntu
```
Inside WSL Ubuntu terminal: Follow the Ubuntu install steps above (either using Ubuntu Debian package / Build from source).


#### ✅ Option B — Use a full Linux VM (VirtualBox, VMware, or WSL2 Ubuntu)

If you need GPU or privileged access, use a full Linux VM with Apptainer installed inside.




### Reference:
https://apptainer.org/docs/admin/main/installation.html