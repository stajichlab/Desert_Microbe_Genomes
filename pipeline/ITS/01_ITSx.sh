#!/usr/bin/bash -l
#SBATCH --mem 24gb -c 16 --out logs/ITSx.log

CPU=$SLURM_CPUS_ON_NODE
if [ -z $CPU ]; then
	CPU=1
fi

module load ITSx

mkdir -p ITS
pushd ITS

ln -s ../asm/AAFTF/JEM2.spades.fasta .
ln -s ../asm/AAFTF/JEM2.sorted.fasta .
ln -s ../asm/AAFTF/JEM1.spades.fasta .
ln -s ../asm/AAFTF/JEM1.sorted.fasta .

for file in $(ls *.sorted.fasta *.spades.fasta)
do
	ITSx -i $file -o $(basename $file .fasta) --nhmmer T --cpu $CPU --allow_reorder T -t fungi
done
