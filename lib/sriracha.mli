open! Base
open! Import

module Main : sig
  (** [Main.t] represents the various different kinds of main functions that a loader
      could support. These may involve dependencies that sriracha shouldn't care about,
      e.g. [unit -> unit Deferred.t], but these are the concern of the loader, not the
      core of sriracha. *)

  type t = ..
end

(** Use this to specify the main entry-point to your program. This will be used by your
    hot loader as the main entry point to your app. *)
val start_with_hot_reloading
  :  Main.t
     (** this should be a constructor specific to your loader, e.g.
         [Hot_loader_async.Async main], or [Hot_loader_lwt.Lwt main]. *)
  -> unit

val add_reload_hook : (unit -> unit) -> unit

module For_loaders : sig
  module App : sig
    type t

    (** Access the main function. *)
    val main : t -> Main.t

    (** Hot-reload all of the app's hot-reloadable functions. *)
    val hot_reload : t -> unit Or_error.t
  end

  (** The main entry-point: load the provided sriracha-enabled library. *)
  val load_app : path_to_cmxs:string -> App.t
end

module For_ppx_sriracha : sig
  (** For internal use only. Use [let%hot my_function _ = _] instead. *)
  val register
    :  __FUNCTION__:string
    -> ('a -> 'r)
    -> ('a -> 'r) Typerep.t
    -> ('a -> 'r) Staged.t
  [@@alert use_ppx_sriracha]
end
