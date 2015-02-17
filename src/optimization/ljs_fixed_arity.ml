open Prelude
open Ljs_syntax
open Ljs_opt

(* take out argument declaration exp, and return ordered formal
   parameter list *)
let trim_args (exp : exp) : id list * exp =
  let get_args e =
    match e with
    | GetField (_, Id (_, "%args"), String (_, index), _) ->
      begin try
        Some (int_of_string index)
      with
        _ -> None
      end
    | _ -> None
  in
  let get_order (args : (int * id) list) : id list =
    let rec fetch (cur : int) =
      try
        let x = List.assoc cur args in
        x :: fetch (cur+1)
      with
        _ -> []
    in
    fetch 0
  in
  let args : (int * id) list ref = ref [] in
  let rec trim exp : exp =
    match exp with
    | Let (pos, x, xv, body) ->
      begin match get_args xv with
        | Some (index) ->
          args := (index, x) :: !args;
          trim body
        | None ->
          Let (pos, x, trim xv, trim body)
      end
    | Lambda (_, _, _) -> exp
    | exp -> optimize trim exp
  in
  get_order !args, trim exp

let update_args (old_xs : id list) (new_xs : id list) =
  match old_xs with
  | hd :: tl when hd = "%this" ->
    hd :: new_xs
  | _ -> old_xs

(* mkArgsObj is called on an object which has the arguments as properties.
   This function will extract those arguments.
 *)
let parse_args_obj (args : exp list) : exp list option =
  let get_field_values (obj : exp) : exp list option =
    let rec get_values props = match props with
      | [] -> []
      | (s, Data({value=value}, _, _)) :: tl ->
        value :: get_values tl
      | (s, Accessor(_,_,_)) :: tl ->
        failwith "ArgsObj should not contain Accessor"
    in
    match obj with
    | Object (_, _, props) ->
      begin try
          Some (get_values props)
        with
          _ -> failwith (sprintf "ArgsObj pattern match failed: %s"
                           (Exp_util.ljs_str obj))
      end
    | _ -> None
  in
  match args with
  | match_this :: [App (_, Id (_, "%mkArgsObj"), [argobj])] ->
    begin match get_field_values argobj with
      | Some (lst) -> Some (match_this :: lst)
      | None -> None
    end
  | _ -> None

(* delete one field whose name is given by string fld *)
let delete_field (fld : string) (obj : exp) : exp =
  let rec delete (fld : string) (props : (string * prop) list) : (string * prop) list =
    match props with
    | [] -> []
    | (str, p) :: tl when str = fld -> delete fld tl
    | hd :: tl ->
      hd :: (delete fld tl)
  in
  match obj with
  | Object (p, a, props) ->
    Object (p, a, delete fld props)
  | _ -> obj
    
let fixed_arity (exp : exp) : exp =
  (* clean formal parameter *)
  let rec fixed_formal_parameter (exp : exp) : exp =
    (* clean related %args expression *)
    let rec clean_args (fbody : exp) : exp =
      let is_arg_delete (exp : exp) : bool = match exp with
        (* match %args[delete "%new"] *)
        | DeleteField(_, Id(_, "%args"), String (_, "%new")) -> true
        | _ -> false
      in
      let rec clean_arguments (exp : exp) : exp =
        (* clean "arguments" property in context *)
        match exp with
        | Let (p, "%context", xv, body) ->
          Let (p, "%context", clean_arguments xv, body)
        | Let (p, x, xv, body) ->
          Let (p, x, xv, clean_arguments body)
        | Object (_, _, _) -> delete_field "arguments" exp
        | Lambda (_, _, _) -> exp
        | _ -> optimize clean_arguments exp
      in
      match fbody with
      | Seq (_, e1, e2) when is_arg_delete e1 ->
        clean_arguments e2
      | _ -> fbody
    in
    match exp with
    | Lambda (pos, xs, body) ->
      (* take out those Let bindings in function body *)
      let args, new_body = trim_args body in
      (* make a new formal parameter list *)
      let new_xs = update_args xs args in
      (* clean %args in the body, and "arguments" property in context(if exists)*)
      let new_body = clean_args new_body in
      Lambda (pos, new_xs, fixed_formal_parameter new_body)
    | _ ->
      optimize fixed_formal_parameter exp
  in
  (* clean call site *)
  let rec fixed_call_site (exp : exp) : exp =
    match exp with
    | App (p, f, args) ->
      let f = fixed_call_site f in
      begin match parse_args_obj args with
      | Some (arg_list) ->
        App (p, f, arg_list)
      | None ->
        let args = List.map fixed_call_site args in
        App (p, f, args)
      end
    | _ -> optimize fixed_call_site exp
  in
  let e1 = fixed_formal_parameter exp in
  let e2 = fixed_call_site e1 in
  e2