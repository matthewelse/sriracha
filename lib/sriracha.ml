open! Core
open! Async

let witness = Type_equal.Id.create ~name:"sriracha" sexp_of_unit
let initial_load = ref true

exception Loaded of (unit -> unit Deferred.t)

module Thunk = struct
  type t =
    | T :
        { f : 'args -> 'res
        ; arg_typerep : 'args Typerep.t
        ; res_typerep : 'res Typerep.t
        }
        -> t
end

let jump_table : Thunk.t String.Table.t = String.Table.create ()

let enable_hot_reload ~main =
  Core.print_endline "- dynamic load -";
  raise (Loaded main)
;;

let hot_reloader () =
  Core.print_endline "- starting hot reloader -";
  let dynlib = "_build/default/example/example.cmxs" in
  Core.printf "loading: %s\n" dynlib;
  Deferred.forever () (fun () ->
    let%bind () = Clock_ns.after (Time_ns.Span.of_int_sec 2) in
    let new_file = [%string "new.cmxs"] in
    (* This is needed to stop [Ppx_expect_runtime] from complaining when we reload a file. *)
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

let register
  (type a r)
  ~__FUNCTION__:func
  (f : a -> r)
  (arg_rep : a Typerep.t)
  (res_rep : r Typerep.t)
  =
  Hashtbl.set
    jump_table
    ~key:func
    ~data:(T { f; arg_typerep = arg_rep; res_typerep = res_rep });
  Core.print_s [%message "set up jump table" (func : string)];
  Staged.stage (fun (arg : a) ->
    match Hashtbl.find jump_table func with
    | None -> f arg
    | Some (T { f; arg_typerep; res_typerep }) ->
      let T = Typerep.same_witness_exn arg_rep arg_typerep in
      let T = Typerep.same_witness_exn res_rep res_typerep in
      Core.print_s [%message "calling f via jump table"];
      f arg)
;;
