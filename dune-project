(lang dune 3.17)

(name sriracha)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Matthew Else <matthewelse1997@gmail.com>")

(maintainers "Maintainer Name <matthewelse1997@gmail.com>")

(license MIT)

(documentation https://github.com/matthewelse/sriracha)

(package
 (name sriracha)
 (synopsis "🌶️ ⚡️ hot reloading ⚡️ for OCaml")
 (description "A hot reloading library for OCaml, built using Dynlink.")
 (depends ocaml dune ppx_jane ppxlib ppxlib_jane async core core_unix)
 (tags
  ("hot reloading")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
