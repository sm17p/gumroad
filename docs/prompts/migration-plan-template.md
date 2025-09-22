# General Tailwind CSS Migration Plan Template

## Overview

This is a template for migrating any SCSS file to Tailwind CSS using **Playwright visual regression testing** for automated before/after comparison. Follow the guidelines in [@tailwindcss.md](./prompts/tailwindcss.md) and use this plan structure for systematic migration with comprehensive visual testing.

## Migration Strategy

1. **Identify Affected Code Paths** - Analyze SCSS and React components
2. **Create Playwright Visual Tests** - Set up snapshot testing for all affected UI states
3. **Generate Baseline Snapshots** - Run tests to create "before" snapshots
4. **Perform Migration** - Convert SCSS to Tailwind incrementally
5. **Verify Visual Consistency** - Run tests to ensure no visual regressions

## Prerequisites

> **⚠️ HUMAN ACTION REQUIRED** - This is the only step that requires human intervention. All other steps in this plan are automated and executed by coding agents.

### Playwright Setup

**Manual Step:** Ensure Playwright is installed and configured:

```bash
# Install Playwright (if not already done)
npm install --save-dev @playwright/test

# Install Chromium browser (headed mode only)
npx playwright install chromium --with-deps

# Remove headless shell (we only want headed mode)
rm -rf ~/Library/Caches/ms-playwright/chromium_headless_shell-*
```

**Verification:** The coding agent will automatically run Playwright tests to create baseline snapshots and verify the migration.

## Phase 1: Code Analysis & Test Setup

> **🤖 AUTOMATED** - This phase is executed entirely by the coding agent.

### Step 1.1: Identify Affected Code Paths

**Analysis Commands:**

```bash
# Read and analyze the SCSS file
read_file --target_file "app/javascript/stylesheets/[SCSS_FILE]"

# Read and analyze the React component
read_file --target_file "app/javascript/components/[COMPONENT_FILE]"

# Search for usage of SCSS class
grep --pattern "[SCSS_CLASS_NAME]" --path "app/javascript" --output_mode "files_with_matches"
```

**Expected Output:**

- SCSS file with component styles, responsive behavior, and theme variations
- React component using SCSS classes
- List of files that reference the SCSS classes

### Step 1.2: Create Playwright Visual Tests Using MCP

**Use Playwright MCP for Interactive Test Setup:**

**Advantages of using Playwright MCP:**

- Real-time locator discovery with `browser_snapshot`
- Correct form field names and button text via `getByRole`
- Step-by-step verification of each interaction
- Better error handling and debugging

**MCP Test Setup Process:**

```bash
# 1. Navigate to login page and discover elements
mcp_playwright_browser_navigate --url "https://gumroad.dev/login"
mcp_playwright_browser_snapshot

# 2. Fill login form with discovered locators
mcp_playwright_browser_fill_form --fields '[{"name": "Email", "ref": "e28", "type": "textbox", "value": "seller@gumroad.com"}]'
mcp_playwright_browser_fill_form --fields '[{"name": "Password", "ref": "e34", "type": "textbox", "value": "password"}]'
mcp_playwright_browser_click --element "Login button" --ref "e39"

# 3. Navigate through app flow step by step
mcp_playwright_browser_click --element "Products link" --ref "e11"
mcp_playwright_browser_snapshot

# 4. Create test data and reach target component
mcp_playwright_browser_click --element "New product link" --ref "e280"
# ... continue until reaching target component

# 5. Verify target elements exist
mcp_playwright_browser_evaluate --function "() => document.querySelector('.target-class')"
```

**Test Creation Commands:**

```bash
# Create comprehensive visual test suite with discovered locators
write --file_path "tests/[COMPONENT_NAME].spec.ts" --contents "[Test suite with correct MCP-discovered locators]"
```

**Test Coverage:**

- Desktop light/dark mode (uses existing `desktop-light` and `desktop-dark` projects)
- Mobile light/dark mode (uses existing `mobile-light` and `mobile-dark` projects)
- Component states (empty, with content, loading, interactive states)
- Responsive behavior verification

**Authentication Setup:**

Create reusable authentication state to avoid logging in for every test:

