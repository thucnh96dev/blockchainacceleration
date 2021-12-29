#!/bin/bash

# ## License

# Licensed using the [Apache 2.0 license](https://www.apache.org/licenses/LICENSE-2.0).

#     Copyright 2019-2021 Xilinx, Inc.
#     
#     Licensed under the Apache License, Version 2.0 (the "License");
#     you may not use this file except in compliance with the License.
#     You may obtain a copy of the License at
#     
#         http://www.apache.org/licenses/LICENSE-2.0
#     
#     Unless required by applicable law or agreed to in writing, software
#     distributed under the License is distributed on an "AS IS" BASIS,
#     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#     See the License for the specific language governing permissions and
#     limitations under the License.


function print_help() {
    echo ""
    echo "Usage: ./build.sh [option]"
    echo "Options:"
    echo "help                                     print this help"
    echo "build_ethash                             build ethash_kernel.xclbin"
    echo "build_daggen                             build dag_gen_kernel.xclbin"
    echo "build_host                               build ethminer"
    echo "get_xclbin                               down xclbin files needed from Xilinx OMS"
    echo "mine <wallet> <name> <pool_address>      start mining with your wallet, name and pool address"
    echo ""
}

function build_ethash() {
    echo ""
    if [ ! $XILINX_XRT ]
    then
	    echo "Please setup XRT"
        echo "build _ethash"
    elif [ ! $XILINX_VITIS ]
    then
        echo "Please setup Vitis"
		echo "build _ethash"
    else
        export DEVICE=u55n_gen3x4
        export TARGET=hw
        echo "Start to build ethash_kernel.xclbin, will takes several hours"
        cd ./hw/ethash8Greturn
        make xclbin
        cp build_dir.$TARGET.$DEVICE/ethash_kernel.xclbin ../../
        cd ../..
    fi
    echo ""
}

function build_daggen() {
    echo ""
    if [ ! $XILINX_XRT ]
    then
        echo "Please setup XRT"
		echo "build _daggen"
    elif [ ! $XILINX_VITIS ]
    then
        echo "Please setup Vitis"
		echo "build _daggen"
    else
        export DEVICE=u55n_gen3x4
        export TARGET=hw
        echo "Start to build dag_gen_kernel.xclbin, will takes several hours"
        cd ./hw/genDAG
        make xclbin
        cp build_dir.$TARGET.$DEVICE/dag_gen_kernel.xclbin ../../
        cd ../..
    fi
    echo ""
}

function get_xclbin() {
    echo ""
    echo "Download xclbins files needed from Xilinx OMS"
    echo "dag_gen_kernel.xclbin:  https://www.xilinx.com/member/forms/download/xef.html?filename=dag_gen_kernel.xclbin"
    echo "ethash_kernel.xclbin:   https://www.xilinx.com/member/forms/download/xef.html?filename=ethash_kernel.xclbin"
    echo "Pleaase put the xclbin files listed above to the same directory of this build.sh script"
    echo ""
}

function check_devtool() {
    echo ""
    echo "INFO : checking devtool version ..."
    DEVTOOLPATH=/etc/scl/conf
    cd $DEVTOOLPATH

    for file in ./*
    do
        if [ $file == "./devtoolset-7" ] || [ $file == "./devtoolset-8" ]
        then
            #echo $file
            break
        fi
    done

    if [ -e $file ]
        then
            DEVTOOL=${file:2:13}
            echo "INFO : check devtool $DEVTOOL passed!"
            echo "INFO : If there is still regex_error when run the board, Please rerun the following steps:"
            echo "INFO : 1. rm -rf ~/.hunter "
            echo "INFO : 2. mkdir -p ~/.hunter/_Base/Download/Boost/1.66.0/075d0b4/"
            echo "INFO : 3. scl enable $DEVTOOL bash"
            echo "INFO : 4. . build.sh build_host"
    else
        echo"WARNING : regex_error occures when the version of GCC using the Developer Toolset software collection is less than 6!"
    fi
    cd $OLDPWD
    echo ""
    #echo $DEVTOOL
    #scl enable $file bash
    #echo "get_devtool done"
    #return $DEVTOOL
}

function build_host() {
    echo ""
    echo "Please install OpenCL headrs before building host"
    echo "On CentOS, you may try 'sudo yum install opencl-headers' "
    echo "On Ubuntu, you may try 'sudo apt-get install -y opencl-headers' "

    if [ ! $XILINX_XRT ]
    then
        echo "Please setup XRT"
        echo " build_host"
    else
        check_devtool
        #rm -rf boost_1_66_0.7z
        rm -rf ethminer
        echo "Download ethminer"
        git clone https://github.com/ethereum-mining/ethminer.git
        #wget https://boostorg.jfrog.io/artifactory/main/release/1.66.0/source/boost_1_66_0.7z
        mv boost_1_66_0.7z ~/.hunter/_Base/Download/Boost/1.66.0/075d0b4/
        cd ethminer
        git checkout -b xilinx_platform
        git reset --hard cd75c13d38eceb6fed78d47104440a762ca1894e
        git config user.email "dummy@dummy.com"
        git config user.name "Dummy Name"
        git am --abort
        git am ../sw/*.patch
        git submodule update --init --recursive
        mkdir build
        cd build
        cmake ..
        make -j 10
        cd ../../
    fi
    echo ""
}

function mine() {
    echo ""
    echo "mine"
    echo "account:              $1"
    echo "name:                 $2"
    echo "mining pool address:  $3"

    xclbin_1="ethash_kernel.xclbin"
    xclbin_2="dag_gen_kernel.xclbin"
    exe_file="ethminer/build/ethminer/ethminer"
    if [ -f $xclbin_1 ]
    then
        cp $xclbin_1 ethminer/build/ethminer/
    else
        echo "Please build $xclbin_1 or download from Xilinx"
    fi
    if [ -f $xclbin_2 ]
    then
        cp $xclbin_2 ethminer/build/ethminer/
    else
        echo "Please build $xclbin_2 or download from Xilinx"
    fi
    if [ -f $exe_file ]
    then
        :
    else
        echo "Please build ethminer"
    fi

    if [ -f $xclbin_1 ] && [ -f $xclbin_2 ] && [ -f $exe_file ]
    then
        $exe_file -P stratum1+tcp://$1.$2@$3 | tee ./test.log
    fi
}


if [ $# == 0 ]
then
    print_help
elif [ $1 = help ]
then
    print_help
elif [ $1 = build_ethash ]
then
    build_ethash
elif [ $1 = build_daggen ]
then
    build_daggen
elif [ $1 = get_xclbin ]
then
    get_xclbin
elif [ $1 = build_host ]
then
    build_host
elif [ $1 = mine ]
then
    if [ $# = 4 ]
    then
        mine $2 $3 $4
    else
        echo ""
        echo "Need provide acount, name and mining pool address"
        print_help
    fi
else
    echo ""
    echo "Unrecognized option"
    print_help
fi
