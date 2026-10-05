open Mlcpp_cstdio

let file_ok_t = Alcotest.testable Cstdio.File.pp_file ( = )
let file_err_t = Alcotest.testable Cstdio.File.pp_err ( = )


module Testing = struct
  let fopen = fun fn md -> Cstdio.File.fopen fn md |> function
                            | Ok _ -> true
                            | Error _ -> false
  let open_close = fun fn md -> Cstdio.File.fopen fn md |> function
                                 | Ok fptr -> begin
                                    Cstdio.File.fclose fptr |> function
                                                | Ok () -> true
                                                | Error (errno,errstr) -> 
                                                  Printf.printf "no:%d err:%s\n" errno errstr ; false
                                    end
                                 | Error _ -> false

  let fflush = fun fn md -> Cstdio.File.fopen fn md |> function
                                 | Ok fptr -> begin
                                    Cstdio.File.fflush fptr |> function
                                                | Ok _ -> true
                                                | Error (errno,errstr) -> 
                                                  Printf.printf "no:%d err:%s\n" errno errstr ; false
                                    end
                                 | Error _ -> false

  let fflush_all () = Cstdio.File.fflush_all () |> function
                       | Ok () -> true
                       | Error (errno,errstr) -> 
                         Printf.printf "no:%d err:%s\n" errno errstr ; false

  let ftell = fun fn md -> Cstdio.File.fopen fn md |> function
                            | Ok fptr -> begin
                               Cstdio.File.ftell fptr |> function
                                           | Ok floc -> floc
                                           | Error (errno,errstr) -> 
                                             Printf.printf "no:%d err:%s\n" errno errstr ; -2
                               end
                            | Error _ -> -1
  let fseek = fun fn md off -> Cstdio.File.fopen fn md |> function
                                | Ok fptr -> begin
                                  Cstdio.File.fseek fptr off |> function
                                              | Ok _ -> begin
                                                    Cstdio.File.ftell fptr |> function
                                                    | Ok floc -> floc
                                                    | Error (errno,errstr) -> 
                                                      Printf.printf "no:%d err:%s\n" errno errstr ; -3
                                                end
                                              | Error (errno,errstr) -> 
                                                Printf.printf "no:%d err:%s\n" errno errstr ; -2
                                  end |> ignore;
                                  Cstdio.File.fclose fptr |> ignore; 42
                                | Error _ -> -1

  let fseek_relative = fun fn md off1 off2 -> Cstdio.File.fopen fn md |> function
        | Ok fptr -> begin
          Cstdio.File.fseek fptr off1 |> function
            | Ok _ -> begin
              Cstdio.File.fseek_relative fptr off2 |> function
              | Ok _ -> begin
                Cstdio.File.ftell fptr |> function
                | Ok floc -> floc
                | Error (errno,errstr) -> 
                  Printf.printf "no:%d err:%s\n" errno errstr ; -4
                end
              | Error (errno,errstr) -> 
                Printf.printf "no:%d err:%s\n" errno errstr ; -3
              end
            | Error (errno,errstr) -> 
              Printf.printf "no:%d err:%s\n" errno errstr ; -2
          end
        | Error _ -> -1

  let fread = fun fn md n -> Cstdio.File.fopen fn md |> function
                              | Ok fptr -> begin
                                let buf = Cstdio.File.Buffer.create n in
                                Cstdio.File.fread buf n fptr |> function
                                 | Ok cnt -> cnt
                                   (* Printf.printf "  read:%s\n" (Cstdio.File.Buffer.to_string buf) ; -97 *)
                                 | Error (errno,errstr) -> 
                                   Printf.printf "no:%d err:%s\n" errno errstr ; -98
                                end
                              | Error _ -> -99

  let fwrite = fun fn msg -> Cstdio.File.fopen fn "wb" |> function
                              | Ok fptr -> begin
                                  let len = String.length msg in
                                  let buf = Cstdio.File.Buffer.init
                                            len (fun i -> String.get msg i) in
                                  Cstdio.File.fwrite buf len fptr |> function
                                    | Ok cnt -> Cstdio.File.fclose fptr |> ignore; cnt
                                    | Error (errno,errstr) -> Printf.printf "no:%d err:%s\n" errno errstr; -98 
                                end
                              | Error _ -> -99

  let fwrite_s = fun fn msg -> Cstdio.File.fopen fn "wb" |> function
                                | Ok fptr -> begin
                                  Cstdio.File.fwrite_s msg fptr |> function
                                  | Ok cnt -> Cstdio.File.fclose fptr |> ignore; cnt
                                  | Error (errno,errstr) -> Printf.printf "no:%d err:%s\n" errno errstr; -98
                                  end
                                | Error _ -> -99

  let copy_buffer_sz_pos = fun len1 sz pos len2 ->
      let b1 = Cstdio.File.Buffer.create len1 in
      let b2 = Cstdio.File.Buffer.create len2 in
      Cstdio.File.Buffer.copy_sz_pos b1 ~pos1:0 ~sz:sz b2 ~pos2:pos

  let copy_string = fun s ->
      let b = Cstdio.File.Buffer.create (String.length s) in
      Cstdio.File.Buffer.copy_string s b 0; b

