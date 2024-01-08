version 1.0

task run_modelstats {
	input {
		String experiment
		Array [File] model

	}	
	command {
		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts
		git clone --depth 1 --branch v2.0.0-rc.1 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/


		#modelstats

		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/model_stats.sh" ${experiment} ${sep=',' model}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/model_stats.sh ${experiment} ${sep=',' model}
		echo "copying all files to cromwell_root folder"
		
		cp -r /project/model/alpha.txt /cromwell_root/alpha.txt
		cp -r /project/model/beta.txt /cromwell_root/beta.txt
		cp -r /project/model/bias_term.txt /cromwell_root/bias_term.txt
		#model_output=alpha(sequence)+beta(control)+bias_term
	}
	
	output {
		Float alpha = read_float("alpha.txt")
		Float beta = read_float("beta.txt")
		Float bias_term = read_float("bias_term.txt")
	
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.0.0-rc.1'
		memory: 8 + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 HDD"
		gpuType: "nvidia-tesla-k80"
		gpuCount: 1
		nvidiaDriverVersion: "418.87.00"
		maxRetries: 1
	}
}

workflow modelstats {
	input {
		String experiment
		Array [File] model
	}

	call run_modelstats {
		input:
			experiment = experiment,
			model = model
 	}
	output {
		Float alpha = run_modelstats.alpha
		Float beta = run_modelstats.beta
		Float bias_term = run_modelstats.bias_term
	}
}