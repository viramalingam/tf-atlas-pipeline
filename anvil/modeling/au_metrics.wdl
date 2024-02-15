version 1.0

task run_au_metrics {
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
		Boolean? reverse_complement_average
		Int input_seq_len
		Int output_len
		File? exclude_background_regions
	}
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		
		git clone --depth 1 --branch v2.1.0-rc.9 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/
		
		##au_metrics
		
		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/au_metrics.sh" ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${background_regions} ${reverse_complement_average} ${input_seq_len} ${output_len} ${exclude_background_regions}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/au_metrics.sh ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${background_regions} ${reverse_complement_average} ${input_seq_len} ${output_len} ${exclude_background_regions}
		
		
		echo "copying all files to cromwell_root folder"

		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/auprc.txt /cromwell_root/auprc.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/auroc.txt /cromwell_root/auroc.txt
		cp -r /project/predictions_and_metrics_all_peaks_test_chroms/auprc_baseline.txt /cromwell_root/auprc_baseline.txt


		
	}
	
	output {

		Float auprc = read_float("auprc.txt")
		Float auroc = read_float("auroc.txt")
		Float auprc_baseline = read_float("auprc_baseline.txt")

	
	
	}

runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
		memory: 20 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		gpuType: "nvidia-tesla-k80 nvidia-tesla-t4 nvidia-tesla-p4"
		zones: "us-central1-a us-central1-b us-central1-c us-west1-a us-west1-b us-west1-c us-west2-a us-west2-b us-west2-c us-west3-a us-west3-b us-west3-c us-west4-a us-west4-b us-west4-c us-east1-b us-east1-c us-east1-d us-east4-a us-east4-b us-east4-c us-east5-a us-east5-b us-east5-c" 
		gpuCount: 1
		nvidiaDriverVersion: "418.87.00"
		maxRetries: 1 
	}
}

workflow au_metrics {
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
		Boolean? reverse_complement_average = true
		Int input_seq_len = 2114
		Int output_len = 1000  
		File? exclude_background_regions
	}
	
	call run_au_metrics {
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
			background_regions = background_regions,
			reverse_complement_average = reverse_complement_average,
			input_seq_len = input_seq_len,
			output_len = output_len,
			exclude_background_regions = exclude_background_regions
	}
	output {
    
		Float auprc = run_au_metrics.auprc
		Float auroc = run_au_metrics.auroc
		Float auprc_baseline = run_au_metrics.auprc_baseline

	}
}
