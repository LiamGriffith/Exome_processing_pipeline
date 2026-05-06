#!/bin/bash
#SBATCH --job-name=installgnomad
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=48:00:00
#SBATCH --output=../logs/gnomaddownload.out

GNOMAD_DIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/gnomad_cache
mkdir -p "$GNOMAD_DIR"
cd "$GNOMAD_DIR"

BASE=https://storage.googleapis.com/gcp-public-data--gnomad/release/4.0/vcf/exomes

# Download all autosomes + sex chromosomes
for CHR in {1..22} X Y; do
    FILE="gnomad.exomes.v4.0.sites.chr${CHR}.vcf.bgz"
    echo "Downloading $FILE..."
    wget -c "${BASE}/${FILE}"
    wget -c "${BASE}/${FILE}.tbi"
done