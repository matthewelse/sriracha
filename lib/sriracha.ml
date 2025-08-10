open! Base
open! Import

let debug = false

module Main = struct
  type t = ..
end

exception Hot_reload of Main.t

let on_reload_hooks = ref []
let start_with_hot_reloading main = raise (Hot_reload main)
let add_reload_hook f = on_reload_hooks := f :: !on_reload_hooks

module App = struct
  type t =
    { path_to_cmxs : string
    ; mutable main : Main.t
    }

  let main t = t.main

  external mktemp : template:bytes -> unit = "mktemp" "mktemp" [@@noalloc]

  let load cmxs_path =
    try
      Dynlink.loadfile_private cmxs_path;
      Or_error.error_string
        "[with_hot_reloading] was not called by the hot-loaded function"
    with
    | Dynlink.Error (Library's_module_initializers_failed (Hot_reload main)) -> Ok main
    | Dynlink.Error (Inconsistent_import module_name) ->
      Or_error.error_string
        (Stdlib.Format.sprintf
           "A dependency ([%s]) of your hot-reloadable module was changed. You need to \
            restart."
           module_name)
    | exn -> Or_error.of_exn exn
  ;;

  let hot_reload t =
    if debug
    then Stdlib.print_endline (Stdlib.Format.sprintf "hot_reload! %s\n" t.path_to_cmxs);
    let tmpdir = Sys.getenv "TMPDIR" |> Option.value ~default:"/tmp/" in
    let tmp_path = Bytes.of_string (tmpdir ^ "sriracha.cmxs." ^ "XXXXXX") in
    mktemp ~template:tmp_path;
    let tmp_path = Bytes.to_string tmp_path in
    Unix.system (Stdlib.Format.sprintf "cp %s %s" t.path_to_cmxs tmp_path)
    |> (ignore : Unix.process_status -> unit);
    Or_error.map (load tmp_path) ~f:(fun main ->
      t.main <- main;
      List.iter !on_reload_hooks ~f:(fun hook -> hook ()))
  ;;
end

module Thunk = struct
  type t =
    | T :
        { f : 'args -> 'res
        ; typerep : ('args -> 'res) Typerep.t
        }
        -> t
end

let jump_table : (string, Thunk.t) Hashtbl.t = Hashtbl.create (module String)

module For_loaders = struct
  module App = App

  let load_app ~path_to_cmxs : App.t =
    let main = App.load path_to_cmxs |> Or_error.ok_exn in
    { path_to_cmxs; main }
  ;;
end

module For_ppx_sriracha = struct
  let register (type a r) ~__FUNCTION__:func (f : a -> r) (f_typerep : (a -> r) Typerep.t)
    =
    (* TODO: check that this is compatible with the existing function in the jump table. If
       the types mismatch, you probably want to restart the main function or something
       drastic. *)
    Hashtbl.set jump_table ~key:func ~data:(T { f; typerep = f_typerep });
    if debug then Stdlib.Format.printf "🚀 registered: [%s] 🚀\n%!" func;
    Staged.stage (fun (arg : a) ->
      match Hashtbl.find jump_table func with
      | None -> f arg
      | Some (T { f; typerep }) ->
        let T = Typerep.same_witness_exn f_typerep typerep in
        f arg)
  ;;
end
