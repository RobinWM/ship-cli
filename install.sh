#!/bin/bash
set -e

INSTALL_DIR="${INSTALL_DIR:-$HOME/.submit-to-cli/bin}"
mkdir -p "$INSTALL_DIR"

# Detect platform
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Map architecture
case "$ARCH" in
  x86_64) ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Installing submit-to-cli for $OS/$ARCH..."

# If a pre-built binary exists in a release, download it
RELEASE_URL="https://github.com/allinaigc/submit-to-cli/releases/latest/download/submit-to-cli-${OS}-${ARCH}"
if command -v curl &>/dev/null; then
  CURL_CMD="curl -fsSL"
elif command -v wget &>/dev/null; then
  CURL_CMD="wget -qO-"
else
  echo "Error: curl or wget is required"
  exit 1
fi

# Try to download pre-built binary
if $CURL_CMD --head "$RELEASE_URL" &>/dev/null; then
  echo "Downloading binary from $RELEASE_URL..."
  if command -v curl &>/dev/null; then
    curl -fsSL "$RELEASE_URL" -o "$INSTALL_DIR/brennan-cli"
  else
    wget -q "$RELEASE_URL" -O "$INSTALL_DIR/brennan-cli"
  fi
  chmod +x "$INSTALL_DIR/submit-to-cli"
  echo "✅ Installed to $INSTALL_DIR/submit-to-cli"
else
  # Fall back to building from source
  echo "No pre-built binary found. Building from source..."
  cd "$(dirname "$0")"
  npm install
  npm run build
  cp dist/index.js "$INSTALL_DIR/submit-to-cli"
  chmod +x "$INSTALL_DIR/submit-to-cli"
  echo "✅ Built and installed to $INSTALL_DIR/submit-to-cli"
fi

# Add to PATH if needed
SHELL_RC="$HOME/.bashrc"
if [ -f "$SHELL_RC" ]; then
  if ! grep -q "$INSTALL_DIR" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "# submit-to-cli" >> "$SHELL_RC"
    echo "export PATH=\"\$HOME/.submit-to-cli/bin:\$PATH\"" >> "$SHELL_RC"
    echo "Added $INSTALL_DIR to PATH in $SHELL_RC"
  fi
fi

echo "✅ Done! Run 'submit-to-cli --help' to get started."