end


(* a fresh file per test run, removed afterwards *)
let with_tmp_file f =
  let fn = Filename.temp_file "mlcpp_cstdio" ".dat" in
  Fun.protect ~finally:(fun () -> Sys.remove fn) (fun () -> f fn)

(* Tests *)

let test_open_existing () =
  (* Alcotest.(check (result file_ok_t file_err_t)) "fopen existing"
  (Ok _fptr) (* == *) (Testing.fopen "dune-project" "r") *)
  Alcotest.(check bool) "fopen existing"
  true (* == *) (Testing.fopen "test.ml" "r")

let test_open_unknown () =
  (* Alcotest.(check (result file_ok_t file_err_t)) "fopen unknown"
  (Error (en,es)) (* == *) (Testing.fopen "something-1940933.dat" "r") *)
  Alcotest.(check bool) "fopen unknown"
  false (* == *) (Testing.fopen "something-1940933.dat" "r")

let test_open_close_existing () =
  Alcotest.(check bool) "open&close existing"
  true (* == *) (Testing.open_close "test.ml" "r")

let test_open_close_unknown () =
  Alcotest.(check bool) "open&close unknown"
  false (* == *) (Testing.open_close "something-1940933.dat" "r")

let test_fflush_existing () =
  Alcotest.(check bool) "fflush existing"
  true (* == *) (Testing.fflush "test.ml" "r")

let test_fflush_unknown () =
  Alcotest.(check bool) "fflush unknown"
  false (* == *) (Testing.fflush "anything_goes-3902039149034.dat" "r")

let test_fflush_all () =
  Alcotest.(check bool) "fflush all"
  true (* == *) (Testing.fflush_all ())

let test_ftell_existing () =
  Alcotest.(check int) "ftell existing"
  0 (* == *) (Testing.ftell "test.ml" "r")

let test_ftell_unknown () =
  Alcotest.(check int) "ftell unknown"
  (-1) (* == *) (Testing.ftell "anything_goes-1390490239034.dat" "r")

let test_fseek_existing () =
  Alcotest.(check int) "fseek existing"
  42 (* == *) (Testing.fseek "test.ml" "r" 42)
  
let test_fseek_relative_existing () =
  Alcotest.(check int) "fseek existing"
  47 (* == *) (Testing.fseek_relative "test.ml" "r" 42 5)

let test_fseek_relative2_existing () =
  Alcotest.(check int) "fseek existing"
  37 (* == *) (Testing.fseek_relative "test.ml" "r" 42 (-5))

let test_fread_existing () =
  Alcotest.(check int) "fread existing"
  81 (* == *) (Testing.fread "test.ml" "r" 2100)

let test_fwrite () =
  Alcotest.(check int) "fwrite"
  12 (* == *) (with_tmp_file @@ fun fn -> Testing.fwrite fn "hello world.")

