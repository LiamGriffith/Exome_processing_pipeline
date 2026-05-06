#!/bin/bash
#SBATCH --job-name=03bqsr.sh
#SBATCH --array=0-1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=8:00:00
#SBATCH --output=../logs/03_bqsr.out
#SBATCH --error=../logs/03_bqsr.err

# ─── MODULES ────────────────────────────────────────────────────────────────
module purge
module load bear-apps/2022b/live
module load GATK/4.4.0.0-GCCcore-12.2.0-Java-17

# ─── CONFIG ─────────────────────────────────────────────────────────────────
REF=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/GRCh38_no_alt.fna 

# GATK resource bundle (GRCh38) — adjust paths to your cluster's bundle location
DBSNP=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/Homo_sapiens_assembly38.dbsnp138.vcf
MILLS=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz
KG_INDELS=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/1000G_omni2.5.hg38.vcf.gz

# WES: restrict BQSR to exome intervals to avoid base-count inflation
INTERVALS=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/hg38_exome_v2.0.2_targets_sorted_validated.re_annotated.bed

INDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/2_bam
OUTDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/2_bam
mkdir -p "$OUTDIR"

SAMPLES=(OGL WTCHG)
SAMPLE="${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

echo "[$(date)] Running BaseRecalibrator: $SAMPLE"

# Step 1: Build recalibration table
gatk BaseRecalibrator \
    -I "$INDIR/${SAMPLE}.markdup.bam" \
    -R "$REF" \
    --known-sites "$DBSNP" \
    --known-sites "$MILLS" \
    --known-sites "$KG_INDELS" \
    -L "$INTERVALS" \
    -O "$OUTDIR/${SAMPLE}.recal.table"

echo "[$(date)] Running ApplyBQSR: $SAMPLE"

# Step 2: Apply recalibration
gatk ApplyBQSR \
    -I "$INDIR/${SAMPLE}.markdup.bam" \
    -R "$REF" \
    --bqsr-recal-file "$OUTDIR/${SAMPLE}.recal.table" \
    -L "$INTERVALS" \
    -O "$OUTDIR/${SAMPLE}.bqsr.bam"

echo "[$(date)] Done: $OUTDIR/${SAMPLE}.bqsr.bam"