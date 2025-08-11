open! Core
open! Hot_loader_lwt

let%hot request_handler () : string =
  Dream.random 3 |> Dream.to_base64url |> Printf.sprintf "Hello, world! Random tag: %s"
;;

let () =
  if [%reload_enabled]
  then
    Sriracha.start_with_hot_reloading
      (Lwt
         (fun () ->
           Dream.serve
           @@ Dream.logger
           @@ Live_reload.livereload
           @@ Dream.router [ Dream.get "/" (fun _ -> request_handler () |> Dream.html) ]))
;;
