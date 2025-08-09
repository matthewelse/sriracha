open! Core
open Ppxlib

let rec typerep (typ : core_type) : expression =
  (* ppx_typerep_conv doesn't support arrow types for some reason, so convert
     them ourselves. *)
  let loc = typ.ptyp_loc in
  match typ with
  | [%type: [%t? arg] -> [%t? res]] ->
    let arg = typerep arg in
    let res = typerep res in
    [%expr Typerep.Function ([%e arg], [%e res])]
  | other -> [%expr [%typerep_of: [%t other]]]
;;

let extension =
  Extension.V3.declare
    "hot"
    Structure_item
    Ast_pattern.(
      pstr (pstr_value nonrecursive (value_binding ~pat:__' ~expr:__ ^:: nil) ^:: nil))
    (fun ~ctxt:_ name body ->
      let loc = Location.none in
      let arg_type, return_type =
        match body.pexp_desc with
        | Pexp_function
            ( [ { pparam_desc = Pparam_val (Nolabel, None, arg_pat); _ } ]
            , { mode_annotations = []
              ; ret_mode_annotations = []
              ; ret_type_constraint = Some (Pconstraint return_type)
              }
            , _ ) ->
          let arg_type =
            match arg_pat with
            | [%pat? ([%p? _] : [%t? arg_type])] -> arg_type
            | [%pat? ()] -> [%type: unit]
            | _ ->
              Location.raise_errorf
                ~loc:arg_pat.ppat_loc
                "Unsupported function argument: all arguments must have a type \
                 annotation."
          in
          arg_type, return_type
        | Pexp_function
            ( [ { pparam_desc = Pparam_val (Nolabel, None, [%pat? (_ : [%t? _])]); _ } ]
            , { mode_annotations = []
              ; ret_mode_annotations = []
              ; ret_type_constraint = None
              }
            , _ ) ->
          Location.raise_errorf
            ~loc:name.loc
            "Unsupported function: must have a return type annotation."
        | Pexp_function (_ :: _ :: _, _, _) ->
          Location.raise_errorf
            ~loc:name.loc
            "Unsupported function: multiple arguments are not yet supported."
        | _ ->
          Location.raise_errorf
            ~loc:name.loc
            "Unsupported hot-reload value: must be a function with type annotations."
      in
      [%stri
        let [%p name.txt] =
          Sriracha.register
            [%e body]
            ~__FUNCTION__
            [%e typerep arg_type]
            [%e typerep return_type]
          |> Staged.unstage
        ;;])
;;

let () = Driver.V2.register_transformation ~extensions:[ extension ] "sriracha"
