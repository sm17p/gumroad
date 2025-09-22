# Alert Component Migration Plan

## Overview

Migrate `_alert.scss` to a Tailwind-based React component. This is **Priority 3** in the migration order due to its simple specificity profile and state-based variants.

## Migration Progress

**Overall Progress: 108/108 usages migrated (100%) ✅**

- ✅ Phase 1: Component Creation - **COMPLETE**
- ✅ Phase 2: Migrate All Alerts (Unified) - **108/108 complete (100%) - COMPLETE!**

## Specificity Analysis

| Selector                                  | Specificity | Tailwind Equivalent                        |
| ----------------------------------------- | ----------- | ------------------------------------------ |
| `[role="alert"]`                          | (0,1,0)     | Base component classes                     |
| `[role="alert"].success`                  | (0,2,0)     | `variant="success"` prop                   |
| `[role="alert"].success::before`          | (0,2,1)     | Icon child component                       |
| `[role="status"]:not(.tailwind-override)` | (0,2,0)     | Separate `Status` component or shared base |

## Dependencies

- **Uses @extend from:** `%icon` (internal to `_icons.scss`)
- **Used by @extend in:** None
- **Shares selectors with:** `[role="status"]` shares styles

## Current SCSS Structure

```scss
$alert-icons: (
  success: "solid-check-circle",
  danger: "x-circle-fill",
  warning: "solid-shield-exclamation",
  info: "info-circle-fill",
);

[role="alert"],
[role="status"]:not(.tailwind-override):not(.jw-text-alt) {
  display: grid;
  grid-template-columns: 1fr;
  align-items: start;
  padding: spacer(3);
  gap: spacer(2);
  border: $border;
  border-radius: border-radius(1);

  @each $name in $states {
    &.#{$name} {
      @include bg-bordered($name);

      &::before {
        @extend %icon, .icon-#{map-get($alert-icons, $name)};
        width: 1lh;
        color: full-color($name);
        grid-column: -3;
      }
    }
  }
}
```

## Component Definition

The Alert component uses `cva` for variant management. It supports both `role="alert"` (default) and `role="status"`.

**Key Features:**

- Uses `cva` for variant styling (`alertVariants` and `iconColorVariants`)
- Automatically renders variant icon when no custom icon is present
- Supports custom icons via `AlertIcon` wrapper component
- Variants: `success`, `danger`, `warning`, `info`, `accent`
- Icon uses `Icon` component with `tailwind-override` class to prevent SCSS override

**Component Structure:**

- `Alert` - Main container component with variant prop (auto-renders default icon)
- `AlertIcon` - Optional wrapper component for custom icons/images

## SCSS to Tailwind Mapping

### Base Alert

| SCSS                              | Tailwind               | Notes                          |
| --------------------------------- | ---------------------- | ------------------------------ |
| `display: grid`                   | `grid`                 |                                |
| `grid-template-columns: 1fr`      | `grid-cols-[auto_1fr]` | With icon column               |
| `align-items: start`              | `items-start`          |                                |
| `padding: spacer(3)`              | `p-3`                  | 0.75rem                        |
| `gap: spacer(2)`                  | `gap-2`                | 0.5rem                         |
| `border: $border`                 | `border`               | Uses border-color from variant |
| `border-radius: border-radius(1)` | `rounded`              | 0.25rem                        |

### Variant Colors

| SCSS                                | Tailwind         | Notes                                  |
| ----------------------------------- | ---------------- | -------------------------------------- |
| `border-color: rgb(var(--success))` | `border-success` | Full opacity border                    |
| `background-color: gray(2, $name)`  | `bg-success/20`  | 20% opacity background (gray(2) = 0.2) |

**Important:** The `bg-bordered` mixin generates:

- `border-color: rgb(var(--{name}))` → `border-{variant}` in Tailwind
- `background-color: rgb(var(--{name}) / 0.2)` → `bg-{variant}/20` in Tailwind

### Tailwind Theme Colors

All variant colors must be defined in `tailwind.css` `@theme` block:

```css
--color-success: rgb(var(--success));
--color-danger: rgb(var(--danger));
--color-warning: rgb(var(--warning));
--color-info: rgb(var(--info)); /* Added for Alert component */
```

This enables Tailwind utilities like `border-info`, `bg-info/20`, `text-info`, etc.

### Icons

| Variant | Icon Name                  |
| ------- | -------------------------- |
| success | `solid-check-circle`       |
| danger  | `x-circle-fill`            |
| warning | `solid-shield-exclamation` |
| info    | `info-circle-fill`         |
| accent  | (no default icon)          |

