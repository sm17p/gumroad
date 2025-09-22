# Rows Component Migration Plan

## Overview

Migrate `_rows.scss` to Tailwind-based React components. This is **Priority 4** in the migration order. It has medium complexity due to the `%row-item` placeholder and tree structure.

## Specificity Analysis

| Selector                           | Specificity | Tailwind Equivalent        |
| ---------------------------------- | ----------- | -------------------------- |
| `.rows`                            | (0,1,0)     | `Rows` container component |
| `.rows > *`                        | (0,1,1)     | `RowItem` component        |
| `[role="tree"]`                    | (0,1,0)     | `Tree` container component |
| `[role="tree"] [role="treeitem"]`  | (0,2,0)     | `TreeItem` component       |
| `[role="treeitem"][aria-expanded]` | (0,2,0)     | `expandable` prop          |

## Dependencies

- **Uses @extend from:** `%icon` for drag handles and chevrons
- **Used by @extend in:** `_rich_text.scss` (`.embed` extends `%row-item`)
- **Shares selectors with:** `_rich_text.scss`

## Current SCSS Structure

```scss
%row-item {
  display: grid;
  padding: spacer(4);
  align-items: center;
  gap: spacer(4);

  @include breakpoint-up(sm) {
    grid-template-columns: minmax(30%, 1fr) auto;
  }

  .content { display: flex; align-items: center; gap: spacer(2); }
  & > :not(.content, .actions) { grid-column: 1/-1; }
  &:not(:last-child) { border-bottom: $border; }
  & > .actions { display: flex; flex-wrap: wrap; justify-content: flex-end; gap: spacer(2); }
  [aria-grabbed] { @extend %icon, .icon-outline-drag; margin-left: -spacer(4); order: -1; }
}

.rows {
  @include rows;
  > * { @extend %row-item; }
}

[role="tree"] {
  @include rows;
  [role="treeitem"] { @extend %row-item; ... }
}
```

## Component Definitions

### Rows Container

```tsx
import * as React from "react";
import { classNames } from "$app/utils/classNames";

export interface RowsProps extends React.HTMLProps<HTMLDivElement> {}

export const Rows = React.forwardRef<HTMLDivElement, RowsProps>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={classNames("divide-border border-border bg-background divide-y rounded border", className)}
    {...props}
  />
));
Rows.displayName = "Rows";
```

### RowItem

```tsx
export interface RowItemProps extends React.HTMLProps<HTMLDivElement> {
  draggable?: boolean;
}

export const RowItem = React.forwardRef<HTMLDivElement, RowItemProps>(
  ({ draggable, className, children, ...props }, ref) => (
    <div
      ref={ref}
      className={classNames("grid items-center gap-4 p-4", "sm:grid-cols-[minmax(30%,1fr)_auto]", className)}
      {...props}
    >
      {draggable && (
        <span className="icon icon-outline-drag text-muted order-first -ml-4 cursor-move" aria-grabbed="false" />
      )}
      {children}
    </div>
  ),
);
RowItem.displayName = "RowItem";
```

### RowContent

```tsx
export const RowContent = React.forwardRef<HTMLDivElement, React.HTMLProps<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={classNames("flex items-center gap-2", className)} {...props} />
  ),
);
RowContent.displayName = "RowContent";
```

### RowActions

```tsx
export const RowActions = React.forwardRef<HTMLDivElement, React.HTMLProps<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={classNames("flex flex-wrap items-center justify-end gap-2", className)} {...props} />
  ),
);
RowActions.displayName = "RowActions";
```

## SCSS to Tailwind Mapping

### `%row-item` Base

| SCSS                                           | Tailwind                              | Notes      |
| ---------------------------------------------- | ------------------------------------- | ---------- |
| `display: grid`                                | `grid`                                |            |
| `padding: spacer(4)`                           | `p-4`                                 | 1rem       |
| `align-items: center`                          | `items-center`                        |            |
| `gap: spacer(4)`                               | `gap-4`                               | 1rem       |
| `grid-template-columns: minmax(30%, 1fr) auto` | `sm:grid-cols-[minmax(30%,1fr)_auto]` | Responsive |

### `.rows` Container

