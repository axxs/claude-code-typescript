#!/usr/bin/env bash
# smart-lint.sh - Intelligent project-aware code quality checks for Claude Code
#
# SYNOPSIS
#   smart-lint.sh [options]
#
# DESCRIPTION
#   Automatically detects project type and runs ALL quality checks.
#   Every issue found is blocking - code must be 100% clean to proceed.
#
# OPTIONS
#   --debug       Enable debug output
#   --fast        Skip slow checks (import cycles, security scans)
#
# EXIT CODES
#   0 - Success (all checks passed - everything is ✅ GREEN)
#   1 - General error (missing dependencies, etc.)
#   2 - ANY issues found - ALL must be fixed
#
# CONFIGURATION
#   Project-specific overrides can be placed in .claude-hooks-config.sh
#   See inline documentation for all available options.

# Don't use set -e - we need to control exit codes carefully
set +e

# ============================================================================
# COLOR DEFINITIONS AND UTILITIES
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Debug mode
CLAUDE_HOOKS_DEBUG="${CLAUDE_HOOKS_DEBUG:-0}"

# Logging functions
log_debug() {
    [[ "$CLAUDE_HOOKS_DEBUG" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $*" >&2
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*" >&2
}

# Performance timing
time_start() {
    if [[ "$CLAUDE_HOOKS_DEBUG" == "1" ]]; then
        echo $(($(date +%s%N)/1000000))
    fi
}

time_end() {
    if [[ "$CLAUDE_HOOKS_DEBUG" == "1" ]]; then
        local start=$1
        local end=$(($(date +%s%N)/1000000))
        local duration=$((end - start))
        log_debug "Execution time: ${duration}ms"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# ============================================================================
# PROJECT DETECTION
# ============================================================================

detect_project_type() {
    local project_type="unknown"
    local types=()
    
    # TypeScript project (priority over plain JS)
    if [[ -f "tsconfig.json" ]] || [[ -n "$(find . -maxdepth 3 -name "*.ts" -o -name "*.tsx" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("typescript")
    fi
    
    # Python project
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]] || [[ -n "$(find . -maxdepth 3 -name "*.py" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("python")
    fi
    
    # JavaScript/TypeScript project
    if [[ -f "package.json" ]] || [[ -f "tsconfig.json" ]] || [[ -n "$(find . -maxdepth 3 \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" \) -type f -print -quit 2>/dev/null)" ]]; then
        types+=("javascript")
    fi
    
    # Rust project
    if [[ -f "Cargo.toml" ]] || [[ -n "$(find . -maxdepth 3 -name "*.rs" -type f -print -quit 2>/dev/null)" ]]; then
        types+=("rust")
    fi
    
    # Nix project
    if [[ -f "flake.nix" ]] || [[ -f "default.nix" ]] || [[ -f "shell.nix" ]]; then
        types+=("nix")
    fi
    
    # Return primary type or "mixed" if multiple
    if [[ ${#types[@]} -eq 1 ]]; then
        project_type="${types[0]}"
    elif [[ ${#types[@]} -gt 1 ]]; then
        project_type="mixed:$(IFS=,; echo "${types[*]}")"
    fi
    
    log_debug "Detected project type: $project_type"
    echo "$project_type"
}

# Get list of modified files (if available from git)
get_modified_files() {
    if [[ -d .git ]] && command_exists git; then
        # Get files modified in the last commit or currently staged/modified
        git diff --name-only HEAD 2>/dev/null || true
        git diff --cached --name-only 2>/dev/null || true
    fi
}

# Check if we should skip a file
should_skip_file() {
    local file="$1"
    
    # Check .claude-hooks-ignore if it exists
    if [[ -f ".claude-hooks-ignore" ]]; then
        while IFS= read -r pattern; do
            # Skip comments and empty lines
            [[ -z "$pattern" || "$pattern" =~ ^[[:space:]]*# ]] && continue
            
            # Check if file matches pattern
            if [[ "$file" == $pattern ]]; then
                log_debug "Skipping $file due to .claude-hooks-ignore pattern: $pattern"
                return 0
            fi
        done < ".claude-hooks-ignore"
    fi
    
    # Check for inline skip comments
    if [[ -f "$file" ]] && head -n 5 "$file" 2>/dev/null | grep -q "claude-hooks-disable"; then
        log_debug "Skipping $file due to inline claude-hooks-disable comment"
        return 0
    fi
    
    return 1
}

# ============================================================================
# ERROR TRACKING
# ============================================================================

declare -a CLAUDE_HOOKS_SUMMARY=()
declare -i CLAUDE_HOOKS_ERROR_COUNT=0

add_error() {
    local message="$1"
    CLAUDE_HOOKS_ERROR_COUNT+=1
    CLAUDE_HOOKS_SUMMARY+=("${RED}❌${NC} $message")
}

print_summary() {
    if [[ $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
        # Only show failures when there are errors
        echo -e "\n${BLUE}═══ Summary ═══${NC}" >&2
        for item in "${CLAUDE_HOOKS_SUMMARY[@]}"; do
            echo -e "$item" >&2
        done
        
        echo -e "\n${RED}Found $CLAUDE_HOOKS_ERROR_COUNT issue(s) that MUST be fixed!${NC}" >&2
        echo -e "${RED}════════════════════════════════════════════${NC}" >&2
        echo -e "${RED}❌ ALL ISSUES ARE BLOCKING ❌${NC}" >&2
        echo -e "${RED}════════════════════════════════════════════${NC}" >&2
        echo -e "${RED}Fix EVERYTHING above until all checks are ✅ GREEN${NC}" >&2
    fi
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

load_config() {
    # Default configuration
    export CLAUDE_HOOKS_ENABLED="${CLAUDE_HOOKS_ENABLED:-true}"
    export CLAUDE_HOOKS_FAIL_FAST="${CLAUDE_HOOKS_FAIL_FAST:-false}"
    export CLAUDE_HOOKS_SHOW_TIMING="${CLAUDE_HOOKS_SHOW_TIMING:-false}"
    
    # Language enables
    export CLAUDE_HOOKS_TS_ENABLED="${CLAUDE_HOOKS_TS_ENABLED:-true}"
    export CLAUDE_HOOKS_PYTHON_ENABLED="${CLAUDE_HOOKS_PYTHON_ENABLED:-true}"
    export CLAUDE_HOOKS_JS_ENABLED="${CLAUDE_HOOKS_JS_ENABLED:-true}"
    export CLAUDE_HOOKS_RUST_ENABLED="${CLAUDE_HOOKS_RUST_ENABLED:-true}"
    export CLAUDE_HOOKS_NIX_ENABLED="${CLAUDE_HOOKS_NIX_ENABLED:-true}"
    
    # Project-specific overrides
    if [[ -f ".claude-hooks-config.sh" ]]; then
        source ".claude-hooks-config.sh" || {
            log_error "Failed to load .claude-hooks-config.sh"
            exit 2
        }
    fi
    
    # Quick exit if hooks are disabled
    if [[ "$CLAUDE_HOOKS_ENABLED" != "true" ]]; then
        log_info "Claude hooks are disabled"
        exit 0
    fi
}

# ============================================================================
# TYPESCRIPT LINTING
# ============================================================================

lint_typescript() {
    if [[ "${CLAUDE_HOOKS_TS_ENABLED:-true}" != "true" ]]; then
        log_debug "TypeScript linting disabled"
        return 0
    fi
    
    log_info "Running TypeScript formatting and linting..."
    
    # Check if package.json exists with lint and format scripts
    if [[ -f "package.json" ]]; then
        local has_format=$(grep -E '"format":|"prettier":' package.json 2>/dev/null || echo "")
        local has_lint=$(grep -E '"lint":' package.json 2>/dev/null || echo "")
        local has_typecheck=$(grep -E '"type-check":|"typecheck":' package.json 2>/dev/null || echo "")
        
        if [[ -n "$has_format" || -n "$has_lint" ]]; then
            log_info "Using npm scripts"
            
            # Format check
            if [[ -n "$has_format" ]]; then
                local fmt_output
                if ! fmt_output=$(npm run format 2>&1); then
                    add_error "TypeScript formatting failed (npm run format)"
                    echo "$fmt_output" >&2
                fi
            fi
            
            # Linting
            if [[ -n "$has_lint" ]]; then
                local lint_output
                if ! lint_output=$(npm run lint 2>&1); then
                    add_error "TypeScript linting failed (npm run lint)"
                    echo "$lint_output" >&2
                fi
            fi
            
            # Type checking
            if [[ -n "$has_typecheck" ]]; then
                local typecheck_output
                if ! typecheck_output=$(npm run type-check 2>&1 || npm run typecheck 2>&1); then
                    add_error "TypeScript type checking failed"
                    echo "$typecheck_output" >&2
                fi
            fi
        else
            # Fallback to direct commands
            log_info "Using direct TypeScript/JavaScript tools"
            lint_javascript_direct
        fi
    else
        # No package.json, try direct tools
        log_info "No package.json found, using direct tools"
        lint_javascript_direct
    fi
}

lint_javascript_direct() {
    # Prettier formatting
    if command_exists prettier; then
        local prettier_output
        if ! prettier_output=$(prettier --check . 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(prettier --write . 2>&1); then
                add_error "Prettier formatting failed"
                echo "$format_output" >&2
            fi
        fi
    elif command_exists npx; then
        local prettier_output
        if ! prettier_output=$(npx prettier --check . 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(npx prettier --write . 2>&1); then
                add_error "Prettier formatting failed"
                echo "$format_output" >&2
            fi
        fi
    fi
    
    # ESLint
    if command_exists eslint; then
        local eslint_output
        if ! eslint_output=$(eslint . --ext .js,.jsx,.ts,.tsx 2>&1); then
            add_error "ESLint found issues"
            echo "$eslint_output" >&2
        fi
    elif command_exists npx && [[ -f ".eslintrc" || -f ".eslintrc.js" || -f ".eslintrc.json" || -f "eslint.config.js" ]]; then
        local eslint_output
        if ! eslint_output=$(npx eslint . --ext .js,.jsx,.ts,.tsx 2>&1); then
            add_error "ESLint found issues"
            echo "$eslint_output" >&2
        fi
    fi
    
    # TypeScript compiler
    if command_exists tsc && [[ -f "tsconfig.json" ]]; then
        local tsc_output
        if ! tsc_output=$(tsc --noEmit 2>&1); then
            add_error "TypeScript compilation errors"
            echo "$tsc_output" >&2
        fi
    elif command_exists npx && [[ -f "tsconfig.json" ]]; then
        local tsc_output
        if ! tsc_output=$(npx tsc --noEmit 2>&1); then
            add_error "TypeScript compilation errors"
            echo "$tsc_output" >&2
        fi
    fi
}

# ============================================================================
# OTHER LANGUAGE LINTERS
# ============================================================================

lint_python() {
    if [[ "${CLAUDE_HOOKS_PYTHON_ENABLED:-true}" != "true" ]]; then
        log_debug "Python linting disabled"
        return 0
    fi
    
    log_info "Running Python linters..."
    
    # Black formatting
    if command_exists black; then
        local black_output
        if ! black_output=$(black . --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(black . 2>&1); then
                add_error "Python formatting failed"
                echo "$format_output" >&2
            fi
        fi
    fi
    
    # Linting
    if command_exists ruff; then
        local ruff_output
        if ! ruff_output=$(ruff check --fix . 2>&1); then
            add_error "Ruff found issues"
            echo "$ruff_output" >&2
        fi
    elif command_exists flake8; then
        local flake8_output
        if ! flake8_output=$(flake8 . 2>&1); then
            add_error "Flake8 found issues"
            echo "$flake8_output" >&2
        fi
    fi
    
    return 0
}

lint_javascript() {
    if [[ "${CLAUDE_HOOKS_JS_ENABLED:-true}" != "true" ]]; then
        log_debug "JavaScript linting disabled"
        return 0
    fi
    
    # For plain JavaScript projects without TypeScript
    # TypeScript projects are handled by lint_typescript()
    log_info "Running JavaScript linters..."
    lint_javascript_direct
    
    return 0
}

lint_rust() {
    if [[ "${CLAUDE_HOOKS_RUST_ENABLED:-true}" != "true" ]]; then
        log_debug "Rust linting disabled"
        return 0
    fi
    
    log_info "Running Rust linters..."
    
    if command_exists cargo; then
        local fmt_output
        if ! fmt_output=$(cargo fmt -- --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(cargo fmt 2>&1); then
                add_error "Rust formatting failed"
                echo "$format_output" >&2
            fi
        fi
        
        local clippy_output
        if ! clippy_output=$(cargo clippy --quiet -- -D warnings 2>&1); then
            add_error "Clippy found issues"
            echo "$clippy_output" >&2
        fi
    else
        log_info "Cargo not found, skipping Rust checks"
    fi
    
    return 0
}

lint_nix() {
    if [[ "${CLAUDE_HOOKS_NIX_ENABLED:-true}" != "true" ]]; then
        log_debug "Nix linting disabled"
        return 0
    fi
    
    log_info "Running Nix linters..."
    
    # Find all .nix files
    local nix_files=$(find . -name "*.nix" -type f | grep -v -E "(result/|/nix/store/)" | head -20)
    
    if [[ -z "$nix_files" ]]; then
        log_debug "No Nix files found"
        return 0
    fi
    
    # Check formatting with nixpkgs-fmt or alejandra
    if command_exists nixpkgs-fmt; then
        local fmt_output
        if ! fmt_output=$(echo "$nix_files" | xargs nixpkgs-fmt --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(echo "$nix_files" | xargs nixpkgs-fmt 2>&1); then
                add_error "Nix formatting failed"
                echo "$format_output" >&2
            fi
        fi
    elif command_exists alejandra; then
        local fmt_output
        if ! fmt_output=$(echo "$nix_files" | xargs alejandra --check 2>&1); then
            # Apply formatting and capture any errors
            local format_output
            if ! format_output=$(echo "$nix_files" | xargs alejandra 2>&1); then
                add_error "Nix formatting failed"
                echo "$format_output" >&2
            fi
        fi
    fi
    
    # Static analysis with statix
    if command_exists statix; then
        local statix_output
        if ! statix_output=$(statix check 2>&1); then
            add_error "Statix found issues"
            echo "$statix_output" >&2
        fi
    fi
    
    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Parse command line options
FAST_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            export CLAUDE_HOOKS_DEBUG=1
            shift
            ;;
        --fast)
            FAST_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

# Print header
echo "" >&2
echo "🔍 Style Check - Validating code formatting..." >&2
echo "────────────────────────────────────────────" >&2

# Load configuration
load_config

# Start timing
START_TIME=$(time_start)

# Detect project type
PROJECT_TYPE=$(detect_project_type)
log_info "Project type: $PROJECT_TYPE"

# Main execution
main() {
    # Handle mixed project types
    if [[ "$PROJECT_TYPE" == mixed:* ]]; then
        local types="${PROJECT_TYPE#mixed:}"
        IFS=',' read -ra TYPE_ARRAY <<< "$types"
        
        for type in "${TYPE_ARRAY[@]}"; do
            case "$type" in
                "typescript") lint_typescript ;;
                "javascript") lint_javascript ;;
                "python") lint_python ;;
                "rust") lint_rust ;;
                "nix") lint_nix ;;
            esac
            
            # Fail fast if configured
            if [[ "$CLAUDE_HOOKS_FAIL_FAST" == "true" && $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
                break
            fi
        done
    else
        # Single project type
        case "$PROJECT_TYPE" in
            "typescript") lint_typescript ;;
            "javascript") lint_javascript ;;
            "python") lint_python ;;
            "rust") lint_rust ;;
            "nix") lint_nix ;;
            "unknown") 
                log_info "No recognized project type, skipping checks"
                ;;
        esac
    fi
    
    # Show timing if enabled
    time_end "$START_TIME"
    
    # Print summary
    print_summary
    
    # Return exit code - any issues mean failure
    if [[ $CLAUDE_HOOKS_ERROR_COUNT -gt 0 ]]; then
        return 2
    else
        return 0
    fi
}

# Run main function
main
exit_code=$?

# Final message and exit
if [[ $exit_code -eq 2 ]]; then
    echo -e "\n${RED}🛑 FAILED - Fix all issues above! 🛑${NC}" >&2
    echo -e "${YELLOW}📋 NEXT STEPS:${NC}" >&2
    echo -e "${YELLOW}  1. Fix the issues listed above${NC}" >&2
    echo -e "${YELLOW}  2. Verify the fix by running the lint command again${NC}" >&2
    echo -e "${YELLOW}  3. Continue with your original task${NC}" >&2
    exit 2
else
    # Always exit with 2 so Claude sees the continuation message
    echo -e "\n${YELLOW}👉 Style clean. Continue with your task.${NC}" >&2
    exit 2
fi