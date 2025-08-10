open! Core
open! Async

let%hot do_something (prefix : string) () : unit =
  for i = 1 to 3 do
    print_endline [%string "%{prefix} %{i#Int}"]
  done
;;

let main () =
  Clock_ns.every Time_ns.Span.second (fun () -> do_something "hello, world!" ());
  Deferred.never ()
;;

let () = Sriracha.start_with_hot_reloading (Hot_loader.Async main)
