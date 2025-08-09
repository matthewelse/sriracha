open! Core
open! Async

let hot_impl () =
  for i = 1 to 2 do
    Core.print_endline [%string "hello, world %{i#Int}"]
  done
;;

let hot =
  (* TODO: ppx'ify *)
  Sriracha.register hot_impl ~__FUNCTION__ [%typerep_of: unit] [%typerep_of: unit]
  |> Staged.unstage
;;

let main () =
  Clock_ns.every Time_ns.Span.second (fun () -> hot ());
  Deferred.never ()
;;

let () = Sriracha.with_hot_reloading main
