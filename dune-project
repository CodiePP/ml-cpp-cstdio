(lang dune 3.4)

(name mlcpp_cstdio)

(generate_opam_files true)

(source
 (github CodiePP/ml-cpp-cstdio))

(authors "Alexander Diemand <codieplusplus@apax.net>")

(maintainers "Alexander Diemand <codieplusplus@apax.net>")

(license "Apache-2.0")

(documentation https://github.com/CodiePP/ml-cpp-cstdio/blob/main/docs)

(package
 (name mlcpp_cstdio)
 (synopsis "OCaml embedded C++ file input/output")
 (description "Files and byte buffers on the C heap through C++ <cstdio>, for OCaml on Linux and macOS")
 (depends
  (ocaml (>= 4.14))
  dune
  (alcotest :with-test))
 (tags
  (files io stdio buffers bindings c++)))
