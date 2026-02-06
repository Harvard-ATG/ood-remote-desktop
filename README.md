# OOD Remote Desktop - Apptainer

This repo contains a working configuration to run a remote desktop in an apptainer configuration in Open OnDemand in the HUIT OOD environment. It requires a [spack](https://spack.io/) environment to use [apptainer](https://apptainer.org/) commands, and also requires a built container that exists in a location accessible to compute nodes. In this case that's a shared EFS volume.

## Compute Nodes

This app is configured to run on desktop nodes configured by Parallel Cluster, assumed to be in a queue called `desktop`. This will ensure that VNC is available for the remote desktop connection. 

## Spack Environment

The spack environment is articulated in `spack-environment/apptainer/spack.yml`. The environment can be created with a command like `spack env create apptainer ./spack-environment/apptainer/spack.yml` from the root of this repo. The run script at `template/script.sh.erb` will activate the spack installation at `/shared/spack` and then the environment called `apptainer` in order to run the container.

## Apptainer container

The definition for the apptainer container is at `build/xfce.def`. It can be invoked after the apptainer module is loaded with `apptainer build /shared/apptainerImages/xfce.sif ./build/xfce.def` from the root of this repo. This is a native apptainer image build based on an Ubuntu docker image.


### Notes

Should you get this warning while doing the apptainer build `failed to write (No space left on device)`, you can run the build via this command ex: `apptainer build --tmpdir /scratch/apptainerImages ovito.sif ovito.def`. The space availiablity  in the tmp directory that Apptainer is using is full so we will need to explicitly tell apptainer to use another directory.