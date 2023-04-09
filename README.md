# ml-cpp-cstdio
OCaml embedded cross-platform C++ &lt;[cstdio](https://en.cppreference.com/w/cpp/header/cstdio)>

## the interface

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

    val pp_file : Format.formatter -> file -> unit
    val pp_err : Format.formatter -> errinfo -> unit
end
```
