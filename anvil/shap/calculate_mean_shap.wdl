version 1.0

task mean_shap {
	input {
		File? shap_0
		File? shap_1
		File? shap_2
		File? shap_3
		File? shap_4
		File? shap_5
		File? shap_6
		File? shap_7
		File? shap_8
		File? shap_9

	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch main https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/shap/

		##mean shap

		echo "run /my_scripts/tf-atlas-pipeline/anvil/shap/calculate_mean_shap.sh" ${shap_0},${shap_1},${shap_2},${shap_3},${shap_4},${shap_6},${shap_7},${shap_8},${shap_9}
		/my_scripts/tf-atlas-pipeline/anvil/shap/calculate_mean_shap.sh ${shap_0},${shap_1},${shap_2},${shap_3},${shap_4},${shap_6},${shap_7},${shap_8},${shap_9}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/shap_dir_peaks/counts_mean_shap_scores.h5 /cromwell_root/counts_scores.h5
		cp -r /project/shap_dir_peaks/profile_mean_shap_scores.h5 /cromwell_root/profile_scores.h5
	}
	
	output {
		File profile_mean_shap_scores_h5 = "profile_mean_shap_scores.h5"
		File counts_mean_shap_scores_h5 = "counts_mean_shap_scores.h5"
		        
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v1.6.5'
		memory: 32 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"
		maxRetries: 1
	}
}

workflow mean_shap {
	input {
		File? shap_0
		File? shap_1
		File? shap_2
		File? shap_3
		File? shap_4
		File? shap_5
		File? shap_6
		File? shap_7
		File? shap_8
		File? shap_9


	}

	call run_mean_shap {
		input:
		shap_0 = shap_0
		shap_1 = shap_1
		shap_2 = shap_2
		shap_3 = shap_3
		shap_4 = shap_4
		shap_5 = shap_5
		shap_6 = shap_6
		shap_7 = shap_7
		shap_8 = shap_8
		shap_9 = shap_9

	}
	output {
		File profile_mean_shap_scores_h5 = run_mean_shap.profile_mean_shap_scores_h5
		File counts_mean_shap_scores_h5 = run_mean_shap.counts_mean_shap_scores_h5
		
	}
}