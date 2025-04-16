# Plan: Refactor Edit Format Selection in run-aider.sh

**Goal:** Elevate the Aider edit format selection to a dedicated, interactive menu step within the `run-aider.sh` script, allowing users to explicitly choose the format before the final launch confirmation.

**Rationale:**
- Improve user awareness and control over the edit format being used.
- Make the selection process clearer than the previous pre-launch toggle.
- Provide a foundation for potentially supporting more Aider edit formats in the future.
- Address user feedback regarding the importance of specific formats (e.g., `editor-whole`).
- Ensure user choice overrides Aider's internal automatic format selection.

**Steps:**

1.  **DONE - Identify Supported Edit Formats:**
    *   Reviewed Aider documentation for `--edit-format` flag.
    *   Formats offered:
        *   Code Mode: `diff`, `whole`, `search_replace`.
        *   Architect Mode: `editor-diff`, `editor-whole`, `editor-diff-fenced`.

2.  **DONE - Create New Menu Function (`select_edit_format`):**
    *   Defined `select_edit_format` function.
    *   Takes mode (`code` or `architect`) as input.
    *   Displays relevant formats with a "Back" option.
    *   Sets global `SELECT_EDIT_FORMAT_RESULT`.

3.  **DONE - Integrate `select_edit_format` into Mode Flows:**
    *   Called `select_edit_format` after model selection in `run_code_mode` and `run_architect_mode`.
    *   Handled "Back" and "invalid" results appropriately.
    *   Stored result in `selected_format` variable.

4.  **DONE - Refactor `launch_aider` Function:**
    *   Added `selected_format` parameter.
    *   Removed old default/initial format logic.
    *   Modified pre-launch confirmation loop:
        *   Displays chosen `selected_format`.
        *   Removed old "Switch Format" option.
        *   Adjusted menu options: `1`=Launch, `2`=Back to Format Select, `0`=Back to Main Menu.
        *   Updated prompt text.
    *   Ensured final `cmd_array` includes `--edit-format "$selected_format"`.

5.  **DONE - Aesthetic Refinements:**
    *   Standardized menu title format (centered, uppercase).
    *   Used static, pre-formatted title strings for simplicity.
    *   Improved layout and clarity of the launch confirmation screen (model display, command title).
    *   Refined "Back" behavior from launch confirmation menu.

6.  **TODO - Update Documentation (`README-aider.md`, `README.md`):**
    *   In `README-aider.md`:
        *   Update the "Edit Formats" section to describe the new dedicated selection step.
        *   Remove the explanation of the old pre-launch switching mechanism.
        *   List and describe the edit formats presented in the new menu for each mode, including `editor-diff-fenced`.
        *   Clarify that the script's selection overrides Aider's automatic format choice.
    *   In `README.md`:
        *   Update the "Example Interactions" section to show the new edit format selection menu step for both modes, including the new Architect format option and updated launch screen.
        *   Modify the final confirmation screen examples to remove the "Switch Format" option and show the selected format.
        *   Ensure the feature list accurately reflects the new behavior.

7.  **TODO - Final Testing:**
    *   Test Code mode: Select various formats (`whole`, `diff`, `search_replace`), ensure the correct flag is passed, test "Back" options from format and launch menus.
    *   Test Architect mode: Select various formats (`editor-diff`, `editor-whole`, `editor-diff-fenced`), ensure the correct flag is passed, test "Back" options.
    *   Verify the final confirmation screen accurately reflects the chosen format and has the updated options and layout.
    *   Ensure API key handling and other functionalities remain unaffected.
