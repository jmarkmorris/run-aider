# Pro Tips for Using Aider

**Setup & Environment:**

*   **Preview History:** Keep `aider-chat-history.md` open in preview mode for easy reference, reducing scrolling strain in the terminal.
*   **Dark Mode:** Use Aider's dark mode (`--dark-mode` or config) for better visibility of code snippets if your terminal has a light background.
*   **Choose the Right Model:** Experiment with different LLMs based on task complexity, context needs, and budget.

**Planning & Strategy:**

*   **Use LLM for Planning:** Generate and maintain a `plan.md` with the LLM, including tasks, goals, and even value/risk assessments.
*   **Break Down Complex Tasks:** Tackle large features or refactors in smaller, manageable steps. Guide Aider incrementally.

**Interaction & Prompting:**

*   **Be Specific & Provide Context:** Clearly state *what*, *where* (files/functions), and *why*. Include constraints, errors, and examples.
*   **Manage Context Actively:** Use `/add`, `/drop`, and `/ls` to keep the context focused on relevant files, improving performance and reducing cost.
*   **Iterate and Refine:** Expect iterative development. Point out errors specifically and ask for corrections.
*   **Reuse Prompts:** Copy/paste effective prompts from your `aider-chat-history.md`.
*   **Use `/ask`:** Leverage `/ask` for guidance on approach, design decisions, or understanding code.

**Verification & Quality:**

*   **Leverage Tests Heavily:** Ask Aider to write/update tests. Run tests frequently using `/test <your_test_command>` to verify changes immediately.
*   **Review Generated Code Critically:** Treat AI code like code from a junior dev. Understand it, check for issues, don't trust blindly.
*   **Run Linters/Formatters:** Use `/run <lint/format_command>` to maintain code quality and consistency.
*   **Remove Stale Comments:** Periodically ask the LLM to clean up outdated history comments or comments irrelevant to the current code state.

**Workflow & Recovery:**

*   **Commit Working Changes Often:** Once tests pass for a logical chunk of work, commit it. This prevents losing good work if subsequent steps go wrong.
*   **Recover from Confusion:** If the session goes off track, use `/diff` to review, `/undo` to revert the last change, or revert manually via Git. Then `/clear` the conversation history or restart Aider to get a fresh state. Confusion tends to persist if not cleared.
*   **Consolidate Utilities:** Periodically ask Aider to identify and refactor redundant code into shared utility modules (e.g., `utils.py`).
*   **Utilize Aider Commands:** Learn useful commands like `/diff`, `/undo`, `/run`, `/test`, and `/git` for efficient workflow within Aider.

