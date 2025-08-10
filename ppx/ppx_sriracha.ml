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

let extract_param_type = function
  | { pparam_desc = Pparam_val (Nolabel, None, arg_pat); _ } ->
    let loc = arg_pat.ppat_loc in
    (match arg_pat with
     | [%pat? ([%p? _] : [%t? arg_type])] -> arg_type
     | [%pat? ()] -> [%type: unit]
     | _ ->
       Location.raise_errorf
         ~loc:arg_pat.ppat_loc
         "Unsupported function argument: all arguments must have a type annotation.")
  | { pparam_desc = Pparam_val (_, _, arg_pat); _ } ->
    Location.raise_errorf
      ~loc:arg_pat.ppat_loc
      "Unsupported function argument: labelled and optional arguments are not supported."
  | { pparam_desc = Pparam_newtype _; pparam_loc; _ } ->
    Location.raise_errorf
      ~loc:pparam_loc
      "Unsupported function argument: locally abstract types are not supported."
;;

let ghostify =
  object
    inherit Ppxlib.Ast_traverse.map
    method! location loc = { loc with loc_ghost = true }
  end
;;

let extension =
  Extension.V3.declare
    "hot"
    Structure_item
    Ast_pattern.(
      (* let $name = $body *)
      pstr (pstr_value nonrecursive (value_binding ~pat:__ ~expr:__ ^:: nil) ^:: nil))
    (fun ~ctxt name body ->
      let arg_types, return_type =
        match body.pexp_desc with
        | Pexp_function
            ( args
            , { mode_annotations = []
              ; ret_mode_annotations = []
              ; ret_type_constraint = Some (Pconstraint return_type)
              }
            , _ ) ->
          ( List.map
              ~f:(fun param : Ppxlib_jane.Shim.arrow_argument ->
                let type_ = extract_param_type param in
                { arg_label = Nolabel; arg_modes = []; arg_type = type_ })
              args
          , ({ result_modes = []; result_type = return_type }
             : Ppxlib_jane.Shim.arrow_result) )
        | Pexp_function
            ( _
            , { mode_annotations = []
              ; ret_mode_annotations = []
              ; ret_type_constraint = None
              }
            , _ ) ->
          Location.raise_errorf
            ~loc:name.ppat_loc
            "Unsupported function: must have a return type annotation."
        | Pexp_function _ ->
          Location.raise_errorf
            ~loc:name.ppat_loc
            "Unsupported function: mode annotations are not supported."
        | _ ->
          Location.raise_errorf
            ~loc:name.ppat_loc
            "Unsupported hot-reload value: must be a function with type annotations on \
             every argument and the return type."
      in
      let function_type =
        Ppxlib_jane.Ast_builder.Default.tarrow ~loc:name.ppat_loc arg_types return_type
      in
      let body =
        let loc = body.pexp_loc in
        [%expr
          Sriracha.register
            [%e body]
            ~__FUNCTION__
            [%e ghostify#expression @@ typerep function_type]
          |> Staged.unstage]
      in
      let loc =
        { (Expansion_context.Extension.extension_point_loc ctxt) with loc_ghost = true }
      in
      [%stri let [%p name] = [%e body]])
;;

let () = Driver.V2.register_transformation ~extensions:[ extension ] "sriracha"
