/*
 * Define the parameters used in the processes below
 */

params.SECOND_PASS = false
params.BWT_SECOND_PASS_OPTIONS = false
params.BWT_DB_PREFIX = false
params.SEQUENCER = false
params.TRIMMOMATIC_OPTIONS = false
params.SNAP_OPTIONS = false
params.BLAST_CHECK = false
params.WRITE_UNIQUES = false
params.BLAST_EVAL = false
params.ADD_HOST_FILTERED_TO_REPORT = false
params.HOST_FILTER_TAXID = 9606
params.H_STRICT = false
params.H_TAXID = 9606
params.FILTER_LIST = "[12908,28384,48479]"
params.LOGIC = "strict"
params.INCLUSION_TAXID = 2759
params.EXCLUSION_TAXID = 9604
params.ENTREZ_EMAIL = "uwvirongs@gmail.com"
params.BASE_DELIMITER = "_"
params.MIN_READ_CUTOFF = 10
params.SAM_NO_BUILD_LIST = "[2759,77133]"
params.EDIT_DISTANCE_OFFSET = 6
params.BUILD_SAMS = false

/*
 * Define the processes used in this workflow
 */

process filter_human_paired {

    // Define the Docker container used for this step
    container "quay.io/fhcrc-microbiome/bowtie2:bowtie2-2.2.9-samtools-1.3.1"

    // Define the input files
    input:
      tuple val(base), file(r1), file(r2)
      file "*"

    // Define the output files
    output:
      tuple val(base), file("${base}_R1_filtered.fastq.gz"), file("${base}_R2_filtered.fastq.gz")
      tuple val(base), file("${base}.log")

    // Clean up the ephemeral working space (not the persistent file storage)
    afterScript "rm *"

    // Code to be executed inside the task
    script:
      """
#!/bin/bash

set -e

# For logging and debugging, list all of the files in the working directory
ls -lahtr

echo "Starting the alignment of ${r1} and ${r2}"
bowtie2 \
    ${params.BWT_SECOND_PASS_OPTIONS} \
    --threads 16 \
    -x ${params.BWT_DB_PREFIX} \
    -q \
    -1 <(gunzip -c ${r1}) \
    -2 <(gunzip -c ${r2}) \
    -S ${base}_mappedSam 2>&1 | \
    tee -a ${base}.log

echo "Extracting the BAM alignments"
samtools view -Sb -@ 16 ${base}_mappedSam > ${base}_mappedBam

# Extract the R1
echo "Extracting the R1 FASTQ"
samtools view -@ 16 -F 2 ${base}_mappedBam | \
samtools view -@ 16 -f 64 - | \
    awk \'{if(\$3 == \"*\") print \"@\" \$1 \"\\n\" \$10 \"\\n\" \"+\" \$1 \"\\n\" \$11}\' | \
    gzip -c > ${base}_R1_filtered.fastq.gz

echo "Extracting the R2 FASTQ"
# Extract the R2
samtools view -@ 16 -F 2 ${base}_mappedBam | \
samtools view -@ 16 -f 128 - | \
    awk \'{if(\$3 == \"*\") print \"@\" \$1 \"\\n\" \$10 \"\\n\" \"+\" \$1 \"\\n\" \$11}\' | \
    gzip -c > ${base}_R2_filtered.fastq.gz
      """
}


