import argparse
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import os
import json
from collections import OrderedDict
import h5py
import hdf5plugin
import numpy as np
import modiscolite
import modiscolite.tfmodisco
import modiscolite.util
from modiscolite.visualization import viz_sequence
import random
import numpy

random.seed(0)
numpy.random.seed(0)

from tensorflow.random import set_seed 
set_seed(1234)

def save_hierarchy(h, grp):
	root_node_names = []
	for i in range(len(h.root_nodes)):
		node_name = "root_node"+str(i)
		root_node_names.append(node_name)
		save_node(h.root_nodes[i], grp.create_group(node_name))
        
	dset = grp.create_dataset("root_node_names", (len(root_node_names),), dtype=h5py.special_dtype(vlen=bytes))
	dset[:] = root_node_names


def save_node(node, grp):
	if node.indices_merged is not None:
		grp.create_dataset("indices_merged", data=np.array(node.indices_merged)) 
		grp.create_dataset("submat_crosscontam", data=np.array(node.submat_crosscontam)) 
		grp.create_dataset("submat_alignersim", data=np.array(node.submat_alignersim))
        
	save_pattern(node.pattern, grp.create_group("pattern"))

	if node.child_nodes is not None:
		child_node_names = []
		for i in range(len(node.child_nodes)):
			child_node_name = "child_node"+str(i)
			child_node_names.append(child_node_name)
			save_node(node.child_nodes[i], grp.create_group(child_node_name))
			#node.child_nodes[i].save_hdf5(grp.create_group(child_node_name))

		dset = grp.create_dataset("child_node_names", (len(child_node_names),), dtype=h5py.special_dtype(vlen=bytes))
		dset[:] = child_node_names

def save_pattern(pattern, grp):
	track_grp = grp.create_group("sequence")
	track_grp.create_dataset("fwd", data=pattern.sequence)
	track_grp.create_dataset("rev", data=pattern.sequence[::-1, ::-1])
	track_grp.attrs["has_pos_axis"] = True

	track_grp = grp.create_group("task0_contrib_scores")
	track_grp.create_dataset("fwd", data=pattern.contrib_scores)
	track_grp.create_dataset("rev", data=pattern.contrib_scores[::-1, ::-1])
	track_grp.attrs["has_pos_axis"] = True

	track_grp = grp.create_group("task0_hypothetical_contribs")
	track_grp.create_dataset("fwd", data=pattern.hypothetical_contribs)
	track_grp.create_dataset("rev", data=pattern.hypothetical_contribs[::-1, ::-1])
	track_grp.attrs["has_pos_axis"] = True

	seqlets_and_alnmts_grp = grp.create_group("seqlets_and_alnmts")

	dset = seqlets_and_alnmts_grp.create_dataset("seqlets", (len(pattern.seqlets),), dtype=h5py.special_dtype(vlen=bytes))
	dset[:] = [str(x) for x in pattern.seqlets]

	seqlets_and_alnmts_grp.create_dataset("alnmts", 
		data=np.zeros(len(pattern.seqlets)))

	if pattern.subclusters is not None:
		grp.create_dataset("subclusters", data=pattern.subclusters)
		subcluster_to_subpattern_grp = grp.create_group("subcluster_to_subpattern")

		dset = subcluster_to_subpattern_grp.create_dataset("subcluster_names", (len(pattern.subcluster_to_subpattern.keys()),), dtype=h5py.special_dtype(vlen=bytes))
		dset[:] = ["subcluster_"+str(x) for x in pattern.subcluster_to_subpattern.keys()]

		for subcluster, subpattern in pattern.subcluster_to_subpattern.items():
			subpattern_grp = subcluster_to_subpattern_grp.create_group("subcluster_"+str(subcluster)) 
			save_pattern(subpattern, subpattern_grp)


def save_patterns(patterns, grp):
	all_pattern_names = []
	for idx, pattern in enumerate(patterns):
		pattern_name = "pattern_"+str(idx)
		all_pattern_names.append(pattern_name)
		pattern_grp = grp.create_group(pattern_name)
		save_pattern(pattern, pattern_grp)

	dset = grp.create_dataset("all_pattern_names", (len(all_pattern_names),), dtype=h5py.special_dtype(vlen=bytes))
	dset[:] = all_pattern_names

def save_string_list(string_list, dset_name, grp):
	dset = grp.create_dataset(dset_name, (len(string_list),),
							  dtype=h5py.special_dtype(vlen=bytes))
	dset[:] = string_list

def save_seqlet_coords(seqlets, dset_name, grp):
	coords_strings = [str(x) for x in seqlets] 
	save_string_list(string_list=coords_strings,
					 dset_name=dset_name, grp=grp)

