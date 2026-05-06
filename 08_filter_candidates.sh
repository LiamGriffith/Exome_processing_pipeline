#!/bin/bash
#SBATCH --job-name=08filtercandidates
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=12:00:00
#SBATCH --output=../logs/08filtercandidates.out
#SBATCH --error=../logs/08filtercandidates.err

# ─── MODULES ────────────────────────────────────────────────────────────────
module purge
module load bear-apps/2024a/live
module load Python/3.12.3-GCCcore-13.3.0

# ─── CONFIG ─────────────────────────────────────────────────────────────────
INDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/5_annotated
OUTDIR=/rds/projects/m/morgannv-liam-mibtp/Exomes/Data/6_candidates
mkdir -p "$OUTDIR"

VCF="$INDIR/joint_annotated.vcf.gz"

# gnomAD AF threshold — ultra-rare: absent OR AF < 0.0001
AF_THRESHOLD=0.0001

# Sample names as they appear in the VCF header (must match GATK SM: tags)
SAMPLE_OGL="OGL"
SAMPLE_WTCHG="WTCHG"

echo "[$(date)] Starting candidate variant filtering"

# ─── STEP 1: Pre-filter — ultra-rare in gnomAD ──────────────────────────────
# Keep variants where gnomADe_AF is missing (novel) or < threshold across all pops
# We filter on INFO field added by VEP's --custom gnomADe annotation

echo "[$(date)] Filtering to ultra-rare variants (gnomAD AF < $AF_THRESHOLD or absent)"

bcftools view "$VCF" \
| bcftools filter \
    --include '(INFO/gnomADe_AF="." || INFO/gnomADe_AF < 0.0001) &&
               (INFO/gnomADe_AF_nfe="." || INFO/gnomADe_AF_nfe < 0.0001) &&
               (INFO/gnomADe_AF_afr="." || INFO/gnomADe_AF_afr < 0.0001) &&
               (INFO/gnomADe_AF_eas="." || INFO/gnomADe_AF_eas < 0.0001)' \
    --output-type z \
    --output "$OUTDIR/ultra_rare.vcf.gz"

bcftools index --tbi "$OUTDIR/ultra_rare.vcf.gz"

echo "[$(date)] Ultra-rare variants: $(bcftools view -H $OUTDIR/ultra_rare.vcf.gz | wc -l)"

# ─── STEP 2: Shared homozygous alt variants ──────────────────────────────────
echo "[$(date)] Extracting shared homozygous alt variants"

bcftools view "$OUTDIR/ultra_rare.vcf.gz" \
| bcftools view \
    --genotype hom \
    --output-type z \
    --output "$OUTDIR/hom_pre.vcf.gz"

# Both samples must be hom alt (1/1) — not hom ref (0/0)
bcftools filter \
    --include "GT[${SAMPLE_OGL}]='1/1' && GT[${SAMPLE_WTCHG}]='1/1'" \
    --output-type z \
    --output "$OUTDIR/shared_homozygous.vcf.gz" \
    "$OUTDIR/hom_pre.vcf.gz"

bcftools index --tbi "$OUTDIR/shared_homozygous.vcf.gz"

NHOM=$(bcftools view -H "$OUTDIR/shared_homozygous.vcf.gz" | wc -l)
echo "[$(date)] Shared homozygous alt variants: $NHOM"

# ─── STEP 3: Compound heterozygous — using python script (below) ─────────────
echo "[$(date)] Running compound het analysis"

python3 << 'PYEOF'
import sys, gzip, re
from collections import defaultdict

vcf_path = "$OUTDIR/ultra_rare.vcf.gz"
out_path  = "$OUTDIR/shared_comphet.tsv"

sample_names = ["$SAMPLE_OGL", "$SAMPLE_WTCHG"]

# Parse VCF
gene_variants = defaultdict(lambda: defaultdict(list))  # gene -> sample -> [variants]
header_samples = []

