#!/usr/bin/env python3

import sys
import os
import json
import subprocess
import argparse
import textwrap
import re

# --- Configuration File Path ---
# Define the config file path relative to the script's actual directory
# Get the absolute path of the script, resolving any symlinks
SCRIPT_REAL_PATH = os.path.realpath(__file__)
# Get the directory containing the script
SCRIPT_DIR = os.path.dirname(SCRIPT_REAL_PATH)
CONFIG_FILE = os.path.join(SCRIPT_DIR, "aider_config.json")

# --- Model and Vendor Definitions ---
# These lists will be populated from JSON
VENDORS = []
VENDOR_MODELS = {}  # Dictionary to hold models per vendor
CODE_EDIT_FORMATS = []
ARCHITECT_EDIT_FORMATS = []

# Parallel list holding the API key environment variable name for each vendor
# Populated dynamically based on VENDORS list
VENDOR_API_KEY_VARS = []

# Parallel list to track the source of the API key ("env", "file", or "unset")
VENDOR_KEY_SOURCE = []

# --- Centered Menu Titles (Static) ---
# Calculated for an 80-character width
TITLE_MODE_SELECT = "                         SELECT AIDER OPERATING MODE                          "
TITLE_CODE_VENDOR = "                           SELECT CODE MODE VENDOR                            "
TITLE_CODE_MODEL = "                            SELECT CODE MODE MODEL                             "
TITLE_ARCH_VENDOR = "                         SELECT ARCHITECT MODE VENDOR                         "
TITLE_ARCH_MODEL = "                          SELECT ARCHITECT MODE MODEL                          "
TITLE_EDITOR_VENDOR = "                            SELECT EDITOR VENDOR                             "
TITLE_EDITOR_MODEL = "                             SELECT EDITOR MODEL                              "
TITLE_CODE_FORMAT = "                         SELECT CODE MODE EDIT FORMAT                         "
TITLE_ARCH_FORMAT = "                       SELECT ARCHITECT EDIT FORMAT                         "
TITLE_LAUNCH_CODE = "                         LAUNCHING AIDER: CODE MODE                          "
TITLE_LAUNCH_ARCH = "                       LAUNCHING AIDER: ARCHITECT MODE                       "

# --- Separator Lines ---
SEPARATOR_MAIN = "================================================================================"  # 80 chars
SEPARATOR_SUB = "--------------------------------------------------------------------------------"  # 80 chars

# --- Global variable to store selection result ---
SELECT_RESULT = None

# --- JSON Configuration Loading ---
def load_json_config(config_file):
    """
    Loads configuration from JSON file and validates its structure.
    """
    if not os.path.exists(config_file):
        print(f"Error: Configuration file '{config_file}' not found.", file=sys.stderr)
        print("Please create a configuration file with vendors, models, and edit formats.", file=sys.stderr)
        print("""Example format:
{
  "vendors": ["OPENAI", "ANTHROPIC"],
  "models": {
    "OPENAI": ["gpt-4o", "gpt-4-turbo"],
    "ANTHROPIC": ["claude-3-5-haiku-20241022"]
  },
  "edit_formats": {
    "code": ["whole", "diff"],
    "architect": ["editor-whole", "editor-diff"]
  }
}""", file=sys.stderr)
        sys.exit(1)

    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Configuration file '{config_file}' contains invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    validate_json_structure(config, config_file)

    print(f"Loading configuration from {config_file}...")
    return config

def validate_json_structure(config, config_file):
    """
    Validates that the JSON file has the required structure.
    """
    missing_fields = []

    if 'vendors' not in config:
        missing_fields.append("vendors")
    elif not isinstance(config['vendors'], list):
        print(f"Error: 'vendors' must be an array in {config_file}", file=sys.stderr)
        sys.exit(1)

    if 'models' not in config:
        missing_fields.append("models")
    elif not isinstance(config['models'], dict):
        print(f"Error: 'models' must be an object in {config_file}", file=sys.stderr)
        sys.exit(1)

    if 'edit_formats' not in config:
        missing_fields.append("edit_formats")
    elif not isinstance(config['edit_formats'], dict):
        print(f"Error: 'edit_formats' must be an object in {config_file}", file=sys.stderr)
        sys.exit(1)
    else:
        if 'code' not in config['edit_formats']:
            missing_fields.append("edit_formats.code")
        elif not isinstance(config['edit_formats']['code'], list):
            print(f"Error: 'edit_formats.code' must be an array in {config_file}", file=sys.stderr)
            sys.exit(1)
        elif not config['edit_formats']['code']:
             print(f"Error: 'edit_formats.code' array is empty in {config_file}", file=sys.stderr)
             print("Please add at least one edit format for code mode (e.g., 'whole', 'diff').", file=sys.stderr)
             sys.exit(1)


        if 'architect' not in config['edit_formats']:
            missing_fields.append("edit_formats.architect")
        elif not isinstance(config['edit_formats']['architect'], list):
            print(f"Error: 'edit_formats.architect' must be an array in {config_file}", file=sys.stderr)
            sys.exit(1)
        elif not config['edit_formats']['architect']:
             print(f"Error: 'edit_formats.architect' array is empty in {config_file}", file=sys.stderr)
             print("Please add at least one edit format for architect mode (e.g., 'editor-whole', 'editor-diff').", file=sys.stderr)
             sys.exit(1)


    if missing_fields:
        print(f"Error: The following required fields are missing in {config_file}:", file=sys.stderr)
        for field in missing_fields:
            print(f"  - {field}", file=sys.stderr)
        print("Please ensure the configuration file contains all required fields.", file=sys.stderr)
        sys.exit(1)

    # Check that all vendors listed have model entries
    missing_vendor_models = [v for v in config['vendors'] if v not in config['models']]
    if missing_vendor_models:
        print(f"Error: The following vendors are listed in 'vendors' but missing from the 'models' section in {config_file}:", file=sys.stderr)
        for v in missing_vendor_models:
            print(f"  - {v}", file=sys.stderr)
        print("Please add model entries for all vendors listed in the 'vendors' array.", file=sys.stderr)
        sys.exit(1)

    # Check that no vendor model lists are empty
    empty_model_lists = [v for v in config['vendors'] if not config['models'].get(v)]
    if empty_model_lists:
         print(f"Error: The following vendors have empty model arrays in {config_file}:", file=sys.stderr)
         for v in empty_model_lists:
             print(f"  - {v}" , file=sys.stderr)
         print("Please add at least one model for each vendor.", file=sys.stderr)
         sys.exit(1)


