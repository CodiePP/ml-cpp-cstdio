#!/bin/sh
# Test coverage of the OCaml code (bisect_ppx) and of the C++ stubs (gcov).
# Needs bisect_ppx installed; reports go to _coverage/.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

rm -rf _coverage
mkdir -p _coverage/ocaml _coverage/cxx
# recompile the stubs: dune removes the .gcno notes (not a declared target)
# as stale on later builds, and old .gcda counts would add up
rm -rf _build/default/lib

BISECT_FILE="$root/_coverage/ocaml/bisect" \
  dune runtest --force --profile coverage --instrument-with bisect_ppx

echo "OCaml (bisect_ppx):"
bisect-ppx-report summary --coverage-path _coverage/ocaml
bisect-ppx-report html --coverage-path _coverage/ocaml -o _coverage/ocaml/html

echo "C++ (gcov):"
# gcov finds the source relative to the directory it was compiled in
cd _build/default/lib
gcov cstdio.cxx >/dev/null
mv ./*.gcov "$root/_coverage/cxx/"
cd "$root"
# gcov's own summary counts the lines of a template once per instantiation
# with GCC (but not with clang): count every source line once instead.
# Lines are "count:line:source"; "-" is not executable, "#####"/"=====" not run.
awk -F: '
  $2 + 0 > 0 && !seen[$2 + 0]++ {
    c = $1; gsub(/[ *]/, "", c)
    if (c == "-") next
    total++
    if (c !~ /^(#####|=====)$/) run++
  }
  END { printf "Lines executed:%.2f%% of %d\n", 100 * run / total, total }
' _coverage/cxx/cstdio.cxx.gcov
echo "reports: _coverage/ocaml/html/index.html, _coverage/cxx/cstdio.cxx.gcov"
