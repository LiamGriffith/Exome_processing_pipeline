# Exome_processing_pipeline

### HPC pipeline for processing filtering exome data

#### Current filter:
Joint genotyping annotation of two related patients to identify novel/ultra-rare candidate mutations shared between two family members of consanguineous origins.

All filtering logic is within 08_filter_candidates.sh, and can be adjusted as desired

This pipeline does the following according to GATK best practices:
1. Aligns fastqs using BWA-MEM
2. Marks duplicates using GATK MarkDuplicates
3. Applies base quality recalibration
4. Runs GATK HaplotypeCaller
5. Joint genotypes the samples using GenomicsDB + GenotypeGVCFs
6. Hard filters samples (vsqr not used due to only 2 samples, use vsqr if >30 exomes)
7. Annotates using VEP, gnomAD, and CADD
8. Filters candidates
9. Outputs 2 vcfs, one with novel or ultra-rare shared homozygous mutations, and one with novel or ultra-rare shared compound heterozygous mutations

### How to Run:
1. Make sure all file paths are correct in every script
2. Run install_gnomad.sh 
3. Run merge_gnomad.sh
4. Run install_vep_cache.sh
5. Run install_cadd.sh
6. Make sure you have all known site files downloaded with correct paths in all scripts
7. Make sure you have reference genome downloaded with correct paths in all scripts
8. Make sure you have sequencing bed file in all scripts with correct path
9. Run submit_pipeline.sh