# Build Troubleshooting After Sync

If sync completed but build fails, use this default sequence:

1. Re-run `git zc sync`.
2. Re-run `git zc build`.
3. Capture and inspect the first `error:` line (ignore warnings for initial triage).
4. Verify toolchain:
   - `rustc --version`
   - `cargo --version`
5. On macOS linker/toolchain issues, run `xcode-select --install`.
6. If cache/build artifacts are suspected, run `cargo clean` and retry `git zc build`.

## Build Commands Used by `git zc build`

```bash
cargo build --release --locked
cargo install --path . --force --locked
```
