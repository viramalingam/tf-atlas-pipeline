version 1.0

task run_basicstats {
	input {
		String experiment
		Array [File] bigwigs
		File peaks
		File background_regions
		File splits_json       


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v1.3.2b https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/


		#basic stats

		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/basic_stats.sh" ${experiment} ${sep=',' bigwigs} ${peaks} ${background_regions} ${splits_json}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/basic_stats.sh ${experiment} ${sep=',' bigwigs} ${peaks} ${background_regions} ${splits_json}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/chip_control_correlation_peaks/spearman.txt /cromwell_root/spearman.txt
		cp -r /project/chip_control_correlation_peaks/pearson.txt /cromwell_root/pearson.txt
		cp -r /project/chip_control_correlation_peaks/number_of_peaks.txt /cromwell_root/number_of_peaks.txt
		cp -r /project/chip_control_correlation_peaks/number_of_peaks_test_chroms.txt /cromwell_root/number_of_peaks_test_chroms.txt

		cp -r /project/chip_control_correlation_all_peaks/spearman.txt /cromwell_root/spearman_all_peaks.txt
		cp -r /project/chip_control_correlation_all_peaks/pearson.txt /cromwell_root/pearson_all_peaks.txt
	}
	
	output {
		Float spearman = read_float("spearman.txt")
		Float pearson = read_float("pearson.txt")
		Int number_of_peaks = read_int("number_of_peaks.txt")
		Int number_of_peaks_test_chroms = read_int("number_of_peaks_test_chroms.txt")
		Float spearman_all_peaks = read_float("spearman_all_peaks.txt")
		Float pearson_all_peaks = read_float("pearson_all_peaks.txt")
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v1.3.0'
		memory: 32 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		nvidiaDriverVersion: "418.87.00"
  		maxRetries: 1
	}
}

workflow basicstats {
	input {
		String experiment
		Array [File] bigwigs
		File peaks
		File background_regions
		File splits_json 

	}

	call run_basicstats {
		input:
			experiment = experiment,
			bigwigs = bigwigs,
			peaks = peaks,
			background_regions = background_regions,
			splits_json = splits_json
 	}
	output {
		Float spearman_with_control = run_basicstats.spearman
		Float pearson_with_control = run_basicstats.pearson
		Int number_of_peaks = run_basicstats.number_of_peaks
		Int number_of_peaks_test_chroms = run_basicstats.number_of_peaks_test_chroms
		Float spearman_with_control_all_peaks = run_basicstats.spearman_all_peaks
		Float pearson_with_control_all_peaks = run_basicstats.pearson_all_peaks
	}
}