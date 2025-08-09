open! Core
open! Async

let hot_impl () =
  for i = 1 to 2 do
    Core.print_endline [%string "hello, world %{i#Int}"]
  done
;;

let hot () = Sriracha.call hot_impl ()

let main () =
  Core.print_endline "helloooo";
  Clock_ns.every Time_ns.Span.second (fun () -> hot ());
  Deferred.never ()
;;

let () = Sriracha.enable_hot_reload ~main ~hot:hot_impl
