version 1.0
task run_motif_hit_calling {
	input {
		String experiment
		File counts_modisco_h5
		File profile_modisco_h5
		File peaks
		File counts_shap_h5
		File profile_shap_h5
		File chroms_txt
		Float? cwm_threshold
		Int? window
		String? gpuType
		String? sqrt_transform
	}
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v2.3.3 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/motif_hit_calling/
		
		##motif_hit_calling
		
		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment}_counts_0p6 ${counts_modisco_h5} ${peaks} ${counts_shap_h5} ${chroms_txt} 0.6 ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment}_counts_0p6 ${counts_modisco_h5} ${peaks} ${counts_shap_h5} ${chroms_txt} 0.6 ${cwm_threshold} ${sqrt_transform} ${window}
		
		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment}_counts_0p7 ${counts_modisco_h5} ${peaks} ${counts_shap_h5} ${chroms_txt} 0.7 ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment}_counts_0p7 ${counts_modisco_h5} ${peaks} ${counts_shap_h5} ${chroms_txt} 0.7 ${cwm_threshold} ${sqrt_transform} ${window}
		
		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment}_counts_0p8 ${counts_modisco_h5} ${peaks} ${counts_shap_h5} ${chroms_txt} 0.8 ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment}_counts_0p8 ${counts_modisco_h5} ${peaks} ${counts_shap_h5} ${chroms_txt} 0.8 ${cwm_threshold} ${sqrt_transform} ${window}

		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment}_counts_0p9 ${counts_modisco_h5} ${peaks} ${counts_shap_h5} ${chroms_txt} 0.9 ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment}_counts_0p9 ${counts_modisco_h5} ${peaks} ${counts_shap_h5} ${chroms_txt} 0.9 ${cwm_threshold} ${sqrt_transform} ${window}

		
		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment}_profile_0p6 ${profile_modisco_h5} ${peaks} ${profile_shap_h5} ${chroms_txt} 0.6 ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment}_profile_0p6 ${profile_modisco_h5} ${peaks} ${profile_shap_h5} ${chroms_txt} 0.6 ${cwm_threshold} ${sqrt_transform} ${window}
		
		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment}_profile_0p7 ${profile_modisco_h5} ${peaks} ${profile_shap_h5} ${chroms_txt} 0.7 ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment}_profile_0p7 ${profile_modisco_h5} ${peaks} ${profile_shap_h5} ${chroms_txt} 0.7 ${cwm_threshold} ${sqrt_transform} ${window}
		
		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment}_profile_0p8 ${profile_modisco_h5} ${peaks} ${profile_shap_h5} ${chroms_txt} 0.8 ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment}_profile_0p8 ${profile_modisco_h5} ${peaks} ${profile_shap_h5} ${chroms_txt} 0.8 ${cwm_threshold} ${sqrt_transform} ${window}

		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment}_profile_0p9 ${profile_modisco_h5} ${peaks} ${profile_shap_h5} ${chroms_txt} 0.9 ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment}_profile_0p9 ${profile_modisco_h5} ${peaks} ${profile_shap_h5} ${chroms_txt} 0.9 ${cwm_threshold} ${sqrt_transform} ${window}

		
		echo "copying all files to cromwell_root folder"
		
		tar -cf /cromwell_root/motif_hits.tar /${experiment}_counts_0p6/hits /${experiment}_counts_0p7/hits /${experiment}_counts_0p8/hits /${experiment}_counts_0p9/hits /${experiment}_profile_0p6/hits /${experiment}_profile_0p7/hits /${experiment}_profile_0p8/hits /${experiment}_profile_0p9/hits
	}
	
	output {
		File motif_hits_tar = "motif_hits.tar"
	
	}
	runtime {
		docker: 'vivekramalingam/gcp-motif_hits_v2.3.2'
		memory: "16 GB"
		cpu: 4
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		gpuCount: 1
		gpuType: "nvidia-tesla-" + gpuType
		zones: "us-west4-a us-west4-b us-west4-c"
		nvidiaDriverVersion: "535.161.08"
		maxRetries: 1
	}
}
workflow motif_hit_calling {
	input {
		String experiment
		File counts_modisco_h5
		File profile_modisco_h5
		File peaks
		File counts_shap_h5
		File profile_shap_h5
		File chroms_txt
		Float? cwm_threshold=0.3
		Int? window=400
		String? gpuType="p4"
		String? sqrt_transform="False"
	}
	call run_motif_hit_calling {
		input:
			experiment=experiment,
			counts_modisco_h5=counts_modisco_h5,
			profile_modisco_h5=profile_modisco_h5,
			peaks=peaks,
			counts_shap_h5=counts_shap_h5,
			profile_shap_h5=profile_shap_h5,
			chroms_txt=chroms_txt,
			cwm_threshold=cwm_threshold,
			window=window,
			gpuType=gpuType,
			sqrt_transform=sqrt_transform
	}
	output {
		File motif_hits_tar = run_motif_hit_calling.motif_hits_tar
	}
}
