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
		Int seed
		Int input_seq_len
		Int output_len

  	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v2.1.0-rc.7 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/shap/

		##shap

		echo "run /my_scripts/tf-atlas-pipeline/anvil/shap/shap_pipeline.sh" ${experiment} ${input_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${sep=',' model} ${seed} ${input_seq_len} ${output_len}
		/my_scripts/tf-atlas-pipeline/anvil/shap/shap_pipeline.sh ${experiment} ${input_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${sep=',' model} ${seed} ${input_seq_len} ${output_len}

		echo "copying all files to cromwell_root folder"
		
		cp -r /project/shap_dir_peaks /cromwell_root/
		cp -r /project/shap_dir_peaks/counts_scores.h5 /cromwell_root/counts_scores.h5
		cp -r /project/shap_dir_peaks/profile_scores.h5 /cromwell_root/profile_scores.h5
		cp -r /project/shap_dir_peaks/counts_scores.bw /cromwell_root/counts_scores.bw
		cp -r /project/shap_dir_peaks/profile_scores.bw /cromwell_root/profile_scores.bw
	}
	
	output {
		Array[File] shap_dir_peaks = glob("shap_dir_peaks/*")
		File counts_shap_scores = "counts_scores.h5"
		File profile_shap_scores = "profile_scores.h5"
		File counts_shap_scores_bw = "counts_scores.bw"
		File profile_shap_scores_bw = "profile_scores.bw"
		        
	
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
		memory: 30 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 HDD"
		gpuType: "nvidia-tesla-k80"
		gpuCount: 1
		nvidiaDriverVersion: "418.87.00"
		maxRetries: 1
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
		Int seed=0
		Int input_seq_len = 2114
		Int output_len = 1000

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
			model = model,
			seed = seed,
			input_seq_len = input_seq_len,
			output_len = output_len
	}
	output {
		Array[File] shap_dir_peaks = run_shap.shap_dir_peaks
		File profile_shap_scores = run_shap.profile_shap_scores
		File counts_shap_scores = run_shap.counts_shap_scores
		File profile_shap_scores_bw = run_shap.profile_shap_scores_bw
		File counts_shap_scores_bw = run_shap.counts_shap_scores_bw
		
	}
}
