// Copyright 2009 the Sputnik authors.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/**
* @name: S15.3.4.3_A8_T3;
* @section: 15.3.4.3;
* @assertion: Function.prototype.apply can`t be used as [[create]] caller;
* @description: Checking if creating "new Function.apply" fails;
*/


// Converted for Test262 from original Sputnik source

ES5Harness.registerTest( {
id: "S15.3.4.3_A8_T3",

path: "15_Native\15.3_Function_Objects\15.3.4_Properties_of_the_Function_Prototype_Object\15.3.4.3_Function.prototype.apply\S15.3.4.3_A8_T3.js",

assertion: "Function.prototype.apply can`t be used as [[create]] caller",

description: "Checking if creating \"new Function.apply\" fails",

test: function testcase() {
   try {
  obj = new Function.apply;
  $ERROR('#1: Function.prototype.apply can\'t be used as [[create]] caller');
} catch (e) {
  if (!(e instanceof TypeError)) {
  	$ERROR('#1.1: Function.prototype.apply can\'t be used as [[create]] caller');
  }
}

 }
});