def motif_discovery_argsparser():
	""" Command line arguments for the motif_discovery script

		Returns:
			argparse.ArgumentParser
	"""
	
	parser = argparse.ArgumentParser()
	
	parser.add_argument("--scores-path", type=str, 
						help="Path to the importance scores hdf5 file")
	
	parser.add_argument("--scores-locations", type=str, 
						help="path to bed file containing the locations "
						"that match the scores")

	parser.add_argument("--output-directory", type=str, 
						help="Path to the output directory")
	
	parser.add_argument("--max_seqlets", type=int, default=25000, 
						help="Max number of seqlets per metacluster "
						"for modisco")

	parser.add_argument('--modisco-window-size', type=int,
						help="size of the window around the peak "
						"coodrinate that will be considered for motif"
						"discovery", default=400)
	return parser


def save_plot(weights, dst_fname):
	"""
	
	"""
	print(dst_fname)
	colors = {0:'green', 1:'blue', 2:'orange', 3:'red'}
	plot_funcs = {0: viz_sequence.plot_a, 1: viz_sequence.plot_c, 
				  2: viz_sequence.plot_g, 3: viz_sequence.plot_t}

	fig = plt.figure(figsize=(20, 2))
	ax = fig.add_subplot(111) 
	viz_sequence.plot_weights_given_ax(ax=ax, array=weights, 
									   height_padding_factor=0.2,
									   length_padding=1.0, 
									   subticks_frequency=1.0, 
									   colors=colors, plot_funcs=plot_funcs, 
									   highlight={}, ylabel="")

	plt.savefig(dst_fname)

