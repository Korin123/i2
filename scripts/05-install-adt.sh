#!/usr/bin/env bash
# Install i2's analyze-deployment-tooling (ADT) into adt/ (git-ignored), pinned to
# ADT_VERSION. Run inside the dev container. Uses ADT's own bootstrap at the matching
# tag, which pulls i2group/i2eng-analyze-containers-client:<version> and lays out the
# scripts/, configs/, pre-reqs/ tree.
# Put the i2 Analyze minimal toolkit at adt/pre-reqs/i2analyzeMinimal.tar.gz first if you can:
# bootstrap then also builds the core images (solr_redhat, solr_client_redhat, i2a_tools_redhat).
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
[ -f "$here/env.sh" ] && source "$here/env.sh"
ADT_VERSION="${ADT_VERSION:-3.2.2}"
dest="$root/adt"

mkdir -p "$dest/pre-reqs"
curl -fsSL "https://raw.githubusercontent.com/i2group/analyze-deployment-tooling/v${ADT_VERSION}/bootstrap" \
  -o "$dest/bootstrap"
chmod +x "$dest/bootstrap"
"$dest/bootstrap" -p "$dest" -o "$ADT_VERSION" -y

echo ">>> ADT ${ADT_VERSION} installed in adt/. Next:"
echo "    1. toolkit not in adt/pre-reqs yet? copy it to adt/pre-reqs/i2analyzeMinimal.tar.gz, then: manage-environment -t update"
echo "    2. create the base-demo config and build: docs/how-to/build-and-push-images.md (step A3 on)"
