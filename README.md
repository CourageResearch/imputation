# Genomic Imputation Pipeline

A Docker-based pipeline for performing whole-genome imputation on 23andMe-style genetic data, converting it to GRCh38 phased and imputed VCF format.

## Overview

This pipeline performs the following steps:
1. **Format Conversion**: Converts 23andMe TSV format to VCF (GRCh37)
2. **Data Processing**: Adds chromosome prefixes and patches missing ALT alleles
3. **Genome Build Conversion**: Lifts over from GRCh37 to GRCh38 using CrossMap
4. **Phasing**: Uses Eagle v2.4.1 to phase the data
5. **Imputation**: Uses Beagle v4.1 to impute missing variants
6. **Finalization**: Concatenates all chromosomes into a single VCF file

## Prerequisites

- Docker Desktop
- Large genomic reference files (see Data Requirements below)

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url>
   cd imputation
   ```

2. **Build the Docker image**:
   ```bash
   docker build -t imputation-pipeline .
   ```

3. **Run the pipeline**:
   ```bash
   docker run --rm -it \
     -v "$PWD/static_files:/imputation/static_files" \
     -v "$PWD/target_genomes:/imputation/target_genomes" \
     imputation-pipeline target_genomes/your_sample.txt
   ```

## Data Requirements

The pipeline requires several large reference files that should be placed in the `static_files/` directory:

### Required Files Structure
```
static_files/
├── alt_alleles.db                    # SQLite database for ALT allele lookup
├── beagle_maps/                      # Beagle genetic maps (chr1-22)
├── bin/
│   └── eagle                         # Eagle v2.4.1 binary
├── chain/
│   └── hg19ToHg38.over.chain.gz      # Genome build conversion chain
├── eagle_maps/                       # Eagle genetic maps (chr1-22)
├── fasta/
│   ├── Homo_sapiens_assembly37.fasta # GRCh37 reference genome
│   └── Homo_sapiens_assembly38.fasta # GRCh38 reference genome
├── jars/
│   └── beagle.27Jan18.7e1.jar        # Beagle v4.1 JAR file
├── ref_bcfs/                         # Eagle reference BCF files (chr1-22)
├── ref_brefs/                        # Beagle reference BREF files (chr1-22)
└── scripts/
    ├── addchr.txt                    # Chromosome prefix mapping
    ├── alt_fix.py                    # ALT allele patching script
    └── dropchr.txt                   # Chromosome prefix removal mapping
```

### Input Format

The pipeline expects 23andMe-style TSV files with the following columns:
- `rsid`: SNP identifier
- `chromosome`: Chromosome number (1-22, X, Y, MT)
- `position`: Genomic position
- `genotype`: Genotype (e.g., "AA", "AG", "GG")

Example:
```
rsid	chromosome	position	genotype
rs4477212	1	82154	AA
rs3094315	1	752566	AG
rs3131972	1	752721	GG
```

## Output

The pipeline creates a results directory named `{sample}_results/` containing:

- **Phased data**: `phased_dir/` - Eagle-phased VCF files per chromosome
- **Imputed data**: `imputed_dir/` - Beagle-imputed VCF files per chromosome  
- **Final result**: `{sample}_imputed_all.vcf.gz` - Complete imputed genome in VCF format

## Performance

- **Memory**: Requires ~8GB RAM for Beagle imputation
- **Storage**: Results can be several GB per sample
- **Time**: ~1-2 hours for a complete genome depending on hardware

## Troubleshooting

### Common Issues

1. **Missing reference files**: Ensure all required files are in `static_files/`
2. **Memory errors**: Increase Docker memory allocation in Docker Desktop settings
3. **Permission errors**: Ensure Docker has access to mounted volumes

### Logs

The pipeline provides detailed progress feedback with timestamps:
```
[2025-07-03 18:45:00] Starting imputation pipeline for: target_genomes/sample.txt
[2025-07-03 18:45:00] Step 2/9: Copying and compressing raw file...
[2025-07-03 18:45:10] Step 5/9: Patching missing ALT alleles...
[2025-07-03 18:45:30] Step 7/9: Starting Eagle phasing (chromosomes 1-22)...
```

## License

[Add your license information here]

## Citation

If you use this pipeline in your research, please cite:
- Eagle v2.4.1: Loh et al. (2016) Nature Genetics
- Beagle v4.1: Browning & Browning (2016) Nature Genetics
- CrossMap: Zhao et al. (2014) Bioinformatics 