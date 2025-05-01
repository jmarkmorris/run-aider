# Aider Documentation

## Installing aider

* python -m pip install aider-install
* aider-install

Note: there is also an aider package known to pip, but that is something else.

You can run Aider with the --verbose flag to enable verbose output. This will provide detailed logs and information about the operations being performed. If you are using a configuration file for Aider, you can add the --verbose option to the configuration settings.

## Running Aider with run-aider.py

The `run-aider.py` script provides an interactive command-line interface to configure and launch `aider`. It simplifies the process by:

- Allowing you to choose the operating mode:
    - **Code Mode:** Standard `aider` operation for direct code generation and modification.
    - **Architect Mode:** Uses separate LLMs for high-level planning (Architect) and detailed code implementation (Editor).
- Guiding you through selecting the LLM vendor (OpenAI, Anthropic, Google, Deepseek) and specific model for each role (Code, Architect, Editor).
- Managing API keys securely (loading from environment or files).
- **Providing a dedicated menu step to select the Aider edit format** (`default` – Aider decides automatically, `whole`, `diff`, `diff-fenced`, `udiff`, `udiff-simple` for Code mode; `default`, `editor-whole`, `editor-diff`, `editor-diff-fenced` for Architect mode). This allows you to explicitly choose the format **or** defer to Aider’s internal heuristics.
- Automatically adding `README-prompts.md` and `README-ask.md` as read-only files to the Aider chat context (via `.aider.conf.yml`).

Use `python run-aider.py` in your terminal to start the configuration process. To see detailed usage instructions, including API key setup and menu flow, run `python run-aider.py -h` or `python run-aider.py --help`.

---

## Documentation and References

LLMs know about standard tools and libraries but may have outdated information about API versions and function arguments. You can provide up-to-date documentation by:

- Pasting doc snippets directly into the chat
- Including a URL to docs in your chat message for automatic scraping (example: `Add a submit button like this https://ui.shadcn.com/docs/components/button`)
- Using the `/read` command to import doc files from your filesystem

## Creating New Files

To create a new file:
1. Add it to the repository first with `/add <file>`
2. This ensures aider knows the file exists and will write to it
3. Without this step, aider might modify existing files even when you request a new one

## Sending Multi-line Messages

Multiple options for sending long, multi-line messages:

- Enter `{` alone on the first line to start a multiline message and `}` alone on the last line to end it
- Use `{tag` to start and `tag}` to end (useful when your message contains closing braces)
- Use `/paste` to insert text from clipboard directly into the chat

## Vi/Vim Keybindings

Run aider with the `--vim` switch (automatically included by `run-aider.py`) to enable vi/vim keybindings:

| Key | Function |
|-----|----------|
| Up Arrow | Move up one line in current message |
| Down Arrow | Move down one line in current message |
| Ctrl-Up | Scroll back through previous messages |
| Ctrl-Down | Scroll forward through previous messages |
| Esc | Switch to command mode |
| i | Switch to insert mode |
| a | Move cursor right and switch to insert mode |
| A | Move to end of line and switch to insert mode |
| I | Move to beginning of line and switch to insert mode |
| h | Move cursor left |
| j | Move cursor down |
| k | Move cursor up |
| l | Move cursor right |
| w | Move forward one word |
| b | Move backward one word |
| 0 | Move to beginning of line |
| $ | Move to end of line |
| x | Delete character under cursor |
| dd | Delete current line |
| u | Undo last change |
| Ctrl-R | Redo last undone change |

## Tips

- /paste : pastes image from clipboard
- /web : goes to url and scrapes it.
- /clear : erases context other than the files.

---

## Edit Formats (`--edit-format`) and `run-aider.py`

Aider's `--edit-format` option controls how code changes are presented to the LLM (or between LLMs in Architect mode). The `run-aider.py` script helps select this format explicitly before launching. Understanding the differences can help troubleshoot failed edits.

**`run-aider.py` Behavior:**