```bash
# Create auth setup file
write --file_path "tests/auth.setup.ts" --contents "
import { test as setup, expect } from '@playwright/test';

const authFile = 'playwright/.auth/seller.json';

setup('authenticate as seller', async ({ page }) => {
  await page.goto('/login');
  await page.getByRole('textbox', { name: 'Email' }).fill('seller@gumroad.com');
  await page.getByRole('textbox', { name: 'Password' }).fill('password');
  await page.getByRole('button', { name: 'Login' }).click();
  await page.waitForURL('/dashboard');
  await expect(page.getByText('Seller')).toBeVisible();
  await page.context().storageState({ path: authFile });
});
"

# Update playwright.config.ts to include auth setup
search_replace --file_path "playwright.config.ts" --old_string "projects: [" --new_string "projects: [
    { name: 'setup', testMatch: /.*\.setup\.ts/ },
    { name: 'desktop-light', use: { ...devices['Desktop Chrome'], viewport: { width: 1710, height: 1112 }, colorScheme: 'light', storageState: 'playwright/.auth/seller.json' }, dependencies: ['setup'] },
    { name: 'desktop-dark', use: { ...devices['Desktop Chrome'], viewport: { width: 1710, height: 1112 }, colorScheme: 'dark', storageState: 'playwright/.auth/seller.json' }, dependencies: ['setup'] },
    { name: 'mobile-light', use: { ...devices['Pixel 7'], colorScheme: 'light', storageState: 'playwright/.auth/seller.json' }, dependencies: ['setup'] },
    { name: 'mobile-dark', use: { ...devices['Pixel 7'], colorScheme: 'dark', storageState: 'playwright/.auth/seller.json' }, dependencies: ['setup'] },
"
```

**Benefits of Auth State:**

- **Faster Tests**: No login step in each test
- **More Reliable**: Authentication happens once in setup
- **Better Performance**: Reuses session across all test projects
- **Cleaner Tests**: Focus on component behavior, not authentication

**MCP Workflow Benefits:**

1. **Accurate Locators**: No guessing about form field names or button text
2. **Real-time Verification**: See exactly what elements are available
3. **Step-by-step Testing**: Verify each interaction works before proceeding
4. **Better Error Handling**: See what actually fails and why
5. **Faster Development**: Interactive discovery vs. trial-and-error coding

**MCP Debugging Techniques:**

When Playwright tests get stuck (e.g., on `about:blank`), use MCP tools to debug:

```bash
# 1. Check current page state
mcp_playwright_browser_snapshot

# 2. Check console messages for errors
mcp_playwright_browser_console_messages

# 3. Check network requests
mcp_playwright_browser_network_requests

# 4. Evaluate page state programmatically
mcp_playwright_browser_evaluate --function "() => ({ url: window.location.href, readyState: document.readyState, title: document.title })"

# 5. Check authentication state
mcp_playwright_browser_evaluate --function "() => localStorage.getItem('auth_token') || 'No auth token found'"

# 6. Force navigation if stuck
mcp_playwright_browser_navigate --url "https://gumroad.dev/dashboard"
```

**Common Issues & Solutions:**

- **`about:blank`**: Usually navigation timeout or auth issues - try re-navigating
- **Element not found**: Use `browser_snapshot` to see actual available elements
- **Authentication failures**: Check if auth state is properly loaded
- **JavaScript errors**: Check console messages for compilation errors

### Step 1.3: Generate Baseline Snapshots

**Test Execution:**

```bash
# Run Playwright tests using existing config projects
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=desktop-light"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=desktop-dark"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=mobile-light"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=mobile-dark"

# Verify snapshots were created in tests/[COMPONENT_NAME].spec.ts-snapshots/
# Playwright automatically adds project name and platform (e.g., -desktop-light-darwin.png)
```

list_dir --target_directory "tests"

````

**Expected Output:**

- Baseline snapshots for all UI states (desktop/mobile, light/dark)
- Test results showing all tests passed
- Snapshot files in `tests/[COMPONENT_NAME].spec.ts-snapshots/`

### Step 1.4: Verify Current State

**Verification Commands:**

