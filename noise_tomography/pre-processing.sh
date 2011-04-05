#!/bin/bash -eu

#################### pre-simulation ###########################################################################
# in this part, we make preparations for the simulations

# now we are in this directory:   (prefix)SPECFEM3D/examples/noise_tomography
# save this path as "script_dir", later we will copy default files from this folder
script_dir=`pwd`

echo `date`
echo "running directory: $script_dir"
echo

echo
echo "(will take about 3 h 30 min)"
echo


# return to the main SPECFEM3D directory
cd ../../

# compile the package
make > tmp.log
make combine_vol_data >> tmp.log

cd $script_dir

# specify directories for executables, input files and output files
# those values are default for SPECFEM3D
bin="$script_dir/bin"
in_out_files="$script_dir/in_out_files"
in_data_files="$script_dir/in_data_files"

# specify which kernel we want to visualize
# since the Rayleigh wave is dominantly dependent on shear wave speed, we choose shear wave speed kernels
# you may visualize other kernels if you would like to
kernel="beta_kernel"

# create directories for noise simulations and adjoint simulations
# they are also default in SPECFEM3D
mkdir -p $in_out_files
mkdir -p $in_out_files/SEM
mkdir -p $in_out_files/NOISE_TOMOGRAPHY
mkdir -p $in_out_files/DATABASES_MPI
mkdir -p $in_out_files/OUTPUT_FILES

# create directories for storing kernels (first contribution and second contribution)
mkdir -p $in_out_files/NOISE_TOMOGRAPHY/1st
mkdir -p $in_out_files/NOISE_TOMOGRAPHY/2nd

# copy noise input files
cp $script_dir/NOISE_TOMOGRAPHY/S_squared                $in_out_files/NOISE_TOMOGRAPHY/
cp $script_dir/NOISE_TOMOGRAPHY/irec_master_noise*       $in_out_files/NOISE_TOMOGRAPHY/
cp $script_dir/NOISE_TOMOGRAPHY/nu_master                $in_out_files/NOISE_TOMOGRAPHY/

# copy model information
cp $script_dir/DATABASES_MPI/proc*                       $in_out_files/DATABASES_MPI/

# copy simulation parameter files
#cp $script_dir/in_data_files/Par_file*                   $in_data_files/
#cp $script_dir/in_data_files/CMTSOLUTION                 $in_data_files/
#cp $script_dir/in_data_files/STATIONS*                   $in_data_files/

# copy and compile subroutine for adjoint source calculation
#cp $script_dir/bin/adj_traveltime_filter.f90             $bin/
cd $bin
ifort adj_traveltime_filter.f90 > tmp.log
ln -s ../../../bin/xgenerate_databases
ln -s ../../../bin/xspecfem3D
ln -s ../../../bin/xcombine_vol_data

#****************************************************************************************************************************************************
#////////////////////////////// SIMULATION IS STARTING //////////////////////////////////////////////////////////////////////////////////////////////
# as theory states, one noise sensitivity kernel contains two contributions
# both the 1st and the 2nd contributions may be obtained through THREE steps
# each contribution requires a distinct 'master' reicever, as shown in Tromp et al., 2010, GJI
# each step requires slightly different Par_file, as documented in the Manual

# if you don't understand above sentences, you will probably get confused later
# please STOP now and go back to the paper & Manual
#///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#****************************************************************************************************************************************************

#################### first contribution ###########################################################################
# in this part, we start noise simulations for 1st contribution of the noise sensitivity kernels
echo `date`
echo "1. contribution..."
echo
# the master receiver is receiver 1
cp $in_out_files/NOISE_TOMOGRAPHY/irec_master_noise_contribution1  $in_out_files/NOISE_TOMOGRAPHY/irec_master_noise

# step 1 of noise simulation
cp $in_data_files/Par_file_step1                         $in_data_files/Par_file
mpirun -np 4 ./xgenerate_databases
mpirun -np 4 ./xspecfem3D

# step 2 of noise simulation
cp $in_data_files/Par_file_step2                         $in_data_files/Par_file
mpirun -np 4 ./xspecfem3D
mv $in_out_files/OUTPUT_FILES/X2.DB.BXZ.semd             $in_out_files/SEM/

