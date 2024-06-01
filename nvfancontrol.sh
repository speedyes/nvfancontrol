#!/bin/bash
# set -x
## Variables
config_path=""
config_csv=""
config_plot=""
config_var="config.cfg"
pwm="n"
config_path="n"
hwmon="/sys/class/hwmon"
fan_good="n"
cfg=0
steps=0
sudo=0

## Functions ##

# Main function that controls fan(s)
fan_control() {
    if (( $sudo == 0 )); then
        echo "Please run with root privileges!"
        exit 1
    fi

    source config.cfg

    config_path="$user_home/.config/nvfancontrol"
    config_csv="$config_path/fan_curve.csv"
    user_name=${user_home##*/}

    if [ $pwm = "n" ]; then
        echo "pwm_path not found."
        exit 1
    elif [ $config_path = "n" ]; then
        echo "config_path not found."
        exit 1
    fi

    # Get PWM value based on temperature
    get_pwm_value() {
        local temp=$1
        while IFS=, read -r threshold pwm1; do
            if (( temp <= threshold )); then
                echo $pwm1
                return
            fi
        done < "$config_csv"
        echo 0 # Default to 0 if no match found
    }

    while true; do
        # Ensure that the fan is in manual mode (co;ntrolled by software, not firmware)
        echo 1 > "$hwmon/$pwm"_enable

        # Read GPU temperature
        gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

        # Get PWM value based on GPU temperature
        pwm_value=$(get_pwm_value $gpu_temp)

        # Write PWM value to control file
        echo $pwm_value > "$hwmon/$pwm"

        sleep 2
    done
}


# Write data to CSV
write_to_csv() {
    echo "$1,$2" >> $config_csv
}

# Convert percentage to PWM
convert_percent_to_pwm() {
    local percentage=$1
    # Calculate PWM, rounding to the nearest whole number
    local pwm=$(( (percentage * 255 + 50) / 100 ))
    echo $pwm
}

# Generate a graph
graph() {
    if ! command -v gnuplot &> /dev/null; then
        echo "gnuplot not found! Program will not generate a fan curve graph."
        return
    else
        truncate -s 0 $config_plot
        plot
    fi
}

# Generate a config for gnuplot and run gnuplot
plot() {
        echo $"set datafile separator ','" >> $config_plot
        echo $'set title "Fan Curve"' >> $config_plot
        echo $'set xlabel "Temperature"' >> $config_plot
        echo $'set ylabel "Fan Speed (PWM)"' >> $config_plot
        echo $"plot '$config_csv' using 1:2 with lines" >> $config_plot
        echo "Opening gnuplot..."
        nohup gnuplot -p $config_plot
}

pwm_valid() {
    # Check what input user has chosen
    if [[ $method == 1 ]]; then
        fan_speed=$(convert_percent_to_pwm $fan_speed)
    fi

    # Validate fan speed is within 0-255
    if ! [[ $fan_speed =~ ^[0-9]+$ ]] || [ $fan_speed -lt 0 ] || [ $fan_speed -gt 255 ]; then
        echo "Invalid fan speed. Please enter a PWM value (0-255) or percentage (0-100)"
        return
    fi
}

# Check if fan speed test mode is enabled
hwmon() {
    if (( cfg == 1 )); then
        echo "PWM device path is: $pwm"
    elif [ "$test_mode" != "n" ]; then
        echo "What's your pwm device path?"
        echo "ex. (/sys/class/hwmon/)hwmon2/pwm2"
        read pwm
    fi
}

# Check if config file already exists, if yes then clear and if no, create that file
conf_check() {
    if [ -f $config_csv ]; then
        truncate -s 0 $config_csv
    else
        mkdir -p $config_path
        touch $config_csv
    fi
}

# Check if user has root privileges
check_sudo() {
    if (( $EUID == 0 )); then
        sudo=1
    fi
}

## Logic ##

while getopts ":c" option; do
    case $option in
        c) # Enable configurator mode
            continue;;
        \?) # Invalid option
            echo "Wrong switch, exiting..."
            exit;;
    esac
done

# Check if no arguments were given (jump to fancontrol function)
if (( $# == 0 )); then
    check_sudo
    fan_control
fi

echo "Type at any moment 'exit' and changes will be saved."
echo "Tip: install gnuplot to display a nice fan curve graph at the end!"
echo ""
sleep 0.5 # Make sure user notices this message, delete if you want

# Ask user if they want to type in percentage of fan speed or raw value
echo "Speed%(100) or PWM(255)? (1/2)"
read method
echo ""

check_sudo
if [ -f $config_var ]; then
    source $config_var
    cfg=1
fi

# I don't think anybody wants their config file to be in /root
if (( cfg == 1 )); then
    echo "Home path is: $user_home"
elif (( sudo == 1 )); then
    echo "Because you run as root, type in your non-root user home path:"
    echo "ex: /home/user"
    read user_home
    echo ""
else
    user_home="$HOME"
fi

# Variables 2
config_path="$user_home/.config/nvfancontrol"
config_csv="$config_path/fan_curve.csv"
config_plot="$config_path/plot.gnuplot"
user_name=${user_home##*/}

# Ask user if they want to test fan speed each time new one gets set
if (( sudo == 1 )); then
    echo "Test your settings before saving? Requires root privileges! (Y/n)"
    read test_mode
    hwmon
fi

conf_check

# Main loop
while true; do
    while [ "$fan_good" == "n" ]; do
        echo "Enter fan speed:"
        read fan_speed
        if (( "$fan_speed" == "exit" )); then
            break 2
        elif [ "$test_mode" == "n" ]; then
            pwm_valid
            break
        elif [ $sudo = 1 ]; then
            pwm_valid
            echo ""
            echo "Spinning $pwm to $fan_speed PWM..."
            echo 1 > "$hwmon/$pwm"_enable
            sleep 0.2 # Just to be safe
            echo $fan_speed > "$hwmon/$pwm"
            sleep 1 # Wait for the fan to spin up to (almost) specified value
            echo "Did a correct fan spun up succesfully? (restart and choose different pwm if not)"
            echo "Is that speed acceptable at (not yet) defined temperature?"
            echo "(Y/n)"
            read fan_good
        else
            pwm_valid
            break
        fi
    done

    echo "Enter temperature:"
    read temperature
    if [ "$temperature" != "exit" ]; then
        fan_good="n"
        (( steps += 1 ))
        echo ""
        echo "steps: $steps"
        echo ""
    fi

    # Write the fan speed and temperature to the CSV file
    write_to_csv $temperature $fan_speed
done

# If user is root, then change ownership of config_path and it's files from root to non-root user for easier editing
if [ $sudo == 1 ]; then
    chown -hR $user_name:$user_name $config_path
fi

echo "Configuration completed. Saved to $config_path."
graph