process filter_human_single {

    // Define the Docker container used for this step
    container "quay.io/fhcrc-microbiome/bowtie2:bowtie2-2.2.9-samtools-1.3.1"

    // Define the input files
    input:
      tuple val(base), file(r1)
      file "*"

    // Define the output files
    output:
      tuple val(base), file("${base}_R1_filtered.fastq.gz")
      tuple val(base), file("${base}.log")

    // Clean up the ephemeral working space (not the persistent file storage)
    afterScript "rm *"

    // Code to be executed inside the task
    script:
      """
#!/bin/bash

set -e

# For logging and debugging, list all of the files in the working directory
ls -lahtr

echo "Starting the alignment of ${r1}"
bowtie2 \
    ${params.BWT_SECOND_PASS_OPTIONS} \
    --threads 16 \
    -x ${params.BWT_DB_PREFIX} \
    -q \
    -U <(gunzip -c ${r1}) \
    -S ${base}_mappedSam 2>&1 | \
    tee -a ${base}.log

echo "Extracting the BAM alignments"
samtools view -Sb -@ 16 ${base}_mappedSam > ${base}_mappedBam

# Extract the R1
echo "Extracting the FASTQ"
samtools view -@ 16 -f 4 ${base}_mappedBam | \
    awk \'{if(\$3 == \"*\") print \"@\" \$1 \"\\n\" \$10 \"\\n\" \"+\" \$1 \"\\n\" \$11}\' | \
    gzip -c > ${base}_R1_filtered.fastq.gz
      """
}

process trimmomatic_single {

    // Define the Docker container used for this step
    container "quay.io/fhcrc-microbiome/openjdk:jre-8"

    // Define the input files
    input:
      tuple val(base), file(r1)
      file TRIMMOMATIC_JAR
      file TRIMMOMATIC_ADAPTER 

    // Define the output files
    output:
      tuple val(base), file("${base}_R1_trimmed.fastq.gz")

    // Clean up the ephemeral working space (not the persistent file storage)
    afterScript "rm *"

    // Code to be executed inside the task
    script:
      """
#!/bin/bash

set -e

# For logging and debugging, list all of the files in the working directory
ls -lahtr

gunzip -c ${r1}

echo "Starting to trim ${r1}"
java -jar \
    ${TRIMMOMATIC_JAR} \
    SE \
    -threads 16 \
    ${r1} \
    ${base}_R1_trimmed.fastq.gz \
    ${params.SEQUENCER}${TRIMMOMATIC_ADAPTER}${params.TRIMMOMATIC_OPTIONS}
"""
}

process trimmomatic_paired {

    // Define the Docker container used for this step
    container "quay.io/fhcrc-microbiome/openjdk:jre-8"

    // Define the input files
    input:
      tuple val(base), file(r1), file(r2)
      file TRIMMOMATIC_JAR
      file TRIMMOMATIC_ADAPTER 

    // Define the output files
    output:
      tuple val(base), file("${base}_R1_trimmed.fastq.gz"), file("${base}_R2_trimmed.fastq.gz")

    // Clean up the ephemeral working space (not the persistent file storage)
    afterScript "rm *"

    // Code to be executed inside the task
    script:
      """
#!/bin/bash

set -e

# For logging and debugging, list all of the files in the working directory
ls -lahtr

echo "Starting to trim ${r1} and ${r2}"
java -jar \
    ${TRIMMOMATIC_JAR} \
    PE \
    -threads 16 \
    ${r1} \
    ${r2} \
    ${base}_R1_trimmed.fastq.gz \
    ${base}_R1_unpaired.fastq.gz \
    ${base}_R2_trimmed.fastq.gz \
    ${base}_R2_unpaired.fastq.gz \
    ${params.SEQUENCER}${TRIMMOMATIC_ADAPTER}${params.TRIMMOMATIC_OPTIONS}
"""
}

process snap_paired {

    // Define the Docker container used for this step
    container "quay.io/fhcrc-microbiome/snap-no-header:v1.0beta.18--0"

    // Define the input files
    input:
      tuple val(base), file(r1), file(r2)
      each file(SNAP_DB)

    // Define the output files
    output:
      tuple val(base), file("${base}_${SNAP_DB.name}.sam")

    // Clean up the ephemeral working space (not the persistent file storage)
    afterScript "rm *"

    // Code to be executed inside the task
    script:
      """
#!/bin/bash

set -e

# For logging and debugging, list all of the files in the working directory
ls -lahtr

echo "Starting to align ${r1} and ${r2}"
snap-aligner paired ${SNAP_DB} ${r1} ${r2} -o ${base}_${SNAP_DB.name}.sam -t 16 ${params.SNAP_OPTIONS}
"""
}

