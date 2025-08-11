open! Core
open! Hot_loader_lwt

let html_to_string html = Format.asprintf "%a" (Tyxml.Html.pp ()) html

let%hot request_handler () : string =
  let open Tyxml in
  let html =
    [%html
      {|
    <html>
    <head><title>Home</title></head>
    <body>
      <h1>|}
        [ Html.txt "Good morning, world!" ]
        {|</h1>
    </body>
  </html>
    |}]
  in
  html_to_string html
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
