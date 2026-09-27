#!/usr/bin/env bash
# 01_nf_funannotate.sh — sbatch launcher for stajichlab/nf_funannotate1 (HPCC).
#
# Drives genome cleaning -> masking -> training -> gene prediction -> functional
# annotation over samples_funannotate.csv (see 00_make_samples_funannotate.sh,
# which regenerates that sheet from samples.csv + the current genome FASTAs).
#
# Nextflow keeps per-launchDir state (work/, .nextflow/, .nextflow.log) that
# is NOT safe to share between concurrently-running pipelines: the project
# root is the launchDir for the still-running nf_aaftf pipeline (its own
# workDir is work/aaftf, isolated by profile_aaftf.config, but .nextflow/ and
# .nextflow.log are launchDir-wide and get rotated/locked by whichever
# `nextflow run` starts most recently). To avoid any interference with the
# live AAFTF run, this launches from its own subdirectory (.nf_launch/annotate)
# with its own work/ and .nextflow/ state, entirely separate from the
# project-root launchDir the AAFTF pipeline uses.
#
# Submit from this project dir:
#   sbatch pipeline/annotation/01_nf_funannotate.sh [extra nextflow args...]
#
# Quick graph validation (stub, runs in seconds on a login node):
#   nextflow run $HOME/projects/nf/nf_funannotate1 -profile test -stub-run
#
#SBATCH -N 1
#SBATCH -n 2
#SBATCH --mem 8G
#SBATCH -t 7-00:00:00
#SBATCH --job-name nf_funannotate
#SBATCH -o logs/slurm/nf_funannotate_%j.out
#SBATCH -e logs/slurm/nf_funannotate_%j.err

set -euo pipefail

PROJECT="${PROJECT:-$PWD}"
PIPELINE="${PIPELINE:-$HOME/projects/nf/nf_funannotate1}"
REVISION="${REVISION:-}"
LAUNCH_DIR="${LAUNCH_DIR:-$PROJECT/.nf_launch/annotate}"
SAMPLES="${SAMPLES:-$LAUNCH_DIR/samples_funannotate.csv}"

mkdir -p "$PROJECT/logs/slurm" "$LAUNCH_DIR/logs/nextflow"

source /etc/profile.d/modules.sh 2>/dev/null || true
module load nextflow apptainer 2>/dev/null || module load nextflow

# Regenerate the funannotate samplesheet from samples.csv every run, so it
# always reflects the latest AAFTF genome output (see 00_make_samples_funannotate.sh
# for where GENOME currently resolves to and why that will need updating).
# GENOME paths in the sheet are absolute, so it's safe to launch from
# LAUNCH_DIR instead of PROJECT.
"$PROJECT/pipeline/annotation/00_make_samples_funannotate.sh" "$PROJECT/samples.csv" "$SAMPLES"

cd "$LAUNCH_DIR"

nextflow run "${PIPELINE}" ${REVISION:+-r "${REVISION}"} \
    -profile annotate,slurm,ucr_hpcc \
    -resume \
    --samples "$SAMPLES" \
    --target  "$PROJECT/results/annotation" \
    --run_sra_fetch false \
    "$@"
