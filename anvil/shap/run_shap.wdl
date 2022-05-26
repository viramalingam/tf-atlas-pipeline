version 1.0

task run_shap {
	input {
		String experiment
		File input_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		Array [File] model


  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch vdev_shap_single_multinomial https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/shap/

		##shap

		echo "run /my_scripts/tf-atlas-pipeline/anvil/shap/shap_pipeline.sh" ${experiment} ${input_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${sep=',' model}
		/my_scripts/tf-atlas-pipeline/anvil/shap/shap_pipeline.sh ${experiment} ${input_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${sep=',' model}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/shap /cromwell_root/
		cp -r /project/shap/counts_scores.h5 /cromwell_root/counts_scores.h5
		cp -r /project/shap/profile_scores.h5 /cromwell_root/profile_scores.h5
	}
	
	output {
		Array[File] shap = glob("shap/*")
		File profile_shape_scores = "counts_scores.h5"
		File counts_shape_scores = "profile_scores.h5"
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_vdev_shap_single_multinomial'
		memory: 30 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"
		gpuType: "nvidia-tesla-k80"
		gpuCount: 1
		nvidiaDriverVersion: "450.51.05" 
  		maxRetries: 3
	}
}

workflow shap {
	input {
		String experiment
		File input_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		Array [File] model

	}

	call run_shap {
		input:
			experiment = experiment,
			input_json = input_json,
			reference_file = reference_file,
			reference_file_index = reference_file_index,	
			chrom_sizes = chrom_sizes,
			chroms_txt = chroms_txt,
			bigwigs = bigwigs,
			peaks = peaks,
			model = model
 	}
	output {
		Array[File] shap = run_shap.shap
		File profile_shape_scores = run_shap.counts_scores.h5
		File counts_shape_scores = run_shap.profile_scores.h5
		
	}
}
