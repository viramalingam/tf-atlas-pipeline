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
		Int input_seq_len
		Int output_len
	}
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		
		git clone --depth 1 --branch v2.1.0-rc.3 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/
		
		##fastpredict
		
		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/predict_on_bed_file.sh" ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${input_seq_len} ${output_len}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/predict_on_bed_file.sh ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${input_seq_len} ${output_len}
		
		
		echo "copying all files to cromwell_root folder"
		
		cp -r /project/predictions_and_metrics /cromwell_root/
	}
	
	output {
		Array[File] predictions_and_metrics = glob("predictions_and_metrics/*")

	}

runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
		memory: 32 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		gpuType: "nvidia-tesla-T4"
		zones: "us-central1-a us-central1-b us-central1-c us-west1-a us-west1-b us-west1-c us-west4-a us-west4-b us-west4-c us-east1-b us-east1-c us-east1-d us-east4-a us-east4-b us-east4-c us-east5-a us-east5-b us-east5-c us-west2-a us-west2-b us-west2-c us-west3-a us-west3-b us-west3-c" 
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
		Int input_seq_len = 2114
		Int output_len = 1000
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
			peaks = peaks,
			input_seq_len = input_seq_len,
			output_len = output_len
	}
	output {
		Array[File] predictions_and_metrics = run_predict_on_peaks.predictions_and_metrics

	}
}
