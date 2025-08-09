open! Core
open! Async

let witness = Type_equal.Id.create ~name:"sriracha" sexp_of_unit
let initial_load = ref true

exception Loaded of (unit -> unit Deferred.t)

let jump_table : (unit -> unit) or_null ref = ref Null

let enable_hot_reload ~main ~hot =
  Core.print_endline "- dynamic load -";
  jump_table := This hot;
  raise (Loaded main)
;;

let hot_reloader () =
  Core.print_endline "- starting hot reloader -";
  let dynlib = "_build/default/example/example.cmxs" in
  Core.printf "loading: %s\n" dynlib;
  Deferred.forever () (fun () ->
    let%bind () = Clock_ns.after (Time_ns.Span.of_int_sec 2) in
    let new_file = [%string "new.cmxs"] in
    (try Ppx_expect_runtime.Current_file.unset () with
     | _ -> ());
    (try Dynlink.loadfile_private new_file with
     | Dynlink.Error (Library's_module_initializers_failed (Loaded _)) ->
       Core.print_endline "successfully reloaded!"
     | exn -> Core.eprint_s [%message "exception raised when loading" (exn : Exn.t)]);
    return ());
  try
    Dynlink.loadfile_private dynlib;
    return ()
  with
  | Dynlink.Error (Library's_module_initializers_failed (Loaded main)) ->
    Core.print_endline "successfully loaded!";
    main ()
  | exn ->
    Core.eprint_s [%message "exception raised when loading" (exn : Exn.t)];
    return ()
;;

let call ~here:(_ : [%call_pos]) f arg =
  match !jump_table with
  | Null -> f arg
  | This f ->
    Core.print_s [%message "calling f via jump table"];
    f arg
;;
