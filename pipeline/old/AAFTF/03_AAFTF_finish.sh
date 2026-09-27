#!/usr/bin/bash -l
#SBATCH -N 1 -n 1 -c 24 --mem 64gb --out logs/AAFTF_finish.%a.log

# requires AAFTF 0.3.1 or later for full support of fastp options used

MEM=64
CPU=$SLURM_CPUS_ON_NODE
N=${SLURM_ARRAY_TASK_ID}

if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "Need an array id or cmdline val for the job"
        exit
    fi
fi

FASTQ=input
SAMPLEFILE=samples.csv
ASM=asm/AAFTF
WORKDIR=$SCRATCH
WORKDIR=working_AAFTF
PHYLUM=Ascomycota
mkdir -p $ASM $WORKDIR
if [ -z $CPU ]; then
    CPU=1
fi


module load AAFTF
export AAFTF_DB=/bigdata/stajichlab/shared/lib/AAFTF_DB

IFS=, # set the delimiter to be ,
#tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read ID BASE SRA SPECIES STRAIN FCS_TAXONID LOCUSTAG BIOPROJECT BIOSAMPLE NOTES
tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read ID FORWARD REVERSE
do
    if [[ "$NOTES" == "Too Low" ]]; then
        echo "skipping $N ($ID) as it is too low coverage ($NOTES)"
        continue
    fi
    FCS_GX=$ASM/${ID}.fcs_gx.fasta
    CLEANDUP=$ASM/${ID}.rmdup.fasta
    POLISHED=$ASM/${ID}.polished.fasta
    SORTED=$ASM/${ID}.sorted.fasta
    STATS=$ASM/${ID}.sorted.stats.txt
    DEPTH=$ASM/${ID}.depth.txt
    L=$FASTQ/$FORWARD
    R=$FASTQ/$REVERSE
    LEFT=$WORKDIR/${ID}_filtered_1.fastq.gz
    RIGHT=$WORKDIR/${ID}_filtered_2.fastq.gz
    MERGED=$WORKDIR/${ID}_filtered_U.fastq.gz

    if [[ ! -f $CLEANDUP && ! -f $CLEANDUP.gz ]]; then
        AAFTF rmdup -i $FCS_GX -o $CLEANDUP -c $CPU -m 500
    fi

    if [[ ! -f $POLISHED && ! -f $POLISHED.gz ]]; then
        if [ ! -f $CLEANDUP ]; then
            gunzip $CLEANDUP
        fi
        AAFTF polish --method polca -i $CLEANDUP -o $POLISHED -c $CPU --left $LEFT  --right $RIGHT --mem $MEM
    fi

    if [[ ! -f $POLISHED && ! -f $POLISHED.gz ]]; then
        echo "Error running Pilon, did not create file. Exiting"
        exit
    fi

    if [ ! -f $SORTED ]; then
        AAFTF sort -i $POLISHED -o $SORTED
        pigz $POLISHED
    fi

    if [ ! -f $STATS ]; then
        AAFTF assess -i $SORTED -r $STATS
    fi
    if [ ! -f $DEPTH ]; then
	    AAFTF depth -i $SORTED -l $LEFT -r $RIGHT -o $DEPTH 
    fi
done
