#!/bin/bash

## Variables
config_path=""
config_csv=""
config_plot=""
hwmon="/sys/class/hwmon"
fan_good="n"
steps=0
sudo=0

## Functions ##

# Function to write data to CSV
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

hwmon() {
    if [ "$test_mode" == "n" ]; then
        return
    else
        echo "What's your pwm device path?"
        echo "ex. (/sys/class/hwmon/)hwmon2/pwm2"
        read pwm
    fi
}

## Logic ##

conf_check() {
    # Check if config file already exists, if yes then clear and if no, create that file
    if [ -f $config_csv ]; then
        truncate -s 0 $config_csv
    else
        mkdir -p $config_path
        touch $config_csv
    fi
}

if (( $EUID == 0 )); then
    sudo=1
fi

echo "Type at any moment 'exit' and changes will be saved."
echo "Tip: install gnuplot to display a nice fan curve graph at the end!"
echo ""
sleep 0.5 # Make sure user notices this message, delete if you want

# Ask user if they want to type in percentage of fan speed or raw value
echo "Speed%(100) or PWM(255)? (1/2)"
read method
echo ""

# I don't think anybody wants their config file to be in /root
if (( sudo == 1 )); then
    echo "Because you run as root, type in your non-root user home path:"
    echo "ex: /home/user"
    read user_home
    echo ""
else
    user_home="$HOME"
fi

config_path="$user_home/.config/nvfanconf"
config_csv="$config_path/fan_curve.csv"
config_plot="$config_path/plot.gnuplot"

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
    if [ "$temperature" == "exit" ]; then
        break
    else
        fan_good="n"
        (( steps += 1 ))
        echo ""
        echo "steps: $steps"
        echo ""
    fi

    # Write the fan speed and temperature to the CSV file
    write_to_csv $temperature $fan_speed
done
echo "Configuration completed. Saved to $config_path."
graph
