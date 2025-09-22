# SCSS to Tailwind Migration Priority Guide

## Overview

This document defines the priority order for migrating SCSS files to Tailwind CSS based on **CSS specificity analysis**. Lower specificity and fewer dependencies = safer to migrate first.

## CSS Specificity Reference

| Level | Selector Type    | Specificity | Risk    | Example                        |
| ----- | ---------------- | ----------- | ------- | ------------------------------ |
| 1     | Universal `*`    | (0,0,0)     | Lowest  | `* { box-sizing }`             |
| 2     | Element          | (0,0,1)     | Low     | `button { }`                   |
| 3     | Class            | (0,1,0)     | Low     | `.pill { }`                    |
| 4     | Attribute        | (0,1,0)     | Low     | `[role="alert"]`               |
| 5     | Pseudo-class     | (0,1,0)     | Medium  | `:hover`, `:first-child`       |
| 6     | Combined         | (0,2,0)+    | Medium  | `.stack > *:not(:first-child)` |
| 7     | Deep nesting     | (0,3,0)+    | High    | `.form fieldset.danger input`  |
| 8     | `@extend` chains | Varies      | High    | Multiple inheritance           |
| 9     | `:where()` reset | (0,0,0)     | Special | `button:where(:not(.x))`       |

---

## Migration Order (Safest First)

### Tier 1: Isolated Components (Lowest Risk)

Simple class selectors, no deep nesting, no `@extend` dependencies on external classes.

| Priority | File          | Lines | Usages | Specificity Profile      | Status             |
| -------- | ------------- | ----- | ------ | ------------------------ | ------------------ |
| **1**    | `_stack.scss` | 94    | ~92    | `.stack` (0,1,0)         | ✅ Component ready |
| **2**    | `_pill.scss`  | 56    | ~50    | `.pill` (0,1,0)          | 🔲 Pending         |
| **3**    | `_alert.scss` | 39    | ~47    | `[role="alert"]` (0,1,0) | 🔲 Pending         |

### Tier 2: Structural Components (Medium Risk)

Some child selectors but self-contained scope.

| Priority | File             | Lines | Usages | Specificity Profile             | Status     |
| -------- | ---------------- | ----- | ------ | ------------------------------- | ---------- |
| **4**    | `_rows.scss`     | 97    | ~21    | `.rows > *` (0,1,1)             | 🔲 Pending |
| **5**    | `_dropdown.scss` | -     | Low    | `.dropdown`, `.popover` (0,1,0) | 🔲 Pending |
| **6**    | `_cart.scss`     | -     | Low    | `.cart[role=list]` (0,2,0)      | 🔲 Pending |

### Tier 3: Navigation & Layout (Medium-High Risk)

Responsive breakpoints, context-dependent styling.

| Priority | File                | Lines | Usages | Specificity Profile                | Status     |
| -------- | ------------------- | ----- | ------ | ---------------------------------- | ---------- |
| **7**    | `_nested_menu.scss` | -     | Low    | `.nested-menu [role=menu]` (0,2,0) | 🔲 Pending |
| **8**    | `_product.scss`     | -     | Medium | `article.product-card` (0,1,1)     | 🔲 Pending |
| **9**    | `_profile.scss`     | -     | Medium | `.profile > header` (0,1,1)        | 🔲 Pending |

### Tier 4: Form System (High Risk)

Element selectors, pseudo-classes, complex attribute chains.

| Priority | File           | Lines | Usages | Specificity Profile              | Status     |
| -------- | -------------- | ----- | ------ | -------------------------------- | ---------- |
| **10**   | `_forms.scss`  | 445   | High   | `input:not([type])` (0,2,1)      | 🔲 Pending |
| **11**   | `_button.scss` | 95    | ~160   | `button:where(:not(.x))` (0,0,1) | 🔲 Pending |

### Tier 5: Rich Content (Highest Risk)

Deep nesting, editor integration, `@extend` chains.

| Priority | File              | Lines | Usages | Specificity Profile                     | Status     |
| -------- | ----------------- | ----- | ------ | --------------------------------------- | ---------- |
| **12**   | `_rich_text.scss` | -     | High   | `.rich-text .embed > .preview` (0,3,0)+ | 🔲 Pending |

---

## Specificity Analysis Per File

### `_stack.scss` ✅ (Priority 1 - READY)

```scss
.stack { ... }                              // (0,1,0) ✅ Safe
.stack > * { ... }                          // (0,1,1) ✅ Handled by divide-y
.stack > *:not(:first-child) { ... }        // (0,2,1) ✅ Handled by divide-y
.stack.borderless { ... }                   // (0,2,0) ✅ borderless prop
.stack.two-columns { ... }                  // (0,2,0) ✅ className override
main.stack { ... }                          // (0,1,1) ✅ className override
```

**Component:** `app/javascript/components/ui/Stack.tsx`
**Plan:** `docs/migration-plans/stack/README.md`

### `_pill.scss` (Priority 2)

```scss
.pill { ... }                               // (0,1,0) ✅ Safe
.pill.small { ... }                         // (0,2,0) ✅ Safe
.pill.success { ... }                       // (0,2,0) ✅ Safe (each $bg-color)
.pill.select { ... }                        // (0,2,0) ✅ Safe
.pill.dismissable::before { ... }           // (0,2,1) ✅ Safe
.pill.expandable::before { ... }            // (0,2,1) ✅ Safe
```

**Risk:** LOW

- No element selectors
- Internal `@extend` only (for `%icon`)
- Simple variant pattern maps to props

### `_alert.scss` (Priority 3)

