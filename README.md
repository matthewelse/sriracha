<h1 align="center">🌶️ <span style="font-family: monospace">sriracha</span> 🌶️</h1>

<p align="center">
  <i align="center">Type-safe hot reloading for OCaml 🐪🚀</i>
</p>

## Introduction

Sriracha is a library for type-safe hot-reloading of OCaml functions, inspired by
[subsecond](https://github.com/DioxusLabs/dioxus/tree/main/packages/subsecond).

## Usage

See [example](example/example.ml) for a working example.

🌶️ `sriracha` 🌶️ requires you to tweak the way you start your application, at
least when you want to run it for the purposes of live-reloading.

You should write a `main` function with type `unit -> unit Async.Deferred.t`, and
annotate any hot-reloadable functions with `let%hot`.

> Note that any hot-reloadable functions require explicit type annotations, and require
> `Core` and `ppx_typerep_conv` to be available (since we use `Typerep.t` to ensure
> type-safety under the hood).

```ocaml
open! Core
open! Async

let%hot reloadable () : unit =
  print_endline "hello, world!"
;;

let main () =
  Clock_ns.every Time_ns.Span.second (fun () -> do_something "hello, world!" ());
  Deferred.never ()
;;

let () = Sriracha.with_hot_reloading main
```

## Future functionality

- [ ] add a flag to `ppx_sriracha` to statically remove all of the hot-reloading points in
  release builds.

- [ ] handle nested function calls correctly (e.g. detect a new function being called
  within an old function.

