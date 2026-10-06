# ml-cpp-cstdio
OCaml embedded C++ &lt;[cstdio](https://en.cppreference.com/w/cpp/header/cstdio)>

Files and byte buffers for OCaml, through C++ `<cstdio>`:

* `fopen`, `fclose`, `fread`, `fwrite`, `fseek`, `ftell`, `fflush`, `feof`, `ferror`
  with errors as `(_, errinfo) result`: the `errno` and its message
* `Buffer.ta`: a chunk of bytes on the C heap, outside of the OCaml heap, that
  `fread` and `fwrite` use directly; `fwrite_s` writes a string without a copy
* `with_file`, `fold_chunks`, `read_all`: open and always close, read in chunks, read everything
* `content64k`: up to 64 KiB of a file from any position, in one call

The semantics of every function are in [lib/cstdio.mli](lib/cstdio.mli).

Supported platforms: Linux and macOS. Windows is not yet supported.


## install it

Requires OCaml >= 4.14 and a C++17 compiler (GCC or Clang).

```sh
opam pin add mlcpp_cstdio git+https://github.com/CodiePP/ml-cpp-cstdio.git
```

or from a clone:

```sh
git clone https://github.com/CodiePP/ml-cpp-cstdio.git
cd ml-cpp-cstdio
opam install .            # builds, (optionally) tests and installs; or:
opam install . --deps-only --with-test && dune build && dune install
```

and in your `dune` file: `(libraries mlcpp_cstdio)`


## use it

From [examples/copy_file.ml](examples/copy_file.ml) (built and run by `dune runtest`):

```OCaml
open Mlcpp_cstdio
module F = Cstdio.File

let ok what = function
  | Ok x -> x
  | Error (errno, msg) -> failwith (Printf.sprintf "%s: %s (%d)" what msg errno)

(* copy src to dst, 4 bytes at a time to show the loop;
   with_file closes both files, also when fwrite fails *)
let copy src dst =
  F.with_file src "rb" @@ fun fin ->
  F.with_file dst "wb" @@ fun fout ->
  F.fold_chunks ~chunk:4 fin 0 (fun buf n total ->
    F.fwrite buf n fout |> ok "fwrite" |> ignore;
    total + n)

let () =
  ...
  Printf.printf "copied %d bytes\n" (copy src dst |> ok "copy");
  assert (F.read_all dst |> ok "read copy" = "hello, cstdio!\n")
```


## error handling

File operations return `Ok _` or `Error (errno, message)`:

| `errno` | meaning |
|---|---|
| `> 0` | the operating system's `errno`, e.g. `2` (ENOENT); `22` (EINVAL) for an invalid mode or a NUL byte in a name |
| `-1` | invalid argument: released buffer, negative length or position |
| `-99` | the file is closed, or failed to open |

The end of a file is not an error: `fread` returns `Ok 0`.

`Buffer.get`, `set`, `sub_string`, `copy_string` and `create` raise `Invalid_argument`
for indices or sizes out of bounds; `Buffer.copy_sz_pos` returns a negative code.

Files and buffers are not thread-safe. A file that is not closed is closed
when it is garbage collected; `Buffer.release` frees a buffer's memory early.


## build it

`dune build`

format the OCaml code (ocamlformat 0.28.1, checked by CI): `dune fmt`


## run the demo

`dune exec bin/main.exe`


## run the tests

`dune runtest`

with the C++ code instrumented by AddressSanitizer and UndefinedBehaviorSanitizer:

`ASAN_OPTIONS=detect_leaks=0 dune runtest --profile sanitize`

coverage of the OCaml code (bisect_ppx, `opam install bisect_ppx`) and of the C++ code (gcov),
with reports in `_coverage/`:

`scripts/coverage.sh`

throughput of `fwrite`, `fread` and the buffer copies (size in MiB, default 256):

`dune exec --profile release bench/bench.exe -- 1024`


## the interface

Abbreviated; see [lib/cstdio.mli](lib/cstdio.mli).

```OCaml
module File :
sig
    (* Buffer.ta represents a chunk of C-bytes *)
    module Buffer :
    sig
      type ta
      val create : int -> ta
      val release : ta -> ta
      val resize : ta -> int -> unit
      val good : ta -> bool
      val init : int -> (int -> char) -> ta
      val to_string : ta -> string
      val from_string : string -> ta
      val sub_string : ta -> pos:int -> len:int -> string
      val size : ta -> int
      val get : ta -> int -> char
      val set : ta -> int -> char -> unit
      val copy_sz_pos : ta -> pos1:int -> sz:int -> ta -> pos2:int -> int
      val copy_string : string -> ta -> int -> unit
    end

    type file
    type errinfo = (int * string)

    val to_string : file -> string

    val fopen : string -> string -> (file, errinfo) result
    val fclose : file -> (unit, errinfo) result
    val fflush : file -> (unit, errinfo) result
    val fflush_all : unit -> (unit, errinfo) result
    val ftell : file -> (int, errinfo) result
    val fseek : file -> int -> (unit, errinfo) result
    val fseek_relative : file -> int -> (unit, errinfo) result
    val fseek_end : file -> int -> (unit, errinfo) result
    val fread : Buffer.ta -> int -> file -> (int, errinfo) result
    val fwrite : Buffer.ta -> int -> file -> (int, errinfo) result
    val fwrite_s : string -> file -> (int, errinfo) result
    val ferror : file -> errinfo
    val feof : file -> bool

    val content64k : string -> int -> (Buffer.ta, errinfo) result
    val with_file : string -> string -> (file -> ('a, errinfo) result) -> ('a, errinfo) result
    val fold_chunks : ?chunk:int -> file -> 'a -> (Buffer.ta -> int -> 'a -> 'a) -> ('a, errinfo) result
    val read_all : string -> (string, errinfo) result

    val pp_file : Format.formatter -> file -> unit
    val pp_err : Format.formatter -> errinfo -> unit
end
```
