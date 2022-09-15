open Result

module File = struct
    type cpp_file
    type file = { ptr: cpp_file; fname: string; mode: string }
    type errinfo = (int * string)

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

    let pp_file fmt f = Format.fprintf fmt "%s" @@ to_string f
    let pp_err fmt (eno,estr) = Format.fprintf fmt "%d/%s" eno estr

end (* File *)
