# Plan for Implementing JSON Configuration in run-aider.sh

## Overview
Currently, `run-aider.sh` has hardcoded arrays for vendors, models, and edit formats. We need to modify it to read these configurations from the `aider_config.json` file that has already been created.

## Step-by-Step Implementation Plan

### Phase 1: JSON Parsing and Configuration Loading
1. Add a function to check if `jq` is installed (required for JSON parsing in bash)
2. Create a function to load and parse the JSON configuration file
3. Replace hardcoded arrays with dynamic loading from JSON
4. Add error handling for missing or malformed JSON

### Phase 2: Refactor Model and Vendor Selection
5. Update the vendor selection logic to use the dynamically loaded vendors
6. Update the model selection logic to use the dynamically loaded models for each vendor
7. Update the edit format selection to use formats from JSON

### Phase 3: Error Handling and Fallbacks
8. Add fallback to hardcoded defaults if JSON file is missing or invalid
9. Add validation to ensure required configuration elements exist
10. Add helpful error messages for configuration issues

### Phase 4: Testing and Documentation
11. Test all paths through the application with various configurations
12. Update documentation to reflect the new JSON-based configuration
13. Add examples of how to modify the JSON configuration

## Implementation Details

For each step, we'll need to:
1. Identify the specific sections of code to modify
2. Create the new functions or modify existing ones
3. Test each change incrementally
4. Ensure backward compatibility where possible

The JSON structure is already defined in `aider_config.json` with:
- A list of vendors
- A nested object of models by vendor
- A nested object of edit formats by mode

We'll need to parse this structure and use it throughout the script.
