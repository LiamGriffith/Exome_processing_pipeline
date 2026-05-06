#!/bin/bash
#SBATCH --job-name=install_vep_cache.sh
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=6:00:00
#SBATCH --output=../logs/install_vep_cache_%j.out
module purge
module load bear-apps/2024a/live
module load VEP/115.2-GCC-13.3.0   # Check what version this loads: vep --help | head -5

VEP_CACHE_DIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/vep_cache   # Pick somewhere with ~50GB free
mkdir -p "$VEP_CACHE_DIR"

# Download and unpack the GRCh38 cache
# Replace 110 with your installed VEP version number
VEP_VERSION=115

perl $(dirname $(which vep))/INSTALL.pl \
    --AUTO cf \
    --SPECIES homo_sapiens \
    --ASSEMBLY GRCh38 \
    --CACHEDIR "$VEP_CACHE_DIR" \
    --NO_HTSLIB \
    --NO_UPDATE