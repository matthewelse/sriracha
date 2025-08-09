open! Core

let main () =
  (* Notes from making this work:

     - dead code elimination can mean that sriracha doesn't get linked into the binary,
       which can cause the dlopen to fail. 

     - there's something difficult here about making sure dependencies of the loaded
       program get loaded properly... 

     - I think the key will be to compile two versions of a library you want to hot reload:
       a static version (to ensure that all of your dependencies are linked correctly), and
       a dynamic version (to ensure that 
       *)
  Sriracha.hot_reloader ()
;;
