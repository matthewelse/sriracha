open! Core
open! Hot_loader_lwt

let%hot request_handler () : Dream.response Lwt.t =
  Dream.random 3
  |> Dream.to_base64url
  |> Printf.sprintf "Hello, world! Random tag: %s"
  |> Dream.html
;;

let () =
  Sriracha.start_with_hot_reloading
    (Lwt
       (fun () ->
         Dream.run
         @@ Dream.logger
         @@ Live_reload.livereload
         @@ Dream.router [ Dream.get "/" (fun _ -> request_handler ()) ];
         Lwt.return_unit))
;;
