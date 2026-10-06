# Changes

## [0.9.0] - 2026-10-05

### Breaking

- `Buffer.get`, `Buffer.set` and `Buffer.copy_string` raise `Invalid_argument`
  for an index out of bounds; `get` returned an invalid `char`, `set` and
  `copy_string` silently did nothing.
- `Buffer.create` raises `Invalid_argument` for a negative size.
- `fopen` accepts only the C11 modes (`r`, `w`, `a`, optionally `+` and `b`,
  `x` with `w`) and rejects names and modes containing a NUL byte, with `EINVAL`.
- `feof` is `true` for a closed file.
- The end of a file is not an error: `fread` returns `Ok 0` instead of
  `Error (-42, "EOF")`, and `content64k` an empty buffer.
- Linux and macOS only; opam rejects other platforms.
- The demo executable `mlCppCStdio` is no longer installed.

### Added

- `with_file` (closes the file also on exceptions), `fold_chunks` (read a file
  in chunks), `read_all` and `Buffer.sub_string`.
- Documentation of every function and of the error codes in `lib/cstdio.mli`.
- `examples/` (copy a file through a buffer), built and run by `dune runtest`.
- `bench/`: write and read throughput, `Buffer.to_string`/`from_string`.
- `dune runtest --profile sanitize` (AddressSanitizer, UndefinedBehaviorSanitizer).
- `scripts/coverage.sh`: test coverage of OCaml (bisect_ppx) and C++ (gcov); a CI job runs it.
- Regression tests for the fixes below.
- Forgejo CI workflow and CI image (`docker/Dockerfile`); a lint job checks the
  formatting (ocamlformat) and runs cppcheck on the C++ stubs.
- `SECURITY.md`; this changelog.

### Fixed

- `fread` and `fwrite` with a negative length overflowed the buffer or wrote
  heap memory to the file; they return `Error (-1, "invalid length")`.
- Using a file after `fclose` (including a second `fclose`) was a use after
  free; it returns `Error (-99, "no FILE pointer")`.
- Failing `Buffer.copy_sz_pos` calls corrupted the GC roots.
- `Buffer.copy_sz_pos` and `Buffer.copy_string` could overflow their bounds
  checks for large sizes or positions; `copy_sz_pos` allows overlapping ranges.
- Bytes from `0x80` to `0xff` read from a buffer were invalid OCaml `char`s.
- Error messages were empty on Linux (glibc `strerror_r`); `errno` could be
  overwritten before it was read; an error with `errno` 0 was reported as success.
- `content64k` opened files with the invalid mode `"rx"` and leaked the file
  on errors.
- Files dropped without `fclose` leaked their descriptor; they are closed when
  garbage collected.
- Out of memory in the C++ code terminated the process; it raises `Out_of_memory`.
- The GC did not account for the memory of buffers.
- The Coq module `lib/Cstdio.v` is removed: it was not built and declared
  functions that do not exist.
- Package metadata: declared dependencies (`alcotest` for tests, OCaml >= 4.14),
  removed the unused `ppx_optcomp`, SPDX license id `Apache-2.0`, documentation URL,
  description and tags.
- Tests and demo were not repeatable (fixed `/tmp` files opened with `"wx"`).

### Changed

- `Buffer.to_string` and `Buffer.from_string` copy with one `memcpy` instead of
  a C call per byte.
- C++ is compiled with `-O2 -Wall -Wextra`.
