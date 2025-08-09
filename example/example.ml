open! Core
open! Async

let%hot hot () : unit =
  for i = 1 to 1 do
    Core.print_endline [%string "hello, world %{i#Int}"]
  done
;;

let main () =
  Clock_ns.every Time_ns.Span.second (fun () -> hot ());
  Deferred.never ()
;;

let () = Sriracha.with_hot_reloading main
