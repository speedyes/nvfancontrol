#!/bin/bash
# Exit if any error occurs
# set -e
# Print every command that runs to the terminal
# set -x

# Path to the PWM control file
PWM_PATH="/sys/class/hwmon/hwmon2/pwm2"

# Path to the CSV configuration file
CONFIG_PATH="/home/speed/l.csv"

# Main function
main() {
    echo "Create a config file now? (y/n)"
    read ans
    if [ $ans == y ]; then
        config
    elif [ $ans == n ]; then
        read_config
    else
        echo "I accept only y/n!"
    fi
}

# Config

# config() {
#     return
# }

# Function to get PWM value based on temperature
get_pwm_value() {
    local temp=$1
    while IFS=, read -r threshold pwm; do
        if (( temp <= threshold )); then
            echo $pwm
            return
        fi
    done < "$CONFIG_PATH"
    echo 0 # Default to 0 if no match found
}

while true; do
    # Ensure that the fan is in manual mode (controlled by software, not firmware)
    echo 1 > "$PWM_PATH"_enable

    # Read GPU temperature
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

    # Get PWM value based on GPU temperature
    PWM_VALUE=$(get_pwm_value $GPU_TEMP)

    # Write PWM value to control file
    echo $PWM_VALUE > "$PWM_PATH"
    # Print fan speed (0-255) and GPU Temperature for debugging
    # echo "fan=$PWM_VALUE    temp=$GPU_TEMP"
    sleep 2
done
