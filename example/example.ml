open! Core
open! Async

let hot_impl ()  =
  for i = 1 to 4 do
    Core.print_endline [%string "hello, world %{i#Int}"]
  done
;;

let hot =
  Sriracha.register hot_impl ~__FUNCTION__ [%typerep_of: unit] [%typerep_of: unit]
  |> Staged.unstage
;;

let main () =
  Core.print_endline "helloooo";
  Clock_ns.every Time_ns.Span.second (fun () -> hot ());
  Deferred.never ()
;;

let () = Sriracha.enable_hot_reload ~main