def initialize_configuration():
    """
    Initializes global configuration variables from the JSON file.
    """
    global VENDORS, VENDOR_MODELS, CODE_EDIT_FORMATS, ARCHITECT_EDIT_FORMATS, VENDOR_API_KEY_VARS, VENDOR_KEY_SOURCE

    config = load_json_config(CONFIG_FILE)

    VENDORS = config.get('vendors', [])
    VENDOR_MODELS = config.get('models', {})
    CODE_EDIT_FORMATS = config.get('edit_formats', {}).get('code', [])
    ARCHITECT_EDIT_FORMATS = config.get('edit_formats', {}).get('architect', [])

    # Populate VENDOR_API_KEY_VARS based on VENDORS
    VENDOR_API_KEY_VARS = [f"{vendor}_API_KEY" for vendor in VENDORS]
    # Special case for Google
    if "GOOGLE" in VENDORS:
         google_index = VENDORS.index("GOOGLE")
         # Use GEMINI_API_KEY primarily, fallback to GOOGLE_API_KEY
         VENDOR_API_KEY_VARS[google_index] = ["GEMINI_API_KEY", "GOOGLE_API_KEY"]


    # Initialize VENDOR_KEY_SOURCE
    VENDOR_KEY_SOURCE = ["unset"] * len(VENDORS)

    print(f"Configuration loaded successfully from {CONFIG_FILE}")


# --- API Key Loading Helper Functions ---

def _load_keys_from_env():
    """
    Attempts to load API keys from environment variables.
    Updates VENDOR_KEY_SOURCE.
    """
    print("Checking environment variables for API keys...")
    all_found = True
    for i, vendor in enumerate(VENDORS):
        api_key_vars = VENDOR_API_KEY_VARS[i]
        if isinstance(api_key_vars, list): # Handle special cases like Google
             found_key = False
             for var in api_key_vars:
                 if os.environ.get(var):
                     # For Google, we prefer GEMINI_API_KEY, but if GOOGLE_API_KEY is set, use it
                     # and ensure GEMINI_API_KEY is also set for consistency if needed later
                     if var == "GOOGLE_API_KEY" and not os.environ.get("GEMINI_API_KEY"):
                         os.environ["GEMINI_API_KEY"] = os.environ["GOOGLE_API_KEY"]
                         print(f"Using GOOGLE_API_KEY from environment for {vendor}")
                     elif var == "GEMINI_API_KEY":
                          print(f"Using GEMINI_API_KEY from environment for {vendor}")

                     VENDOR_KEY_SOURCE[i] = "env"
                     found_key = True
                     break # Found a key for this vendor
             if not found_key:
                 VENDOR_KEY_SOURCE[i] = "unset"
                 all_found = False

        else: # Standard case
            if os.environ.get(api_key_vars):
                VENDOR_KEY_SOURCE[i] = "env"
                # print(f"Debug: Found {vendor} key ({api_key_vars}) in env.") # Optional debug
            else:
                VENDOR_KEY_SOURCE[i] = "unset"
                all_found = False
                # print(f"Debug: Did not find {vendor} key ({api_key_vars}) in env.") # Optional debug

    if all_found:
        print("All required API keys found in environment variables.")
        return True
    else:
        print("One or more API keys not found in environment variables. Will check files.")
        return False

def _find_keys_file():
    """
    Finds the API keys file to use based on environment variable or default path.
    Returns the path or None if not found.
    """
    primary_file = os.environ.get("PRIMARY_KEYS_FILE")
    secondary_file = os.path.expanduser("~/.llm_api_keys")
    file_to_use = None

    if primary_file and os.path.isfile(primary_file):
        file_to_use = primary_file
        # print(f"Debug: Using primary keys file: {file_to_use}") # Optional debug
    elif os.path.isfile(secondary_file):
        file_to_use = secondary_file
        # print(f"Debug: Using secondary keys file: {file_to_use}") # Optional debug
    # else:
        # print("Debug: No API keys file found.") # Optional debug

    return file_to_use

