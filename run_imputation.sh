#!/usr/bin/env bash
###############################################################################
#  run_imputation.sh  – one-shot 23-and-Me → GRCh38 phased & imputed pipeline
#
#  USAGE:  ./run_imputation.sh  target_genomes/<sample>.txt[.gz]
###############################################################################
set -euo pipefail

# Function to print timestamps and progress
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

### ───────────────────────────── 0. sanity ─────────────────────────────────###
[[ $# == 1 ]] || { echo "Usage: $0 target_genomes/<sample>.txt[.gz]"; exit 1; }
IN_TXT=$1
[[ -f $IN_TXT ]] || { echo "Input file not found: $IN_TXT"; exit 1; }

log "Starting imputation pipeline for: $IN_TXT"

### ─────────────────────────── 1. paths/vars ───────────────────────────────###
ROOT_DIR=$(pwd)                            # run script from project root

BASE=$(basename "$IN_TXT")                 # genome_AB.txt(.gz)
STEM=${BASE%%.*}                           # genome_AB

log "Processing sample: $STEM"

# ---- static resources ----------------------------------------------------- #
FASTA_37="${ROOT_DIR}/static_files/fasta/Homo_sapiens_assembly37.fasta"
FASTA_38="${ROOT_DIR}/static_files/fasta/Homo_sapiens_assembly38.fasta"
CHAIN="${ROOT_DIR}/static_files/chain/hg19ToHg38.over.chain.gz"

REF_DIR_EAGLE="${ROOT_DIR}/static_files/ref_bcfs"
MAP_DIR_EAGLE="${ROOT_DIR}/static_files/eagle_maps"

REF_DIR_BEAGLE="${ROOT_DIR}/static_files/ref_brefs"
MAP_DIR_BEAGLE="${ROOT_DIR}/static_files/beagle_maps"
JAR="${ROOT_DIR}/static_files/jars/beagle.27Jan18.7e1.jar"
EAGLE="${ROOT_DIR}/static_files/bin/eagle"

ADDCHR_MAP="${ROOT_DIR}/static_files/scripts/addchr.txt"
DROPCHR_MAP="${ROOT_DIR}/static_files/scripts/dropchr.txt"

# ---- per-sample folders & files ------------------------------------------- #
OUT_DIR="${ROOT_DIR}/results/${STEM}_results"
PHASED_DIR="${OUT_DIR}/phased_dir"
IMPUTED_DIR="${OUT_DIR}/imputed_dir"

RAW_GZ="${OUT_DIR}/${STEM}.txt.gz"

VCF_GZ="${OUT_DIR}/${STEM}.build37.vcf.gz"
VCF_CHR_GZ="${OUT_DIR}/${STEM}.build37.chr.vcf.gz"
RAW_VCF="${OUT_DIR}/${STEM}.build37.chr.alt.vcf.gz"

NOCHR_VCF="${OUT_DIR}/${STEM}.nochr.b37.vcf.gz"
LIFT_VCF="${OUT_DIR}/${STEM}.lift38.vcf"
SORT_VCF="${OUT_DIR}/${STEM}.lift38.sorted.vcf.gz"
PRIM_VCF="${OUT_DIR}/${STEM}.lift38.primary.vcf.gz"
CHR_VCF="${OUT_DIR}/${STEM}.lift38.primary.chr.vcf.gz"

FINAL_VCF="${OUT_DIR}/${STEM}_imputed_all.vcf.gz"

log "Creating output directories..."
mkdir -p "$OUT_DIR" "$PHASED_DIR" "$IMPUTED_DIR"

### ─────────────────────────── 2. gzip copy ────────────────────────────────###
log "Step 2/9: Copying and compressing raw file..."
if [[ $IN_TXT == *.gz ]]; then
  cp "$IN_TXT" "$RAW_GZ"
  log "  ✓ Copied compressed file"
else
  gzip -c "$IN_TXT" > "$RAW_GZ"
  log "  ✓ Compressed and copied file"
fi

### ─────────────────────────── 3. TSV→VCF (GRCh37) ─────────────────────────###
log "Step 3/9: Converting TSV to VCF (build37)..."
bcftools convert --tsv2vcf "$RAW_GZ" -f "$FASTA_37" -s "$STEM" -Oz -o "$VCF_GZ"
tabix -f -p vcf "$VCF_GZ"
log "  ✓ VCF created and indexed"

### ─────────────────────────── 4. add chr prefix ───────────────────────────###
log "Step 4/9: Adding chromosome prefixes..."
bcftools annotate --rename-chrs "$ADDCHR_MAP" -Oz -o "$VCF_CHR_GZ" "$VCF_GZ"
tabix -f -p vcf "$VCF_CHR_GZ"
log "  ✓ Chromosome prefixes added"

### ─────────────────────────── 5. fix missing ALT ──────────────────────────###
log "Step 5/9: Patching missing ALT alleles (this may take several minutes)..."
python static_files/scripts/alt_fix.py  "$VCF_CHR_GZ"
# alt_fix.py writes ${STEM}.build37.chr.alt.vcf.gz in the same folder
log "  ✓ ALT alleles patched"

### ─────────────────────── 6. nochr → liftover → chr ───────────────────────###
log "Step 6/9: Performing genome build conversion (chr→nochr→liftover→chr)..."
log "  - Removing chr prefixes for CrossMap..."
bcftools annotate --rename-chrs "$DROPCHR_MAP" -Oz -o "$NOCHR_VCF" "$RAW_VCF"
tabix -f -p vcf "$NOCHR_VCF"

log "  - Running CrossMap liftover to GRCh38 (this may take several minutes)..."
CrossMap.py vcf "$CHAIN" "$NOCHR_VCF" "$FASTA_38" "$LIFT_VCF"

log "  - Sorting and compressing..."
bcftools sort "$LIFT_VCF" -Oz -o "$SORT_VCF"
tabix -f -p vcf "$SORT_VCF"

log "  - Filtering to primary contigs..."
CONTIGS=$(printf '%s,' {1..22} X Y MT); CONTIGS=${CONTIGS%,}
bcftools view -r "$CONTIGS" -Oz -o "$PRIM_VCF" "$SORT_VCF"
tabix -f -p vcf "$PRIM_VCF"

log "  - Adding chr-prefix again..."
bcftools annotate --rename-chrs "$ADDCHR_MAP" -Oz -o "$CHR_VCF" "$PRIM_VCF"
tabix -f -p vcf "$CHR_VCF"
log "  ✓ Genome build conversion complete"

### ─────────────────────────── 7. Eagle phasing ────────────────────────────###
# COMMENTED OUT FOR TESTING - This step is very time-consuming
# log "Step 7/9: Starting Eagle phasing (chromosomes 1-22)..."
# for CHR in {1..22}; do
#   log "  - Phasing chromosome ${CHR}/22..."
#   "$EAGLE" \
#     --vcfRef        "${REF_DIR_EAGLE}/1000GP_dedup_chr${CHR}.bcf" \
#     --vcfTarget     "$CHR_VCF" \
#     --geneticMapFile "${MAP_DIR_EAGLE}/eagle_chr${CHR}_b38.map" \
#     --chrom         "$CHR" \
#     --outPrefix     "${PHASED_DIR}/${STEM}_phased_chr${CHR}" \
#     --numThreads    4 \
#     --allowRefAltSwap
#   log "    ✓ Chromosome ${CHR} phased"
# done
# log "  ✓ All chromosomes phased"
log "Step 7/9: Eagle phasing SKIPPED for testing"

### ─────────────────────────── 8. Beagle imput. ────────────────────────────###
# COMMENTED OUT FOR TESTING - This step is very time-consuming
# log "Step 8/9: Starting Beagle imputation (chromosomes 1-22)..."
# for CHR in {1..22}; do
#   GT=${PHASED_DIR}/${STEM}_phased_chr${CHR}.vcf.gz
#   REF=${REF_DIR_BEAGLE}/1000GP_dedup_chr${CHR}.bref
#   MAP=${MAP_DIR_BEAGLE}/beagle_chr${CHR}_b38.map
#   for f in "$GT" "$REF" "$MAP"; do
#     [[ -f $f ]] || { log "    ⚠ Skipping chr${CHR} (missing $f)"; continue 2; }
#   done
#   log "  - Imputing chromosome ${CHR}/22..."
#   java -Xmx8g -jar "$JAR" \
#        gt="$GT" \
#        ref="$REF" \
#        map="$MAP" \
#        impute=true \
#        out=${IMPUTED_DIR}/${STEM}_imputed_chr${CHR} \
#        nthreads=4
#   log "    ✓ Chromosome ${CHR} imputed"
# done
# log "  ✓ All chromosomes imputed"
log "Step 8/9: Beagle imputation SKIPPED for testing"

### ─────────────────────── 9. concatenate chr1-22 ─────────────────────────###
# COMMENTED OUT FOR TESTING - No imputed files to concatenate
# log "Step 9/9: Finalizing results..."
# log "  - Indexing imputed chromosomes..."
# for CHR in {1..22}; do
#   tabix -f -p vcf "${IMPUTED_DIR}/${STEM}_imputed_chr${CHR}.vcf.gz"
# done
# 
# log "  - Concatenating all chromosomes..."
# LIST=$(mktemp)
# for CHR in {1..22}; do
#   echo "${IMPUTED_DIR}/${STEM}_imputed_chr${CHR}.vcf.gz" >> "$LIST"
# done
# bcftools concat -f "$LIST" -Oz -o "$FINAL_VCF"
# tabix -f -p vcf "$FINAL_VCF"
# rm -f "$LIST"
log "Step 9/9: Final concatenation SKIPPED for testing"

log "✓ Pipeline completed successfully (TEST MODE - phasing and imputation skipped)!"
log "✓ Intermediate file: $CHR_VCF"
log "✓ Results directory: $OUT_DIR"
