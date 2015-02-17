open Prelude
open Util
open OUnit2
open Ljs_fold_const

let suite = 
  let cmp before after = cmp before fold_const after in
  let no_change code = no_change code fold_const in
  let obj = "{[#proto: null, #extensible: false, #class: 'Object']
             'fld1': {#value 1, #writable false},
             'fld2': {#getter func(this, arg) {1}, #setter func(t) {t}}}" 
  in
  let sideeffect = "{[#proto: null, #extensible: false, #class: 'Object']
                    'fld1': {#value prim('pretty', 1), #writable false},
                    'fld2': {#getter func(this, arg) {1}, #setter func(t) {t}}}"
  in 
  "Test Const Folding" >:::
    [
      "fold getobjattr" >::
        (cmp (obj ^ "[<#extensible>]")
             "false");

      "fold getobjattr on side-effect obj" >::
        (no_change (sideeffect ^ "[<#extensible>]"));

      (* ---------------------------- *)
      "fold getattr" >::
        (cmp (obj ^ "['fld1'<#value>]")
             "1");

      "fold getattr field not present" >::
        (cmp (obj ^ "['fld3'<#value>]")
             "undefined");

      "fold getattr on side-effect object" >::
        (no_change (sideeffect ^ "['fld1'<#value>]"));
      
      (* ---------------------------- *)
      "get field" >::
        (cmp (obj ^ "['fld1']")
             "1");
      
      "get a field that has getter" >:: 
        (cmp (obj ^ "['fld2']")
             "func(this, arg){1}({[]})");

      "get a field on side-effect obj" >::
        (no_change (sideeffect ^ "['fld1']"));

      "get a field that not exists" >::
        (cmp (obj ^ "['fld3']")
             "undefined");

      (* ---------------------------- *)
      "op1" >::
        (cmp "prim('typeof', 1)"
             "'number'");

      "op1 given invalid argument" >::
        (no_change "prim('object-to-string', 1)");

      "op1 cannot be optimized" >::
        (no_change "prim('object-to-string', {[]})");

      "op1 has sideeffect" >::
        (no_change "prim('pretty', 1)");

      (* ---------------------------- *)
      "if" >::
        (cmp "if (prim('+',1,2)) {1} else {2}" "2");
      "if" >::
        (cmp "if (func(s){s}) {1} else {2}" "2");
      "if" >::
        (cmp "if ({[]}) {1} else {2}" "2");
      "if" >::
        (cmp "if ('') {1} else {2}" "2");
      "if" >::
        (cmp "if (1) {1} else {2}" "2");
      "if" >::
        (cmp "if (0) {1} else {2}" "2");
      "if" >::
        (no_change "if (prim('pretty', 1)) {1} else {2}");
      "if" >::
        (no_change "let (x=1) prim('+', x, 1)");

      "rec" >::
        (no_change "let (r = 1)
                    rec (r = func(t) { r(prim('-',t,1))})
                    r(x)");

      (* ------------------------------ *)
      "look through proto" >::
        (cmp "{[#extensible: false, 
                #proto: {[#extensible: false,
                          #proto: {[#extensible: false,
                                    #proto: {[#extensible: false,
                                              #proto: {[#extensible: false]}]}]
                                    'fld1': {#value 1, #writable false}}]
                          'fld2': {#value 2, #writable false}}]
               'fld3': {#value 3, #writable false}}['fld1']"
             "1");
                      
      "label and break" >::
      (cmp "label ret : {
            break ret {[]} }"
           "{[]}");


      "label and break" >::
      (no_change "label ret : {
                  if (t === 3) {
                     break ret {[]} 
                  } else {
                     break ret 1
                  }}");


    ]

let _ =
  run_test_tt_main suite