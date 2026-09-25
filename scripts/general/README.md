# General bioinformatics scripts

Scripts for miscellaneous bioinformatics tasks, such as compression and decompression of data.

### compress.sh
```
Archive and compress a directory on the HPC into a single .tar.gz using
multi-threaded pigz. The original directory is left in place.

  1. Check the input directory exists
  2. Create a .tar.gz of the directory with tar + pigz
     (threads taken from --cpus-per-task)
  3. Report success and the output archive size, or exit with an error

Requirements:
  - Conda environment with pigz (archive)
  - Free disk space for the compressed archive alongside the original data

Input:
  - Path to the directory to compress, with no trailing slash (INPUT_DIR)

Main outputs (in the parent directory of INPUT_DIR):
  - <INPUT_DIR name>.tar.gz, containing the directory itself as its top level
    e.g. /path/to/data/folder -> /path/to/data/folder.tar.gz
  - SLURM logs (in the submission directory):
    compress_<jobid>.out, compress_<jobid>.err

Usage:
  Set INPUT_DIR to the directory to compress, then:
  sbatch compress.sh

version: 1.0
```


### decompress.sh
```
Decompress and extract a .tar.gz archive on the HPC using multi-threaded
pigz, keeping the original archive.

  1. Decompress the .tar.gz to an intermediate .tar (pigz, 8 threads)
  2. Extract the .tar into the same directory as the input archive
  3. Remove the intermediate .tar after decompression

Requirements:
  - Conda environment with pigz (archive)
  - Free disk space for both the intermediate .tar and the extracted
    contents alongside the original archive

Input:
  - Absolute path to a .tar.gz archive (INPUT_ARCHIVE)

Main outputs (in the input archive's directory):
  - Extracted archive contents
  - Original .tar.gz is kept (pigz -k)
  - SLURM logs: decompress_<jobid>.out, decompress_<jobid>.err

Usage:
  Set INPUT_ARCHIVE to the absolute path of the archive, then:
  sbatch decompress.sh

version: 1.0
```