1.  **Dedicated Selection Step:** After selecting the model(s), `run-aider.py` presents a menu to choose the edit format based on the `aider_config.json` file **plus a dynamic _Default (Aider chooses)_ option**:
    *   **Code Mode Options (Example Config):** `default` (automatic), `whole`, `diff`, `diff-fenced`, `udiff`, `udiff-simple`
    *   **Architect Mode Options (Example Config):** `default` (automatic), `editor-whole`, `editor-diff`, `editor-diff-fenced`
2.  **Explicit Control or Delegation:**  
    * Selecting any explicit format passes `--edit-format <format>` to Aider.  
    * Selecting **Default** omits the `--edit-format` flag entirely, letting Aider apply its built-in heuristics to pick the best format for the chosen model(s).
3.  **Pre-Launch Confirmation:** The final confirmation screen displays the chosen format (or _Default_) and the full command before execution.

**Description of Edit Formats:**

*Formats available in Code Mode (based on example config):*

1.  **`diff`**
    *   **What it does:** Presents changes in standard `diff` format (`+`/`-` lines).
    *   **How it works:** Sends only calculated differences to the LLM. Aider then attempts to apply this diff/patch to the local file.
    *   **Pros:** Concise, focuses LLM on changes, lower token usage.
    *   **Cons:** Edits can sometimes fail if the LLM generates an invalid diff, if the context lines in the diff don't perfectly match the current file, or if the changes are complex/overlapping.
    *   **`run-aider.py` Usage:** Selectable in the Code Mode edit format menu if present in `aider_config.json`.

2.  **`whole`**
    *   **What it does:** Presents the *entire* proposed file content to the LLM.
    *   **How it works:** Sends the complete intended file text. Aider replaces the existing file content with the new content received from the LLM. This bypasses the complexities of patch application.
    *   **Pros:** Can be more reliable if `diff` edits fail frequently, as it avoids diff generation/application errors.
    *   **Cons:** Uses significantly more tokens (higher cost, potentially slower), may hit context limits on very large files, and might encourage the LLM to make broader, unintended changes if not prompted carefully.
    *   **`run-aider.py` Usage:** Selectable in the Code Mode edit format menu if present in `aider_config.json`.

3.  **`diff-fenced`**
    *   **What it does:** Similar to `diff`, but presents the diff to the LLM enclosed within markdown code fences (```diff ... ```).
    *   **How it works:** Sends the calculated differences within markdown fences. Aider then attempts to apply this diff/patch.
    *   **Pros:** May improve reliability for some LLMs by clearly delineating the diff content, potentially leading to better diff generation. Concise, lower token usage than `whole`.
    *   **Cons:** Still relies on diff application, so potential for patch failures remains if the diff is invalid or context mismatches occur.
    *   **`run-aider.py` Usage:** Selectable in the Code Mode edit format menu if present in `aider_config.json`.

4.  **`udiff`**
    *   **What it does:** Presents changes in the unified diff format.
    *   **How it works:** Sends the calculated differences in unified diff format. Aider then attempts to apply this diff/patch.
    *   **Pros:** Standard diff format, concise, lower token usage than `whole`.
    *   **Cons:** Similar risks of patch application failures as the standard `diff` format.
    *   **`run-aider.py` Usage:** Selectable in the Code Mode edit format menu if present in `aider_config.json`.

5.  **`udiff-simple`**
    *   **What it does:** Presents changes in a simplified unified diff format.
    *   **How it works:** Sends the calculated differences in a simplified unified diff format. Aider then attempts to apply this diff/patch.
    *   **Pros:** Potentially easier for some LLMs to parse than full `udiff`, concise, lower token usage than `whole`.
    *   **Cons:** Still relies on diff application, so potential for patch failures remains.
    *   **`run-aider.py` Usage:** Selectable in the Code Mode edit format menu if present in `aider_config.json`.

*Formats available in Architect Mode (control main -> editor interaction, based on example config):*

