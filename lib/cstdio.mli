
module File :
sig
    module Buffer :
    sig
      type ta
      val create : int -> ta
      val init : int -> (int -> char) -> ta
      val to_string : ta -> string
      val from_string : string -> ta
      val size : ta -> int
      val get : ta -> int -> char
      val set : ta -> int -> char -> unit
      val copy_sz_pos : ta -> int -> int -> ta -> int -> int
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
    val ferror : file -> errinfo
    val feof : file -> bool

    val content64k : string -> int -> (Buffer.ta, errinfo) result

    val pp_file : Format.formatter -> file -> unit
    val pp_err : Format.formatter -> errinfo -> unit
end
