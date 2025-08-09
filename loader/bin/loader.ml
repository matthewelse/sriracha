let () =
  let (_ : unit Async.Deferred.t) = Hot_loader.main () in
  Async.Scheduler.go () |> Core.Nothing.unreachable_code
;;
