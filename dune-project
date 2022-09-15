(lang dune 3.4)

(name mlcpp_cstdio)

(generate_opam_files true)

(source
 (github CodiePP/ml-cpp-cstdio))

(authors "Alexander Diemand <codieplusplus@apax.net>")

(maintainers "Alexander Diemand <codieplusplus@apax.net>")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name mlcpp_cstdio)
 (synopsis "OCaml embedded C++ file input/output")
 (description "C++ cstdio is a cross-platform abstraction of file input/output now available in OCaml")
 (depends ocaml dune)
 (tags
  (topics "cross-platform file input/output abstraction" your project)))