process snap_single {

    // Define the Docker container used for this step
    container "quay.io/fhcrc-microbiome/snap-no-header:v1.0beta.18--0"

    // Define the input files
    input:
      tuple val(base), file(r1)
      each file(SNAP_DB)

    // Define the output files
    output:
      tuple val(base), file("${base}_${SNAP_DB.name}.sam")

    // Clean up the ephemeral working space (not the persistent file storage)
    afterScript "rm *"

    // Code to be executed inside the task
    script:
      """
#!/bin/bash

set -e

# For logging and debugging, list all of the files in the working directory
ls -lahtr

echo "Starting to align ${r1}"
snap-aligner single ${SNAP_DB} ${r1} -o ${base}_${SNAP_DB.name}.sam -t 16 ${params.SNAP_OPTIONS}
"""
}

process collect_snap_results {

    // Define the Docker container used for this step
    container "ubuntu:18.04"

    // Define the input files
    input:
      tuple val(base), file(sam_list)

    // Define the output files
    output:
      tuple val(base), file("${base}.sam")

    // Clean up the ephemeral working space (not the persistent file storage)
    afterScript "rm *"

    // Code to be executed inside the task
    script:
      """
#!/bin/bash

set -e

# For logging and debugging, list all of the files in the working directory
ls -lahtr

echo "Checking that all files were staged correctly"
for fp in ${sam_list}; do
    [ -s \$fp ]
done

echo "Concatenating files"
cat ${sam_list} > ${base}.sam
"""
}

process CLOMP_summary {

    // Define the Docker container used for this step
    container "quay.io/fhcrc-microbiome/clomp:v0.1.2"

    // Define the input files
    input:
      tuple val(base), file(sam_list), file(log_file)
      file BLAST_CHECK_DB
      file "kraken_db/"
    output:
      file "*final_report.tsv"  // Final report TSV
      file "${log_file}"        // Logfile

    // Clean up the ephemeral working space (not the persistent file storage)
    afterScript "rm *"

    // Code to be executed inside the task
    script:
    """
#!/usr/bin/env python3

import ast 
import subprocess
import glob
import argparse 
import os
import operator
from collections import Counter
from ete3 import NCBITaxa
import timeit
from collections import defaultdict
ncbi = NCBITaxa()


# The tie-breaking function takes a list of taxid,edit_distances in the form [[taxid,edit_distance],[taxid,edit_distance],..
# references the global variable LOGIC to control the underlying tiebreaking code, breaks ties and 
# returns a single taxid as a string and a Boolean value (as to whether the read needs to re-BLASTEd against host).
def tie_break(taxid_list):
	score_list = [] 
	actual_taxid_list = []
	for id in taxid_list:
		score_list.append(id[1])
	
	# this can filter out any hits that are sufficiently worse than the edit distance for the 'best'
	# alignment - set to zero to only hold scores that have the best edit distance , and increase to a 
	# number greater than the snap option -d to hold all hits
	best_edit_distance = min(score_list) + ${params.EDIT_DISTANCE_OFFSET}
	
	# Keep taxids that have an edit distance less than the acceptable edit distance defined above 
	for id in taxid_list:
		if id[1] <= best_edit_distance:
			actual_taxid_list.append(id[0])
	#No longer holding edit distances		
	taxid_list = actual_taxid_list
	lineage_list = []
	
	for id in taxid_list:
		# Not all taxids have valid lineages 
		try:
			#Not every taxid has a valid NCBI lineage, so this statement has to be encased in a try statement.
			lineage = ncbi.get_lineage(id)
			# filters out lineages that contain taxids in the FILTER_LIST variable
			# commonly, this is 'other sequences', 'artificial sequences' or 'environmental samples' 
			if any(x in ${params.FILTER_LIST} for x in lineage):
				lineage = []
		except:
			lineage = []
		
		if lineage:
			lineage_list.append(lineage)
	
	if not lineage_list:
		return ['*',False]
	
	# controls if use any alignment to the human genome as grounds for classification as human source
	if "${params.H_STRICT}" == "true":
		# check if H_TAXID ever shows up in 
		if any(int(${params.H_TAXID}) in sl for sl in lineage_list):
			return [${params.H_TAXID},False]
			

	# count all taxids in all lineages 
	taxid_to_count_map = {}
	for each_lineage in lineage_list:
		for each_taxid in each_lineage:
			if each_taxid in taxid_to_count_map:
				taxid_to_count_map[each_taxid] += 1
			else:
				taxid_to_count_map[each_taxid] = 1
	
	#Set the threshold according to the pre-specified LOGIC in the initialization file
	num_assignments = len(lineage_list)
	if "${params.LOGIC}" == 'strict':
		threshold = num_assignments
	elif "${params.LOGIC}" == '90':
		threshold = num_assignments - ((num_assignments /10) + 1) 
	elif "${params.LOGIC}" == 'oneoff':
		threshold = num_assignments - 1
	else:
		print('invalid logic threshold: defaulting to strict')
		threshold = num_assignments
	
	#Now we will find all the taxids that meet threshold/LOGIC specified above.
	surviving_taxids = []
	for taxid_key in taxid_to_count_map:
		# main filtering - everything that passes this step gets a list intersection and the 
		# most specific taxid left is returned 
		if taxid_to_count_map[taxid_key] >= threshold:
			surviving_taxids.append(taxid_key)
			
	if len(surviving_taxids) == 0:
		return ['*',False]

	d = {}

	for the_value in surviving_taxids:
		d[the_value] = len(ncbi.get_lineage(the_value))
	#Find the remaining taxid with the longest lineage.
	#The longest lineage is defined as the longest list.  #nicetohave: this is not pulling the taxonomic rank at any point.
	assigned_hit = max(d.items(), key=operator.itemgetter(1))[0]
	recheck = False 
	
	#Assign a Boolean value for each read as to whether it needs to be searched against a custom BLAST database
	#Here, we are just assigning whether it needs to be searched or not.  The custom BLAST database would need to be made separately.
	#All reads downstream of INCLUSION_TAXID and but not downstream of EXCLUSION_TAXID will be assigned a True value.
	if "${params.BLAST_CHECK}" == "true":
		assigned_lineage = ncbi.get_lineage(assigned_hit)
		if ${params.INCLUSION_TAXID} in assigned_lineage and ${params.EXCLUSION_TAXID} not in assigned_lineage:
			recheck = True
	
	return [assigned_hit, recheck]


#Every read has a taxid assignment or is unassigned at this point.

# wrapper for a kraken script that converts tab seperated taxid\tcount file and writes a 
# Pavian output file for it. Requires a copy of ncbi's taxonomy database and some blank files
# This is a map of assigned taxids to number of occurrences as well as the total number of unassigned reads.
def new_write_kraken(basename, final_counts_map, num_unassigned):
	print('Preparing output for ${base}')
	# we write a file in the form taxid\tcount 
	l = open('${base}_temp_kraken.tsv', 'w')
	
	# initialize with the number of unassigned, we'll need to add human host filtering in earlier
	# because some reads will get tie broken to human 
	
	l.write('0\t' + str(num_unassigned))
	# write the rest of the taxids to the file
	for key in final_counts_map.keys():
		l.write('\\n' + str(key) + '\t' + str(final_counts_map[key]))
	
	# this close is required so we get an EOF before passing the file to kraken-report 
	l.close()
	
	# kraken-report creates a file that Pavian likes - we name the file base_final_report.tsv
	kraken_report_cmd = 'krakenuniq-report --db kraken_db --taxon-counts ${base}_temp_kraken.tsv > ${base}_final_report.tsv'
	subprocess.call(kraken_report_cmd, shell=True)
	

# takes a list of finished output files and builds sam files for species level assignments 
# for each sample sam files are wrote directly to disk 
def build_sams(input_list):
	
	# only try to import this if we're trying to build sam files 
	from Bio import Entrez 
	Entrez.email = ${params.ENTREZ_EMAIL}
	
	# go through each file report output files 
	for file_name in glob.glob('*report.tsv'):
		base = file_name.split("${params.BASE_DELIMITER}")[0]
		taxid_to_assemble = []
		
		# grab a list of taxids that are at a species level and also have greater than MIN_READ_CUTOFF assigned to them 
		for line in open(file_name):
			line_list = line.split('\t')
			if line_list[3] == 'S' and int(line_lsit[2]) >= ${params.MIN_READ_CUTOFF}:
				lineage = ncbi.get_lineage(line_list[4])
				# filter out any taxids that have lineages that include anything from the blacklist
				if not any(x in ${params.SAM_NO_BUILD_LIST} for x in lineage):
					taxid_to_assemble.append(line_list[4])
		
		# go through each taxid that we pulled in the last loop and parse the sam file for the accession numbers of the entries that each read aligned to
		# Each read can align to more than one NT entry across all SNAP databases so we grab every accession number that is this taxid 
		for taxid in taxid_to_assemble:
			taxid_search_list = [str(taxid)]
			taxid_search_list = taxid_search_list + ncbi.get_descendant_taxa(taxid, intermediate_nodes=True)
			list_of_reads_to_pull = []
			# this gets a list of every read that was assigned a given taxid 
			for a_line in open(base + '_assignments.txt'):
				a_line_list = a_line.split('\t')
				if a_line_list[1]  in taxid_search_list:
					list_of_reads_to_pull.append(a_line_list[0])
			acc_num_list = []
			# this gets us all accession numbers that all these reads aligned to 
			for s_file in glob.glob(base + '*' + '.sam'):
				for line in open(s_file):
					sam_line_list = sam_line.split('\t')
					if sam_line_list[0] in list_of_reads_to_pull and 'complete_genome' in sam_line_list[2]:
						acc_num_list.append(sam_line_list[2].split('.')[0])
			if len(acc_num_list) == 0:
				print('No complete genome reference found, not assembling taxid: ' + str(taxid))
				break
				
			# now we figure out the most common accession number that was assigned to this taxid
			most_common_acc_num = max(set(acc_num_list), key = acc_num_list.count)
			
			taxid_lineage = ncbi.get_lineage(taxid)
			# we walk up the taxonomy tree ASSEMBLY_NODE_OFFSET nodes and pull all reads that were taxonomically assigned at or below that node
			taxid_to_pull = taxid_lineage[ASSEMBLY_NODE_OFFSET]
			taxid_search_list = taxid_to_pull + ncbi.get_dsecendant_taxa(taxid_to_pull, intermediate_nodes = True)
			
			header_list = []
			seq_list = []
			g = open(base + '_' + taxid + '.fasta', 'w')
			# then we write all the reads that are at or below the taxid_to_pull variable and write them into a fasta file 
			for line in open(base + '_assignments.txt'):
				line_list = line.split('\t')
				if int(line_list[1]) in taxid_search_list:
					g.write('>' + line_list[0] + '\\n')
					g.write(line_list[2])
			g.close()
			
			# now we download the reference fasta file for the most common acession number 
			print('Searching NCBI for Accession number:' + most_common_acc_num + ' for taxid ' + str(taxid))
			record = Entrez.read(Entrez.esearch(db='nucleotide', term=most_common_acc_num))
			try:
				h2 = Entrez.efetch(db='nucleotide', id=record['IdList'][0], rettype='fasta', retmode='text')
			except:
				print(str(taxid) + ' did not return hits - not assembling')
				break
			
			# build some file names for the bowtie index and our reference fasta 
			ref_fasta = base + '_' + str(taxid) + '_ref.fasta'
			ref_db = base + '_' + str(taxid) + '_bwt_db'
			g = open(ref_fasta, 'w')
			g.write(h2.read())
			g.close()
			print('building bowtie2 index') 
			# build the bowtie2 index 
			subprocess.call('bowtie2-build ' + ref_fasta + ' ' + ref_db + ' > /dev/null 2>&1 ', shell=True)
			print('Done with index build. Aligning...')
			# aling and output the sam file 
			subprocess.call('bowtie2 -x ' + ref_db + ' -@ ' + THREADS + ' -f -U ' + base + '_' + str(taxid) + '.fasta --no-unal > ' + base + '_' + str(taxid) + '.sam', shell=True)
			subprocess.call('rm ' + ref_db, shell=True)
				

base_start_time = timeit.default_timer()
read_to_taxids_map = {}
reads_seq_map = {}
#For every SAM file for a given sample, read in the SAM files.
for sam_file in glob.glob('*.sam'):
    file_start_time = timeit.default_timer()
    print('Reading in ' + sam_file)
    
    #For every line in the SAM file
    line_count = 0
    for line in open(sam_file):
        line_count += 1
        #Skip the first three lines, which are header
        if line_count > 3:
            #For each read, pull the SAM information for that read.
            line_list = line.split('\t')
            current_read = line_list[0]
            snap_assignment_of_current_read = line_list[2]
            sequence_of_current_read = line_list[9]
            
            #If read is unassigned, call it unassigned and throw it out.  Unassigned reads do not have an edit distance, assign it 100.
            if snap_assignment_of_current_read == '*':
                # higher edit distance than anything else makes sure this gets parsed out 
                current_read_taxid = [snap_assignment_of_current_read,100]
            else:
                #Pull the taxid and the edit distance from each line.
                current_read_taxid = [snap_assignment_of_current_read.split('#')[-1],
                    int(line_list[12].split(':')[-1])]
            #Create map for each sample.
            #The key in each map is the read ID and the values are lists.
            #For every read, append a list of taxid and edit distance from each SAM file.
            if current_read in read_to_taxids_map:
                read_to_taxids_map[current_read].append(current_read_taxid)
            else: 
                # if this is the first time we've seen this read add the sequence to the list
                # and initialize the read -> taxid_list map  
                read_to_taxids_map[current_read] = [current_read_taxid]
                # also store the read and the sequence, this does need to be in a map 
                reads_seq_map[current_read] = sequence_of_current_read

    file_runtime = str(timeit.default_timer() - file_start_time)
    print('Reading in file ' + sam_file + ' took ' + file_runtime)

per_base_runtime = str(timeit.default_timer() - base_start_time)
print("${base}" + ' took ' + per_base_runtime + ' in total to read')
final_assignment_counts = defaultdict(int)

#Now we've read all the reads for all the SAM files for one sample.  We are still within the sample For loop here.
#We have all the reads with all the taxids and edit distances that have been assigned.
print('Breaking ties for ' + "${base}")
tie_break_start = timeit.default_timer()
# now we're done with the loop and we have a map with reads to list of taxids assigned to them
g = open("${base}" + '_assignments.txt', 'w')
e = open("${base}" + '_unassigned.txt','w')
unass_count = 0
taxid_to_read_set = {}

if "${params.BLAST_CHECK}" == "true":
    z = open("${base}_recheck.txt", 'w')


for read_key in read_to_taxids_map.keys():
    # Now we need to assign only one taxid to each read, which means we need to run the tie-breaking function. 
    loaded_read = reads_seq_map[read_key]
    
    #Create a results list which is a taxid and a boolean, which answers whether I should re-BLAST this or not.
    r_list = tie_break(read_to_taxids_map[read_key])
    tax_assignment = r_list[0]
    
    # This will only ever be true if BLAST_CHECK is set to True
    if r_list[1]:
        z.write('>' + read_key + '\\n' + loaded_read + '\\n')
        
        
    
    #If the read is unassigned, write it to the unassigned file.
    if tax_assignment == '*':
        e.write('>' + read_key + '\\n' + loaded_read + '\\n')
        unass_count += 1
    # otherwise write it out to the read-by-read assignment file 
    else:
        g.write(read_key + '\t' + str(tax_assignment) + '\t' + loaded_read + '\\n')
        # create a mapping of taxid -> unique reads.  Unique reads are defined as reads without the exact same sequence.  This can help in debugging.
        if "${params.WRITE_UNIQUES}" == "true":
            if str(tax_assignment) in taxid_to_read_set:
                taxid_to_read_set[str(tax_assignment)].add(loaded_read,)
            else:
                taxid_to_read_set[str(tax_assignment)] = set([loaded_read])
            
        if tax_assignment in final_assignment_counts:
            final_assignment_counts[tax_assignment] += 1
        else:
            final_assignment_counts[tax_assignment] = 1

g.close()
e.close()
if "${params.BLAST_CHECK}" == "true":
    z.close()
    subprocess.call('blastn -db ${BLAST_CHECK_DB} -task blastn -query ${base}_recheck.txt -num_threads 20 -evalue ${params.BLAST_EVAL} -outfmt "6 qseqid" -max_target_seqs 1 -max_hsps 1 > blast_check.txt', shell=True)
    redo_taxid_list = []
    for line in open('blast_check.txt'):
        redo_taxid_list.append(line.split())
    n = open('new_assignments.txt', 'w')
    for line in open("${base}" + '_assignments.txt'):
        ll = line.split('\t')
        if ll[0] in redo_taxid_list:
            n.write(ll[0] + '\t' + DB_TAXID + '\t' + ll[2].strip() + '\\n')
        else:
            n.write(line)
    n.close()
    for item in redo_taxid_list:
        final_assignment_counts[read_to_taxids_map[item]] += 1
        final_assignment_counts[DB_TAXID] += 1
    
        
        

#For each sample, we make a folder and for every taxid, we create a FASTA file that are named by their taxid.  We lose the read ID in this file.  #nicetohave would be hold the read ID here.
#Here we will write a FASTA of unique reads
if "${params.WRITE_UNIQUES}" == "true":
    subprocess.call('mkdir ' + "${base}".split('.')[0], shell=True)
    for id in taxid_to_read_set.keys():
        f = open("${base}".split('.')[0] + '/' + str(id) + '_uniques.txt', 'w')
        count = 0
        for item in taxid_to_read_set[id]:
            f.write('>' + str(count) + '\\n')
            f.write(item + '\\n')
            count += 1
        f.close()
    
tie_break_time = str(timeit.default_timer() - tie_break_start)
print('Tie breaking ' + "${base}" + ' took ' + tie_break_time)

#For each sample, write the Pavian output.
new_write_kraken("${base}", final_assignment_counts, unass_count)

if "${params.ADD_HOST_FILTERED_TO_REPORT}" == "true":
    line_count = 0
    for log_line in open("${log_file}", "rt"):
        line_count += 1
        if line_count == 4 or line_count == 5:
            final_assignment_counts[${params.HOST_FILTER_TAXID}] += int(log_line.split()[0])
        if "${params.SECOND_PASS}" == "true" and (line_count == 10 or line_count == 11):
            final_assignment_counts[${params.HOST_FILTER_TAXID}] += int(log_line.split()[0])

new_write_kraken("${base}" + '_with_host', final_assignment_counts, unass_count)


if "${params.BUILD_SAMS}" == "true":
    build_sams(sam_list)

    """
}