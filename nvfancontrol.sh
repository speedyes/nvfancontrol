#!/bin/bash

# Path to the PWM control file (ex. /sys/class/hwmon/hwmon2/pwm2)
pwm_path="pwm"

# Path to the CSV configuration file (ex. /home/user/.config/nvfanconf)
config_path="conf"

if [ $pwm_path == "pwm" ]; then
    echo "Please open fanscript.sh with your editor and edit 'pwm_path' variable!"
    exit 1
elif [ $config_path == "conf" ]; then
    echo "Please open fanscript.sh with your editor and edit 'config_path' variable!"
    exit 1
fi

# Function to get PWM value based on temperature
get_pwm_value() {
    local temp=$1
    while IFS=, read -r threshold pwm; do
        if (( temp <= threshold )); then
            echo $pwm
            return
        fi
    done < "$config_path/fan_curve.csv"
    echo 0 # Default to 0 if no match found
}

while true; do
    # Ensure that the fan is in manual mode (controlled by software, not firmware)
    echo 1 > "$pwm_path"_enable

    # Read GPU temperature
    gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

    # Get PWM value based on GPU temperature
    pwm_value=$(get_pwm_value $gpu_temp)

    # Write PWM value to control file
    echo $pwm_value > $pwm_path

    sleep 2
done
