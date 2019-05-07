include config

.PHONY : help
help : Makefile
	@sed -n 's/^##//p' $<
###################################################
##
## leap_prep : complex_structs protein_structs
## __ creates all prmtop, inpcrd files for wild-type and mutant free protein and complexes, as well as their dependencies
##
.PHONY : leap_prep
leap_prep : PRMTOPwat_complex.prmtop INPCRDwat_complex.inpcrd PRMTOPwat_protein.prmtop INPCRDwat_protein.inpcrd
## leap_prep recipes ::
##
## MAA.lib : MAA.cmd
## __ creates .lib for Mutant Amino Acid
##
## complex_structs : leap_complex.in MAA.lib
## __ makes paramter/topology and coord files for complex
##
## protein_structs : leap_protein.in MAA.lib
## __ makes paramter/topology and coord files for free protein
##
MAA.lib : MAA.cmd
	@sh $< $(MUT_3) >> leap.log
.PHONY complex_structs : 
PRMTOPwat_complex.prmtop INPCRDwat_complex.inpcrd PRMTOPwat_protein.prmtop INPCRDwat_protein.inpcrd : leap.in MAA.lib | $(PDBdir)
	@sh $< $(WT_struct) $(MUT_struct) $(MHC_struct) "$(TCRSSBondList)" "$(MHCSSBondList)" $(p_ions) $(c_ions) >> leap.log
	@grep -i error leap.log

###################################################
##
## merge_prmtops : PRMTOPwat_%-merged.prmtop INPCRDwat_%-merged.inpcrd
## __ submits jobs using parmed.py to merge prmtops for TI
## __ Exits Makefile afterwards. These jobs are submitted to the SGE, so you must wait for them to complete before continuing.
##
.PHONY : merge_prmtops
merge_prmtops : merge_complex.out merge_protein.out
	$(error PRMTOP merge job files submitted -- please wait until these jobs are finished to continue.)
## merge_prmtops recipes ::
##
## merge_complex : PRMTOPwat_complex-merged.prmtop INPCRDwat_complex-merged.inpcrd
## __ combines prmtop and inpcrd files for TCR/pMHC complexes.
##
## merge_protein : PRMTOPwat_protein-merged.prmtop INPCRDwat_protein-merged.inpcrd
## __ combines prmtop and inpcrd files for free TCRs.
##
merge_protein.out : PRMTOPwat_protein-merged.prmtop INPCRDwat_protein-merged.inpcrd
merge_complex.out : PRMTOPwat_complex-merged.prmtop INPCRDwat_complex-merged.inpcrd

PRMTOPwat_%-merged.prmtop INPCRDwat_%-merged.inpcrd : merge.in PRMTOPwat_%.prmtop INPCRDwat_%.inpcrd
	@sh $< $* $(MUT) $(HM)
###################################################
##
## setup_min
## __ creates directories for complex, free protein, and each window for both conditions between 0.00 .. lambda .. 1.00
## __ submits minimization jobs for each of these windows, using 8-32 cores (min_job.sh)
## __ This recipe exits Makefile after job submission. Jobs are submitted to the SGE, so you must wait for them to complete before continuing.
.PHONY : setup_min
setup_min : min_protein min_complex
	$(error Minimization job files submitted -- please wait until these jobs are finished to continue.)
## setup_min recipes ::
##
## min_protein : min_job.sh ALL MD TEMPLATES equalize_volume.sh and proper directory structure
## __ starts minimization jobs, and fills in variables specific to each lambda window for free protein
##
## min_complex : min_job.sh ALL MD TEMPLATES equalize_volume.sh and proper directory structure
## __ starts minimization jobs, and fills in variables specific to each lambda window for complex
##
min_% : min_job.sh $(mdTemplates) equalize_volume.sh | %Wins
	@sh $< $* $($*JOBnames) $(MDinpDir) $(jobInpDir) "$(windows)" $(dt)
