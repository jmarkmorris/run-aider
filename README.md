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
- **Dedicated menu for selecting Aider edit format** (overrides Aider defaults)
- Secure API management (Environment variables or local file)
- Contextual AI interaction (auto-includes `README-prompts.md` and `README-ask.md`)

**Customization:** Easily add new vendors and models by modifying the script's model arrays.

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

**Vendor and Model Changes**
   - Edit `run-aider.sh` to add new vendors and models to the respective arrays (e.g., `GOOGLE_MODELS`, `VENDORS`).

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
- **Dedicated edit format selection step**
- Command preview before launch

### Code Mode Selection
```
Step 1: Select Aider Operating Mode
=====================================
             SELECT MODE
=====================================
1. Code Mode
2. Architect Mode
0. Exit
=====================================
Enter your choice [1-2, Enter=0]: 1


Select Code VENDOR:
=====================================
1. GOOGLE
2. ANTHROPIC
3. OPENAI
4. DEEPSEEK
0. Back
=====================================
Enter your choice [1-4, Enter=0]: 3


Select Code MODEL:
=====================================
1. chatgpt-4o-latest
2. gpt-4.5-preview
3. openai/o3-mini
4. gpt-4o
5. gpt-4-turbo
0. Back
=====================================
Enter your choice [1-5, Enter=0]: 4


Select Edit Format for Code Mode:
=====================================
1. whole
2. diff
3. search_replace
0. Back
=====================================
Enter your choice [1-3, Enter=0]: 1


Launching Aider: Code Mode
Main Model:      OPENAI/gpt-4o
Edit Format:     whole
-------------------------------------
Command to Run:
aider --vim --no-auto-commit --read README-prompts.md --read README-ask.md --model gpt-4o --chat-mode code --edit-format whole
-------------------------------------
1. Launch Aider with this command
2. Back to Main Menu (Abort Launch)
-------------------------------------
Enter choice [1-2, 0=Back, Enter=1]:
```



### Architect Mode Selection
```
Step 1: Select Aider Operating Mode
=====================================
             SELECT MODE
=====================================
1. Code Mode
2. Architect Mode
0. Exit
=====================================
Enter your choice [1-2, Enter=0]: 2


Select Architect VENDOR:
=====================================
1. GOOGLE
2. ANTHROPIC
3. OPENAI
4. DEEPSEEK
0. Back
=====================================
Enter your choice [1-4, Enter=0]: 2


Select Architect MODEL:
=====================================
1. claude-3-7-sonnet-20250219
2. claude-3-5-haiku-20241022
0. Back
=====================================
Enter your choice [1-2, Enter=0]: 1


Select Editor VENDOR:
=====================================
1. GOOGLE
2. ANTHROPIC
3. OPENAI
4. DEEPSEEK
9. Use same VENDOR and MODEL as Architect
0. Back
=====================================
Enter your choice [1-4, 9, Enter=0]: 4


Select Editor MODEL:
=====================================
1. deepseek/deepseek-coder
2. deepseek-reasoner
3. deepseek/deepseek-reasoner
4. deepseek/deepseek-chat
0. Back
=====================================
Enter your choice [1-4, Enter=0]: 1


Select Edit Format for Architect Mode:
=====================================
1. editor-whole
2. editor-diff
3. editor-diff-fenced
0. Back
=====================================
Enter your choice [1-3, Enter=0]: 3


Launching Aider: Architect Mode
Main Model:      ANTHROPIC/claude-3-7-sonnet-20250219 (Editor: DEEPSEEK/deepseek/deepseek-coder)
Edit Format:     editor-diff-fenced
-------------------------------------
Command to Run:
aider --vim --no-auto-commit --read README-prompts.md --read README-ask.md --model claude-3-7-sonnet-20250219 --architect --editor-model deepseek/deepseek-coder --edit-format editor-diff-fenced
-------------------------------------
1. Launch Aider with this command
2. Back to Main Menu (Abort Launch)
-------------------------------------
Enter choice [1-3, 0=Back, Enter=1]:
```

