version 1.0

task run_motif_hit_calling {
	input {
		String experiment
		File modisco_h5
		File peaks
		File shap_h5    
		String match_type
		String shap_h5_type
		Float? alpha
		Int? window
		File chroms_txt
		String? gpuType
        
	}
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch main https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/motif_hit_calling/
 		       
		##motif_hit_calling
		
		echo "/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh" ${experiment} ${modisco_h5} ${peaks} ${shap_h5} ${match_type} ${shap_h5_type} ${alpha} ${window} ${chroms_txt}
		/my_scripts/tf-atlas-pipeline/anvil/motif_hit_calling/motif_hit_calling.sh ${experiment} ${modisco_h5} ${peaks} ${shap_h5} ${match_type} ${shap_h5_type} ${alpha} ${window} ${chroms_txt}
		echo "copying all files to cromwell_root folder"
		
		cd /project     
		tar -xvf /project/hits
		
		cp -r /project/hits.tar /cromwell_root/motif_hits_tar
		
	}
	
	output {
		File motif_hits_tar = "motif_hits_tar"
		
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-motif_hits'
		memory: "16 GB"
		cpu: 4
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		gpuCount: 1
		gpuType: "nvidia-tesla-" + gpuType
		zones: "us-central1-a us-central1-b us-central1-c us-west1-a us-west1-b us-west1-c us-west4-a us-west4-b us-west4-c us-east1-b us-east1-c us-east1-d us-east4-a us-east4-b us-east4-c us-east5-a us-east5-b us-east5-c us-west2-a us-west2-b us-west2-c us-west3-a us-west3-b us-west3-c" 
		nvidiaDriverVersion: "418.87.00"
		maxRetries: 1
	}
}

workflow motif_hit_calling {
	input {
		String experiment
		File modisco_h5
		File peaks
		File shap_h5    
		String match_type
		String shap_h5_type
		Float? alpha=0.6
		Int? window=400
		File chroms_txt
		String? gpuType="p4"

	}



	call run_motif_hit_calling {
		input:
			experiment=experiment,
			modisco_h5=modisco_h5,
			peaks=peaks,
			shap_h5=shap_h5,
			match_type=match_type,
			shap_h5_type=shap_h5_type,
			alpha=alpha,
			window=window,
			chroms_txt=chroms_txt,
			gpuType=gpuType

	}
	output {
		File motif_hits_tar = run_motif_hit_calling.motif_hits_tar
		
	}
}



