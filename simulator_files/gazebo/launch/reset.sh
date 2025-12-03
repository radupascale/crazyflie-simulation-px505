#!/bin/bash

WORLD="crazysim_default"
MODEL_NAME="x500_0"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
src_path="$SCRIPT_DIR/../../../../.."
build_path=${src_path}/sitl_make/build

function start_cf2()
{
    pushd $build_path
	N=$1 # Cf ID
	echo "starting instance $N in $(pwd)"
	$build_path/cf2 $((19950+${N})) > out.log 2> error.log &

	popd &>/dev/null
}

function reset_plugin()
{
    gz service -s /cf_0/reset_plugin \
        --reqtype gz.msgs.Boolean \
        --reptype gz.msgs.Boolean \
        --timeout 2000 \
        --req 'data: true' >/dev/null
}

function to_origin()
{
    gz service -s /world/$WORLD/set_pose \
        --reqtype gz.msgs.Pose \
        --reptype gz.msgs.Boolean \
        --timeout 2000 \
        --req 'name: "'$MODEL_NAME'", position: {x: 0, y: 0, z: 0.5}, orientation: {x: 0, y: 0, z: 0, w: 1}' > /dev/null &
}

# Kill everything that can make the drone move
pkill -x cf2 || true
pkill -9 "cfclient"
reset_plugin

while true; do
    read X Y _ <<< $(gz model -m "$MODEL_NAME" --pose | awk '/Pose/ {getline; gsub(/[\[\]]/,""); print $1, $2}')

    if awk "BEGIN {exit !($X > -0.1 && $X < 0.1 && $Y > -0.1 && $Y < 0.1)}"; then
        to_origin
        reset_plugin
        break
    else
        to_origin
        sleep 2.0
    fi
done


# start the fr
start_cf2 0 &

cfclient >/dev/null 2>/dev/null &
