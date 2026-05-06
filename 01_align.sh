#!/bin/bash
#SBATCH --job-name=01_align.sh
#SBATCH --array=0-1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=../logs/01_align.out
#SBATCH --error=../logs/01_align.err

# ─── MODULES ────────────────────────────────────────────────────────────────
module purge
module load bear-apps/2023a/live
module load BWA/0.7.17-GCCcore-12.3.0
module load SAMtools/1.21-GCC-12.3.0

# ─── CONFIG — edit these paths ──────────────────────────────────────────────
REF=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/GRCh38_no_alt.fna         # BWA-MEM2 index must exist (.0123, .amb, etc.)
FASTQ_DIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/1_trimmed
OUTDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/2_bam
mkdir -p "$OUTDIR"

# ─── SAMPLE TABLE ───────────────────────────────────────────────────────────
# FORMAT: SAMPLE_ID  R1_FILENAME  R2_FILENAME  FLOWCELL  LANE  LIBRARY
SAMPLES=(
    "OGL   OGL-2532950-U194_S1_L001_trimmed_R1.fastq.gz   OGL-2532950-U194_S1_L001_trimmed_R2.fastq.gz   FLOWCELL1 L001 LIB_OGL"
    "WTCHG WTCHG-945098-U150_S1_L001_R1_trimmed.fastq.gz  WTCHG-945098-U150_S1_L001_R2_trimmed.fastq.gz  FLOWCELL2 L001 LIB_WTCHG"
)

IFS=' ' read -r SAMPLE R1 R2 FC LANE LIB <<< "${SAMPLES[$SLURM_ARRAY_TASK_ID]}"

R1_PATH="$FASTQ_DIR/$R1"
R2_PATH="$FASTQ_DIR/$R2"

# Read group — required by GATK downstream
RG="@RG\tID:${FC}.${LANE}\tSM:${SAMPLE}\tPL:ILLUMINA\tLB:${LIB}\tPU:${FC}.${LANE}.${SAMPLE}"

echo "[$(date)] Aligning sample: $SAMPLE"

bwa mem \
    -t "$SLURM_CPUS_PER_TASK" \
    -R "$RG" \
    "$REF" \
    "$R1_PATH" \
    "$R2_PATH" \
| samtools sort \
    -@ 4 \
    -m 4G \
    -o "$OUTDIR/${SAMPLE}.sorted.bam"

samtools index "$OUTDIR/${SAMPLE}.sorted.bam"

echo "[$(date)] Done: $OUTDIR/${SAMPLE}.sorted.bam"