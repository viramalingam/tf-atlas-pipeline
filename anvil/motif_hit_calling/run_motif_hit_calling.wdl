version 1.0

task run_motif_hit_calling {
	input {
		String experiment
		File modisco_h5
		File peaks
		File shap_h5    
		String match_type
		String shap_h5_type
		?Float alpha
		?Int window
		File chroms_txt


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v2.1.0-rc.3 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/motif_hit_calling/

		##motif_hit_calling

        mkdir -p /project/$experiment
 
        finemo extract-regions-h5 -c $shap_h5 -o /project/$experiment/regions_bw.npz -w $window -t $shap_h5_type

        finemo call-hits -a $alpha -M $match_type -r /project/$experiment/regions_bw.npz -m $modisco_h5 -p $peaks -C $chroms_txt -o /project/$experiment

        finemo report -H /project/$experiment/hits.tsv -r /project/$experiment/regions_bw.np -m $modisco_h5 -p $peaks -o /project/$experiment/ -W $window

		echo "copying all files to cromwell_root folder"
        
		tar -xvf /project/$experiment/
		
		cp -r /project/${experiment}.tar /cromwell_root/motif_hits_tar
		
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
		gpuType: "nvidia-tesla-k80"
		gpuCount: 1
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
		?Float alpha=0.6
		?Int window=400
		File chroms_txt      
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
			chroms_txt=chroms_txt 

	}
	output {
		File motif_hits_tar = run_motif_hit_calling.motif_hits_tar
		
	}
}