###################################################
##
## setup_prep
## __ Submits job performing steps md1 (defrost) through md4 (NVT equilibration).
## __ Can sometimes fail between md3 (NPT equilibration) and md4 -- density equilibration script (equalize_volume) is not perfect.
##
.PHONY : setup_prep
setup_prep : prep_complex prep_protein
## setup_prep recipes::
##
## prep_protein :
## prep_complex : 
## __ Checks each window in TOP/run/CONDITION/ folder for:
## ____ 1.) a complete md0_min2.out
## ____ 2.) No jobs are running with JOBNAME for that window.
## __ If both of these are true, then submits prep.job for all windows. Otherwise, informs users that minimization does not appear complete.
##
prep_% :
	@$(foreach var,$(windows),test "$(shell tail -n 1 run/$*/$(var)/md0_min2.out | tr -s ' ' | cut -d ' ' -f 2)" = 'Master' && test ! $(shell qstat | grep $($*JOBnames) | tail -n 1 | tr -s ' ' | cut -d ' ' -f 5) = gkeller1 && echo "qsub run/$*/$(var)/prep.job" || echo "Minimization not yet complete in $* window $(var).";)
###################################################
##
## setup_prod : prod_complex prod_protein
## prod_complex :
## prod_protein : 
## __ Checks each window in TOP/run/CONDITION/ folder for:
## ____ 1.) a complete Prod_0.rst
## ____ 2.) No jobs are running with JOBNAME for that window.
## __ If both of these are true, then submits prep.job for all windows. Otherwise, informs users that prep. jobs do not appear complete.
##
.PHONY : setup_prod
setup_prod : prod_complex prod_protein
prod_% :
	@$(foreach var,$(windows),test -f run/$*/Prod_0.rst && test ! $(shell qstat | grep $($*JOBnames) | tail -n 1 | tr -s ' ' | cut -d ' ' -f 5) = gkeller1 && echo "qsub run/$*/$(var)/prod.job" || echo "Equilibration not yet complete in $* window $(var).";)
###################################################
$(PDBdir) :
	@mkdir $(PDBdir)

$(RUNdir) :
	@mkdir $(RUNdir)

$(CONDdirs) : $(RUNdir)
	@$(foreach cond,$(CONDdirs),mkdir $(cond);)

MDdirs : complexWins proteinWins
%Wins : | $(CONDdirs)
	@$(foreach var,$(windows),mkdir $(RUNdir)/$*/$(var)/;)
	@$(foreach var,$(windows),mkdir $(RUNdir)/$*/$(var)/$(var)-prep/;)
###################################################
##
## UTIL Recipes ::
##
## todo :
## __ Lists Features to be added.
##
.PHONY : todo
todo :
	@echo "TO-DO"
	@echo "1.) General case disulfides in leap for protein, complex."
	@echo "		1a.) Translate numbering from PDB -> leap."
	@echo "		1b.) Replace appropraite CYS with CYX but NO OTHERS."
	@echo " 2.) Check for finished merge files prior to minimization."
	@echo "		2a.) Merge.out files end with done."
## check :
## __ Lists required scripts, input files which are nonexistent or not currently in the correct location.
## __ This should be run before starting the workflow unless user is familiar with the process.
##
.PHONY : check
check :
	@$(foreach file,$(fileList),test -f $(file) || echo "Missing master script: $(file)";)
	@$(foreach struct, $(WT_protein) $(WT_complex) $(MUT_protein) $(MUT_complex),test -f $(struct) || echo "Missing PDB file: $(struct)";)
	@$(foreach dir,$(tempDirs),test -d $(dir) || echo "Missing directory: $(dir)";)
	@$(foreach temp,$(mdNames),test -f $(MDinpDir)/$(temp).tmpl || echo "Missing MD template: $(temp).tmpl";)
	@$(foreach job,prep.job prod.job,test -f $(jobInpDir)/$(job) || echo "Missing job template: $(job)";)
## Run: make instructions to receive instructions for running AMBER TI using this workflow.
##
.PHONY : instructions
instructions : Makefile
	@sed -n 's/^#@//p' $<

.PHONY : clean
clean :
	@rm *.prmtop *.inpcrd *.out leap.log 
	@rm -r $(RUNdir)/
#@
#@
#@ TO USE for AMBER Thermodynamic Integration::
#@ __ Prepare PDB files for each structure. Change mutating residue to "MAA." Rename cystines to CYX. Remove H atoms.
#@ __ Edit config file with disulfide bond info for protein and complex, job name, etc.
#@ __ run: make merge_prmtops
#@ __ Once merge_prmtop jobs are finished (several hours) run: make setup_min
#@ __ Once minimization is complete for both complex and protein, run: make setup_prep.
#@ __ __ Alternatively, run prep separately for complex, protein with: make prep_complex, make prep_protein.
#@ __ Once prep is finished, run: make setup_prod.
#@ __ Separate production run commands are analogous to those for prep.
#@
#@
