#!/bin/bash
#---------------------------------------------------------------------------------
#AIDER LAUNCH COMMAND RECOVERY
#aider --model gemini/gemini-2.5-pro-exp-03-25 --chat-mode code --edit-format whole
#---------------------------------------------------------------------------------

# --- Determine Script's Real Directory ---
# Get the absolute path of the script, resolving any symlinks
# This ensures the script can find its config file even when run via a symlink
SCRIPT_REAL_PATH=$(readlink -f "$0")
# Get the directory containing the script
SCRIPT_DIR=$(dirname "$SCRIPT_REAL_PATH")

# --- Configuration File Path ---
# Define the config file path relative to the script's actual directory
CONFIG_FILE="$SCRIPT_DIR/aider_config.json"

# --- Check for Required Tools ---
check_required_tools() {
    # Check if jq is installed for JSON parsing
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is required for JSON parsing but not found."
        echo "Please install jq using your package manager:"
        echo "  - Debian/Ubuntu: sudo apt install jq"
        echo "  - macOS: brew install jq"
        echo "  - Windows (with chocolatey): choco install jq"
        exit 1
    fi
    return 0
}

# --- JSON Configuration Loading ---
# Loads configuration from JSON file
load_json_config() {
    local config_file="$CONFIG_FILE"
    
    # Check if config file exists
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file '$config_file' not found."
        echo "Please create a configuration file with vendors, models, and edit formats."
        echo "Example format:"
        echo '{
  "vendors": ["OPENAI", "ANTHROPIC"],
  "models": {
    "OPENAI": ["gpt-4o", "gpt-4-turbo"],
    "ANTHROPIC": ["claude-3-5-haiku-20241022"]
  },
  "edit_formats": {
    "code": ["whole", "diff"],
    "architect": ["editor-whole", "editor-diff"]
  }
}'
        exit 1
    fi
    
    # Check if jq is available - this will exit if jq is not found
    check_required_tools
    
    # Validate that the file contains valid JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        echo "Error: Configuration file '$config_file' contains invalid JSON."
        echo "Please check the file for syntax errors (missing commas, brackets, etc)."
        exit 1
    fi
    
    # Validate the overall structure of the JSON
    validate_json_structure "$config_file"
    
    echo "Loading configuration from $config_file..."
    return 0
}

