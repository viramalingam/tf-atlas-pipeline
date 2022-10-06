version 1.0

task run_mean_shap {
	input {
		Array [File]? counts_shap
		Array [File]? profile_shap

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
		Array [File]? counts_shap
		Array [File]? profile_shap




	}

	call run_mean_shap {
		input:
		counts_shap = counts_shap,
		profile_shap = profile_shap

	}
	output {
		File profile_mean_shap_scores_h5 = run_mean_shap.profile_mean_shap_scores_h5
		File counts_mean_shap_scores_h5 = run_mean_shap.counts_mean_shap_scores_h5
		
	}
}