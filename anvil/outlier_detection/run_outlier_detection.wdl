version 1.0

task run_outlier_detection {
	input {
		String experiment
		File input_outlier_json
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks

  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v1.0.1b https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/outlier_detection/


		##outlier_detection

		echo "run /my_scripts/tf-atlas-pipeline/anvil/outlier_detection//outliers.sh" ${experiment} ${input_outlier_json} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks}
		/my_scripts/tf-atlas-pipeline/anvil/outlier_detection//outliers.sh ${experiment} ${input_outlier_json} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks}

		echo "copying all files to cromwell_root folder"

		gzip /project/peaks_inliers.bed
		
		cp /project/peaks_inliers.bed.gz /cromwell_root/peaks_inliers.bed.gz
		
	}
	
	output {
		File peaks_inliers_bed = "peaks_inliers.bed.gz"
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v1.0.0'
		memory: 8 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 SSD"

	}
}

workflow outlier_detection {
	input {
		String experiment
		File input_outlier_json
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
	}

	call run_outlier_detection {
		input:
			experiment = experiment,
			input_outlier_json = input_outlier_json,
			chrom_sizes = chrom_sizes,
			chroms_txt = chroms_txt,
			bigwigs = bigwigs,
			peaks = peaks
 	}
	output {
		File peaks_inliers_bed = run_outlier_detection.peaks_inliers_bed
		
	}
}