let test_fwrite_s () =
  Alcotest.(check int) "fwrite"
  12 (* == *) (with_tmp_file @@ fun fn -> Testing.fwrite_s fn "hello world.")

let test_copy_buffer_all () =
  Alcotest.(check int) "copy buffer"
  10 (* == *) (Testing.copy_buffer_sz_pos 10 10 0 10)

let test_copy_buffer_src_short () =
  Alcotest.(check int) "copy buffer"
  (-1) (* == *) (Testing.copy_buffer_sz_pos 5 10 0 10)

let test_copy_buffer_tgt_short1 () =
  Alcotest.(check int) "copy buffer"
  (-2) (* == *) (Testing.copy_buffer_sz_pos 10 10 0 5)

let test_copy_buffer_tgt_short2 () =
  Alcotest.(check int) "copy buffer"
  (-2) (* == *) (Testing.copy_buffer_sz_pos 10 10 1 10)

let test_resize_buffer_short () =
  Alcotest.(check int) "resize buffer short"
  (6) (* == *) (Cstdio.File.Buffer.init 6 (fun i -> String.get "hello." i) |>
                    (fun b -> Cstdio.File.Buffer.resize b 3; b) |>
                    Cstdio.File.Buffer.size
                   )

let test_resize_buffer () =
  Alcotest.(check char) "resize buffer"
  ('o') (* == *) (Cstdio.File.Buffer.init 6 (fun i -> String.get "hello." i) |>
                    (fun b -> Cstdio.File.Buffer.resize b 66; b) |>
                    (fun b -> Cstdio.File.Buffer.get b 4)
                   )

let test_create_many_buffers () =
  Alcotest.(check string) "create many buffers"
  ("√") (* == *) (for _i = 0 to 999 do
                   (Cstdio.File.Buffer.create 10000000 |>
                    Cstdio.File.Buffer.release |> ignore)
                 done; "√")

let test_copy_string () =
  Alcotest.(check string) "copy string"
  ("hello world!") (* == *) (Testing.copy_string "hello " |>
                    (fun b -> Cstdio.File.Buffer.resize b 12; b) |>
                    (fun b -> Cstdio.File.Buffer.copy_string "world!" b 6;
                    Cstdio.File.Buffer.to_string b)
                   )

(* Regression tests for the security fixes *)

let errno_of = function
  | Ok _ -> 0
  | Error (errno, _) -> errno

let test_fread_negative_length () =
  Alcotest.(check int) "fread negative length"
  (-1) (* == *) (Cstdio.File.fopen "test.ml" "r" |> function
                 | Error _ -> -99
                 | Ok fptr ->
                   let buf = Cstdio.File.Buffer.create 16 in
                   let r = Cstdio.File.fread buf (-1) fptr in
                   Cstdio.File.fclose fptr |> ignore;
                   errno_of r)

let test_fwrite_negative_length () =
  Alcotest.(check int) "fwrite negative length"
  (-1) (* == *) (with_tmp_file @@ fun fn ->
                 Cstdio.File.fopen fn "wb" |> function
                 | Error _ -> -99
                 | Ok fptr ->
                   let buf = Cstdio.File.Buffer.create 16 in
                   let r = Cstdio.File.fwrite buf (-1) fptr in
                   Cstdio.File.fclose fptr |> ignore;
                   errno_of r)

let test_use_after_fclose () =
  Alcotest.(check (list int)) "use after fclose"
  [0; -99; -99; -99; -99; -99] (* == *)
  (with_tmp_file @@ fun fn ->
   Cstdio.File.fopen fn "wb" |> function
   | Error _ -> []
   | Ok fptr ->
     let buf = Cstdio.File.Buffer.create 16 in
     let closed = Cstdio.File.fclose fptr |> errno_of in
     let closed2 = Cstdio.File.fclose fptr |> errno_of in
     let rd = Cstdio.File.fread buf 16 fptr |> errno_of in
     let wr = Cstdio.File.fwrite buf 16 fptr |> errno_of in
     let wrs = Cstdio.File.fwrite_s "hello" fptr |> errno_of in
     let (err, _) = Cstdio.File.ferror fptr in
     [closed; closed2; rd; wr; wrs; err])

