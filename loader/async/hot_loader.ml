open! Core
open! Async

(* This is how you specify the main function of your app. *)
type Sriracha.Main.t += Async of (unit -> unit Deferred.t)

let before_reload () =
  (* This is a hack to make [Ppx_expect_runtime] happy. If we don't do this, we get an
     exception on startup. This seems fine since we're not running any tests. *)
  try (Ppx_expect_runtime.Current_file.unset [@alert "-ppx_expect_runtime"]) () with
  | _ -> ()
;;

let start_watching app =
  Clock_ns.every Time_ns.Span.second (fun () ->
    before_reload ();
    match Sriracha.For_loaders.App.hot_reload app with
    | Ok () -> eprintf "⚡️ hot reload ⚡️ successful\n%!"
    | Error err -> eprintf "🥵 error while hot reloading: %s\n" (Error.to_string_hum err))
;;

let command =
  Command.async
    ~summary:"run an app with hot reloading"
    [%map_open.Command
      let cmxs = anon ("PATH" %: string) in
      fun () ->
        let app = Sriracha.For_loaders.load_app ~path_to_cmxs:cmxs in
        start_watching app;
        let main = Sriracha.For_loaders.App.main app in
        match main with
        | Sriracha.Main.Sync f ->
          print_endline "⚡️ starting app with hot reloading ⚡️";
          f ();
          return ()
        | Async f -> f ()
        | _ -> failwith "Unsupported main function."]
;;
