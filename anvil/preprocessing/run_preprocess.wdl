version 1.0

task run_preprocess {
	input {
		String experiment
		String encode_access_key
		String encode_secret_key
		File metadata
		File chrom_sizes
	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch main https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/preprocessing/


		##preprocessing
		echo "run /my_scripts/tf-atlas-pipeline/anvil/preprocessing/run_preprocess.sh"
		/my_scripts/tf-atlas-pipeline/anvil/preprocessing/run_preprocess.sh experiment ${encode_access_key} ${encode_secret_key} ${metadata} ${chrom_sizes}
		cp downloads/*.bed.gz /cromwell_root/peaks.bed.gz
		cp -r bigWigs /cromwell_root/
		
	}
	
	output {
		File peaks_bed = "peaks.bed.gz"
		Array[File] output_bw = glob("bigWigs/*.bigWig")
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
		memory: 40 + "GB"
		bootDiskSizeGb: 200
		disks: "local-disk 1000 HDD"
	}
}

workflow preprocess {
	input {
		String experiment
		String encode_access_key
		String encode_secret_key
		File metadata
		File chrom_sizes
	}

	call run_preprocess {
		input:
			experiment = experiment,
			encode_access_key = encode_access_key,
			encode_secret_key = encode_secret_key,
			metadata = metadata,
			chrom_sizes = chrom_sizes
	}
	output {
		File peaks_bed = run_preprocess.peaks_bed
		Array[File] output_bw = run_preprocess.output_bw
		

	}
}
