
let () =
  let open Alcotest in
  run "ML Cpp CStdio" [
    TestCStdio.test;
  ]