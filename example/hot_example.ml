open! Core

let main () =
  (* Notes from making this work:

     - dead code elimination can mean that sriracha doesn't get linked into the binary,
       which can cause the dlopen to fail. 

     - there's something difficult here about making sure dependencies of the loaded
       program get loaded properly... *)
  Sriracha.hot_reloader ()
;;
