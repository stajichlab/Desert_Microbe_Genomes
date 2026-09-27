#!/usr/bin/bash -l
#SBATCH -N 1 -n 1 -c 64 -p short --mem 500gb --out logs/AAFTF_clean_fcsgx.log
hostname
SRC=/srv/projects/db/ncbi-fcs/0.5.4/gxdb
DEST=/dev/shm
CPU=$SLURM_CPUS_ON_NODE

SAMPLEFILE=samples.csv
ASM=asm/AAFTF
WORKDIR=$SCRATCH

if [ -z $CPU ]; then
    CPU=1
fi


module load AAFTF
IFS=, # set the delimiter to be ,
FCS_TAXONID=4751
tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read ID FORWARD REVERSE
do
    VECCLEAN=$ASM/${ID}.vecscreen.fasta
    FCS_GX=$ASM/${ID}.fcs_gx.fasta
    if [[ ! -s $VECCLEAN ]]; then
        echo "Error, missing vecscreen file for $ID, skipping"
        continue
    fi
    if [[ -s $FCS_GX ]]; then
        echo "Already have FCS_GX file for $ID, skipping"
        continue
    fi

    rsync -a --progress $SRC $DEST
    AAFTF fcs_gx_purge -i $VECCLEAN -o $FCS_GX -c $CPU --db $DEST/gxdb/all -t $FCS_TAXONID
done

rm -rf $DEST/gxdb
