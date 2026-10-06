open Mlcpp_cstdio

let chunk = 64 * 1024

let time f =
  let t0 = Unix.gettimeofday () in
  let r = f () in
  (r, Unix.gettimeofday () -. t0)

let fail what (errno, errstr) =
  Printf.eprintf "%s failed: %d %s\n" what errno errstr;
  exit 1

let write_file fn total =
  match Cstdio.File.fopen fn "wb" with
  | Error e -> fail "fopen" e
  | Ok f ->
      let buf =
        Cstdio.File.Buffer.init chunk (fun i -> Char.chr (i land 0xff))
      in
      let rec go n =
        if n < total then
          match Cstdio.File.fwrite buf chunk f with
          | Error e -> fail "fwrite" e
          | Ok cnt -> go (n + cnt)
        else n
      in
      let n = go 0 in
      Cstdio.File.fclose f |> ignore;
      n

let read_file fn =
  match Cstdio.File.fopen fn "rb" with
  | Error e -> fail "fopen" e
  | Ok f ->
      let buf = Cstdio.File.Buffer.create chunk in
      let rec go n =
        match Cstdio.File.fread buf chunk f with
        | Ok 0 -> n (* end of file *)
        | Ok cnt -> go (n + cnt)
        | Error e -> fail "fread" e
      in
      let n = go 0 in
      Cstdio.File.fclose f |> ignore;
      n

let () =
  let mib =
    if Array.length Sys.argv > 1 then int_of_string Sys.argv.(1) else 256
  in
  let total = mib * 1024 * 1024 in
  let fn = Filename.temp_file "mlcpp_cstdio_bench" ".dat" in
  Fun.protect ~finally:(fun () -> Sys.remove fn) @@ fun () ->
  let report what (n, dt) =
    Printf.printf "%-6s %d MiB in %.3f s: %.1f MiB/s\n" what
      (n / 1024 / 1024)
      dt
      (float_of_int n /. 1048576. /. dt)
  in
  report "write" (time (fun () -> write_file fn total));
  report "read" (time (fun () -> read_file fn));
  let s = String.make (16 * 1024 * 1024) 'x' in
  let b, dt = time (fun () -> Cstdio.File.Buffer.from_string s) in
  report "from_string" (String.length s, dt);
  report "to_string"
    (time (fun () -> String.length (Cstdio.File.Buffer.to_string b)))
