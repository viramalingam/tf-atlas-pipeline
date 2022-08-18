version 1.0

task peak_wise_splits {
	input {
		String experiment
		Array[File] bigwigs 
		File peaks
		File nonpeaks
		Int number_of_folds


	}
	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch dev_peak_wise_training https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/
		
		##modelling
		
		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/peak_wise_splits_pipeline.sh" ${experiment} ${sep=',' bigwigs} ${peaks} ${nonpeaks} ${number_of_folds}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/peak_wise_splits_pipeline.sh ${experiment} ${sep=',' bigwigs} ${peaks} ${nonpeaks} ${number_of_folds}
		
		echo "copying all files to cromwell_root folder"
		
		cp -r /project/indices_dir /cromwell_root/

	}
	
	output {
		Array[File] peak_wise_splits = glob("indices_dir/*")
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_dev_peak_wise_training'
		memory: 8 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
	}
}

workflow create_peak_wise_splits {
	input {
		String experiment
		Array[File] bigwigs 
		File peaks
		File nonpeaks
		Int number_of_folds
	}
	
	call run_modelling {
		input:
			experiment = experiment,
			bigwigs = bigwigs,
			testing_input_json = testing_input_json,
			peaks = peaks,
			nonpeaks = nonpeaks,
			number_of_folds = number_of_folds
	}
	output {
		File bpnet_params_updated_json = peak_wise_splits.bpnet_params_updated_json
		Array[File] peak_wise_splits = peak_wise_splits.peak_wise_splits
		
	}
}