# calculating adjoint source
# note that "a.out" is compiled from "ifort adj_traveltime_filter.f90"
# this program produces two traces --- adj_sources_contribution1 & adj_sources_contribution2
./a.out
# since it's 1st contribution, we inject adjoint source 1 at receiver 2
# pay attention to "adj_sources_contribution1" & "X2.DB.BXZ.adj"
# we will be using "adj_sources_contribution2" & "X1.DB.BXZ.adj" for the 2nd contribution in next part
rm $in_out_files/SEM/*.adj
cp $in_out_files/SEM/adj_sources_contribution1           $in_out_files/SEM/X2.DB.BXZ.adj

# step 3 of noise simulation
cp $in_data_files/Par_file_step3                         $in_data_files/Par_file
mpirun -np 4 ./xspecfem3D

# store kernels
cp $in_out_files/DATABASES_MPI/*kernel*                  $in_out_files/NOISE_TOMOGRAPHY/1st/

# visualization (refer to other examples, if you don't know the visualization process very well)
# note that "xcombine_vol_data" is compiled by "make combine_vol_data"
# this program generates a file "$in_out_files/OUTPUT_FILES/$kernel.mesh"
./xcombine_vol_data 0 3 $kernel $in_out_files/DATABASES_MPI/  $in_out_files/OUTPUT_FILES/ 1
# you may need to install "mesh2vtu" package first, before you can use "mesh2vtu.pl"
# convert "$in_out_files/OUTPUT_FILES/$kernel.mesh" to "$in_out_files/NOISE_TOMOGRAPHY/1st_$kernel.vtu"
# which can be loaded and visualized in Paraview
mesh2vtu.pl -i $in_out_files/OUTPUT_FILES/$kernel.mesh -o $in_out_files/NOISE_TOMOGRAPHY/1st_$kernel.vtu

# at the end of this part, we obtain the 1st contribution of the noise sensitivity kernel, stored as:
# $in_out_files/NOISE_TOMOGRAPHY/1st_$kernel.vtu

echo 

#################### second contribution ###########################################################################
# in this part, we start noise simulations for 2nd contribution of the noise sensitivity kernels

echo `date`
echo "2. contribution..."
echo

# the master receiver is receiver 2
cp $in_out_files/NOISE_TOMOGRAPHY/irec_master_noise_contribution2  $in_out_files/NOISE_TOMOGRAPHY/irec_master_noise

# step 1 of noise simulation
cp $in_data_files/Par_file_step1                         $in_data_files/Par_file
mpirun -np 4 ./xspecfem3D

# step 2 of noise simulation
cp $in_data_files/Par_file_step2                         $in_data_files/Par_file
mpirun -np 4 ./xspecfem3D

# calculating adjoint source
# since it's 2nd contribution, we inject adjoint source 2 at receiver 1
# pay attention to "adj_sources_contribution2" & "X1.DB.BXZ.adj"
# we have been using "adj_sources_contribution1" & "X2.DB.BXZ.adj" for the 1st contribution in previous part
rm $in_out_files/SEM/*.adj
cp $in_out_files/SEM/adj_sources_contribution2           $in_out_files/SEM/X1.DB.BXZ.adj

# step 3 of noise simulation
cp $in_data_files/Par_file_step3                         $in_data_files/Par_file
mpirun -np 4 ./xspecfem3D

# store kernels
cp $in_out_files/DATABASES_MPI/*kernel*                  $in_out_files/NOISE_TOMOGRAPHY/2nd/

# visualization (refer to other examples, if you don't know the visualization process very well)
# this program generates a file "$in_out_files/OUTPUT_FILES/$kernel.mesh"
./xcombine_vol_data 0 3 $kernel $in_out_files/DATABASES_MPI/  $in_out_files/OUTPUT_FILES/ 1
# you may need to install "mesh2vtu" package first, before you can use "mesh2vtu.pl"
# convert "$in_out_files/OUTPUT_FILES/$kernel.mesh" to "$in_out_files/NOISE_TOMOGRAPHY/1st_$kernel.vtu"
# which can be loaded and visualized in Paraview
mesh2vtu.pl -i $in_out_files/OUTPUT_FILES/$kernel.mesh -o $in_out_files/NOISE_TOMOGRAPHY/2nd_$kernel.vtu

# at the end of this part, we obtain the 2nd contribution of the noise sensitivity kernel, stored as:
# $in_out_files/NOISE_TOMOGRAPHY/2nd_$kernel.vtu

echo
echo `date` 
echo "done"