def parse_csq(info, csq_keys):
    """Extract gene from VEP CSQ INFO field."""
    m = re.search(r'CSQ=([^;]+)', info)
    if not m:
        return None
    entries = m.group(1).split(',')
    for entry in entries:
        fields = entry.split('|')
        d = dict(zip(csq_keys, fields))
        gene = d.get('SYMBOL') or d.get('Gene')
        if gene:
            return gene
    return None

csq_keys = []
records = []

with gzip.open(vcf_path, 'rt') as f:
    for line in f:
        if line.startswith('##INFO=<ID=CSQ'):
            # Extract CSQ field names
            m = re.search(r'Format: ([^"]+)"', line)
            if m:
                csq_keys = m.group(1).split('|')
        elif line.startswith('#CHROM'):
            cols = line.strip().split('\t')
            header_samples = cols[9:]
            sample_idx = {s: i for i, s in enumerate(header_samples)}
        elif not line.startswith('#'):
            cols = line.strip().split('\t')
            chrom, pos, vid, ref, alt, qual, filt, info, fmt = cols[:9]
            gts = cols[9:]

            gene = parse_csq(info, csq_keys) if csq_keys else None
            if not gene:
                continue

            fmt_fields = fmt.split(':')
            gt_idx = fmt_fields.index('GT') if 'GT' in fmt_fields else 0

            sample_gts = {}
            for sname in sample_names:
                if sname in sample_idx:
                    gt_raw = gts[sample_idx[sname]].split(':')[gt_idx]
                    gt_clean = gt_raw.replace('|','/')
                    sample_gts[sname] = gt_clean
                else:
                    sample_gts[sname] = './.'

            records.append({
                'chrom': chrom, 'pos': pos, 'id': vid,
                'ref': ref, 'alt': alt,
                'gene': gene, 'info': info,
                'sample_gts': sample_gts
            })

# Find compound hets: per gene, each sample must have ≥2 het variants on different alleles
def is_het(gt):
    alleles = re.split(r'[/|]', gt)
    return len(set(alleles)) == 2 and '.' not in alleles

comphet_genes = set()
for gene, _ in [(r['gene'], r) for r in records]:
    gene_recs = [r for r in records if r['gene'] == gene]
    for sname in sample_names:
        het_recs = [r for r in gene_recs if is_het(r['sample_gts'].get(sname, './.'))]
        if len(het_recs) >= 2:
            comphet_genes.add(gene)

# Keep only genes where BOTH samples have comphet
shared_comphet_genes = set()
for gene in comphet_genes:
    gene_recs = [r for r in records if r['gene'] == gene]
    both_comphet = all(
        len([r for r in gene_recs if is_het(r['sample_gts'].get(s, './.'))])  >= 2
        for s in sample_names
    )
    if both_comphet:
        shared_comphet_genes.add(gene)

# Write output
with open(out_path, 'w') as out:
    header = ['GENE','CHROM','POS','REF','ALT','VARIANT_ID'] + \
             [f'GT_{s}' for s in sample_names] + ['INFO']
    out.write('\t'.join(header) + '\n')
    for r in records:
        if r['gene'] in shared_comphet_genes:
            row = [r['gene'], r['chrom'], r['pos'], r['ref'], r['alt'], r['id']] + \
                  [r['sample_gts'].get(s, './.') for s in sample_names] + \
                  [r['info']]
            out.write('\t'.join(row) + '\n')

print(f"Shared compound het genes: {len(shared_comphet_genes)}")
print(f"Output written to: {out_path}")
if shared_comphet_genes:
    print("Genes:", ', '.join(sorted(shared_comphet_genes)))
PYEOF

# ─── STEP 4: Summary report ──────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════"
echo "  CANDIDATE VARIANT SUMMARY"
echo "════════════════════════════════════════════════════════"
echo "  Shared homozygous alt (ultra-rare): $NHOM variants"
echo "    → $OUTDIR/shared_homozygous.vcf.gz"
echo ""
echo "  Shared compound het (ultra-rare):"
echo "    → $OUTDIR/shared_comphet.tsv"
echo "════════════════════════════════════════════════════════"
echo ""
echo "[$(date)] Pipeline complete."