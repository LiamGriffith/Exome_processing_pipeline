#!/bin/bash
#SBATCH --job-name=04haplotypecaller.sh
#SBATCH --array=0-1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=../logs/04haplotypecaller.out
#SBATCH --error=../logs/04haplotypecaller.err

# ─── MODULES ────────────────────────────────────────────────────────────────
module purge
module load bear-apps/2022b/live
module load GATK/4.4.0.0-GCCcore-12.2.0-Java-17

# ─── CONFIG ─────────────────────────────────────────────────────────────────
REF=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/GRCh38_no_alt.fna

# WES exome intervals — critical for WES to avoid calling in low-coverage off-target
INTERVALS=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/hg38_exome_v2.0.2_targets_sorted_validated.re_annotated.bed

INDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/2_bam
OUTDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/3_gvcf
TMPDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/tmp
mkdir -p "$OUTDIR"

SAMPLES=(OGL WTCHG)
SAMPLE="${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

echo "[$(date)] Running HaplotypeCaller on: $SAMPLE"

gatk HaplotypeCaller \
    -R "$REF" \
    -I "$INDIR/${SAMPLE}.bqsr.bam" \
    -O "$OUTDIR/${SAMPLE}.g.vcf.gz" \
    -ERC GVCF \
    -L "$INTERVALS" \
    --tmp-dir "$TMPDIR" \
    --native-pair-hmm-threads 4 \
    -G StandardAnnotation \
    -G StandardHCAnnotation \
    -G AS_StandardAnnotation \
    --dbsnp /rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/Homo_sapiens_assembly38.dbsnp138.vcf

echo "[$(date)] Done: $OUTDIR/${SAMPLE}.g.vcf.gz"