| SCSS                              | Tailwind               | Notes   |
| --------------------------------- | ---------------------- | ------- |
| `border: $border`                 | `border border-border` |         |
| `border-radius: border-radius(1)` | `rounded`              | 0.25rem |
| `@include bg-color(filled)`       | `bg-background`        |         |

### Border Between Items

| SCSS                                   | Tailwind                           | Notes |
| -------------------------------------- | ---------------------------------- | ----- |
| `&:not(:last-child) { border-bottom }` | `divide-y divide-border` on parent |       |

### Drag Handle

| SCSS                        | Tailwind                                      |
| --------------------------- | --------------------------------------------- |
| `margin-left: -(spacer(4))` | `-ml-4`                                       |
| `order: -1`                 | `order-first`                                 |
| `@include text-muted`       | `text-muted` (custom) or `text-foreground/50` |

## Tree Component (Separate Migration)

The `[role="tree"]` structure is more complex and may warrant a separate phase:

```tsx
export interface TreeProps extends React.HTMLProps<HTMLDivElement> {}

export const Tree = React.forwardRef<HTMLDivElement, TreeProps>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    role="tree"
    className={classNames("divide-border border-border bg-background divide-y rounded border", className)}
    {...props}
  />
));

export interface TreeItemProps extends React.HTMLProps<HTMLDivElement> {
  expanded?: boolean;
  onToggle?: () => void;
}

export const TreeItem = React.forwardRef<HTMLDivElement, TreeItemProps>(
  ({ expanded, onToggle, className, children, ...props }, ref) => (
    <div
      ref={ref}
      role="treeitem"
      aria-expanded={expanded}
      className={classNames("grid items-center gap-4 p-4", "sm:grid-cols-[minmax(30%,1fr)_auto]", className)}
      {...props}
    >
      {children}
    </div>
  ),
);
```

## Migration Phases

### Phase 1: Rows Container + RowItem

1. Create `Rows.tsx` with base components
2. Migrate simple `.rows` usages
3. Use `divide-y` for borders

### Phase 2: RowContent + RowActions

1. Add helper components for content/actions columns
2. Migrate usages with `.content` and `.actions` classes

### Phase 3: Draggable Rows

1. Add `draggable` prop to RowItem
2. Handle `[aria-grabbed]` styling
3. Migrate drag-and-drop usages

### Phase 4: Tree Structure

1. Create `Tree` and `TreeItem` components
2. Handle `aria-expanded` states
3. Handle nested `[role="group"]` styling

## Usage Patterns

### Simple Rows

```tsx
// Before
<div className="rows">
  <div>
    <div className="content">Item 1</div>
    <div className="actions"><button>Edit</button></div>
  </div>
  <div>
    <div className="content">Item 2</div>
  </div>
</div>

// After
<Rows>
  <RowItem>
    <RowContent>Item 1</RowContent>
    <RowActions><button>Edit</button></RowActions>
  </RowItem>
  <RowItem>
    <RowContent>Item 2</RowContent>
  </RowItem>
</Rows>
```

### Draggable Row

```tsx
// Before
<div className="rows">
  <div>
    <span aria-grabbed="false"></span>
    <div className="content">Draggable item</div>
  </div>
</div>

// After
<Rows>
  <RowItem draggable>
    <RowContent>Draggable item</RowContent>
  </RowItem>
</Rows>
```

## Validation Strategy

After each phase:

1. Run TypeScript check: `npx tsc --noEmit`
2. Run Playwright visual tests
3. Verify drag handles work
4. Test responsive grid behavior

## Files to Update

```bash
grep -r "className=\".*rows" app/javascript/components --include="*.tsx"
grep -r 'role="tree"' app/javascript/components --include="*.tsx"
grep -r 'role="treeitem"' app/javascript/components --include="*.tsx"
```

## Dependency Note

`_rich_text.scss` uses `@extend %row-item` for `.embed` styling. This means:

1. Keep `%row-item` in SCSS until rich text is migrated
2. Or extract shared classes to a utility

## SCSS Cleanup

Defer cleanup until:

1. All `.rows` usages migrated
2. All `[role="tree"]` usages migrated
3. `_rich_text.scss` `.embed` dependency resolved
