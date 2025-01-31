ure the script stops on errors
#set -e

# Input: SRA Accession ID (passed as the first argument)
SRA_ID=$1

# Ensure SRA ID is provided
if [ -z "$SRA_ID" ]; then
	            echo "Usage: $0 <SRA_ID>"
		                    exit 1
fi

# Step 1: Download SRA file using prefetch
echo "Downloading SRA file for $SRA_ID..."
mkdir -p ./output_sra
prefetch $SRA_ID

# Step 2: Convert SRA to FASTQ using fasterq-dump
echo "Converting SRA to FASTQ..."
mkdir -p ./output_fastq
fasterq-dump $SRA_ID --outdir ./home/talhadanish/talha/output_fastq

# Step 3: Run FastQC on the FASTQ files
echo "Running FastQC on FASTQ files..."
mkdir -p ./output_fastqc
fastqc ./output_fastq/${SRA_ID}.fastq -o ./output_fastqc

# Step 4: Run FastP for additional processing
echo "Running FastP on FASTQ files..."
mkdir -p ./output_fastp
fastp \
	            -i ./output_fastq/${SRA_ID}.fastq \
		                    -o ./output_fastp/${SRA_ID}_clean.fastq \
				                        --html ./output_fastp/${SRA_ID}_output_fastp.html --json ./output_fastp/${SRA_ID}_output_fastp.json \
							                        --cut_front --cut_tail --cut_mean_quality 20 --length_required 30
# Step 5: Downloading genome and running BWA alignment
echo "Step 5: Genome downloading and alignment"

# Create a directory for BWA output
mkdir -p ./output_bwa

# Download the yeast genome
GENOME_URL="https://hgdownload.soe.ucsc.edu/goldenPath/sacCer3/bigZips/sacCer3.fa.gz"
GENOME_FILE="sacCer3.fa.gz"
OUTPUT_SAM="./output_bwa/${SRA_ID}_aligned.sam"
SORTED_BAM="./output_bwa/${SRA_ID}_aligned_sorted.bam"

echo "Downloading yeast genome..."
wget $GENOME_URL -O $GENOME_FILE

# Extract genome filI
echo "Extracting genome..."
gunzip -f $GENOME_FILE  # Ensure uncompressed file is sacCer3.fa

# Index the genome with BWA
echo "Indexing the genome..."
bwa index sacCer3.fa  # Use the uncompressed file

# Perform alignment using BWA
echo "Aligning reads with BWA..."
bwa mem sacCer3 /home/talhadanish/talha/output_fastp/${SRA_ID}_clean.fastq > $OUTPUT_SAM

# Convert SAM to BAM and sort
echo "Converting SAM to sorted BAM..."
samtools view -Sb $OUTPUT_SAM | samtools sort -o $SORTED_BAM

# Index the BAM file
echo "Indexing BAM file..."
samtools index $SORTED_BAM

echo "Alignment complete. Files are in ./output_bwa"

# Generate alignment statistics
echo "Generating alignment statistics..."
samtools flagstat $SORTED_BAM > ./output_bwa/${SRA_ID}_alignment_stats.txt
samtools depth $SORTED_BAM > ./output_bwa/${SRA_ID}_coverage.txt

echo "Pipeline completed successfully!"
echo "Cleaned FASTQ files: ./fastp_data/${SRA_ID}_1.clean.fastq, ./fastp_data/${SRA_ID}_2.clean.fastq"
echo "Sorted BAM file: $SORTED_BAM"
echo "Alignment statistics: ./bwa_data/${SRA_ID}_alignment_stats.txt"
echo "Coverage file: ./bwa_data/${SRA_ID}_coverage.txt"