let test_feof_after_fclose () =
  Alcotest.(check bool) "feof after fclose"
  true (* == *) (Cstdio.File.fopen "test.ml" "r" |> function
                 | Error _ -> false
                 | Ok fptr ->
                   Cstdio.File.fclose fptr |> ignore;
                   Cstdio.File.feof fptr)

let test_fopen_nul_in_name () =
  Alcotest.(check bool) "fopen NUL in file name"
  false (* == *) (Testing.fopen "test.ml\000../../etc/passwd" "r")

let test_fopen_invalid_mode () =
  Alcotest.(check (list bool)) "fopen modes"
  [false; false; false; false; true; true; true; false] (* == *)
  (* test.ml is read-only in _build, so open a writable temp file *)
  (with_tmp_file @@ fun fn ->
   List.map (fun md -> Testing.open_close fn md)
     ["rx"; "re"; "r\000"; ""; "rb"; "r+b"; "a+"; "ax"])

let all_bytes = String.init 256 Char.chr

let test_buffer_binary_roundtrip () =
  Alcotest.(check string) "bytes 0x00..0xff round-trip"
  all_bytes (* == *) (Cstdio.File.Buffer.from_string all_bytes |> Cstdio.File.Buffer.to_string)

let test_fwrite_fread_binary () =
  Alcotest.(check string) "binary write & read back"
  all_bytes (* == *)
  (with_tmp_file @@ fun fn ->
   (Cstdio.File.fopen fn "wb" |> function
    | Error _ -> ()
    | Ok fptr ->
      Cstdio.File.fwrite_s all_bytes fptr |> ignore;
      Cstdio.File.fclose fptr |> ignore);
   Cstdio.File.content64k fn 0 |> function
   | Error (_, errstr) -> errstr
   | Ok buf -> Cstdio.File.Buffer.to_string buf)

let test_buffer_get_oob () =
  let b = Cstdio.File.Buffer.create 4 in
  Alcotest.check_raises "get index too big"
    (Invalid_argument "Buffer.get: index out of bounds")
    (fun () -> Cstdio.File.Buffer.get b 4 |> ignore);
  Alcotest.check_raises "get negative index"
    (Invalid_argument "Buffer.get: index out of bounds")
    (fun () -> Cstdio.File.Buffer.get b (-1) |> ignore)

let test_buffer_set_oob () =
  let b = Cstdio.File.Buffer.create 4 in
  Alcotest.check_raises "set index too big"
    (Invalid_argument "Buffer.set: index out of bounds")
    (fun () -> Cstdio.File.Buffer.set b 4 'x')

let test_buffer_released () =
  let b = Cstdio.File.Buffer.create 4 |> Cstdio.File.Buffer.release in
  Alcotest.check_raises "get on released buffer"
    (Invalid_argument "Buffer.get: index out of bounds")
    (fun () -> Cstdio.File.Buffer.get b 0 |> ignore);
  Alcotest.(check int) "copy from released buffer"
  (-1) (* == *) (Cstdio.File.Buffer.copy_sz_pos b ~pos1:0 ~sz:0 (Cstdio.File.Buffer.create 4) ~pos2:0)

let test_copy_string_oob () =
  let b = Cstdio.File.Buffer.create 4 in
  Alcotest.check_raises "copy_string negative index"
    (Invalid_argument "Buffer.copy_string: out of bounds")
    (fun () -> Cstdio.File.Buffer.copy_string "ab" b (-1));
  Alcotest.check_raises "copy_string too long"
    (Invalid_argument "Buffer.copy_string: out of bounds")
    (fun () -> Cstdio.File.Buffer.copy_string "abc" b 2);
  Alcotest.check_raises "copy_string index overflow"
    (Invalid_argument "Buffer.copy_string: out of bounds")
    (fun () -> Cstdio.File.Buffer.copy_string "ab" b max_int)

