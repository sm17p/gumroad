# Phase 1: Create Alert Component

## Overview

Create a new Tailwind-based `Alert` component in `app/javascript/components/ui/Alert.tsx`. This component will replace the SCSS-based `[role="alert"]` pattern for **inline alert messages** that appear in page content.

## Important: Existing Alert Component

**DO NOT modify** the existing `Alert.tsx` at `app/javascript/components/server-components/Alert.tsx`. That component is:

- A **toast/notification system** (fixed position, auto-dismisses)
- Used for flash messages via `showAlert()` function
- Rendered as a singleton in layouts
- Has completely different styling and behavior

The new `ui/Alert.tsx` is for **inline alert messages** that appear in the page flow, not as floating toasts.

## Component Location

**New file:** `app/javascript/components/ui/Alert.tsx`

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

| SCSS                              | Tailwind                           | Notes                          |
| --------------------------------- | ---------------------------------- | ------------------------------ |
| `display: grid`                   | `grid`                             |                                |
| `grid-template-columns: 1fr`      | `grid-cols-[auto_1fr]`             | With icon column               |
| `align-items: start`              | `items-start`                      |                                |
| `padding: spacer(3)`              | `p-3`                              | 0.75rem                        |
| `gap: spacer(2)`                  | `gap-2`                            | 0.5rem                         |
| `border: $border`                 | `border`                           | Uses border-color from variant |
| `border-radius: border-radius(1)` | `rounded`                          | 0.25rem                        |
| `@include bg-bordered($name)`     | `border-{variant} bg-{variant}/20` | Variant-specific               |

## Icon Mapping

| Variant | Icon Name                  |
| ------- | -------------------------- |
| success | `solid-check-circle`       |
| danger  | `x-circle-fill`            |
| warning | `solid-shield-exclamation` |
| info    | `info-circle-fill`         |
| accent  | (no default icon)          |

Icons are rendered using the `Icon` component from `$app/components/Icons` with variant-specific colors via `iconColorVariants`.

## Usage Patterns

The Alert component supports two main usage patterns:

### Pattern 1: Auto-icon (default)

```tsx
<Alert variant="info">Status message</Alert>
```

Automatically renders the variant icon. No `AlertIcon` needed.

### Pattern 2: Custom icon with AlertIcon

```tsx
<Alert variant="info">
  <AlertIcon asChild>
    <img src="custom-icon.png" alt="" className="size-12" />
  </AlertIcon>
  Status message
</Alert>
```

When using custom images or icons, wrap them in `AlertIcon` with `asChild` to render directly instead of wrapping in a `<span>`. This is the pattern used in migrated components like `NewProductPage.tsx`, `ProductEdit/ShareTab/index.tsx`, and `DiscountsPage.tsx`.

**Note:** `AlertIcon` is a simple wrapper component. It does not auto-render variant icons - use Pattern 1 for default icons.

## Implementation Steps

1. ✅ Create `app/javascript/components/ui/Alert.tsx` with the component definition above
2. ✅ Export from `app/javascript/components/ui/index.ts` (if it exists) or ensure direct import works - Direct import works (no index.ts needed)
3. ✅ Verify TypeScript compiles: `npx tsc --noEmit`
4. ✅ Test close button functionality with a real usage - Migrated `TeamPage.tsx` as test case

## Test Case for Close Button ✅ Migrated

**File:** `app/javascript/components/server-components/Settings/TeamPage.tsx` (line 270)

**Migration completed!** This was used to test close button functionality:

```tsx
// Before
<div role="alert" className="success">
  <div>{deletedMember.name !== "" ? deletedMember.name : deletedMember.email} was removed from team members</div>
  <button
    className="close"
    type="button"
    onClick={asyncVoid(async () => {
      // ... restore member logic
      setDeletedMember(null);
    })}
  >
    Undo
  </button>
</div>

// After ✅
<Alert className="grid-cols-[auto_1fr_auto]" variant="success">
  <div>
    {deletedMember.name !== "" ? deletedMember.name : deletedMember.email} was removed from team members
  </div>
  <button
    className="col-start-2 sm:col-start-3"
    type="button"
    onClick={asyncVoid(async () => {
      // ... restore member logic
      setDeletedMember(null);
    })}
  >
    Undo
  </button>
</Alert>
```

**Migration pattern:**

- Use `grid-cols-[auto_1fr_auto]` className override to create 3-column layout (icon, content, close)
- Close button uses `col-start-2 sm:col-start-3` to position in the third column (responsive: second column on mobile, third on sm+)
- This matches the SCSS behavior where `.close` moves from column 1 to column 2 on sm+ breakpoint
- The Alert component's default `grid-cols-[auto_1fr]` is overridden when close button is needed

## Validation Checklist

- [x] Component file created at `app/javascript/components/ui/Alert.tsx`
- [x] TypeScript compiles without errors
- [x] Component accepts and forwards refs correctly
- [x] Component accepts standard HTML div props (className, etc.)
- [x] Existing `server-components/Alert.tsx` remains unchanged
- [x] Component supports both `role="alert"` (default) and `role="status"`
- [x] Component supports optional `variant` prop (defaults to base styling when undefined)
- [x] `AlertIcon` component supports custom children via `asChild` prop
- [x] All 5 variants defined (success, danger, warning, info, accent)
- [x] All 5 variants render correctly (visually tested ✅)
- [x] Icons display correctly for each variant (visually tested ✅)
- [x] Grid layout shows icon on left, content on right (visually tested ✅)
- [x] Border and background colors match SCSS version (visually tested ✅)
- [x] Dark mode works correctly (visually tested ✅)
- [x] Close button functionality tested (migrated `TeamPage.tsx` ✅)

## Phase 1 Status: ✅ COMPLETE

All implementation steps completed and visually tested. The Alert component is ready for Phase 2 migration.

**Component Features:**

- ✅ Supports 5 variants: `success`, `danger`, `warning`, `info`, `accent`
- ✅ Supports both `role="alert"` (default) and `role="status"`
- ✅ Auto-renders variant icon when no custom icon is present
- ✅ `AlertIcon` wrapper component for custom icons/images
- ✅ Close button support via className override pattern
- ✅ All variants visually tested and working

## Notes

- The component uses `grid-cols-[auto_1fr]` to create a two-column layout: icon column (auto width) and content column (flexible)
- Icon size is `size-[1lh]` (1 line height) to match SCSS `width: 1lh`
- Icon has `aria-hidden="true"` since it's decorative
- Uses `tailwind-override` class to prevent SCSS `.icon:not(.tailwind-override)` from overriding Tailwind size classes
- Variant prop is optional (defaults to base styling when undefined)
- `AlertIcon` is a simple wrapper component for custom icons - it does not use context
- Supports both `role="alert"` (default) and `role="status"` for semantic distinction
- This is for **inline alerts only** - not for toast notifications (use `showAlert()` from server-components/Alert for those)
- `AlertTitle` and `AlertDescription` components were removed - use plain `div` elements with appropriate className for layout

## `asChild` Support on AlertIcon

The `AlertIcon` component supports the `asChild` prop using Radix UI's `Slot` component. This allows you to render custom icons/images directly without an extra wrapper `<span>`.

### Usage Example

```tsx
<Alert variant="info" role="status">
  <AlertIcon asChild>
    <img src={customImage} alt="" className="size-12" />
  </AlertIcon>
  <div>Your message here</div>
</Alert>
```

**Result with `asChild`:**

- The image renders directly without a `<span>` wrapper
- All `AlertIcon` props are merged onto the image element

**Result without `asChild`:**

- The image is wrapped in a `<span>` element
