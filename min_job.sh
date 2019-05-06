top=$(pwd)
run=$top/run
type=$1
N=$2
MD_inputs=$top/$3
tmpls=$(ls $MD_inputs | cut -d '.' -f 1)
JOB_inputs=$top/$4
lambda_step=$5

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
for window in `seq 0.00 $lambda_step 1.00`; do
	cd $window
	for file in $tmpls; do
		sed "s/%L%/$window/" "$MD_inputs/$file.tmpl" | sed "s/%R%/$R/" | sed "s/%TS1%/$ts1/g" | sed "s/%TS2%/$ts2/g" | sed "s/%NS%/$ns/" > "$file.in"
	done
	for job in prep prod; do
		sed  "s/%N%/$N-$window/" $JOB_inputs/$job.job | sed  "s/%R%/$R/" | sed  "s/%W%/$window/g" > "$job.job"
	done
	ln -sf "$top/INPCRDwat_$type-merged.inpcrd" ./TI-merged_WAT.inpcrd
	ln -sf "$top/PRMTOPwat_$type-merged.prmtop" ./TI-merged_WAT.prmtop
	ln -sf "$top/equalize_volume.sh" ./equalize_volume.sh
	ln -sf "$top/RCA.sh" ./RCA.sh
	qsub <<-_EOF
			#!/bin/bash
			#$ -N $N-$window
			#$ -pe smp 8-32
			#$ -M gkeller1@nd.edu
			#$ -m ae
			#$ -q long
			source /afs/crc.nd.edu/x86_64_linux/Modules/3.2.10/init/bash
			pI=/afs/crc.nd.edu/x86_64_linux/a/amber/16.0/intel/17.1/ompi-2.1.1/amber18/bin/pmemd.MPI
			module purge
			# Increase the MPI buffer
			export P4_GLOBMEMSIZE=268435456
			module load amber/18.0
			mpirun -np \$NSLOTS \$pI -O -i md0_min1.in -o md0_min1.out -r md0_min1.rst -p TI-merged_WAT.prmtop -c TI-merged_WAT.inpcrd -ref TI-merged_WAT.inpcrd
			mpirun -np \$NSLOTS \$pI -O -i md0_min2.in -o md0_min2.out -r md0_min2.rst -p TI-merged_WAT.prmtop -c md0_min1.rst
			_EOF

	cd $run/$type
done
