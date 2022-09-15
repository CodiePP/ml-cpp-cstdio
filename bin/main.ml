
open Mlcpp_cstdio

let () =
    let fres = Cstdio.File.fopen "/tmp/test101.txt" "wx" in
    match fres with
    | Ok f1 -> Printf.printf "OK file: %s\n" (Cstdio.File.to_string f1)
    | Error (errno, errstr) -> Printf.printf "Failure: %d %s\n" errno errstr
