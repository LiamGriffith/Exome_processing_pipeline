#!/bin/bash
#SBATCH --job-name=05joint_genotype
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=128:00:00
#SBATCH --output=../logs/05jointgenotype.out
#SBATCH --error=../logs/05jointgenotype.err

# ─── MODULES ────────────────────────────────────────────────────────────────
module purge
module load bear-apps/2022b/live
module load GATK/4.4.0.0-GCCcore-12.2.0-Java-17

# ─── CONFIG ─────────────────────────────────────────────────────────────────
REF=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/GRCh38_no_alt.fna
INTERVALS=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/hg38_exome_v2.0.2_targets_sorted_validated.re_annotated.bed
DBSNP=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/Homo_sapiens_assembly38.dbsnp138.vcf

GVCF_DIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/3_gvcf
GENOMICSDB=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/3_gdb     # Must NOT already exist
OUTDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/4_vcf
TMPDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/tmp
mkdir -p "$OUTDIR" 

# ─── STEP 1: GenomicsDBImport ────────────────────────────────────────────────
echo "[$(date)] Running GenomicsDBImport"

gatk GenomicsDBImport \
    -V "$GVCF_DIR/OGL.g.vcf.gz" \
    -V "$GVCF_DIR/WTCHG.g.vcf.gz" \
    --genomicsdb-workspace-path "$GENOMICSDB" \
    -L "$INTERVALS" \
    --tmp-dir "$TMPDIR" \
    --reader-threads 4 \
    --batch-size 50 \
    --genomicsdb-shared-posixfs-optimizations true

echo "[$(date)] GenomicsDBImport complete"

# ─── STEP 2: GenotypeGVCFs ──────────────────────────────────────────────────
echo "[$(date)] Running GenotypeGVCFs"

gatk GenotypeGVCFs \
    -R "$REF" \
    -V "gendb://$GENOMICSDB" \
    -O "$OUTDIR/joint_raw.vcf.gz" \
    -L "$INTERVALS" \
    --dbsnp "$DBSNP" \
    --tmp-dir "$TMPDIR" \
    -G StandardAnnotation \
    -G AS_StandardAnnotation \
    --include-non-variant-sites false

echo "[$(date)] Done: $OUTDIR/joint_raw.vcf.gz"
