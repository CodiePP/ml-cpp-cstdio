open Result
(* open Bigarray *)

module File = struct
    type cpp_file   (* internal *)
    type file = { ptr: cpp_file; fname: string; mode: string }
    type errinfo = (int * string)
    (* an error is indicated by the pair: errno, errstr where errno is != 0 *)

    module Buffer = struct
        (* type ta = (char, int8_unsigned_elt, c_layout) Array1.t *)
        type ta
        (* an array of bytes *)
        (* let create n = Bigarray.Array1.create Bigarray.char Bigarray.c_layout n *)
        external create : int -> ta = "cpp_buffer_create"
        external release : ta -> ta = "cpp_buffer_release"
        external resize : ta -> int -> unit = "cpp_buffer_resize"
        external good : ta -> bool = "cpp_buffer_good"
        external size : ta -> int = "cpp_buffer_size"
        external get : ta -> int -> char = "cpp_buffer_get"
        external set : ta -> int -> char -> unit = "cpp_buffer_set"
        let rec init' n f b =
            match n with
            | 0 -> b
            | i -> begin
                set b (i - 1) (f (i - 1)) |> ignore;
                init' (n - 1) f b
                end
        let init n f = (* Bigarray.Array1.init Bigarray.char Bigarray.c_layout n f *)
            let b = create n in
            init' n f b
        let to_string b =
            let len = size b in
            String.init len (fun i -> get b i)
        let from_string s =
            let len = String.length s in
            init len (fun i -> String.get s i)
        (* let size = Bigarray.Array1.dim *)
        external cpp_copy_sz_pos : ta -> int -> int -> ta -> int -> int = "cpp_copy_sz_pos"
        let copy_sz_pos b1 ~pos1:pos1 ~sz:sz b2 ~pos2:pos2 = cpp_copy_sz_pos b1 pos1 sz b2 pos2
        external copy_string : string -> ta -> int -> unit = "cpp_copy_string"
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

    external cpp_fwrite_s : string -> cpp_file -> (int * errinfo) = "cpp_fwrite_s"
    let fwrite_s s f = match cpp_fwrite_s s f.ptr with
        | (cnt, (0, _)) -> Ok cnt
        | (_, (errno, errstr)) -> Error (errno, errstr)

    external cpp_ferror : cpp_file -> errinfo = "cpp_ferror"
    let ferror f = cpp_ferror f.ptr

    external cpp_feof : cpp_file -> bool = "cpp_feof"
    let feof f = cpp_feof f.ptr

    let content64k fp fpos =
        if fpos < 0 then Error (-1, "file pos. cannot be negative")
        else
        let bsz = 64 * 1024 in
        fopen fp "rx" |> function
        | Error err -> Error err
        | Ok file -> begin
            fseek file fpos |> function
            | Error err -> Error err
            | Ok () -> begin
                let b = Buffer.create bsz in
                fread b bsz file |> function
                | Error err -> Error err
                | Ok n -> begin
                    let b' =
                        if n < bsz
                        then let b2 = Buffer.create n in
                             Buffer.copy_sz_pos b ~pos1:0 ~sz:n b2 ~pos2:0 |> ignore;
                             b2
                        else b in
                    fclose file |> function
                    | Error err -> Error err
                    | Ok () -> Ok b'
                    end
                end
            end

    let pp_file fmt f = Format.fprintf fmt "%s" @@ to_string f
    let pp_err fmt (eno,estr) = Format.fprintf fmt "%d/%s" eno estr

end (* File *)
