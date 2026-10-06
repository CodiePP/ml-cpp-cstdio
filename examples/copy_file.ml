(* Write a file, copy it in chunks through a buffer, read the copy back *)

open Mlcpp_cstdio
module F = Cstdio.File

let ok what = function
  | Ok x -> x
  | Error (errno, msg) -> failwith (Printf.sprintf "%s: %s (%d)" what msg errno)

(* copy src to dst, 4 bytes at a time to show the loop;
   with_file closes both files, also when fwrite fails *)
let copy src dst =
  F.with_file src "rb" @@ fun fin ->
  F.with_file dst "wb" @@ fun fout ->
  F.fold_chunks ~chunk:4 fin 0 (fun buf n total ->
      F.fwrite buf n fout |> ok "fwrite" |> ignore;
      total + n)

let () =
  let src = Filename.temp_file "mlcpp_cstdio_example" ".txt" in
  let dst = Filename.temp_file "mlcpp_cstdio_example" ".copy" in
  Fun.protect ~finally:(fun () ->
      Sys.remove src;
      Sys.remove dst)
  @@ fun () ->
  F.with_file src "wb" (F.fwrite_s "hello, cstdio!\n") |> ok "write" |> ignore;

  Printf.printf "copied %d bytes\n" (copy src dst |> ok "copy");
  assert (F.read_all dst |> ok "read copy" = "hello, cstdio!\n");

  (* errors carry the errno and its message *)
  match F.fopen (Filename.concat dst "missing") "r" with
  | Error (errno, msg) -> Printf.printf "fopen: %s (errno %d)\n" msg errno
  | Ok _ -> assert false
