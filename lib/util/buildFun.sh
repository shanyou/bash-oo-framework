# build docker function
namespace util/buildFun
# return $1 random tag
gen_tag() {
    local  __resultvar=$1
    local date_str=$(date +"%Y%m%d.%H%M")

    if [[ "$__resultvar" ]]; then
        eval $__resultvar="'$date_str'"
    else
        echo "$date_str"
    fi

    return 0
}

# build docker image
# param $1: path contains Dockerfile
# return $2 imageid for build image
# error exit when no Dockerfile find in path
function build_image {
    [string] __build_path
    [string] __build_ver
    [string] __resultvar
    pushd $__build_path

    if ! [ -f "Dockerfile" ]; then
        subject=error Log "Can not find Dockerfile !!!"
        return 1
    fi

    if [[ -z "$__build_ver" ]]; then
        Log "__build_ver is empty try generate a new one"
        gen_tag __build_ver
    fi

    local __build_name=$(basename ${1})
    local __docker_tag=${IMAGE_ROOT}/${__build_name}:${__build_ver}

    docker build --rm -t $__docker_tag .
    if [[ "$?" != 0 ]]; then
        Log "build image failed"
        return 1
    fi
    local __image_id=$(docker images -q $__docker_tag | head -n 1)
    docker tag ${IMAGE_ROOT}/${__build_name}:${__build_ver} ${IMAGE_ROOT}/${__build_name}:latest
    Log "build image ${__image_id} done !!!"

    popd

    if [[ "$__resultvar" ]]; then
        eval $__resultvar="'$__image_id'"
    else
        echo "$__image_id"
    fi

    return 0
}

# build jar use gradle
# param $1: project directory
# error exit when no gradle.build file in path
function build_jar {
    pushd $1

    if ! [ -f "build.gradle" ]; then
        subject=error Log "Can not find file build.gradle !!!"
        return 1
    fi

    gradle clean
    gradle assemble
    local __res=$?
    popd
    return "$__res"
}

function build_test {
    pushd $1

    if ! [ -f "build.gradle" ]; then
        subject=error Log "Can not find file build.gradle !!!"
        return 1
    fi

    gradle clean
    gradle build
    local __res=$?
    popd
    return "$__res"
}

# try to use wechat noify user build progress
function notify_message() {
    curl -X POST -H "Content-Type: text/plain" -d "$*" $WECHAT_API
}

# get docker tag name by image id from $1
# param $1: image id
# return $2 tag
function get_tags_by_id {
    local  __resultvar=$2
    local __tags
    if ! [ -z "$1" ]; then
        __tags=$(docker images | grep $1 | head -n 1 | awk '{printf("%s:%s", $1, $2)}')
    fi

    if [[ "$__resultvar" ]]; then
        eval $__resultvar="'$__tags'"
    else
        echo "$__tags"
    fi

    return 0
}

# publish image to remote docker registry
# param $1 local image id
# error exit when image id not exists
function publish_image_by_id {
    local __image_id=$1
    if [ -z "${__image_id}" ]; then
        subject=error Log "Input image id empty"
        return 1
    fi
    Log "begin publish local ${__image_id} to remote"
    local __local_tag
    unset __local_tag

    get_tags_by_id ${__image_id} __local_tag
    if [ -z "${__local_tag}" ]; then
        subject=error Log "image ${__image_id} not exists try to build one"
        return 1
    fi

    Log "begin publish image to remote registry"
    local __latest_tag=$(echo ${__local_tag} | sed "s/\(.*\):.*/\1:latest/g")
    docker tag ${__local_tag} ${REMOTE_REG}/${__latest_tag} 2>/dev/null
    docker tag ${__local_tag} ${REMOTE_REG}/${__local_tag} 2>/dev/null

    Log "begin publish tag latest"
    docker push ${REMOTE_REG}/${__latest_tag}
    Log "begin publish tag ${__local_tag}"
    docker push ${REMOTE_REG}/${__local_tag}
    Log "publish image done !!!"
    return 0
}

function copy_build() {
    [string] __build_path
    [string] __build_ver
    [string] __copy_path
    [integer] __for_publish
    __for_publish=${__for_publish:-0}

    pushd $__build_path

    local __build_name=$(basename ${1})
    local __docker_tag=${IMAGE_ROOT}/${__build_name}:${__build_ver}

    __copy_path=${__copy_path:-$PUBLISH_DIR}

    local __publish_tag=""
    if [[ "${__for_publish}" != 0 ]]; then
        # tag build for publish
        __publish_tag="_publish"
    fi
    local __copy_latest_path=${__copy_path}/${PUBLISH_LATEST}

    Log init copy path ${__copy_path}
    #rm -rf ${__copy_path}/* 2>/dev/null
    rm -rf ${__copy_latest_path}/* 2>/dev/null
    mkdir -p ${__copy_path}/${__build_ver}${__publish_tag}
    mkdir -p ${__copy_latest_path}

    # TODO: try to verify that docker image exists
    Log begin save docker images
    # find image id
    local __image_id=$(docker images | grep ${__build_name} | grep ${__build_ver}| head -n 1 | awk '{print $3}')
    Log get __image_id is ===== ${__image_id}
    docker save -o ${__copy_path}/${__build_ver}${__publish_tag}/${__build_name}.image.${__image_id}.tar $__docker_tag


    Log generate app version and git log
    echo $__build_ver > ${__copy_path}/${__build_ver}${__publish_tag}/version.txt
    git log -3 --pretty=format:"%d %H %ai %an %s" > ${__copy_path}/${__build_ver}${__publish_tag}/gitlog.txt

    Log copy artifact
    __app_dirs=($(find -name "distributions"))
    for __app_dir in "${__app_dirs[@]}"; do
      yes | cp -rf ${__app_dir}/*.tar ${__copy_path}/${__build_ver}${__publish_tag}/ || true
      yes | cp -rf ${__app_dir}/*.zip ${__copy_path}/${__build_ver}${__publish_tag}/ || true
    done

    Log copy latest
    yes | cp -rf ${__copy_path}/${__build_ver}${__publish_tag}/* ${__copy_latest_path} || true
    popd
}
