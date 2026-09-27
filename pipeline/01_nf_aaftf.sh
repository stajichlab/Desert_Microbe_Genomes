#!/usr/bin/env bash
# run_nf_aaftf.sh — sbatch launcher for the nf_aaftf Nextflow pipeline (HPCC).
#
# Drives every sample in samples_aaftf.csv (sample,read_1,read_2,taxid — the
# AAFTF pipeline's only required columns) through the full AAFTF flow:
#   trim -> filter -> assemble (SPAdes) -> vector/contam screen -> rmdup
#   -> polish (POLCA) -> sort -> assess -> depth
#
# samples_aaftf.csv (project root) is the master sheet with the extra annotation
# metadata (SPECIES, STRAIN, LOCUSTAG, BUSCO_LINEAGE, ...); samples_aaftf.csv
# is just its first 4 columns, kept separate so this launcher isn't coupled to
# columns it doesn't use. See pipeline/annotation/00_make_samples_funannotate.sh
# for the funannotate-side sheet derived from the same samples.csv.
#
# Submit from this project dir (so samples_aaftf.csv + input/ resolve):
#   sbatch run_nf_aaftf.sh [extra nextflow args...]
#
# Quick graph validation (stub, runs in seconds on a login node):
#   nextflow run <pipeline> -profile aaftf -stub-run --n_test 2 --outdir /tmp/nf_aaftf_stub
#
# After the run finishes it calls summarize_results.sh to build results_summary/.
#SBATCH -N 1
#SBATCH -n 2
#SBATCH --mem 8G
#SBATCH -t 7-00:00:00
#SBATCH --job-name nf_aaftf
#SBATCH -o logs/slurm/nf_aaftf_%j.out
#SBATCH -e logs/slurm/nf_aaftf_%j.err

set -euo pipefail

PROJECT="${PROJECT:-$PWD}"                 # project dir (default: submission dir)
PIPELINE="${PIPELINE:-$HOME/projects/nf/nf_aaftf}"   # nf_aaftf Nextflow pipeline
REVISION="${REVISION:-}"                   # optional git branch/tag/commit of the pipeline

mkdir -p "$PROJECT/logs/slurm" "$PROJECT/logs/nextflow"

source /etc/profile.d/modules.sh 2>/dev/null || true
module load nextflow singularity

cd "$PROJECT"

nextflow run "${PIPELINE}" ${REVISION:+-r "${REVISION}"} \
    -profile aaftf \
    -resume \
    --samples "$PROJECT/samples_aaftf.csv" \
    --indir   "$PROJECT/input" \
    --outdir  "$PROJECT/results" \
    --vector_screen_method vecscreen \
    --skip_fcsgx false \
    "$@"

# Collect final assemblies + stats + depth into a clean summary folder.
"$PROJECT/summarize_results.sh" --project "$PROJECT"
