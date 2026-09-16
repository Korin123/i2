# Set up the dev container

One container has everything: i2's ADT (builds the images) plus az, Bicep, kubectl and kubelogin (deploys them).

**You need:** Windows with WSL 2 (or macOS), Docker Desktop with at least 5 GB memory, VS Code with the Dev Containers extension, and the i2 Analyze minimal toolkit.

1. **Clone inside WSL**, not on a Windows drive. ADT needs the same path inside and outside the container.
   ```bash
   cd ~ && git clone https://github.com/Korin123/i2.git && cd i2 && code .
   ```
2. In VS Code: **F1 → Dev Containers: Reopen in Container**. The first build takes a few minutes.
3. Sign in to Azure:
   ```bash
   az login
   ```
4. Create your settings file and fill it in:
   ```bash
   cp scripts/env.example scripts/env.sh
   ```
5. Put the toolkit at `adt/pre-reqs/i2analyzeMinimal.tar.gz`, then install ADT:
   ```bash
   scripts/05-install-adt.sh
   ```
   If you installed ADT before adding the toolkit, add it now and run `manage-environment -t update`.

`adt/` and `scripts/env.sh` are git-ignored, so the licensed toolkit and your settings are never committed.
