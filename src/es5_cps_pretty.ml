open Prelude
open Es5_cps

open Format
open FormatExt

let rec vert_intersperse a lst = match lst with
  | [] -> []
  | [x] -> [x]
  | x :: xs -> squish [x; a] :: (vert_intersperse a xs)

let rec value v = match v with
  | Null _ -> text "null"
  | Undefined _ -> text "undefined"
  | Num (_,n) -> text (string_of_float n)
  | String (_,s) -> text ("\"" ^ s ^ "\"")
  | True _ -> text "true"
  | False _-> text "false"
  | Id (p, x) -> text x
  | Object (p, avs, props) ->
    braces (vert [attrsv avs; vert (vert_intersperse (text ",") (map prop props))])
  | Lambda (p, ret, exn, xs, e) ->
    vert [squish [text "lam"; parens (horz (text "Ret" :: text ret :: text "," ::
                                              text "Exn" :: text exn :: text ";" :: 
                                              (intersperse (text ",") (map text xs))))];
          braces (exp e)]

and prim p = match p with
  | GetAttr (p, a, o, f) ->
    squish [text o;
            brackets (horz [text f; angles (horz [text (Es5_syntax.string_of_attr a)])])]
  | SetAttr (p, a, o, f, v) ->
    squish [text o;
            brackets (squish [text f; angles (horz [text (Es5_syntax.string_of_attr a)]);
                              text "="; text v])]
  | SetBang (p, x, e) ->
    horz [text x; text "<-"; text e]
  | Op1 (p, op, e) -> 
    squish [text "prim"; parens (horz [text ("\"" ^ op ^ "\","); text e])]
  | Op2 (p, op, e1, e2) ->
    squish [text "prim"; parens (horz [text ("\"" ^ op ^ "\","); text e1; text ","; text e2])]
  | DeleteField (p, o, f) ->
    squish [text o; brackets (horz [text "delete"; text f])]

and exp e = match e with
  | LetValue (p, x, v, body) ->
    vert [horz [text "letVal"; vert [parens (horz [text x; text "="; value v])]];
          horz [text "in"; vert [exp body]]]
  | LetPrim (p, x, pr, body) ->
    vert [horz [text "letPrim"; vert [parens (horz [text x; text "="; prim pr])]];
          horz [text "in"; vert [exp body]]]
  | LetRetCont (ret, x, e, body) ->
    vert [horz [text "letRet"; horz [text ret; parens (text x); text "="]; vert [exp e]];
          horz [text "in"; vert [exp body]]]
  | LetExnCont (exn, x, l, e, body) ->
    vert [horz [text "letExn"; horz [text exn; parens (horz [text x; text l]); text "="; vert [exp e]]];
          horz [text "in"; vert [exp body]]]
  | SetField (p, o, f, v, args, ret, exn) ->
    squish [text o; 
            brackets (horz [text f; text "="; text v; text ","; text args]); 
            brackets (horz [text ret; text "or"; text exn])]
  | GetField (p, o, f, args, ret, exn) ->
    squish [text o; 
            brackets (horz [text f; text ","; text args]); 
            brackets (horz [text ret; text "or"; text exn])]
  | If (p, c, t, e) -> 
    horz [text "if"; vert [parens (horz [text c]);
                           braces (exp t);
                           text "else";
			   (match e with
			   | If _ -> (exp e)
			   | _ -> braces (exp e))]]
  | AppFun (p, f, ret, exn, args) ->
    horz [squish [text f; parens (squish (text "Ret " :: text ret :: text ", " ::
                                   text "Exn " :: text exn :: text "; " :: 
                                   intersperse (text ", ") (map text args)))]]
  | AppRetCont (r, x) ->
    horz [squish [text r; parens (horz [text x])]]
  | AppExnCont (e, x, l) ->
    horz [squish [text e; parens (horz [text x ; text ","; text l])]]
  | Rec (p, x, e, body) -> 
    vert [horz [text "rec"; vert [parens (horz [text x; text "="; text e])]];
          horz [text "in"; vert [exp body]]]
  | Eval (p, s) -> 
      squish [text "@eval"; parens (exp s)]

and attrsv { proto = p; code = c; extensible = b; klass = k } =
  let proto = match p with None -> [] 
    | Some e -> [horz [text "#proto:"; text e]] in
  let code = match c with None -> [] 
    | Some e -> [horz [text "#code:"; text e]] in
  brackets (vert (map (fun x -> squish [x; (text ",")])
                  (proto@
                    code@
                    [horz [text "#class:"; text ("\"" ^ k ^ "\"")]; 
                     horz [text "#extensible:"; text (string_of_bool b)]])))
              
(* TODO: print and parse enum and config *)
and prop (f, prop) = match prop with
  | Data ({value=v; writable=w}, enum, config) ->
    horz [text ("'" ^ f ^ "'"); text ":"; braces (horz [text "#value"; 
                                          text v; text ","; 
                                          text "#writable";  
                                          text (string_of_bool w);
                                          text ",";
                                          text "#configurable";
                                          text (string_of_bool config)])]
  | Accessor ({getter=g; setter=s}, enum, config) ->
    horz [text ("'" ^ f ^ "'"); text ":"; braces (horz [text "#getter";
                                          text g; text ",";
                                          text "#setter";
                                          text s])]