def motif_discovery_main(scores_path, output_directory, modisco_window_size, max_seqlets):
	if not os.path.exists(scores_path):
		raise Exception(
			"Score file {} does not exist".format(scores_path))

	if not os.path.exists(output_directory):
		raise Exception(
			"Output directiry {} does not exist".format(output_directory))

	# Load the scores
	scores = h5py.File(scores_path, 'r')

	try:
		center = scores['hyp_scores'].shape[1] // 2
		start = center - modisco_window_size // 2
		end = center + modisco_window_size // 2
		
		shap_scores = scores['hyp_scores'][:, start:end, :]
		one_hot_seqs = scores['input_seqs'][:, start:end, :]
	except KeyError:
		center = scores['shap']['seq'].shape[2] // 2
		start = center - modisco_window_size // 2
		end = center + modisco_window_size // 2
		
		shap_scores = scores['shap']['seq'][:, :, start:end].transpose(0, 2, 1)
		one_hot_seqs = scores['raw']['seq'][:, :, start:end].transpose(0, 2, 1)

	scores.close()

	(multitask_seqlet_creation_results, metaclustering_results, 
		metacluster_idx_to_submetacluster_results) = modiscolite.tfmodisco.TFMoDISco(
		hypothetical_contribs=shap_scores, one_hot=one_hot_seqs,
		max_seqlets_per_metacluster=max_seqlets,
		sliding_window_size=20,
		flank_size=5,
		target_seqlet_fdr=0.05,
		n_leiden_runs=2)

	modisco_results_path = '{}/modisco_results.h5'.format(
		output_directory)
		

	########
	### Ugly saving code
	########

	grp = h5py.File(modisco_results_path, 'w')

	multitask_group = grp.create_group("multitask_seqlet_creation_results")
	save_string_list(
		  string_list=list(multitask_seqlet_creation_results['task_name_to_coord_producer_results'].keys()),
		  dset_name="task_names", grp=multitask_group)

	multitask2_group = multitask_group.create_group("multitask_seqlet_creator")
	multitask2_group.create_group("coord_producer")
	multitask2_group.create_group("overlap_resolver")
	multitask2_group.attrs['verbose'] = True

	save_seqlet_coords(seqlets=multitask_seqlet_creation_results['final_seqlets'], dset_name="final_seqlets", grp=multitask_group)

	tntcpg = multitask_group.create_group("task_name_to_coord_producer_results")

	coord_producer_results = multitask_seqlet_creation_results['task_name_to_coord_producer_results']['task0']
	save_string_list(string_list=[str(x) for x in coord_producer_results['seqlets']], dset_name="coords", grp=tntcpg)

	tnt_group = tntcpg.create_group("tnt_results")
	tnt_group.attrs['class'] = 'FWACTransformAndThresholdResults'

	metaclustering_group = grp.create_group("metaclustering_results")
	metaclustering_group.create_dataset("metacluster_indices", data=metaclustering_results['metacluster_indices'])

	metaclustering_group.attrs["class"] = "SignBasedPatternClustering"
	save_string_list(['task0'], dset_name="task_names", grp=metaclustering_group) 
	
	task_name_to_value_provider_grp = metaclustering_group.create_group("task_name_to_value_provider")

	task0_group = task_name_to_value_provider_grp.create_group("task0")
	task0_group.attrs["class"] = "TransformCentralWindowValueProvider"
	task0_group.attrs["track_name"] = "task0_contrib_scores"
	task0_group.attrs["central_window"] = 20
	
	val_transformer_group = task0_group.create_group("val_transformer")
	val_transformer_group.attrs["class"] = "AbsPercentileValTransformer"
	
	metaclustering_group.attrs["min_cluster_size"] = 100
	metaclustering_group.attrs["verbose"] = True
	metaclustering_group.attrs["fit_called"] = True

	activity_pattern_to_cluster_idx_grp = metaclustering_group.create_group("activity_pattern_to_cluster_idx")
	for activity_pattern, cluster_idx in metaclustering_results['pattern_to_cluster_idx'].items():
		activity_pattern_to_cluster_idx_grp.attrs[activity_pattern] = cluster_idx

	group = grp.create_group("metacluster_idx_to_submetacluster_results")
	for idx, results in metacluster_idx_to_submetacluster_results.items():
		smc_group = group.create_group("metacluster_{}".format(idx))
		smc_group.attrs['size'] = results['metacluster_size']
		save_seqlet_coords(seqlets=results['seqlets'], dset_name="seqlets", grp=smc_group)

		patterns = results['seqlets_to_patterns_result']
		pattern_group = smc_group.create_group("seqlets_to_patterns_result")
		pattern_group.attrs["success"] = patterns['success']
		pattern_group.attrs["other_config"] = json.dumps(patterns['other_config'], indent=4, separators=(',', ': '))

		if patterns['success']:
			if patterns['each_round_initcluster_motifs'] is not None:
				rounds_motifs = pattern_group.create_group("each_round_initcluster_motifs")
				all_round_names = []

				for round_idx, initcluster_motifs in enumerate(patterns['each_round_initcluster_motifs']):
					round_name = "round_" + str(round_idx)
					save_patterns(patterns=initcluster_motifs, grp=rounds_motifs.create_group(round_name)) 

				save_string_list(string_list=all_round_names, dset_name="all_round_names", grp=rounds_motifs)


			save_patterns(patterns['patterns'], pattern_group.create_group("patterns"))
			save_patterns(patterns['remaining_patterns'], pattern_group.create_group("remaining_patterns"))

			cluster_group = pattern_group.create_group("cluster_results")
			cluster_group.attrs['class'] = 'ClusterResults'
			cluster_group.create_dataset("cluster_indices", data=patterns['cluster_results']['cluster_indices'])

			save_hierarchy(patterns['pattern_merge_hierarchy'], pattern_group.create_group("pattern_merge_hierarchy"))

			#patterns['pattern_merge_hierarchy'].save_hdf5(grp=pattern_group.create_group("pattern_merge_hierarchy"))


	#tfmodisco_results.save_hdf5(h5py.File(modisco_results_path, 'w'))
	print("Saved modisco results to file {}".format(str(modisco_results_path)))
	####

	seqlet_path = '{}/seqlets.txt'.format(output_directory)
	#print("Saving seqlets to %s" % seqlet_path)
	seqlets = metacluster_idx_to_submetacluster_results[0]['seqlets']
	bases = np.array(["A", "C", "G", "T"])
	with open(seqlet_path, "w") as f:
		for seqlet in seqlets:
			sequence = "".join(bases[np.argmax(seqlet.sequence, axis=-1)])
			example_index = seqlet.example_idx
			start, end = seqlet.start, seqlet.end
			f.write(">example%d:%d-%d\n" % (example_index, start, end))
			f.write(sequence + "\n")

	#print("Saving pattern visualizations")

	patterns = (metacluster_idx_to_submetacluster_results[0]['seqlets_to_patterns_result']['patterns'])

	# generate .pngs of each motif and write motif seqlet to
	# individual files
	for idx,pattern in enumerate(patterns):		
		pattern_seqlet_path = os.path.join(output_directory,
										   'pattern{}_seqlets.txt'.format(idx))
		with open(pattern_seqlet_path, "w") as f: 
			for seqlet in pattern.seqlets:
				sequence = "".join(
					bases[np.argmax(seqlet.sequence, axis=-1)]
				)
				example_index = seqlet.example_idx
				start, end = seqlet.start, seqlet.end
				f.write(">example%d:%d-%d\n" % (example_index, start, end))
				f.write(sequence + "\n")

		save_plot(pattern.contrib_scores, '{}/contrib_{}.png'.format(output_directory, idx))
		save_plot(pattern.sequence, '{}/sequence_{}.png'.format(output_directory, idx))

if __name__ == '__main__':
	parser = motif_discovery_argsparser()
	args = parser.parse_args()
	motif_discovery_main(args.scores_path, args.output_directory, 
		args.modisco_window_size, args.max_seqlets)