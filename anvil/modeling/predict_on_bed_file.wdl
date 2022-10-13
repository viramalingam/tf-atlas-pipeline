version 1.0

task run_predict_on_peaks {
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
		
	}
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		
		git clone --depth 1 --branch dev_chrom_predctions https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/
		
		##fastpredict
		
		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/predict_on_bed_file.sh" ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/predict_on_bed_file.sh ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks}
		
		
		echo "copying all files to cromwell_root folder"
		
		cp -r /project/predictions_and_metrics /cromwell_root/
	}
	
	output {
		Array[File] predictions_and_metrics = glob("predictions_and_metrics/*")

	}

runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v1.6.0'
		memory: 32 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		gpuType: "nvidia-tesla-k80"
		gpuCount: 1
		nvidiaDriverVersion: "418.87.00"
		maxRetries: 1 
	}
}

workflow predict_on_peaks {
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
		
	}
	
	call run_predict_on_peaks {
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
			peaks = peaks
	}
	output {
		Array[File] predictions_and_metrics = run_predict_on_peaks.predictions_and_metrics

	}
}
