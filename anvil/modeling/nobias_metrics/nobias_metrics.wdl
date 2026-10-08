version 1.0

# Released BPNet model performance with the bias (control) tracks and with
# the bias set to zero, plus probes on the frozen model and bias-only
# baselines, for one experiment and one fold (anvil/modeling/nobias_metrics/,
# see nobias_metrics.sh and README.md there). Modelled on
# anvil/modeling/au_metrics.wdl: same inputs and docker; run once per fold with
# that fold's model and splits_json. The scripts are cloned at the tag below.
# Outputs: nobias_metrics.tsv (every score x metric) and one Float per value,
# <metric><tag> with metric auprc, auroc, pearson, spearman, pearson_all_peaks,
# spearman_all_peaks and tag "" (model, with bias), _wo_bias (model, bias = 0),
# _linear_probe(_wo_bias), _dense_probe(_wo_bias), _control_only,
# _shuffled_sequence(_wo_bias), _label_shuffle(_wo_bias),
# _label_shuffle_linear_probe(_wo_bias), _label_shuffle_dense_probe(_wo_bias).

task run_nobias_metrics {
	input {
		String experiment
		Int fold
		Array [File] model
		File testing_input_json
		File splits_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		File background_regions
		Boolean? reverse_complement_average
		Int input_seq_len
		Int output_len
		File? exclude_background_regions
		Boolean run_probes_and_baselines
		Boolean save_predictions
		String gpuType
		Int cpu
		Int memory_gb
		Int preemptible_tries
	}
	command {
		# the task working directory (/cromwell_root on PAPI, /mnt/disks/cromwell_root on
		# GCP Batch): outputs are copied here, so record it before cd-ing away
		workdir=$(pwd)

		#create data directories and download scripts
		cd /; mkdir my_scripts
		cd /my_scripts

		git clone --depth 1 --branch nobias_metrics-v0.1.0 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/nobias_metrics/

		##nobias_metrics

		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/nobias_metrics/nobias_metrics.sh" ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${background_regions} ${reverse_complement_average} ${input_seq_len} ${output_len} "${exclude_background_regions}" ${fold} ${run_probes_and_baselines}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/nobias_metrics/nobias_metrics.sh ${experiment} ${sep=',' model} ${testing_input_json} ${splits_json} ${reference_file} ${reference_file_index} ${chrom_sizes} ${chroms_txt} ${sep=',' bigwigs} ${peaks} ${background_regions} ${reverse_complement_average} ${input_seq_len} ${output_len} "${exclude_background_regions}" ${fold} ${run_probes_and_baselines} || exit 1

		echo "copying all files to the task working directory"

		cp -r /project/nobias_outputs/* $workdir/
		if [ "${save_predictions}" = "true" ]; then
			cp /project/predictions_and_metrics_all_peaks_test_chroms_wo_bias/${experiment}_split000_predictions.h5 $workdir/predictions_wo_bias.h5
		fi
	}

	output {

		File nobias_metrics_tsv = "nobias_metrics.tsv"
		File metrics_per_model_tar = "metrics_per_model.tar"
		Array[File] predictions_wo_bias_h5 = glob("predictions_wo_bias*.h5")

		Float auprc = read_float("auprc.txt")
		Float auroc = read_float("auroc.txt")
		Float pearson = read_float("pearson.txt")
		Float spearman = read_float("spearman.txt")
		Float pearson_all_peaks = read_float("pearson_all_peaks.txt")
		Float spearman_all_peaks = read_float("spearman_all_peaks.txt")
		Float auprc_wo_bias = read_float("auprc_wo_bias.txt")
		Float auroc_wo_bias = read_float("auroc_wo_bias.txt")
		Float pearson_wo_bias = read_float("pearson_wo_bias.txt")
		Float spearman_wo_bias = read_float("spearman_wo_bias.txt")
		Float pearson_all_peaks_wo_bias = read_float("pearson_all_peaks_wo_bias.txt")
		Float spearman_all_peaks_wo_bias = read_float("spearman_all_peaks_wo_bias.txt")
		Float auprc_linear_probe_wo_bias = read_float("auprc_linear_probe_wo_bias.txt")
		Float auroc_linear_probe_wo_bias = read_float("auroc_linear_probe_wo_bias.txt")
		Float pearson_linear_probe_wo_bias = read_float("pearson_linear_probe_wo_bias.txt")
		Float spearman_linear_probe_wo_bias = read_float("spearman_linear_probe_wo_bias.txt")
		Float pearson_all_peaks_linear_probe_wo_bias = read_float("pearson_all_peaks_linear_probe_wo_bias.txt")
		Float spearman_all_peaks_linear_probe_wo_bias = read_float("spearman_all_peaks_linear_probe_wo_bias.txt")
		Float auprc_dense_probe_wo_bias = read_float("auprc_dense_probe_wo_bias.txt")
		Float auroc_dense_probe_wo_bias = read_float("auroc_dense_probe_wo_bias.txt")
		Float pearson_dense_probe_wo_bias = read_float("pearson_dense_probe_wo_bias.txt")
		Float spearman_dense_probe_wo_bias = read_float("spearman_dense_probe_wo_bias.txt")
		Float pearson_all_peaks_dense_probe_wo_bias = read_float("pearson_all_peaks_dense_probe_wo_bias.txt")
		Float spearman_all_peaks_dense_probe_wo_bias = read_float("spearman_all_peaks_dense_probe_wo_bias.txt")
		Float auprc_linear_probe = read_float("auprc_linear_probe.txt")
		Float auroc_linear_probe = read_float("auroc_linear_probe.txt")
		Float pearson_linear_probe = read_float("pearson_linear_probe.txt")
		Float spearman_linear_probe = read_float("spearman_linear_probe.txt")
		Float pearson_all_peaks_linear_probe = read_float("pearson_all_peaks_linear_probe.txt")
		Float spearman_all_peaks_linear_probe = read_float("spearman_all_peaks_linear_probe.txt")
		Float auprc_dense_probe = read_float("auprc_dense_probe.txt")
		Float auroc_dense_probe = read_float("auroc_dense_probe.txt")
		Float pearson_dense_probe = read_float("pearson_dense_probe.txt")
		Float spearman_dense_probe = read_float("spearman_dense_probe.txt")
		Float pearson_all_peaks_dense_probe = read_float("pearson_all_peaks_dense_probe.txt")
		Float spearman_all_peaks_dense_probe = read_float("spearman_all_peaks_dense_probe.txt")
		Float auprc_control_only = read_float("auprc_control_only.txt")
		Float auroc_control_only = read_float("auroc_control_only.txt")
		Float pearson_control_only = read_float("pearson_control_only.txt")
		Float spearman_control_only = read_float("spearman_control_only.txt")
		Float pearson_all_peaks_control_only = read_float("pearson_all_peaks_control_only.txt")
		Float spearman_all_peaks_control_only = read_float("spearman_all_peaks_control_only.txt")
		Float auprc_shuffled_sequence = read_float("auprc_shuffled_sequence.txt")
		Float auroc_shuffled_sequence = read_float("auroc_shuffled_sequence.txt")
		Float pearson_shuffled_sequence = read_float("pearson_shuffled_sequence.txt")
		Float spearman_shuffled_sequence = read_float("spearman_shuffled_sequence.txt")
		Float pearson_all_peaks_shuffled_sequence = read_float("pearson_all_peaks_shuffled_sequence.txt")
		Float spearman_all_peaks_shuffled_sequence = read_float("spearman_all_peaks_shuffled_sequence.txt")
		Float auprc_shuffled_sequence_wo_bias = read_float("auprc_shuffled_sequence_wo_bias.txt")
		Float auroc_shuffled_sequence_wo_bias = read_float("auroc_shuffled_sequence_wo_bias.txt")
		Float pearson_shuffled_sequence_wo_bias = read_float("pearson_shuffled_sequence_wo_bias.txt")
		Float spearman_shuffled_sequence_wo_bias = read_float("spearman_shuffled_sequence_wo_bias.txt")
		Float pearson_all_peaks_shuffled_sequence_wo_bias = read_float("pearson_all_peaks_shuffled_sequence_wo_bias.txt")
		Float spearman_all_peaks_shuffled_sequence_wo_bias = read_float("spearman_all_peaks_shuffled_sequence_wo_bias.txt")
		Float auprc_label_shuffle = read_float("auprc_label_shuffle.txt")
		Float auroc_label_shuffle = read_float("auroc_label_shuffle.txt")
		Float pearson_label_shuffle = read_float("pearson_label_shuffle.txt")
		Float spearman_label_shuffle = read_float("spearman_label_shuffle.txt")
		Float pearson_all_peaks_label_shuffle = read_float("pearson_all_peaks_label_shuffle.txt")
		Float spearman_all_peaks_label_shuffle = read_float("spearman_all_peaks_label_shuffle.txt")
		Float auprc_label_shuffle_wo_bias = read_float("auprc_label_shuffle_wo_bias.txt")
		Float auroc_label_shuffle_wo_bias = read_float("auroc_label_shuffle_wo_bias.txt")
		Float pearson_label_shuffle_wo_bias = read_float("pearson_label_shuffle_wo_bias.txt")
		Float spearman_label_shuffle_wo_bias = read_float("spearman_label_shuffle_wo_bias.txt")
		Float pearson_all_peaks_label_shuffle_wo_bias = read_float("pearson_all_peaks_label_shuffle_wo_bias.txt")
		Float spearman_all_peaks_label_shuffle_wo_bias = read_float("spearman_all_peaks_label_shuffle_wo_bias.txt")
		Float auprc_label_shuffle_linear_probe_wo_bias = read_float("auprc_label_shuffle_linear_probe_wo_bias.txt")
		Float auroc_label_shuffle_linear_probe_wo_bias = read_float("auroc_label_shuffle_linear_probe_wo_bias.txt")
		Float pearson_label_shuffle_linear_probe_wo_bias = read_float("pearson_label_shuffle_linear_probe_wo_bias.txt")
		Float spearman_label_shuffle_linear_probe_wo_bias = read_float("spearman_label_shuffle_linear_probe_wo_bias.txt")
		Float pearson_all_peaks_label_shuffle_linear_probe_wo_bias = read_float("pearson_all_peaks_label_shuffle_linear_probe_wo_bias.txt")
		Float spearman_all_peaks_label_shuffle_linear_probe_wo_bias = read_float("spearman_all_peaks_label_shuffle_linear_probe_wo_bias.txt")
		Float auprc_label_shuffle_dense_probe_wo_bias = read_float("auprc_label_shuffle_dense_probe_wo_bias.txt")
		Float auroc_label_shuffle_dense_probe_wo_bias = read_float("auroc_label_shuffle_dense_probe_wo_bias.txt")
		Float pearson_label_shuffle_dense_probe_wo_bias = read_float("pearson_label_shuffle_dense_probe_wo_bias.txt")
		Float spearman_label_shuffle_dense_probe_wo_bias = read_float("spearman_label_shuffle_dense_probe_wo_bias.txt")
		Float pearson_all_peaks_label_shuffle_dense_probe_wo_bias = read_float("pearson_all_peaks_label_shuffle_dense_probe_wo_bias.txt")
		Float spearman_all_peaks_label_shuffle_dense_probe_wo_bias = read_float("spearman_all_peaks_label_shuffle_dense_probe_wo_bias.txt")
		Float auprc_label_shuffle_linear_probe = read_float("auprc_label_shuffle_linear_probe.txt")
		Float auroc_label_shuffle_linear_probe = read_float("auroc_label_shuffle_linear_probe.txt")
		Float pearson_label_shuffle_linear_probe = read_float("pearson_label_shuffle_linear_probe.txt")
		Float spearman_label_shuffle_linear_probe = read_float("spearman_label_shuffle_linear_probe.txt")
		Float pearson_all_peaks_label_shuffle_linear_probe = read_float("pearson_all_peaks_label_shuffle_linear_probe.txt")
		Float spearman_all_peaks_label_shuffle_linear_probe = read_float("spearman_all_peaks_label_shuffle_linear_probe.txt")
		Float auprc_label_shuffle_dense_probe = read_float("auprc_label_shuffle_dense_probe.txt")
		Float auroc_label_shuffle_dense_probe = read_float("auroc_label_shuffle_dense_probe.txt")
		Float pearson_label_shuffle_dense_probe = read_float("pearson_label_shuffle_dense_probe.txt")
		Float spearman_label_shuffle_dense_probe = read_float("spearman_label_shuffle_dense_probe.txt")
		Float pearson_all_peaks_label_shuffle_dense_probe = read_float("pearson_all_peaks_label_shuffle_dense_probe.txt")
		Float spearman_all_peaks_label_shuffle_dense_probe = read_float("spearman_all_peaks_label_shuffle_dense_probe.txt")
		Float auprc_baseline = read_float("auprc_baseline.txt")
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
		cpu: cpu
		memory: memory_gb + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 100 SSD"
		gpuType: "nvidia-tesla-" + gpuType
		gpuCount: 1
		zones: "us-central1-a us-central1-b us-central1-c us-west1-a us-west1-b us-west1-c us-west4-a us-west4-b us-west4-c us-east1-b us-east1-c us-east1-d us-east4-a us-east4-b us-east4-c us-east5-a us-east5-b us-east5-c us-west2-a us-west2-b us-west2-c us-west3-a us-west3-b us-west3-c"
		nvidiaDriverVersion: "535.161.08"
		preemptible: preemptible_tries
		maxRetries: 1
	}
}

workflow nobias_metrics {
	input {
		String experiment
		Int fold
		Array [File] model
		File testing_input_json
		File splits_json
		File reference_file
		File reference_file_index
		File chrom_sizes
		File chroms_txt
		Array [File] bigwigs
		File peaks
		File background_regions
		Boolean? reverse_complement_average = true
		Int input_seq_len = 2114
		Int output_len = 1000
		File? exclude_background_regions
		Boolean run_probes_and_baselines = true
		Boolean save_predictions = false
		String gpuType = "t4"
		Int cpu = 8
		Int memory_gb = 52
		Int preemptible_tries = 0
	}

	call run_nobias_metrics {
		input:
			experiment = experiment,
			fold = fold,
			model = model,
			testing_input_json = testing_input_json,
			splits_json = splits_json,
			reference_file = reference_file,
			reference_file_index = reference_file_index,
			chrom_sizes = chrom_sizes,
			chroms_txt = chroms_txt,
			bigwigs = bigwigs,
			peaks = peaks,
			background_regions = background_regions,
			reverse_complement_average = reverse_complement_average,
			input_seq_len = input_seq_len,
			output_len = output_len,
			exclude_background_regions = exclude_background_regions,
			run_probes_and_baselines = run_probes_and_baselines,
			save_predictions = save_predictions,
			gpuType = gpuType,
			cpu = cpu,
			memory_gb = memory_gb,
			preemptible_tries = preemptible_tries
	}

	output {
		File nobias_metrics_tsv = run_nobias_metrics.nobias_metrics_tsv
		File metrics_per_model_tar = run_nobias_metrics.metrics_per_model_tar
		Array[File] predictions_wo_bias_h5 = run_nobias_metrics.predictions_wo_bias_h5
		Float auprc = run_nobias_metrics.auprc
		Float auroc = run_nobias_metrics.auroc
		Float pearson = run_nobias_metrics.pearson
		Float spearman = run_nobias_metrics.spearman
		Float pearson_all_peaks = run_nobias_metrics.pearson_all_peaks
		Float spearman_all_peaks = run_nobias_metrics.spearman_all_peaks
		Float auprc_wo_bias = run_nobias_metrics.auprc_wo_bias
		Float auroc_wo_bias = run_nobias_metrics.auroc_wo_bias
		Float pearson_wo_bias = run_nobias_metrics.pearson_wo_bias
		Float spearman_wo_bias = run_nobias_metrics.spearman_wo_bias
		Float pearson_all_peaks_wo_bias = run_nobias_metrics.pearson_all_peaks_wo_bias
		Float spearman_all_peaks_wo_bias = run_nobias_metrics.spearman_all_peaks_wo_bias
		Float auprc_linear_probe_wo_bias = run_nobias_metrics.auprc_linear_probe_wo_bias
		Float auroc_linear_probe_wo_bias = run_nobias_metrics.auroc_linear_probe_wo_bias
		Float pearson_linear_probe_wo_bias = run_nobias_metrics.pearson_linear_probe_wo_bias
		Float spearman_linear_probe_wo_bias = run_nobias_metrics.spearman_linear_probe_wo_bias
		Float pearson_all_peaks_linear_probe_wo_bias = run_nobias_metrics.pearson_all_peaks_linear_probe_wo_bias
		Float spearman_all_peaks_linear_probe_wo_bias = run_nobias_metrics.spearman_all_peaks_linear_probe_wo_bias
		Float auprc_dense_probe_wo_bias = run_nobias_metrics.auprc_dense_probe_wo_bias
		Float auroc_dense_probe_wo_bias = run_nobias_metrics.auroc_dense_probe_wo_bias
		Float pearson_dense_probe_wo_bias = run_nobias_metrics.pearson_dense_probe_wo_bias
		Float spearman_dense_probe_wo_bias = run_nobias_metrics.spearman_dense_probe_wo_bias
		Float pearson_all_peaks_dense_probe_wo_bias = run_nobias_metrics.pearson_all_peaks_dense_probe_wo_bias
		Float spearman_all_peaks_dense_probe_wo_bias = run_nobias_metrics.spearman_all_peaks_dense_probe_wo_bias
		Float auprc_linear_probe = run_nobias_metrics.auprc_linear_probe
		Float auroc_linear_probe = run_nobias_metrics.auroc_linear_probe
		Float pearson_linear_probe = run_nobias_metrics.pearson_linear_probe
		Float spearman_linear_probe = run_nobias_metrics.spearman_linear_probe
		Float pearson_all_peaks_linear_probe = run_nobias_metrics.pearson_all_peaks_linear_probe
		Float spearman_all_peaks_linear_probe = run_nobias_metrics.spearman_all_peaks_linear_probe
		Float auprc_dense_probe = run_nobias_metrics.auprc_dense_probe
		Float auroc_dense_probe = run_nobias_metrics.auroc_dense_probe
		Float pearson_dense_probe = run_nobias_metrics.pearson_dense_probe
		Float spearman_dense_probe = run_nobias_metrics.spearman_dense_probe
		Float pearson_all_peaks_dense_probe = run_nobias_metrics.pearson_all_peaks_dense_probe
		Float spearman_all_peaks_dense_probe = run_nobias_metrics.spearman_all_peaks_dense_probe
		Float auprc_control_only = run_nobias_metrics.auprc_control_only
		Float auroc_control_only = run_nobias_metrics.auroc_control_only
		Float pearson_control_only = run_nobias_metrics.pearson_control_only
		Float spearman_control_only = run_nobias_metrics.spearman_control_only
		Float pearson_all_peaks_control_only = run_nobias_metrics.pearson_all_peaks_control_only
		Float spearman_all_peaks_control_only = run_nobias_metrics.spearman_all_peaks_control_only
		Float auprc_shuffled_sequence = run_nobias_metrics.auprc_shuffled_sequence
		Float auroc_shuffled_sequence = run_nobias_metrics.auroc_shuffled_sequence
		Float pearson_shuffled_sequence = run_nobias_metrics.pearson_shuffled_sequence
		Float spearman_shuffled_sequence = run_nobias_metrics.spearman_shuffled_sequence
		Float pearson_all_peaks_shuffled_sequence = run_nobias_metrics.pearson_all_peaks_shuffled_sequence
		Float spearman_all_peaks_shuffled_sequence = run_nobias_metrics.spearman_all_peaks_shuffled_sequence
		Float auprc_shuffled_sequence_wo_bias = run_nobias_metrics.auprc_shuffled_sequence_wo_bias
		Float auroc_shuffled_sequence_wo_bias = run_nobias_metrics.auroc_shuffled_sequence_wo_bias
		Float pearson_shuffled_sequence_wo_bias = run_nobias_metrics.pearson_shuffled_sequence_wo_bias
		Float spearman_shuffled_sequence_wo_bias = run_nobias_metrics.spearman_shuffled_sequence_wo_bias
		Float pearson_all_peaks_shuffled_sequence_wo_bias = run_nobias_metrics.pearson_all_peaks_shuffled_sequence_wo_bias
		Float spearman_all_peaks_shuffled_sequence_wo_bias = run_nobias_metrics.spearman_all_peaks_shuffled_sequence_wo_bias
		Float auprc_label_shuffle = run_nobias_metrics.auprc_label_shuffle
		Float auroc_label_shuffle = run_nobias_metrics.auroc_label_shuffle
		Float pearson_label_shuffle = run_nobias_metrics.pearson_label_shuffle
		Float spearman_label_shuffle = run_nobias_metrics.spearman_label_shuffle
		Float pearson_all_peaks_label_shuffle = run_nobias_metrics.pearson_all_peaks_label_shuffle
		Float spearman_all_peaks_label_shuffle = run_nobias_metrics.spearman_all_peaks_label_shuffle
		Float auprc_label_shuffle_wo_bias = run_nobias_metrics.auprc_label_shuffle_wo_bias
		Float auroc_label_shuffle_wo_bias = run_nobias_metrics.auroc_label_shuffle_wo_bias
		Float pearson_label_shuffle_wo_bias = run_nobias_metrics.pearson_label_shuffle_wo_bias
		Float spearman_label_shuffle_wo_bias = run_nobias_metrics.spearman_label_shuffle_wo_bias
		Float pearson_all_peaks_label_shuffle_wo_bias = run_nobias_metrics.pearson_all_peaks_label_shuffle_wo_bias
		Float spearman_all_peaks_label_shuffle_wo_bias = run_nobias_metrics.spearman_all_peaks_label_shuffle_wo_bias
		Float auprc_label_shuffle_linear_probe_wo_bias = run_nobias_metrics.auprc_label_shuffle_linear_probe_wo_bias
		Float auroc_label_shuffle_linear_probe_wo_bias = run_nobias_metrics.auroc_label_shuffle_linear_probe_wo_bias
		Float pearson_label_shuffle_linear_probe_wo_bias = run_nobias_metrics.pearson_label_shuffle_linear_probe_wo_bias
		Float spearman_label_shuffle_linear_probe_wo_bias = run_nobias_metrics.spearman_label_shuffle_linear_probe_wo_bias
		Float pearson_all_peaks_label_shuffle_linear_probe_wo_bias = run_nobias_metrics.pearson_all_peaks_label_shuffle_linear_probe_wo_bias
		Float spearman_all_peaks_label_shuffle_linear_probe_wo_bias = run_nobias_metrics.spearman_all_peaks_label_shuffle_linear_probe_wo_bias
		Float auprc_label_shuffle_dense_probe_wo_bias = run_nobias_metrics.auprc_label_shuffle_dense_probe_wo_bias
		Float auroc_label_shuffle_dense_probe_wo_bias = run_nobias_metrics.auroc_label_shuffle_dense_probe_wo_bias
		Float pearson_label_shuffle_dense_probe_wo_bias = run_nobias_metrics.pearson_label_shuffle_dense_probe_wo_bias
		Float spearman_label_shuffle_dense_probe_wo_bias = run_nobias_metrics.spearman_label_shuffle_dense_probe_wo_bias
		Float pearson_all_peaks_label_shuffle_dense_probe_wo_bias = run_nobias_metrics.pearson_all_peaks_label_shuffle_dense_probe_wo_bias
		Float spearman_all_peaks_label_shuffle_dense_probe_wo_bias = run_nobias_metrics.spearman_all_peaks_label_shuffle_dense_probe_wo_bias
		Float auprc_label_shuffle_linear_probe = run_nobias_metrics.auprc_label_shuffle_linear_probe
		Float auroc_label_shuffle_linear_probe = run_nobias_metrics.auroc_label_shuffle_linear_probe
		Float pearson_label_shuffle_linear_probe = run_nobias_metrics.pearson_label_shuffle_linear_probe
		Float spearman_label_shuffle_linear_probe = run_nobias_metrics.spearman_label_shuffle_linear_probe
		Float pearson_all_peaks_label_shuffle_linear_probe = run_nobias_metrics.pearson_all_peaks_label_shuffle_linear_probe
		Float spearman_all_peaks_label_shuffle_linear_probe = run_nobias_metrics.spearman_all_peaks_label_shuffle_linear_probe
		Float auprc_label_shuffle_dense_probe = run_nobias_metrics.auprc_label_shuffle_dense_probe
		Float auroc_label_shuffle_dense_probe = run_nobias_metrics.auroc_label_shuffle_dense_probe
		Float pearson_label_shuffle_dense_probe = run_nobias_metrics.pearson_label_shuffle_dense_probe
		Float spearman_label_shuffle_dense_probe = run_nobias_metrics.spearman_label_shuffle_dense_probe
		Float pearson_all_peaks_label_shuffle_dense_probe = run_nobias_metrics.pearson_all_peaks_label_shuffle_dense_probe
		Float spearman_all_peaks_label_shuffle_dense_probe = run_nobias_metrics.spearman_all_peaks_label_shuffle_dense_probe
		Float auprc_baseline = run_nobias_metrics.auprc_baseline
	}
}
