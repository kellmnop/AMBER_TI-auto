# AMBER_TI-auto

Allows for automated thermodynamic integration of single point mutations in TCR:pMHC complexes in AMBER molecular dynamic simulations.

The main workhorse is provided as a *Makefile*, with each session-specific parameters specified in the *config* file.
All scripts are set to run on Notre Dame's CRC UGE.

## To use:

1. Prepare PDB files for each structure (TCR, pMHC, mutant TCR) including modifying cystine residues to CYX. The mutant TCR should be identical to the TCR structure, but with atoms not common with the WT residue removed and the mutant position name switch to MAA.
1. Edit config file with file names, job names, disulfide information, etc.
1. run `make merge_prmtops` to create AMBER paramter/toplogy and coordinate files, and combine these for use in TI. May take up to several hours to complete.
1. Once *merge_complex.out* and *merge_protein.out* files are successful, run `make setup_min` to start minimization jobs.
1. Once _md0_min1.out_ and _md0_min2.out_ are finished, run `make setup_prep`.
1. Production run commands are analogous to those for prep.
