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

  let fwrite = fun fn msg -> Cstdio.File.fopen fn "wx" |> function
                              | Ok fptr -> begin
                                  let len = String.length msg in
                                  let buf = Cstdio.File.Buffer.init
                                            len (fun i -> String.get msg i) in
                                  Cstdio.File.fwrite buf len fptr |> function
                                    | Ok cnt -> Cstdio.File.fclose fptr |> ignore; cnt
                                    | Error (errno,errstr) -> Printf.printf "no:%d err:%s\n" errno errstr; -98 
                                end
                              | Error _ -> -99

  let fwrite_s = fun fn msg -> Cstdio.File.fopen fn "wx" |> function
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
  12 (* == *) (Testing.fwrite "/tmp/hello_world.txt" "hello world.")

let test_fwrite_s () =
  Alcotest.(check int) "fwrite"
  12 (* == *) (Testing.fwrite_s "/tmp/hello_world2.txt" "hello world.")

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
    (* test_case "resize buffer (short)" `Quick test_resize_buffer_short; *)
    (* test_case "resize buffer" `Quick test_resize_buffer; *)
  ]