6.  **`editor-diff`**
    *   **What it does:** Sends the diff from the *main* LLM's changes to the *editor* LLM.
    *   **How it works:** Editor LLM receives only the diff to review/refine. Aider then attempts to apply the (potentially refined) diff.
    *   **Pros:** Focuses editor on refining specific changes, lower token usage than `editor-whole`.
    *   **Cons:** Subject to the same diff application risks as the standard `diff` format if the main or editor LLM produces a problematic diff.
    *   **`run-aider.py` Usage:** Selectable in the Architect Mode edit format menu if present in `aider_config.json`.

7.  **`editor-whole`**
    *   **What it does:** Sends the *entire file content* proposed by the *main* LLM to the *editor* LLM.
    *   **How it works:** Editor LLM receives the full proposed file content for review/refinement. Aider then replaces the local file with the final version from the editor LLM. This bypasses diff application issues between the main and editor steps.
    *   **Pros:** Gives editor full context; can be more reliable if `editor-diff` or `editor-diff-fenced` fails.
    *   **Cons:** Uses significantly more tokens than diff-based formats, potentially increasing cost and latency.
    *   **`run-aider.py` Usage:** Selectable in the Architect Mode edit format menu if present in `aider_config.json`.

8.  **`editor-diff-fenced`**
    *   **What it does:** Similar to `editor-diff`, but presents the diff to the editor LLM enclosed within markdown code fences (```diff ... ```).
    *   **How it works:** Editor LLM receives the fenced diff. Aider applies the resulting diff.
    *   **Pros:** May improve reliability for some LLMs by clearly delineating the diff content. Token usage similar to `editor-diff`.
    *   **Cons:** Still relies on diff application, so potential for patch failures remains if the diff is invalid or context mismatches occur.
    *   **`run-aider.py` Usage:** Selectable in the Architect Mode edit format menu if present in `aider_config.json`.

There are other edit formats available in Aider (like `line`, `search_replace`). The choices offered by `run-aider.py` depend entirely on the contents of your `aider_config.json` file.

**Troubleshooting Edit Failures:**

If you experience frequent failed edits, especially with complex changes:
*   In **Code Mode**, switching from a diff format (`diff`, `diff-fenced`, `udiff`, `udiff-simple`) to `whole` might improve reliability (at the cost of tokens).
*   In **Architect Mode**, switching from `editor-diff` or `editor-diff-fenced` to `editor-whole` might improve reliability (at the cost of tokens).

**Summary:**

*   `run-aider.py` provides a dedicated menu for selecting Aider's edit format based on `aider_config.json`.
*   Your choice in the script **overrides** Aider's internal defaults/automatic selection.
*   **Code Mode Options (Example Config):** `whole`, `diff`, `diff-fenced`, `udiff`, `udiff-simple`.
*   **Architect Mode Options (Example Config):** `editor-whole`, `editor-diff`, `editor-diff-fenced`.
*   `whole`/`editor-whole` formats are generally more robust but use more tokens.
*   Diff-based formats (`diff`, `diff-fenced`, `udiff`, `udiff-simple`, `editor-diff`, `editor-diff-fenced`) are more token-efficient but rely on potentially fragile diff/patch application.

---

## Changing Aider Settings

The recommended way to configure Aider is using a `.aider.conf.yml` file.

*   **.aider.conf.yml File:** Create a file named `.aider.conf.yml` in your home directory or at the root of your git repository. You can then add settings to this file in YAML format. For example:

    ```yaml
    dark-mode: true
    ```
*   **Environment Variables:** You can also set environment variables to configure aider. The environment variable name is usually `AIDER_` followed by the option name in uppercase. For example, to enable dark mode, you would set `AIDER_DARK_MODE=true`. You can set these variables in your shell or in a `.env` file.

*   **Command Line Options:** These are still supported, but `.aider.conf.yml` is preferred for persistent configuration.

See also:

*   https://aider.chat/docs/config.html
*   https://aider.chat/docs/config/options.html
*   https://aider.chat/docs/faq.html
