open Prelude
open Ljs_syntax
open Ljs_opt
open Ljs_alpha_rename
module EU = Exp_util


(*
[E/I](lam I' body) = lam I' [E/I] body
[E/I]let (I'=exp) body = let (I'=[E/I]exp) [E/I]body
   if I != I'
[E/I]let (I=exp) body) = let (I = [E/I]exp) body
   if 

*)

let debug_on = false

let dprint, dprint_string, dprint_ljs = Debug.make_debug_printer ~on:debug_on "propagate_nonconst"


(* Id => expression * free vars in expression *)
type env = (exp * IdSet.t) IdMap.t
let in_env x env = IdMap.mem x env
let have_intersection s1 s2 =
  not (IdSet.is_empty (IdSet.inter s1 s2))
(* For functions and objects, propagate those that are just used once.

   For expressions that may have side effect, be careful not alter the
   semantics.
*)

(* remove anything that contains id in free vars from env *)
let remove_id_value (id : id) (env : env) : env =
  let not_free (id : id) (value : (exp * IdSet.t)) =
    let _, s = value in
    not (IdSet.mem id s)
  in
  IdMap.filter not_free env

(* get current free variables in the env *)
let existing_names env : IdSet.t =
  IdMap.fold (fun str elm set ->
      let _, frees = elm in
      IdSet.union frees set
    ) env IdSet.empty

let rename_let x body namespace : id * exp * IdSet.t =
  if not (IdSet.mem x namespace) then
    x, body, namespace
  else
    let new_x, new_space = fresh_name x namespace in
    let new_body = alpha_rename body new_space in
    new_x, new_body, new_space


(* predicate for primitive constant *)
let is_prim_constant (e : exp) : bool = match e with
  | Null _
  | Undefined _
  | Num (_, _)
  | String (_, _)
  | True _
  | False _ -> true
  | _ -> false

(* constant lambda contains no free vars. Side effect in the body is fine *)
let is_lambda_constant (e: exp) : bool = match e with
  | Lambda (_, ids, body) ->
     IdSet.is_empty (free_vars e)
  | _ -> false

