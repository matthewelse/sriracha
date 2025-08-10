open! Core
open! Async

let command =
  Command.async
    ~summary:"run an app with hot reloading"
    [%map_open.Command
      let cmxs = anon ("PATH" %: string) in
      fun () -> Sriracha.hot_reloader ~dynlib:cmxs]
;;
