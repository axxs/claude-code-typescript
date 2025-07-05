# Claude Code TypeScript Framework

A comprehensive framework for using Claude Code with TypeScript projects, providing automated code quality checks, structured workflows, and TypeScript-specific best practices.

## Quick Start

### Installation

1. **Copy the framework files to your project:**
   ```bash
   # Clone this repository
   git clone https://github.com/axxs/claude-code-typescript.git
   
   # Copy the essential files to your project
   cp claude-code-typescript/CLAUDE.md ./CLAUDE.md
   cp -r claude-code-typescript/commands ./.claude/commands
   cp claude-code-typescript/settings.json ./.claude/settings.json
   
   # Optional: Copy hooks for automated checks
   cp -r claude-code-typescript/hooks/* ~/.claude/hooks/
   ```

2. **For new TypeScript projects:**
   ```bash
   # Initialize a new TypeScript project
   npm init -y
   npm install --save-dev typescript eslint prettier @types/node
   npx tsc --init
   npx eslint --init
   
   # Add the Claude framework
   cp path/to/framework/CLAUDE.md ./CLAUDE.md
   ```

3. **For existing TypeScript projects:**
   ```bash
   # Just copy the CLAUDE.md to your project root
   cp path/to/framework/CLAUDE.md ./CLAUDE.md
   
   # Ensure you have the required npm scripts in package.json:
   # "scripts": {
   #   "lint": "eslint . --ext .ts,.tsx,.js,.jsx",
   #   "format": "prettier --write .",
   #   "type-check": "tsc --noEmit",
   #   "test": "jest"
   # }
   ```

## Core Components

### CLAUDE.md
The main instruction file that tells Claude Code how to work with your TypeScript project. Place this in your project root. It enforces:
- No `any` types
- Proper async/await usage
- Comprehensive error handling
- Clean code practices
- Test-driven development

### Slash Commands

Located in `.claude/commands/`, these provide structured workflows:

- **`/check`** - Comprehensive code quality validation
  ```
  # Usage in Claude Code:
  /check
  
  # This will:
  # - Run all linters (ESLint, Prettier, TypeScript compiler)
  # - Execute all tests
  # - Fix any issues found (not just report them)
  # - Keep working until everything passes
  ```

- **`/next <task>`** - Production-quality implementation
  ```
  # Usage:
  /next implement user authentication with JWT
  
  # This enforces:
  # - Research → Plan → Implement workflow
  # - No shortcuts or "good enough" code
  # - All linters must pass before completion
  # - Comprehensive testing
  ```

- **`/prompt <question>`** - Get detailed assistance
  ```
  # Usage:
  /prompt how should I structure my Redux store?
  ```

### Hooks (Optional but Recommended)

The `smart-lint.sh` hook automatically runs after Claude Code modifies files:

1. **Install hooks globally:**
   ```bash
   mkdir -p ~/.claude/hooks
   cp hooks/smart-lint.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/smart-lint.sh
   ```

2. **Configure for your project** (optional):
   ```bash
   # Create project-specific config
   cp hooks/example-claude-hooks-config.sh .claude-hooks-config.sh
   
   # Edit to customize:
   # - Disable specific linters
   # - Set project-specific rules
   # - Configure performance options
   ```

3. **Exclude files from checks:**
   ```bash
   # Create ignore file
   cp hooks/example-claude-hooks-ignore .claude-hooks-ignore
   
   # Add patterns for files to skip:
   # node_modules/**
   # dist/**
   # *.generated.ts
   ```

## Workflow Examples

### Starting a New Feature
```bash
# 1. Tell Claude Code about the task
"Implement a user authentication system with JWT tokens"

# 2. Claude will automatically:
# - Research the codebase
# - Create a plan
# - Implement with proper TypeScript types
# - Ensure all linters pass
# - Write tests
```

### Checking Code Quality
```bash
# Run comprehensive checks
/check

# Claude will:
# - Run ESLint, Prettier, and TypeScript compiler
# - Fix all issues automatically
# - Run tests and fix failures
# - Continue until everything is green
```

### Working with Hooks

When hooks are installed, they'll automatically run after file changes:

```
> Edit operation feedback:
  - [~/.claude/hooks/smart-lint.sh]:
  🔍 Style Check - Validating code formatting...
  ────────────────────────────────────────────
  [INFO] Project type: typescript
  [INFO] Running TypeScript formatting and linting...
  [INFO] Using npm scripts
  
  👉 Style clean. Continue with your task.
```

If issues are found, Claude Code will automatically fix them before continuing.

## Best Practices

1. **Always have CLAUDE.md in your project root** - This ensures consistent behavior

2. **Set up npm scripts** in your package.json:
   ```json
   {
     "scripts": {
       "lint": "eslint . --ext .ts,.tsx,.js,.jsx",
       "format": "prettier --write .",
       "type-check": "tsc --noEmit",
       "test": "jest",
       "test:watch": "jest --watch"
     }
   }
   ```

3. **Use TypeScript strict mode** in tsconfig.json:
   ```json
   {
     "compilerOptions": {
       "strict": true,
       "noImplicitAny": true,
       "strictNullChecks": true
     }
   }
   ```

4. **Configure ESLint** for TypeScript:
   ```bash
   npm install --save-dev @typescript-eslint/parser @typescript-eslint/eslint-plugin
   ```

## Customization

### Project-Specific Instructions
Add project-specific rules to your CLAUDE.md:
```markdown
## Project-Specific Rules

- Use React functional components only
- Follow our API naming convention: `useXxxApi` for hooks
- All API calls must use the `apiClient` service
```

### Disable Checks Temporarily
```bash
# In .claude-hooks-config.sh
export CLAUDE_HOOKS_TS_ENABLED=false  # Disable TypeScript checks
export CLAUDE_HOOKS_ENABLED=false      # Disable all hooks
```

### Custom Ignore Patterns
```bash
# In .claude-hooks-ignore
*.test.ts      # Skip test files
*.config.ts    # Skip config files
src/legacy/**  # Skip legacy code
```

## Troubleshooting

### Hooks Not Running
1. Ensure hooks are executable: `chmod +x ~/.claude/hooks/*.sh`
2. Check Claude Code settings: The hooks directory should be `~/.claude/hooks/`
3. Verify no syntax errors: `bash -n ~/.claude/hooks/smart-lint.sh`

### Linting Errors
1. Ensure all dev dependencies are installed: `npm install`
2. Check that npm scripts exist in package.json
3. Run linters manually to debug: `npm run lint`

### TypeScript Errors
1. Ensure tsconfig.json exists: `npx tsc --init`
2. Install TypeScript types: `npm install --save-dev @types/node`
3. Check for missing type definitions

## Advanced Usage

### Multi-Agent Workflows
Claude Code can spawn multiple agents for complex tasks:
```
"Refactor the entire authentication system to use OAuth2"

# Claude will:
# - Spawn agents to research different parts
# - Parallelize implementation work
# - Coordinate testing efforts
```

### Ultrathink Mode
For complex architectural decisions:
```
"I need to ultrathink about the best state management solution for this app"
```

## Contributing

To contribute to this framework:
1. Fork the repository
2. Make your changes
3. Ensure all files follow the established patterns
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details