(** Files and byte buffers through C++ [<cstdio>].

    Errors are returned as [Error (errno, message)] ({!File.errinfo}):
    - [errno > 0]: the operating system's [errno], e.g. [2] (ENOENT) and its
      message
    - [-1]: invalid argument (released buffer, negative length or position)
    - [-99]: the file is closed (or failed to open)

    The end of a file is not an error: {!File.fread} returns [Ok 0].

    Files and buffers are not thread-safe: do not share one between threads or
    domains without a lock. *)

module File : sig
  (** A chunk of bytes on the C heap, outside of the OCaml heap. *)
  module Buffer : sig
    type ta

    val create : int -> ta
    (** [create n] is a buffer of [n] zero bytes. If the memory cannot be
        allocated, the buffer has size [0] (see {!good}).
        @raise Invalid_argument if [n < 0] *)

    val release : ta -> ta
    (** [release b] frees the memory of [b] now instead of when [b] is garbage
        collected, and returns [b], which is now empty: size [0], [good] is
        [false]. *)

    val resize : ta -> int -> unit
    (** [resize b n] grows [b] to [n] bytes, keeping its content; the new bytes
        are {b not} initialised. Does nothing if [n] is not larger than the
        current size, or if [b] was released. *)

    val good : ta -> bool
    (** [good b] is [true] if [b] holds memory: not released, size > 0. *)

    val init : int -> (int -> char) -> ta
    (** [init n f] is a buffer of [n] bytes, byte [i] set to [f i]. *)

    val to_string : ta -> string
    (** A copy of the whole buffer. *)

    val from_string : string -> ta
    (** A buffer holding a copy of the string. *)

    val sub_string : ta -> pos:int -> len:int -> string
    (** [sub_string b ~pos ~len] is a copy of [len] bytes of [b] at [pos].
        @raise Invalid_argument if the range is out of bounds *)

    val size : ta -> int

    val get : ta -> int -> char
    (** @raise Invalid_argument if the index is out of bounds *)

    val set : ta -> int -> char -> unit
    (** @raise Invalid_argument if the index is out of bounds *)

    val copy_sz_pos : ta -> pos1:int -> sz:int -> ta -> pos2:int -> int
    (** [copy_sz_pos b1 ~pos1 ~sz b2 ~pos2] copies [sz] bytes from [b1] at
        [pos1] to [b2] at [pos2] (the ranges may overlap) and returns [sz], or
        nothing is copied and it returns [-1] if [b1] is too short or released,
        [-2] if [b2] is too short or released, [-3] if [sz < 0], [-4] if
        [pos1 < 0], [-5] if [pos2 < 0]. *)

    val copy_string : string -> ta -> int -> unit
    (** [copy_string s b i] copies [s] into [b] at index [i].
        @raise Invalid_argument if [s] does not fit at [i] *)
  end

  type file
  type errinfo = int * string

  val to_string : file -> string
  (** ["name(mode)"] as given to {!fopen}. *)

  val fopen : string -> string -> (file, errinfo) result
  (** [fopen name mode] opens a file. [mode] is one of the C11 modes: ["r"],
      ["w"] or ["a"], optionally followed by ["+"] and ["b"], and ["x"] (fail if
      the file exists) with ["w"] only. Names or modes containing a NUL byte and
      other modes are rejected with [EINVAL]. *)

  val fclose : file -> (unit, errinfo) result
  (** Closing a closed file is an error ([-99]). A file that is never closed is
      closed when it is garbage collected. *)

  val fflush : file -> (unit, errinfo) result

  val fflush_all : unit -> (unit, errinfo) result
  (** Flushes all open output streams. *)

  val ftell : file -> (int, errinfo) result
  (** The current position in bytes. *)

  val fseek : file -> int -> (unit, errinfo) result
  (** Moves to an absolute position. *)

  val fseek_relative : file -> int -> (unit, errinfo) result
  (** Moves relative to the current position. *)

  val fseek_end : file -> int -> (unit, errinfo) result
  (** Moves relative to the end of the file. *)

  val fread : Buffer.ta -> int -> file -> (int, errinfo) result
  (** [fread b n f] reads up to [min n (Buffer.size b)] bytes into the start of
      [b] and returns how many were read: fewer near the end of the file, [0] at
      the end. *)

  val fwrite : Buffer.ta -> int -> file -> (int, errinfo) result
  (** [fwrite b n f] writes the first [min n (Buffer.size b)] bytes of [b] and
      returns how many were written. *)

  val fwrite_s : string -> file -> (int, errinfo) result
  (** Writes a string without copying it into a buffer first. *)

  val ferror : file -> errinfo
  (** [(0, "-")] if the error indicator of the file is not set. *)

  val feof : file -> bool
  (** [true] at the end of the file, and for a closed file. *)

  val content64k : string -> int -> (Buffer.ta, errinfo) result
  (** [content64k name pos] reads up to 64 KiB of the file [name] starting at
      byte [pos]; the buffer has the size of what was read, [0] if [pos] is at
      or beyond the end of the file. *)

  val with_file :
    string -> string -> (file -> ('a, errinfo) result) -> ('a, errinfo) result
  (** [with_file name mode f] opens the file, applies [f] and closes the file,
      also if [f] raises. An error of {!fclose} (which flushes) is returned if
      [f] succeeded. *)

  val fold_chunks :
    ?chunk:int ->
    file ->
    'a ->
    (Buffer.ta -> int -> 'a -> 'a) ->
    ('a, errinfo) result
  (** [fold_chunks ~chunk f init g] reads [f] from its current position to the
      end, [chunk] bytes at a time (default 64 KiB), and calls [g buf n acc] for
      each chunk: the first [n] bytes of [buf] are the data. [buf] is reused for
      the next chunk and released at the end; copy what you keep. *)

  val read_all : string -> (string, errinfo) result
  (** The whole content of a file. *)

  val pp_file : Format.formatter -> file -> unit
  val pp_err : Format.formatter -> errinfo -> unit
end
