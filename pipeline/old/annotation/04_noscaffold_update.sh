#!/usr/bin/bash -l
#SBATCH  --time 2-0:00:00 --ntasks 16 --nodes 1 --mem 24G --out logs/annotate_noscaffold_update.%a.log

module load singularity
HOSTNAME=$(hostname -s)
echo "Running on $HOSTNAME"
# Define stop mysqldb
RUNID=$$
stop_mysqldb() { singularity instance stop mysqldb$RUNID; }

# Define error handler
error_exit()
{
    stop_mysqldb
	echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

# Set trap to ensure mysqldb is stopped
trap "stop_mysqldb; exit 130" SIGHUP SIGINT SIGTERM

# Set some vars
mkdir -p $SCRATCH/db $SCRATCH/conf
rsync -a ~/bigdata/mysql/db/mysql $SCRATCH/db/ || error_exit "Failed to copy mysql data"
cp  ~/.pasa/pasa_conf/my.cnf $SCRATCH/conf/my.cnf || error_exit "Failed to copy pasa config file"
cp ~/.pasa/pasa_conf/conf.txt $SCRATCH/conf/pasa-local-${HOSTNAME}.config.txt 
PORT=$(shuf -i3000-4999 -n1)

export SINGULARITY_BINDPATH=$SCRATCH
export PASACONF=$SCRATCH/conf/pasa-local-${HOSTNAME}.config.txt
#export PASACONF=$SINGULARITYENV_PASACONF
sed -i "s/^MYSQLSERVER.*$/MYSQLSERVER=${HOSTNAME}:${PORT}/" ${PASACONF}
perl -i -p -e "s/port = \d+/port = ${PORT}/" $SCRATCH/conf/my.cnf
SIF=/bigdata/stajichlab/shared/lib/mariadb/mariadb.sif
# Start Database
singularity instance start --writable-tmpfs -B $SCRATCH/conf/my.cnf:/etc/mysql/my.cnf,$SCRATCH/db/:/var/lib/mysql,$SCRATCH/conf:/usr/conf $SIF mysqldb$RUNID /usr/bin/mysqld_safe


module load funannotate
SAMPLES=samples.csv
export PASAHOME=$HOME/.pasa

MEM=24G
CPU=$SLURM_CPUS_ON_NODE
if [ -z $CPU ]; then
	CPU=1
fi

export AUGUSTUS_CONFIG_PATH=$(realpath lib/augustus/3.5/config)
export FUNANNOTATE_DB=/bigdata/stajichlab/shared/lib/funannotate_db
export PASACONF=$HOME/pasa.config.txt

SEED_SPECIES=coccidioides_immitis

SBT=$(realpath lib/sbt/Cocci.sbt) # this can be changed

INDIR=unscaffolded_genomes
OUTDIR=unscaffolded_annotation
N=${SLURM_ARRAY_TASK_ID}

if [ -z $N ]; then
    N=$1
    if [ -z $N ]; then
        echo "need to provide a number by --array or cmdline"
        exit
    fi
fi
MAX=$(wc -l $SAMPLES | awk '{print $1}')

if [ $N -gt $MAX ]; then
    echo "$N is too big, only $MAX lines in $SAMPLES"
    exit
fi

IFS=,
tail -n +2 $SAMPLES | sed -n ${N}p | while read RUNACC STRAIN BIOSAMPLE CENTER EXPERIMENT PROJECT ORGANISM FILEBASE NOTES LOCUSTAG
do
	name=$STRAIN
	MASKED=$INDIR/${name}.masked.fasta
	if [[ "$NOTES" == "Skip" ]]; then
		echo "Skipping $N ($ID) as this was flagged as a bad sample"
		continue
    fi
	if [ ! -f $MASKED ]; then
		echo " no genome for $MASKED ($STRAIN $ORGANISM)"
		exit
	fi
        funannotate update --cpus $CPU -i $OUTDIR/$name --out $OUTDIR/$name \
			--sbt $SBT --memory $MEM --pasa_db mysql
done
