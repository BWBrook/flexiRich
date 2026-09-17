# Goal008 evidence snapshot

Archived on 17 September 2026 before Goal009 implementation. The archive contains
the complete final `theory-v2`, `development-v1`, `legacy-v1` and `synthesis-v2`
output directories at their original repository-relative paths. It includes the
restricted first-year input tables, figures, numerical checks, source receipts
and original session information. Preliminary superseded outputs and manuscript
rendering caches are excluded.

SHA-256 of `goal008-final-outputs.tar.gz`:

```
4b81065297f3eee6da6aa13a3d5f20d9c2fe854fdd9fa34b594ec10080068468
```

All 77 original closeout source receipts matched immediately before archiving.
This preserves the completed development evidence; it does not retrospectively
make the original analysis a prospectively committed run. Its recorded package
drift and inspection disclosure remain part of the evidence.

To recover into a fresh checkout, first inspect `tar -tzf` and then extract from
the repository root with `tar --keep-old-files -xzf` and the archive path. Do not
overwrite an existing output directory. The manuscript is reproducible from its
committed Markdown and these figures using `make manuscript` with local makedoc.
