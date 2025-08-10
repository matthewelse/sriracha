open! Core
open! Async

let%hot hot (prefix : string) () : unit =
  for i = 1 to 5 do
    Core.print_endline [%string "%{prefix} %{i#Int}"]
  done
;;

let main () =
  Clock_ns.every Time_ns.Span.second (fun () -> hot "hello, world!" ());
  Deferred.never ()
;;

let () = Sriracha.with_hot_reloading main
