#!/bin/bash
#SBATCH --job-name=02markdup.sh
#SBATCH --array=0-1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=6:00:00
#SBATCH --output=../logs/02markdup.sh.out
#SBATCH --error=../logs/02markdup.sh.err

# ─── MODULES ────────────────────────────────────────────────────────────────
module purge
module load bear-apps/2022b/live
module load GATK/4.4.0.0-GCCcore-12.2.0-Java-17
module load SAMtools/1.17-GCC-12.2.0

# ─── CONFIG ─────────────────────────────────────────────────────────────────
BAMDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/2_bam
OUTDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/2_bam
TMPDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/tmp
mkdir -p "$OUTDIR" "$TMPDIR"

SAMPLES=(OGL WTCHG)
SAMPLE="${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

echo "[$(date)] Marking duplicates: $SAMPLE"

gatk MarkDuplicates \
    --INPUT  "$BAMDIR/${SAMPLE}.sorted.bam" \
    --OUTPUT "$OUTDIR/${SAMPLE}.markdup.bam" \
    --METRICS_FILE "$OUTDIR/${SAMPLE}.dup_metrics.txt" \
    --TMP_DIR "$TMPDIR" \
    --OPTICAL_DUPLICATE_PIXEL_DISTANCE 2500 \
    --CREATE_INDEX true \
    --VALIDATION_STRINGENCY SILENT

echo "[$(date)] Done: $OUTDIR/${SAMPLE}.markdup.bam"