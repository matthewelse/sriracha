open! Core
open! Async

exception Loaded of (unit -> unit Deferred.t)

module Thunk = struct
  type t =
    | T :
        { f : 'args -> 'res
        ; typerep : ('args -> 'res) Typerep.t
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
    on_error
      (Error.of_string "[with_hot_reloading] was not called by the hot-loaded function")
  with
  | Dynlink.Error (Library's_module_initializers_failed (Loaded main)) ->
    Core.print_endline "successfully reloaded!";
    f main
  | exn ->
    Core.eprint_s [%message "exception raised when loading" (exn : Exn.t)];
    on_error (Error.of_exn exn)
;;

let hot_reloader ~dynlib =
  Core.print_endline "- starting hot reloader -";
  Core.printf "loading: %s\n" dynlib;
  let%bind md5sum = Process.run_exn ~prog:"md5sum" ~args:[ dynlib ] () in
  let md5sum = ref md5sum in
  (* TODO: rip out all of the async code, and use threads instead *)
  (* I'm too lazy to make fswatch work, so just md5sum the file every time we reload, and
     if the file differs, reload. *)
  Deferred.forever () (fun () ->
    let%bind () = Clock_ns.after (Time_ns.Span.of_int_sec 2) in
    let%bind new_md5sum = Process.run_exn ~prog:"md5sum" ~args:[ dynlib ] () in
    if String.equal !md5sum new_md5sum
    then return ()
    else (
      md5sum := new_md5sum;
      let tmp_file = Filename_unix.temp_file "sriracha" "cmxs" in
      let%bind () =
        Process.run_expect_no_output_exn ~prog:"cp" ~args:[ dynlib; tmp_file ] ()
      in
      reload
        tmp_file
        ~f:(fun _ -> return ())
        ~on_error:(fun error ->
          Core.eprint_s [%message "error while reloading" (error : Error.t)];
          return ())));
  reload dynlib ~f:(fun main -> main ()) ~on_error:Error.raise
;;

let register (type a r) ~__FUNCTION__:func (f : a -> r) (f_typerep : (a -> r) Typerep.t) =
  (* TODO: check that this is compatible with the existing function in the jump table. If
     the types mismatch, you probably want to restart the main function or something
     drastic. *)
  Hashtbl.set jump_table ~key:func ~data:(T { f; typerep = f_typerep });
  Core.print_s [%message "set up jump table" (func : string)];
  Staged.stage (fun (arg : a) ->
    match Hashtbl.find jump_table func with
    | None -> f arg
    | Some (T { f; typerep }) ->
      let T = Typerep.same_witness_exn f_typerep typerep in
      f arg)
;;