```bash
# Check for console errors
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=chromium --reporter=line"

# Check for linting errors
read_lints --paths "app/javascript/components/[COMPONENT_FILE]" "app/javascript/stylesheets/[SCSS_FILE]"
````

**Expected Output:**

- All Playwright tests pass
- No console errors
- No linting errors
- Baseline snapshots created successfully

## Phase 2: Incremental Migration

> **🤖 AUTOMATED** - This phase is executed entirely by the coding agent.

### Step 2.1: Convert Primary Styles

**Migration Commands:**

```bash
# Convert SCSS styles to Tailwind classes
search_replace --file_path "app/javascript/components/[COMPONENT_FILE]" --old_string "[OLD_JSX]" --new_string "[NEW_JSX_WITH_TAILWIND]"

# Remove corresponding SCSS styles
search_replace --file_path "app/javascript/stylesheets/[SCSS_FILE]" --old_string "[SCSS_RULES_TO_REMOVE]" --new_string ""
```

**Verification:**

```bash
# Run Playwright tests on all projects to verify no visual regression
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=desktop-light"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=desktop-dark"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=mobile-light"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=mobile-dark"

# Check for linting errors
read_lints --paths "app/javascript/components/[COMPONENT_FILE]"
```

**Expected Output:**

- All tests pass (no visual changes)
- No linting errors
- Component styling preserved with Tailwind classes

### Step 2.2: Convert Secondary Styles

**Migration Commands:**

```bash
# Convert additional SCSS styles to Tailwind classes
search_replace --file_path "app/javascript/components/[COMPONENT_FILE]" --old_string "[OLD_JSX_2]" --new_string "[NEW_JSX_WITH_TAILWIND_2]"

# Remove corresponding SCSS styles
search_replace --file_path "app/javascript/stylesheets/[SCSS_FILE]" --old_string "[SCSS_RULES_TO_REMOVE_2]" --new_string ""
```

**Verification:**

```bash
# Run Playwright tests on all projects to verify no visual regression
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=desktop-light"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=desktop-dark"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=mobile-light"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=mobile-dark"

# Check for linting errors
read_lints --paths "app/javascript/components/[COMPONENT_FILE]"
```

**Expected Output:**

- All tests pass (no visual changes)
- No linting errors
- Additional styling preserved with Tailwind classes

### Step 2.3: Clean Up SCSS File

**Migration Commands:**

```bash
# Remove empty SCSS file if all styles migrated
delete_file --target_file "app/javascript/stylesheets/[SCSS_FILE]"

# Or remove empty rules if file still has content
search_replace --file_path "app/javascript/stylesheets/[SCSS_FILE]" --old_string "[SCSS_CLASS_NAME] {\n  \n}" --new_string ""
```

**Verification:**

```bash
# Run Playwright tests on all projects to verify no visual regression
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=desktop-light"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=desktop-dark"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=mobile-light"
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=mobile-dark"

# Check for linting errors
read_lints --paths "app/javascript/components/[COMPONENT_FILE]"
```

**Expected Output:**

- All tests pass (no visual changes)
- No linting errors
- SCSS file cleaned up or removed

## Phase 3: Final Verification

> **🤖 AUTOMATED** - This phase is executed entirely by the coding agent.

### Step 3.1: Comprehensive Test Suite

**Test Execution:**

```bash
# Run all Playwright tests to verify migration success
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=chromium"

# Run tests on mobile Chrome as well
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project='Mobile Chrome'"
```

**Expected Output:**

- All tests pass on both desktop and mobile
- No visual regressions detected
- Migration completed successfully

### Step 3.2: Final Cleanup

**Cleanup Commands:**

```bash
# Check for any remaining linting errors
read_lints --paths "app/javascript/components/[COMPONENT_FILE]"

