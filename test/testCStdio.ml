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
                                  end
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

(* Runner *)

let test =
  let open Alcotest in
  "ML Cpp CStdio",
  [
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
  ]