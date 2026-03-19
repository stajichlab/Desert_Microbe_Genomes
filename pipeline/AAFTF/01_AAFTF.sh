#!/usr/bin/bash -l
#SBATCH -N 1 -n 1 -c 24 --mem 64gb --out logs/AAFTF.%a.log

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
mkdir -p $ASM $WORKDIR
if [ -z $CPU ]; then
    CPU=1
fi


module load AAFTF
export AAFTF_DB=/bigdata/stajichlab/shared/lib/AAFTF_DB
module load fastp
IFS=, # set the delimiter to be ,
tail -n +2 $SAMPLEFILE | sed -n ${N}p | while read ID FORWARD REVERSE
do
    ASMFILE=$ASM/${ID}.spades.fasta
    VECCLEAN=$ASM/${ID}.vecscreen.fasta

    if [[ ! -s $SORTED ]]; then
        LEFTIN=$FASTQ/$FORWARD
        RIGHTIN=$FASTQ/$REVERSE
	echo "$L $R"
        LEFTTRIM=$WORKDIR/${ID}_1P.fastq.gz
        RIGHTTRIM=$WORKDIR/${ID}_2P.fastq.gz
        MERGETRIM=$WORKDIR/${ID}_fastp_MG.fastq.gz

        # these are final processed files for assembly
        LEFT=$WORKDIR/${ID}_filtered_1.fastq.gz
        RIGHT=$WORKDIR/${ID}_filtered_2.fastq.gz
        MERGED=$WORKDIR/${ID}_filtered_U.fastq.gz

        echo "$BASE $ID $STRAIN"
        echo "left=$LEFTIN right=$RIGHTIN leftrim=$LEFTTRIM rightrim=$RIGHTTRIM"
        if [ ! -f $LEFT ]; then
            if [ ! -f $LEFTTRIM ]; then
            # this should all be merged into AAFTF as one step
                AAFTF trim --method fastp --dedup --merge --memory $MEM --left $LEFTIN --right $RIGHTIN -c $CPU -o $WORKDIR/${ID}_fastp
		echo "$WORKDIR/${ID}_fastp_1P.fastq.gz is left"
                AAFTF trim --method fastp --cutright -c $CPU --memory $MEM \
                    --left $WORKDIR/${ID}_fastp_1P.fastq.gz --right $WORKDIR/${ID}_fastp_2P.fastq.gz \
                    -o $WORKDIR/${ID}_fastp2
                AAFTF trim --method bbduk -c $CPU --memory $MEM \
                    --left $WORKDIR/${ID}_fastp2_1P.fastq.gz \
                    --right $WORKDIR/${ID}_fastp2_2P.fastq.gz \
                    -o $WORKDIR/${ID}
            fi
            AAFTF filter -c $CPU --memory $MEM -o $WORKDIR/${ID} --left $LEFTTRIM --right $RIGHTTRIM --aligner bbduk
            AAFTF filter -c $CPU --memory $MEM -o $WORKDIR/${ID} --left $MERGETRIM --aligner bbduk
            if [ -f $LEFT ]; then
                rm -f $LEFTTRIM $RIGHTTRIM $WORKDIR/${ID}_fastp*
                echo "found $LEFT"
            else
                echo "did not create left file ($LEFT $RIGHT)"
                exit
            fi
        fi
        if [ ! -f $ASMFILE ]; then # can skip we already have made an assembly
            AAFTF assemble -c $CPU --left $LEFT --right $RIGHT --merged $MERGED --memory $MEM \
            -o $ASMFILE -w $WORKDIR/spades_${ID}
        fi
        if [ -s $ASMFILE ]; then
            rm -rf $WORKDIR/spades_${ID}/K?? $WORKDIR/spades_${ID}/tmp $WORKDIR/spades_${ID}/K???
            rm -rf $WORKDIR/spades_${ID}
        fi

        if [ ! -f $ASMFILE ]; then
            echo "SPADES must have failed, exiting"
            tail -n 100 $WORKDIR/spades_${ID}/spades.log
            exit
        fi
    fi

    if [[ ! -f $VECCLEAN && ! -f $VECCLEAN.gz ]]; then
        AAFTF fcs_screen -i $ASMFILE -o $VECCLEAN
    fi
done
