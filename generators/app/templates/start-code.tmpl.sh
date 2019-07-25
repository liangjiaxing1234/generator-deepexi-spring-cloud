#!/bin/bash
cd `dirname $0`

source ./common.sh

#----------------- 参数提取 start -----------------#
output_log=
build=
port=8080

while getopts lbp: opt
do
    case $opt in
        l)
            output_log=true
            ;;
        b)
            build=true
            ;;
        p)
            port=$OPTARG
            ;;
        ?)
            error "Usage: %s: [-b] [-l] [-p] args\n" $0
            exit 2
            ;;
    esac
done
#----------------- 参数提取 end -----------------#

#----------------- 启动逻辑 start -----------------#
project_name='${artifactId}'

img_mvn="maven:3.3.3-jdk-8"                 # docker image of maven
m2_cache=~/.m2                              # the local maven cache dir
proj_home=$PWD                              # the project root dir
img_output=$project_name                    # output image tag
container_name=$img_output                  # container name

h1 '准备启动应用'$project_name'（基于Docker）'

if [ ! -z $build ];then
    h2 '准备构建项目'

    if which mvn ; then
        info '使用本地maven构建项目'
        mvn clean package -DskipTests
    else
        info '使用maven镜像['$img_mvn']构建项目'
        docker run --rm \
            -v $m2_cache:/root/.m2 \
            -v $proj_home:/usr/src/mymaven \
            -w /usr/src/mymaven \
            $img_mvn mvn clean package -DskipTests
    fi
    if [ $? -eq 0 ];then
        success '项目构建成功'
    else
        error '项目构建失败'
        exit 1
    fi

    h2 '准备构建Docker镜像'

    sudo mv $proj_home/$project_name-provider/target/$project_name-*.jar $proj_home/$project_name-provider/target/app.jar
    docker build --rm -t $img_output .
    if [ $? -eq 0 ];then
        success '镜像构建成功'
    else
        error '镜像构建失败'
        exit 2
    fi
fi

info '删除已存在的容器' && docker rm -f $container_name

info '准备启动docker容器'

CONTAINER_NAME=$container_name \
PORT=$port \
IMG_NAME=$img_output \
sh run.sh

if [ $? -eq 0 ];then
    success '容器启动成功'
else
    error '容器启动失败'
    exit 3
fi

if [ ! -z $output_log ];then
    note '以下是docker容器启动输出，你可以通过ctrl-c中止它，这并不会导致容器停止'
    docker logs -f $container_name
fi

#----------------- 启动逻辑 end -----------------#
