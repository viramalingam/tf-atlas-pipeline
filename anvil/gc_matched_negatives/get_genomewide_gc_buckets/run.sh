ref_fasta=$1
chrom_sizes=$2
inputlen=$3
stride=$4
genome=$5
out_prefix="genomewide_gc_"$genome"_stride_"$stride"_inputlen_"$inputlen

python get_genomewide_gc_bins.py --ref_fasta $ref_fasta \
		  --chrom_sizes $chrom_sizes \
		  --out_prefix $out_prefix \
		  --inputlen $inputlen \
		  --stride $stride