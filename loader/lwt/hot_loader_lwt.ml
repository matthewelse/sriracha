open! Core
open! Lwt.Syntax

(* These modules unfortunately can't live in the application itself.

   [Make_typename] performs top-level effects that ultimately provides a type-equality
   witness between two values of the same type, so these need to run exactly once at
   startup, rather than every time we hot-reload the app. 

   TODO: are there any ways of making this less annoying for users? I don't see how we
   can do better than this without cursed syntactic things combined with [Obj.magic]? *)
module Lwt = struct
  module T = struct
    include Lwt

    include Typerep_lib.Make_typename.Make1 (struct
        type nonrec 'a t = 'a t

        let name = "Lwt.t"
      end)
  end

  include T

  let typerep_of_t (type a) (typerep_of_a : a Typerep.t) : a Lwt.t Typerep.t =
    Typerep.Named (named typerep_of_a, Second Value)
  ;;
end

(* This is how you specify the main function of your app. *)
type Sriracha.Main.t += Lwt of (unit -> unit Lwt.t)

let before_reload () =
  (* This is a hack to make [Ppx_expect_runtime] happy. If we don't do this, we get an
     exception on startup. This seems fine since we're not running any tests. *)
  try (Ppx_expect_runtime.Current_file.unset [@alert "-ppx_expect_runtime"]) () with
  | _ -> ()
;;

let rec start_watching app =
  let%lwt () = Lwt_unix.sleep 0.1 in
  before_reload ();
  (match Sriracha.For_loaders.App.hot_reload app with
   | Ok `reloaded -> Logs.info (fun log -> log "⚡️ hot reload ⚡️ successful")
   | Ok `unchanged -> Logs.debug (fun log -> log "⚡️ hot reload ⚡️ skipped")
   | Error err ->
     Logs.err (fun log -> log "Error while hot reloading: %s" (Error.to_string_hum err)));
  start_watching app
;;

let main cmxs =
  let app = Sriracha.For_loaders.load_app ~path_to_cmxs:cmxs in
  Lwt.dont_wait (fun () -> start_watching app) raise;
  let main = Sriracha.For_loaders.App.main app in
  match main with
  | Lwt f ->
    Logs.info (fun log -> log "⚡️ starting app with hot reloading ⚡️");
    f ()
  | _ -> failwith "Unsupported main function."
;;

let () = Findlib.init ()

let command =
  Command.basic
    ~summary:"run an app with hot reloading"
    [%map_open.Command
      let cmxs = anon ("PATH" %: string)
      and extra_libraries =
        flag "L" (listed string) ~doc:"LIBS additional libraries to dynamically load"
      in
      fun () ->
        Fl_dynload.load_packages extra_libraries;
        Lwt_main.run (main cmxs)]
;;
