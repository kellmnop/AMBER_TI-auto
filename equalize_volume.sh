#!/bin/bash

avg_vol=$(grep 'VOLUME' md3_eqNPT.out | tail -2 | head -1 | awk '{print $9}')
n1=$(tail -1 md3_eqNPT.rst | awk '{print $1}')
n2=$(tail -1 md3_eqNPT.rst | awk '{print $2}')
n3=$(tail -1 md3_eqNPT.rst | awk '{print $3}')
w=$(echo $n1 | cut -d '.' -f 1)
p=$(echo $n1 | cut -d '.' -f 2)

python << EOF
from re import sub
with open('md3_eqNPT.rst', 'r') as inFile:
	inText  = inFile.read()
dims = [$n1, $n2, $n3]
outText = inText.replace(str(min(dims)), '{:{w}.{p}f}'.format($avg_vol / (dims.pop(dims.index(max(dims))) * max(dims)), w=len("$w"), p=len("$p")))
with open('md3_eqNPT-eq.rst', 'w') as outFile:
	outFile.write(outText)
EOF
