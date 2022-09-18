open Result
open Bigarray

module File = struct
    type cpp_file   (* internal *)
    type file = { ptr: cpp_file; fname: string; mode: string }
    type errinfo = (int * string)
    (* an error is indicated by the pair: errno, errstr where errno is != 0 *)

    module Buffer = struct
        type ta = (char, int8_unsigned_elt, c_layout) Array1.t
        (* an array of bytes *)
        let create n = Bigarray.Array1.create Bigarray.char Bigarray.c_layout n
        let init n f = Bigarray.Array1.init Bigarray.char Bigarray.c_layout n f
        let to_string a = let len = Bigarray.Array1.dim a in
            String.init len (fun i -> Bigarray.Array1.get a i)
        let size = Bigarray.Array1.dim
        let get = Bigarray.Array1.get
        let set = Bigarray.Array1.set
    end

    let to_string file = file.fname ^ "(" ^ file.mode ^ ")"
    external cpp_fopen : string -> string -> (cpp_file * errinfo) = "cpp_fopen"
    let fopen fn mode = match cpp_fopen fn mode with
        | (fptr, (0, _)) -> Ok { ptr = fptr; fname = fn; mode = mode }
        | (_, (errno, errstr)) -> Error (errno, errstr)

    external cpp_fclose : cpp_file -> errinfo = "cpp_fclose"
    let fclose f = match cpp_fclose f.ptr with
        | (0, _) -> Ok ()
        | (errno, errstr) -> Error (errno, errstr)

    external cpp_fflush : cpp_file -> errinfo = "cpp_fflush"
    let fflush f = match cpp_fflush f.ptr with
        | (0, _) -> Ok ()
        | (errno, errstr) -> Error (errno, errstr)

    external cpp_fflush_all : unit -> errinfo = "cpp_fflush_all"
    let fflush_all () = match cpp_fflush_all () with
        | (0, _) -> Ok ()
        | (errno, errstr) -> Error (errno, errstr)

    external cpp_ftell : cpp_file -> (int * errinfo) = "cpp_ftell"
    let ftell f = match cpp_ftell f.ptr with
        | (floc, (0, _)) -> Ok (floc)
        | (_, (errno, errstr)) -> Error (errno, errstr)

    external cpp_fseek : cpp_file -> int -> errinfo = "cpp_fseek"
    let fseek f n = match cpp_fseek f.ptr n with
        | (0, _) -> Ok ()
        | (errno, errstr) -> Error (errno, errstr)
    external cpp_fseek_relative : cpp_file -> int -> errinfo = "cpp_fseek_relative"
    let fseek_relative f n = match cpp_fseek_relative f.ptr n with
        | (0, _) -> Ok ()
        | (errno, errstr) -> Error (errno, errstr)
    external cpp_fseek_end : cpp_file -> int -> errinfo = "cpp_fseek_end"
    let fseek_end f n = match cpp_fseek_end f.ptr n with
        | (0, _) -> Ok ()
        | (errno, errstr) -> Error (errno, errstr)

    external cpp_fread : Buffer.ta -> int -> cpp_file -> (int * errinfo) = "cpp_fread"
    let fread a n f = match cpp_fread a n f.ptr with
        | (cnt, (0, _)) -> Ok cnt
        | (_, (errno, errstr)) -> Error (errno, errstr)

    external cpp_fwrite : Buffer.ta -> int -> cpp_file -> (int * errinfo) = "cpp_fwrite"
    let fwrite a n f = match cpp_fwrite a n f.ptr with
        | (cnt, (0, _)) -> Ok cnt
        | (_, (errno, errstr)) -> Error (errno, errstr)

    external cpp_ferror : cpp_file -> errinfo = "cpp_ferror"
    let ferror f = cpp_ferror f.ptr

    external cpp_feof : cpp_file -> bool = "cpp_feof"
    let feof f = cpp_feof f.ptr


    let pp_file fmt f = Format.fprintf fmt "%s" @@ to_string f
    let pp_err fmt (eno,estr) = Format.fprintf fmt "%d/%s" eno estr

end (* File *)
