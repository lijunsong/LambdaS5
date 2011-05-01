// Copyright 2009 the Sputnik authors.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/**
* @name: S15.10.4.1_A5_T7;
* @section: 15.10.4.1;
* @assertion: If F contains any character other than 'g', 'i', or 'm', or if it contains the same one more than once, then throw a SyntaxError exception;
* @description: Checking if using 1.0 as F leads to throwing the correct exception;
*/


// Converted for Test262 from original Sputnik source

ES5Harness.registerTest( {
id: "S15.10.4.1_A5_T7",

path: "15_Native\15.10_RegExp_Objects\15.10.4_The_RegExp_Constructor\S15.10.4.1_A5_T7.js",

assertion: "If F contains any character other than \'g\', \'i\', or \'m\', or if it contains the same one more than once, then throw a SyntaxError exception",

description: "Checking if using 1.0 as F leads to throwing the correct exception",

test: function testcase() {
   //CHECK#1
try {
	$ERROR('#1.1: new RegExp("^",1.0) throw SyntaxError. Actual: ' + (new RegExp("^",1.0)));
} catch (e) {
	if ((e instanceof SyntaxError) !== true) {
		$ERROR('#1.2: new RegExp("^",1.0) throw SyntaxError. Actual: ' + (e));
	}
}


 }
});
