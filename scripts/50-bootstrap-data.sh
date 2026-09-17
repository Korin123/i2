#!/usr/bin/env bash
# (Re-)run only the Information Store initialisation (db-init Job). It is part of
# scripts/40-deploy-workload.sh, where it runs before Liberty as in ADT's deploy order;
# this wrapper is for resuming a failed db-init on its own. Completed steps are skipped.
exec "$(dirname "$0")/40-deploy-workload.sh" database
