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
# GENOME resolves to results/sort/<sample>.sorted.fasta.gz -- the final AAFTF
# output (FCS-GX cleaned, rmdup'd, polished, sorted, compressed), confirmed
# present for all 14 samples 2026-09-26 (nf_aaftf run 29116703 completed:
# completed=86 failed=0 cached=27). Uses an ABSOLUTE path deliberately: the
# funannotate launcher (01_nf_funannotate.sh) runs from its own isolated
# .nf_launch/annotate/ launchDir, so a relative GENOME path here would
# resolve against THAT directory, not this project root. nf_funannotate1
# reads .gz genome FASTAs directly (see assets/schema_input.json), no need
# to decompress first.
#
# Usage:  pipeline/annotation/00_make_samples_funannotate.sh [samples.csv] [samples_funannotate.csv]
set -euo pipefail

PROJECT="${PROJECT:-$PWD}"
IN="${1:-$PROJECT/samples.csv}"
OUT="${2:-$PROJECT/samples_funannotate.csv}"

GENOME_DIR="${GENOME_DIR:-$PROJECT/results/sort}"
GENOME_SUFFIX="${GENOME_SUFFIX:-.sorted.fasta.gz}"

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
