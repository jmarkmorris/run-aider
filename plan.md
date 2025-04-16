# Plan: Refactor Edit Format Selection in run-aider.sh

**Goal:** Elevate the Aider edit format selection to a dedicated, interactive menu step within the `run-aider.sh` script, allowing users to explicitly choose the format before the final launch confirmation.

**Rationale:**
- Improve user awareness and control over the edit format being used.
- Make the selection process clearer than the previous pre-launch toggle.
- Provide a foundation for potentially supporting more Aider edit formats in the future.
- Address user feedback regarding the importance of specific formats (e.g., `editor-whole`).
- Ensure user choice overrides Aider's internal automatic format selection.

**Steps:**

1.  **Identify Supported Edit Formats:**
    *   Review Aider documentation (or use `aider --help`) to confirm the full list of valid arguments for the `--edit-format` flag.
    *   Common formats include: `diff`, `whole`, `search_replace`, `line`.
    *   Architect mode specific formats (controlling main -> editor interaction): `editor-diff`, `editor-whole`, `editor-diff-fenced`.
    *   Determine which formats are relevant and practical to offer for each mode (Code vs. Architect) in the script's menu. *Decision: Offer `diff`, `whole`, `search_replace` for Code mode, and `editor-diff`, `editor-whole`, `editor-diff-fenced` for Architect mode.*

2.  **Create New Menu Function (`select_edit_format`):**
    *   Define a new bash function, `select_edit_format`, similar in structure to `select_entity`.
    *   **Input:** The current mode (`code` or `architect`).
    *   **Logic:**
        *   Based on the input mode, display a numbered list of the relevant edit formats identified in Step 1.
        *   Include a "Back" option (0).
        *   Prompt the user for their choice.
        *   Validate the input.
    *   **Output:** Set a global variable (e.g., `SELECT_EDIT_FORMAT_RESULT`) to the chosen format string (e.g., "whole", "editor-diff-fenced") or an empty string for "Back", or "invalid".

3.  **Integrate `select_edit_format` into Mode Flows:**
    *   In `run_code_mode`:
        *   After successfully selecting the `main_model`, call `select_edit_format "code"`.
        *   Check the result: If "Back", clear previous selections (model) and loop back appropriately. If "invalid", re-prompt.
        *   Store the valid selected format in a local variable (e.g., `selected_format`).
        *   Pass `selected_format` to the `launch_aider` function.
    *   In `run_architect_mode`:
        *   After successfully selecting the `editor_model` (or determining it's "default"), call `select_edit_format "architect"`.
        *   Check the result: If "Back", return to main menu. If "invalid", re-prompt.
        *   Store the valid selected format in a local variable (e.g., `selected_format`).
        *   Pass `selected_format` to the `launch_aider` function.

4.  **Refactor `launch_aider` Function:**
    *   Add a new parameter to accept the `selected_format` chosen by the user.
    *   **Remove** any logic related to initial/default formats. The format is now explicitly passed in.
    *   **Modify** the pre-launch confirmation loop:
        *   The menu should now *display* the chosen `selected_format`.
        *   **Remove** the previous option "2. Switch to Format: ...". This is no longer needed.
        *   Adjust the menu numbering (e.g., 1. Launch, 2. Back to Main Menu).
        *   Update the prompt accordingly.
    *   Ensure the final `cmd_array` includes `--edit-format "$selected_format"` using the passed-in value, thus overriding Aider's automatic selection.

5.  **Update Documentation (`README-aider.md`, `README.md`):**
    *   In `README-aider.md`:
        *   Update the "Edit Formats" section to describe the new dedicated selection step.
        *   Remove the explanation of the old pre-launch switching mechanism.
        *   List and describe the edit formats presented in the new menu for each mode, including `editor-diff-fenced`.
        *   Clarify that the script's selection overrides Aider's automatic format choice.
    *   In `README.md`:
        *   Update the "Example Interactions" section to show the new edit format selection menu step for both modes, including the new Architect format option.
        *   Modify the final confirmation screen examples to remove the "Switch Format" option and show the selected format.
        *   Ensure the feature list accurately reflects the new behavior.

6.  **Testing:**
    *   Test Code mode: Select various formats (`whole`, `diff`, `search_replace`), ensure the correct flag is passed, test "Back".
    *   Test Architect mode: Select various formats (`editor-diff`, `editor-whole`, `editor-diff-fenced`), ensure the correct flag is passed, test "Back".
    *   Verify the final confirmation screen accurately reflects the chosen format and has the updated options.
    *   Ensure API key handling and other functionalities remain unaffected.