# Verify no console errors
run_terminal_cmd --command "npx playwright test tests/[COMPONENT_NAME].spec.ts --project=chromium --reporter=line"
```

**Expected Output:**

- No linting errors
- No console errors
- Clean, maintainable Tailwind code

## Common Knowledge & Best Practices

### Desktop Viewport Configuration

**Mac-Optimized Viewport Sizes:**

- **MacBook Pro**: 1440x900 (13"), 1680x1050 (15"), 2560x1600 (16")
- **iMac**: 1920x1080 (21"), 2560x1440 (27"), 5120x2880 (27" Retina)
- **Mac Studio Display**: 2560x1440 or 5120x2880
- **Custom Mac Setup**: 1710x1112 (user's actual viewport)

**Recommended Desktop Viewport:** Use the user's actual viewport size for most accurate testing

### Light/Dark Mode Testing

**Playwright Color Scheme Emulation:**

```javascript
// Test light mode
await page.emulateMedia({ colorScheme: "light" });

// Test dark mode
await page.emulateMedia({ colorScheme: "dark" });
```

**Manual Theme Toggle (Fallback):**

```javascript
// For sites that use CSS classes for theme switching
await page.evaluate(() => {
  document.documentElement.classList.toggle("dark");
});
```

### Mobile Testing Configuration

**Pixel 8 Pro Specifications:**

- **Viewport**: 375x667
- **Device Pixel Ratio**: 3.0
- **User Agent**: Chrome Mobile

### Visual Testing Best Practices

1. **Snapshot Naming Convention:**

   - `[COMPONENT]-[VIEWPORT]-[THEME].png`
   - Examples: `menubar-desktop-light.png`, `menubar-mobile-dark.png`

2. **Test Coverage:**

   - Desktop light/dark mode
   - Mobile light/dark mode
   - Interactive states (hover, focus, active)
   - Responsive breakpoints
   - Component variations

3. **Visual Regression Detection:**

   - Use `expect(page).toHaveScreenshot()` for automatic comparison
   - Set appropriate threshold for minor differences
   - Test both full page and component-specific snapshots

4. **Accepting Visual Changes:**

   ```bash
   # Create initial baseline snapshots
   npx playwright test tests/[COMPONENT].spec.ts --project=chromium --update-snapshots

   # Accept new visual changes after migration
   npx playwright test tests/[COMPONENT].spec.ts --project=chromium --update-snapshots

   # Regular test run (compares against baselines)
   npx playwright test tests/[COMPONENT].spec.ts --project=chromium
   ```

5. **Test Execution Modes:**
   - **Serial execution** (`fullyParallel: false`) - Tests run one after another for easier verification
   - **Single worker** (`workers: 1`) - Prevents resource conflicts during visual testing
   - **Headed mode** (`headless: false`) - Allows visual verification during test runs

## Usage Instructions

### Human Workflow (Minimal)

1. **Install Playwright** (only manual step):

   ```bash
   npm install --save-dev @playwright/test
   npx playwright install chromium --with-deps
   ```

2. **Provide the migration plan** to a coding agent with placeholders filled in

3. **Monitor progress** as the agent executes the automated phases

### Coding Agent Workflow (Automated)

1. **Copy this template** to a new file: `docs/migration-plans/[COMPONENT_NAME]-migration.md`

2. **Replace placeholders** with actual values:

   - `[SCSS_FILE]` → Path to the SCSS file being migrated
   - `[COMPONENT_FILE]` → Path to the React component file
   - `[COMPONENT_NAME]` → Name of the component (e.g., "nested-menu")
   - `[SCSS_CLASS_NAME]` → Name of the SCSS class being migrated

3. **Follow the guidelines** in [@tailwindcss.md](./prompts/tailwindcss.md)

4. **Execute all phases automatically**:
   - Phase 1: Analyze code and create Playwright tests
   - Phase 2: Perform incremental migration with verification
   - Phase 3: Final verification and cleanup

### Verification Checklist

- [ ] All Playwright tests pass before migration
- [ ] Baseline snapshots created successfully
- [ ] SCSS file analyzed and migration strategy planned
- [ ] Styles converted incrementally with test verification
- [ ] All Playwright tests pass after migration
- [ ] Console errors checked and resolved
- [ ] Linting errors checked and resolved
- [ ] SCSS classes verified as removed
- [ ] Tailwind classes verified as applied
- [ ] Component functionality verified
- [ ] Responsive behavior verified
- [ ] Dark mode behavior verified
- [ ] Visual regressions detected and resolved
