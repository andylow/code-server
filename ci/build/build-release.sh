#!/usr/bin/env bash
set -euo pipefail

# This script requires code-server and vscode to be built with matching MINIFY.

# MINIFY controls whether minified vscode is bundled and whether
# any included node_modules are pruned for production.
MINIFY="${MINIFY-true}"

main() {
  cd "$(dirname "${0}")/../.."
  source ./ci/build/lib.sh

  VSCODE_SRC_PATH="lib/vscode"
  VSCODE_OUT_PATH="$RELEASE_PATH/lib/vscode"

  mkdir -p "$RELEASE_PATH"

  bundle_code_server
  bundle_vscode

  rsync README.md "$RELEASE_PATH"
  rsync LICENSE.txt "$RELEASE_PATH"
  rsync ./lib/vscode/ThirdPartyNotices.txt "$RELEASE_PATH"
}

bundle_code_server() {
  rsync out dist "$RELEASE_PATH"

  # For source maps and images.
  mkdir -p "$RELEASE_PATH/src/browser"
  rsync src/browser/media/ "$RELEASE_PATH/src/browser/media"
  mkdir -p "$RELEASE_PATH/src/browser/pages"
  rsync src/browser/pages/*.html "$RELEASE_PATH/src/browser/pages"

  rsync yarn.lock "$RELEASE_PATH"

  # Adds the commit to package.json
  jq --slurp '.[0] * .[1]' package.json <(
    cat << EOF
  {
    "commit": "$(git rev-parse HEAD)",
    "scripts": {
      "postinstall": "cd lib/vscode && yarn --production && cd extensions && yarn --production"
    }
  }
EOF
  ) > "$RELEASE_PATH/package.json"
}

bundle_vscode() {
  mkdir -p "$VSCODE_OUT_PATH"
  rsync "$VSCODE_SRC_PATH/out-vscode${MINIFY+-min}/" "$VSCODE_OUT_PATH/out"
  rsync "$VSCODE_SRC_PATH/.build/extensions/" "$VSCODE_OUT_PATH/extensions"
  rm -Rf "$VSCODE_OUT_PATH/extensions/node_modules"
  rsync "$VSCODE_SRC_PATH/extensions/package.json" "$VSCODE_OUT_PATH/extensions"
  rsync "$VSCODE_SRC_PATH/extensions/yarn.lock" "$VSCODE_OUT_PATH/extensions"
  rsync "$VSCODE_SRC_PATH/extensions/postinstall.js" "$VSCODE_OUT_PATH/extensions"

  mkdir -p "$VSCODE_OUT_PATH/resources/linux"
  rsync "$VSCODE_SRC_PATH/resources/linux/code.png" "$VSCODE_OUT_PATH/resources/linux/code.png"

  rsync "$VSCODE_SRC_PATH/yarn.lock" "$VSCODE_OUT_PATH"

  # Adds the commit and date to product.json
  jq --slurp '.[0] * .[1]' "$VSCODE_SRC_PATH/product.json" <(
    cat << EOF
  {
    "commit": "$(git rev-parse HEAD)",
    "date": $(jq -n 'now | todate')
  }
EOF
  ) > "$VSCODE_OUT_PATH/product.json"

  # We remove the scripts field so that later on we can run
  # yarn to fetch node_modules if necessary without build scripts
  # being ran.
  # We cannot use --no-scripts because we still want dependant package scripts to run
  # for native modules to be rebuilt.
  jq 'del(.scripts)' < "$VSCODE_SRC_PATH/package.json" > "$VSCODE_OUT_PATH/package.json"
}

main "$@"
