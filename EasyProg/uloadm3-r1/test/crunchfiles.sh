#!/bin/sh

EXO="exoraw -q -c -m 256"
PROGRESS="/bin/echo -n ."

$PROGRESS ; $EXO -o bitmap0.exo bitmap0.prg
$PROGRESS ; $EXO -o bitmap1.exo bitmap1.prg
$PROGRESS ; $EXO -o bitmap2.exo bitmap2.prg
$PROGRESS ; $EXO -o bitmap3.exo bitmap3.prg
$PROGRESS ; $EXO -o bitmap4.exo bitmap4.prg
$PROGRESS ; $EXO -o bitmap5.exo bitmap5.prg
$PROGRESS ; $EXO -o bitmap6.exo bitmap6.prg
$PROGRESS ; $EXO -o bitmap7.exo bitmap7.prg
$PROGRESS ; $EXO -o bitmap8.exo bitmap8.prg
$PROGRESS ; $EXO -o bitmap9.exo bitmap9.prg

echo
