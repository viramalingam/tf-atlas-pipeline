version 1.0
task run_motif_hit_calling {
	input {
		String experiment
		File modisco_h5
		File peaks
		File shap_h5  
		File chroms_txt  
		Float? lambda
		Float? cwm_threshold
		Int? window
		String? gpuType   
		String? sqrt_transform
	}
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch main https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/motif_hit_calling/
		
		##motif_hit_calling
		
		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment} ${modisco_h5} ${peaks} ${shap_h5} ${chroms_txt} ${lambda} ${cwm_threshold} ${sqrt_transform} ${window}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment} ${modisco_h5} ${peaks} ${shap_h5} ${chroms_txt} ${lambda} ${cwm_threshold} ${sqrt_transform} ${window}
		echo "copying all files to cromwell_root folder"
		
		tar -cf /${experiment}/hits.tar /${experiment}/hits
		cp -r /${experiment}/hits.tar /cromwell_root/motif_hits.tar
		cp -r /${experiment}/hits/hits_unique.tsv /cromwell_root/hits_unique.tsv
	}
	
	output {
		File motif_hits_tar = "motif_hits.tar"
		File hits_unique_tsv = "hits_unique.tsv"
	
	}
	runtime {
		docker: 'vivekramalingam/gcp-motif_hits_dev_sqrt-transform'
		memory: "16 GB"
		cpu: 4
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		gpuCount: 1
		gpuType: "nvidia-tesla-" + gpuType
		zones: "us-central1-a us-central1-b us-central1-c us-west1-a us-west1-b us-west1-c us-west4-a us-west4-b us-west4-c us-east1-b us-east1-c us-east1-d us-east4-a us-east4-b us-east4-c us-east5-a us-east5-b us-east5-c us-west2-a us-west2-b us-west2-c us-west3-a us-west3-b us-west3-c" 
		nvidiaDriverVersion: "535.161.08"
		maxRetries: 1
	}
}
workflow motif_hit_calling {
	input {
		String experiment
		File modisco_h5
		File peaks
		File shap_h5    
		File chroms_txt
		Float? lambda=0.7
		Float? cwm_threshold=0.3
		Int? window=400
		String? gpuType="p4"
		String? sqrt_transform="True"
	}
	call run_motif_hit_calling {
		input:
			experiment=experiment,
			modisco_h5=modisco_h5,
			peaks=peaks,
			shap_h5=shap_h5,
			chroms_txt=chroms_txt,
			lambda=lambda,
			cwm_threshold=cwm_threshold,
			window=window,
			gpuType=gpuType,
			sqrt_transform=sqrt_transform
	}
	output {
		File motif_hits_tar = run_motif_hit_calling.motif_hits_tar
		File hits_unique_tsv = run_motif_hit_calling.hits_unique_tsv
	}
}