let test_copy_overflow () =
  (* pos + sz used to overflow and pass the bounds checks *)
  let b1 = Cstdio.File.Buffer.create 10 in
  let b2 = Cstdio.File.Buffer.create 10 in
  Alcotest.(check (list int)) "copy_sz_pos overflowing sizes"
  [-1; -2] (* == *)
  [Cstdio.File.Buffer.copy_sz_pos b1 ~pos1:1 ~sz:max_int b2 ~pos2:0;
   Cstdio.File.Buffer.copy_sz_pos b1 ~pos1:0 ~sz:5 b2 ~pos2:max_int]

let test_copy_errors_gc () =
  (* failing copies used to leave dangling GC roots behind *)
  let fails = ref 0 in
  for _i = 1 to 1000 do
    if Testing.copy_buffer_sz_pos 5 10 0 10 = -1 then incr fails;
    ignore (Sys.opaque_identity (List.init 100 string_of_int))
  done;
  Gc.full_major ();
  Alcotest.(check int) "failing copies and GC" 1000 !fails

(* Runner *)

let test =
  let open Alcotest in
  "ML Cpp CStdio",
  [
    test_case "create many buffers" `Quick test_create_many_buffers;
    test_case "open existing file" `Quick test_open_existing;
    test_case "open unknown file" `Quick test_open_unknown;
    test_case "open&close unknown file" `Quick test_open_close_unknown;
    test_case "open&close existing file" `Quick test_open_close_existing;
    test_case "fflush existing file" `Quick test_fflush_existing;
    test_case "fflush unknown file" `Quick test_fflush_unknown;
    test_case "fflush_all" `Quick test_fflush_all;
    test_case "ftell existing file" `Quick test_ftell_existing;
    test_case "ftell unknown file" `Quick test_ftell_unknown;
    test_case "fseek existing file" `Quick test_fseek_existing;
    test_case "fseek (relative+) existing file" `Quick test_fseek_relative_existing;
    test_case "fseek (relative-) existing file" `Quick test_fseek_relative2_existing;
    test_case "fread on existing file" `Quick test_fread_existing;
    test_case "fwrite buffer to file" `Quick test_fwrite;
    test_case "fwrite string to file" `Quick test_fwrite_s;
    test_case "copy string" `Quick test_copy_string;
    test_case "copy complete buffer" `Quick test_copy_buffer_all;
    test_case "copy from short buffer" `Quick test_copy_buffer_src_short;
    test_case "copy to short buffer" `Quick test_copy_buffer_tgt_short1;
    test_case "copy to short buffer" `Quick test_copy_buffer_tgt_short2;
    test_case "fread negative length" `Quick test_fread_negative_length;
    test_case "fwrite negative length" `Quick test_fwrite_negative_length;
    test_case "use after fclose" `Quick test_use_after_fclose;
    test_case "feof after fclose" `Quick test_feof_after_fclose;
    test_case "fopen NUL in file name" `Quick test_fopen_nul_in_name;
    test_case "fopen invalid modes" `Quick test_fopen_invalid_mode;
    test_case "buffer binary round-trip" `Quick test_buffer_binary_roundtrip;
    test_case "fwrite/fread binary" `Quick test_fwrite_fread_binary;
    test_case "buffer get out of bounds" `Quick test_buffer_get_oob;
    test_case "buffer set out of bounds" `Quick test_buffer_set_oob;
    test_case "released buffer" `Quick test_buffer_released;
    test_case "copy_string out of bounds" `Quick test_copy_string_oob;
    test_case "copy_sz_pos overflow" `Quick test_copy_overflow;
    test_case "failing copies and GC" `Quick test_copy_errors_gc;
    (* test_case "resize buffer (short)" `Quick test_resize_buffer_short; *)
    (* test_case "resize buffer" `Quick test_resize_buffer; *)
  ]
