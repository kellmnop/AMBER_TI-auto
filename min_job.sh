top=$(pwd)
run=$top/run
type=$1
N=$2
MD_inputs=$top/$3
tmpls=$(ls $MD_inputs | cut -d '.' -f 1)
JOB_inputs=$top/$4
windows="$5"
dt=$6
mbar_states=$(echo "$windows" | sed "s/ /\n/g" | wc -l)
mbl=$(echo "$windows" | sed 's/ /, /g')
source /opt/crc/Modules/current/init/sh
module load amber/18.0

cpptraj -p PRMTOPwat_$type-merged.prmtop <<-_EOF
		parmstrip :WAT,Na+,Cl- nobox outprefix nowat
		parmwrite out PRMTOPnowat_$type-merged.prmtop
		run
		quit
_EOF
ts1=$(grep 'timask1' $top/merge_$type.out | cut -d '=' -f 2)
ts2=$(grep 'timask2' $top/merge_$type.out | cut -d '=' -f 2)
ns_=$(echo $ts1 | tr -d "'")$(echo $ts2 | tr -d "'" | tr -d "@")
ns=${ns_::-1}
R=$(head -n 7 $top/PRMTOPnowat_$type-merged.prmtop | tail -1 | tr -s ' ' | cut -d ' ' -f 2)

cd $run/$type
for window in $windows; do
	cd $window
	for file in $tmpls; do
		sed "s/%L%/$window/" "$MD_inputs/$file.tmpl" | sed "s/%R%/$R/" | sed "s/%TS1%/$ts1/g" | sed "s/%TS2%/$ts2/g" | sed "s/%NS%/$ns/" | sed "s/%DT%/$dt/" | sed "s/%WIN%/$mbl/" | sed "s/%MBS%/$mbar_states/" > "$file.in"
	done
	for job in prep prod; do
		sed  "s/%N%/$N-$window/" $JOB_inputs/$job.job | sed  "s/%R%/$R/" | sed  "s/%W%/$window/g" > "$job.job"
	done
	ln -sf "$top/INPCRDwat_$type-merged.inpcrd" ./TI-merged_WAT.inpcrd
	ln -sf "$top/PRMTOPwat_$type-merged.prmtop" ./TI-merged_WAT.prmtop
	ln -sf "$top/equalize_volume.sh" ./equalize_volume.sh
	ln -sf "$top/RCA.sh" ./RCA.sh
	qsub prep.job
	cd $run/$type
done