# --- Validate JSON Structure ---
# Validates that the JSON file has the required structure
validate_json_structure() {
    local config_file="$1"
    local missing_fields=()
    
    # Check for required top-level fields
    if ! jq -e '.vendors' "$config_file" > /dev/null 2>&1; then
        missing_fields+=("vendors")
    fi
    
    if ! jq -e '.models' "$config_file" > /dev/null 2>&1; then
        missing_fields+=("models")
    fi
    
    if ! jq -e '.edit_formats' "$config_file" > /dev/null 2>&1; then
        missing_fields+=("edit_formats")
    fi
    
    # Check for required edit_formats subfields
    if jq -e '.edit_formats' "$config_file" > /dev/null 2>&1; then
        if ! jq -e '.edit_formats.code' "$config_file" > /dev/null 2>&1; then
            missing_fields+=("edit_formats.code")
        fi
        
        if ! jq -e '.edit_formats.architect' "$config_file" > /dev/null 2>&1; then
            missing_fields+=("edit_formats.architect")
        fi
    fi
    
    # Check that vendors is an array
    if jq -e '.vendors' "$config_file" > /dev/null 2>&1; then
        if ! jq -e 'if .vendors | type != "array" then false else true end' "$config_file" > /dev/null 2>&1; then
            echo "Error: 'vendors' must be an array in $config_file"
            exit 1
        fi
    fi
    
    # Check that models is an object
    if jq -e '.models' "$config_file" > /dev/null 2>&1; then
        if ! jq -e 'if .models | type != "object" then false else true end' "$config_file" > /dev/null 2>&1; then
            echo "Error: 'models' must be an object in $config_file"
            exit 1
        fi
    fi
    
    # Check that edit_formats is an object
    if jq -e '.edit_formats' "$config_file" > /dev/null 2>&1; then
        if ! jq -e 'if .edit_formats | type != "object" then false else true end' "$config_file" > /dev/null 2>&1; then
            echo "Error: 'edit_formats' must be an object in $config_file"
            exit 1
        fi
    fi
    
    # Report missing fields
    if [ ${#missing_fields[@]} -gt 0 ]; then
        echo "Error: The following required fields are missing in $config_file:"
        for field in "${missing_fields[@]}"; do
            echo "  - $field"
        done
        echo "Please ensure the configuration file contains all required fields."
        exit 1
    fi
}

# --- Usage Message Function ---
# Define this early so it's available for the help flag check below
display_usage() {
    cat << EOF
Usage: ./run-aider.sh [-h|--help]

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
  and edit formats. If this file is not found or 'jq' is not installed, it will
  fall back to hardcoded defaults.

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
       \$HOME/.llm_api_keys

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
  - To start the interactive menu: ./run-aider.sh
  - To display this help:      ./run-aider.sh -h  OR  ./run-aider.sh --help
EOF
}

# --- Argument Parsing for Help ---
# Check if the first argument is -h or --help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    display_usage # Call the function defined above
    exit 0        # Exit successfully after displaying help
fi

# --- Model and Vendor Definitions ---
# These arrays will be populated from JSON if available, otherwise use hardcoded defaults

# Initialize empty arrays
VENDORS=()
GOOGLE_MODELS=()
ANTHROPIC_MODELS=()
OPENAI_MODELS=()
DEEPSEEK_MODELS=()
CODE_EDIT_FORMATS=()
ARCHITECT_EDIT_FORMATS=()

# Parallel array holding the API key flag for each vendor
VENDOR_API_KEY_FLAGS=(
    "api-key google="   # GOOGLE (Note: includes 'google=')
    "anthropic-api-key " # ANTHROPIC (Note the trailing space)
    "openai-api-key "    # OPENAI (Note the trailing space)
    "deepseek-api-key "  # DEEPSEEK (Note the trailing space)
)

# Parallel array to track the source of the API key ("env", "file", or "unset")
VENDOR_KEY_SOURCE=("unset" "unset" "unset" "unset") # Initialize with values to avoid unbound variable

# --- Load Configuration from JSON ---
load_vendors_from_json() {
    # Check if vendors exist in the JSON
    if ! jq -e '.vendors' "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "Error: 'vendors' field is missing in $CONFIG_FILE"
        echo "Please ensure the configuration file contains a 'vendors' array."
        exit 1
    fi
    
    # Load vendors from JSON
    VENDORS=()
    while IFS= read -r line; do
        VENDORS+=("$line")
    done < <(jq -r '.vendors[]' "$CONFIG_FILE")
    
    # Check if vendors array is empty
    if [ ${#VENDORS[@]} -eq 0 ]; then
        echo "Error: No vendors found in $CONFIG_FILE"
        echo "Please add at least one vendor to the 'vendors' array."
        exit 1
    fi
    
    return 0
}

load_models_from_json() {
    # Check if models object exists in the JSON
    if ! jq -e '.models' "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "Error: 'models' field is missing in $CONFIG_FILE"
        echo "Please ensure the configuration file contains a 'models' object with models for each vendor."
        exit 1
    fi
    
    # Load models for each vendor from JSON
    local missing_vendors=()
    local empty_models=()
    
    for vendor in "${VENDORS[@]}"; do
        local models_array_name="${vendor}_MODELS"
        # Check if the vendor exists in the JSON models section
        if jq -e ".models.\"$vendor\"" "$CONFIG_FILE" > /dev/null 2>&1; then
            # Load models for this vendor
            eval "${models_array_name}=()"
            while IFS= read -r line; do
                eval "${models_array_name}+=(\"\$line\")"
            done < <(jq -r ".models.\"$vendor\"[]" "$CONFIG_FILE")
            
            # Check if models array is empty for this vendor
            local count
            eval "count=\${#${models_array_name}[@]}"
            if [ "$count" -eq 0 ]; then
                empty_models+=("$vendor")
            fi
        else
            missing_vendors+=("$vendor")
        fi
    done
    
    # Report any missing vendor models
    if [ ${#missing_vendors[@]} -gt 0 ]; then
        echo "Error: The following vendors are missing from the 'models' section in $CONFIG_FILE:"
        for v in "${missing_vendors[@]}"; do
            echo "  - $v"
        done
        echo "Please add model entries for all vendors listed in the 'vendors' array."
        exit 1
    fi
    
    # Report any empty model arrays
    if [ ${#empty_models[@]} -gt 0 ]; then
        echo "Error: The following vendors have empty model arrays in $CONFIG_FILE:"
        for v in "${empty_models[@]}"; do
            echo "  - $v"
        done
        echo "Please add at least one model for each vendor."
        exit 1
    fi
    
    return 0
}

load_edit_formats_from_json() {
    # Check if edit_formats object exists in the JSON
    if ! jq -e '.edit_formats' "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "Error: 'edit_formats' field is missing in $CONFIG_FILE"
        echo "Please ensure the configuration file contains an 'edit_formats' object with 'code' and 'architect' arrays."
        exit 1
    fi
    
    # Check and load code edit formats
    if ! jq -e '.edit_formats.code' "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "Error: 'edit_formats.code' array is missing in $CONFIG_FILE"
        echo "Please add a 'code' array under 'edit_formats' with format options."
        exit 1
    fi
    
    CODE_EDIT_FORMATS=()
    while IFS= read -r line; do
        CODE_EDIT_FORMATS+=("$line")
    done < <(jq -r '.edit_formats.code[]' "$CONFIG_FILE")
    
    # Check if code formats array is empty
    if [ ${#CODE_EDIT_FORMATS[@]} -eq 0 ]; then
        echo "Error: 'edit_formats.code' array is empty in $CONFIG_FILE"
        echo "Please add at least one edit format for code mode (e.g., 'whole', 'diff')."
        exit 1
    fi
    
    # Check and load architect edit formats
    if ! jq -e '.edit_formats.architect' "$CONFIG_FILE" > /dev/null 2>&1; then
        echo "Error: 'edit_formats.architect' array is missing in $CONFIG_FILE"
        echo "Please add an 'architect' array under 'edit_formats' with format options."
        exit 1
    fi
    
    ARCHITECT_EDIT_FORMATS=()
    while IFS= read -r line; do
        ARCHITECT_EDIT_FORMATS+=("$line")
    done < <(jq -r '.edit_formats.architect[]' "$CONFIG_FILE")
    
    # Check if architect formats array is empty
    if [ ${#ARCHITECT_EDIT_FORMATS[@]} -eq 0 ]; then
        echo "Error: 'edit_formats.architect' array is empty in $CONFIG_FILE"
        echo "Please add at least one edit format for architect mode (e.g., 'editor-whole', 'editor-diff')."
        exit 1
    fi
    
    return 0
}

# Function to initialize all configuration
initialize_configuration() {
    # First check if the configuration file exists and jq is available
    # This will exit if the file doesn't exist or jq is not installed
    load_json_config
    
    # Initialize empty arrays
    VENDORS=()
    
    # Load configuration from JSON
    # Each of these functions will exit if required data is missing
    load_vendors_from_json
    load_models_from_json
    load_edit_formats_from_json
    
    echo "Configuration loaded successfully from $CONFIG_FILE"
}

# --- Centered Menu Titles (Static) ---
# Calculated for an 80-character width
TITLE_MODE_SELECT="                         SELECT AIDER OPERATING MODE                          "
TITLE_CODE_VENDOR="                           SELECT CODE MODE VENDOR                            "
TITLE_CODE_MODEL="                            SELECT CODE MODE MODEL                             "
TITLE_ARCH_VENDOR="                         SELECT ARCHITECT MODE VENDOR                         "
TITLE_ARCH_MODEL="                          SELECT ARCHITECT MODE MODEL                          "
TITLE_EDITOR_VENDOR="                            SELECT EDITOR VENDOR                             "
TITLE_EDITOR_MODEL="                             SELECT EDITOR MODEL                              "
TITLE_CODE_FORMAT="                         SELECT CODE MODE EDIT FORMAT                         "
TITLE_ARCH_FORMAT="                       SELECT ARCHITECT EDIT FORMAT                         "
TITLE_LAUNCH_CODE="                         LAUNCHING AIDER: CODE MODE                          "
TITLE_LAUNCH_ARCH="                       LAUNCHING AIDER: ARCHITECT MODE                       "

# --- Separator Lines ---
SEPARATOR_MAIN="================================================================================" # 80 chars
SEPARATOR_SUB="--------------------------------------------------------------------------------" # 80 chars


# --- API Key Loading Helper Functions ---

# Attempts to load API keys from environment variables.
# Updates VENDOR_KEY_SOURCE and exports found keys.
#
# Args: None
#
# Outputs:
#   - Exports API key environment variables (e.g., OPENAI_API_KEY) if found.
#   - Modifies the global VENDOR_KEY_SOURCE array.
#
# Returns:
#   - 0 if all vendor keys were found in the environment.
#   - 1 if one or more keys were not found in the environment.
_load_keys_from_env() {
    local vendor api_key_var env_api_key all_found=true i=0

    echo "Checking environment variables for API keys..."

    for vendor in "${VENDORS[@]}"; do
        api_key_var="${vendor}_API_KEY"
        env_api_key="" # Reset for each vendor

        # --- Special handling for GOOGLE ---
        if [[ "$vendor" == "GOOGLE" ]]; then
            if [ -n "$GEMINI_API_KEY" ]; then
                env_api_key="$GEMINI_API_KEY"
            elif [ -n "$GOOGLE_API_KEY" ]; then
                env_api_key="$GOOGLE_API_KEY"
            fi
        else
            # --- Standard handling for other vendors ---
            env_api_key="${!api_key_var}" # Indirect expansion
        fi
        # --- End Vendor Specific Handling ---

        if [ -n "$env_api_key" ]; then
            # Key found in environment, export the standard var and update source
            export "$api_key_var"="$env_api_key"
            VENDOR_KEY_SOURCE[$i]="env"
            # echo "Debug: Found $vendor key in env." # Optional debug
        else
            # Key not found in environment for this vendor
            VENDOR_KEY_SOURCE[$i]="unset"
            all_found=false
            # Ensure the shell variable is also unset in case it lingered from a previous run/source
            unset "$api_key_var"
            # echo "Debug: Did not find $vendor key in env." # Optional debug
        fi
        i=$((i + 1))
    done

    if $all_found; then
        echo "All required API keys found in environment variables."
        return 0 # Success code (all found)
    else
        echo "One or more API keys not found in environment variables. Will check files."
        return 1 # Failure code (some missing)
    fi
}

# Finds the API keys file to use based on environment variable or default path.
#
# Args: None
#
# Outputs:
#   - Prints the full path of the keys file to stdout if found.
#   - Prints nothing if no suitable file is found.
#
# Returns: None
_find_keys_file() {
    local primary_file="$PRIMARY_KEYS_FILE"
    local secondary_file="$HOME/.llm_api_keys"
    local file_to_use=""

    if [ -n "$primary_file" ] && [ -f "$primary_file" ]; then
        file_to_use="$primary_file"
        # echo "Debug: Using primary keys file: $file_to_use" # Optional debug
    elif [ -f "$secondary_file" ]; then
        file_to_use="$secondary_file"
        # echo "Debug: Using secondary keys file: $file_to_use" # Optional debug
    # else
        # echo "Debug: No API keys file found." # Optional debug
    fi

    # Print the path to stdout if found
    echo "$file_to_use"
}

# Loads API keys from the specified file by sourcing it.
# Updates VENDOR_KEY_SOURCE for keys loaded from the file.
#
# Args:
#   $1: keys_file_path - The full path to the API keys file.
#
# Outputs:
#   - Modifies the global VENDOR_KEY_SOURCE array.
#   - Sources the file, potentially exporting environment variables.
#
# Returns: None
_load_keys_from_file() {
    local keys_file_path=$1
    local j=0 vendor_check key_var_check key_val_check

    if [ ! -f "$keys_file_path" ]; then
        echo "Error: Keys file not found at path: $keys_file_path" >&2
        # This should ideally not happen if _find_keys_file worked, but good practice
        return 1
    fi

    echo "Loading API keys from file: $keys_file_path"
    # Disable unbound variable errors temporarily during source
    set +u
    # shellcheck source=/dev/null # Tell shellcheck we are intentionally sourcing a variable path
    source "$keys_file_path"
    set -u # Re-enable unbound variable errors

    # Update source array for keys that were loaded from the file
    for vendor_check in "${VENDORS[@]}"; do
        key_var_check="${vendor_check}_API_KEY"
        # Check the value *after* sourcing, using indirect expansion
        if printenv "$key_var_check" >/dev/null 2>&1; then
            key_val_check="${!key_var_check}"
        else
            key_val_check=""
        fi

        # If source is still unset AND the variable now has a value, it came from the file
        if [[ "${VENDOR_KEY_SOURCE[$j]}" == "unset" && -n "$key_val_check" ]]; then
            VENDOR_KEY_SOURCE[$j]="file"
            # No need to re-export, source should handle that if keys were exported in the file
            # If keys were just assigned (e.g., VAR="value"), export them now
             if ! export -p | grep -q "declare -x ${key_var_check}="; then
                 export "$key_var_check"="$key_val_check"
                 # echo "Debug: Exported $vendor_check key loaded from file." # Optional debug
             fi
        # else
             # echo "Debug: $vendor_check key status unchanged (Source: ${VENDOR_KEY_SOURCE[$j]}, Value present: $( [ -n "$key_val_check" ] && echo true || echo false ))" # Optional debug
        fi
        j=$((j + 1))
    done
}

# --- Main API Key Loading Function ---

# Loads API keys, coordinating checks between environment and files.
# Priority: Environment -> PRIMARY_KEYS_FILE -> $HOME/.llm_api_keys
# Populates VENDOR_KEY_SOURCE. The check_api_key function handles exiting
# if the *required* key is missing later.
#
# Args: None
#
# Outputs:
#   - Exports API key environment variables (e.g., OPENAI_API_KEY) if found.
#   - Populates the global VENDOR_KEY_SOURCE array.
#   - Prints status messages to stdout.
#
# Modifies:
#   - Environment variables for API keys.
#   - VENDOR_KEY_SOURCE array.
load_api_keys() {
    local keys_file_path # Removed env_load_status

    echo "Attempting to load API keys..."

    # Initialize source array
    local i
    for i in "${!VENDORS[@]}"; do
        VENDOR_KEY_SOURCE[$i]="unset"
    done

    # 1. Try loading from environment variables
    _load_keys_from_env
    # env_load_status=$? # Status is no longer needed for control flow here

    # 2. Always check for a keys file, regardless of env status
    keys_file_path=$(_find_keys_file)

    # 3. If a keys file exists, attempt to load from it
    #    This will update the source for keys not found in env.
    if [ -n "$keys_file_path" ]; then
        _load_keys_from_file "$keys_file_path"
    # else # No need for an else block, just proceed if no file found
        # echo "Debug: No API keys file found, proceeding with environment keys only." # Optional debug message
    fi

    # REMOVED the premature exit block that was here.
    # The check_api_key function, called *after* vendor selection,
    # will now be responsible for exiting if the *specifically required*
    # key is missing.

    echo "API key loading process complete."
}


# Generalized function to select an entity (vendor or model) via an interactive menu.
#
# Args:
#   $1: entity_type - The type of entity to select ("vendor" or "model").
#   $2: role_label - A label describing the role for the selection (e.g., "Code", "Architect", "Editor").
#   $3: vendor (optional) - The vendor name, required only when entity_type is "model".
#
# Outputs:
#   - Prints menu options to stdout.
#   - Reads user choice from stdin.
#   - Prints error messages to stderr for invalid input.
#
# Modifies:
#   - Sets the global variable SELECT_ENTITY_RESULT to:
#     - The selected entity name (e.g., "OPENAI", "gpt-4o").
#     - An empty string "" if the user chooses "Back".
#     - "default" if the user chooses "Use same VENDOR and MODEL as Architect" (Editor vendor only).
#     - "invalid" if the user enters an invalid choice.
select_entity() {
    local entity_type=$1  # "vendor" or "model"
    local role_label=$2  # "Code", "Architect", or "Editor"
    # local vendor=$3      # Vendor - Moved inside the 'model' block below
    local entities=()    # Use a regular array instead of nameref
    local num_entities
    local choice i         # Added 'i' for loop counter
    local menu_title=""    # Initialize menu title

    if [[ "$entity_type" == "vendor" ]]; then
        # Filter vendors to only include those with loaded keys
        local available_vendors=()
        local vendor_index=0
        for vendor_name in "${VENDORS[@]}"; do
            if [[ "${VENDOR_KEY_SOURCE[$vendor_index]}" != "unset" ]]; then
                available_vendors+=("$vendor_name")
            fi
            vendor_index=$((vendor_index + 1))
        done
        entities=("${available_vendors[@]}")
        # Select appropriate pre-formatted title
        if [[ "$role_label" == "Code" ]]; then
            menu_title="$TITLE_CODE_VENDOR"
        elif [[ "$role_label" == "Architect" ]]; then
            menu_title="$TITLE_ARCH_VENDOR"
        elif [[ "$role_label" == "Editor" ]]; then
            menu_title="$TITLE_EDITOR_VENDOR"
        fi
    elif [[ "$entity_type" == "model" ]]; then
        local vendor=$3 # Assign vendor here, only when needed for models
        # Use indirect expansion to dynamically get the correct model array elements
        local models_array_ref="${vendor}_MODELS[@]" # Create reference string including [@]
        # Check if the base array variable exists
        local models_array_name="${vendor}_MODELS"
        if declare -p "$models_array_name" &>/dev/null; then
            # Use indirect expansion to assign elements to the local 'entities' array
            entities=("${!models_array_ref}")
        else
            echo "Error: Model array variable not found for vendor: $vendor" >&2
            SELECT_ENTITY_RESULT="invalid"
            return 1 # Return error
        fi
        # Select appropriate pre-formatted title
        if [[ "$role_label" == "Code" ]]; then
            menu_title="$TITLE_CODE_MODEL"
        elif [[ "$role_label" == "Architect" ]]; then
            menu_title="$TITLE_ARCH_MODEL"
        elif [[ "$role_label" == "Editor" ]]; then
            menu_title="$TITLE_EDITOR_MODEL"
        fi
    else
        echo "Error: Invalid entity type: $entity_type" >&2
        SELECT_ENTITY_RESULT="invalid" # Set global var on error too
        return 1
    fi

    # Fallback title if something went wrong
    if [[ -z "$menu_title" ]]; then
        menu_title="         SELECT ${role_label^^} ${entity_type^^}         " # Generic fallback
    fi

    num_entities=${#entities[@]}

    # clear # Disabled for debugging
    # Display menu using pre-formatted title and new separator length
    echo -e "\n$SEPARATOR_MAIN" # Add newline since clear is disabled
    echo "$menu_title"
    echo -e "$SEPARATOR_MAIN"

    # Check if there are any entities to display after filtering
    if [ "$num_entities" -eq 0 ]; then
        if [[ "$entity_type" == "vendor" ]]; then
             echo "No vendors found with loaded API keys."
             echo "Please ensure you have set API keys in environment variables or a keys file."
             echo -e "$SEPARATOR_MAIN"
             echo "0. Back"
             echo -e "$SEPARATOR_MAIN"
             echo -n "Enter your choice [Enter=0]: "
             read choice
             if [[ -z "$choice" || "$choice" == "0" ]]; then
                 SELECT_ENTITY_RESULT="" # Back selected
             else
                 echo "Invalid choice." >&2
                 read -p "Press Enter..."
                 SELECT_ENTITY_RESULT="invalid" # Indicate invalid input
             fi
             return 0
        else
            # This case (no models for a selected vendor) should ideally be caught by load_models_from_json
            # but handle defensively.
            echo "No models available for the selected vendor."
            echo -e "$SEPARATOR_MAIN"
            echo "0. Back"
            echo -e "$SEPARATOR_MAIN"
            echo -n "Enter your choice [Enter=0]: "
            read choice
             if [[ -z "$choice" || "$choice" == "0" ]]; then
                 SELECT_ENTITY_RESULT="" # Back selected
             else
                 echo "Invalid choice." >&2
                 read -p "Press Enter..."
                 SELECT_ENTITY_RESULT="invalid" # Indicate invalid input
             fi
             return 0
        fi
    fi


    # Use C-style for loop for better compatibility
    for ((i=0; i<num_entities; i++)); do
        printf "%d. %s\n" "$((i + 1))" "${entities[$i]}"
    done
    # Add option 9 only when selecting the Editor vendor
    local prompt_range="1-${num_entities}"
    if [[ "$entity_type" == "vendor" && "$role_label" == "Editor" ]]; then
        echo "9. Use same VENDOR and MODEL as Architect"
        prompt_range="1-${num_entities}, 9"
    fi
    echo "0. Back"
    echo -e "$SEPARATOR_MAIN"
    echo -n "Enter your choice [${prompt_range}, Enter=0]: "
    read choice

    SELECT_ENTITY_RESULT=""

    if [[ -z "$choice" || "$choice" == "0" ]]; then
        SELECT_ENTITY_RESULT=""  # "Back" selected
    # Handle option 9 specifically for Editor vendor selection
    elif [[ "$entity_type" == "vendor" && "$role_label" == "Editor" && "$choice" == "9" ]]; then
        SELECT_ENTITY_RESULT="default"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= num_entities )); then
        SELECT_ENTITY_RESULT="${entities[$((choice - 1))]}"
    else
        echo "Invalid choice." >&2
        read -p "Press Enter..."
        SELECT_ENTITY_RESULT="invalid"  # Indicate invalid input
    fi
    # Return 0 for success in setting the global var (or indicating invalid choice)
    return 0
}

# Selects the Aider edit format via an interactive menu.
#
# Args:
#   $1: mode - The current operating mode ("code" or "architect").
#
# Outputs:
#   - Prints menu options to stdout.
#   - Reads user choice from stdin.
#   - Prints error messages to stderr for invalid input.
#
# Modifies:
#   - Sets the global variable SELECT_EDIT_FORMAT_RESULT to:
#     - The selected format string (e.g., "whole", "editor-diff").
#     - An empty string "" if the user chooses "Back".
#     - "invalid" if the user enters an invalid choice.
select_edit_format() {
    local mode=$1
    local formats=()
    local num_formats
    local choice i
    local menu_title="" # Initialize menu title

    # Determine which set of formats to offer based on the mode
    if [[ "$mode" == "code" ]]; then
        formats=("${CODE_EDIT_FORMATS[@]}")
        menu_title="$TITLE_CODE_FORMAT"
    elif [[ "$mode" == "architect" ]]; then
        formats=("${ARCHITECT_EDIT_FORMATS[@]}")
        menu_title="$TITLE_ARCH_FORMAT" # Use updated title
    else
        echo "Error: Invalid mode passed to select_edit_format: $mode" >&2
        SELECT_EDIT_FORMAT_RESULT="invalid"
        return 1
    fi

    # Prepend a default option that lets Aider decide automatically
    local display_options=("Default (Aider chooses)" "${formats[@]}")
    local num_options=${#display_options[@]}

    # clear # Disabled for debugging
    echo -e "\n$SEPARATOR_MAIN" # Add newline since clear is disabled
    echo "$menu_title"
    echo -e "$SEPARATOR_MAIN"

    # Display format options (including Default)
    for ((i=0; i<num_options; i++)); do
        printf "%d. %s\n" "$((i + 1))" "${display_options[$i]}"
    done
    echo "0. Back"
    echo -e "$SEPARATOR_MAIN"
    echo -n "Enter your choice [1-${num_options}, Enter=0]: "
    read choice

    SELECT_EDIT_FORMAT_RESULT=""

    if [[ -z "$choice" || "$choice" == "0" ]]; then
        SELECT_EDIT_FORMAT_RESULT=""  # "Back" selected
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= num_options )); then
        if (( choice == 1 )); then
            SELECT_EDIT_FORMAT_RESULT="default"
        else
            SELECT_EDIT_FORMAT_RESULT="${formats[$((choice - 2))]}"  # Offset by one due to default
        fi
    else
        echo "Invalid choice." >&2
        read -p "Press Enter..."
        SELECT_EDIT_FORMAT_RESULT="invalid"  # Indicate invalid input
    fi

    return 0 # Success
}


# Checks if the API key for the specified vendor is available as an environment variable.
# It relies on load_api_keys having been called previously to load keys from files into env vars if necessary.
#
# Args:
#   $1: vendor - The name of the vendor (e.g., "OPENAI", "GOOGLE").
#
# Outputs:
#   - Prints an error message to stderr and exits with status 1 if the key is not set.
check_api_key() {
    local vendor=$1
    local api_key_var="${vendor}_API_KEY"
    # Use indirect expansion instead of eval
    local api_key="${!api_key_var}"
    local vendor_index=$(_get_vendor_index "$vendor") # Get index for source check
    local key_source="unset" # Default if index is invalid
    if [ "$vendor_index" -ne -1 ]; then
        key_source="${VENDOR_KEY_SOURCE[$vendor_index]}"
    fi

    # Check if the key is actually set *and* its source is known (env or file)
    # This prevents errors if load_api_keys failed silently or VENDOR_KEY_SOURCE is somehow wrong.
    if [ -z "$api_key" ] || [[ "$key_source" == "unset" ]]; then
        local secondary_keys_file="$HOME/.llm_api_keys" # Define for error message
        echo -e "\nError: API key for $vendor is not set or could not be loaded." >&2
        echo -e "Source status: $key_source" >&2 # Add source status to error
        # --- Special error message for GOOGLE ---
        if [[ "$vendor" == "GOOGLE" ]]; then
            echo -e "Please ensure it is defined either as an environment variable (GEMINI_API_KEY or GOOGLE_API_KEY)" >&2
            echo -e "or within your API keys file (GEMINI_API_KEY or GOOGLE_API_KEY)." >&2
            echo -e "Checked locations:" >&2
            echo -e "  - Environment Variable: GEMINI_API_KEY" >&2
            echo -e "  - Environment Variable: GOOGLE_API_KEY" >&2
        else
        # --- Standard error message for other vendors ---
            echo -e "Please ensure it is defined either as an environment variable (${vendor}_API_KEY)" >&2
            echo -e "or within your API keys file." >&2
            echo -e "Checked locations:" >&2
            echo -e "  - Environment Variable: ${vendor}_API_KEY" >&2
        fi
        # --- Common part of error message ---
        if [ -n "$PRIMARY_KEYS_FILE" ]; then
            echo -e "  - Primary Keys File (env): \$PRIMARY_KEYS_FILE -> $PRIMARY_KEYS_FILE" >&2
        else
            echo -e "  - Primary Keys File (env): \$PRIMARY_KEYS_FILE (not set)" >&2
        fi
        echo -e "  - Secondary Keys File (default): $secondary_keys_file" >&2
        exit 1
    fi
    # echo "Debug: API key for $vendor confirmed (Source: $key_source)." # Optional debug
}

# Displays the main menu for selecting the aider operating mode (Code/Architect) or exiting.
#
# Args: None
#
# Outputs:
#   - Prints the menu options to stdout.
display_mode_selection_menu() {
    # clear # Disabled for debugging
    # Display menu using pre-formatted title and new separator length
    echo -e "\n$SEPARATOR_MAIN" # Add newline since clear is disabled
    echo "$TITLE_MODE_SELECT"
    echo -e "$SEPARATOR_MAIN"
    echo "1. Code Mode"
    echo "2. Architect Mode"
    echo "0. Exit"
    echo -e "$SEPARATOR_MAIN"
    echo -n "Enter your choice [1-2, Enter=0]: "
}

# --- Helper functions ---

# Gets the numerical index (0-based) of a vendor within the global VENDORS array.
#
# Args:
#   $1: vendor_name - The uppercase name of the vendor (e.g., "OPENAI").
#
# Outputs:
#   - Prints the numerical index to stdout if found.
#   - Prints -1 to stdout if the vendor is not found in the VENDORS array.
_get_vendor_index() {
    local vendor_name=$1
    local index=-1 i
    for i in "${!VENDORS[@]}"; do
        if [[ "${VENDORS[$i]}" == "$vendor_name" ]]; then
            index=$i
            break
        fi
    done
    echo "$index"
}

# Builds the command-line arguments related to the main model selection.
# This includes the --model flag and potentially the vendor-specific API key flag
# if the key was loaded from a file (not from environment variables).
#
# Args:
#   $1: main_vendor - The selected main vendor name.
#   $2: main_model - The selected main model name.
#   $3: main_api_key - The API key value for the main vendor.
#
# Outputs:
#   - Prints the constructed arguments, one per line, to stdout.
#   - Prints error messages to stderr if the vendor index is not found.
# Returns:
#   - 0 on success.
#   - 1 if the vendor index is not found.
_build_main_model_args() {
    local main_vendor=$1
    local main_model=$2
    local main_api_key=$3
    local args_array=() # Use an array to build arguments
    local vendor_index=$(_get_vendor_index "$main_vendor")

    args_array+=("--model" "$main_model")

    if [ "$vendor_index" -ne -1 ]; then
        local key_source="${VENDOR_KEY_SOURCE[$vendor_index]}"
        # Only add the API key flag if the key was loaded from a file
        if [[ "$key_source" == "file" ]]; then
            local flag_def="${VENDOR_API_KEY_FLAGS[$vendor_index]}"
            local flag_name=""
            local key_prefix=""
            # Remove trailing space if exists
            flag_def="${flag_def% }"
            if [[ "$flag_def" == *= ]]; then
                # Ends with '=', split it (e.g., "api-key google=")
                key_prefix="${flag_def#*=}" # Get "google="
                flag_name="${flag_def%=*}"  # Get "api-key"
                args_array+=("--${flag_name}" "${key_prefix}${main_api_key}")
            else
                # No '=', use the whole definition as flag name (e.g., "openai-api-key")
                flag_name="$flag_def"
                args_array+=("--${flag_name}" "$main_api_key")
            fi
            # echo "Debug: Adding main API key flag for $main_vendor (source: file)" # Optional debug
        # else
            # echo "Debug: Skipping main API key flag for $main_vendor (source: $key_source)" # Optional debug
        fi
    else
        echo "Error: Unknown main vendor index in _build_main_model_args for: $main_vendor" >&2
        return 1
    fi

    # Print array elements one per line
    printf "%s\n" "${args_array[@]}"
    return 0
}

# Builds the command-line arguments specific to Architect mode.
# This includes --architect, potentially --editor-model,
# and the editor's API key flag if the editor vendor is different from the main vendor
# and the key was loaded from a file. The --edit-format flag is NOT added here.
#
# Args:
#   $1: editor_vendor - The selected editor vendor name (or "default").
#   $2: editor_model - The selected editor model name (or "default").
#   $3: editor_api_key - The API key value for the editor vendor (only needed if editor_vendor != main_vendor).
#   $4: main_vendor - The selected main vendor name (used for comparison).
#
# Outputs:
#   - Prints the constructed arguments, one per line, to stdout.
#   - Prints error/warning messages to stderr.
# Returns:
#   - 0 on success.
#   - 1 if the editor vendor index is not found when needed.
_build_architect_args() {
    local editor_vendor=$1
    local editor_model=$2
    local editor_api_key=$3
    local main_vendor=$4 # Needed to check if editor vendor differs
    local args_array=() # Use an array to build arguments

    # Always add --architect. Edit format is added in launch_aider.
    args_array+=("--architect")

    # Add --editor-model only if a specific one is chosen (not default)
    if [ "$editor_model" != "default" ] && [ -n "$editor_model" ]; then
        args_array+=("--editor-model" "$editor_model")

        # Check if editor vendor is different from main vendor
        if [ "$editor_vendor" != "$main_vendor" ]; then
            # We need the API key value if it came from a file
            # The key value is passed in $editor_api_key only if needed (diff vendor)
            local editor_vendor_index=$(_get_vendor_index "$editor_vendor")
            if [ "$editor_vendor_index" -ne -1 ]; then
                local editor_key_source="${VENDOR_KEY_SOURCE[$editor_vendor_index]}"
                # Only add the API key flag if the key was loaded from a file
                if [[ "$editor_key_source" == "file" ]]; then
                    # Ensure the key value is actually available before adding the flag
                    if [ -n "$editor_api_key" ]; then
                        local editor_flag_def="${VENDOR_API_KEY_FLAGS[$editor_vendor_index]}"
                        local editor_flag_name=""
                        local editor_key_prefix=""
                        # Remove trailing space if exists
                        editor_flag_def="${editor_flag_def% }"
                        if [[ "$editor_flag_def" == *= ]]; then
                            # Ends with '=', split it
                            editor_key_prefix="${editor_flag_def#*=}"
                            editor_flag_name="${editor_flag_def%=*}"
                            args_array+=("--${editor_flag_name}" "${editor_key_prefix}${editor_api_key}")
                        else
                            # No '=', use the whole definition as flag name
                            editor_flag_name="$editor_flag_def"
                            args_array+=("--${editor_flag_name}" "$editor_api_key")
                        fi
                        # echo "Debug: Adding editor API key flag for $editor_vendor (source: file)" # Optional debug
                    else
                         # This indicates a logic error - key source is file, but key value wasn't passed
                         echo "Warning: Editor key source for $editor_vendor is 'file', but key value is missing in _build_architect_args." >&2
                    fi
                # else
                    # echo "Debug: Skipping editor API key flag for $editor_vendor (source: $editor_key_source)" # Optional debug
                fi
            else
                echo "Error: Unknown editor vendor index in _build_architect_args for: $editor_vendor" >&2
                return 1 # Explicitly return error code
            fi
        fi
    fi

    # Print array elements one per line
    printf "%s\n" "${args_array[@]}"
    return 0
}

# Builds the command-line arguments specific to Code mode.
# Sets the chat mode. The --edit-format flag is NOT added here.
#
# Args: None
#
# Outputs:
#   - Prints the argument string ("--chat-mode", "code"), one per line, to stdout.
_build_code_args() {
    local args_array=("--chat-mode" "code")
    # Print array elements one per line
    printf "%s\n" "${args_array[@]}"
    return 0
}

# --- End Helper functions for launch_aider ---


# Constructs and executes the final aider command based on the selected mode and models.
# Includes a pre-launch confirmation step with options to launch, go back to format selection,
# or go back to the main menu.
#
# Args:
#   $1: mode - The operating mode ("code" or "architect").
#   $2: main_vendor - The selected main vendor.
#   $3: main_model - The selected main model.
#   $4: editor_vendor - The selected editor vendor (used only in architect mode, can be "default").
#   $5: editor_model - The selected editor model (used only in architect mode, can be "default").
#   $6: selected_format - The chosen edit format string (e.g., "whole", "editor-diff").
#
# Outputs:
#   - Prints status messages, the pre-launch menu, and the final command to stdout before execution.
#   - Executes the aider command if chosen.
#   - Prints error messages to stderr if aider is not found or if the command fails.
# Returns:
#   - 0: Aider launched and exited successfully.
#   - 1: User chose "Back to Main Menu" OR Aider command not found OR Aider failed OR config parsing failed.
#   - 2: User chose "Back to Edit Format Selection".
launch_aider() {
    local mode=$1
    local main_vendor=$2
    local main_model=$3
    local editor_vendor=$4
    local editor_model=$5
    local selected_format=$6 # New argument for the chosen format

    local main_api_key_var="${main_vendor}_API_KEY"
    local main_api_key="${!main_api_key_var}" # Get key value using indirect expansion
    local editor_api_key=""
    local editor_api_key_var=""

    # Base aider command parts in an array
    local cmd_array=("aider")



    # --- Add main model arguments ---
    local main_args_array=()
    while IFS= read -r arg; do
        main_args_array+=("$arg")
    done < <(_build_main_model_args "$main_vendor" "$main_model" "$main_api_key")
    if [ $? -ne 0 ]; then return 1; fi # Exit if helper failed
    # Append main model args to the command array
    cmd_array+=("${main_args_array[@]}")
    # --- End adding main model arguments ---


    # --- Add mode-specific arguments ---
    local mode_args_str
    local mode_args_array=()
    local mode_display_name=""
    local launch_title="" # Initialize launch title

    # Determine mode-specific args and title
    if [ "$mode" == "architect" ]; then
        mode_display_name="Architect Mode" # Keep for potential internal use
        launch_title="$TITLE_LAUNCH_ARCH"
        # Retrieve editor API key value ONLY if editor vendor is different and not default
        if [[ "$editor_vendor" != "$main_vendor" && "$editor_vendor" != "default" && -n "$editor_vendor" ]]; then
             editor_api_key_var="${editor_vendor}_API_KEY"
             editor_api_key="${!editor_api_key_var}" # Get key value using indirect expansion
        fi
        # Get architect-specific args (without edit format)
        mode_args_str=$(_build_architect_args "$editor_vendor" "$editor_model" "$editor_api_key" "$main_vendor")
        if [ $? -ne 0 ]; then return 1; fi # Exit if helper failed

        # Editor display info is handled directly in the menu display below
    else # Code mode
        mode_display_name="Code Mode" # Keep for potential internal use
        launch_title="$TITLE_LAUNCH_CODE"
        # Get code-specific args (without edit format)
        mode_args_str=$(_build_code_args)
        if [ $? -ne 0 ]; then return 1; fi # Exit if helper failed
        # No editor display info needed for code mode
    fi

    # Capture mode args using a while read loop and here-string
    local mode_args_array=()
    while IFS= read -r arg; do
        # Ensure we don't add empty strings if mode_args_str was empty or had blank lines
        [[ -n "$arg" ]] && mode_args_array+=("$arg")
    done <<< "$mode_args_str"
    cmd_array+=("${mode_args_array[@]}")
    # --- End adding mode-specific arguments ---


    # Check if aider command exists before entering the loop
    if ! command -v aider &> /dev/null; then
        echo -e "\nError: Aider command not found." >&2
        echo -e "Please ensure 'aider-chat' is installed and in your PATH." >&2
        read -p "Press Enter to return to the main menu..."
        return 1 # Indicate error/abort -> Back to Main Menu
    fi

    # Pre-launch confirmation loop
    while true; do
        # --- Build the full command array *including the selected format* ---
        local current_cmd_array=("${cmd_array[@]}") # Copy base + read + main + mode args
        # Add --edit-format only if the user selected an explicit format
        if [[ "$selected_format" != "default" && -n "$selected_format" ]]; then
            current_cmd_array+=("--edit-format" "$selected_format")
        fi

        # --- Display the pre-launch menu ---
        # clear # Disabled for debugging
        echo -e "\n$SEPARATOR_MAIN" # Add newline since clear is disabled
        echo "$launch_title" # Use pre-formatted title
        echo -e "$SEPARATOR_MAIN"

        # Display model info based on mode
        if [ "$mode" == "architect" ]; then
            echo -e "Architect Model: ${main_vendor}/${main_model}"
            if [[ "$editor_model" != "default" && -n "$editor_model" ]]; then
                echo -e "Editor Model:    ${editor_vendor}/${editor_model}"
            else
                echo -e "Editor Model:    Default"
            fi
        else # Code mode
            echo -e "Main Model:      ${main_vendor}/${main_model}"
        fi

        local display_format
        if [[ "$selected_format" == "default" || -z "$selected_format" ]]; then
            display_format="Default (Aider chooses)"
        else
            display_format="$selected_format"
        fi
        echo -e "Edit Format:     ${display_format}"
        echo -e "$SEPARATOR_SUB" # Use new separator length
        # Removed blank line before command title
        echo -e "AIDER LAUNCH COMMAND\n"
        # Print the command array elements, quoted for safety/clarity, and wrap
        # Use printf "%q " to quote and add spaces, then pipe to fold, then echo for newline
        printf "%q " "${current_cmd_array[@]}" | fold -s -w "$(tput cols)"
        echo # Add the necessary newline after fold
        echo -e "$SEPARATOR_SUB" # Use new separator length

        # --- Show .aider.conf.yml if it exists in $HOME ---
        if [[ -f "$HOME/.aider.conf.yml" ]]; then
            echo -e "Detected: \$HOME/.aider.conf.yml"
            echo -e "These additional settings will be applied by Aider:\n"
            cat "$HOME/.aider.conf.yml"
            echo -e "\n$SEPARATOR_SUB"
        fi

        echo "1. Launch Aider with this command (Default: Enter)" # Indicate Enter default
        echo "2. Back to Edit Format Selection"
        echo "0. Back to Main Menu (Mode Selection)"
        echo -e "$SEPARATOR_SUB" # Use new separator length
        echo -n "Enter choice [1=Launch, 2=Back to Format, 0=Back to Main, Enter=1]: " # Updated prompt
        read confirm_choice

        # --- Handle user choice ---
        case "${confirm_choice:-1}" in # Default to 1 if Enter is pressed
            1)  # Launch
                echo # Newline before execution
                # Execute the command directly using the array
                "${current_cmd_array[@]}"
                local exit_status=$?
                if [ $exit_status -ne 0 ]; then
                    echo "Error: aider command failed with exit status $exit_status." >&2
                    read -p "Press Enter to return to the main menu..."
                    return 1 # Indicate failure -> Back to Main Menu
                fi
                # Aider ran successfully
                return 0 # Indicate success -> Back to Main Menu
                ;;
            2)  # Back to Edit Format Selection
                return 2 # Return specific code for back to format
                ;;
            0)  # Back to Main Menu
                return 1 # Use 1 to indicate user aborted to main menu
                ;;
            *)  # Invalid choice
                echo "Invalid choice. Press Enter to try again..." >&2
                read
                # Loop continues
                ;;
        esac
    done
}

# The main entry point and control loop of the script.
# Handles mode selection and calls the appropriate mode-specific function.
#
# Args: None
#
# Outputs:
#   - Calls display_mode_selection_menu to show the mode selection UI.
#   - Reads user input for mode selection.
#   - Prints "Goodbye!" on exit.
#   - Prints error messages for unknown modes.
main() {
    # Argument parsing for help is handled at the very top of the script.
    # If we reach here, no help flag was provided.

    # Initialize configuration from JSON or fallback to defaults
    initialize_configuration
    
    # Load API keys
    load_api_keys

    # Loop indefinitely until user explicitly exits (choice 0)
    while true; do
        # Select mode first
        local selected_mode=""
        while true; do
            display_mode_selection_menu
            read mode_choice
            case "$mode_choice" in
                1) selected_mode="code"; break ;;
                2) selected_mode="architect"; break ;;
                ""|0) echo "Goodbye!"; exit 0 ;; # Treat Enter as 0
                *) echo "Invalid choice. Press Enter to continue..."; read ;;
            esac
        done

        # Variables to store selections are now local to the mode functions
        # local main_vendor=""
        # local main_model=""
        # local editor_vendor=""
        # local editor_model="" # Use "default" to signify default editor

        # Call the appropriate function based on selected mode
        if [ "$selected_mode" == "code" ]; then
            run_code_mode  # No arguments needed anymore
        elif [ "$selected_mode" == "architect" ]; then
            run_architect_mode # No arguments needed anymore
        else
            # This case should not be reachable due to the inner loop validation
            echo "Error: Unknown mode selected: $selected_mode" >&2
            exit 1
        fi

        # After run_code_mode or run_architect_mode returns (either after aider runs
        # or the user backs out), the main loop continues, showing the mode selection again.
        # Explicitly continue to ensure the loop restarts correctly.
        continue
    done
}
# Handles the user interaction flow for selecting the vendor and model for Code mode.
# It then calls launch_aider to execute the command.
# Returns control to the main loop after aider exits or if the user selects "Back".
#
# Args: None
#
# Outputs:
#   - Calls select_entity to display menus and get user input.
#   - Calls check_api_key to validate key presence.
#   - Calls launch_aider to run the final command.
#
# Modifies:
#   - Uses and potentially clears local variables main_vendor, main_model.
run_code_mode() {
    local main_vendor=""
    local main_model=""
    local selected_format="" # Variable to hold the chosen format
    local launch_status # Variable to hold launch_aider return status

    # Loop for Vendor Selection
    while true; do
        select_entity "vendor" "Code" # Sets SELECT_ENTITY_RESULT
        if [[ "$SELECT_ENTITY_RESULT" == "invalid" ]]; then
            continue # Re-prompt for vendor
        elif [[ -z "$SELECT_ENTITY_RESULT" ]]; then
            return # Back to main menu
        fi
        main_vendor="$SELECT_ENTITY_RESULT"
        check_api_key "$main_vendor" # Verify key
        break # Vendor selected, exit loop
    done

    # Loop for Model Selection
    while true; do
        select_entity "model" "Code" "$main_vendor" # Sets SELECT_ENTITY_RESULT
        if [[ "$SELECT_ENTITY_RESULT" == "invalid" ]]; then
            continue # Re-prompt for model
        elif [[ -z "$SELECT_ENTITY_RESULT" ]]; then
            # Back selected, need to re-select vendor
            # A simpler approach is just to return.
            return # Back to main menu (will require re-selecting vendor)
        fi
        main_model="$SELECT_ENTITY_RESULT"
        break # Model selected, exit loop
    done

    # Loop for Edit Format Selection and Launch Confirmation
    while true; do
        # Select Edit Format
        select_edit_format "code" # Sets SELECT_EDIT_FORMAT_RESULT
        if [[ "$SELECT_EDIT_FORMAT_RESULT" == "invalid" ]]; then
            continue # Re-prompt for format
        elif [[ -z "$SELECT_EDIT_FORMAT_RESULT" ]]; then
            # Back selected, need to re-select model
            # A simpler approach is just to return.
            return # Back to main menu (will require re-selecting model)
        fi
        selected_format="$SELECT_EDIT_FORMAT_RESULT"

        # Launch aider (which now includes the confirmation menu)
        launch_aider "code" "$main_vendor" "$main_model" "" "" "$selected_format"
        launch_status=$? # Capture return status

        # Check launch_status to decide next action
        if [[ "$launch_status" -eq 2 ]]; then
            # User chose "Back to Edit Format Selection" from launch_aider
            continue # Continue the format selection loop
        else
            # User launched (status 0), chose "Back to Main Menu" (status 1),
            # or an error occurred in launch_aider (status 1).
            # In all these cases, return to the main menu.
            return
        fi
    done
}
# Handles the user interaction flow for selecting the main vendor/model and
# editor vendor/model for Architect mode using a linear sequence with validation loops.
# It then calls launch_aider to execute the command.
# Returns control to the main loop after aider exits or if the user selects "Back".
#
# Args: None
#
# Outputs:
#   - Calls select_entity to display menus and get user input.
#   - Calls check_api_key to validate key presence.
#   - Calls launch_aider to run the final command.
#
# Modifies:
#   - Uses and potentially clears local variables main_vendor, main_model,
#     editor_vendor, editor_model.
run_architect_mode() {
    local main_vendor=""
    local main_model=""
    local editor_vendor=""
    local editor_model=""
    local selected_format="" # Variable to hold the chosen format
    local launch_status # Variable to hold launch_aider return status

    # Step 1: Select Main Vendor
    while true; do
        select_entity "vendor" "Architect" # Sets SELECT_ENTITY_RESULT
        if [[ "$SELECT_ENTITY_RESULT" == "invalid" ]]; then
            continue # Re-prompt for main vendor
        elif [[ -z "$SELECT_ENTITY_RESULT" ]]; then
            return # Back to main menu
        fi
        main_vendor="$SELECT_ENTITY_RESULT"
        check_api_key "$main_vendor" # Verify key is loaded
        break # Vendor selected, exit loop
    done

    # Step 2: Select Main Model
    while true; do
        select_entity "model" "Architect" "$main_vendor" # Sets SELECT_ENTITY_RESULT
        if [[ "$SELECT_ENTITY_RESULT" == "invalid" ]]; then
            continue # Re-prompt for main model
        elif [[ -z "$SELECT_ENTITY_RESULT" ]]; then
             # Back selected, return to main menu
            return
        fi
        main_model="$SELECT_ENTITY_RESULT"
        break # Model selected, exit loop
    done

    # Step 3: Select Editor Vendor
    while true; do
        select_entity "vendor" "Editor" # Sets SELECT_ENTITY_RESULT
        if [[ "$SELECT_ENTITY_RESULT" == "invalid" ]]; then
            continue # Re-prompt for editor vendor
        elif [[ -z "$SELECT_ENTITY_RESULT" ]]; then
            # Back selected, return to main menu
            return
        fi
        editor_vendor="$SELECT_ENTITY_RESULT"
        break # Vendor selected (or "default"), exit loop
    done

    # Step 4: Select Editor Model (or skip if default)
    if [[ "$editor_vendor" == "default" ]]; then
        editor_model="default" # Set model to default as well
    else
        # Specific editor vendor chosen, need to check key and select model
        check_api_key "$editor_vendor" # Verify key is loaded
        while true; do
            select_entity "model" "Editor" "$editor_vendor" # Sets SELECT_ENTITY_RESULT
            if [[ "$SELECT_ENTITY_RESULT" == "invalid" ]]; then
                continue # Re-prompt for editor model
            elif [[ -z "$SELECT_ENTITY_RESULT" ]]; then
                # Back selected, return to main menu
                return
            fi
            editor_model="$SELECT_ENTITY_RESULT"
            break # Model selected, exit loop
        done
    fi

    # Step 5: Loop for Edit Format Selection and Launch Confirmation
    while true; do
        # Select Edit Format
        select_edit_format "architect" # Sets SELECT_EDIT_FORMAT_RESULT
        if [[ "$SELECT_EDIT_FORMAT_RESULT" == "invalid" ]]; then
            continue # Re-prompt for format
        elif [[ -z "$SELECT_EDIT_FORMAT_RESULT" ]]; then
            # Back selected, return to main menu (as per plan)
            return
        fi
        selected_format="$SELECT_EDIT_FORMAT_RESULT"

        # Launch Aider
        launch_aider "architect" "$main_vendor" "$main_model" "$editor_vendor" "$editor_model" "$selected_format"
        launch_status=$? # Capture return status

        # Check launch_status to decide next action
        if [[ "$launch_status" -eq 2 ]]; then
            # User chose "Back to Edit Format Selection" from launch_aider
            continue # Continue the format selection loop
        else
            # User launched (status 0), chose "Back to Main Menu" (status 1),
            # or an error occurred in launch_aider (status 1).
            # In all these cases, return to the main menu.
            return
        fi
    done
}

# Run the main function
main

