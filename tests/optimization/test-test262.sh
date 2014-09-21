#!/bin/sh

DIR=`dirname $0`
cd $DIR/..

if [ -x $1 ]
then
    echo "run through ch07-ch15 test cases in test262:\n usage: $0 <s5-options>"
    exit 1
fi 

chs="ch07 ch08 ch09 ch10 ch11 ch12 ch13 ch14 ch15"
log=test-test262.log
base=optimization/opt-test262-results
testscript=optimization/test-section.sh

rm -f $log
mkdir -p $base

for t in $chs
do
    echo "$t" >> $log
    $testscript nonstrict $t "$@" > $base/$t-nonstrict.txt

    echo "strict $t" >> $log
    $testscript strict $t "$@" > $base/$t-strict.txt
done
