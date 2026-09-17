# Set up the dev container

There are two configurations. VS Code asks which one when you choose **Reopen in Container**.

| Configuration | Open it from | Use it to |
|---|---|---|
| **i2 - Azure tools (works from Windows)** | any checkout, e.g. `D:\Projects\i2` | deploy and operate: `scripts/10`, `20`, `40`, `50`, `60` |
| **i2 - ADT + Azure (open from WSL)** | a clone inside WSL 2 (`/home/<you>/i2`) | everything above, plus building images with ADT: `scripts/05`, `30` |

Both have az, Bicep, kubectl, kubelogin, jq and the Docker CLI (using Docker Desktop).

**Why two?** ADT starts containers that mount your workspace by its host path, so the ADT configuration puts the workspace at the same path inside the container. A Windows path such as `D:\Projects\i2` is not a valid Linux path, so VS Code shows a **blank window** if you open the ADT configuration from Windows. Use the Azure tools configuration there, or clone into WSL for image builds.

**You need:** Docker Desktop (at least 5 GB memory) and VS Code with the Dev Containers extension. For image builds, also WSL 2 and the i2 Analyze minimal toolkit.

## Azure tools (from Windows)

1. Open the repo folder in VS Code.
2. **F1 → Dev Containers: Reopen in Container** → **i2 - Azure tools (works from Windows)**. The first build takes a few minutes.
3. Sign in and create your settings file:
   ```bash
   az login
   cp scripts/env.example scripts/env.sh
   ```

## ADT + Azure (from WSL, for image builds)

1. **Clone inside WSL**, not on a Windows drive:
   ```bash
   cd ~ && git clone <this repository URL> i2 && cd i2 && code .
   ```
2. **F1 → Dev Containers: Reopen in Container** → **i2 - ADT + Azure (open from WSL)**.
3. Sign in and create your settings file:
   ```bash
   az login
   cp scripts/env.example scripts/env.sh
   ```
4. Put the toolkit at `adt/pre-reqs/i2analyzeMinimal.tar.gz`, then install ADT:
   ```bash
   scripts/05-install-adt.sh
   ```
   If you installed ADT before adding the toolkit, add it now and run `manage-environment -t update`.

`az login` is kept in a Docker volume, so both configurations share it and it survives rebuilds. `adt/` and `scripts/env.sh` are git-ignored, so the licensed toolkit and your settings are never committed.

**VS Code went blank?** You opened the ADT configuration from a Windows path. Close the window, reopen the folder locally (**F1 → Dev Containers: Reopen Folder Locally**), and pick the Azure tools configuration.
