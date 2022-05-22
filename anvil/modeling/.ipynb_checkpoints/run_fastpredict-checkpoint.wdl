version 1.0

task run_fastpredict {
	input {
		String experiment
		Array [File] model
		File testing_input_json
		File splits_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		File background_regions


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts

		git clone --depth 1 --branch v1.0.1a https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/


		##fastpredict

		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/fastpredict_pipeline.sh" ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${background_regions}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/fastpredict_pipeline.sh ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${background_regions}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/predictions_and_metrics_test_peaks_test_chroms /cromwell_root/
		cp -r /project/predictions_and_metrics_test_peaks_all_chroms /cromwell_root/
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms /cromwell_root/
		cp -r /project/predictions_and_metrics_all_peaks_all_chroms /cromwell_root/


		cp -r /project/predictions_and_metrics_test_peaks_test_chroms/spearman.txt /cromwell_root/spearman.txt
		cp -r /project/predictions_and_metrics_test_peaks_test_chroms/pearson.txt /cromwell_root/pearson.txt
		cp -r /project/predictions_and_metrics_test_peaks_test_chroms/jsd.txt /cromwell_root/jsd.txt

		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/spearman.txt /cromwell_root/spearman_all_peaks.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/pearson.txt /cromwell_root/pearson_all_peaks.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/jsd.txt /cromwell_root/jsd_all_peaks.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/auprc.txt /cromwell_root/auprc.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/auroc.txt /cromwell_root/auroc.txt
	}
	
	output {
		Array[File] predictions_and_metrics_test_peaks_test_chroms = glob("predictions_and_metrics_test_peaks_test_chroms/*")
		Array[File] predictions_and_metrics_test_peaks_all_chroms = glob("predictions_and_metrics_test_peaks_all_chroms/*")

		Array[File] predictions_and_metrics_all_peaks_all_chroms = glob("predictions_and_metrics_all_peaks_all_chroms/*")
		Array[File] predictions_and_metrics_all_peaks_test_chroms = glob("predictions_and_metrics_all_peaks_test_chroms/*")

		Float spearman = read_float("spearman.txt")
		Float pearson = read_float("pearson.txt")
		Float jsd = read_float("jsd.txt")

		Float spearman_all_peaks = read_float("spearman_all_peaks.txt")
		Float pearson_all_peaks = read_float("pearson_all_peaks.txt")
		Float jsd_all_peaks = read_float("jsd_all_peaks.txt")
		Float auprc = read_float("auprc.txt")
		Float auroc = read_float("auroc.txt")
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v1.0.0'
		memory: 32 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		gpuType: "nvidia-tesla-k80"
		gpuCount: 1
		nvidiaDriverVersion: "418.87.00"
  		maxRetries: 3 
	}
}

workflow fastpredict {
	input {
		String experiment
		Array [File] model
		File testing_input_json
		File splits_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		File background_regions

	}

	call run_fastpredict {
		input:
			experiment = experiment,
			model = model,
			testing_input_json = testing_input_json,
			splits_json = splits_json,
			reference_file = reference_file,
			reference_file_index = reference_file_index,	
			chrom_sizes = chrom_sizes,
			chroms_txt = chroms_txt,
			bigwigs = bigwigs,
			peaks = peaks,
			background_regions = background_regions
 	}
	output {
		Array[File] predictions_and_metrics_all_peaks_test_chroms = run_fastpredict.predictions_and_metrics_all_peaks_test_chroms
		Array[File] predictions_and_metrics_test_peaks_test_chroms = run_fastpredict.predictions_and_metrics_test_peaks_test_chroms
		Array[File] predictions_and_metrics_all_peaks_all_chroms = run_fastpredict.predictions_and_metrics_all_peaks_all_chroms
		Array[File] predictions_and_metrics_test_peaks_all_chroms = run_fastpredict.predictions_and_metrics_test_peaks_all_chroms
		Float spearman = run_fastpredict.spearman
		Float pearson = run_fastpredict.pearson
		Float jsd = run_fastpredict.jsd
		Float spearman_all_peaks = run_fastpredict.spearman_all_peaks
		Float pearson_all_peaks = run_fastpredict.pearson_all_peaks
		Float jsd_all_peaks = run_fastpredict.jsd_all_peaks
		Float auprc = run_fastpredict.auprc
		Float auroc = run_fastpredict.auroc
		
	}
}