```scss
[role="alert"] { ... }                      // (0,1,0) ✅ Safe
[role="alert"].success { ... }              // (0,2,0) ✅ Safe
[role="alert"].success::before { ... }      // (0,2,1) ✅ Safe
[role="status"]:not(.tailwind-override) { } // (0,2,0) ✅ Uses :not() escape hatch
```

**Risk:** LOW

- Attribute selectors equivalent to class specificity
- State-based variants only
- Already has `.tailwind-override` escape pattern

### `_rows.scss` (Priority 4)

```scss
.rows { ... }                               // (0,1,0) ✅ Safe
.rows > * { @extend %row-item }             // (0,1,1) ⚠️ Uses placeholder
[role="tree"] { ... }                       // (0,1,0) ✅ Safe
[role="tree"] [role="treeitem"] { ... }     // (0,2,0) ⚠️ Nested attributes
```

**Risk:** MEDIUM

- Uses `@extend %row-item` internally
- Nested attribute selectors
- Tree structure requires careful component design

### `_forms.scss` (Priority 10)

```scss
input:not([type]) { ... }                   // (0,2,1) ⚠️ Complex negation
$text-inputs interpolation { ... }          // Dynamic selector list
fieldset.danger input[type="radio"] { }     // (0,3,2) ⚠️ Deep chain
.combobox datalist option:focus { }         // (0,3,1) ⚠️ Deep nesting
label:has(input:disabled) { }               // (0,2,2) ⚠️ :has() selector
```

**Risk:** HIGH

- 445 lines of complex selectors
- Interpolated selector variables (`$text-inputs`)
- Complex attribute chains
- `:has()` pseudo-class usage

### `_button.scss` (Priority 11)

```scss
button:where(:not(.tailwind-override)) { }  // (0,0,1) Special :where() reset
%button { ... }                             // Placeholder extended by .button
.button { @extend %button }                 // (0,1,0) but inherits complexity
.button.primary:hover:not(:disabled) { }    // (0,4,0) Complex state chain
.button-facebook { ... }                    // (0,1,0) Brand buttons
```

**Risk:** HIGH

- `:where()` specificity reset pattern
- `@extend` chains with `%button` and `%active-button`
- Brand button loop with dynamic colors
- Complex hover/disabled state combinations

### `_rich_text.scss` (Priority 12)

```scss
.rich-text > * { ... }                      // (0,1,1) Child selector
.rich-text .embed { ... }                   // (0,2,0) Nested class
.rich-text .embed > .preview { ... }        // (0,3,0) Deep nesting
.rich-text .embed > .preview > :first-child // (0,3,1) Very deep
.ProseMirror[contenteditable=true] { }      // (0,2,1) Editor-specific
```

**Risk:** HIGHEST

- TipTap/ProseMirror editor integration
- Deep nesting (4+ levels)
- Editor-specific attribute selectors
- Complex preview/embed structures

---

## Migration Decision Flowchart

```
START: Pick SCSS file
    │
    ▼
┌─────────────────────────────────┐
│ Does it use @extend to external │
│ classes (not internal %)?       │
└─────────────────────────────────┘
    │ YES ──────────────────────────▶ DEFER (needs dependency analysis)
    │ NO
    ▼
┌─────────────────────────────────┐
│ Does it use element selectors   │
│ (button, input, form)?          │
└─────────────────────────────────┘
    │ YES ──────────────────────────▶ TIER 4+ (high collision risk)
    │ NO
    ▼
┌─────────────────────────────────┐
│ Does it have > 2 levels of      │
│ nesting (e.g., .a .b .c)?       │
└─────────────────────────────────┘
    │ YES ──────────────────────────▶ TIER 3 (needs careful testing)
    │ NO
    ▼
┌─────────────────────────────────┐
│ Does it use :where() or has     │
│ !important anywhere?            │
└─────────────────────────────────┘
    │ YES ──────────────────────────▶ TIER 4 (specificity complications)
    │ NO
    ▼
  TIER 1-2: Safe to migrate early
```

---

## Child Selector Elimination Patterns

| SCSS Pattern                    | Tailwind/React Approach                          |
| ------------------------------- | ------------------------------------------------ |
| `.parent > *`                   | Create `<ParentItem>` component                  |
| `.parent > *:not(:first-child)` | Use `divide-y divide-border` on parent           |
| `.parent > *:first-child`       | Use `first:` variant or `StackHeader` component  |
| `.parent > *:last-child`        | Use `last:` variant or `StackFooter` component   |
| `.parent > :nth-child(odd)`     | Use `odd:` variant or loop with index            |
| `.parent.variant > *`           | Pass `variant` prop, apply classes conditionally |

---

## Files NOT to Migrate

These files contain foundational utilities and should remain as SCSS:

| File                | Reason                                     |
| ------------------- | ------------------------------------------ |
| `_colors.scss`      | Pure Sass functions for color manipulation |
| `_definitions.scss` | Mixins, variables, CSS custom properties   |
| `_font.scss`        | @font-face declarations                    |
| `_icons.scss`       | Icon mask-image definitions                |
| `_icon_names.scss`  | Icon class name mappings                   |
| `_global.scss`      | `@layer base` reset styles                 |
| `_legacy.scss`      | ERB view compatibility                     |

---

## Next Steps

1. ✅ Stack migration in progress (Phase 1 & 2 complete, Phases 3-5 pending via `docs/migration-plans/stack/`)
2. 🔲 Create Pill component and migration plan
3. 🔲 Create Alert component and migration plan
4. 🔲 Continue through priority order

---

## Related Documents

- [Migration Plan Template](./prompts/migration-plan-template.md)
- [Stack Migration Plan](./stack/README.md)
- [Tailwind CSS Guidelines](./prompts/tailwindcss.md)
