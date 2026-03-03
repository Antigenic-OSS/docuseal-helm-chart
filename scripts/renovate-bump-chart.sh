#!/usr/bin/env bash
set -euo pipefail

current="$(sed -n 's/^version:[[:space:]]*//p' Chart.yaml | head -n1 | tr -d '"')"
IFS='.' read -r major minor patch <<<"${current}"
patch=$((patch + 1))
next="${major}.${minor}.${patch}"
image_tag="$(sed -n '/^image:/,/^[^[:space:]]/s/^[[:space:]]*tag:[[:space:]]*//p' values.yaml | head -n1 | tr -d '"')"

sed -i.bak "s/^version:[[:space:]]*.*/version: ${next}/" Chart.yaml
rm -f Chart.yaml.bak

if [ -n "${image_tag}" ]; then
  sed -i.bak "s/^appVersion:[[:space:]]*.*/appVersion: \"${image_tag}\"/" Chart.yaml
  rm -f Chart.yaml.bak
fi

sed -i.bak "s/^[[:space:]]*targetRevision:[[:space:]]*.*/    targetRevision: ${next}/" examples/argocd/application.yaml
rm -f examples/argocd/application.yaml.bak

sed -i.bak "s/^[[:space:]]*version:[[:space:]]*.*/      version: ${next}/" examples/flux/helmrelease.yaml
rm -f examples/flux/helmrelease.yaml.bak
