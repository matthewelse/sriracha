open! Core
open! Async

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
let with_hot_reloading main = raise (Loaded main)

let reload dynlib ~f ~on_error =
  Core.printf "loading: %s\n" dynlib;
  (* This is needed to stop [Ppx_expect_runtime] from complaining when we reload a file. *)
  (try (Ppx_expect_runtime.Current_file.unset [@alert "-ppx_expect_runtime"]) () with
   | _ -> ());
  try
    Dynlink.loadfile_private dynlib;
    on_error ()
  with
  | Dynlink.Error (Library's_module_initializers_failed (Loaded main)) ->
    Core.print_endline "successfully reloaded!";
    f main
  | exn ->
    Core.eprint_s [%message "exception raised when loading" (exn : Exn.t)];
    on_error ()
;;

let hot_reloader ~dynlib =
  Core.print_endline "- starting hot reloader -";
  Core.printf "loading: %s\n" dynlib;
  (* TODO: rip out all of the async code, and use threads instead *)
  Deferred.forever () (fun () ->
    let%bind () = Clock_ns.after (Time_ns.Span.of_int_sec 2) in
    let tmp_file = Filename_unix.temp_file "dynlib" "cmxs" in
    let%bind () =
      Process.run_expect_no_output_exn ~prog:"cp" ~args:[ dynlib; tmp_file ] ()
    in
    reload tmp_file ~f:(fun _ -> return ()) ~on_error:(fun () -> return ()));
  reload dynlib ~f:(fun main -> main ()) ~on_error:(fun () -> return ())
;;

let register
  (type a r)
  ~__FUNCTION__:func
  (f : a -> r)
  (arg_rep : a Typerep.t)
  (res_rep : r Typerep.t)
  =
  (* TODO: check that this is compatible with the existing function in the jump table. If
     the types mismatch, you probably want to restart the main function or something
     drastic. *)
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