Icons are rendered using the `Icon` component from `$app/components/Icons` with variant-specific colors via `iconColorVariants`.

## Migration Phases

See detailed task files for each phase:

1. **[Phase 1: Create Alert Component](01-create-component.md)** - ✅ **COMPLETE** - Create the base Alert component in `ui/Alert.tsx`
2. **[Phase 2: Migrate All Alerts (Unified)](02-migrate-alerts.md)** - Migrate all 106 alert/status usages organized by pattern and complexity (**55 migrated ✅ - 51.9%**)

### Phase 1: Create Alert Component

1. Create `Alert.tsx` with variant prop
2. Include icon rendering within component
3. Keep grid layout for icon + content

### Phase 2: Migrate All Alerts (Unified)

**Unified migration plan organized by pattern and complexity:**

- ✅ Level 1 (simplest) - ~77/~77 complete (100%)
- ✅ Level 2 (medium) - ~8/~8 complete (100%)
- ✅ Level 3 (medium-hard) - 4/4 complete (100%)
- ✅ Level 4 (hard) - 3/3 complete (100%)
- ✅ Level 5 (very hard) - ~4/~4 complete (100%)

**Overall Progress: 55/106 complete (51.9%)**

- `role="alert"`: 14/37 complete (37.8%)
- `role="status"`: 24/28 complete (85.7%)

See [Phase 2 documentation](02-migrate-alerts.md) for detailed patterns and migration examples.

### Phase 4: Status Role (Merged into Phase 2)

All `[role="status"]` and `[role="alert"]` usages are now handled in the unified Phase 2 migration plan, organized by pattern and complexity rather than by role. See [Phase 2 documentation](02-migrate-alerts.md) for details.

## Usage Patterns to Migrate

### Simple Alert

```tsx
// Before
<div role="alert" className="success">
  Your changes have been saved.
</div>

// After
<Alert variant="success">
  Your changes have been saved.
</Alert>
```

### Alert with Close Button

```tsx
// Before
<div role="alert" className="success">
  <div>Message</div>
  <button className="close" onClick={onClose}>Undo</button>
</div>

// After
<Alert className="grid-cols-[auto_1fr_auto]" variant="success">
  <div>Message</div>
  <button className="col-start-2 sm:col-start-3" onClick={onClose}>Undo</button>
</Alert>
```

**Pattern:** Use className override to create 3-column grid layout. Close button uses `col-start-2 sm:col-start-3` for responsive positioning. See [Phase 2 documentation](02-migrate-alerts.md#close-button-pattern) for details.

## Existing Alert Component

**Important:** There's already an `Alert.tsx` at `app/javascript/components/server-components/Alert.tsx`. This is a **toast/notification system** (fixed position, auto-dismisses) and should **NOT be modified**.

The existing component:

- Is a toast notification system for flash messages
- Uses `showAlert()` function to trigger via postMessage
- Rendered as singleton in layouts
- Has completely different styling (fixed, top-4, left-1/2, etc.)

The new `ui/Alert.tsx` component is for **inline alert messages** that appear in page content, not as floating toasts. These are separate use cases and should remain separate components.

## Validation Strategy

After each phase:

1. Run TypeScript check: `npx tsc --noEmit` ✅
2. Run Playwright visual tests
3. Verify dark mode works ✅ (visually tested)
4. Test all 5 variants (success, danger, warning, info, accent) ✅ (visually tested)

**Current Status:**

- ✅ Phase 1: Component created and tested
- ✅ Phase 2: 108/108 unified alerts migrated (100%) - **COMPLETE!**
  - ✅ Level 1 (simplest) - ~77/~77 complete (100%)
  - ✅ Level 2 (medium) - ~8/~8 complete (100%)
  - ✅ Level 3 (medium-hard) - 4/4 complete (100%)
  - ✅ Level 4 (hard) - 3/3 complete (100%)
  - ✅ Level 5 (very hard) - ~4/~4 complete (100%)

## Files to Update

Search for alert usages:

```bash
grep -r 'role="alert"' app/javascript/components --include="*.tsx"
grep -r 'role="status"' app/javascript/components --include="*.tsx"
```

## SCSS Cleanup

Keep `_alert.scss` intact until:

1. ✅ All React components migrated (108/108 complete - 100%)
2. ERB views deprecated
3. ✅ All alert/status usages handled (108/108 complete - 100%)

**Note:** The SCSS file will remain in use for:

- ERB template views that haven't been migrated to React
- Any remaining unmigrated React components
- Backward compatibility during the migration period
