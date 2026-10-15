---
name: frontend-feature
description: Implement a frontend feature end to end with typed components, accessible markup, loading and error states, and tests that match the existing React or Next.js patterns. Use this when building or modifying UI components, pages, hooks or state.
---

# Frontend Feature

## Objective

Deliver a UI change that is typed, accessible, resilient to every network
state, and consistent with the design system already in the project.

## When to use

- Adding or modifying a component, page, route, hook or state store.
- Adding a form with validation.
- Integrating a new API endpoint into the UI.
- Fixing a visual or interaction defect.

## When not to use

- A pure backend change.
- A design-system primitive already provided by the library.
- A change confined to static copy, with no behavioural impact.

## Required inputs

- The user story or defect, in the requester's words.
- The design: mockup, screenshot, or Figma reference, plus the states that
  matter (empty, loading, error, partial, success).
- The existing patterns: component library, styling approach, state
  management, test setup.

## Procedure

1. **Read the existing patterns first.** Find a comparable component and copy
   its structure: file layout, naming, export style, prop typing, styling
   approach, test placement. Consistency beats personal preference.

2. **Type the boundary.** Define the data types for props and for every API
   response. Use a discriminated union for the request state rather than three
   booleans that can contradict each other:

   ```ts
   type LoadState<T> =
     | { status: "idle" }
     | { status: "loading" }
     | { status: "error"; error: ApiError }
     | { status: "success"; data: T };
   ```

3. **Implement every state, explicitly.** Initial, loading, empty, partial,
   error, success, and reloading while stale. A component that only renders
   the success case is incomplete.

4. **Keep server state out of global state.** Fetch in the data layer with the
   project's query library, or in a hook with an abort signal. Never mirror
   API data into a global store: it duplicates the cache and goes stale.

5. **Derive, do not duplicate.** Compute values with a selector or a pure
   function during render. Duplicated state must be updated in every code path
   that changes the original, which is where the bugs live.

6. **Meet the accessibility baseline.**
   - Semantic elements before `div` with a role.
   - Every input has a programmatically associated label.
   - Keyboard operation and a visible focus ring for every interactive
     element.
   - Errors announced with `role="alert"` or `aria-live`, not colour alone.
   - Contrast at least 4.5:1 for text and 3:1 for interface components.
   - Images have meaningful `alt`, decorative images have `alt=""`.

7. **Handle the messy cases.** Slow network, double submission, out-of-order
   responses, stale data, component unmount mid-request, extremely long
   strings, and text in Spanish that is longer than English.

8. **Optimise only what is measured.** Add `memo` or a virtualised list only
   after a profile shows a problem, and say what was measured.

9. **Test at the right level.**
   - Unit: pure hooks, utilities, reducers.
   - Component: rendering and interaction through the DOM, using
     `getByRole` rather than test ids.
   - Integration: one test per user-visible flow, mocking at the network
     boundary and never the component tree.
   - End to end: only the critical journeys.

10. **Verify.** Run the project's own format, lint, typecheck and test
    commands. Report the real output.

## Constraints

- Never use `any`, and never cast through `any` to escape a type error.
- Never fetch inside a component body on every render.
- Never block the UI thread with synchronous heavy computation.
- Never disable the lint rule instead of fixing the cause.
- Never hardcode a colour, spacing value or breakpoint outside the design
  tokens.
- Never introduce a state library to solve a local state problem.
- Never disable a test to make the suite pass.

## Validation checklist

- [ ] Existing pattern followed; no new pattern introduced for one component
- [ ] Props and API types explicit, no `any`
- [ ] Load state modelled as a union, not parallel booleans
- [ ] idle, loading, empty, error, success and partial all handled
- [ ] No API data duplicated into a global store
- [ ] Semantic HTML, labelled inputs, keyboard operable, visible focus
- [ ] Errors announced to assistive technology
- [ ] Slow network and double submission handled
- [ ] Tests written at the level described, querying by role
- [ ] Format, lint, typecheck and tests run; real output reported

## Mandatory output format

```markdown
## Summary
<what was built, in two sentences>

## Files changed
| Path | Change |
|------|--------|

## Types
```ts
<the new or changed types>
```

## States handled
- [ ] idle
- [ ] loading
- [ ] empty
- [ ] error
- [ ] success
- [ ] partial / stale

## Accessibility
- Semantics: <elements used and why>
- Keyboard: <how it is operated>
- Focus: <management approach>
- Announcements: <what is announced and when>
- Contrast checked: yes | no

## Performance decisions
| Decision | Evidence | Alternative rejected |
|----------|----------|---------------------|

## Tests added
| Test | Level | Proves |
|------|-------|--------|

## Validation
| Command | Result |
|---------|--------|

## Not covered
- <what was left out and the residual risk>
```

## Completion criteria

- Every state is implemented, not only the happy path.
- The component is keyboard operable and the errors are announced.
- No `any`, no duplicated server state.
- Tests query by role and cover the failure paths.
- All validation commands ran and their real output is reported.