
module File :
sig
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

    val pp_file : Format.formatter -> file -> unit
    val pp_err : Format.formatter -> errinfo -> unit
end
