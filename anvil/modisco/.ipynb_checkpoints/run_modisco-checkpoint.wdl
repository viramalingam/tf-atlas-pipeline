version 1.0

task run_modisco {
	input {
		String experiment
		Array [File] shap
        Int? trim_size
		Int? initial_flank_to_add
		Int? final_flank_to_add
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

		echo "run /my_scripts/tf-atlas-pipeline/anvil/modisco/modisco_pipeline.sh" ${experiment} ${sep=',' shap} ${max_seqlets} ${trim_size} ${initial_flank_to_add} ${final_flank_to_add}
		/my_scripts/tf-atlas-pipeline/anvil/modisco/modisco_pipeline.sh ${experiment} ${sep=',' shap} ${max_seqlets} ${trim_size} ${initial_flank_to_add} ${final_flank_to_add}

		echo "copying all files to cromwell_root folder"
		mkdir /cromwell_root/modisco
		cp -r /project/modisco_profile /cromwell_root/modisco/modisco_profile
		cp -r /project/modisco_counts /cromwell_root/modisco/modisco_counts
		tar -cf /cromwell_root/modisco.tar /cromwell_root/modisco
	}
	output {
		File modisco_tar = "modisco.tar"
		File modisco_profile_h5 = "modisco_profile/modisco_results.h5"
		File modisco_counts_h5 = "modisco_counts/modisco_results.h5"
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modisco_modiscolite_v2.1.0'
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
		Int? trim_size = 30
		Int? initial_flank_to_add = 10
		Int? final_flank_to_add = 0
		Int? max_seqlets=25000
		Int? mem_gb=16
		Int? number_of_cpus=4



	}

	call run_modisco {
		input:
			experiment = experiment,
			shap = shap,
			trim_size = trim_size,
			initial_flank_to_add = initial_flank_to_add,
			final_flank_to_add = final_flank_to_add,
			max_seqlets = max_seqlets,
			mem_gb = mem_gb,
			number_of_cpus = number_of_cpus

	}
	output {
		File modisco_tar = run_modisco.modisco_tar
		File modisco_profile_h5 = run_modisco.modisco_profile_h5
		File modisco_counts_h5 = run_modisco.modisco_counts_h5
	}
}
