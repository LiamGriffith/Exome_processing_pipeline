#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# MASTER SUBMISSION SCRIPT
# Submits all pipeline steps with correct SLURM dependencies.
# Run this once from your project directory: bash submit_pipeline.sh
# ─────────────────────────────────────────────────────────────────────────────


set -euo pipefail
mkdir -p logs

echo "Submitting rare variant discovery pipeline..."

# Step 1: Align (array: 2 samples, no dependency)
JOB1=$(sbatch --parsable 01_align.sh)
echo "01_align submitted: $JOB1"

# Step 2: MarkDuplicates (depends on all align array jobs finishing)
JOB2=$(sbatch --parsable --dependency=afterok:$JOB1 02_markdup.sh)
echo "02_markdup submitted: $JOB2"

# Step 3: BQSR (depends on markdup)
JOB3=$(sbatch --parsable --dependency=afterok:$JOB2 03_bqsr.sh)
echo "03_bqsr submitted: $JOB3"

# Step 4: HaplotypeCaller GVCF (depends on BQSR)
JOB4=$(sbatch --parsable --dependency=afterok:$JOB3 04_haplotypecaller.sh)
echo "04_haplotypecaller submitted: $JOB4"

# Step 5: Joint genotyping (depends on both GVCFs being ready)
JOB5=$(sbatch --parsable --dependency=afterok:$JOB4 05_joint_genotype.sh)
echo "05_joint_genotype submitted: $JOB5"

# Step 6: VQSR / hard filter
JOB6=$(sbatch --parsable --dependency=afterok:$JOB5 06_vqsr_filter.sh)
echo "06_vqsr_filter submitted: $JOB6"

# Step 7: VEP annotation
JOB7=$(sbatch --parsable --dependency=afterok:$JOB6 07_annotate.sh)
echo "07_annotate submitted: $JOB7"

# Step 8: Candidate filtering
JOB8=$(sbatch --parsable --dependency=afterok:$JOB7 08_filter_candidates.sh)
echo "08_filter_candidates submitted: $JOB8"

echo ""
echo "All jobs submitted. Monitor with: squeue -u $USER"
echo "Final outputs will be in: /path/to/output/candidates/"