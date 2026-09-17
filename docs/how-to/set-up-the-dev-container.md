# Set up the dev container

All work on this repo happens in one dev container, **i2 - ADT + Azure (open from WSL)**: editing, git, `az`, Bicep, kubectl, and building the i2 images with ADT. It is ADT's own dev container plus the Azure tools (az, Bicep, kubectl, kubelogin, jq, Docker CLI).

**You need:** Docker Desktop (at least 5 GB memory, WSL 2 backend), WSL 2 (for example Ubuntu), and VS Code with the **Dev Containers** and **WSL** extensions. For image builds, also the i2 Analyze minimal toolkit.

**Why WSL?** ADT starts containers that mount your workspace by its host path, so the workspace must sit at the same path inside and outside the container. A Windows path such as `D:\Projects\i2` is not a valid Linux path, so the clone must live inside WSL.

## Steps

1. **Clone inside WSL**, not on a Windows drive. Open your WSL terminal (Start menu → **Ubuntu**, or whichever Linux you installed):
   ```bash
   cd ~ && git clone <this repository URL> i2
   ```
2. **Open it in VS Code**, from the same WSL terminal:
   ```bash
   cd ~/i2 && code .
   ```
   Not sure which Linux you have? In PowerShell, `wsl -l -v` lists them; the one marked `*` is the default.
3. **F1 → Dev Containers: Reopen in Container**. The first build takes a few minutes.
4. Sign in and create your settings file:
   ```bash
   az login
   cp scripts/env.example scripts/env.sh
   ```
5. When you have the toolkit, put it at `adt/pre-reqs/i2analyzeMinimal.tar.gz`, then install ADT:
   ```bash
   scripts/05-install-adt.sh
   ```
   If you installed ADT before adding the toolkit, add it now and run `manage-environment -t update`.

**Every day:** WSL terminal → `cd ~/i2 && code .` → reopen in the container → `git pull`.

`az login` is kept in a Docker volume, so it survives rebuilds. `adt/` and `scripts/env.sh` are git-ignored, so the licensed toolkit and your settings are never committed.

**VS Code went blank?** The folder was opened from a Windows path. Close the window and open the WSL clone (step 2).
