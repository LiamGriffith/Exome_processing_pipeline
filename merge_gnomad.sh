#!/bin/bash
#SBATCH --job-name=mergegnomad
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=../logs/gnomadmerge.out

module purge
module load bear-apps/2024a/live
module load BCFtools/1.21-GCC-13.3.0

GNOMAD_DIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/gnomad_cache

# Build the file list in chr order
FILES=$(for CHR in {1..22} X Y; do
    echo "$GNOMAD_DIR/gnomad.exomes.v4.0.sites.chr${CHR}.vcf.bgz"
done)

bcftools concat \
    --threads 8 \
    --allow-overlaps \
    --output-type z \
    --output "$GNOMAD_DIR/gnomad.exomes.v4.0.sites.merged.vcf.bgz" \
    $FILES

bcftools index --tbi --threads 8 \
    "$GNOMAD_DIR/gnomad.exomes.v4.0.sites.merged.vcf.bgz"