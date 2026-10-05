# CI image for mlcpp_cstdio: build & test, sanitize (ASan/UBSan) and
# coverage (bisect_ppx, gcov).
#
# Stage 1 builds an opam switch with the compiler and the packages the build
# and tests need. Stage 2 copies only that switch (minus sources, docs and
# opam bookkeeping) onto a plain Debian base with a C++ toolchain, so the
# final image carries no opam, no build caches and no package sources.
#
# Debian (glibc) rather than Alpine (musl): the sanitize job needs libasan,
# which gcc does not support on musl.
#
# Build:  docker buildx build --platform linux/amd64,linux/arm64 -t code.sbclab.net/alex/mlcpp-cstdio-ci:5.3 -f docker/Dockerfile --push .
#         docker build --build-arg OCAML_VERSION=4.14.2 -t code.sbclab.net/alex/mlcpp-cstdio-ci:4.14 docker/


ARG DEBIAN_VERSION=trixie

FROM debian:${DEBIAN_VERSION}-slim AS build

ARG OCAML_VERSION=5.3.0
# Keep in sync with the build/test dependencies in lib/dune and test/dune.
ARG OPAM_PACKAGES="dune alcotest bisect_ppx"

RUN apt-get update \
 && apt-get install -y --no-install-recommends opam build-essential ca-certificates git curl rsync patch unzip bubblewrap \
 && rm -rf /var/lib/apt/lists/*

ENV OPAMROOT=/opt/opam \
    OPAMYES=1 \
    OPAMCONFIRMLEVEL=unsafe-yes \
    OPAMNODEPEXTS=1 \
    OPAMDOWNLOADJOBS=4

RUN opam init --bare --disable-sandboxing --no-setup \
 && opam switch create ci "ocaml-base-compiler.${OCAML_VERSION}" \
 && opam install --switch=ci ${OPAM_PACKAGES} \
 && opam clean --all-switches --download-cache --logs --repo-cache

# Drop what a CI build never touches: opam bookkeeping, docs, bytecode copies
# of the compilers, editor/annotation files and build-only tools.
RUN cd /opt/opam/ci \
 && rm -rf .opam-switch/sources .opam-switch/build .opam-switch/backup \
           doc man share/man \
           lib/ocamlbuild lib/topkg lib/ocaml/ocamldoc \
 && rm -f bin/*.byte bin/ocamlbuild* bin/topkg* bin/ocamldoc* \
 && find lib \( -name '*.cmt' -o -name '*.cmti' \) -delete

FROM debian:${DEBIAN_VERSION}-slim

# g++:        compile and link the C++ stubs (-lstdc++); ships libasan/libubsan
#             and pulls in gcc with gcov
# git/nodejs: needed by actions/checkout inside the job container
RUN apt-get update \
 && apt-get install -y --no-install-recommends g++ libc6-dev git nodejs ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -d /home/ci ci

# The OCaml compiler embeds its install prefix, so the switch must keep its path.
COPY --from=build /opt/opam/ci /opt/opam/ci

ENV OPAM_SWITCH_PREFIX=/opt/opam/ci \
    PATH=/opt/opam/ci/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    CAML_LD_LIBRARY_PATH=/opt/opam/ci/lib/stublibs:/opt/opam/ci/lib/ocaml/stublibs:/opt/opam/ci/lib/ocaml \
    OCAML_TOPLEVEL_PATH=/opt/opam/ci/lib/toplevel

USER ci
WORKDIR /home/ci

CMD ["dune", "--version"]
