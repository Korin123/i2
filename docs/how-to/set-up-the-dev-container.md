# Set up the dev container

All work on this repo happens in one dev container, **i2 - ADT + Azure (open from WSL)**: editing, git, `az`, Bicep, kubectl, and building the i2 images with ADT. You install nothing else: the tools are inside the container.

**Why WSL?** ADT starts containers that mount your workspace by its host path, so the workspace must sit at the same path inside and outside the container. A Windows path such as `D:\Projects\i2` is not a valid Linux path, so the repo must live **inside WSL**. WSL is only where the folder lives; you do not work in WSL itself.

The examples use the folder `~/dev/projects/i2`. Any folder inside WSL works.

---

## New PC (once)

### 1. Install on Windows
| Install | Check |
|---|---|
| **WSL with Ubuntu**: PowerShell as administrator → `wsl --install`, then restart | PowerShell → `wsl -l -v` lists Ubuntu, `VERSION 2` |
| **Docker Desktop** | Settings → General: **Use the WSL 2 based engine** on. Settings → Resources → **WSL integration**: your Ubuntu on. Settings → Resources: memory at least 5 GB |
| **VS Code** with the **Dev Containers** and **WSL** extensions | Extensions view shows both installed |

### 2. Open Ubuntu
**Do:** Start menu → **Ubuntu**. The first time, it asks you to create a Linux username and password.
**You should see:** a prompt like `<you>@<pc>:~$`.

### 3. Download the repo into WSL
**Do:** in the Ubuntu window:
```bash
mkdir -p ~/dev/projects && cd ~/dev/projects && git clone <repository URL> i2
```
for example `git clone https://github.com/Korin123/i2.git i2`. Ubuntu already includes git. A public repository needs no sign-in to download.
**You should see:** `Cloning into 'i2'...` and `done`.

### 4. Open it in VS Code
**Do:** in the same Ubuntu window:
```bash
cd ~/dev/projects/i2 && code .
```
The first time, VS Code installs its WSL support, which takes a minute.
**You should see:** VS Code with **WSL: Ubuntu** in the bottom-left corner.

### 5. Open the dev container
**Do:** click **Reopen in Container** (or **F1 → Dev Containers: Reopen in Container**). The first build takes a few minutes.
**You should see:** **Dev Container: i2 - ADT + Azure** in the bottom-left corner.

### 6. Sign in to Azure and create your settings
**Do:** Terminal → New Terminal (this terminal is inside the container):
```bash
az login
cp scripts/env.example scripts/env.sh
```
Edit `scripts/env.sh`: `SUBSCRIPTION_ID`, `LOCATION`, `I2_ENV` (for example `alpha`). This file is git-ignored, so every PC needs its own.
**You should see:** `az account show --query name -o tsv` prints your subscription.

### 7. (When you have the toolkit) install ADT
Follow [build-and-push-images.md](build-and-push-images.md), Part A.

---

## Every day

1. Start Docker Desktop.
2. Ubuntu window:
   ```bash
   cd ~/dev/projects/i2 && code .
   ```
3. VS Code: **Reopen in Container**.
4. VS Code terminal:
   ```bash
   git pull
   ```

---

## Pushing your changes to GitHub

Downloading needs no sign-in; `git push` does. The simplest way is to let WSL use the Windows sign-in window (needs **Git for Windows** installed on the PC). Once, in the Ubuntu window:
```bash
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
git config --global user.name "<your name>"
git config --global user.email "<your email>"
```
The first `git push` then opens a browser window to sign in to GitHub. The dev container reuses this sign-in.

---

## Good to know

- `az login` is kept in a Docker volume, so it survives container rebuilds.
- `adt/` (the licensed toolkit) and `scripts/env.sh` are git-ignored and never committed.
- Moved the folder? VS Code builds the container again for the new location the first time. That is normal.

## Certificate errors (corporate network)

**Symptom:** `az` is missing after the container builds, and running `bash .devcontainer/azure-tools.sh` shows `self-signed certificate in certificate chain` or `CERTIFICATE_VERIFY_FAILED`.

**Why:** your network inspects secure traffic and re-signs it with your organisation's own root certificate. Windows trusts it; the container does not yet.

**Fix (once per PC):**

1. **Export the certificate from Windows.** PowerShell (not as administrator):
   ```powershell
   Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root | Select-Object Subject, Thumbprint
   ```
   Find your organisation's root, often named after the company or the proxy product (for example Zscaler, Netskope, Palo Alto). Not sure which? In the dev container, `curl -sv https://pypi.org 2>&1 | grep issuer` shows the name. Then export it (replace the thumbprint):
   ```powershell
   $c = Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root | Where-Object Thumbprint -eq '<thumbprint>' | Select-Object -First 1
   "-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($c.RawData, 'InsertLineBreaks') + "`n-----END CERTIFICATE-----" | Out-File -Encoding ascii $HOME\Downloads\corp-root.crt
   ```
   **You should see:** `corp-root.crt` in your Downloads folder.
2. **Put it in the repo.** Drag `corp-root.crt` from Downloads onto the `.devcontainer/certs` folder in the VS Code Explorer. It is git-ignored, never committed.
3. **Install the tools again.** VS Code terminal:
   ```bash
   bash .devcontainer/azure-tools.sh
   ```
   **You should see:** `Trusted 1 extra root CA(s)` and, at the end, `Azure tools installed`.
4. Open a **new** terminal. `az version` now works. Future rebuilds of the container pick up the certificate automatically.

## Problems

| Problem | Fix |
|---|---|
| VS Code window goes **blank** | The folder was opened from a Windows path (for example `D:\...`). Close it and open the WSL copy (step 4) |
| `code: command not found` in Ubuntu | Install VS Code on Windows (tick **Add to PATH**), then close and reopen Ubuntu |
| `az: command not found` in the container | Setup may still be running (wait, then new terminal). Otherwise run `bash .devcontainer/azure-tools.sh`; certificate error → [Certificate errors](#certificate-errors-corporate-network) |
| **Reopen in Container** fails with a Docker error | Docker Desktop not running, or WSL integration for Ubuntu is off (step 1) |
| Can't find the folder | In Ubuntu: `ls ~/dev/projects`. In Windows File Explorer: **Linux → Ubuntu → home → \<you\> → dev → projects → i2** |
| Which Linux do I have? | PowerShell: `wsl -l -v`; the one marked `*` is the default |
