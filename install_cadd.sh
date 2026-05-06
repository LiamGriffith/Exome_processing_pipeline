#!/bin/bash
#SBATCH --job-name=cadd_download
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=24:00:00
#SBATCH --output=../logs/cadd_download.out

CADD_DIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/cadd_cache
mkdir -p "$CADD_DIR"
cd "$CADD_DIR"

# SNVs (whole genome pre-scored) ~78GB
wget -c https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz
wget -c https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/whole_genome_SNVs.tsv.gz.tbi

# Indels ~5GB
wget -c https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz
wget -c https://krishna.gs.washington.edu/download/CADD/v1.7/GRCh38/gnomad.genomes.r4.0.indel.tsv.gz.tbi