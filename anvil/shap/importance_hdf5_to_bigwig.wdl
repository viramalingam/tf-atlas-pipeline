version 1.0

task run_shap_h5_to_bw {
	input {
		File chrom_sizes
		Array [File] shaps_dir
	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v2.1.0-rc.7 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/shap/

		##shap

		echo "run /my_scripts/tf-atlas-pipeline/anvil/shap/importance_hdf5_to_bigwig.sh" ${chrom_sizes} ${sep=',' shaps_dir}
		/my_scripts/tf-atlas-pipeline/anvil/shap/importance_hdf5_to_bigwig.sh ${chrom_sizes} ${sep=',' shaps_dir}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/shap_dir_peaks/counts_scores.bw /cromwell_root/counts_scores.bw
		cp -r /project/shap_dir_peaks/profile_scores.bw /cromwell_root/profile_scores.bw
	}
	
	output {

		File counts_shap_scores_bw = "counts_scores.bw"
		File profile_shap_scores_bw = "profile_scores.bw"

	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
		memory: 30 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"
		maxRetries: 1
	}
}

workflow shap_h5_to_bw {
	input {
		File chrom_sizes
		Array [File] shaps_dir

	}

	call run_shap_h5_to_bw {
		input:
			chrom_sizes = chrom_sizes,
			shaps_dir = shaps_dir
 	}
	output {
		File profile_shap_scores_bw = run_shap_h5_to_bw.profile_shap_scores_bw
		File counts_shap_scores_bw = run_shap_h5_to_bw.counts_shap_scores_bw
		
	}
}
