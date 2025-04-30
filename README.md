# run-aider.sh
Your customizable agentic Ai coding launcher

## Overview

- run-aider.sh is an extensible bash script designed to empower developers to create their personalized AI coding workflow tool.
- It provides a flexible, menu-driven interface for configuring and launching Aider with Large Language Models (LLMs).

## Philosophy

This tool is intentionally designed for continuous personal evolution. You and your team of Ai agents are encouraged to:
- Modify the list of supported LLM vendors and models
- Add new interaction modes
- Customize configuration options
- Adapt the script to your specific workflow needs

## Core Features

### Interaction Modes
- **Code Mode:** A coding collaboration with a single agent assigned to all Ai tasks.
- **Architect Mode:** A coding collaboration with one agent assigned to coding and another agent assigned to editing.

### Flexible Configuration
- Interactive mode selection (Code/Architect)
- Interactive vendor and model selection for each role
- Edit format selection  
  • **Code Mode:** `default` (Aider chooses), `whole`, `diff`, `diff-fenced`, `udiff`, `udiff-simple`  
  • **Architect Mode:** `default` (Aider chooses), `editor-whole`, `editor-diff`, `editor-diff-fenced`
- Secure API management (Environment variables or local file)
- Configuration handled via `.aider.conf.yml` (e.g. `--vim`, `--read`, etc.)

**Customization:** Easily add new vendors and models by modifying a json config file.

## Getting Started

### Prerequisites
- Bash shell
- [Aider-Chat](https://aider.chat) installed (`python -m pip install aider-install && aider-install`)
- API keys for desired LLM providers

### Installation
```bash
# Clone the repository
git clone https://github.com/your-username/run-aider.git
cd run-aider

# Make the script executable
chmod +x run-aider.sh
```

### Usage
```bash
# Launch the interactive AI coding assistant
./run-aider.sh
```

## Customization

**Configuration File**
   - The script requires a configuration file named `aider_config.json` in the same directory.
   - This file defines all available vendors, models, and edit formats.
   - You must maintain this file to keep up with new model releases and deprecations.

**JSON Configuration Format**
```json
{
  "vendors": [
    "OPENAI",
    "ANTHROPIC",
    "GOOGLE",
    "DEEPSEEK"
  ],
  "models": {
    "OPENAI": [
      "gpt-4o",
      "gpt-4-turbo"
    ],
    "ANTHROPIC": [
      "claude-3-5-haiku-20241022"
    ],
    "GOOGLE": [
      "gemini/gemini-2.5-pro-exp-03-25"
    ],
    "DEEPSEEK": [
      "deepseek/deepseek-coder"
    ]
  },
  "edit_formats": {
    "code": [
      "whole",
      "diff",
      "diff-fenced",
      "udiff",
      "udiff-simple"
    ],
    "architect": [
      "editor-whole",
      "editor-diff",
      "editor-diff-fenced"
    ]
  }
}
```

**Requirements**
   - The `jq` command-line tool must be installed for JSON parsing.
   - All vendors listed in the `vendors` array must have corresponding entries in the `models` object.
   - Both `code` and `architect` edit formats must be defined (the **Default** option is added dynamically by `run-aider.sh`).

## Documentation
- Interactive help: `./run-aider.sh -h`
- Detailed documentation: `README.md`
- Aider-specific features and formats: `README-aider.md`

## License

MIT License - See `LICENSE` for details.

**Your Tool, Your Rules: Evolve, Customize, Innovate**

## Example Interactions

These example interactions showcase the tool's interactive menu system, demonstrating:
- Mode selection (Code vs. Architect)
- Vendor and model selection
- Edit format selection (including **Default (Aider chooses)**)
- Command preview before launch

> Note: The actual list of edit formats displayed in the interactive menus will reflect the contents of your current `aider_config.json` plus the dynamically added **Default** option.  
> With the default configuration shown above, you should see **six** options in Code mode (`default`, `whole`, `diff`, `diff-fenced`, `udiff`, `udiff-simple`) and **four** options in Architect mode (`default`, `editor-whole`, `editor-diff`, `editor-diff-fenced`). The transcript below was captured before the additional modes were added and therefore shows fewer options.

```
run-aider.sh
Loading configuration from ../run-aider/aider_config.json...
Configuration loaded successfully from ../run-aider/aider_config.json
Attempting to load API keys...
Checking environment variables for API keys...
All required API keys found in environment variables.
Loading API keys from file: /Users/markmorris/.llm_api_keys
API key loading process complete.

================================================================================
                         SELECT AIDER OPERATING MODE
================================================================================
1. Code Mode
2. Architect Mode
0. Exit
================================================================================
Enter your choice [1-2, Enter=0]: 1

================================================================================
                           SELECT CODE MODE VENDOR
================================================================================
1. GOOGLE
2. ANTHROPIC
3. OPENAI
4. DEEPSEEK
0. Back
================================================================================
Enter your choice [1-4, Enter=0]: 1

================================================================================
                            SELECT CODE MODE MODEL
================================================================================
1. gemini/gemini-2.5-pro-exp-03-25
2. gemini/gemini-2.5-pro-preview-03-25
3. gemini/gemini-2.0-flash-exp
4. gemini/gemini-2.0-flash
0. Back
================================================================================
Enter your choice [1-4, Enter=0]: 1

================================================================================
                         SELECT CODE MODE EDIT FORMAT
================================================================================
1. Default (Aider chooses)
2. whole
3. diff
4. diff-fenced
5. udiff
6. udiff-simple
0. Back
================================================================================
Enter your choice [1-6, Enter=0]: 1
...
```

(Transcript truncated for brevity.)

