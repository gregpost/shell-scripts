#!/usr/bin/env bash
set -euo pipefail

echo "Updating system packages…"
sudo apt update
sudo apt install -y python3 python3-pip python3-venv curl

echo "Installing pipx (for isolated installations)…"
python3 -m pip install --user pipx
python3 -m pipx ensurepath

# Reload shell to ensure pipx is in PATH
export PATH="$PATH:$HOME/.local/bin"

echo "Installing ShellGPT via pipx…"
pipx install shell-gpt

echo "Installing Ollama for local models support…"
curl -fsSL https://ollama.com/install.sh | sh

echo "Pulling a local model (mistral:7b-instruct)…"
ollama pull mistral:7b-instruct  # or any other preferred model :contentReference[oaicite:1]{index=1}

echo "Configuring ShellGPT to use Ollama and the local model…"
mkdir -p ~/.config/shell_gpt
cat > ~/.config/shell_gpt/.sgptrc << EOF
[DEFAULT]
DEFAULT_MODEL = ollama/mistral:7b-instruct
USE_LITELLM = true
OPENAI_USE_FUNCTIONS = false
EOF

echo "Shell integration (optional): adding hotkeys…"
sgpt --install-integration  # adds to ~/.bashrc or ~/.zshrc :contentReference[oaicite:2]{index=2}

echo "Installed! Restart your terminal or run:"
echo "  source ~/.bashrc  # or ~/.zshrc"

echo "🎉 To start chatting, run either:"
echo "  sgpt --chat"
echo "  sgpt -s \"your shell command prompt\""
echo
echo "For code-only responses:"
echo "  sgpt --code \"write a quicksort in python\""

