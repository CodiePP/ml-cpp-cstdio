
open Mlcpp_cstdio

let test1 () =
    let fres = Cstdio.File.fopen "/tmp/test101.txt" "wx" in
    match fres with
    | Ok f1 -> Printf.printf "OK file: %s\n" (Cstdio.File.to_string f1)
    | Error (errno, errstr) -> Printf.printf "Failure: %d %s\n" errno errstr

let test2 () =
    let b = Cstdio.File.Buffer.create 520 in
    let () = Cstdio.File.Buffer.set b 42 '!' in
    let c1 = Cstdio.File.Buffer.get b 42 in
    let () = Cstdio.File.Buffer.resize b 1293 in
    let c2 = Cstdio.File.Buffer.get b 42 in
    (* Printf.printf "%c = %c = '!' ? " c1 c2; *)
    let () = Cstdio.File.Buffer.set b 1042 '!' in
    let c3 = Cstdio.File.Buffer.get b 1042 in
    Printf.printf "%c = %c = %c = '!' ? " c1 c2 c3

let rec repeat_realloc n b =
    match n with
    | 0 -> ()
    | i -> let sz = Cstdio.File.Buffer.size b in
           Cstdio.File.Buffer.resize b (sz + 112);
           repeat_realloc (i - 1) b

let test3 () =
    let t0 = Sys.time() in
    let b = Cstdio.File.Buffer.create 540 in
    let () = repeat_realloc 1000000 b in
    let t1 = Sys.time() in
    Printf.printf "test: run time = %4.3fs\n" (t1 -. t0)

let test4 () =
    let m = "amore mio!" in
    let len = String.length m in
    let b = Cstdio.File.Buffer.init len (fun i -> String.get m i) in
    Cstdio.File.fopen "/tmp/hello_world42.txt" "wx" |> function
    | Ok fptr -> begin
        Cstdio.File.fwrite b len fptr |> function
        | Ok cnt -> Printf.printf "   written:%d\n" cnt
        | Error (errno,errstr) -> 
          Printf.printf "fwrite failed; no:%d err:%s\n" errno errstr;
        Cstdio.File.fclose fptr |> function
        | Ok _ -> Printf.printf "   fclose())\n"
        | Error (errno,errstr) -> 
          Printf.printf "fclose failed; no:%d err:%s\n" errno errstr
        end
    | Error (errno,errstr) -> 
        Printf.printf "fopen failed; no:%d err:%s\n" errno errstr

let () =
    test1 ();
    test2 ();
    test3 ();
    test4 ()