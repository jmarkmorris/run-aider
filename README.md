# Run Aider: Your Interactive Launcher for Aider-Chat

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) <!-- Update if license differs -->

Tired of typing long, complex `aider` commands? Wish you could effortlessly switch models, modes, or troubleshoot edits by changing formats on the fly? **Run Aider** is your command center for a smoother, more powerful `aider-chat` experience!

This `bash` script wraps `aider` in an intuitive interactive terminal menu. Configure your AI coding sessions precisely how you want, without memorizing a single flag. Spend less time setting up and more time coding with your AI partner.

## Why Use Run Aider?

*   **Effortless Configuration:** Ditch the command-line flag juggling. Select modes, vendors, and models through a clear, step-by-step menu.
*   **Dual Modes:** Instantly switch between standard **Code Mode** for direct interaction and **Architect Mode** for sophisticated planning and implementation using separate LLMs.
*   **Multi-Vendor & Model Support:** Works with Google Gemini, Anthropic Claude, OpenAI GPT, and Deepseek models. Choose the best brain for the job, including specific models for Architect and Editor roles.
*   **Secure API Key Handling:** Automatically detects and loads API keys from environment variables or dedicated files (`$PRIMARY_KEYS_FILE` or `~/.llm_api_keys`), keeping your secrets safe and out of shell history.
*   **On-the-Fly Edit Format Switching:** This is a game-changer! If `aider` fails to apply changes (often due to `diff` issues), the pre-launch menu lets you instantly switch between `diff`/`whole` (or `editor-diff`/`editor-whole`) formats before retrying. See [Understanding Edit Formats](#understanding-edit-format-selection) below.
*   **Context-Aware AI:** Automatically includes `README-prompts.md` (your coding standards) and `README-ask.md` (useful `aider` prompts) in the chat context, ensuring the AI adheres to your project's guidelines from the start.
*   **Sensible Defaults:** Launches `aider` with common useful options like `--vim` (for Vim keybindings) and `--no-auto-commit` by default.

## Features

*   **Interactive Menu System:** User-friendly setup flow.
*   **Mode Selection:** Code vs. Architect.
*   **Vendor Selection:** Google, Anthropic, OpenAI, Deepseek.
*   **Model Selection:** Granular choice for Code, Architect, and Editor roles.
*   **API Key Management:** Secure loading from environment or files.
*   **Pre-launch Confirmation:** Review the exact command and current edit format.
*   **Edit Format Switching:** Toggle between `diff` and `whole` based formats *before* launch to improve edit reliability.
*   **Automatic File Inclusion:** Adds `README-prompts.md` and `README-ask.md`.
*   **Help Option:** Comprehensive usage guide via `./run-aider.sh -h`.

## Prerequisites

1.  **Bash:** The script requires `bash` to run. (Tested on macOS, likely compatible with Linux).
2.  **Aider-Chat:** You must have `aider-chat` installed and functional. See the official [Aider Installation Guide](https://aider.chat/docs/install.html) or `README-aider.md`.
3.  **LLM API Keys:** Obtain API keys for the LLM vendors you plan to use.

## Installation

1.  **Clone the repository (or download the script):**
    ```bash
    # Replace with your actual repository URL if hosting on GitHub/GitLab etc.
    git clone https://github.com/your-username/your-repo-name.git
    cd your-repo-name
    ```
    Alternatively, just download `run-aider.sh`, `README-prompts.md`, and `README-ask.md` into your project directory.
2.  **Make the script executable:**
    ```bash
    chmod +x run-aider.sh
    ```

## Usage

Navigate to your project directory in the terminal and simply run:

