#	trim_shell_pe.py V 1.0
#	Copyright (C) 2019 Ryan C. Shean 
#		This program is free software: you can redistribute it and/or modify
#		it under the terms of the GNU General Public License as published by
#		the Free Software Foundation, either version 3 of the License, or
#		(at your option) any later version.

#		This program is distributed in the hope that it will be useful,
#		but WITHOUT ANY WARRANTY; without even the implied warranty of
#		MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#		GNU General Public License for more details.

#		You should have received a copy of the GNU General Public License
#		along with this program. If not, see <http://www.gnu.org/licenses/>.# multi_snap_shell.py 


# goes through all host filtered and trimmed paired end fastq files in a folder and aligns them to a bunch of snap databases 
# outputs one sam file per sample per snap database. - more extensive commenting is available in the SE version
import subprocess
import glob
# edit this list to reflect the naming convention of the number of chunks of NT you made 
DB_LIST = ['00','01','02','03','04','05','06','07','08','09','10','11','12','13']

for db_num in DB_LIST:
	# this just builds a text string for each of our snap indexes so if you named yours different things modify this 
	snap_db = '/hd2/nt.' + db_num + '.snapindex'
	# points to location of snap aligner (Use the one I have forked on my github to avoid writing HUGE headers on each sam file) 
	snap_cmd = '/tools/snap2/snap/snap-aligner '
	
	# we build the command for all files per database, this allows us to load each database into RAM only once which is the slowest part of the entire process
	for file_name in glob.glob('*_hf.trimmed.fastq'):
		base = file_name.split('_')[0]
		r1 = base_name + '_R1_hf.trimmed.fastq'
		r2 = base_name + '_R2_hf.trimmed.fastq'
		
		print('Aligning ' + base + ' to viral nt...')
		# SNAP options:
		# -t number of threads for multi-threading
		# -mrl minimum read length to even attempt to align - we have this set REALLY low. I recommend that this be at least 50 
		# -d maximum edit distance that we allow for an alignment 
		# -h maximum number of other locations that a read can align to - 
		# -omax additional number of alignments to report
		# -om extra edit distance that that extra alignments specified by -omax are allowed to be from the 'best' alignment 
		snap_cmd += ' paired ' + snap_db + ' ' + r1 + ' ' + r2 + ' -o ' + base + '_' + db_num + '.sam -t 42 -mrl 30 -d 11 -h 30000 -om 1 -omax 20 , '

	subprocess.call(snap_cmd, shell =True)

