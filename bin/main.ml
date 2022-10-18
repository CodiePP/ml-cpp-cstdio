
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

let () =
    test1 ();
    test2 ()