def _load_keys_from_file(keys_file_path):
    """
    Loads API keys from the specified file by parsing VAR="value" lines.
    Updates VENDOR_KEY_SOURCE for keys loaded from the file.
    """
    if not os.path.isfile(keys_file_path):
        print(f"Error: Keys file not found at path: {keys_file_path}", file=sys.stderr)
        return

    print(f"Loading API keys from file: {keys_file_path}")
    try:
        with open(keys_file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue

                # Parse lines like VAR="value" or VAR='value' or VAR=value
                match = re.match(r'^(\w+)=["\']?(.*?)["\']?$', line)
                if match:
                    var_name = match.group(1)
                    var_value = match.group(2)

                    # Check if this variable name corresponds to any of our expected API key vars
                    # Handle the Google case where multiple vars map to one vendor
                    is_api_key_var = False
                    for i, vendor_vars in enumerate(VENDOR_API_KEY_VARS):
                        if isinstance(vendor_vars, list):
                            if var_name in vendor_vars:
                                # If this key wasn't already set by env, mark it as file-sourced
                                if VENDOR_KEY_SOURCE[i] == "unset":
                                    VENDOR_KEY_SOURCE[i] = "file"
                                # Set the environment variable
                                os.environ[var_name] = var_value
                                # print(f"Debug: Loaded {var_name} from file.") # Optional debug
                                is_api_key_var = True
                                break # Found a match for this line
                        else: # Standard case
                            if var_name == vendor_vars:
                                # If this key wasn't already set by env, mark it as file-sourced
                                if VENDOR_KEY_SOURCE[i] == "unset":
                                    VENDOR_KEY_SOURCE[i] = "file"
                                # Set the environment variable
                                os.environ[var_name] = var_value
                                # print(f"Debug: Loaded {var_name} from file.") # Optional debug
                                is_api_key_var = True
                                break # Found a match for this line

                    # If it's an API key var, we've processed it. If not, ignore it.
                    # We don't need to handle non-API key vars from the file.

    except Exception as e:
        print(f"Warning: Could not parse API keys file {keys_file_path}: {e}", file=sys.stderr)


def load_api_keys():
    """
    Loads API keys, coordinating checks between environment and files.
    Priority: Environment -> PRIMARY_KEYS_FILE -> $HOME/.llm_api_keys
    Populates VENDOR_KEY_SOURCE.
    """
    print("Attempting to load API keys...")

    # 1. Try loading from environment variables
    _load_keys_from_env()

    # 2. Always check for a keys file, regardless of env status
    keys_file_path = _find_keys_file()

    # 3. If a keys file exists, attempt to load from it
    #    This will update the source for keys not found in env.
    if keys_file_path:
        _load_keys_from_file(keys_file_path)

    print("API key loading process complete.")


def check_api_key(vendor):
    """
    Checks if the API key for the specified vendor is available as an environment variable.
    It relies on load_api_keys having been called previously.
    Exits if the key is not set.
    """
    try:
        vendor_index = VENDORS.index(vendor)
        api_key_vars = VENDOR_API_KEY_VARS[vendor_index]
        key_source = VENDOR_KEY_SOURCE[vendor_index]

        api_key_set = False
        if isinstance(api_key_vars, list): # Handle special cases like Google
            for var in api_key_vars:
                if os.environ.get(var):
                    api_key_set = True
                    break
        else: # Standard case
            if os.environ.get(api_key_vars):
                api_key_set = True

        if not api_key_set or key_source == "unset":
            secondary_keys_file = os.path.expanduser("~/.llm_api_keys")
            print(f"\nError: API key for {vendor} is not set or could not be loaded.", file=sys.stderr)
            print(f"Source status: {key_source}", file=sys.stderr)
            # --- Special error message for GOOGLE ---
            if vendor == "GOOGLE":
                print("Please ensure it is defined either as an environment variable (GEMINI_API_KEY or GOOGLE_API_KEY)", file=sys.stderr)
                print("or within your API keys file (GEMINI_API_KEY or GOOGLE_API_KEY).", file=sys.stderr)
                print("Checked locations:", file=sys.stderr)
                print("  - Environment Variable: GEMINI_API_KEY", file=sys.stderr)
                print("  - Environment Variable: GOOGLE_API_KEY", file=sys.stderr)
            else:
            # --- Standard error message for other vendors ---
                print(f"Please ensure it is defined either as an environment variable ({api_key_vars})", file=sys.stderr)
                print("or within your API keys file.", file=sys.stderr)
                print("Checked locations:", file=sys.stderr)
                print(f"  - Environment Variable: {api_key_vars}", file=sys.stderr)

            # --- Common part of error message ---
            if os.environ.get("PRIMARY_KEYS_FILE"):
                print(f"  - Primary Keys File (env): $PRIMARY_KEYS_FILE -> {os.environ.get('PRIMARY_KEYS_FILE')}", file=sys.stderr)
            else:
                print("  - Primary Keys File (env): $PRIMARY_KEYS_FILE (not set)", file=sys.stderr)
            print(f"  - Secondary Keys File (default): {secondary_keys_file}", file=sys.stderr)
            sys.exit(1)
        # print(f"Debug: API key for {vendor} confirmed (Source: {key_source}).") # Optional debug

    except ValueError:
        print(f"Error: Unknown vendor '{vendor}' passed to check_api_key.", file=sys.stderr)
        sys.exit(1)


def select_entity(entity_type, role_label, vendor=None):
    """
    Generalized function to select an entity (vendor or model) via an interactive menu.
    Sets the global SELECT_RESULT.
    """
    global SELECT_RESULT
    entities = []
    menu_title = ""

    if entity_type == "vendor":
        # Filter vendors to only include those with loaded keys
        available_vendors = [v for i, v in enumerate(VENDORS) if VENDOR_KEY_SOURCE[i] != "unset"]
        entities = available_vendors
        if role_label == "Code":
            menu_title = TITLE_CODE_VENDOR
        elif role_label == "Architect":
            menu_title = TITLE_ARCH_VENDOR
        elif role_label == "Editor":
            menu_title = TITLE_EDITOR_VENDOR
    elif entity_type == "model":
        if vendor is None:
            print("Error: Vendor must be provided when selecting a model.", file=sys.stderr)
            SELECT_RESULT = "invalid"
            return
        entities = VENDOR_MODELS.get(vendor, [])
        if role_label == "Code":
            menu_title = TITLE_CODE_MODEL
        elif role_label == "Architect":
            menu_title = TITLE_ARCH_MODEL
        elif role_label == "Editor":
            menu_title = TITLE_EDITOR_MODEL
    else:
        print(f"Error: Invalid entity type: {entity_type}", file=sys.stderr)
        SELECT_RESULT = "invalid"
        return

    if not menu_title:
         menu_title = f"         SELECT {role_label.upper()} {entity_type.upper()}         " # Generic fallback


    num_entities = len(entities)

    # clear # Disabled for debugging
    print(f"\n{SEPARATOR_MAIN}")
    print(menu_title)
    print(SEPARATOR_MAIN)

    if num_entities == 0:
        if entity_type == "vendor":
             print("No vendors found with loaded API keys.")
             print("Please ensure you have set API keys in environment variables or a keys file.")
        else:
             print(f"No models available for the selected vendor: {vendor}")

        print(SEPARATOR_MAIN)
        print("0. Back")
        print(SEPARATOR_MAIN)
        choice = input("Enter your choice [Enter=0]: ").strip()
        if not choice or choice == "0":
            SELECT_RESULT = None  # Back selected
        else:
            print("Invalid choice.", file=sys.stderr)
            input("Press Enter...")
            SELECT_RESULT = "invalid"  # Indicate invalid input
        return

    for i, entity in enumerate(entities):
        print(f"{i + 1}. {entity}")

    prompt_range = f"1-{num_entities}"
    if entity_type == "vendor" and role_label == "Editor":
        print("9. Use same VENDOR and MODEL as Architect")
        prompt_range = f"1-{num_entities}, 9"

    print("0. Back")
    print(SEPARATOR_MAIN)
    choice = input(f"Enter your choice [{prompt_range}, Enter=0]: ").strip()

    SELECT_RESULT = None

    if not choice or choice == "0":
        SELECT_RESULT = None  # "Back" selected
    elif entity_type == "vendor" and role_label == "Editor" and choice == "9":
        SELECT_RESULT = "default"
    elif choice.isdigit():
        choice_index = int(choice) - 1
        if 0 <= choice_index < num_entities:
            SELECT_RESULT = entities[choice_index]
        else:
            print("Invalid choice.", file=sys.stderr)
            input("Press Enter...")
            SELECT_RESULT = "invalid"  # Indicate invalid input
    else:
        print("Invalid choice.", file=sys.stderr)
        input("Press Enter...")
        SELECT_RESULT = "invalid"  # Indicate invalid input


def select_edit_format(mode):
    """
    Selects the Aider edit format via an interactive menu.
    Sets the global SELECT_RESULT.
    """
    global SELECT_RESULT
    formats = []
    menu_title = ""

    if mode == "code":
        formats = CODE_EDIT_FORMATS
        menu_title = TITLE_CODE_FORMAT
    elif mode == "architect":
        formats = ARCHITECT_EDIT_FORMATS
        menu_title = TITLE_ARCH_FORMAT
    else:
        print(f"Error: Invalid mode passed to select_edit_format: {mode}", file=sys.stderr)
        SELECT_RESULT = "invalid"
        return

    display_options = ["Default (Aider chooses)"] + formats
    num_options = len(display_options)

    # clear # Disabled for debugging
    print(f"\n{SEPARATOR_MAIN}")
    print(menu_title)
    print(SEPARATOR_MAIN)

    for i, option in enumerate(display_options):
        print(f"{i + 1}. {option}")
    print("0. Back")
    print(SEPARATOR_MAIN)
    choice = input(f"Enter your choice [1-{num_options}, Enter=0]: ").strip()

    SELECT_RESULT = None

    if not choice or choice == "0":
        SELECT_RESULT = None  # "Back" selected
    elif choice.isdigit():
        choice_index = int(choice) - 1
        if 0 <= choice_index < num_options:
            if choice_index == 0:
                SELECT_RESULT = "default"
            else:
                SELECT_RESULT = formats[choice_index - 1]  # Offset by one due to default
        else:
            print("Invalid choice.", file=sys.stderr)
            input("Press Enter...")
            SELECT_RESULT = "invalid"  # Indicate invalid input
    else:
        print("Invalid choice.", file=sys.stderr)
        input("Press Enter...")
        SELECT_RESULT = "invalid"  # Indicate invalid input


def _get_vendor_index(vendor_name):
    """Gets the numerical index (0-based) of a vendor within the global VENDORS list."""
    try:
        return VENDORS.index(vendor_name)
    except ValueError:
        return -1

def _get_api_key_value(vendor):
    """Retrieves the API key value for a vendor from environment variables."""
    try:
        vendor_index = VENDORS.index(vendor)
        api_key_vars = VENDOR_API_KEY_VARS[vendor_index]

        if isinstance(api_key_vars, list): # Handle special cases like Google
            for var in api_key_vars:
                if os.environ.get(var):
                    return os.environ.get(var)
            return None # Should not happen if check_api_key passed
        else: # Standard case
            return os.environ.get(api_key_vars) # Should not be None if check_api_key passed

    except ValueError:
        print(f"Error: Unknown vendor '{vendor}' passed to _get_api_key_value.", file=sys.stderr)
        return None


def _build_main_model_args(main_vendor, main_model):
    """
    Builds the command-line arguments related to the main model selection.
    Includes --model flag and potentially the vendor-specific API key flag
    if the key was loaded from a file.
    """
    args_list = ["--model", main_model]
    vendor_index = _get_vendor_index(main_vendor)

    if vendor_index != -1:
        key_source = VENDOR_KEY_SOURCE[vendor_index]
        # Only add the API key flag if the key was loaded from a file
        if key_source == "file":
            # Determine the correct API key variable name to use for the flag
            # For Google, use GEMINI_API_KEY if set, otherwise GOOGLE_API_KEY
            api_key_var_name = None
            if isinstance(VENDOR_API_KEY_VARS[vendor_index], list): # Google case
                 if os.environ.get("GEMINI_API_KEY"):
                     api_key_var_name = "GEMINI_API_KEY"
                 elif os.environ.get("GOOGLE_API_KEY"):
                     api_key_var_name = "GOOGLE_API_KEY"
            else: # Standard case
                 api_key_var_name = VENDOR_API_KEY_VARS[vendor_index]

            if api_key_var_name and os.environ.get(api_key_var_name):
                api_key_value = os.environ.get(api_key_var_name)
                # Determine the flag name based on the vendor
                flag_name = None
                if main_vendor == "GOOGLE":
                    flag_name = "api-key" # Aider uses --api-key google=...
                    args_list.extend([f"--{flag_name}", f"google={api_key_value}"])
                elif main_vendor == "ANTHROPIC":
                    flag_name = "anthropic-api-key"
                    args_list.extend([f"--{flag_name}", api_key_value])
                elif main_vendor == "OPENAI":
                    flag_name = "openai-api-key"
                    args_list.extend([f"--{flag_name}", api_key_value])
                elif main_vendor == "DEEPSEEK":
                    flag_name = "deepseek-api-key"
                    args_list.extend([f"--{flag_name}", api_key_value])

                # print(f"Debug: Adding main API key flag for {main_vendor} (source: file)") # Optional debug
            # else:
                 # print(f"Warning: Key source is 'file' for {main_vendor}, but key value not found in env.") # Should not happen if load_api_keys worked
        # else:
            # print(f"Debug: Skipping main API key flag for {main_vendor} (source: {key_source})") # Optional debug
    else:
        print(f"Error: Unknown main vendor index in _build_main_model_args for: {main_vendor}", file=sys.stderr)
        # Don't exit, just return args built so far

    return args_list

def _build_architect_args(editor_vendor, editor_model, main_vendor):
    """
    Builds the command-line arguments specific to Architect mode.
    Includes --architect, potentially --editor-model,
    and the editor's API key flag if the editor vendor is different from the main vendor
    and the key was loaded from a file. The --edit-format flag is NOT added here.
    """
    args_list = ["--architect"]

    # Add --editor-model only if a specific one is chosen (not default)
    if editor_model != "default" and editor_model is not None:
        args_list.extend(["--editor-model", editor_model])

        # Check if editor vendor is different from main vendor AND not default
        if editor_vendor != "default" and editor_vendor != main_vendor:
            editor_vendor_index = _get_vendor_index(editor_vendor)
            if editor_vendor_index != -1:
                editor_key_source = VENDOR_KEY_SOURCE[editor_vendor_index]
                # Only add the API key flag if the key was loaded from a file
                if editor_key_source == "file":
                    editor_api_key_value = _get_api_key_value(editor_vendor)
                    if editor_api_key_value:
                        # Determine the flag name based on the editor vendor
                        editor_flag_name = None
                        if editor_vendor == "GOOGLE":
                            editor_flag_name = "api-key" # Aider uses --api-key google=...
                            args_list.extend([f"--{editor_flag_name}", f"google={editor_api_key_value}"])
                        elif editor_vendor == "ANTHROPIC":
                            editor_flag_name = "anthropic-api-key"
                            args_list.extend([f"--{editor_flag_name}", editor_api_key_value])
                        elif editor_vendor == "OPENAI":
                            editor_flag_name = "openai-api-key"
                            args_list.extend([f"--{editor_flag_name}", editor_api_key_value])
                        elif editor_vendor == "DEEPSEEK":
                            editor_flag_name = "deepseek-api-key"
                            args_list.extend([f"--{editor_flag_name}", editor_api_key_value])

                        # print(f"Debug: Adding editor API key flag for {editor_vendor} (source: file)") # Optional debug
                    # else:
                         # print(f"Warning: Editor key source for {editor_vendor} is 'file', but key value is missing in _build_architect_args.") # Should not happen
                # else:
                    # print(f"Debug: Skipping editor API key flag for {editor_vendor} (source: {editor_key_source})") # Optional debug
            else:
                print(f"Error: Unknown editor vendor index in _build_architect_args for: {editor_vendor}", file=sys.stderr)
                # Don't exit, just return args built so far

    return args_list

def _build_code_args():
    """
    Builds the command-line arguments specific to Code mode.
    Sets the chat mode. The --edit-format flag is NOT added here.
    """
    return ["--chat-mode", "code"]

def launch_aider(mode, main_vendor, main_model, editor_vendor, editor_model, selected_format):
    """
    Constructs and executes the final aider command based on the selected mode and models.
    Includes a pre-launch confirmation step.
    Returns:
      0: Aider launched and exited successfully.
      1: User chose "Back to Main Menu" OR Aider command not found OR Aider failed.
      2: User chose "Back to Edit Format Selection".
    """
    # Base aider command parts in an array
    cmd_list = ["aider"]

    # --- Add main model arguments ---
    cmd_list.extend(_build_main_model_args(main_vendor, main_model))

    # --- Add mode-specific arguments ---
    if mode == "architect":
        cmd_list.extend(_build_architect_args(editor_vendor, editor_model, main_vendor))
        launch_title = TITLE_LAUNCH_ARCH
    else: # Code mode
        cmd_list.extend(_build_code_args())
        launch_title = TITLE_LAUNCH_CODE

    # Check if aider command exists before entering the loop
    if not subprocess.run(["command", "-v", "aider"], capture_output=True).returncode == 0:
        print("\nError: Aider command not found.", file=sys.stderr)
        print("Please ensure 'aider-chat' is installed and in your PATH.", file=sys.stderr)
        input("Press Enter to return to the main menu...")
        return 1 # Indicate error/abort -> Back to Main Menu

    # Pre-launch confirmation loop
    while True:
        # --- Build the full command list *including the selected format* ---
        current_cmd_list = list(cmd_list) # Copy base + main + mode args
        # Add --edit-format only if the user selected an explicit format
        if selected_format != "default" and selected_format is not None:
            current_cmd_list.extend(["--edit-format", selected_format])

        # --- Display the pre-launch menu ---
        # clear # Disabled for debugging
        print(f"\n{SEPARATOR_MAIN}")
        print(launch_title)
        print(SEPARATOR_MAIN)

        # Display model info based on mode
        if mode == "architect":
            print(f"Architect Model: {main_vendor}/{main_model}")
            if editor_model != "default" and editor_model is not None:
                print(f"Editor Model:    {editor_vendor}/{editor_model}")
            else:
                print("Editor Model:    Default")
        else: # Code mode
            print(f"Main Model:      {main_vendor}/{main_model}")

        display_format = selected_format if selected_format != "default" else "Default (Aider chooses)"
        print(f"Edit Format:     {display_format}")
        print(SEPARATOR_SUB)
        print("AIDER LAUNCH COMMAND\n")

        # Print the command list elements, quoted and wrapped
        quoted_cmd = " ".join(subprocess.list2cmdline(current_cmd_list).split()) # Use list2cmdline for quoting, then split/join to handle spaces
        terminal_width = os.get_terminal_size().columns
        wrapped_cmd = textwrap.fill(quoted_cmd, width=terminal_width, subsequent_indent="  ")
        print(wrapped_cmd)

        print(SEPARATOR_SUB)

        # --- Show .aider.conf.yml if it exists in $HOME ---
        aider_conf_path = os.path.expanduser("~/.aider.conf.yml")
        if os.path.exists(aider_conf_path):
            print(f"Detected: {aider_conf_path}")
            print("These additional settings will be applied by Aider:\n")
            try:
                with open(aider_conf_path, 'r') as f:
                    print(f.read())
                print(f"\n{SEPARATOR_SUB}")
            except Exception as e:
                print(f"Warning: Could not read {aider_conf_path}: {e}", file=sys.stderr)
                print(f"\n{SEPARATOR_SUB}")


        print("1. Launch Aider with this command (Default: Enter)")
        print("2. Back to Edit Format Selection")
        print("0. Back to Main Menu (Mode Selection)")
        print(SEPARATOR_SUB)
        confirm_choice = input("Enter choice [1=Launch, 2=Back to Format, 0=Back to Main, Enter=1]: ").strip() or "1"

        # --- Handle user choice ---
        if confirm_choice == "1":
            print() # Newline before execution
            try:
                # Execute the command directly using the list
                result = subprocess.run(current_cmd_list, check=False) # Don't raise exception on non-zero exit
                exit_status = result.returncode
                if exit_status != 0:
                    print(f"Error: aider command failed with exit status {exit_status}.", file=sys.stderr)
                    input("Press Enter to return to the main menu...")
                    return 1 # Indicate failure -> Back to Main Menu
                # Aider ran successfully
                return 0 # Indicate success -> Back to Main Menu
            except FileNotFoundError:
                 print("\nError: 'aider' command not found. Is it installed and in your PATH?", file=sys.stderr)
                 input("Press Enter to return to the main menu...")
                 return 1 # Indicate error/abort -> Back to Main Menu
            except Exception as e:
                 print(f"\nAn error occurred while trying to launch aider: {e}", file=sys.stderr)
                 input("Press Enter to return to the main menu...")
                 return 1 # Indicate error/abort -> Back to Main Menu

        elif confirm_choice == "2":
            return 2 # Return specific code for back to format
        elif confirm_choice == "0":
            return 1 # Use 1 to indicate user aborted to main menu
        else:
            print("Invalid choice. Press Enter to try again...", file=sys.stderr)
            input()
            # Loop continues


def display_mode_selection_menu():
    """Displays the main menu for selecting the aider operating mode (Code/Architect) or exiting."""
    # clear # Disabled for debugging
    print(f"\n{SEPARATOR_MAIN}")
    print(TITLE_MODE_SELECT)
    print(SEPARATOR_MAIN)
    print("1. Code Mode")
    print("2. Architect Mode")
    print("0. Exit")
    print(SEPARATOR_MAIN)
    choice = input("Enter your choice [1-2, Enter=0]: ").strip() or "0"
    return choice

def run_code_mode():
    """Handles the user interaction flow for selecting vendor/model/format for Code mode."""
    main_vendor = None
    main_model = None
    selected_format = None
    launch_status = None

    # Loop for Vendor Selection
    while True:
        select_entity("vendor", "Code") # Sets SELECT_RESULT
        if SELECT_RESULT == "invalid":
            continue # Re-prompt for vendor
        elif SELECT_RESULT is None:
            return # Back to main menu
        main_vendor = SELECT_RESULT
        check_api_key(main_vendor) # Verify key
        break # Vendor selected, exit loop

    # Loop for Model Selection
    while True:
        select_entity("model", "Code", main_vendor) # Sets SELECT_RESULT
        if SELECT_RESULT == "invalid":
            continue # Re-prompt for model
        elif SELECT_RESULT is None:
            # Back selected, return to main menu
            return
        main_model = SELECT_RESULT
        break # Model selected, exit loop

    # Loop for Edit Format Selection and Launch Confirmation
    while True:
        # Select Edit Format
        select_edit_format("code") # Sets SELECT_RESULT
        if SELECT_RESULT == "invalid":
            continue # Re-prompt for format
        elif SELECT_RESULT is None:
            # Back selected, return to main menu
            return
        selected_format = SELECT_RESULT

        # Launch aider (which now includes the confirmation menu)
        launch_status = launch_aider("code", main_vendor, main_model, None, None, selected_format)

        # Check launch_status to decide next action
        if launch_status == 2:
            # User chose "Back to Edit Format Selection" from launch_aider
            continue # Continue the format selection loop
        else:
            # User launched (status 0), chose "Back to Main Menu" (status 1),
            # or an error occurred in launch_aider (status 1).
            # In all these cases, return to the main menu.
            return


def run_architect_mode():
    """Handles the user interaction flow for selecting vendor/model/format for Architect mode."""
    main_vendor = None
    main_model = None
    editor_vendor = None
    editor_model = None
    selected_format = None
    launch_status = None

    # Step 1: Select Main Vendor
    while True:
        select_entity("vendor", "Architect") # Sets SELECT_RESULT
        if SELECT_RESULT == "invalid":
            continue # Re-prompt for main vendor
        elif SELECT_RESULT is None:
            return # Back to main menu
        main_vendor = SELECT_RESULT
        check_api_key(main_vendor) # Verify key is loaded
        break # Vendor selected, exit loop

    # Step 2: Select Main Model
    while True:
        select_entity("model", "Architect", main_vendor) # Sets SELECT_RESULT
        if SELECT_RESULT == "invalid":
            continue # Re-prompt for main model
        elif SELECT_RESULT is None:
             # Back selected, return to main menu
            return
        main_model = SELECT_RESULT
        break # Model selected, exit loop

    # Step 3: Select Editor Vendor
    while True:
        select_entity("vendor", "Editor") # Sets SELECT_RESULT
        if SELECT_RESULT == "invalid":
            continue # Re-prompt for editor vendor
        elif SELECT_RESULT is None:
            # Back selected, return to main menu
            return
        editor_vendor = SELECT_RESULT
        break # Vendor selected (or "default"), exit loop

    # Step 4: Select Editor Model (or skip if default)
    if editor_vendor == "default":
        editor_model = "default" # Set model to default as well
    else:
        # Specific editor vendor chosen, need to check key and select model
        check_api_key(editor_vendor) # Verify key is loaded
        while True:
            select_entity("model", "Editor", editor_vendor) # Sets SELECT_RESULT
            if SELECT_RESULT == "invalid":
                continue # Re-prompt for editor model
            elif SELECT_RESULT is None:
                # Back selected, return to main menu
                return
            editor_model = SELECT_RESULT
            break # Model selected, exit loop

    # Step 5: Loop for Edit Format Selection and Launch Confirmation
    while True:
        # Select Edit Format
        select_edit_format("architect") # Sets SELECT_RESULT
        if SELECT_RESULT == "invalid":
            continue # Re-prompt for format
        elif SELECT_RESULT is None:
            # Back selected, return to main menu (as per plan)
            return
        selected_format = SELECT_RESULT

        # Launch Aider
        launch_status = launch_aider("architect", main_vendor, main_model, editor_vendor, editor_model, selected_format)

        # Check launch_status to decide next action
        if launch_status == 2:
            # User chose "Back to Edit Format Selection" from launch_aider
            continue # Continue the format selection loop
        else:
            # User launched (status 0), chose "Back to Main Menu" (status 1),
            # or an error occurred in launch_aider (status 1).
            # In all these cases, return to the main menu.
            return


def main():
    """Main entry point of the script."""
    parser = argparse.ArgumentParser(
        description="Interactive script to configure and launch the 'aider' tool.",
        formatter_class=argparse.RawTextHelpFormatter, # Use RawTextHelpFormatter for custom formatting
        add_help=False # Add help manually to match bash script's -h/--help handling
    )
    parser.add_argument(
        '-h', '--help', action='store_true',
        help='Display this help message and exit.'
    )

    # Parse only the help argument first
    # This allows the rest of the script to run if no help is requested
    # and avoids issues with unknown arguments if aider is launched later.
    help_parser = argparse.ArgumentParser(add_help=False)
    help_parser.add_argument('-h', '--help', action='store_true')
    args, _ = help_parser.parse_known_args()

    if args.help:
        # Print the full help message
        print("""Usage: ./run-aider.py [-h|--help]

This script provides an interactive menu to configure and launch the 'aider' tool.

Options:
  -h, --help    Display this help message and exit.

Description:
  The script guides you through selecting the operating mode (Code or Architect),
  the LLM vendor (Google, Anthropic, OpenAI, Deepseek), the specific model,
  and the desired edit format. It manages API keys and prepares the final
  'aider' command. It also automatically reads files specified under the 'read:'
  key in a .aider.conf.yml file if found.

  The script uses configuration from 'aider_config.json' for vendors, models,
  and edit formats. If this file is not found, it will exit.

API Key Setup:
  API keys are required for the selected LLM vendor(s). They can be provided in
  one of the following ways (checked in this order):

  1. Environment Variables:
     Export the required variables before running the script:
       export OPENAI_API_KEY="sk-..."
       export ANTHROPIC_API_KEY="sk-..."
       export GEMINI_API_KEY="AIza..."  # Preferred for Google
       # or export GOOGLE_API_KEY="AIza..."
       export DEEPSEEK_API_KEY="sk-..."

  2. API Keys File:
     - If the 'PRIMARY_KEYS_FILE' environment variable is set, the script will
       look for a file at that path.
     - Otherwise, it will look for a file at the default location:
       $HOME/.llm_api_keys

     The keys file should contain lines like:
       # LLM API Keys Configuration
       OPENAI_API_KEY="sk-..."
       ANTHROPIC_API_KEY="sk-..."
       GEMINI_API_KEY="AIza..."
       DEEPSEEK_API_KEY="sk-..."
       # Ensure the file is not world-readable (chmod 600)

Menu Flow:
  - Select Mode: Choose between 'Code' or 'Architect'.
  - Select Vendor(s): Choose the LLM provider.
  - Select Model(s): Choose the specific model. In Architect mode, select for
    both Architect and Editor roles.
  - Select Edit Format: Choose the desired edit format (e.g., 'whole', 'diff',
    'editor-whole', 'editor-diff-fenced').

Pre-Launch Confirmation:
  Before running 'aider', the script will display:
  - The selected mode, models, and edit format.
  - The 'aider' command with selected arguments
  - A display of ~/.aider.conf.yml which has more arguments for aider.
  You will then have options to:
  - Launch 'aider'.
  - Go back to the Edit Format selection menu.
  - Go back to the main menu (Mode selection).

Invocation:
  - To start the interactive menu: ./run-aider.py
  - To display this help:      ./run-aider.py -h  OR  ./run-aider.py --help
""")
        sys.exit(0)

    # Initialize configuration from JSON
    initialize_configuration()

    # Load API keys
    load_api_keys()

    # Loop indefinitely until user explicitly exits (choice 0)
    while True:
        # Select mode first
        selected_mode = None
        while selected_mode is None:
            mode_choice = display_mode_selection_menu()
            if mode_choice == "1":
                selected_mode = "code"
            elif mode_choice == "2":
                selected_mode = "architect"
            elif mode_choice == "0":
                print("Goodbye!")
                sys.exit(0)
            else:
                print("Invalid choice. Press Enter to continue...", file=sys.stderr)
                input()

        # Call the appropriate function based on selected mode
        if selected_mode == "code":
            run_code_mode()
        elif selected_mode == "architect":
            run_architect_mode()
        else:
            # This case should not be reachable due to the inner loop validation
            print(f"Error: Unknown mode selected: {selected_mode}", file=sys.stderr)
            sys.exit(1)

        # After run_code_mode or run_architect_mode returns (either after aider runs
        # or the user backs out), the main loop continues, showing the mode selection again.
        # Explicitly continue to ensure the loop restarts correctly.
        continue


if __name__ == "__main__":
    main()
