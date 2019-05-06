source /opt/crc/Modules/current/init/sh
module load amber/18.0
MUT=$1
tleap -f - <<_EOF
source leaprc.protein.ff14SB
MAA = sequence { $MUT }
set MAA restype protein
set MAA head MAA.1.N
set MAA tail MAA.1.C
set MAA.1 connect0 MAA.1.N
set MAA.1 connect1 MAA.1.C
saveoff MAA MAA.lib
quit
_EOF
sed -i "s/$MUT/MAA/g" MAA.lib
