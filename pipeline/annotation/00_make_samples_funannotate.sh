#!/usr/bin/env bash
# 00_make_samples_funannotate.sh — derive samples_funannotate.csv from samples.csv.
#
# samples.csv (project root) drives the AAFTF assembly pipeline and already
# carries most columns nf_funannotate1 needs (SPECIES, STRAIN, TRANSL_TABLE,
# LOCUSTAG, BUSCO_LINEAGE, NCBI_TAXONID). It is missing ASMID (nf_funannotate1's
# required primary key) and its GENOME column points at the AAFTF pipeline's
# own read/assembly inputs, not a finished genome FASTA.
#
# This script writes a SEPARATE sheet (samples_funannotate.csv) rather than
# editing samples.csv in place, so the AAFTF launcher (01_nf_aaftf.sh) keeps
# using its own columns untouched.
#
# GENOME currently resolves to results/vecscreen/<sample>.vecscreen.fasta —
# the latest AAFTF output available as of 2026-09-26. AAFTF is still running
# (contam/FCS-GX cleanup was only just added) and the final assembly location
# will move (likely back to results/sort/*.sorted.fasta once that stage
# reruns with contam cleaning). Re-run this script to regenerate the sheet
# once final assemblies land somewhere else — update GENOME_DIR/GENOME_SUFFIX
# below, or override via env vars.
#
# Usage:  pipeline/annotation/00_make_samples_funannotate.sh [samples.csv] [samples_funannotate.csv]
set -euo pipefail

PROJECT="${PROJECT:-$PWD}"
IN="${1:-$PROJECT/samples.csv}"
OUT="${2:-$PROJECT/samples_funannotate.csv}"

GENOME_DIR="${GENOME_DIR:-$PROJECT/results/vecscreen}"
GENOME_SUFFIX="${GENOME_SUFFIX:-.vecscreen.fasta}"

awk -F, -v OFS=, -v genome_dir="$GENOME_DIR" -v genome_suffix="$GENOME_SUFFIX" '
NR==1 {
    for (i=1; i<=NF; i++) col[$i] = i
    print "SPECIES,STRAIN,ASMID,LOCUSTAG,BUSCO_LINEAGE,TRANSL_TABLE,NCBI_TAXONID,GENOME"
    next
}
{
    sample       = $col["sample"]
    species      = $col["SPECIES"]
    strain       = $col["STRAIN"]
    transl_table = $col["TRANSL_TABLE"]
    locustag     = $col["LOCUSTAG"]
    busco        = $col["BUSCO_LINEAGE"]
    taxid        = $col["NCBI_TAXONID"]
    if (taxid == "") taxid = $col["taxid"]
    genome = genome_dir "/" sample genome_suffix
    print species, strain, sample, locustag, busco, transl_table, taxid, genome
}
' "$IN" > "$OUT"

echo "Wrote $OUT ($(($(wc -l < "$OUT") - 1)) samples)" >&2

tail -n +2 "$OUT" | awk -F, '{print $NF}' | while read -r g; do
    [ -e "$g" ] || echo "WARNING: missing genome file: $g" >&2
done