(* def_set stores the identifiers that are modified by assignment
   somewhere in their scopes, so any identifier that maps to such an
   id should not be appied copy propagation. This is a really
   conservative approximation.
*)
let propagate_nonconst (exp : exp) : exp =
  let rec propagate_rec (exp : exp) (env : env) (def_set : IdSet.t) : exp =
    let propagate e = propagate_rec e env def_set in
    match exp with
    | Id (_, id) -> begin try
          let e, _ = IdMap.find id env in
          e
        with _ -> exp
      end
    | Let (p, x, xexp, body) ->
      let x_v = propagate_rec xexp env def_set in
      (* rename current x into something else if necessary. *)
      let namespace = existing_names env in
      let x, body, namespace = rename_let x body namespace in
      (* x may or may be be renamed, so x could be rebound and might
         be able to propagate again. remove from the def_set *)
      let def_set = IdSet.remove x def_set in
      let _ = assert (not (IdSet.mem x def_set)) in
      (* if x is mutated in its scope, the x should not be propagated *)
      let def_set = if EU.mutate_var x body then 
          IdSet.add x def_set  (* add new_x instead of x *)
        else
          def_set 
      in
      let freevars = free_vars x_v in
      let is_mutated_in_body = IdSet.mem x def_set in
      if is_mutated_in_body || EU.multiple_usages x body then
        (* x_v has to be single-use form *)
        let _ = dprint "let(%s=...) is mutated or used multiple times in body\n" x in
        Let (p, x, x_v, propagate_rec body env def_set)
      else begin match is_mutated_in_body, not (EU.multiple_usages x body), x_v with
        | true, _, _ ->
          (* x is mutated in the body, don't propagate x *)
          let _ = dprint "do not propagate. let(%s=...) is mutated in body\n" x in
          Let (p, x, x_v, propagate_rec body env def_set)

        | _, _, x_v when (is_prim_constant x_v) || (is_lambda_constant x_v) ->
          let _ = dprint_string "don't propagate constant var and constant lambda.\n" in
          Let (p, x, x_v, propagate_rec body env def_set)
          
        (* --------- NOW: x is not mutated ----------*)
        (* use this to propagate constant

        | false, _ , x_v when is_prim_constant x_v ->
          (* x is a constant, used what-ever many times, propagate it *)
          let _ = dprint "%s is a constant, propagate" x in
          let env = IdMap.add x (x_v, freevars) env in
          Let (p, x, x_v, propagate_rec body env def_set)
        *)

        | false, true, Lambda (_, _, _) ->
          (* a single-use lambda, propagate it 
             NOTE: we DO allow the free variables of the function to
             get mutated in the scope
          *)
          let _  = dprint "match single-use lambda case for let (%s=...)\n" x in
          let env = IdMap.add x (x_v, freevars) env in
          Let (p, x, x_v, propagate_rec body env def_set)


        | false, true, x_v when IdSet.is_empty freevars ->
          (* a single-use expression does not contain free variables, just propagate it *)
          let _ = dprint_string "match expression that has no free variable. propagate it\n" in
          let env = IdMap.add x (x_v, freevars) env in
          Let (p, x, x_v, propagate_rec body env def_set)
            
        | false, true, x_v when have_intersection freevars def_set ->
          (* a single-use expression contains free variables and the
             free variables will be mutated, *)
          if EU.no_side_effect_prior_use x body then
            (* propagate it only when x is used before any side
               effect *)
            let _ = dprint "match no-side-effect-prior-use case for let (%s=..)\n" x in
            let env = IdMap.add x (x_v, freevars) env in
            Let (p, x, x_v, propagate_rec body env def_set)
          else
            let _ = dprint "cannot propagate let(%s=..) because it is used after side effect taking place\n" x in
            Let (p, x, x_v, propagate_rec body env def_set)

        | false, true, x_v when not (have_intersection freevars def_set) ->
          (* a single-use expression contains free variables and these free variables are
             not mutated. just propagate it *)
          let _ = dprint "%s's expression has no mutated free variable, safe to propagate\n" x in
          let env = IdMap.add x (x_v, freevars) env in
          Let (p, x, x_v, propagate_rec body env def_set)
            
        | mutate, single, x_v ->
          let _ = dprint_string (sprintf "mutated? %b\n" mutate) in
          let _ = dprint_string (sprintf "single? %b\n" single) in
          let _ = dprint_string (sprintf "intersect? %b\n" (have_intersection freevars def_set)) in
          let _ = dprint "cannot propagate let(%s=...), no case matched\n" x in 
          Let (p, x, x_v, propagate_rec body env def_set)
      end 
    | Rec (p, x, xexp, body) ->
      let namespace = existing_names env in
      let exp = alpha_rename exp namespace in
      let x, xexp, body = match exp with
        | Rec (_, x, xv, body) -> x, xv, body
        | _ -> failwith "nonreachable"
      in
      let def_set = IdSet.remove x def_set in
      let x_v = propagate_rec xexp env def_set in
      if (EU.mutate_var x xexp) || (EU.mutate_var x body) then
        let def_set = IdSet.add x def_set in
        Rec (p, x, x_v, propagate_rec body env def_set)
      else
        let def_set = IdSet.remove x def_set in
        Rec (p, x, x_v, propagate_rec body env def_set)
    | Lambda (p,xs,body) ->
      let namespace = existing_names env in
      let new_exp = alpha_rename exp namespace in
      let xs, body = match new_exp with 
        | Lambda(_, xs, body) -> xs, body
        | _ -> failwith "unreachable"
      in
      (* decide for each parameter whether it is modified in body:
          - if it does, add to def_set
          - if it does not, remove from def_set
      *)
      let def_set = List.fold_left
          (fun set x-> if EU.mutate_var x body then
              IdSet.add x set
            else
              IdSet.remove x set)
          def_set xs in
      Lambda (p, xs, propagate_rec body env def_set)
    | Undefined _ 
    | Null _ 
    | String (_, _)
    | Num (_, _)
    | True _ 
    | False _
    | Object (_,_,_) 
    | GetAttr (_, _, _, _)
    | GetObjAttr (_, _, _)
    | GetField (_, _, _, _)
    | Op1 (_,_,_)
    | Op2 (_,_,_,_)
    | If (_, _, _, _)
    | SetAttr (_,_,_,_,_)
    | SetObjAttr (_,_,_,_)
    | SetField (_,_,_,_,_)
    | DeleteField (_, _, _) 
    | OwnFieldNames (_,_)
    | SetBang (_,_,_)
    | App (_,_,_) 
    | Seq (_,_,_) 
    | Label (_,_,_)
    | Break (_,_,_)
    | TryCatch (_,_,_)
    | TryFinally (_,_,_)
    | Throw (_,_)
    | Hint (_,_,_)
      -> optimize propagate exp
  in
  propagate_rec exp IdMap.empty IdSet.empty
