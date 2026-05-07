#!/bin/bash
#SBATCH --job-name=07annotate.sh
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=128:00:00
#SBATCH --output=../logs/07annotate.out
#SBATCH --error=../logs/07annotate.err

# ─── MODULES ────────────────────────────────────────────────────────────────
module purge
module load bear-apps/2024a/live
module load VEP/115.2-GCC-13.3.0
module load BCFtools/1.21-GCC-13.3.0

# ─── CONFIG ─────────────────────────────────────────────────────────────────
VEP_CACHE=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/vep_cache
VEP_VERSION=115
GNOMAD_EXOMES=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/gnomad_cache/gnomad.exomes.v4.0.sites.merged.vcf.bgz
CADD_SNVS=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/cadd_cache/whole_genome_SNVs.tsv.gz
CADD_INDELS=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/cadd_cache/gnomad.genomes.r4.0.indel.tsv.gz
INDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/4_vcf
OUTDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/5_annotated
mkdir -p "$OUTDIR" 

echo "[$(date)] Running VEP annotation"

vep \
    --input_file  "$INDIR/joint_PASS.vcf.gz" \
    --output_file "$OUTDIR/joint_annotated.vcf.gz" \
    --vcf \
    --compress_output bgzip \
    --stats_file  "$OUTDIR/vep_stats.html" \
    --cache \
    --offline \
    --dir_cache "$VEP_CACHE" \
    --cache_version "$VEP_VERSION" \
    --assembly GRCh38 \
    --fasta /path/to/GRCh38/GRCh38.fa \
    --fork "$SLURM_CPUS_PER_TASK" \
    --buffer_size 5000 \
    --everything \
    --pick_allele \
    --custom "$GNOMAD_EXOMES,gnomADe,vcf,exact,0,AF,AF_afr,AF_amr,AF_asj,AF_eas,AF_fin,AF_nfe,AF_oth,AF_sas,nhomalt" \
    --plugin CADD,"$CADD_SNVS","$CADD_INDELS" \
    --fields "Uploaded_variation,Location,Allele,Gene,Feature,BIOTYPE,Consequence,IMPACT,SYMBOL,HGVSc,HGVSp,Existing_variation,SIFT,PolyPhen,CADD_PHRED,gnomADe_AF,gnomADe_AF_nfe,gnomADe_AF_afr,gnomADe_AF_amr,gnomADe_AF_eas,gnomADe_nhomalt,CLIN_SIG,CANONICAL"

# Index the output
bcftools index --tbi "$OUTDIR/joint_annotated.vcf.gz"

echo "[$(date)] Done: $OUTDIR/joint_annotated.vcf.gz"
