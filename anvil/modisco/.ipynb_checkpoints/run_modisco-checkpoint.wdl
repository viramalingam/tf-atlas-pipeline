version 1.0

task run_modisco {
	input {
		String experiment
		Array [File] shap
		Int? max_seqlets        


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch main https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modisco/

		##modisco

		echo "run /my_scripts/tf-atlas-pipeline/anvil/modisco/modisco_pipeline.sh" ${experiment} ${sep=',' shap} ${max_seqlets}
		/my_scripts/tf-atlas-pipeline/anvil/modisco/modisco_pipeline.sh ${experiment} ${sep=',' shap} ${max_seqlets}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/modisco_profile /cromwell_root/
		cp -r /project/modisco_counts /cromwell_root/
		
	}
	
	output {
		Array[File] modisco_profile = glob("modisco_profile/*")
		Array[File] modisco_counts = glob("modisco_counts/*")
		
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modisco_modiscolite'
		memory: 16 + "GB"
		cpu: number_of_cpus
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
  		maxRetries: 1
	}
}

workflow modisco {
	input {
		String experiment
		Array [File] shap
		Int? max_seqlets=25000        
	}

	call run_modisco {
		input:
			experiment = experiment,
			shap = shap,
			max_seqlets = max_seqlets
	}
	output {
		Array[File] modisco_profile = run_modisco.modisco_profile
		Array[File] modisco_counts = run_modisco.modisco_counts
		Int max_memory_used_gb = run_modisco.max_memory_used_gb

		
	}
}
