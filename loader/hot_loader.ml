open! Core
open! Async

let command =
  (* Notes from making this work:

     - dead code elimination can mean that sriracha doesn't get linked into the binary,
       which can cause the dlopen to fail. 

     - there's something difficult here about making sure dependencies of the loaded
       program get loaded properly... 

     - I think the key will be to compile two versions of a library you want to hot reload:
       a static version (to ensure that all of your dependencies are linked correctly), and
       a dynamic version (to ensure that
  *)
  Command.async
    ~summary:"run an app with hot reloading"
    [%map_open.Command
      let cmxs = anon ("PATH" %: string) in
      fun () -> Sriracha.hot_reloader ~dynlib:cmxs]
;;
