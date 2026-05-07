#!/bin/bash
#SBATCH --job-name=06vqsrfilter
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=128:00:00
#SBATCH --output=../logs/06vqsrfilter.out
#SBATCH --error=../logs/06vqsrfilter.err

# ─── MODULES ────────────────────────────────────────────────────────────────
module purge
module load bear-apps/2022b/live
module load GATK/4.4.0.0-GCCcore-12.2.0-Java-17

# ─── CONFIG ─────────────────────────────────────────────────────────────────
REF=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/reference/GRCh38_no_alt.fna


INDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/4_vcf
OUTDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/4_vcf
TMPDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/tmp
mkdir -p "$OUTDIR"

# ─── NOTE ON WES + VQSR ─────────────────────────────────────────────────────
# VQSR requires ~30 WES samples to be well-calibrated. With only 2 samples,
# we use hard filters (GATK best-practice recommendation for small cohorts).
# If you later add more samples, switch to VQSR by uncommenting below.
# ────────────────────────────────────────────────────────────────────────────

# ─── SEPARATE SNPs AND INDELS ────────────────────────────────────────────────
echo "[$(date)] Separating SNPs"
gatk SelectVariants \
    -R "$REF" \
    -V "$INDIR/joint_raw.vcf.gz" \
    --select-type-to-include SNP \
    -O "$OUTDIR/raw_snps.vcf.gz"

echo "[$(date)] Separating INDELs"
gatk SelectVariants \
    -R "$REF" \
    -V "$INDIR/joint_raw.vcf.gz" \
    --select-type-to-include INDEL \
    -O "$OUTDIR/raw_indels.vcf.gz"

# ─── HARD FILTER SNPs (GATK recommended for small WES cohorts) ───────────────
echo "[$(date)] Hard filtering SNPs"
gatk VariantFiltration \
    -R "$REF" \
    -V "$OUTDIR/raw_snps.vcf.gz" \
    --filter-expression "QD < 2.0"    --filter-name "QD2" \
    --filter-expression "FS > 60.0"   --filter-name "FS60" \
    --filter-expression "MQ < 40.0"   --filter-name "MQ40" \
    --filter-expression "MQRankSum < -12.5" --filter-name "MQRankSum-12.5" \
    --filter-expression "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" \
    --filter-expression "SOR > 3.0"   --filter-name "SOR3" \
    -O "$OUTDIR/filtered_snps.vcf.gz"

# ─── HARD FILTER INDELs ──────────────────────────────────────────────────────
echo "[$(date)] Hard filtering INDELs"
gatk VariantFiltration \
    -R "$REF" \
    -V "$OUTDIR/raw_indels.vcf.gz" \
    --filter-expression "QD < 2.0"    --filter-name "QD2" \
    --filter-expression "FS > 200.0"  --filter-name "FS200" \
    --filter-expression "ReadPosRankSum < -20.0" --filter-name "ReadPosRankSum-20" \
    --filter-expression "SOR > 10.0"  --filter-name "SOR10" \
    -O "$OUTDIR/filtered_indels.vcf.gz"

# ─── MERGE BACK ─────────────────────────────────────────────────────────────
echo "[$(date)] Merging SNPs and INDELs"
gatk MergeVcfs \
    -I "$OUTDIR/filtered_snps.vcf.gz" \
    -I "$OUTDIR/filtered_indels.vcf.gz" \
    -O "$OUTDIR/joint_filtered.vcf.gz"

# ─── KEEP ONLY PASS VARIANTS ────────────────────────────────────────────────
echo "[$(date)] Selecting PASS variants only"
gatk SelectVariants \
    -R "$REF" \
    -V "$OUTDIR/joint_filtered.vcf.gz" \
    --exclude-filtered \
    -O "$OUTDIR/joint_PASS.vcf.gz"

echo "[$(date)] Done: $OUTDIR/joint_PASS.vcf.gz"

# ─── VQSR ALTERNATIVE (uncomment if cohort grows to ≥30 WES samples) ────────
# SNP VQSR:
# gatk VariantRecalibrator -R $REF -V $INDIR/joint_raw.vcf.gz \
#     --resource:hapmap,known=false,training=true,truth=true,prior=15 $HAPMAP \
#     --resource:omni,known=false,training=true,truth=false,prior=12 $OMNI \
#     --resource:1000G,known=false,training=true,truth=false,prior=10 $KG_SNP \
#     --resource:dbsnp,known=true,training=false,truth=false,prior=2 $DBSNP \
#     -an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR \
#     -mode SNP --output $OUTDIR/snp.recal --tranches-file $OUTDIR/snp.tranches
