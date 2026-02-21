# Plugin Playbook (When Feature Is Not Decided Yet)

If plugin/extension functionality is not decided yet:

- Do not implement speculative code paths.
- Run a short discovery step and propose 2-3 concrete plugin candidates.
- Prefer extension points in this order unless user says otherwise:
  1. `Tool` (`src/tools/traits.rs`)
  2. `Channel` (`src/channels/traits.rs`)
  3. `Provider` (`src/providers/traits.rs`)
  4. `Peripheral` (`src/peripherals/traits.rs`)
- Keep scope minimal: new module + factory registration + focused tests.
- Avoid cross-cutting rewrites when a trait implementation is sufficient.

## Default Next Action

1. Confirm extension type (Tool/Channel/Provider/Peripheral).
2. Define one concrete user-facing capability and one explicit non-goal.
3. Implement only that slice on `feat/*`.
