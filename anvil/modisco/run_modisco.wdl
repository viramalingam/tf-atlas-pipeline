version 1.0

task run_modisco {
	input {
		String experiment
		Array [File] shap
		Int? max_seqlets    
		Int? mem_gb
		Int? number_of_cpus


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
		Array[File] modisco_profile_motifs = glob("modisco_profile/trimmed_logos/*")
		Array[File] modisco_counts_motifs = glob("modisco_counts/trimmed_logos/*")
		File modisco_profile_h5 = "modisco_profile/modisco_results.h5"
		File modisco_counts_h5 = "modisco_counts/modisco_results.h5"
		
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modisco_modiscolite_v2.0.7m'
		memory: mem_gb + "GB"
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
		Int? mem_gb=16
		Int? number_of_cpus=4        



	}




	call run_modisco {
		input:
			experiment = experiment,
			shap = shap,
			max_seqlets = max_seqlets,
			mem_gb = mem_gb,
			number_of_cpus = number_of_cpus

	}
	output {
		Array[File] modisco_profile = run_modisco.modisco_profile_motifs
		Array[File] modisco_counts = run_modisco.modisco_counts_motifs
		File modisco_profile_h5 = run_modisco.modisco_profile_h5
		File modisco_counts_h5 = run_modisco.modisco_counts_h5
		
	}
}
