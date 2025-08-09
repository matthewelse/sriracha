open! Core

let witness = Type_equal.Id.create ~name:"sriracha" sexp_of_unit
let initial_load = ref true

exception Loaded

let enable_hot_reload () =
  print_endline "- dynamic load -";
  raise Loaded
;;

let register impl = impl

let hot_reloader () =
  print_endline "attempting live reload";
  let dynlib = "_build/default/example2/example2.cmxs" in
  printf "loading: %s\n" dynlib;
  (try Dynlink.loadfile_private dynlib with
   | exn -> print_s [%message "exception raised while loading" (exn : Exn.t)]);
  print_endline "successfully loaded!"
