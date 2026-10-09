version 1.0

# Affinity distillation (Alexandari et al. 2023) on gcPBM probes for one experiment,
# fold 0: the released model and the model trained with bias = 0 (run_modelling_bias0.wdl),
# both scored on the same probes and backgrounds (anvil/modeling/nobias_metrics/,
# see gcpbm_affinity.sh and README.md there). Same docker and GPU as nobias_metrics.wdl;
# the scripts are cloned at the tag below.
# Score per probe: mean over backgrounds of the change in log counts (counts head,
# reverse-complement averaged, bias input zero) when the 36 bp probe replaces the
# centre of the background. Backgrounds: n_peak_backgrounds of the experiment's peaks
# (all chromosomes, summit-centred), dinucleotide shuffled, each with its reverse
# complement, the same for both models (realized panel: panel_peaks.fa).
# Outputs: scores.tsv.gz (per probe), metrics.tsv, check.json, deltas.npz (probe x
# background deltas and baselines), panel_peaks.fa, and one Float per value,
# <metric>_<model> with metric pearson_all, spearman_all, pearson_nonnegctrl,
# spearman_nonnegctrl and model released or bias0; bias_check_max_abs_delta_difference
# checks that the released model's scores do not depend on the bias input.

task run_gcpbm_affinity {
	input {
		String experiment
		Array [File] model
		Array [File] model_bias0
		File gcpbm_tsv
		String gcpbm_column
		Int n_peak_backgrounds
		Int probe_subset
		File reference_file
		File reference_file_index
		String gpuType
		String zones
		Int cpu
		Int memory_gb
		Int preemptible_tries
	}
	command {
		set -euo pipefail
		workdir=$(pwd)

		cd /; mkdir my_scripts
		cd /my_scripts

		git clone --depth 1 --branch gcpbm_affinity-v0.3.0 https://github.com/viramalingam/tf-atlas-pipeline.git
		chmod -R 777 tf-atlas-pipeline
		cd tf-atlas-pipeline/anvil/modeling/nobias_metrics/

		echo "run /my_scripts/tf-atlas-pipeline/anvil/modeling/nobias_metrics/gcpbm_affinity.sh" ${experiment} ${sep=',' model} ${sep=',' model_bias0} ${gcpbm_tsv} ${gcpbm_column} ${n_peak_backgrounds} ${reference_file} ${reference_file_index} ${probe_subset}
		/my_scripts/tf-atlas-pipeline/anvil/modeling/nobias_metrics/gcpbm_affinity.sh ${experiment} ${sep=',' model} ${sep=',' model_bias0} ${gcpbm_tsv} ${gcpbm_column} ${n_peak_backgrounds} ${reference_file} ${reference_file_index} ${probe_subset}

		echo "copying all files to the task working directory"
		cp -r /project/gcpbm_outputs/* $workdir/
	}

	output {
		File scores_tsv = "scores.tsv.gz"
		File metrics_tsv = "metrics.tsv"
		File check_json = "check.json"
		File log = "gcpbm_affinity.log"
		File deltas_npz = "deltas.npz"
		File peaks_panel_fa = "panel_peaks.fa"

		Float pearson_all_released = read_float("pearson_all_released.txt")
		Float spearman_all_released = read_float("spearman_all_released.txt")
		Float pearson_nonnegctrl_released = read_float("pearson_nonnegctrl_released.txt")
		Float spearman_nonnegctrl_released = read_float("spearman_nonnegctrl_released.txt")
		Float pearson_all_bias0 = read_float("pearson_all_bias0.txt")
		Float spearman_all_bias0 = read_float("spearman_all_bias0.txt")
		Float pearson_nonnegctrl_bias0 = read_float("pearson_nonnegctrl_bias0.txt")
		Float spearman_nonnegctrl_bias0 = read_float("spearman_nonnegctrl_bias0.txt")
		Float bias_check_max_abs_delta_difference = read_float("bias_check_max_abs_delta_difference.txt")
	}

	runtime {
		docker: 'vivekramalingam/tf-atlas:gcp-modeling_v2.1.0-rc.1'
		cpu: cpu
		memory: memory_gb + "GB"
		bootDiskSizeGb: 50
		disks: "local-disk 50 SSD"
		gpuType: "nvidia-tesla-" + gpuType
		gpuCount: 1
		zones: zones   # GCP Batch: all zones must be in one region
		nvidiaDriverVersion: "535.161.08"
		preemptible: preemptible_tries
		maxRetries: 1
	}
}

workflow gcpbm_affinity {
	input {
		String experiment
		Array [File] model
		Array [File] model_bias0
		File gcpbm_tsv
		String gcpbm_column
		Int n_peak_backgrounds = 200
		Int probe_subset = 0    # > 0: a fixed random subset of probes (seed 0), for tests
		File reference_file
		File reference_file_index
		String gpuType = "t4"
		String zones = "us-west4-a us-west4-b us-west4-c"
		Int cpu = 4
		Int memory_gb = 16
		Int preemptible_tries = 0
	}

	call run_gcpbm_affinity {
		input:
			experiment = experiment,
			model = model,
			model_bias0 = model_bias0,
			gcpbm_tsv = gcpbm_tsv,
			gcpbm_column = gcpbm_column,
			n_peak_backgrounds = n_peak_backgrounds,
			probe_subset = probe_subset,
			reference_file = reference_file,
			reference_file_index = reference_file_index,
			gpuType = gpuType,
			zones = zones,
			cpu = cpu,
			memory_gb = memory_gb,
			preemptible_tries = preemptible_tries
	}

	output {
		File scores_tsv = run_gcpbm_affinity.scores_tsv
		File metrics_tsv = run_gcpbm_affinity.metrics_tsv
		File check_json = run_gcpbm_affinity.check_json
		File log = run_gcpbm_affinity.log
		File deltas_npz = run_gcpbm_affinity.deltas_npz
		File peaks_panel_fa = run_gcpbm_affinity.peaks_panel_fa
		Float pearson_all_released = run_gcpbm_affinity.pearson_all_released
		Float spearman_all_released = run_gcpbm_affinity.spearman_all_released
		Float pearson_nonnegctrl_released = run_gcpbm_affinity.pearson_nonnegctrl_released
		Float spearman_nonnegctrl_released = run_gcpbm_affinity.spearman_nonnegctrl_released
		Float pearson_all_bias0 = run_gcpbm_affinity.pearson_all_bias0
		Float spearman_all_bias0 = run_gcpbm_affinity.spearman_all_bias0
		Float pearson_nonnegctrl_bias0 = run_gcpbm_affinity.pearson_nonnegctrl_bias0
		Float spearman_nonnegctrl_bias0 = run_gcpbm_affinity.spearman_nonnegctrl_bias0
		Float bias_check_max_abs_delta_difference = run_gcpbm_affinity.bias_check_max_abs_delta_difference
	}
}
