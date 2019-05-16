# A prototype QC pipeline in Snakemake and Singularity

## Running

Clone the repository:

`git clone https:...`

### Unix

Run `bash startup.sh`. This will download the singularity images, and a test dataset. Then, run `snakemake --use-singularity`. 
Assumes `snakemake` is installed an available.

### Mac

Install `vagrant` and `virtualbox`. I suggest using `brew`:

`brew cask install vagrant virtualbox`

Then, run:

`vagrant up` --- this will bootstrap the Ubuntu box with Singularity installed, and will download all the Singularity images.

Then, run:

`vagrant ssh` --- this will log you on to the Ubuntu box.

Then, run:

`cd qc_folder && snakemake`

## Elements

1. Raw stats and trimming
   1. `seqtk`
   2. `timmomatic` (could eventually use `fastp`)
2. Kmer genome size and optional subsampling
   1. `mash`
3. Species identification
   1. `kraken2` --- for this prototype I am only using the 8GB minikraken DB.
4. Assembly
   1. `spades`
   2. `shovill`
   3. `skesa`
5. Serotyping/Sequence Typing
   1. `mlst`
   2. Appropriate serotyping tool for the species
6. AMR detection
   1. `abricate`


## Structure

Rather than target inputs and outputs from the different tools, I took an approach of 
generating a `toml` formatted file that has all the information (see below for an 
example output). These `toml` files 
are then passed between rules. This simplifies the rule construction, and produces 
a single file at the end with all the information we would like to archive in a DB.

At the momement, the rules are structured in a dependency structure that enforces a 
linear run through the pipeline. In other words, a rule only depends on the previous
rule, and will only affect the next rule. This is not the most efficient approach,
as there are some rules that could all depend on a single step and thus be run in 
parallel. However, this approach allows one to incrementally build the `toml` file
rather than have to gather all the files at the end.

## Rules

### `read_assessment`

Generates basic stats on the reads. Takes as a `param` the `file_type`. At the
momemt, we have two file types: `raw` and `trimmed`. The idea is that the 
rule can be reused to generate the same stats from `trimmed` files. We will
see that below.

### `trim_reads`

Uses `trimmomatic` to trim the reads. Accepts the following `params`:

- `min_qual`: Minimum quality score (0-40)
- `file_type`: default `raw` --- one could eventually preprocess the reads before trimming

One can also set the `threads` directive, defaul 1.

### `trimmed_read_assessment`

Like `read_assessment` above, but on the trimmed reads.

### `run_kraken`

Run `kraken2` to perform kmer species identification. At the moment, the command
assumes `--paired` reads. This could become flexible to allow for single-end reads.
Accepts the following `params`:

- `file_type`: whether to use the `raw` or `trimmed` reads (default: `trimmed`)
- `kraken_opts`: a `str` with additional options to pass on to the `kraken` command.

One can also set the `threads` directive, default 2.

### `estimate_genome_size`

Run `mash sketch` to estimate genome size and expected coverage of the genome. 
Accepts the following `params`:

- `file_type`: which read set to use (`raw` or `trimmed`; default: `trimmed`)
- `min_kmer_count`: ignore `kmers` with `min_kmer_count` or fewer counts (default: 3)
- `kmer_len`: the lenght of kmers to count (default: 31)
- `mash_opts`: a `str` with additional options to pass on to `mash sketch`

### `assemble_reads`

Using one of `shovill`, `spades`, or `skesa` assemble the reads. The rule 
accepts as `params`:

- `assembler`: one of `shovill`, `spades`, or `skesa`
- `file_type`: which reads to use (`raw` or `trimmed`)
- `memory`: try to keep the RAM footprint to this level (in GB)
- `asm_opts`: a `str` to pass on to the assembler command

In addition, one can set the `threads` directive (default 2).

The current setup could be modified to allow for all three assemblers to be 
run in parallel using the same rule. One would have to modify the `input`
directive to accept the `assembler` as a wildcard. One would have to modify
the approach to allow for self-contained `toml` files per rule, and then a
gather function at the end to put them all together.

### `run_mlst`

Run `mlst` on the assembled contigs. 
Accepts as parameters:

- `assembler`: to specify which assembly to use
- `mlst_opts`: a `str` to pass on to the `mlst` command with additional options.

### `run_amr`

Run `abricate` on the assembled contigs.
Accepts as parameters:

- `assembler`: to specify which assembly to use
- `db`: to specify which DB to use
- `abricate_opts`: a `str` to pass on additional options to the `abricate` command.

### `gather_toml`

A rule that will eventually act to gather all the `toml` files from individual steps
into a single `toml` for a sample.