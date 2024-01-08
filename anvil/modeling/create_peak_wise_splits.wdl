version 1.0

task run_peak_wise_splits {
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
		git clone --depth 1 --branch v2.0.0-rc.4 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/
		
		##peak_wise_splits
		
		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/peak_wise_splits_pipeline.sh" ${experiment} ${sep=',' bigwigs} ${peaks} ${nonpeaks} ${number_of_folds}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/peak_wise_splits_pipeline.sh ${experiment} ${sep=',' bigwigs} ${peaks} ${nonpeaks} ${number_of_folds}
		
		echo "copying all files to cromwell_root folder"
		
		cp -r /project/splits_indices /cromwell_root/
		cp -r /project/supplemental_outputs /cromwell_root/
	}
	
	output {
		Array[File] peak_wise_splits = glob("splits_indices/*")
		Array[File] supplemental_outputs = glob("supplemental_outputs/*")
		File group_df_csv = "supplemental_outputs/group_df.csv"
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.0.0-rc.1'
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
	
	call run_peak_wise_splits {
		input:
			experiment = experiment,
			bigwigs = bigwigs,
			peaks = peaks,
			nonpeaks = nonpeaks,
			number_of_folds = number_of_folds
	}
	output {
		Array[File] peak_wise_splits = run_peak_wise_splits.peak_wise_splits
		Array[File] supplemental_outputs = run_peak_wise_splits.supplemental_outputs
		File group_df_csv = run_peak_wise_splits.group_df_csv
		
	}
}
