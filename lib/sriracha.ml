open! Core

let witness = Type_equal.Id.create ~name:"sriracha" sexp_of_unit
let initial_load = ref true

exception Loaded of (unit -> unit)

let enable_hot_reload ~main =
  print_endline "- dynamic load -";
  raise (Loaded main)
;;

let hot_reloader () =
  print_endline "- starting hot reloader -";
  let dynlib = "_build/default/example/example.cmxs" in
  printf "loading: %s\n" dynlib;
  try Dynlink.loadfile_private dynlib with
  | Dynlink.Error (Library's_module_initializers_failed (Loaded main)) ->
    print_endline "successfully loaded!"
    ;
    main ()
;;
