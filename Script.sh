#!/bin/bash

# Set directories
RAW_DATA_DIR="raw_data"
QC_DATA_DIR="qc_data"
TRIMMED_DATA_DIR="trimmed_data"
REPAIRED_DATA_DIR="repaired_data"
REF_DATA_DIR="ref_data"
ALIGNMENT_DIR="alignment"

# Create necessary directories
mkdir -p "$RAW_DATA_DIR" "$QC_DATA_DIR" "$TRIMMED_DATA_DIR" "$REPAIRED_DATA_DIR" "$REF_DATA_DIR" "$ALIGNMENT_DIR"

# Step 1: Download data
echo "Downloading data..."
wget -P "$RAW_DATA_DIR" https://zenodo.org/records/10426436/files/ERR8774458_1.fastq.gz
wget -P "$RAW_DATA_DIR" https://zenodo.org/records/10426436/files/ERR8774458_2.fastq.gz

# Step 2: Quality check
echo "Performing quality check..."
fastqc "$RAW_DATA_DIR/ERR8774458_1.fastq.gz" -o "$QC_DATA_DIR/"
fastqc "$RAW_DATA_DIR/ERR8774458_2.fastq.gz" -o "$QC_DATA_DIR/"

# Step 3: Repair the data
echo "Repairing data..."
repair.sh in1="$TRIMMED_DATA_DIR/trimmed_ERR8774458_1.fastq.gz" \
in2="$TRIMMED_DATA_DIR/trimmed_ERR8774458_2.fastq.gz" \
out1="$REPAIRED_DATA_DIR/repaired_ERR8774458_1.fastq.gz" \
out2="$REPAIRED_DATA_DIR/repaired_ERR8774458_2.fastq.gz" \
outs="$REPAIRED_DATA_DIR/repaired_orphaned.fastq.gz"

# Step 4: Download reference genome
echo "Downloading reference genome..."
wget -P "$REF_DATA_DIR" https://zenodo.org/records/10886725/files/Reference.fasta

# Step 5: Index reference genome
echo "Indexing reference genome..."
bwa index "$REF_DATA_DIR/Reference.fasta"

# Step 6: Align reads to reference
echo "Aligning reads to reference..."
bwa mem "$REF_DATA_DIR/Reference.fasta" \
"$REPAIRED_DATA_DIR/repaired_ERR8774458_1.fastq.gz" \
"$REPAIRED_DATA_DIR/repaired_ERR8774458_2.fastq.gz" > "$ALIGNMENT_DIR/aligned_reads.sam"

# Step 7: Convert SAM to BAM
echo "Converting SAM to BAM..."
samtools view -Sb "$ALIGNMENT_DIR/aligned_reads.sam" > "$ALIGNMENT_DIR/aligned_reads.bam"

# Step 8: Sort the BAM file
echo "Sorting the BAM file..."
samtools sort "$ALIGNMENT_DIR/aligned_reads.bam" -o "$ALIGNMENT_DIR/sorted_aligned_reads.bam"

# Step 9: Index the sorted BAM file
echo "Indexing the sorted BAM file..."
samtools index "$ALIGNMENT_DIR/sorted_aligned_reads.bam"

# Step 10: Variant calling
echo "Calling variants..."
bcftools mpileup -f "$REF_DATA_DIR/Reference.fasta" "$ALIGNMENT_DIR/sorted_aligned_reads.bam" | \
bcftools call -mv -Ov -o "$ALIGNMENT_DIR/variants.vcf"

# Step 11: Filter variants
echo "Filtering variants..."
bcftools filter -s LowCoverage -e 'DP<10' "$ALIGNMENT_DIR/variants.vcf" -o "$ALIGNMENT_DIR/filtered_variants.vcf"

echo "Analysis completed successfully!"
